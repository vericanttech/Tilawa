# Tilawa — Design Spec

## Design Principles
1. The Quran text is sacred — it lives in its own visual world, never mixed with app UI
2. Every screen uses the same two-material system: parchment and dark chrome
3. Minimal chrome — the fewer UI elements, the more the ayah breathes
4. Gold is the only accent color — used sparingly for active states and highlights

---

## Color Tokens

```swift
// Parchment world
let parchment       = Color(hex: "#F5EDD8")  // base surface
let parchmentDark   = Color(hex: "#EAD9B2")  // subtle depth
let ink             = Color(hex: "#1E1408")  // primary text on parchment
let inkMid          = Color(hex: "#4A3520")  // secondary text on parchment
let inkLight        = Color(hex: "#7A5C35")  // tertiary / transliteration

// Chrome world
let chromeBg        = Color(hex: "#2A1F0F")  // main background
let chromeCard      = Color(hex: "#332613")  // card surface
let chromeCard2     = Color(hex: "#3A2C18")  // card hover/selected
let chromeBorder    = Color(hex: "#B8860B").opacity(0.18)
let chromeText      = Color(hex: "#C8A86A")  // primary text on chrome
let chromeMuted     = Color(hex: "#7A6040")  // secondary text on chrome

// Accent
let gold            = Color(hex: "#B8860B")
let goldLight       = Color(hex: "#D4A843")
let goldPale        = Color(hex: "#F0D898")
```

---

## Typography

```swift
// Arabic text — Quran only
// Font: Lateef or Amiri (bundle both, fallback)
let ayahFont        = Font.custom("Lateef-Regular", size: 34)    // gate screen
let ayahFontSmall   = Font.custom("Lateef-Regular", size: 22)    // home preview
let surahNameArabic = Font.custom("Lateef-Regular", size: 28)    // surah card

// Latin text — UI chrome
// Font: Cormorant Garamond
let displayFont     = Font.custom("CormorantGaramond-Regular", size: 26)
let bodyFont        = Font.custom("CormorantGaramond-Regular", size: 16)
let translitFont    = Font.custom("CormorantGaramond-Italic", size: 15)
let labelFont       = Font.custom("CormorantGaramond-Regular", size: 14)
let capsFont        = Font.custom("CormorantGaramond-Regular", size: 11)
// capsFont always used with .tracking(3) and .textCase(.uppercase)
```

**Font files to bundle in Xcode:**
- `Lateef-Regular.ttf` — Google Fonts (open license)
- `Amiri-Regular.ttf` — Google Fonts (fallback Arabic)
- `CormorantGaramond-Regular.ttf`
- `CormorantGaramond-Italic.ttf`
- `CormorantGaramond-Medium.ttf`

---

## Spacing & Radius

```swift
let radiusSm   = 4.0
let radiusMd   = 8.0  // default card
let radiusLg   = 10.0
let radiusXl   = 12.0 // surah hero card
let radiusFull = 999.0 // pills, toggles

let spacingXs  = 4.0
let spacingS   = 8.0
let spacingM   = 12.0
let spacingL   = 16.0
let spacingXl  = 20.0
let spacing2xl = 24.0
let spacing3xl = 32.0
let spacing4xl = 48.0
```

---

## Screen 1 — Gate Screen

**Layout:** Two zones, stacked vertically. No navigation bar.

### Parchment Zone (flex: fills available space)
- Background: `parchment` with subtle horizontal line texture
- Bottom edge: 1px gold gradient rule
- Bottom padding: 40px, top padding: 48px, horizontal: 32px

**Surah header**
- Text: surah name in English (e.g. "Surah Ya-Sin")
- Style: `capsFont`, tracking 0.2em, color: `gold`
- Margin bottom: 36px

**Per ayah block** (repeated for each ayah in chunk)
- Separator between ayahs: 1px `gold.opacity(0.2)` with 32px vertical margin

  **Ayah number badge**
  - Size: 22×22px circle
  - Border: 1px `gold.opacity(0.4)`
  - Text: ayah number, 10px, color `gold`
  - Margin bottom: 14px

  **Arabic text**
  - Font: `ayahFont` (Lateef 34px)
  - Color: `ink`
  - Direction: RTL, center aligned
  - Line height: 2.0
  - Margin bottom: 12px

  **Transliteration**
  - Font: `translitFont` (Cormorant Italic 15px)
  - Color: `inkLight`
  - Center aligned
  - Line height: 1.6

### Chrome Zone (fixed height: ~180px)
- Background: `chromeBg`
- Top edge: 1px `chromeBorder` rule
- Padding: 20px top, 24px horizontal, 28px bottom

**App label row** (top of chrome zone)
- Left: app icon (38×38px, system app icon if available, else colored initial) + app name in `capsFont` `chromeMuted`
- Right: timer counter "0 / 18s" in `capsFont` `chromeMuted`

**Timer bar**
- Height: 2px
- Track: `white.opacity(0.08)`
- Fill: gradient `gold` → `goldPale`, animates width
- Border radius: 1px

**Unlock button**
- Width: full, height: 52px, border radius: `radiusSm`
- Waiting state: transparent bg, border `white.opacity(0.07)`, text `white.opacity(0.15)`, label "Reading..."
- Ready state: bg `gold`, border `goldLight`, text `ink` weight medium, label "Continue to app ↗"
- Ready state: pulsing glow animation `gold.opacity(0.35)` → `gold.opacity(0.55)`, 2.5s loop

**Streak row**
- 3 items: Ayahs read / Day streak / Today
- Separated by 1px `white.opacity(0.06)` vertical rules
- Number: 20px `chromeText`, label: `capsFont` `chromeMuted`

---

## Screen 2 — Home / Dashboard

**Layout:** Dark chrome throughout. Navigation bar hidden. ScrollView.

### Top bar
- Left: wordmark "Tilawa" in 18px `chromeText` (with gold accent on last 2 chars)
- Right: settings gear button, 32×32px circle, border `chromeBorder`

### Surah hero card (parchment island)
- Background: `parchment`, border radius: `radiusXl`, margin: 20px horizontal
- Subtle line texture overlay

  **Card top row**
  - Left stack: eyebrow "Current surah" in `capsFont` `gold`, surah name in 26px `ink`, Arabic name in `surahNameArabic` `inkMid`
  - Right: "Change" pill button — `gold` text, `gold.opacity(0.1)` bg, `gold.opacity(0.25)` border

  **Progress bar**
  - Label row: "Progress" in 12px `inkLight` — "34 of 83 ayahs" in 12px `inkMid`
  - Track: 4px height, `gold.opacity(0.15)`, radius 2px
  - Fill: gradient `gold` → `goldLight`

  **Next ayah preview**
  - Top border: 1px `gold.opacity(0.2)`, padding top 16px, margin top 18px
  - Eyebrow: "Up next — ayah 34" in `capsFont` `gold`
  - Arabic: `ayahFontSmall` (22px), color `ink`, RTL right-aligned
  - Transliteration: 13px italic `inkLight`

### Stats row
- 3 equal cards, 12px gap, horizontal padding 20px
- Card: `chromeCard` bg, `chromeBorder`, radius `radiusLg`, padding 16px
- Number: 28px `chromeText` (streak number in `goldLight`)
- Label: `capsFont` `chromeMuted`

### Guarded apps section
- Section header: "Guarded apps" `capsFont` `chromeMuted` + "Manage" button `gold`
- App rows: `chromeCard` bg, `chromeBorder`, radius `radiusLg`, 6px gap
- Each row: 38×38px app icon + name/sub-text + toggle
- Toggle on: `gold` bg, knob `ink`
- Toggle off: `white.opacity(0.08)` bg, knob white

---

## Screen 3 — Setup

**Layout:** Dark chrome. Full screen with top bar + scrollable body.

### Top bar
- Left: "← Back" in `labelFont` `chromeMuted`
- Center: "Setup" in `capsFont` `chromeText`
- Right: "Done" in `labelFont` `gold`

### Surah section
- Section label: "Choose your surah" `capsFont` `chromeMuted`
- Search input: `chromeCard` bg, `chromeBorder`, radius `radiusMd`, 11px padding, `chromeText`

**Surah rows** (scrollable list, max height 340px)
- Default: `chromeCard` bg, `chromeBorder`, radius `radiusLg`
- Hover: `chromeCard2` bg, border opacity 0.35
- Selected: `gold.opacity(0.08)` bg, `gold` border
- Left: number in 11px `chromeMuted`
- Center: English name 15px `chromeText`, meta "83 ayahs · Meccan" 11px italic `chromeMuted`
- Right: Arabic name 20px Lateef `chromeMuted` (selected: `goldLight`)
- Selected indicator: 18×18px gold circle with ✓ in `ink`

### Apps section
- Section label: "Guarded apps" `capsFont` `chromeMuted`
- Uses Apple's native `FamilyActivityPicker` — presented as sheet
- "Add another app..." row: dashed `gold.opacity(0.25)` border, `+` icon, italic `chromeMuted` text

---

## Animations

| Element | Animation |
|---|---|
| Gate screen ayahs | Fade up, 0.7s ease, staggered 0.15s between ayahs |
| Timer bar fill | Linear width transition, 1s intervals |
| Unlock button ready state | Pulsing box-shadow, 2.5s ease-in-out loop |
| Home card sections | Fade up, 0.5s ease, 0.1s stagger |
| Surah selection | Border color transition 0.2s |
| App toggle | Background + knob position 0.25s ease |

---

## Assets to Prepare
- [ ] App icon (Islamic geometric, warm gold on dark brown, no text)
- [ ] Lateef-Regular.ttf
- [ ] Amiri-Regular.ttf
- [ ] CormorantGaramond-Regular.ttf
- [ ] CormorantGaramond-Italic.ttf
- [ ] CormorantGaramond-Medium.ttf
- [ ] tilawa_quran.json (from prepare_quran_data.py)
