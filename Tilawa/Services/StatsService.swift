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

    // MARK: - Reading (Get familiar / Read with meaning)

    /// Records a finished reading pause and moves to the next chunk.
    /// Returns true when this read completed a full pass through the surah.
    @discardableResult
    func recordRead(ayahCount: Int, state: inout AppState, surah: Surah) -> Bool {
        state.totalAyahsRead += ayahCount
        state.todayAyahsRead += ayahCount
        state.currentChunkIndex += 1
        var finishedPass = false
        if state.currentChunkIndex >= surah.chunks.count {
            state.currentChunkIndex = 0
            state.timesThroughSurah += 1
            state.surahsCompleted += 1
            finishedPass = true
        }
        logDay(ayahs: ayahCount, state: &state)
        updateStreak(state: &state)
        saveState(state)
        return finishedPass
    }

    // MARK: - Muraja'ah

    /// The verse to review in the next pause: the most overdue verse, else the next verse
    /// never reviewed, else the verse coming due soonest (there is always something to recall).
    func nextReviewVerse(in surah: Surah, state: AppState, now: Date = Date()) -> Verse? {
        let items = state.reviewItems
        let due = surah.verses
            .filter { items[$0.id] != nil && items[$0.id]!.dueAt <= now }
            .sorted { items[$0.id]!.dueAt < items[$1.id]!.dueAt }
        if let first = due.first { return first }
        if let fresh = surah.verses.first(where: { items[$0.id] == nil }) { return fresh }
        return surah.verses.min { (items[$0.id]?.dueAt ?? now) < (items[$1.id]?.dueAt ?? now) }
    }

    func reviewStage(for verseId: Int, state: AppState) -> Int {
        state.reviewItems[verseId]?.stage ?? 0
    }

    /// Records one muraja'ah pause. `recalled` is false when the person asked to see it again soon.
    func recordReview(verseId: Int, recalled: Bool, state: inout AppState, now: Date = Date()) {
        var item = state.reviewItems[verseId] ?? ReviewItem()
        item.timesReviewed += 1
        if recalled {
            let wasStage = item.stage
            item.stage = min(item.stage + 1, 3)
            let interval: TimeInterval
            switch item.stage {
            case 1: interval = 30 * 60               // see it fading in 30 minutes
            case 2: interval = 2 * 60 * 60           // first word only a couple of hours later
            default:
                if wasStage < 3 {
                    interval = 24 * 60 * 60          // first full recall: tomorrow
                } else {
                    let days = min(30, max(2, (item.timesReviewed - 3) * 2))
                    interval = TimeInterval(days) * 24 * 60 * 60
                }
            }
            item.dueAt = now.addingTimeInterval(interval)
        } else {
            item.stage = max(item.stage - 1, 0)
            item.dueAt = now.addingTimeInterval(10 * 60)
        }
        state.reviewItems[verseId] = item
        state.totalReviews += 1
        state.totalAyahsRead += 1
        state.todayAyahsRead += 1
        logDay(ayahs: 1, state: &state)
        updateStreak(state: &state)
        saveState(state)
    }

    func strongVerseCount(in surah: Surah, state: AppState) -> Int {
        surah.verses.filter { state.reviewItems[$0.id]?.isStrong == true }.count
    }

    /// Verses due for review today, in order.
    func versesDueToday(in surah: Surah, state: AppState, now: Date = Date()) -> [Verse] {
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        return surah.verses
            .filter { (state.reviewItems[$0.id]?.dueAt ?? .distantFuture) < endOfDay }
            .sorted { (state.reviewItems[$0.id]?.dueAt ?? now) < (state.reviewItems[$1.id]?.dueAt ?? now) }
    }

    // MARK: - Streak & history

    func updateStreak(state: inout AppState) {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = state.lastReadDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 { state.streakDays += 1 }
            else if diff > 1 { state.streakDays = 1 }
            else if state.streakDays == 0 { state.streakDays = 1 }
        } else {
            state.streakDays = 1
        }
        state.longestStreak = max(state.longestStreak, state.streakDays)
        state.lastReadDate = Date()
    }

    private func logDay(ayahs: Int, state: inout AppState) {
        let day = Calendar.current.startOfDay(for: Date())
        state.dailyAyahs[day, default: 0] += ayahs
        // Keep roughly the last 3 months.
        if let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: day) {
            state.dailyAyahs = state.dailyAyahs.filter { $0.key >= cutoff }
        }
    }

    /// Ayahs read per day for the last `days` days, oldest first.
    func history(days: Int, state: AppState) -> [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return state.dailyAyahs[day] ?? 0
        }
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

    /// Zeros all reading statistics. Persists immediately.
    func resetProgress() {
        var state = loadState()
        state.totalAyahsRead = 0
        state.todayAyahsRead = 0
        state.streakDays = 0
        state.longestStreak = 0
        state.lastReadDate = nil
        state.currentChunkIndex = 0
        state.timesThroughSurah = 0
        state.surahsCompleted = 0
        state.reviewItems = [:]
        state.totalReviews = 0
        state.dailyAyahs = [:]
        saveState(state)
    }
}
