import SwiftUI

/// "Progress": streak, the last four weeks, and what the current goal has built up.
/// (Named ProgressTabView so it does not clash with SwiftUI's ProgressView.)
struct ProgressTabView: View {
    @ObservedObject var appState: AppStateStore

    private let quran = QuranService.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Progress")
                    .font(DesignTokens.largeTitle)
                    .foregroundColor(DesignTokens.ink)

                streakCard
                heatmapCard
                HStack(spacing: 12) {
                    ForEach(stats, id: \.label) { stat in
                        statCard(stat)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.mist.ignoresSafeArea())
    }

    private var streakCard: some View {
        let s = appState.state
        return HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26))
                .foregroundColor(DesignTokens.streak)
                .frame(width: 56, height: 56)
                .background(Circle().fill(DesignTokens.streakTint))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.streakDays == 1 ? "1 day" : "\(s.streakDays) days")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(DesignTokens.ink)
                Text("Current streak · longest \(max(s.longestStreak, s.streakDays))")
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.muted)
            }
            Spacer()
        }
        .card()
    }

    private var heatmapCard: some View {
        let days = StatsService.shared.history(days: 28, state: appState.state)
        let maxDay = max(1, days.max() ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Last 4 weeks")
                    .font(DesignTokens.headline)
                    .foregroundColor(DesignTokens.ink)
                Spacer()
                Text("\(days.filter { $0 > 0 }.count) of 28 days")
                    .font(DesignTokens.caption)
                    .foregroundColor(DesignTokens.muted)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: days[i], max: maxDay))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(i == days.count - 1 ? DesignTokens.ink.opacity(0.4) : .clear, lineWidth: 1.5)
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Read on \(days.filter { $0 > 0 }.count) of the last 28 days")
            HStack(spacing: 6) {
                Text("Less").font(.system(size: 11)).foregroundColor(DesignTokens.muted)
                ForEach(0..<DesignTokens.heat.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3).fill(DesignTokens.heat[i]).frame(width: 12, height: 12)
                }
                Text("More").font(.system(size: 11)).foregroundColor(DesignTokens.muted)
            }
            .accessibilityHidden(true)
        }
        .card()
    }

    private func color(for count: Int, max: Int) -> Color {
        guard count > 0 else { return DesignTokens.heat[0] }
        let ratio = Double(count) / Double(max)
        if ratio > 0.66 { return DesignTokens.heat[3] }
        if ratio > 0.33 { return DesignTokens.heat[2] }
        return DesignTokens.heat[1]
    }

    private struct Stat { let value: String; let label: String }

    private var stats: [Stat] {
        let s = appState.state
        let surah = quran.surah(id: s.selectedSurahId)
        switch s.goal {
        case .review:
            let strong = surah.map { StatsService.shared.strongVerseCount(in: $0, state: s) } ?? 0
            return [
                Stat(value: "\(strong)/\(surah?.totalVerses ?? 0)", label: "Verses strong"),
                Stat(value: "\(s.totalReviews)", label: "Reviews done"),
            ]
        case .familiar:
            return [
                Stat(value: "\(s.timesThroughSurah)×", label: "Through \(surah?.name ?? "the surah")"),
                Stat(value: "\(s.totalAyahsRead)", label: "Verses read"),
            ]
        case .meaning:
            return [
                Stat(value: "\(s.totalAyahsRead)", label: "Verses understood"),
                Stat(value: "\(s.surahsCompleted)", label: "Surahs finished"),
            ]
        }
    }

    private func statCard(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(DesignTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(stat.label)
                .font(DesignTokens.caption)
                .foregroundColor(DesignTokens.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18, radius: DesignTokens.radiusXl)
    }
}
