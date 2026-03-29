# Tilawa — Cursor Build Prompt

## What we're building
A native iOS app called **Tilawa** that gates access to selected apps behind a Quran reading moment. When a user tries to open a guarded app (e.g. Instagram), they first read a chunk of their chosen surah — Arabic text + transliteration — and wait for the reading timer to complete. Then the app unlocks. Progress is tracked: streak, total ayahs read, position through the surah.

---

## Technical constraints
- Swift 5.9+, SwiftUI only
- iOS 16.0 minimum deployment target
- FamilyControls entitlement required (add to entitlements file)
- No backend, no auth, no network calls at runtime
- All Quran data from local bundled `tilawa_quran.json`
- Persistence via UserDefaults only
- Fonts bundled locally: Lateef-Regular, Amiri-Regular, CormorantGaramond-Regular, CormorantGaramond-Italic, CormorantGaramond-Medium

---

## Project structure

```
Tilawa/
├── TilawaApp.swift
├── Models/
│   ├── Surah.swift           — Codable structs for Quran data
│   └── AppState.swift        — Persisted user state
├── Services/
│   ├── QuranService.swift    — Load + query tilawa_quran.json
│   ├── ShieldService.swift   — FamilyControls blocking/unblocking
│   └── StatsService.swift    — Streak, ayah count, daily reset
├── Views/
│   ├── GateView.swift        — The ayah gate (shown on unlock flow)
│   ├── HomeView.swift        — Dashboard
│   └── SetupView.swift       — Surah picker + app selection
├── Components/
│   ├── AyahBlock.swift       — Arabic text + transliteration unit
│   ├── TimerBar.swift        — Animated progress bar
│   ├── UnlockButton.swift    — Ghost → gold transition button
│   ├── SurahCard.swift       — Parchment hero card
│   ├── StatCard.swift        — Single stat (number + label)
│   └── AppRow.swift          — Guarded app row with toggle
├── Extensions/
│   └── Color+Hex.swift       — Color(hex:) initializer
├── Resources/
│   └── tilawa_quran.json
└── ShieldConfigurationExtension/
    └── ShieldConfigurationExtension.swift
```

---

## Build this in order — one task at a time

### Task 1 — Project setup
Create the Xcode project with:
- Bundle ID: `com.tilawa.app`
- Add `FamilyControls` capability in Signing & Capabilities
- Add `NSFamilyControlsUsageDescription` to Info.plist: "Tilawa needs this to guard your selected apps with Quran reading."
- Add all font files to Resources and register them in Info.plist under `UIAppFonts`
- Add `tilawa_quran.json` to Resources
- Add `ShieldConfigurationExtension` target

Done state: project builds with no errors, fonts load, JSON file is accessible.

---

### Task 2 — Data models

**Surah.swift:**
```swift
import Foundation

struct Surah: Codable, Identifiable {
    let id: Int
    let name: String
    let transliteration: String
    let nameArabic: String
    let type: String
    let totalVerses: Int
    let verses: [Verse]
    let chunks: [Chunk]

    enum CodingKeys: String, CodingKey {
        case id, name, transliteration, type, verses, chunks
        case nameArabic = "name_arabic"
        case totalVerses = "total_verses"
    }
}

struct Verse: Codable, Identifiable {
    let id: Int
    let text: String
    let transliteration: String
    let wordCount: Int
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id, text, transliteration
        case wordCount = "word_count"
        case durationSeconds = "duration_seconds"
    }
}

struct Chunk: Codable {
    let ayahIds: [Int]
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case ayahIds = "ayah_ids"
        case durationSeconds = "duration_seconds"
    }
}
```

**AppState.swift:**
```swift
import Foundation

struct AppState: Codable {
    var selectedSurahId: Int = 36        // Ya-Sin default
    var currentChunkIndex: Int = 0
    var totalAyahsRead: Int = 0
    var todayAyahsRead: Int = 0
    var lastReadDate: Date? = nil
    var streakDays: Int = 0
    var isFirstLaunch: Bool = true
}
```

Done state: models compile, CodingKeys map correctly to JSON snake_case fields.

---

### Task 3 — QuranService

```swift
// Services/QuranService.swift
// Loads tilawa_quran.json once at launch, provides query methods

class QuranService: ObservableObject {
    static let shared = QuranService()
    private(set) var surahs: [Surah] = []

    func load() { /* decode JSON from bundle */ }
    func surah(id: Int) -> Surah? { /* find by id */ }
    func currentChunk(surahId: Int, chunkIndex: Int) -> (verses: [Verse], duration: Int)? { /* return verses for chunk */ }
    func search(_ query: String) -> [Surah] { /* filter by name */ }
}
```

Done state: can call `QuranService.shared.surah(id: 36)` and get Ya-Sin with all 83 verses and pre-computed chunks.

---

### Task 4 — ShieldService

```swift
// Services/ShieldService.swift
import FamilyControls
import ManagedSettings

class ShieldService: ObservableObject {
    static let shared = ShieldService()
    private let store = ManagedSettingsStore()
    @Published var isAuthorized = false
    @Published var selection = FamilyActivitySelection()

    func requestAuthorization() async { /* AuthorizationCenter.shared.requestAuthorization */ }
    func applyShield() { /* store.shield.applications = selection.applicationTokens */ }
    func removeShield() { /* store.shield.applications = nil */ }
    func scheduleReLock(after seconds: Double = 30) { /* DispatchQueue.main.asyncAfter */ }
    func saveSelection() { /* encode selection to UserDefaults */ }
    func loadSelection() { /* decode selection from UserDefaults */ }
}
```

Done state: calling `applyShield()` blocks selected apps, `removeShield()` unblocks them.

---

### Task 5 — StatsService

```swift
// Services/StatsService.swift

class StatsService {
    static let shared = StatsService()

    func recordRead(ayahCount: Int, state: inout AppState) {
        // Add to totals
        // Update streak (1 day gap = increment, >1 day = reset to 1, same day = no change)
        // Update lastReadDate
        // Advance chunkIndex, loop at surah end
        // Save to UserDefaults
    }

    func resetDailyCountIfNeeded(state: inout AppState) {
        // If lastReadDate is yesterday or earlier, reset todayAyahsRead = 0
    }
}
```

Done state: reading 5 ayahs increments both `totalAyahsRead` and `todayAyahsRead` by 5. Streak increments correctly across days.

---

### Task 6 — GateView

The core screen. Shown when user taps "Read today's ayah" from the shield.

Layout:
- Full screen, no navigation bar, no status bar
- Top: parchment zone (flex height) — surah header, ayah blocks, transliteration
- Bottom: chrome zone (fixed ~180px) — app label, timer bar, unlock button, streak row

Key behaviors:
- On appear: start timer counting up from 0 to `chunk.durationSeconds`
- Timer runs via `Timer.publish(every: 1, on: .main, in: .common)`
- At `elapsed >= chunk.durationSeconds`: unlock button becomes active
- On button tap: call `StatsService.recordRead`, call `ShieldService.removeShield`, call `ShieldService.scheduleReLock`, dismiss view

Design tokens: see DESIGN_SPEC.md
Arabic text direction: `.environment(\.layoutDirection, .rightToLeft)` on Arabic Text views

Done state: gate screen renders with real ayah data, timer counts up, button unlocks at correct time, stats update on confirm.

---

### Task 7 — HomeView

Layout (ScrollView, dark chrome bg):
- Top bar: wordmark + settings button
- Surah card (parchment): name, Arabic name, progress bar, next chunk preview
- Stats row: 3 StatCard components
- Guarded apps section: list of AppRow components with working toggles

Key behaviors:
- "Change" button → navigate to SetupView (surah section focused)
- "Manage" button → navigate to SetupView (apps section focused)
- App toggle calls `ShieldService.applyShield()` / `ShieldService.removeShield()`
- Stats read live from `AppState` via `@StateObject`

Done state: home screen shows real data from AppState and QuranService, toggles work.

---

### Task 8 — SetupView

Layout (ScrollView, dark chrome bg):
- Top bar: Back + "Setup" title + Done
- Section 1: "Choose your surah" — search field + scrollable surah list
- Divider
- Section 2: "Guarded apps" — triggers `FamilyActivityPicker` sheet + app rows

Key behaviors:
- Surah search filters list in real time
- Selecting a surah updates `AppState.selectedSurahId` and resets `currentChunkIndex = 0`
- Currently selected surah highlighted in gold
- "Add another app" row presents `FamilyActivityPicker`
- Done saves state and dismisses

Done state: can pick a surah, see it selected, go back to home and see it reflected in the surah card.

---

### Task 9 — ShieldConfigurationExtension

Create a `ShieldConfigurationExtension` target. Customize the shield that appears when a guarded app is tapped:

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.16, green: 0.12, blue: 0.06, alpha: 0.95),
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "One moment",
                color: UIColor(red: 0.78, green: 0.66, blue: 0.42, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Read today's ayah first",
                color: UIColor(red: 0.47, green: 0.38, blue: 0.25, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Tilawa",
                color: UIColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 1.0)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.72, green: 0.53, blue: 0.07, alpha: 1.0)
        )
    }
}
```

Done state: tapping a blocked app shows the warm dark shield with gold button.

---

### Task 10 — URL scheme + deep link handling

Add URL scheme `tilawa` to Info.plist so the shield's "Open Tilawa" button opens the app directly to GateView:

```swift
// TilawaApp.swift
.onOpenURL { url in
    if url.scheme == "tilawa", url.host == "unlock" {
        showGateView = true
    }
}
```

Done state: tapping "Open Tilawa" on the shield opens Tilawa directly on the gate screen, not the home screen.

---

## What NOT to build in v1
- No user account or login
- No iCloud sync
- No push notifications
- No audio playback
- No tajweed coloring
- No translation (transliteration only)
- No Android version
- No widget
- No Apple Watch app
