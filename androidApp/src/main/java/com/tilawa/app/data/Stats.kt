package com.tilawa.app.data

import java.time.LocalDate

/** Reading, muraja'ah and streak rules. Same behaviour as the iOS StatsService. */
object Stats {
    private const val MINUTE = 60_000L
    private const val HOUR = 60 * MINUTE
    private const val DAY = 24 * HOUR

    fun today(): Long = LocalDate.now().toEpochDay()

    /** A finished reading pause. Returns the new state and whether it completed a pass through the surah. */
    fun recordRead(state: AppState, ayahCount: Int, chunkCount: Int): Pair<AppState, Boolean> {
        var next = state.currentChunkIndex + 1
        var times = state.timesThroughSurah
        var completed = state.surahsCompleted
        val finishedPass = next >= chunkCount.coerceAtLeast(1)
        if (finishedPass) {
            next = 0
            times += 1
            completed += 1
        }
        val updated = logDay(
            state.copy(
                currentChunkIndex = next,
                timesThroughSurah = times,
                surahsCompleted = completed,
                totalAyahsRead = state.totalAyahsRead + ayahCount,
                todayAyahsRead = state.todayAyahsRead + ayahCount,
            ),
            ayahCount,
        )
        return withStreak(updated) to finishedPass
    }

    /** Verses read outside the main surah (e.g. a wird): totals, history and streak only. */
    fun recordVerses(state: AppState, ayahCount: Int): AppState = withStreak(
        logDay(
            state.copy(
                totalAyahsRead = state.totalAyahsRead + ayahCount,
                todayAyahsRead = state.todayAyahsRead + ayahCount,
            ),
            ayahCount,
        ),
    )

    /** Most overdue verse, else the first never reviewed, else the one due soonest. */
    fun nextReviewVerse(surah: Surah, state: AppState, now: Long = System.currentTimeMillis()): Verse? {
        val items = state.reviewItems
        surah.verses
            .filter { items[it.id]?.let { item -> item.dueAt <= now } == true }
            .minByOrNull { items.getValue(it.id).dueAt }
            ?.let { return it }
        surah.verses.firstOrNull { it.id !in items }?.let { return it }
        return surah.verses.minByOrNull { items[it.id]?.dueAt ?: now }
    }

    /**
     * Muraja'ah is for a surah you've memorized, so a verse you haven't reviewed yet starts with
     * some words faded. The full verse (stage 0) only comes back after a miss.
     */
    const val NEW_VERSE_STAGE = 1

    fun reviewStage(verseId: Int, state: AppState): Int = state.reviewItems[verseId]?.stage ?: NEW_VERSE_STAGE

    fun recordReview(state: AppState, verseId: Int, recalled: Boolean, now: Long = System.currentTimeMillis()): AppState {
        val old = state.reviewItems[verseId] ?: ReviewItem(stage = NEW_VERSE_STAGE)
        val times = old.timesReviewed + 1
        val item = if (recalled) {
            val stage = (old.stage + 1).coerceAtMost(3)
            val interval = when (stage) {
                1 -> 30 * MINUTE
                2 -> 2 * HOUR
                else -> if (old.stage < 3) DAY else ((times - 3) * 2).coerceIn(2, 30) * DAY
            }
            ReviewItem(stage, now + interval, times)
        } else {
            ReviewItem((old.stage - 1).coerceAtLeast(0), now + 10 * MINUTE, times)
        }
        val updated = logDay(
            state.copy(
                reviewItems = state.reviewItems + (verseId to item),
                totalReviews = state.totalReviews + 1,
                totalAyahsRead = state.totalAyahsRead + 1,
                todayAyahsRead = state.todayAyahsRead + 1,
            ),
            1,
        )
        return withStreak(updated)
    }

    fun strongVerseCount(surah: Surah, state: AppState): Int =
        surah.verses.count { state.reviewItems[it.id]?.isStrong == true }

    fun versesDueToday(surah: Surah, state: AppState): List<Verse> {
        val endOfDay = LocalDate.now().plusDays(1).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
        return surah.verses
            .filter { (state.reviewItems[it.id]?.dueAt ?: Long.MAX_VALUE) < endOfDay }
            .sortedBy { state.reviewItems[it.id]?.dueAt ?: 0L }
    }

    /** Ayahs per day for the last [days] days, oldest first. */
    fun history(state: AppState, days: Int): List<Int> {
        val today = today()
        return (days - 1 downTo 0).map { state.dailyAyahs[today - it] ?: 0 }
    }

    private fun logDay(state: AppState, ayahs: Int): AppState {
        val today = today()
        val days = (state.dailyAyahs + (today to (state.dailyAyahs[today] ?: 0) + ayahs))
            .filterKeys { it >= today - 90 }
        return state.copy(dailyAyahs = days)
    }

    private fun withStreak(state: AppState): AppState {
        val today = today()
        val streak = when (state.lastReadEpochDay) {
            null -> 1
            today -> state.streakDays.coerceAtLeast(1)
            today - 1 -> state.streakDays + 1
            else -> 1
        }
        return state.copy(
            streakDays = streak,
            longestStreak = maxOf(state.longestStreak, streak),
            lastReadEpochDay = today,
        )
    }

    fun ordinal(n: Int): String {
        val suffix = when {
            n % 100 in 11..13 -> "th"
            n % 10 == 1 -> "st"
            n % 10 == 2 -> "nd"
            n % 10 == 3 -> "rd"
            else -> "th"
        }
        return "$n$suffix"
    }

    fun relativeDue(dueAt: Long, now: Long = System.currentTimeMillis()): String {
        val minutes = ((dueAt - now) / MINUTE).toInt()
        if (minutes < 60) return "in ${minutes.coerceAtLeast(1)} min"
        val zone = java.time.ZoneId.systemDefault()
        val dueDay = java.time.Instant.ofEpochMilli(dueAt).atZone(zone).toLocalDate().toEpochDay()
        return when (val days = dueDay - today()) {
            0L -> "later today"
            1L -> "tomorrow"
            else -> "in $days days"
        }
    }
}
