import SwiftUI

/// "Surahs" tab.
struct SetupView: View {
    @ObservedObject var appState: AppStateStore
    @ObservedObject var shield: ShieldService

    var body: some View {
        NavigationStack {
            SurahLibraryView(appState: appState, showsTitle: true)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Searchable list of surahs. Used by the Surahs tab and pushed from onboarding.
struct SurahLibraryView: View {
    @ObservedObject var appState: AppStateStore
    var showsTitle: Bool = true

    enum Filter: Hashable { case suggested, short, all }

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var filter: Filter = .suggested

    private let quran = QuranService.shared

    private var surahs: [Surah] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { return quran.search(q) }
        switch filter {
        case .suggested: return SuggestedSurah.library.compactMap { quran.surah(id: $0) }
        case .short: return quran.surahs.filter { $0.totalVerses <= 20 }
        case .all: return quran.surahs
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if showsTitle {
                    Text("Surahs")
                        .font(DesignTokens.largeTitle)
                        .foregroundColor(DesignTokens.ink)
                }

                searchField

                if searchText.isEmpty {
                    HStack(spacing: 8) {
                        chip("Suggested", .suggested)
                        chip("Short", .short)
                        chip("All 114", .all)
                    }
                }

                LazyVStack(spacing: 0) {
                    ForEach(surahs) { surah in
                        row(surah)
                        if surah.id != surahs.last?.id {
                            Rectangle().fill(DesignTokens.hairline).frame(height: 1).padding(.leading, 64)
                        }
                    }
                }
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusCard, style: .continuous).fill(DesignTokens.surface))

                if surahs.isEmpty {
                    Text("No surah matches “\(searchText)”.")
                        .font(DesignTokens.callout)
                        .foregroundColor(DesignTokens.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.mist.ignoresSafeArea())
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignTokens.muted)
            TextField("Search by name or number", text: $searchText)
                .font(DesignTokens.body)
                .foregroundColor(DesignTokens.ink)
                .tint(DesignTokens.accent)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(DesignTokens.muted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: DesignTokens.radiusMd, style: .continuous).fill(DesignTokens.track))
    }

    private func chip(_ title: String, _ value: Filter) -> some View {
        let on = filter == value
        return Button { filter = value } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(on ? .white : DesignTokens.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(on ? DesignTokens.accent : DesignTokens.surface))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(_ surah: Surah) -> some View {
        let selected = appState.state.selectedSurahId == surah.id
        return Button {
            appState.selectSurah(id: surah.id)
            if !showsTitle || isPushed { dismiss() }
        } label: {
            HStack(spacing: 14) {
                Text("\(surah.id)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(selected ? .white : DesignTokens.mutedStrong)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? DesignTokens.accent : DesignTokens.surfaceMuted))
                VStack(alignment: .leading, spacing: 2) {
                    Text(surah.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.ink)
                    Text("\(surah.totalVerses) verses · \(surah.type.capitalized)\(selected ? " · Current" : "")")
                        .font(DesignTokens.caption)
                        .foregroundColor(selected ? DesignTokens.accent : DesignTokens.muted)
                }
                Spacer()
                Text(surah.nameArabic)
                    .font(DesignTokens.arabic(20))
                    .foregroundColor(selected ? DesignTokens.accent : DesignTokens.mutedStrong)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// True when pushed onto a navigation stack (e.g. from onboarding), so picking a surah goes back.
    @Environment(\.isPresented) private var isPushed
}
