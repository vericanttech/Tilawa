import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class AppStateStore: ObservableObject {
    @Published var state: AppState {
        didSet {
            StatsService.shared.saveState(state)
            ShieldContext.write(from: state)
            if oldValue.reminderKey != state.reminderKey { rescheduleReminders() }
        }
    }

    /// When the next reading reminder comes, or nil when they're off.
    @Published private(set) var nextReminderAt: Date?

    /// Rebuilds the queue of upcoming reminders (on launch, after reading, when settings change).
    func rescheduleReminders() {
        nextReminderAt = Reminders.reschedule(state: state)
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
        // Read with meaning starts in English; leaving it goes back to Arabic.
        // Someone who reads in transliteration keeps it.
        if goal == .meaning {
            state.readIn = .english
        } else if state.readIn == .english {
            state.readIn = .arabic
        }
    }

    func completeOnboarding() {
        state.hasCompletedOnboarding = true
        state.isFirstLaunch = false
    }

    /// Reload state from UserDefaults (e.g. after StatsService.resetProgress()).
    func reloadFromStorage() {
        state = StatsService.shared.loadState()
    }

    // MARK: - Which wird the next pause reads

    enum GateWird: Equatable {
        /// Pauses from a paused app or its notification: today's wird first, if one is due.
        case auto
        /// "Read now" on Today: the main surah.
        case none
        /// A wird card's Read button.
        case item(Int)
    }

    /// Set just before a pause opens; back to `.auto` once it closes.
    @Published var gateWird: GateWird = .auto

    /// The wird item the pause about to open reads, or nil for the main surah.
    func resolveGateWird() -> Int? {
        switch gateWird {
        case .none: return nil
        case .item(let id): return id
        case .auto: return Wird.current(state)?.id
        }
    }

    // MARK: - Reading sessions (a pause, plus any "Keep reading")

    private var quran: QuranService { QuranService.shared }

    /// The first page of a pause.
    func firstSegment(wirdId: Int?) -> ReadingSegment? {
        if let wirdId, let page = wirdSegment(wirdId, after: nil) { return page }
        return mainSegment(chunkIndex: state.currentChunkIndex)
    }

    /// What "Keep reading" shows after `after`: the rest of that wird surah, then the next wird due today,
    /// then the main surah (not in Muraja'ah, which reviews one verse at a time).
    func nextSegment(after: ReadingSegment) -> ReadingSegment? {
        let lastId = after.verses.last?.id ?? 0
        if let wirdId = after.wirdId {
            if let page = wirdSegment(wirdId, after: lastId) { return page }
            for item in Wird.dueToday(state) where item.id != wirdId {
                if let page = wirdSegment(item.id, after: nil) { return page }
            }
        }
        if state.goal == .review { return nil }
        guard let main = quran.surah(id: state.selectedSurahId), !main.chunks.isEmpty else { return nil }
        if after.wirdId != nil { return mainSegment(chunkIndex: state.currentChunkIndex) }
        let index = main.chunks.firstIndex { $0.ayahIds.contains(lastId) }
        return mainSegment(chunkIndex: index.map { ($0 + 1) % main.chunks.count } ?? state.currentChunkIndex)
    }

    /// Counts `segment` as read. Returns the surah name if this finished it (a pass, or today's wird).
    func recordSegment(_ segment: ReadingSegment) -> String? {
        if let wirdId = segment.wirdId {
            guard let item = state.wird.first(where: { $0.id == wirdId }) else { return nil }
            var updated = state
            let finished = Wird.record(&updated, item: item, surah: segment.surah, verses: segment.verses)
            state = updated
            return finished ? segment.surah.name : nil
        }
        let finishedPass = recordRead(ayahCount: segment.verses.count, surah: segment.surah)
        return finishedPass ? segment.surah.name : nil
    }

    /// What the done screen shows after `read` pages (already recorded).
    func doneInfo(read: [ReadingSegment], finished: [String]) -> DoneInfo? {
        guard let last = read.last, let lastVerse = last.verses.last else { return nil }
        let count = read.reduce(0) { $0 + $1.verses.count }
        let chip: String
        if let name = finished.last {
            chip = "Finished \(name)"
        } else if let wirdId = last.wirdId {
            let upTo = state.wird.first { $0.id == wirdId }.map { Wird.upTo(state, $0) } ?? lastVerse.id
            chip = "\(last.surah.name) \(upTo)/\(last.surah.totalVerses)"
        } else if state.goal == .familiar {
            chip = "\(last.surah.name) · \(Ordinal.string(state.timesThroughSurah + 1)) time through"
        } else {
            chip = "\(last.surah.name) \(lastVerse.id)/\(last.surah.totalVerses)"
        }
        let keep = last.verses.last(where: { $0.translation != nil }) ?? lastVerse
        return DoneInfo(
            headline: count == 1 ? "1 verse read" : "\(count) verses read",
            chip: chip,
            cardLabel: "Take with you",
            cardText: keep.translation.map { "“\($0)”" } ?? keep.text,
            cardTextIsArabic: keep.translation == nil,
            cardRef: "\(last.surah.name) \(last.surah.id):\(keep.id)"
        )
    }

    private func mainSegment(chunkIndex: Int) -> ReadingSegment? {
        guard let main = quran.surah(id: state.selectedSurahId), !main.chunks.isEmpty else { return nil }
        let chunk = main.chunks[min(max(0, chunkIndex), main.chunks.count - 1)]
        let verses = chunk.ayahIds.compactMap { id in main.verses.first { $0.id == id } }
        return verses.isEmpty ? nil : ReadingSegment(surah: main, wirdId: nil, verses: verses)
    }

    /// Next page of a wird surah, after ayah `after` (or after today's progress when nil).
    private func wirdSegment(_ id: Int, after: Int?) -> ReadingSegment? {
        guard let item = state.wird.first(where: { $0.id == id }),
              let surah = quran.surah(id: item.surahId) else { return nil }
        let verses = Wird.nextVerses(surah, after: max(after ?? 0, Wird.upTo(state, item)))
        return verses.isEmpty ? nil : ReadingSegment(surah: surah, wirdId: id, verses: verses)
    }

    // MARK: - Wird

    func addWird(surahId: Int, weekdays: Set<Int>, everyDays: Int, remindAt: Int? = nil) {
        guard Wird.canAdd(state) else { return }
        let id = (state.wird.map(\.id).max() ?? 0) + 1
        state.wird.append(WirdItem(id: id, surahId: surahId, weekdays: weekdays, everyDays: everyDays, remindAt: remindAt))
    }

    func updateWird(_ item: WirdItem) {
        guard let i = state.wird.firstIndex(where: { $0.id == item.id }) else { return }
        state.wird[i] = item
    }

    func removeWird(id: Int) {
        state.wird.removeAll { $0.id == id }
        state.wirdProgress[id] = nil
    }

    func moveWird(id: Int, by offset: Int) {
        guard let i = state.wird.firstIndex(where: { $0.id == id }) else { return }
        let j = min(max(0, i + offset), state.wird.count - 1)
        guard i != j else { return }
        var list = state.wird
        list.insert(list.remove(at: i), at: j)
        state.wird = list
    }
}

// MARK: - Reading reminders

/// Gentle reading reminders: every few hours inside the person's waking window, a notification with the next
/// few verses. iOS can't repeat "every 2 hours between 8 and 10", so the next few days are queued ahead and
/// rebuilt whenever the app opens or the person reads. If they stop opening the app, reminders end with the queue.
enum Reminders {
    static let idPrefix = "tilawa.reminder."
    /// How far ahead reminders are queued (iOS keeps at most 64 pending notifications per app).
    static let daysAhead = 3
    static let maxQueued = 48
    /// Ids 48..<64 are for wird reminders at their own time.
    static let maxWirdQueued = 16

    /// The next reminder after `from`, inside the window.
    static func nextAt(_ state: AppState, from: Date) -> Date {
        let cal = Calendar.current
        let candidate = from.addingTimeInterval(TimeInterval(state.remindEveryHours) * 3600)
        let day = cal.startOfDay(for: candidate)
        let start = cal.date(byAdding: .hour, value: min(max(state.remindFrom, 0), 23), to: day) ?? candidate
        let end = cal.date(byAdding: .hour, value: min(max(state.remindUntil, 1), 24), to: day) ?? candidate
        if candidate < start { return start }                                         // night: first thing in the morning
        if candidate >= end { return cal.date(byAdding: .day, value: 1, to: start) ?? start } // past the window: tomorrow
        return candidate
    }

    /// Replaces the queued reminders. Returns when the first one comes.
    @MainActor
    @discardableResult
    static func reschedule(state: AppState, now: Date = Date()) -> Date? {
        let center = UNUserNotificationCenter.current()
        // Fixed ids, removed in the same order as the adds below (a lookup first would race with them).
        center.removePendingNotificationRequests(withIdentifiers: (0..<64).map { "\(idPrefix)\($0)" })
        guard state.hasCompletedOnboarding else { return nil }

        let quran = QuranService.shared
        if quran.surahs.isEmpty { quran.load() }
        let horizon = now.addingTimeInterval(TimeInterval(daysAhead) * 24 * 3600)
        var times: [Date] = []
        if state.remindersOn {
            var t = nextAt(state, from: now)
            while t < horizon && times.count < maxQueued {
                times.append(t)
                t = nextAt(state, from: t)
            }
        }
        for (index, time) in times.enumerated() {
            guard let content = content(state: state, at: time, now: now, quran: quran) else { continue }
            add(center, id: index, at: time, content: content)
        }
        // A wird with its own time is reminded then, on its days, even with the regular reminders off.
        let wirdTimes = wirdTimes(state: state, now: now, horizon: horizon, quran: quran)
        for (index, entry) in wirdTimes.enumerated() {
            add(center, id: maxQueued + index, at: entry.time, content: entry.content)
        }
        return (times + wirdTimes.map { $0.time }).min()
    }

    private static func add(_ center: UNUserNotificationCenter, id: Int, at time: Date, content: UNMutableNotificationContent) {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        center.add(UNNotificationRequest(
            identifier: "\(idPrefix)\(id)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        ))
    }

    /// Wird reminders at their own time over the next few days (skipping one already read today).
    private static func wirdTimes(state: AppState, now: Date, horizon: Date, quran: QuranService) -> [(time: Date, content: UNMutableNotificationContent)] {
        let cal = Calendar.current
        var result: [(time: Date, content: UNMutableNotificationContent)] = []
        for dayOffset in 0...daysAhead {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)) else { continue }
            for item in Wird.activeItems(state) where item.isDue(on: day) {
                guard let minutes = item.remindAt, let surah = quran.surah(id: item.surahId),
                      let time = cal.date(byAdding: .minute, value: minutes, to: day),
                      time > now, time < horizon else { continue }
                let upTo = cal.isDate(day, inSameDayAs: now) ? Wird.upTo(state, item, now: now) : 0
                let verses = Wird.nextVerses(surah, after: upTo)
                guard !verses.isEmpty else { continue }
                let title = upTo == 0 ? "Time for your wird · \(surah.name)" : "Continue your wird · \(surah.name)"
                result.append((time, reading(title: title, surah: surah, verses: verses, state: state)))
            }
        }
        return Array(result.sorted { $0.time < $1.time }.prefix(maxWirdQueued))
    }

    /// Clears reminders already showing (after the person reads).
    static func clearDelivered() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(idPrefix) })
        }
    }

    /// The verses a reminder offers: that day's wird first, else the main surah (a recall in muraja'ah).
    /// Queued ahead, so today's wird starts from today's progress and later days from the beginning.
    static func content(state: AppState, at time: Date, now: Date, quran: QuranService) -> UNMutableNotificationContent? {
        let sameDay = Calendar.current.isDate(time, inSameDayAs: now)
        for item in Wird.activeItems(state) where item.isDue(on: time) {
            guard let surah = quran.surah(id: item.surahId) else { continue }
            let upTo = sameDay ? Wird.upTo(state, item, now: now) : 0
            let verses = Wird.nextVerses(surah, after: upTo)
            if !verses.isEmpty {
                return reading(title: "Today’s wird · \(surah.name)", surah: surah, verses: verses, state: state)
            }
        }
        guard let surah = quran.surah(id: state.selectedSurahId), !surah.chunks.isEmpty else { return nil }
        if state.goal == .review {
            let content = UNMutableNotificationContent()
            content.title = "Quick muraja’ah · \(surah.name)"
            if let verse = StatsService.shared.nextReviewVerse(in: surah, state: state, now: time) {
                content.body = "Can you recall ayah \(verse.id)? About 15 seconds."
            } else {
                content.body = "Can you recall the next ayah? About 15 seconds."
            }
            content.sound = .default
            return content
        }
        let chunk = surah.chunks[min(state.currentChunkIndex, surah.chunks.count - 1)]
        let verses = chunk.ayahIds.compactMap { id in surah.verses.first { $0.id == id } }
        guard !verses.isEmpty else { return nil }
        return reading(title: "A few verses of \(surah.name)", surah: surah, verses: verses, state: state)
    }

    private static func reading(title: String, surah: Surah, verses: [Verse], state: AppState) -> UNMutableNotificationContent {
        let first = verses[0]
        // The verse as the person reads it. The translation is shown as it is (QuranEnc asks it isn't changed).
        let line: String
        switch state.readIn {
        case .arabic: line = first.text
        case .transliteration: line = first.transliteration
        case .english: line = first.translation ?? first.transliteration
        }
        let range = verses.count == 1 ? "\(surah.id):\(first.id)" : "\(surah.id):\(first.id)–\(verses.last!.id)"
        let count = verses.count == 1 ? "1 verse" : "\(verses.count) verses"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(line)\n\(surah.name) \(range) · \(count)"
        content.sound = .default
        content.threadIdentifier = "tilawa.reminders"
        return content
    }
}

/// One page of reading in a pause: a few verses of the main surah, or of a wird surah.
struct ReadingSegment: Equatable {
    let surah: Surah
    let wirdId: Int?
    let verses: [Verse]

    /// Identifies the page (for resetting the timer and scroll position).
    var key: String { "\(surah.id)-\(wirdId ?? 0)-\(verses.first?.id ?? 0)" }

    static func == (a: ReadingSegment, b: ReadingSegment) -> Bool { a.key == b.key }
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
        // A wird due today comes first: the shield says so.
        if let item = Wird.current(state, quran: quran), let wirdSurah = quran.surah(id: item.surahId) {
            let verses = Wird.nextVerses(wirdSurah, after: Wird.upTo(state, item))
            let count = verses.count == 1 ? "1 verse" : "\(verses.count) verses"
            defaults.set(ReadingGoal.familiar.rawValue, forKey: goalKey)
            defaults.set(wirdSurah.name, forKey: surahNameKey)
            defaults.set("Today’s wird: read \(count) of \(wirdSurah.name) to open it.", forKey: detailKey)
            return
        }
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
