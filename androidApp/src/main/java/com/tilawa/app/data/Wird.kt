package com.tilawa.app.data

/** Wird (الورد) rules: what's due today, how far the person got, and recording reading. */
object Wird {
    /** Free users keep one wird; more is Tilawa Plus. */
    const val FREE_LIMIT = 1

    /** One-tap suggestions for the common ones. */
    data class Preset(val surahId: Int, val weekdays: Set<Int> = emptySet(), val everyDays: Int = 0, val note: String)

    val presets = listOf(
        Preset(18, weekdays = setOf(5), note = "Al-Kahf on Fridays"),
        Preset(67, everyDays = 1, note = "Al-Mulk every night"),
        Preset(36, everyDays = 2, note = "Ya-Sin every 2 days"),
        Preset(56, everyDays = 1, note = "Al-Waqi'ah every night"),
        Preset(32, everyDays = 1, note = "As-Sajdah every night"),
    )

    fun canAdd(state: AppState): Boolean = state.isPro || state.wird.size < FREE_LIMIT

    /** Items that count: all of them with Plus, otherwise the first [FREE_LIMIT]. */
    fun activeItems(state: AppState): List<WirdItem> =
        if (state.isPro) state.wird else state.wird.take(FREE_LIMIT)

    fun dueToday(state: AppState, day: Long = Stats.today()): List<WirdItem> =
        activeItems(state).filter { it.isDue(day) }

    /** Highest ayah read today for [item]; 0 if not started. */
    fun upTo(state: AppState, item: WirdItem, day: Long = Stats.today()): Int =
        state.wirdProgress[item.id]?.takeIf { it.day == day }?.upTo ?: 0

    fun isFinished(state: AppState, item: WirdItem, surah: Surah, day: Long = Stats.today()): Boolean =
        upTo(state, item, day) >= surah.totalVerses

    /** The wird pauses read right now: the first one due today that isn't finished, in list order. */
    fun current(state: AppState, quran: QuranRepository, day: Long = Stats.today()): WirdItem? =
        dueToday(state, day).firstOrNull { item -> quran.surah(item.surahId)?.let { !isFinished(state, item, it, day) } == true }

    /** The next small piece of [surah] after ayah [upTo], using the same chunks as normal pauses. */
    fun nextVerses(surah: Surah, upTo: Int): List<Verse> {
        // The chunk holding the next unread ayah, starting from that ayah, so nothing is skipped.
        val chunk = surah.chunks.firstOrNull { (it.ayahIds.lastOrNull() ?: 0) > upTo } ?: return emptyList()
        return chunk.ayahIds.filter { it > upTo }.mapNotNull { id -> surah.verses.firstOrNull { it.id == id } }
    }

    /** The person read [verses] of [item]'s surah. Returns the new state and whether that finished today's wird for it. */
    fun record(state: AppState, item: WirdItem, surah: Surah, verses: List<Verse>, day: Long = Stats.today()): Pair<AppState, Boolean> {
        val before = upTo(state, item, day)
        val after = maxOf(before, verses.maxOfOrNull { it.id } ?: before)
        val finished = before < surah.totalVerses && after >= surah.totalVerses
        val progress = (state.wirdProgress.filterValues { it.day == day } + (item.id to WirdProgress(day, after)))
        val updated = Stats.recordVerses(state, verses.size).copy(
            wirdProgress = progress,
            wirdsCompleted = state.wirdsCompleted + if (finished) 1 else 0,
        )
        return updated to finished
    }

    /** Next day [item] is due after today, for "Next: Friday". */
    fun nextDueDay(item: WirdItem, from: Long = Stats.today()): Long? =
        (1L..60L).map { from + it }.firstOrNull { item.isDue(it) }
}
