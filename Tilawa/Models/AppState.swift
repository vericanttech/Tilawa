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

struct AppState: Codable {
    var selectedSurahId: Int = 36        // Ya-Sin default
    var currentChunkIndex: Int = 0
    var totalAyahsRead: Int = 0
    var todayAyahsRead: Int = 0
    var lastReadDate: Date?
    var streakDays: Int = 0
    var isFirstLaunch: Bool = true

    var language: Language = .english
    var readingSpeed: ReadingSpeed = .normal
    var showTransliteration: Bool = true
}
