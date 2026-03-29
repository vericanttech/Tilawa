import Foundation

final class StatsService {
    static let shared = StatsService()
    private let stateKey = "tilawa.appState"

    private init() {}

    func loadState() -> AppState {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return AppState()
        }
        return state
    }

    func saveState(_ state: AppState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    func recordRead(ayahCount: Int, state: inout AppState, surah: Surah) {
        state.totalAyahsRead += ayahCount
        state.todayAyahsRead += ayahCount
        state.currentChunkIndex += 1
        if state.currentChunkIndex >= surah.chunks.count {
            state.currentChunkIndex = 0
        }
        updateStreak(state: &state)
        saveState(state)
    }

    func updateStreak(state: inout AppState) {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = state.lastReadDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 { state.streakDays += 1 }
            else if diff > 1 { state.streakDays = 1 }
        } else {
            state.streakDays = 1
        }
        state.lastReadDate = Date()
    }

    func resetDailyCountIfNeeded(state: inout AppState) {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = state.lastReadDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            if lastDay < today {
                state.todayAyahsRead = 0
            }
        }
    }

    /// Zeros total ayahs, today's count, streak, and last read date. Persists immediately.
    func resetProgress() {
        var state = loadState()
        state.totalAyahsRead = 0
        state.todayAyahsRead = 0
        state.streakDays = 0
        state.lastReadDate = nil
        saveState(state)
    }
}
