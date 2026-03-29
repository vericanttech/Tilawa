import Foundation

final class QuranService: ObservableObject {
    static let shared = QuranService()
    private(set) var surahs: [Surah] = []

    func load() {
        guard let url = Bundle.main.url(forResource: "tilawa_quran", withExtension: "json") else {
            print("Tilawa: tilawa_quran.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            surahs = try decoder.decode([Surah].self, from: data)
        } catch {
            print("Tilawa: failed to load Quran data: \(error)")
        }
    }

    func surah(id: Int) -> Surah? {
        surahs.first { $0.id == id }
    }

    func currentChunk(surahId: Int, chunkIndex: Int) -> (verses: [Verse], duration: Int)? {
        guard let s = surah(id: surahId), chunkIndex >= 0, chunkIndex < s.chunks.count else { return nil }
        let chunk = s.chunks[chunkIndex]
        let verses = chunk.ayahIds.compactMap { ayahId in s.verses.first { $0.id == ayahId } }
        return (verses, chunk.durationSeconds)
    }

    func search(_ query: String) -> [Surah] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return surahs }
        return surahs.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.nameArabic.contains(query) ||
            $0.transliteration.localizedCaseInsensitiveContains(q)
        }
    }
}
