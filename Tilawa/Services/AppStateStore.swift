import Foundation
import SwiftUI

@MainActor
final class AppStateStore: ObservableObject {
    @Published var state: AppState {
        didSet {
            StatsService.shared.saveState(state)
            ShieldContext.write(from: state)
        }
    }

    init() {
        var loaded = StatsService.shared.loadState()
        StatsService.shared.resetDailyCountIfNeeded(state: &loaded)
        state = loaded
        ShieldContext.write(from: loaded)
    }

    @discardableResult
    func recordRead(ayahCount: Int, surah: Surah) -> Bool {
        StatsService.shared.recordRead(ayahCount: ayahCount, state: &state, surah: surah)
    }

    func recordReview(verseId: Int, recalled: Bool) {
        StatsService.shared.recordReview(verseId: verseId, recalled: recalled, state: &state)
    }

    func selectSurah(id: Int) {
        guard id != state.selectedSurahId else { return }
        state.selectedSurahId = id
        state.currentChunkIndex = 0
        state.timesThroughSurah = 0
        state.reviewItems = [:]
    }

    func setGoal(_ goal: ReadingGoal) {
        state.goal = goal
        state.meaningFirst = (goal == .meaning)
    }

    func completeOnboarding() {
        state.hasCompletedOnboarding = true
        state.isFirstLaunch = false
    }

    /// Reload state from UserDefaults (e.g. after StatsService.resetProgress()).
    func reloadFromStorage() {
        state = StatsService.shared.loadState()
    }
}

/// What the system shield (a separate extension) needs to know to word its message:
/// written to the shared App Group whenever the app state changes.
enum ShieldContext {
    static let suite = "group.com.tilawa.app"
    static let goalKey = "tilawa.shield.goal"
    static let surahNameKey = "tilawa.shield.surahName"
    static let detailKey = "tilawa.shield.detail"

    @MainActor
    static func write(from state: AppState) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defaults.set(state.goal.rawValue, forKey: goalKey)
        let quran = QuranService.shared
        if quran.surahs.isEmpty { quran.load() }
        guard let surah = quran.surah(id: state.selectedSurahId) else { return }
        defaults.set(surah.name, forKey: surahNameKey)

        let detail: String
        switch state.goal {
        case .review:
            if let verse = StatsService.shared.nextReviewVerse(in: surah, state: state) {
                detail = "Quick muraja’ah: recall \(surah.name), ayah \(verse.id).\nAbout 15 seconds."
            } else {
                detail = "Quick muraja’ah of \(surah.name)."
            }
        case .familiar, .meaning:
            let index = min(state.currentChunkIndex, max(0, surah.chunks.count - 1))
            let chunk = surah.chunks.isEmpty ? nil : surah.chunks[index]
            let count = chunk?.ayahIds.count ?? 1
            var seconds = chunk?.durationSeconds ?? 20
            if state.goal == .meaning { seconds = Int(Double(seconds) * 1.6) }
            let verses = count == 1 ? "1 verse" : "\(count) verses"
            let withMeaning = state.goal == .meaning ? ", with meaning," : ""
            detail = "Read \(verses) of \(surah.name)\(withMeaning) to open it.\nAbout \(roundedSeconds(seconds)) seconds."
        }
        defaults.set(detail, forKey: detailKey)
    }

    private static func roundedSeconds(_ s: Int) -> Int {
        max(5, Int((Double(s) / 5).rounded()) * 5)
    }
}
