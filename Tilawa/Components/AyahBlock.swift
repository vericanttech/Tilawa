import SwiftUI

struct AyahBlock: View {
    let verse: Verse
    var showTransliteration: Bool = true

    private var ayahFont: Font { Font.custom("Lateef-Regular", size: 42) }
    private var translitFont: Font { Font.custom("CormorantGaramond-Italic", size: 22) }

    var body: some View {
        VStack(alignment: .center, spacing: DesignTokens.spacingS) {
            Text("\(verse.id)")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.gold)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(DesignTokens.gold.opacity(0.4), lineWidth: 1))
                .padding(.bottom, DesignTokens.spacingS)

            Text(verse.text)
                .font(ayahFont)
                .foregroundColor(DesignTokens.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(20)
                .environment(\.layoutDirection, .rightToLeft)

            if showTransliteration {
                Text(verse.transliteration)
                    .font(translitFont)
                    .foregroundColor(DesignTokens.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
        }
    }
}
