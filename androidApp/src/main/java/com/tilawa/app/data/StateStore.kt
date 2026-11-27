package com.tilawa.app.data

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

class StateStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(): AppState {
        val today = Stats.today()
        val lastDay = prefs.longOrNull("lastReadEpochDay")
        val isFirstLaunch = prefs.getBoolean("isFirstLaunch", true)
        return AppState(
            selectedSurahId = prefs.getInt("selectedSurahId", 67),
            currentChunkIndex = prefs.getInt("currentChunkIndex", 0),
            totalAyahsRead = prefs.getInt("totalAyahsRead", 0),
            todayAyahsRead = if (lastDay != null && lastDay < today) 0 else prefs.getInt("todayAyahsRead", 0),
            lastReadEpochDay = lastDay,
            streakDays = prefs.getInt("streakDays", 0),
            longestStreak = prefs.getInt("longestStreak", prefs.getInt("streakDays", 0)),
            isFirstLaunch = isFirstLaunch,
            // People who used the old version skip onboarding.
            hasCompletedOnboarding = prefs.getBoolean("hasCompletedOnboarding", !isFirstLaunch),
            goal = prefs.enum("goal", ReadingGoal.FAMILIAR),
            // Older versions had a "meaning first" switch.
            readIn = prefs.enum("readIn", if (prefs.getBoolean("meaningFirst", false)) ReadIn.ENGLISH else ReadIn.ARABIC),
            showArabic = prefs.getBoolean("showArabic", true),
            showMeaning = prefs.getBoolean("showMeaning", true),
            language = prefs.enum("language", Language.ENGLISH),
            readingSpeed = prefs.enum("readingSpeed", ReadingSpeed.NORMAL),
            showTransliteration = prefs.getBoolean("showTransliteration", true),
            lockDelay = prefs.enum("lockDelay", LockDelay.FIFTEEN_MINUTES),
            timesThroughSurah = prefs.getInt("timesThroughSurah", 0),
            surahsCompleted = prefs.getInt("surahsCompleted", 0),
            reviewItems = decodeReviews(prefs.getString("reviewItems", null)),
            totalReviews = prefs.getInt("totalReviews", 0),
            dailyAyahs = decodeDays(prefs.getString("dailyAyahs", null)),
            wird = decodeWird(prefs.getString("wird", null)),
            wirdProgress = decodeWirdProgress(prefs.getString("wirdProgress", null)),
            wirdsCompleted = prefs.getInt("wirdsCompleted", 0),
            isPro = prefs.getBoolean("isPro", false),
        )
    }

    fun save(state: AppState) {
        prefs.edit()
            .putInt("selectedSurahId", state.selectedSurahId)
            .putInt("currentChunkIndex", state.currentChunkIndex)
            .putInt("totalAyahsRead", state.totalAyahsRead)
            .putInt("todayAyahsRead", state.todayAyahsRead)
            .putLongOrRemove("lastReadEpochDay", state.lastReadEpochDay)
            .putInt("streakDays", state.streakDays)
            .putInt("longestStreak", state.longestStreak)
            .putBoolean("isFirstLaunch", state.isFirstLaunch)
            .putBoolean("hasCompletedOnboarding", state.hasCompletedOnboarding)
            .putString("goal", state.goal.name)
            .putString("readIn", state.readIn.name)
            .putBoolean("showArabic", state.showArabic)
            .putBoolean("showMeaning", state.showMeaning)
            .putString("language", state.language.name)
            .putString("readingSpeed", state.readingSpeed.name)
            .putBoolean("showTransliteration", state.showTransliteration)
            .putString("lockDelay", state.lockDelay.name)
            .putInt("timesThroughSurah", state.timesThroughSurah)
            .putInt("surahsCompleted", state.surahsCompleted)
            .putString("reviewItems", encodeReviews(state.reviewItems))
            .putInt("totalReviews", state.totalReviews)
            .putString("dailyAyahs", encodeDays(state.dailyAyahs))
            .putString("wird", encodeWird(state.wird))
            .putString("wirdProgress", encodeWirdProgress(state.wirdProgress))
            .putInt("wirdsCompleted", state.wirdsCompleted)
            .putBoolean("isPro", state.isPro)
            .apply()
    }

    fun resetProgress(state: AppState): AppState = state.copy(
        currentChunkIndex = 0,
        totalAyahsRead = 0,
        todayAyahsRead = 0,
        lastReadEpochDay = null,
        streakDays = 0,
        longestStreak = 0,
        timesThroughSurah = 0,
        surahsCompleted = 0,
        reviewItems = emptyMap(),
        totalReviews = 0,
        dailyAyahs = emptyMap(),
        wirdProgress = emptyMap(),
        wirdsCompleted = 0,
    ).also(::save)

    /** Words the "app is paused" notification uses (read by the accessibility service). */
    fun savePauseText(goal: ReadingGoal, detail: String) {
        prefs.edit().putString(KEY_PAUSE_GOAL, goal.name).putString(KEY_PAUSE_DETAIL, detail).apply()
    }

    private fun encodeReviews(items: Map<Int, ReviewItem>): String = JSONObject().apply {
        items.forEach { (id, item) ->
            put(id.toString(), JSONObject().put("stage", item.stage).put("dueAt", item.dueAt).put("times", item.timesReviewed))
        }
    }.toString()

    private fun decodeReviews(raw: String?): Map<Int, ReviewItem> = runCatching {
        val json = JSONObject(raw ?: return emptyMap())
        json.keys().asSequence().associate { key ->
            val o = json.getJSONObject(key)
            key.toInt() to ReviewItem(o.optInt("stage"), o.optLong("dueAt"), o.optInt("times"))
        }
    }.getOrDefault(emptyMap())

    private fun encodeWird(items: List<WirdItem>): String = org.json.JSONArray().apply {
        items.forEach { item ->
            put(
                JSONObject()
                    .put("id", item.id)
                    .put("surah", item.surahId)
                    .put("weekdays", org.json.JSONArray(item.weekdays.sorted()))
                    .put("everyDays", item.everyDays)
                    .put("startDay", item.startDay),
            )
        }
    }.toString()

    private fun decodeWird(raw: String?): List<WirdItem> = runCatching {
        val json = org.json.JSONArray(raw ?: return emptyList())
        (0 until json.length()).map { i ->
            val o = json.getJSONObject(i)
            val days = o.optJSONArray("weekdays")
            WirdItem(
                id = o.getLong("id"),
                surahId = o.getInt("surah"),
                weekdays = (0 until (days?.length() ?: 0)).map { days!!.getInt(it) }.toSet(),
                everyDays = o.optInt("everyDays"),
                startDay = o.optLong("startDay"),
            )
        }
    }.getOrDefault(emptyList())

    private fun encodeWirdProgress(progress: Map<Long, WirdProgress>): String = JSONObject().apply {
        progress.forEach { (id, p) -> put(id.toString(), JSONObject().put("day", p.day).put("upTo", p.upTo)) }
    }.toString()

    private fun decodeWirdProgress(raw: String?): Map<Long, WirdProgress> = runCatching {
        val json = JSONObject(raw ?: return emptyMap())
        json.keys().asSequence().associate { key ->
            val o = json.getJSONObject(key)
            key.toLong() to WirdProgress(o.getLong("day"), o.getInt("upTo"))
        }
    }.getOrDefault(emptyMap())

    private fun encodeDays(days: Map<Long, Int>): String =
        JSONObject().apply { days.forEach { (day, n) -> put(day.toString(), n) } }.toString()

    private fun decodeDays(raw: String?): Map<Long, Int> = runCatching {
        val json = JSONObject(raw ?: return emptyMap())
        json.keys().asSequence().associate { it.toLong() to json.getInt(it) }
    }.getOrDefault(emptyMap())

    private inline fun <reified T : Enum<T>> SharedPreferences.enum(key: String, fallback: T): T =
        getString(key, null)?.let { runCatching { enumValueOf<T>(it) }.getOrNull() } ?: fallback

    private fun SharedPreferences.longOrNull(key: String): Long? =
        if (contains(key)) getLong(key, 0) else null

    private fun SharedPreferences.Editor.putLongOrRemove(key: String, value: Long?) =
        if (value == null) remove(key) else putLong(key, value)

    companion object {
        const val PREFS = "tilawa_preferences"
        const val KEY_PAUSE_GOAL = "pauseGoal"
        const val KEY_PAUSE_DETAIL = "pauseDetail"
    }
}
