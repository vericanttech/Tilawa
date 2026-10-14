package com.tilawa.app.data

import android.content.Context
import org.json.JSONArray

class QuranRepository(context: Context) {
    val surahs: List<Surah> by lazy {
        context.assets.open("tilawa_quran.json").bufferedReader().use { reader ->
            parseSurahs(JSONArray(reader.readText()))
        }
    }

    fun surah(id: Int): Surah? = surahs.firstOrNull { it.id == id }

    fun search(query: String): List<Surah> {
        val term = query.trim()
        if (term.isEmpty()) return surahs
        return surahs.filter {
            it.name.contains(term, ignoreCase = true) ||
                it.transliteration.contains(term, ignoreCase = true) ||
                it.nameArabic.contains(term)
        }
    }

    private fun parseSurahs(root: JSONArray): List<Surah> = buildList {
        for (i in 0 until root.length()) {
            val item = root.getJSONObject(i)
            val versesJson = item.getJSONArray("verses")
            val verses = buildList {
                for (v in 0 until versesJson.length()) {
                    val verse = versesJson.getJSONObject(v)
                    add(
                        Verse(
                            id = verse.getInt("id"),
                            text = verse.getString("text"),
                            transliteration = verse.optString("transliteration"),
                            wordCount = verse.getInt("word_count"),
                            durationSeconds = verse.getInt("duration_seconds"),
                        ),
                    )
                }
            }
            val chunksJson = item.getJSONArray("chunks")
            val chunks = buildList {
                for (c in 0 until chunksJson.length()) {
                    val chunk = chunksJson.getJSONObject(c)
                    val idsJson = chunk.getJSONArray("ayah_ids")
                    add(
                        Chunk(
                            ayahIds = List(idsJson.length()) { idsJson.getInt(it) },
                            durationSeconds = chunk.getInt("duration_seconds"),
                        ),
                    )
                }
            }
            add(
                Surah(
                    id = item.getInt("id"),
                    name = item.getString("name"),
                    transliteration = item.getString("transliteration"),
                    nameArabic = item.getString("name_arabic"),
                    type = item.getString("type"),
                    totalVerses = item.getInt("total_verses"),
                    verses = verses,
                    chunks = chunks,
                ),
            )
        }
    }
}
