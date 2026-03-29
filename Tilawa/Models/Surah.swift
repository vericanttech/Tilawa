import Foundation

struct Surah: Codable, Identifiable {
    let id: Int
    let name: String
    let transliteration: String
    let nameArabic: String
    let type: String
    let totalVerses: Int
    let verses: [Verse]
    let chunks: [Chunk]

    enum CodingKeys: String, CodingKey {
        case id, name, transliteration, type, verses, chunks
        case nameArabic = "name_arabic"
        case totalVerses = "total_verses"
    }
}

struct Verse: Codable, Identifiable {
    let id: Int
    let text: String
    let transliteration: String
    let wordCount: Int
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id, text, transliteration
        case wordCount = "word_count"
        case durationSeconds = "duration_seconds"
    }
}

struct Chunk: Codable {
    let ayahIds: [Int]
    let durationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case ayahIds = "ayah_ids"
        case durationSeconds = "duration_seconds"
    }
}
