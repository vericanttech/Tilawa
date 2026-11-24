package com.tilawa.app.data

data class Verse(
    val id: Int,
    val text: String,
    val transliteration: String,
    val wordCount: Int,
    val durationSeconds: Int,
    /** English meaning. Null until the bundled data includes a licensed translation. */
    val translation: String? = null,
    /** Translator's footnotes for this verse, e.g. "[2] Allāh is a proper name…". */
    val footnotes: String? = null,
) {
    /** Arabic words, used by the fading muraja'ah view. */
    val words: List<String> get() = text.split(' ').filter { it.isNotBlank() }
}

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
    FIFTEEN_MINUTES(15 * 60_000L),
    THIRTY_MINUTES(30 * 60_000L),
    SIXTY_MINUTES(60 * 60_000L),
    TWO_HOURS(2 * 60 * 60_000L),
    NONE(null),
}

/** Why the person uses Tilawa. Shapes every pause. */
enum class ReadingGoal(
    val title: String,
    val summary: String,
    val nowLabel: String,
    val actionTitle: String,
) {
    /** Read one surah again and again until it feels familiar. */
    FAMILIAR(
        "Get familiar",
        "Read one surah again and again, until it feels like yours.",
        "Getting familiar",
        "Read now",
    ),
    /** Muraja'ah: keep a memorized surah fresh with fading-verse recall. */
    REVIEW(
        "Muraja’ah",
        "You’ve memorized it. Keep it fresh with verses that fade so you recall them.",
        "Muraja’ah",
        "Review now",
    ),
    /** English first, Arabic underneath. */
    MEANING(
        "Read with meaning",
        "English first, with the Arabic underneath. No Arabic reading needed.",
        "Reading with meaning",
        "Read now",
    ),
}

/** Muraja'ah progress for one verse. Stage 0 = full text, 1 = some words faded, 2 = first word only, 3 = from memory. */
data class ReviewItem(
    val stage: Int = 0,
    val dueAt: Long = 0L,
    val timesReviewed: Int = 0,
) {
    val isStrong: Boolean get() = stage >= 3 && timesReviewed >= 4
}

data class AppState(
    val selectedSurahId: Int = 67,
    val currentChunkIndex: Int = 0,
    val totalAyahsRead: Int = 0,
    val todayAyahsRead: Int = 0,
    val lastReadEpochDay: Long? = null,
    val streakDays: Int = 0,
    val longestStreak: Int = 0,
    val isFirstLaunch: Boolean = true,
    val hasCompletedOnboarding: Boolean = false,
    val goal: ReadingGoal = ReadingGoal.FAMILIAR,
    val meaningFirst: Boolean = false,
    val language: Language = Language.ENGLISH,
    val readingSpeed: ReadingSpeed = ReadingSpeed.NORMAL,
    val showTransliteration: Boolean = true,
    val lockDelay: LockDelay = LockDelay.FIFTEEN_MINUTES,
    val timesThroughSurah: Int = 0,
    val surahsCompleted: Int = 0,
    val reviewItems: Map<Int, ReviewItem> = emptyMap(),
    val totalReviews: Int = 0,
    /** Ayahs read per day (epoch day → count), last ~90 days. */
    val dailyAyahs: Map<Long, Int> = emptyMap(),
)

data class GuardedApp(val packageName: String, val label: String)

/** What the done screen shows after a pause. */
data class DoneInfo(
    val headline: String,
    val chip: String,
    val cardLabel: String,
    val cardText: String,
    val cardTextIsArabic: Boolean,
    val cardRef: String,
)
