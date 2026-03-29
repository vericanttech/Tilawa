import SwiftUI

struct SurahCard: View {
    let surah: Surah
    let progressAyahs: Int
    let nextAyahPreview: Verse?
    var language: Language = .english
    var showTransliteration: Bool = true

    private var surahNameArabic: Font { Font.custom("Lateef-Regular", size: 28) }
    private var ayahFontSmall: Font { Font.custom("Lateef-Regular", size: 26) }
    private var translitFontSmall: Font { Font.custom("CormorantGaramond-Italic", size: 16) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXs) {
                Text(Localization.L("surah_card.current_surah", language))
                    .font(Font.custom("CormorantGaramond-Regular", size: 11))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(DesignTokens.gold)
                Text(surah.name)
                    .font(Font.custom("CormorantGaramond-Regular", size: 26))
                    .foregroundColor(DesignTokens.ink)
                Text(surah.nameArabic)
                    .font(surahNameArabic)
                    .foregroundColor(DesignTokens.inkMid)
                    .environment(\.layoutDirection, .rightToLeft)
            }

            VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                HStack {
                    Text(Localization.L("surah_card.progress", language))
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.inkLight)
                    Spacer()
                    Text(String(format: Localization.L("surah_card.of_ayahs", language), progressAyahs, surah.totalVerses))
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.inkMid)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignTokens.gold.opacity(0.15))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [DesignTokens.gold, DesignTokens.goldLight], startPoint: .leading, endPoint: .trailing))
                            .frame(width: surah.totalVerses > 0 ? geo.size.width * CGFloat(progressAyahs) / CGFloat(surah.totalVerses) : 0, height: 4)
                    }
                }
                .frame(height: 4)
            }

            if let verse = nextAyahPreview {
                VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                    Rectangle()
                        .fill(DesignTokens.gold.opacity(0.2))
                        .frame(height: 1)
                        .padding(.top, DesignTokens.spacingL)
                        .padding(.bottom, DesignTokens.spacingS)

                    Text(String(format: Localization.L("surah_card.up_next_ayah", language), verse.id))
                        .font(Font.custom("CormorantGaramond-Regular", size: 11))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(DesignTokens.gold)

                    Text(verse.text)
                        .font(ayahFontSmall)
                        .foregroundColor(DesignTokens.ink)
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)

                    if showTransliteration {
                        Text(verse.transliteration)
                            .font(translitFontSmall)
                            .foregroundColor(DesignTokens.inkLight)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingL)
    }
}
