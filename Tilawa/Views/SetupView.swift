import SwiftUI

struct SetupView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let quran = QuranService.shared

    private var filteredSurahs: [Surah] {
        quran.search(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            pageTitle
                .background(DesignTokens.appBackground)

            Divider()
                .background(DesignTokens.cardBorder)
                .opacity(0)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacing2xl) {
                    surahSection
                }
                .padding(.bottom, 32)
            }
            .clipped()
        }
        .background(DesignTokens.appBackground)
    }

    private var pageTitle: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(Localization.L("setup.your_surah", appState.state.language))
                .font(.system(size: 18))
                .foregroundColor(DesignTokens.topBarTitle)
            Text(Localization.L("setup.your_surah_subtitle", appState.state.language))
                .font(Font.custom("CormorantGaramond-Italic", size: 12))
                .foregroundColor(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.spacingXl)
        .padding(.top, DesignTokens.spacing2xl)
        .padding(.bottom, DesignTokens.spacingS)
    }

    private var surahSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            Text(Localization.L("setup.choose_surah", appState.state.language))
                .font(Font.custom("CormorantGaramond-Regular", size: 11))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundColor(DesignTokens.sectionLabel)
                .padding(.horizontal, DesignTokens.spacingXl)

            searchField
                .padding(.horizontal, DesignTokens.spacingXl)

            LazyVStack(spacing: DesignTokens.spacingS) {
                ForEach(filteredSurahs) { surah in
                    surahRow(surah)
                }
            }
            .padding(.horizontal, DesignTokens.spacingXl)
        }
    }

    private var searchField: some View {
        let placeholder = Localization.L("setup.search_surah", appState.state.language)
        let searchFont = Font.custom("CormorantGaramond-Regular", size: 15)
        return ZStack(alignment: .leading) {
            Text(placeholder)
                .font(searchFont)
                .tracking(0.04)
                .foregroundColor(DesignTokens.searchPlaceholder)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .opacity(searchText.isEmpty ? 1 : 0)
            TextField("", text: $searchText)
                .font(searchFont)
                .tracking(0.04)
                .foregroundColor(DesignTokens.searchText)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .focused($isSearchFocused)
                .accentColor(DesignTokens.gold)
        }
        .background(DesignTokens.searchBg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                .stroke(
                    isSearchFocused ? DesignTokens.gold.opacity(0.45) : DesignTokens.cardBorder,
                    lineWidth: 1
                )
        )
    }

    private func surahRow(_ surah: Surah) -> some View {
        let isSelected = appState.state.selectedSurahId == surah.id
        return Button {
            appState.selectSurah(id: surah.id)
        } label: {
            HStack(spacing: DesignTokens.spacingM) {
                Text("\(surah.id)")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.secondaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Text(surah.name)
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.primaryText)
                    Text(String(format: Localization.L("setup.ayahs_meta", appState.state.language), surah.totalVerses, surah.type))
                        .font(Font.custom("CormorantGaramond-Italic", size: 11))
                        .foregroundColor(DesignTokens.secondaryText)
                }

                Spacer()

                Text(surah.nameArabic)
                    .font(Font.custom("Lateef-Regular", size: 20))
                    .foregroundColor(isSelected ? DesignTokens.goldLight : DesignTokens.secondaryText)
                    .environment(\.layoutDirection, .rightToLeft)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.gold)
                }
            }
            .padding(DesignTokens.spacingM)
            .background(isSelected ? DesignTokens.gold.opacity(0.08) : DesignTokens.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                    .stroke(isSelected ? DesignTokens.gold : DesignTokens.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
