# How Tilawa Handles App Locking and Unlocking

This document explains how guarded apps (e.g. Instagram) are locked and unlocked, what the UI shows, and what actually happens on the device.

---

## Two Layers Involved

### 1. ManagedSettings (what is blocked)

- **`ManagedSettingsStore`** (named `"tilawa.shield"`) holds what *can* be blocked.
- **`applyShield()`**  
  - **`store.shield.applications`** — individual apps from `FamilyActivitySelection.applicationTokens`, minus toggled-off apps.  
  - **`store.shield.applicationCategories`** — **`.specific(…)`** for categories from `selection.categoryTokens` (e.g. Social), minus toggled-off categories; **`.none`** when none.  
  - **Effect:** The system blocks those apps and/or apps in those categories **when** the store is considered “active.”
- **`removeShield()`**  
  - Clears **both** `applications` and **`applicationCategories`** (`.none`).  
  - **Effect:** Blocking stops for apps and categories.

So: **Lock = store has apps and/or categories set. Unlock = store cleared for both.**

### 2. DeviceActivity (when blocking is active)

- **`DeviceActivityCenter`** and **`DeviceActivitySchedule`** control *when* the system runs the **TilawaMonitor** extension (e.g. full day 00:00–23:59 for normal blocking, or “from now to now+15 min” for the unlock window).
- **Unlock flow:** When the user completes the gate we **clear the store** (`removeShield()`) so apps unlock immediately. We then start a schedule for activity **`tilawa.relock`** with interval **now → now+15 minutes**. When that interval **ends**, the system calls **`intervalDidEnd`** in the TilawaMonitor extension, which **re-applies the shield** from tokens saved in App Group UserDefaults. So: unlock = remove shield + start short schedule; relock = extension runs at end of interval and sets `store.shield.applications` again.
- **Token persistence:** On each `applyShield()`, the main app saves **`tilawa.shieldApplicationTokens`** and **`tilawa.shieldCategoryTokens`** to the App Group. The extension’s **`intervalDidEnd`** restores **both** `store.shield.applications` and **`store.shield.applicationCategories`**. Selection, excluded apps, and excluded categories are persisted so they survive restarts.
- **Schedule minimum:** `DeviceActivitySchedule` requires a minimum interval length; 5 and 10 minutes trigger **`intervalTooShort`**. We use **15 minutes** for the unlock window.

---

## Next Lock (schedule + UI)

- **`nextLockAt`** is stored (as a timestamp) in:
  - App Group UserDefaults (`group.com.tilawa.app`)
  - Read by both the app and the ShieldConfigurationExtension.

- **`nextSessionDelay`** is an enum (user choices):

  ```swift
  enum NextSessionDelay: String, CaseIterable, Codable {
      case m15, m30, m60, h2, none
  }
  ```

  with helper:

  ```swift
  var seconds: TimeInterval? {
      switch self {
      case .m15: return 15 * 60
      case .m30: return 30 * 60
      case .m60: return 60 * 60
      case .h2:  return 2 * 60 * 60
      case .h24: return 24 * 60 * 60
      case .none: return nil
      }
  }
  ```

- **`isUnlockWindowActive`**  
  - Computed as “we are between gate completion and the next lock time”:  
    returns `true` when `nextLockAt` is in the future **and** the shield is currently inactive (`!isShieldActive`).

- **Used for:**
  - **Root view:** **TabView** when nothing to shield, unlock window active, `skipGateAfterAddingApps` is true, or `userRequestedReadingGate` is false (normal app open). **GateView** only when the user **explicitly asked** for the gate (Home “Read ayah · unlock apps”, simulator gate preview, or tap the shield notification) and `canStartNewGate` is true.
  - **HomeView:** Shows the “Locking in X min” banner while `isUnlockWindowActive` is true and `nextLockAt` is in the future.
  - **ShieldConfigurationExtension:** Reads `tilawa.nextLockAt` and shows either “Apps unlocked · locking again soon” (before `nextLockAt`) or “Read ayah to unlock app” (no scheduled lock).

So: **Unlock window** now means **“apps are currently unlocked until `nextLockAt`”**. Unlock is driven by `removeShield()` on gate completion (apps unlock immediately) plus a relock schedule targeting `nextLockAt`; the extension re-applies the shield in `intervalDidEnd` when that interval ends.

---

## When Do We Lock? (applyShield / startFullDayMonitoring)

Locking means: **store has apps set**, and we intend the system to enforce it. In code that is **`applyShield()`** (and, where used, **`startFullDayMonitoring()`**).

| When | What runs |
|------|-----------|
| **User taps Done** in Settings “Add app” sheet | `applyShield()` then `startFullDayMonitoring()`. We also set **`skipGateAfterAddingApps = true`** so the root stays on **TabView** (no read screen yet); apps are locked. |
| **User opens Tilawa** and **unlock window is expired** | `onAppear` clears `skipGateAfterAddingApps`, calls **`startFullDayMonitoring()`** (re-apply shield). **GateView is not shown** unless they tapped the notification or Home “Read ayah”. |
| **User toggles an app off** in Settings (excluded from shield) | `setAppShieldEnabled(..., enabled: false)` → `applyShield()`. So we update which apps are in the store. |
| **No apps left to shield** | `applyShield()` sets `store.shield.applications = nil` and calls `center.stopMonitoring(...)`. So we effectively unlock and stop monitoring. |

So: **Lock is applied when the user first adds apps (Done in Settings), when they open the app outside the unlock window, or when they change guarded apps.** Relock after 15 minutes happens when the TilawaMonitor extension’s **`intervalDidEnd`** runs (at the end of the “now → now+15 min” schedule), which re-applies the shield from saved tokens.

---

## When Do We Unlock? (remove shield + schedule next lock)

Unlocking means: **user can open guarded apps**. We **clear the store** (`removeShield()`) so the system stops blocking immediately, then schedule a **relock** (activity `tilawa.relock`) for `now + nextSessionDelay`.

| When | What runs |
|------|-----------|
| **User finishes GateView** (reads ayah, taps Continue) | `confirmUnlock()` calls `completeGateAndScheduleNextLock()` (and records the read when surah is available). So: **`removeShield()`** (store cleared, apps unlock), stop all monitoring, then **schedule** `tilawa.relock` so that when the delay expires, the schedule’s interval ends and the TilawaMonitor extension’s **`intervalDidEnd(for: .relock)`** runs to re-apply the shield from App Group–saved tokens → **apps lock again**. |

So: **Unlock is immediate** (store cleared). **Relock is automatic** when the selected delay expires (extension re-applies the shield from App Group–saved tokens).

---

## End-to-End Flow (as implemented today)

1. **First install (no apps to shield)**  
   `hasAppsToShield` is false → root shows **TabView**. User can open Settings, add guarded apps, and tap Done. No locking until they add apps.

2. **User adds apps and taps Done (Settings)**  
   `applyShield()` + `startFullDayMonitoring()` + **`skipGateAfterAddingApps = true`** → store has apps, full-day schedule is active → apps are **locked**. Root stays on **TabView** (no read screen yet).

3. **User opens Tilawa later (outside unlock window, apps already selected)**  
   **TabView** by default. User taps **Read ayah · unlock apps** (or the shield notification) → **`userRequestedReadingGate = true`** → **GateView**. User reads ayah to unlock.

4. **User completes gate**  
   `confirmUnlock()` → `unlockForTenMinutes()`: **`removeShield()`** (store cleared → **apps unlock**), set `unlockExpiry` (15 min), stop all monitoring, start schedule **tilawa.relock** (now → now+15 min). UI shows “Apps unlocked · 15 min remaining.”

5. **~15 minutes later (user may or may not open Tilawa)**  
   The relock schedule’s interval **ends**. The system calls TilawaMonitor’s **`intervalDidEnd(for: tilawa.relock)`**. The extension loads saved tokens from App Group and sets `store.shield.applications` → **apps relock**.

6. **User opens Tilawa again (after 15 minutes)**  
   **TabView**; user taps Read ayah or notification to open **GateView** again.

So: **… → Relock → Open Tilawa → tabs until user explicitly opens the gate → read → 15 min unlock → repeat.**

---

## Summary Table

| Concept | What it is | What actually locks/unlocks apps |
|--------|------------|-----------------------------------|
| **hasAppsToShield** | True when at least one app **or category** is selected and not toggled off | Drives root / gate (category-only picks count) |
| **skipGateAfterAddingApps** | True right after Done on picker | TabView until next `onAppear` clears it |
| **userRequestedReadingGate** | True after Home “Read ayah”, simulator gate button, or shield notification tap | Required (with apps + no unlock window + not skipGate) to show **GateView** |
| **applyShield()** | Puts selected app tokens into the store and saves to App Group | **Locks** (system enforces when schedule is active) |
| **removeShield()** | Clears the store | **Unlocks**; called in `unlockForTenMinutes()` so apps unlock immediately |
| **Unlock window** | `unlockExpiry` in UserDefaults; drives “X min remaining” and shield text | **UI and copy** |
| **DeviceActivity schedules** | Full-day (tilawa.blocking) and relock (tilawa.relock, now→now+15min); TilawaMonitor extension | **Relock**: extension’s `intervalDidEnd` re-applies shield from App Group tokens; **minimum interval 15 min** (5/10 min → `intervalTooShort`) |
| **startFullDayMonitoring()** | applyShield + clearUnlockWindow + startMonitoring(full day); guarded by `authorizationStatus == .approved` | **Locks**; called when user adds apps (Done) and when they open app outside unlock window |
| **unlockForTenMinutes()** | removeShield, setUnlockWindow(900), stopMonitoring, startMonitoring(tilawa.relock, now→now+15min); guarded by `authorizationStatus == .approved` | **Unlock** (store cleared); **relock** when extension’s intervalDidEnd runs |
| **App Group tokens** | `tilawa.shieldApplicationTokens` + `tilawa.shieldCategoryTokens`; selection + excluded apps/categories | Extension re-applies apps **and** categories in `intervalDidEnd` |

---

## Fallback if Extension Doesn’t Run (No Relock After 15 Min)

If the system does not call the TilawaMonitor extension’s **`intervalDidEnd`** when the 15‑minute interval ends (e.g. background/process lifecycle), apps will stay unlocked until the user opens Tilawa again. When they do, `onAppear` runs `startFullDayMonitoring()` (because `!isUnlockWindowActive()`), which re-applies the shield and restarts the full-day schedule. So relock still happens on next app open.

---

## What We Did to Get It Working

Summary of the implementation that makes lock/unlock reliable:

1. **Named store**  
   One **`ManagedSettingsStore(named: "tilawa.shield")`** in both the main app and the TilawaMonitor extension so the same store is enforced and re-applied.

2. **Unlock = remove shield + schedule**  
   On gate completion we **`removeShield()`** first (apps unlock immediately), then start a **relock** schedule (activity `tilawa.relock`) with interval **now → now+15 min**. We do *not* rely on “schedule start in the future”; we use **`intervalDidEnd`** in the extension when the short interval ends.

3. **Token persistence (App Group)**  
   The main app saves **`tilawa.shieldApplicationTokens`** (the app tokens to shield) to **`UserDefaults(suiteName: "group.com.tilawa.app")`** in `applyShield()`. The extension reads that in **`intervalDidEnd`** and sets **`store.shield.applications`** so relock works. Selection and excluded tokens are also persisted so they survive restarts.

4. **Schedule minimum**  
   **`DeviceActivitySchedule`** rejects intervals that are too short (5 and 10 minutes throw **`intervalTooShort`**). We use **15 minutes** for the unlock window.

5. **Authorization check**  
   Before **`startMonitoring`** we check **`AuthorizationCenter.shared.authorizationStatus == .approved`** so we don’t start schedules when Screen Time isn’t approved.

6. **Extension logging**  
   TilawaMonitor uses **`os_log` / `Logger`** (subsystem `com.tilawa.monitor`) so we can see **`intervalDidEnd`** and **`reapplyShield`** in Console.app when the extension runs.

7. **No read screen right after adding apps**  
   When the user taps Done after selecting apps we set **`skipGateAfterAddingApps = true`** so the root stays on TabView (timer is set, apps are locked, but we don’t show the gate). The gate appears when they open the app again; **`onAppear`** clears the flag.

8. **Unlock button always unlocks**  
   **`confirmUnlock()`** always calls **`unlockForTenMinutes()`**; we only call **`recordRead`** when a surah is available. That way the button always triggers unlock even if the Quran chunk didn’t load.
