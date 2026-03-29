# Tilawa — Build Roadmap & Algorithm Spec

## Overview
Tilawa is a native iOS app that gates access to selected apps behind a Quran reading moment. Every time the user opens a guarded app, they read one chunk of their chosen surah before the app unlocks. Progress is tracked globally across all guarded apps.

---

## Phase 0 — Data Preparation (before Xcode)
- [ ] Download `quran_with_transliteration.json` from quran-json npm package
- [ ] Run `prepare_quran_data.py` to produce `tilawa_quran.json`
- [ ] Verify output: 114 surahs, word counts, duration estimates, chunks pre-computed
- [ ] Add `tilawa_quran.json` to Xcode project under `Resources/`

---

## Phase 1 — Core App Shell
- [ ] New Xcode project, SwiftUI, iOS 16+ minimum
- [ ] Add `FamilyControls` entitlement (requires Apple developer account, special capability)
- [ ] Request `FamilyControls` authorization on first launch
- [ ] Set up local persistence with `UserDefaults` + a simple `AppState` model
- [ ] Load and parse `tilawa_quran.json` into Swift models at launch

**Swift models:**
```swift
struct Surah: Codable, Identifiable {
    let id: Int
    let name: String
    let transliteration: String
    let nameArabic: String
    let type: String
    let totalVerses: Int
    let verses: [Verse]
    let chunks: [Chunk]
}

struct Verse: Codable, Identifiable {
    let id: Int
    let text: String
    let transliteration: String
    let wordCount: Int
    let durationSeconds: Int
}

struct Chunk: Codable {
    let ayahIds: [Int]
    let durationSeconds: Int
}

// Persisted in UserDefaults
struct AppState: Codable {
    var selectedSurahId: Int        // default: 36 (Ya-Sin)
    var currentChunkIndex: Int      // which chunk we're on in the surah
    var totalAyahsRead: Int
    var todayAyahsRead: Int
    var lastReadDate: Date?
    var streakDays: Int
    var guardedApps: [String]       // bundle identifiers
}
```

---

## Phase 2 — Screen Time Integration
This is the most technically sensitive phase. Take it step by step.

### Step 1 — Request authorization
```swift
import FamilyControls

// In your onboarding / setup flow:
let center = AuthorizationCenter.shared
try await center.requestAuthorization(for: .individual)
```
Authorization must be requested in foreground. If denied, app explains why it needs it.

### Step 2 — Select apps to guard (Setup screen)
```swift
import FamilyControls
import ManagedSettings

// Present the native Apple app picker:
@State var selection = FamilyActivitySelection()
@State var showPicker = false

.familyActivityPicker(isPresented: $showPicker, selection: $selection)
```
Apple's native picker handles app selection — you don't need to display app icons yourself. Save the resulting `FamilyActivitySelection` to UserDefaults encoded as JSON.

### Step 3 — Block the guarded apps
```swift
import ManagedSettings

let store = ManagedSettingsStore()

func applyRestrictions(selection: FamilyActivitySelection) {
    store.shield.applications = selection.applicationTokens
}

func removeRestrictions() {
    store.shield.applications = nil
}
```

### Step 4 — Custom shield (the gate screen)
When a blocked app is tapped, iOS shows a shield. You customize it:
- Create a `ShieldConfigurationExtension` target in Xcode
- Return your custom `ShieldConfiguration` with parchment background, app name
- The shield has a primary button — "Read today's ayah" — which deep-links into Tilawa

### Step 5 — The unlock flow
1. User taps "Read today's ayah" on the shield
2. iOS opens Tilawa via URL scheme (`tilawa://unlock?app=com.instagram.ios`)
3. Tilawa presents the gate screen (ayah chunk + timer)
4. Timer completes → user taps Continue → Tilawa calls `removeRestrictions()`
5. User goes back to the app — it opens because the block is lifted
6. After N seconds (30s), Tilawa re-applies restrictions in background

**The re-lock timer:**
```swift
// After unlocking, schedule re-lock
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    applyRestrictions(selection: savedSelection)
}
```
30 seconds gives enough time to return to the app before it re-locks.

---

## Phase 3 — Gate Screen
- [ ] Full-screen SwiftUI view
- [ ] Parchment zone: display current chunk ayahs (Arabic + transliteration)
- [ ] Dark chrome zone: app icon, timer bar, unlock button, streak stats
- [ ] Timer counts up from 0 to `chunk.durationSeconds`
- [ ] Unlock button activates when timer completes
- [ ] On unlock: advance `currentChunkIndex`, update stats, call `removeRestrictions()`
- [ ] Loop chunk index back to 0 when surah is complete

**Chunk progression algorithm:**
```swift
func advanceChunk(state: inout AppState, surah: Surah) {
    let ayahsInChunk = surah.chunks[state.currentChunkIndex].ayahIds.count
    state.totalAyahsRead += ayahsInChunk
    state.todayAyahsRead += ayahsInChunk
    state.currentChunkIndex += 1

    // Loop when surah complete
    if state.currentChunkIndex >= surah.chunks.count {
        state.currentChunkIndex = 0
    }

    updateStreak(state: &state)
    saveState(state)
}

func updateStreak(state: inout AppState) {
    let today = Calendar.current.startOfDay(for: Date())
    if let last = state.lastReadDate {
        let lastDay = Calendar.current.startOfDay(for: last)
        let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if diff == 1 { state.streakDays += 1 }
        else if diff > 1 { state.streakDays = 1 }
        // diff == 0 means same day, streak unchanged
    } else {
        state.streakDays = 1
    }
    state.lastReadDate = Date()
}
```

---

## Phase 4 — Home Screen
- [ ] Parchment surah card: name, Arabic name, progress bar, next chunk preview
- [ ] Stats row: streak, total ayahs, today count
- [ ] Guarded apps list with toggle (calls `applyRestrictions` / `removeRestrictions`)
- [ ] "Change" button → Setup screen
- [ ] "Manage" button → Setup screen apps section

---

## Phase 5 — Setup Screen
- [ ] Surah list: scrollable, searchable by name
- [ ] Each row: number, English name, Arabic name, ayah count, Meccan/Medinan
- [ ] Selecting a surah resets `currentChunkIndex` to 0 (new journey begins)
- [ ] Guarded apps section uses Apple's `familyActivityPicker`
- [ ] Done button saves and returns to home

---

## Phase 6 — Polish & Edge Cases
- [ ] First launch: skip home, go straight to Setup
- [ ] Handle `FamilyControls` authorization denied gracefully
- [ ] Handle app backgrounded mid-timer (save timer state, resume on foreground)
- [ ] Daily reset of `todayAyahsRead` at midnight
- [ ] Streak recovery grace period: if user misses one day, streak holds (optional)
- [ ] App icon, launch screen, App Store screenshots

---

## Screen Count: 3
1. Gate screen (shown by system shield trigger)
2. Home / dashboard
3. Setup (surah picker + app selection)

---

## Technical Stack
| Concern | Solution |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| App blocking | FamilyControls + ManagedSettings |
| Shield customization | ShieldConfigurationExtension |
| Data | Local JSON bundle (tilawa_quran.json) |
| Persistence | UserDefaults (no backend needed) |
| Minimum iOS | 16.0 |
| Backend | None |
| Auth | None |
