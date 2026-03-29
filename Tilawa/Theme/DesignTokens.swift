import SwiftUI

enum DesignTokens {
    // Parchment (gate screen + shared)
    static let parchment = Color(hex: "#F5EDD8")
    static let parchmentDark = Color(hex: "#EAD9B2")
    static let ink = Color(hex: "#1E1408")
    static let inkMid = Color(hex: "#4A3520")
    static let inkLight = Color(hex: "#7A5C35")

    // Chrome — gate screen only (unchanged)
    static let chromeBg = Color(hex: "#2A1F0F")
    static let chromeCard = Color(hex: "#332613")
    static let chromeCard2 = Color(hex: "#3A2C18")
    static let chromeBorder = Color(hex: "#B8860B").opacity(0.18)
    static let chromeText = Color(hex: "#C8A86A")
    static let chromeMuted = Color(hex: "#7A6040")

    // Light theme — home, settings, setup
    static let appBackground = Color(hex: "#FAF4E8")
    static let cardBackground = Color(hex: "#F2E8D0")
    static let cardBackground2 = Color(hex: "#EDE0C4")
    static let cardBorder = Color(hex: "#B8860B").opacity(0.15)
    static let primaryText = Color(hex: "#1E1408")
    static let secondaryText = Color(hex: "#7A5C35")
    static let surahCardBg = Color(hex: "#FFFFFF")
    static let surahCardShadow = Color(hex: "#B8860B").opacity(0.12)
    static let sectionLabel = Color(hex: "#B8860B")
    static let searchBg = Color(hex: "#EDE0C4")
    static let searchText = Color(hex: "#1E1408")
    static let searchPlaceholder = Color(hex: "#7A5C35")
    static let topBarTitle = Color(hex: "#1E1408")
    static let topBarAction = Color(hex: "#B8860B")
    static let topBarBack = Color(hex: "#7A5C35")
    static let toggleOff = Color.black.opacity(0.1)

    // Accent
    static let gold = Color(hex: "#B8860B")
    static let goldLight = Color(hex: "#D4A843")
    static let goldPale = Color(hex: "#F0D898")

    // Danger (reset, destructive)
    static let danger = Color(hex: "#D4714A")
    static let dangerBg = Color(red: 139/255, green: 58/255, blue: 26/255, opacity: 0.2)
    static let dangerBorder = Color(red: 139/255, green: 58/255, blue: 26/255, opacity: 0.3)

    // Radius
    static let radiusSm: CGFloat = 4
    static let radiusMd: CGFloat = 8
    static let radiusLg: CGFloat = 10
    static let radiusXl: CGFloat = 12
    static let radiusFull: CGFloat = 999

    // Spacing
    static let spacingXs: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXl: CGFloat = 20
    static let spacing2xl: CGFloat = 24
    static let spacing3xl: CGFloat = 32
    static let spacing4xl: CGFloat = 48
}
