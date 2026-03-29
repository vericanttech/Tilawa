# Tilawa

A native iOS app that gates access to selected apps behind a Quran reading moment. When you open a guarded app (e.g. Instagram), you first read a chunk of your chosen surah — Arabic + transliteration — and wait for the reading timer. Then the app unlocks. Progress is tracked: streak, total ayahs read, position through the surah.

## Requirements

- **Xcode 15+** (tested with **Xcode 16.4**)
- iOS 16.0+
- **Apple Developer account** (Family Controls capability requires it)
- Physical device (Screen Time APIs don’t work in Simulator)

## Quick start

### 1. Quran data (already done)

`tilawa_quran.json` is in `Tilawa/Resources/`. To regenerate:

```bash
curl -o quran_transliteration.json \
  https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran_transliteration.json
python3 prepare_quran_data.py
# then replace Tilawa/Resources/tilawa_quran.json
```

### 2. Open in Xcode (16.4)

1. Open `Tilawa.xcodeproj` in Xcode (double‑click or **File → Open**).
2. In the project navigator (left sidebar), select the **Tilawa** project (blue icon), then the **Tilawa** target.
3. Open the **Signing & Capabilities** tab. Choose your **Team**; Xcode will use the existing **Family Controls** entitlement. If you see a capability error, click **+ Capability** and add **Family Controls**.
4. Select the **ShieldConfigurationExtension** target and repeat: same **Team**, ensure **Family Controls** is present (the extension’s entitlements file already includes it).
5. **Product → Build** (⌘B) to confirm the project compiles.

### 3. Fonts (optional but recommended)

In Xcode 16.4: select the **Tilawa** target → **Build Phases** → **Copy Bundle Resources**. Drag the font files into that list (or click **+** and add them). The **Info.plist** already lists them under **UIAppFonts**.

**Where to get the font files:**

| Font | Source | Direct download (GitHub) |
|------|--------|---------------------------|
| **Lateef-Regular.ttf** | [Google Fonts → Lateef](https://fonts.google.com/specimen/Lateef) | `https://raw.githubusercontent.com/google/fonts/main/ofl/lateef/Lateef-Regular.ttf` |
| **Amiri-Regular.ttf** | [Google Fonts → Amiri](https://fonts.google.com/specimen/Amiri) | `https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf` |
| **Cormorant Garamond** (Regular, Italic, Medium) | [Google Fonts → Cormorant Garamond](https://fonts.google.com/specimen/Cormorant+Garamond) | Use **“Download family”** on the Google Fonts page; the zip includes static TTFs. Or browse [google/fonts ofl/cormorantgaramond](https://github.com/google/fonts/tree/main/ofl/cormorantgaramond) (variable fonts; filenames differ). |

**Quick download (Lateef + Amiri) into the project folder:**

```bash
cd /path/to/Tilawa
curl -L -o Tilawa/Resources/Lateef-Regular.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/lateef/Lateef-Regular.ttf"
curl -L -o Tilawa/Resources/Amiri-Regular.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf"
```

Then add **Cormorant Garamond** by downloading the family from [Google Fonts](https://fonts.google.com/specimen/Cormorant+Garamond) (click “Download family”), unzip, and copy `CormorantGaramond-Regular.ttf`, `CormorantGaramond-Italic.ttf`, and `CormorantGaramond-Medium.ttf` into `Tilawa/Resources/`. In Xcode, add all five `.ttf` files to **Copy Bundle Resources**.

If you don’t add the fonts, the app will fall back to system fonts (Arabic may look different).

### 4. Run on device or Simulator

- **Simulator (preview only):** Choose **iPhone 16** (or any iPhone) in the scheme dropdown and press **Product → Run** (⌘R). You’ll see Home and Setup; use **“View gate screen”** at the bottom of Home to open the gate UI. Guarded apps and Family Controls don’t work in Simulator.
- **Device (full behavior):** Connect a physical iPhone, select it in the scheme, then Run. Grant Screen Time when prompted; you can then pick a surah and guarded apps.

## Flow

1. **First launch** → Setup (choose surah + guarded apps).
2. **Home** → Current surah, progress, stats, guarded-apps toggle.
3. **Opening a guarded app** → System shield appears → tap **Open Tilawa** → app opens on the **Gate** screen (ayah chunk + timer) → when the timer finishes, tap **Continue to app** → app unblocks for ~30 seconds, then blocks again.

## URL scheme

The app registers `tilawa://unlock` so the shield’s “Open Tilawa” button can open the app directly to the Gate screen. Configure the shield extension if your setup requires a custom URL.

## Project layout

- `Tilawa/` — main app (SwiftUI, models, services, views, components, theme, resources).
- `ShieldConfigurationExtension/` — custom shield UI when a guarded app is tapped.
- `prepare_quran_data.py` — builds `tilawa_quran.json` from [quran-json](https://github.com/risan/quran-json).

## Roadmap

See [ROADMAP.md](ROADMAP.md) and [BUILD_PROMPT.md](BUILD_PROMPT.md) for the full build plan and algorithm details.
