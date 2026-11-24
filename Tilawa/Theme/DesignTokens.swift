import SwiftUI

/// Calm & modern design system (Tilawa redesign, Nov 2026).
/// Light, airy surfaces; one deep-teal accent; Amiri for Quran text only; SF Pro for UI.
enum DesignTokens {
    // MARK: - Core palette
    static let mist = Color(hex: "#F5F6F2")          // app background
    static let surface = Color(hex: "#FFFFFF")       // cards
    static let surfaceMuted = Color(hex: "#F2F4F3")  // inner wells, icon buttons
    static let track = Color(hex: "#E6EAE8")         // progress tracks, segmented bg
    static let hairline = Color(hex: "#EEF1EF")      // row dividers
    static let outline = Color(hex: "#D5DDDB")       // inactive outlines

    static let ink = Color(hex: "#17262A")           // primary text
    static let inkSoft = Color(hex: "#24363A")       // body copy (translation)
    static let muted = Color(hex: "#56656A")         // secondary text (4.5:1 on mist)
    static let mutedStrong = Color(hex: "#3E4D51")

    static let accent = Color(hex: "#1D6B62")        // deep teal — actions, active states
    static let accentPressed = Color(hex: "#134C45")
    static let accentTint = Color(hex: "#E2EEEA")    // soft teal fills
    static let onAccentTint = Color(hex: "#24413D")

    static let streak = Color(hex: "#9A5B13")        // streak flame (icons, small text)
    static let streakTint = Color(hex: "#F6EBDD")
    static let night = Color(hex: "#17262A")         // dark promo cards

    // Heatmap steps (light → strong)
    static let heat: [Color] = [Color(hex: "#E6EAE8"), Color(hex: "#A8CFC7"), Color(hex: "#5E9F95"), Color(hex: "#1D6B62")]

    // MARK: - Fonts
    static func arabic(_ size: CGFloat) -> Font { .custom("Amiri-Regular", size: size) }
    static let largeTitle = Font.system(size: 30, weight: .bold)
    static let title = Font.system(size: 28, weight: .bold)
    static let headline = Font.system(size: 17, weight: .bold)
    static let body = Font.system(size: 16)
    static let callout = Font.system(size: 15)
    static let caption = Font.system(size: 13)
    static let overline = Font.system(size: 12, weight: .bold)

    // MARK: - Radius
    static let radiusSm: CGFloat = 10
    static let radiusMd: CGFloat = 14
    static let radiusLg: CGFloat = 16
    static let radiusXl: CGFloat = 20
    static let radiusCard: CGFloat = 24
    static let radiusFull: CGFloat = 999

    // MARK: - Spacing
    static let spacingXs: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXl: CGFloat = 20
    static let spacing2xl: CGFloat = 24
    static let spacing3xl: CGFloat = 32
    static let spacing4xl: CGFloat = 48

    // MARK: - Legacy names (mapped onto the new palette so older screens restyle automatically)
    static let parchment = surface
    static let parchmentDark = track
    static let inkMid = mutedStrong
    static let inkLight = muted
    static let chromeBg = night
    static let chromeCard = Color(hex: "#22353A")
    static let chromeCard2 = Color(hex: "#2B4045")
    static let chromeBorder = Color.white.opacity(0.08)
    static let chromeText = Color(hex: "#E2EEEA")
    static let chromeMuted = Color(hex: "#9FB3B0")
    static let appBackground = mist
    static let cardBackground = surface
    static let cardBackground2 = surfaceMuted
    static let cardBorder = hairline
    static let primaryText = ink
    static let secondaryText = muted
    static let surahCardBg = surface
    static let surahCardShadow = Color.black.opacity(0.05)
    static let sectionLabel = accent
    static let searchBg = track
    static let searchText = ink
    static let searchPlaceholder = muted
    static let topBarTitle = ink
    static let topBarAction = accent
    static let topBarBack = muted
    static let toggleOff = Color.black.opacity(0.1)
    static let gold = accent
    static let goldLight = accent
    static let goldPale = accentTint
    static let danger = Color(hex: "#B4432A")
    static let dangerBg = Color(hex: "#B4432A").opacity(0.08)
    static let dangerBorder = Color(hex: "#B4432A").opacity(0.3)
}
