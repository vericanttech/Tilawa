Here's the full refined prompt covering everything discussed today:

```
## Tilawa — Full Revision Prompt

Apply all of the following changes across the entire app.
Work through each section in order. Do not skip any section.

---

## 1. Color system — switch to light theme

Update Theme.swift with these tokens. The app is now light/warm
throughout. Only GateView stays dark.

  // BACKGROUNDS
  static let appBackground     = Color(hex: "#FAF4E8")
  static let cardBackground    = Color(hex: "#F2E8D0")
  static let cardBackground2   = Color(hex: "#EDE0C4")
  static let cardBorder        = Color(hex: "#B8860B").opacity(0.15)

  // TEXT
  static let primaryText       = Color(hex: "#1E1408")
  static let secondaryText     = Color(hex: "#7A5C35")

  // SURAH HERO CARD — white surface lifts off parchment bg
  static let surahCardBg       = Color(hex: "#FFFFFF")
  static let surahCardShadow   = Color(hex: "#B8860B").opacity(0.12)

  // SECTION LABELS
  static let sectionLabel      = Color(hex: "#B8860B")

  // SEARCH FIELD
  static let searchBg          = Color(hex: "#EDE0C4")
  static let searchText        = Color(hex: "#1E1408")
  static let searchPlaceholder = Color(hex: "#7A5C35")

  // TOP BAR
  static let topBarTitle       = Color(hex: "#1E1408")
  static let topBarAction      = Color(hex: "#B8860B")
  static let topBarBack        = Color(hex: "#7A5C35")

  // TOGGLES
  static let toggleOff         = Color.black.opacity(0.1)
  static let toggleOn          = Color(hex: "#B8860B")

  // GATE SCREEN — unchanged, keep all existing chrome tokens
  static let chromeBg          = Color(hex: "#2A1F0F")
  static let chromeCard        = Color(hex: "#332613")
  static let chromeText        = Color(hex: "#C8A86A")
  static let chromeMuted       = Color(hex: "#7A6040")
  static let chromeBorder      = Color(hex: "#B8860B").opacity(0.18)

Apply light theme tokens to: HomeView, SetupView, SettingsView.
GateView keeps all existing dark chrome tokens — do not touch it.

---

## 2. Bottom navigation — replace gear button and Change button

Remove the gear button from HomeView top bar entirely.
Remove the "Change" button from the surah card entirely.
Remove the "Manage" button from the guarded apps section entirely.
The HomeView top bar now shows the wordmark only — nothing else.

Add a TabView in TilawaApp.swift wrapping all three main screens:

  TabView {
      HomeView()
          .tabItem {
              Label("Home", systemImage: "book.pages")
          }
      SetupView()
          .tabItem {
              Label("Surah", systemImage: "moon.stars")
          }
      SettingsView()
          .tabItem {
              Label("Settings", systemImage: "gearshape")
          }
  }

Tab bar styling — apply via UIAppearance in TilawaApp init():

  UITabBar.appearance().backgroundColor =
      UIColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1.0)
  UITabBar.appearance().unselectedItemTintColor =
      UIColor(red: 0.47, green: 0.36, blue: 0.21, alpha: 1.0)

Active tab tint: Color(hex: "#B8860B") set via .tint() on TabView.

GateView is presented as .fullScreenCover — it sits above the
TabView entirely. The tab bar must NOT be visible on GateView.

---

## 3. HomeView — read only dashboard

HomeView is now a pure glance screen. Nothing navigates away from it.

Top bar:
  - Wordmark "Tilawa" only — last 2 chars in gold #B8860B
  - No gear button, no trailing items
  - Background: appBackground #FAF4E8

Surah hero card:
  - Background: white #FFFFFF
  - Corner radius: 12px
  - Shadow: color #B8860B opacity 0.12, radius 12, x 0, y 4
  - No "Change" button — card is fully read only
  - Content: surah name, Arabic name, progress bar, next ayah preview

Stats row — fix equal height issue:
  All three StatCards must be identical height.
  Rename "Ayahs Read" label to "Ayahs" — one word, never wraps.
  Inside StatCard:
    VStack(spacing: 4) {
        Text(number)
        Text(label)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 88)
    .background(cardBackground)
    .cornerRadius(10)
    .overlay(
        RoundedRectangle(cornerRadius: 10)
            .stroke(cardBorder, lineWidth: 1)
    )

Guarded apps section:
  - Section header: "Guarded apps" label only — no "Manage" button
  - Show app name, icon, "Opened N× today"
  - Toggles remain interactive (enable/disable guarded app)
  - Tapping a toggle calls ShieldService.applyShield or removeShield

---

## 4. SetupView — surah tab, no navigation chrome

SetupView is now a top-level tab. Remove all navigation chrome.
  - No Back button
  - No Done button
  - No "Setup" title in a nav bar

Replace with a simple page header at the top:
  VStack(alignment: .leading, spacing: 6) {
      Text("Your Surah")
          .font(.custom("CormorantGaramond-Regular", size: 22))
          .foregroundColor(primaryText)
      Text("Choose the surah you want to read through")
          .font(.custom("CormorantGaramond-Italic", size: 14))
          .foregroundColor(secondaryText)
  }
  .padding(.horizontal, 24)
  .padding(.top, 24)
  .padding(.bottom, 16)

Selecting a surah saves immediately to AppState —
no Done button needed. currentChunkIndex resets to 0 on change.

Search field — exact visual spec:
  DO NOT use .searchable or default TextField styling.
  Use this exact modifier stack:

  TextField("Search surahs...", text: $searchQuery)
      .font(.custom("CormorantGaramond-Regular", size: 15))
      .foregroundColor(Color(hex: "#1E1408"))
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
      .background(Color(hex: "#EDE0C4"))
      .cornerRadius(8)
      .overlay(
          RoundedRectangle(cornerRadius: 8)
              .stroke(
                  isFocused
                      ? Color(hex: "#B8860B").opacity(0.45)
                      : Color(hex: "#B8860B").opacity(0.18),
                  lineWidth: 1
              )
      )
      .accentColor(Color(hex: "#B8860B"))

  Track focus with @FocusState for border opacity transition.

---

## 5. SettingsView — settings tab, no navigation chrome

SettingsView is now a top-level tab. Remove all navigation chrome.
  - No Back button
  - No "Settings" title in a nav bar

Replace with a simple page header:
  Text("Settings")
      .font(.custom("CormorantGaramond-Regular", size: 22))
      .foregroundColor(primaryText)
      .padding(.horizontal, 24)
      .padding(.top, 24)
      .padding(.bottom, 16)

Remove the Account section entirely:
  - Remove "Restore purchase" row
  - Remove "Daily reminder" row
  - Remove the Account section label

Move "Restore purchase" to the About card as a plain text button:
  Button("Restore purchase") {
      Task { try? await AppStore.sync() }
  }
  .font(.custom("CormorantGaramond-Regular", size: 13))
  .foregroundColor(Color(hex: "#B8860B"))

Guarded apps section — "Add an app" row:
  Tapping presents a bottom sheet (not a popup, not an alert).
  The bottom sheet contains Apple's native FamilyActivityPicker.
  Bottom sheet styling:
    - Background: appBackground #FAF4E8
    - Drag handle at top
    - Title "Choose apps to guard" in capsFont primaryText
    - FamilyActivityPicker below title
  On selection confirm: update ShieldService.selection,
  call ShieldService.applyShield(), dismiss sheet.

---

## 6. Change button visual spec (surah card — for any remaining 
## instances elsewhere)

If a "Change" style pill button is used anywhere in the app,
it must look exactly like this — never use default SwiftUI styling:

  Button("Change") { }
      .font(.custom("CormorantGaramond-Regular", size: 11))
      .tracking(4)
      .textCase(.uppercase)
      .foregroundColor(Color(hex: "#B8860B"))
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(Capsule().fill(Color(hex: "#B8860B").opacity(0.1)))
      .overlay(
          Capsule().stroke(
              Color(hex: "#B8860B").opacity(0.25),
              lineWidth: 1
          )
      )

---

## 7. Safe area and scrolling — all screens

All screens must respect the safe area. Rules:

  - DO NOT use .ignoresSafeArea() on HomeView, SetupView,
    or SettingsView
  - Only GateView may use .ignoresSafeArea() and only on the
    background layer, never on the content layer
  - Page headers are always fixed — they are siblings of the
    ScrollView inside a VStack, never inside the ScrollView
  - The correct structure for every screen:

    VStack(spacing: 0) {
        // FIXED — never scrolls
        pageHeaderOrTopBar
            .background(appBackground)

        Divider()
            .background(Color(hex: "#B8860B").opacity(0.15))

        // SCROLLABLE — only this moves
        ScrollView {
            VStack(spacing: 0) {
                // all content
            }
            .padding(.bottom, 32)
        }
    }
    .background(appBackground)

  DO NOT put the header inside the ScrollView.
  DO NOT use NavigationView or .toolbar for header management.

---

## 8. GateView — fixed layout, surah header pinned, ayahs scroll

GateView has three fixed layers. Nothing except the ayah content
scrolls. Structure:

  ZStack {
      // Background layer — bleeds edge to edge
      VStack(spacing: 0) {
          Color(hex: "#F5EDD8")
          Color(hex: "#2A1F0F").frame(height: 180)
      }
      .ignoresSafeArea()

      // Content layer — respects safe area
      VStack(spacing: 0) {

          // 1. SURAH HEADER — pinned, never scrolls
          Text(surahName)
              .font(.custom("CormorantGaramond-Regular", size: 12))
              .tracking(6)
              .textCase(.uppercase)
              .foregroundColor(Color(hex: "#B8860B"))
              .padding(.top, 20)
              .padding(.bottom, 16)
              .frame(maxWidth: .infinity)
              .background(Color(hex: "#F5EDD8"))

          // Gold rule below header
          LinearGradient(
              colors: [.clear, Color(hex: "#B8860B").opacity(0.4), .clear],
              startPoint: .leading, endPoint: .trailing
          )
          .frame(height: 1)

          // 2. AYAH CONTENT — scrollable
          ScrollView(.vertical, showsIndicators: false) {
              VStack(spacing: 0) {
                  ForEach(currentChunk.verses) { verse in
                      AyahBlock(verse: verse)
                  }
              }
              .padding(.horizontal, 32)
              .padding(.top, 32)
              .padding(.bottom, 32)
          }
          .frame(maxWidth: .infinity)
          .background(Color(hex: "#F5EDD8"))

          // Gold rule above chrome
          LinearGradient(
              colors: [.clear, Color(hex: "#B8860B").opacity(0.4), .clear],
              startPoint: .leading, endPoint: .trailing
          )
          .frame(height: 1)

          // 3. CHROME ZONE — fixed, never scrolls
          VStack(spacing: 16) {
              appLabelAndTimer
              timerBar
              unlockButton
              streakRow
          }
          .padding(.horizontal, 24)
          .padding(.top, 20)
          .padding(.bottom, 20)
          .background(Color(hex: "#2A1F0F"))
      }
      // DO NOT add .ignoresSafeArea() to content VStack
  }

Do not use .scrollBounceBehavior() — not available in iOS 16.0.
Default ScrollView bounce behavior is acceptable.
Deployment target is iOS 16.0. Before using any SwiftUI modifier
verify it is available in iOS 16.0 — if unsure, do not use it.

---

## 9. Shield screen — ShieldConfigurationExtension

The shield is what iOS shows when a blocked app is tapped.
No buttons — the shield instructs the user to tap the notification.

  override func configuration(
      shielding application: Application
  ) -> ShieldConfiguration {
      ShieldConfiguration(
          backgroundBlurStyle: nil,
          backgroundColor: UIColor(
              red: 0.98, green: 0.96, blue: 0.91, alpha: 1.0
          ),
          icon: UIImage(named: "AppIcon"),
          title: ShieldConfiguration.Label(
              text: "Tilawa",
              color: UIColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 1.0)
          ),
          subtitle: ShieldConfiguration.Label(
              text: "Tap the notification to read your ayah",
              color: UIColor(red: 0.47, green: 0.36, blue: 0.21, alpha: 1.0)
          ),
          primaryButtonLabel: nil,
          primaryButtonBackgroundColor: nil,
          secondaryButtonLabel: nil
      )
  }

Fallback — if user denied notification permission:
  Check App Group UserDefaults for key "notificationsGranted".
  If false, show primary button instead:
    primaryButtonLabel: ShieldConfiguration.Label(
        text: "Open Tilawa",
        color: UIColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 1.0)
    )
    primaryButtonBackgroundColor: UIColor(
        red: 0.72, green: 0.53, blue: 0.07, alpha: 1.0
    )

---

## 10. Permissions and first launch

On first launch, request permissions in this order:
  1. Notification permission first
  2. FamilyControls authorization second

Notification request:
  UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound]
  ) { granted, _ in
      UserDefaults(suiteName: "group.com.tilawa.app")?
          .set(granted, forKey: "notificationsGranted")
  }

Notification content when shield fires:
  content.title = "Tilawa"
  content.body = "Your ayah is waiting · tap to read"
  content.sound = nil

App Group identifier: group.com.tilawa.app
Add App Groups capability to both Tilawa main target
and TilawaMonitor extension target.

---

## Done state

- App is warm parchment throughout except GateView
- TabView visible on all three main screens with gold active tint
- GateView presents as .fullScreenCover — tab bar not visible
- HomeView is pure dashboard — no navigation buttons
- SetupView and SettingsView are top-level tabs with page titles
- Search field in SetupView is dark parchment, never white
- All page headers are pinned — only content scrolls
- GateView surah header pinned, ayah content scrolls, chrome fixed
- Stats row has equal height cards, "Ayahs" label never wraps
- Shield screen shows parchment background with notification CTA
- Notification fires silently when apps are blocked
- All code compiles on iOS 16.0 deployment target with no warnings
```