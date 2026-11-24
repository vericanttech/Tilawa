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

/// Memory state of one verse in muraja'ah mode (a simple Leitner box).
struct ReviewItem: Codable, Equatable {
    /// 0 = full text, 1 = fading, 2 = first word only, 3 = full recall.
    var stage: Int = 0
    var dueAt: Date = .distantPast
    var timesReviewed: Int = 0

    /// A verse counts as "strong" once it has been recalled from a blank screen.
    var isStrong: Bool { stage >= 3 && timesReviewed >= 4 }
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

    // Redesign additions
    var hasCompletedOnboarding: Bool = false
    var goal: ReadingGoal = .familiar
    /// When true, the English meaning is shown above the Arabic.
    var meaningFirst: Bool = false
    /// Completed passes through the selected surah (familiar / meaning goals).
    var timesThroughSurah: Int = 0
    var surahsCompleted: Int = 0
    /// Muraja'ah memory per ayah of the selected surah, keyed by ayah number.
    var reviewItems: [Int: ReviewItem] = [:]
    var totalReviews: Int = 0
    /// Calendar days (start of day) on which the person read, for the Progress heatmap: ayahs read that day.
    var dailyAyahs: [Date: Int] = [:]

    init() {}

    // Decode tolerantly so state saved by older app versions (without the new keys) still loads.
    private enum CodingKeys: String, CodingKey {
        case selectedSurahId, currentChunkIndex, totalAyahsRead, todayAyahsRead, lastReadDate,
             streakDays, longestStreak, isFirstLaunch, language, readingSpeed, showTransliteration,
             hasCompletedOnboarding, goal, meaningFirst, timesThroughSurah, surahsCompleted,
             reviewItems, totalReviews, dailyAyahs
    }

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
        meaningFirst = try c.decodeIfPresent(Bool.self, forKey: .meaningFirst) ?? (goal == .meaning)
        timesThroughSurah = try c.decodeIfPresent(Int.self, forKey: .timesThroughSurah) ?? 0
        surahsCompleted = try c.decodeIfPresent(Int.self, forKey: .surahsCompleted) ?? 0
        reviewItems = try c.decodeIfPresent([Int: ReviewItem].self, forKey: .reviewItems) ?? [:]
        totalReviews = try c.decodeIfPresent(Int.self, forKey: .totalReviews) ?? 0
        dailyAyahs = try c.decodeIfPresent([Date: Int].self, forKey: .dailyAyahs) ?? [:]
    }
}
