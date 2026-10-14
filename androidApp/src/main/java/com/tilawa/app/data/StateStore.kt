package com.tilawa.app.data

import android.content.Context
import java.time.LocalDate

class StateStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(): AppState {
        val today = LocalDate.now().toEpochDay()
        val lastDay = prefs.longOrNull("lastReadEpochDay")
        val savedTodayCount = prefs.getInt("todayAyahsRead", 0)
        return AppState(
            selectedSurahId = prefs.getInt("selectedSurahId", 36),
            currentChunkIndex = prefs.getInt("currentChunkIndex", 0),
            totalAyahsRead = prefs.getInt("totalAyahsRead", 0),
            todayAyahsRead = if (lastDay != null && lastDay < today) 0 else savedTodayCount,
            lastReadEpochDay = lastDay,
            streakDays = prefs.getInt("streakDays", 0),
            isFirstLaunch = prefs.getBoolean("isFirstLaunch", true),
            language = prefs.enum("language", Language.ENGLISH),
            readingSpeed = prefs.enum("readingSpeed", ReadingSpeed.NORMAL),
            showTransliteration = prefs.getBoolean("showTransliteration", true),
            lockDelay = prefs.enum("lockDelay", LockDelay.FIFTEEN_MINUTES),
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
            .putBoolean("isFirstLaunch", state.isFirstLaunch)
            .putString("language", state.language.name)
            .putString("readingSpeed", state.readingSpeed.name)
            .putBoolean("showTransliteration", state.showTransliteration)
            .putString("lockDelay", state.lockDelay.name)
            .apply()
    }

    fun recordRead(state: AppState, ayahCount: Int, chunkCount: Int): AppState {
        val today = LocalDate.now().toEpochDay()
        val streak = when (state.lastReadEpochDay) {
            null -> 1
            today -> state.streakDays
            today - 1 -> state.streakDays + 1
            else -> 1
        }
        return state.copy(
            currentChunkIndex = (state.currentChunkIndex + 1).mod(chunkCount.coerceAtLeast(1)),
            totalAyahsRead = state.totalAyahsRead + ayahCount,
            todayAyahsRead = state.todayAyahsRead + ayahCount,
            lastReadEpochDay = today,
            streakDays = streak,
        ).also(::save)
    }

    fun resetProgress(state: AppState): AppState = state.copy(
        currentChunkIndex = 0,
        totalAyahsRead = 0,
        todayAyahsRead = 0,
        lastReadEpochDay = null,
        streakDays = 0,
    ).also(::save)

    private inline fun <reified T : Enum<T>> android.content.SharedPreferences.enum(
        key: String,
        fallback: T,
    ): T = getString(key, null)?.let { runCatching { enumValueOf<T>(it) }.getOrNull() } ?: fallback

    private fun android.content.SharedPreferences.longOrNull(key: String): Long? =
        if (contains(key)) getLong(key, 0) else null

    private fun android.content.SharedPreferences.Editor.putLongOrRemove(key: String, value: Long?) =
        if (value == null) remove(key) else putLong(key, value)

    companion object { const val PREFS = "tilawa_preferences" }
}
