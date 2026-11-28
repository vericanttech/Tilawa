import Foundation

enum Language: String, Codable, CaseIterable {
    case english
    case french
    case arabic

    /// ISO 639-1 style code for loading the correct .lproj bundle.
    var localeCode: String {
        switch self {
        case .english: return "en"
        case .french: return "fr"
        case .arabic: return "ar"
        }
    }
}

enum ReadingSpeed: String, Codable, CaseIterable {
    case slow   // 0.85 sec/word
    case normal // 0.65 sec/word (default)
    case fast   // 0.45 sec/word

    /// Multiplier for SECONDS_PER_WORD (higher = slower reading).
    var secondsPerWordMultiplier: Double {
        switch self {
        case .slow: return 0.85
        case .normal: return 0.65
        case .fast: return 0.45
        }
    }
}

/// Why the person uses Tilawa. Chosen in onboarding, changeable in Settings.
enum ReadingGoal: String, Codable, CaseIterable, Identifiable {
    /// Read one surah again and again until it feels familiar.
    case familiar
    /// Muraja'ah: keep a memorized surah fresh with fading-verse recall.
    case review
    /// Read with meaning: English first, Arabic underneath.
    case meaning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .familiar: return "Get familiar"
        case .review: return "Muraja’ah"
        case .meaning: return "Read with meaning"
        }
    }

    var arabicTitle: String? {
        self == .review ? "مراجعة" : nil
    }

    var summary: String {
        switch self {
        case .familiar: return "Read one surah again and again, until it feels like yours."
        case .review: return "You’ve memorized it. Keep it fresh with verses that fade so you recall them."
        case .meaning: return "English first, with the Arabic underneath. No Arabic reading needed."
        }
    }

    var systemImage: String {
        switch self {
        case .familiar: return "repeat"
        case .review: return "brain.head.profile"
        case .meaning: return "character.book.closed"
        }
    }

    /// Label shown above the current surah on Today.
    var nowLabel: String {
        switch self {
        case .familiar: return "Getting familiar"
        case .review: return "Muraja’ah"
        case .meaning: return "Reading with meaning"
        }
    }

    var actionTitle: String { self == .review ? "Review now" : "Read now" }
}

/// Which text a person reads: it's shown large, the others smaller underneath.
enum ReadIn: String, Codable, CaseIterable, Identifiable {
    /// Reads the Arabic script.
    case arabic
    /// Can't read the script, sounds it out in Latin letters.
    case transliteration
    /// Reads for the meaning.
    case english

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arabic: return "Arabic"
        case .transliteration: return "Transliteration"
        case .english: return "English"
        }
    }

    /// Fits a three-way picker in a small card.
    var shortLabel: String { self == .transliteration ? "Latin" : label }
}

/// Memory state of one verse in muraja'ah mode (a simple Leitner box).
struct ReviewItem: Codable, Equatable {
    /// 0 = full text, 1 = fading, 2 = first word only, 3 = full recall.
    var stage: Int = 0
    var dueAt: Date = .distantPast
    var timesReviewed: Int = 0

    /// A verse counts as "strong" once it has been recalled from a blank screen.
    var isStrong: Bool { stage >= 3 && timesReviewed >= 4 }
}

/// One surah in the person's wird (الورد) and the days it's read, e.g. Al-Kahf on Fridays.
struct WirdItem: Codable, Equatable, Identifiable {
    var id: Int
    var surahId: Int
    /// 1 = Monday … 7 = Sunday. Used when `everyDays` is 0.
    var weekdays: Set<Int> = []
    /// Every N days from `startDay` (1 = every day); 0 means use `weekdays`.
    var everyDays: Int = 0
    var startDay: Date = Calendar.current.startOfDay(for: Date())
    /// Minutes after midnight for its own reminder on its days (e.g. 540 = 9:00); nil = only the regular reminders.
    var remindAt: Int? = nil

    /// "9:00 AM".
    static func timeLabel(_ minutes: Int) -> String {
        var parts = DateComponents()
        parts.hour = minutes / 60
        parts.minute = minutes % 60
        let date = Calendar.current.date(from: parts) ?? Date()
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// "Every Friday · 9:00 AM".
    var fullLabel: String {
        remindAt.map { "\(scheduleLabel) · \(Self.timeLabel($0))" } ?? scheduleLabel
    }

    /// Monday-first weekday number (1…7) of a date.
    static func weekday(of date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) + 5) % 7 + 1
    }

    func isDue(on day: Date) -> Bool {
        let cal = Calendar.current
        let day = cal.startOfDay(for: day)
        if everyDays > 0 {
            let diff = cal.dateComponents([.day], from: cal.startOfDay(for: startDay), to: day).day ?? 0
            return diff >= 0 && diff % everyDays == 0
        }
        return weekdays.contains(Self.weekday(of: day))
    }

    static func dayName(_ weekday: Int) -> String {
        // Calendar symbols start on Sunday.
        Calendar(identifier: .gregorian).weekdaySymbols[weekday % 7]
    }

    /// "Every Friday", "Every day", "Mon and Thu", "Every 2 days".
    var scheduleLabel: String {
        if everyDays > 0 { return everyDays == 1 ? "Every day" : "Every \(everyDays) days" }
        if weekdays.count == 7 { return "Every day" }
        let names = weekdays.sorted().map { Self.dayName($0) }
        switch names.count {
        case 0: return "No days chosen"
        case 1: return "Every \(names[0])"
        default:
            let short = names.map { String($0.prefix(3)) }
            return short.dropLast().joined(separator: ", ") + " and " + short.last!
        }
    }
}

/// How far into a wird surah the person got on `day` (highest ayah read).
struct WirdProgress: Codable, Equatable {
    var day: Date
    var upTo: Int
}

struct AppState: Codable {
    var selectedSurahId: Int = 67        // Al-Mulk default
    var currentChunkIndex: Int = 0
    var totalAyahsRead: Int = 0
    var todayAyahsRead: Int = 0
    var lastReadDate: Date?
    var streakDays: Int = 0
    var longestStreak: Int = 0
    var isFirstLaunch: Bool = true

    var language: Language = .english
    var readingSpeed: ReadingSpeed = .normal
    var showTransliteration: Bool = true
    /// Secondary lines under the main text (the one matching `readIn` is always shown).
    var showArabic: Bool = true
    var showMeaning: Bool = true

    // Redesign additions
    var hasCompletedOnboarding: Bool = false
    var goal: ReadingGoal = .familiar
    /// The main, large text on the reading screen.
    var readIn: ReadIn = .arabic
    /// Completed passes through the selected surah (familiar / meaning goals).
    var timesThroughSurah: Int = 0
    var surahsCompleted: Int = 0
    /// Muraja'ah memory per ayah of the selected surah, keyed by ayah number.
    var reviewItems: [Int: ReviewItem] = [:]
    var totalReviews: Int = 0
    /// Calendar days (start of day) on which the person read, for the Progress heatmap: ayahs read that day.
    var dailyAyahs: [Date: Int] = [:]
    /// The wird, in reading order.
    var wird: [WirdItem] = []
    /// Today's progress per wird item id; older days are ignored.
    var wirdProgress: [Int: WirdProgress] = [:]
    var wirdsCompleted: Int = 0
    /// Tilawa Plus. Until purchases are built, only switchable in debug builds.
    var isPro: Bool = false
    /// Reading reminders: every `remindEveryHours` hours between `remindFrom` and `remindUntil` (hours; 24 = midnight).
    var remindersOn: Bool = true
    var remindEveryHours: Int = 2
    var remindFrom: Int = 8
    var remindUntil: Int = 22

    init() {}

    // Decode tolerantly so state saved by older app versions (without the new keys) still loads.
    private enum CodingKeys: String, CodingKey {
        case selectedSurahId, currentChunkIndex, totalAyahsRead, todayAyahsRead, lastReadDate,
             streakDays, longestStreak, isFirstLaunch, language, readingSpeed, showTransliteration,
             hasCompletedOnboarding, goal, readIn, showArabic, showMeaning,
             timesThroughSurah, surahsCompleted,
             reviewItems, totalReviews, dailyAyahs,
             wird, wirdProgress, wirdsCompleted, isPro,
             remindersOn, remindEveryHours, remindFrom, remindUntil
    }

    /// Keys only read from older saved state.
    private enum LegacyKeys: String, CodingKey { case meaningFirst }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppState()
        selectedSurahId = try c.decodeIfPresent(Int.self, forKey: .selectedSurahId) ?? d.selectedSurahId
        currentChunkIndex = try c.decodeIfPresent(Int.self, forKey: .currentChunkIndex) ?? d.currentChunkIndex
        totalAyahsRead = try c.decodeIfPresent(Int.self, forKey: .totalAyahsRead) ?? d.totalAyahsRead
        todayAyahsRead = try c.decodeIfPresent(Int.self, forKey: .todayAyahsRead) ?? d.todayAyahsRead
        lastReadDate = try c.decodeIfPresent(Date.self, forKey: .lastReadDate)
        streakDays = try c.decodeIfPresent(Int.self, forKey: .streakDays) ?? d.streakDays
        longestStreak = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? streakDays
        isFirstLaunch = try c.decodeIfPresent(Bool.self, forKey: .isFirstLaunch) ?? d.isFirstLaunch
        language = try c.decodeIfPresent(Language.self, forKey: .language) ?? d.language
        readingSpeed = try c.decodeIfPresent(ReadingSpeed.self, forKey: .readingSpeed) ?? d.readingSpeed
        showTransliteration = try c.decodeIfPresent(Bool.self, forKey: .showTransliteration) ?? d.showTransliteration
        // Existing users (who already used the old app) skip onboarding.
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? !isFirstLaunch
        goal = try c.decodeIfPresent(ReadingGoal.self, forKey: .goal) ?? d.goal
        // Older versions had a "meaning first" switch instead.
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let meaningFirst = try legacy.decodeIfPresent(Bool.self, forKey: .meaningFirst) ?? (goal == .meaning)
        readIn = try c.decodeIfPresent(ReadIn.self, forKey: .readIn) ?? (meaningFirst ? .english : .arabic)
        showArabic = try c.decodeIfPresent(Bool.self, forKey: .showArabic) ?? true
        showMeaning = try c.decodeIfPresent(Bool.self, forKey: .showMeaning) ?? true
        timesThroughSurah = try c.decodeIfPresent(Int.self, forKey: .timesThroughSurah) ?? 0
        surahsCompleted = try c.decodeIfPresent(Int.self, forKey: .surahsCompleted) ?? 0
        reviewItems = try c.decodeIfPresent([Int: ReviewItem].self, forKey: .reviewItems) ?? [:]
        totalReviews = try c.decodeIfPresent(Int.self, forKey: .totalReviews) ?? 0
        dailyAyahs = try c.decodeIfPresent([Date: Int].self, forKey: .dailyAyahs) ?? [:]
        wird = try c.decodeIfPresent([WirdItem].self, forKey: .wird) ?? []
        wirdProgress = try c.decodeIfPresent([Int: WirdProgress].self, forKey: .wirdProgress) ?? [:]
        wirdsCompleted = try c.decodeIfPresent(Int.self, forKey: .wirdsCompleted) ?? 0
        isPro = try c.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        remindersOn = try c.decodeIfPresent(Bool.self, forKey: .remindersOn) ?? true
        remindEveryHours = try c.decodeIfPresent(Int.self, forKey: .remindEveryHours) ?? 2
        remindFrom = try c.decodeIfPresent(Int.self, forKey: .remindFrom) ?? 8
        remindUntil = try c.decodeIfPresent(Int.self, forKey: .remindUntil) ?? 22
    }

    /// The reminder settings, compared to know when to reschedule.
    var reminderKey: [Int] {
        var key = [remindersOn ? 1 : 0, remindEveryHours, remindFrom, remindUntil, hasCompletedOnboarding ? 1 : 0, isPro ? 1 : 0]
        for item in wird {
            key += [item.id, item.surahId, item.everyDays, item.weekdays.reduce(0) { $0 | (1 << $1) }, item.remindAt ?? -1]
        }
        return key
    }
}

/// Switches for parts of the app that are built but not offered right now.
enum Features {
    /// Pausing other apps until you read (Screen Time / Family Controls). Off for now: reminders come first,
    /// and pausing returns later as an option.
    static let appPausing = false
}
