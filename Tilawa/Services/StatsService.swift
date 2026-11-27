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

    /// Verses read outside the main surah (e.g. a wird): totals, history and streak only.
    func recordVerses(ayahCount: Int, state: inout AppState) {
        state.totalAyahsRead += ayahCount
        state.todayAyahsRead += ayahCount
        logDay(ayahs: ayahCount, state: &state)
        updateStreak(state: &state)
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

    /// Muraja'ah is for a surah you've memorized, so a verse you haven't reviewed yet starts with
    /// some words faded. The full verse (stage 0) only comes back after a miss.
    static let newVerseStage = 1

    func reviewStage(for verseId: Int, state: AppState) -> Int {
        state.reviewItems[verseId]?.stage ?? Self.newVerseStage
    }

    /// Records one muraja'ah pause. `recalled` is false when the person asked to see it again soon.
    func recordReview(verseId: Int, recalled: Bool, state: inout AppState, now: Date = Date()) {
        var item = state.reviewItems[verseId] ?? ReviewItem(stage: Self.newVerseStage)
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
        state.wirdProgress = [:]
        state.wirdsCompleted = 0
        saveState(state)
    }
}

// MARK: - Wird

/// Wird (الورد) rules: what's due today, how far the person got, and recording reading.
/// Same behaviour as the Android `Wird` object.
enum Wird {
    /// Free users keep one wird; more is Tilawa Plus.
    static let freeLimit = 1

    /// One-tap suggestions for the common ones.
    struct Preset {
        let surahId: Int
        var weekdays: Set<Int> = []
        var everyDays: Int = 0
        let note: String
    }

    static let presets: [Preset] = [
        Preset(surahId: 18, weekdays: [5], note: "Al-Kahf on Fridays"),
        Preset(surahId: 67, everyDays: 1, note: "Al-Mulk every night"),
        Preset(surahId: 36, everyDays: 2, note: "Ya-Sin every 2 days"),
        Preset(surahId: 56, everyDays: 1, note: "Al-Waqi'ah every night"),
        Preset(surahId: 32, everyDays: 1, note: "As-Sajdah every night"),
    ]

    static func canAdd(_ state: AppState) -> Bool { state.isPro || state.wird.count < freeLimit }

    /// Items that count: all of them with Plus, otherwise the first `freeLimit`.
    static func activeItems(_ state: AppState) -> [WirdItem] {
        state.isPro ? state.wird : Array(state.wird.prefix(freeLimit))
    }

    static func dueToday(_ state: AppState, now: Date = Date()) -> [WirdItem] {
        activeItems(state).filter { $0.isDue(on: now) }
    }

    /// Highest ayah read today for `item`; 0 if not started.
    static func upTo(_ state: AppState, _ item: WirdItem, now: Date = Date()) -> Int {
        guard let p = state.wirdProgress[item.id], Calendar.current.isDate(p.day, inSameDayAs: now) else { return 0 }
        return p.upTo
    }

    static func isFinished(_ state: AppState, _ item: WirdItem, surah: Surah, now: Date = Date()) -> Bool {
        upTo(state, item, now: now) >= surah.totalVerses
    }

    /// The wird pauses read right now: the first one due today that isn't finished, in list order.
    static func current(_ state: AppState, quran: QuranService = .shared, now: Date = Date()) -> WirdItem? {
        dueToday(state, now: now).first { item in
            guard let surah = quran.surah(id: item.surahId) else { return false }
            return !isFinished(state, item, surah: surah, now: now)
        }
    }

    /// The next small piece of `surah` after ayah `upTo`, using the same chunks as normal pauses.
    static func nextVerses(_ surah: Surah, after upTo: Int) -> [Verse] {
        // The chunk holding the next unread ayah, starting from that ayah, so nothing is skipped.
        guard let chunk = surah.chunks.first(where: { ($0.ayahIds.last ?? 0) > upTo }) else { return [] }
        return chunk.ayahIds.filter { $0 > upTo }.compactMap { id in surah.verses.first { $0.id == id } }
    }

    /// The person read `verses` of `item`'s surah. Returns whether that finished today's wird for it.
    @discardableResult
    static func record(_ state: inout AppState, item: WirdItem, surah: Surah, verses: [Verse], now: Date = Date()) -> Bool {
        let before = upTo(state, item, now: now)
        let after = max(before, verses.map(\.id).max() ?? before)
        let finished = before < surah.totalVerses && after >= surah.totalVerses
        let today = Calendar.current.startOfDay(for: now)
        state.wirdProgress = state.wirdProgress.filter { Calendar.current.isDate($0.value.day, inSameDayAs: today) }
        state.wirdProgress[item.id] = WirdProgress(day: today, upTo: after)
        if finished { state.wirdsCompleted += 1 }
        StatsService.shared.recordVerses(ayahCount: verses.count, state: &state)
        return finished
    }

    /// Next day `item` is due after today, for "Next: Friday".
    static func nextDueDay(_ item: WirdItem, from now: Date = Date()) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        return (1...60).lazy.compactMap { cal.date(byAdding: .day, value: $0, to: today) }.first { item.isDue(on: $0) }
    }
}
