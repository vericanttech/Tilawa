package com.tilawa.app.data

data class Verse(
    val id: Int,
    val text: String,
    val transliteration: String,
    val wordCount: Int,
    val durationSeconds: Int,
)

data class Chunk(val ayahIds: List<Int>, val durationSeconds: Int)

data class Surah(
    val id: Int,
    val name: String,
    val transliteration: String,
    val nameArabic: String,
    val type: String,
    val totalVerses: Int,
    val verses: List<Verse>,
    val chunks: List<Chunk>,
)

enum class Language { ENGLISH, FRENCH, ARABIC }
enum class ReadingSpeed(val secondsPerWord: Double) { SLOW(.85), NORMAL(.65), FAST(.45) }
enum class LockDelay(val millis: Long?) {
    ONE_MINUTE(60_000L),
    FIFTEEN_MINUTES(15 * 60_000L),
    THIRTY_MINUTES(30 * 60_000L),
    SIXTY_MINUTES(60 * 60_000L),
    TWO_HOURS(2 * 60 * 60_000L),
    NONE(null),
}

data class AppState(
    val selectedSurahId: Int = 36,
    val currentChunkIndex: Int = 0,
    val totalAyahsRead: Int = 0,
    val todayAyahsRead: Int = 0,
    val lastReadEpochDay: Long? = null,
    val streakDays: Int = 0,
    val isFirstLaunch: Boolean = true,
    val language: Language = Language.ENGLISH,
    val readingSpeed: ReadingSpeed = ReadingSpeed.NORMAL,
    val showTransliteration: Boolean = true,
    val lockDelay: LockDelay = LockDelay.FIFTEEN_MINUTES,
)

data class GuardedApp(val packageName: String, val label: String)
