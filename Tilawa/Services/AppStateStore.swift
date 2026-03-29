import Foundation
import SwiftUI

@MainActor
final class AppStateStore: ObservableObject {
    @Published var state: AppState {
        didSet { StatsService.shared.saveState(state) }
    }

    init() {
        var loaded = StatsService.shared.loadState()
        StatsService.shared.resetDailyCountIfNeeded(state: &loaded)
        state = loaded
    }

    func recordRead(ayahCount: Int, surah: Surah) {
        StatsService.shared.recordRead(ayahCount: ayahCount, state: &state, surah: surah)
    }

    func selectSurah(id: Int) {
        state.selectedSurahId = id
        state.currentChunkIndex = 0
    }

    /// Reload state from UserDefaults (e.g. after StatsService.resetProgress()).
    func reloadFromStorage() {
        state = StatsService.shared.loadState()
    }
}
