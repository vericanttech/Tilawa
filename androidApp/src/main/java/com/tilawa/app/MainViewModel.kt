package com.tilawa.app

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.tilawa.app.blocking.AppBlockAccessibilityService
import com.tilawa.app.blocking.AppGuardRepository
import com.tilawa.app.data.AppState
import com.tilawa.app.data.DoneInfo
import com.tilawa.app.data.GuardedApp
import com.tilawa.app.data.QuranRepository
import com.tilawa.app.data.ReadingGoal
import com.tilawa.app.data.StateStore
import com.tilawa.app.data.Stats
import com.tilawa.app.data.Surah
import com.tilawa.app.data.Verse

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val stateStore = StateStore(application)
    val quran = QuranRepository(application)
    val appGuard = AppGuardRepository(application)

    var state by mutableStateOf(stateStore.load())
        private set
    /** Package that sent the person here (or [MANUAL_GATE]); null when no pause is showing. */
    var gatePackage by mutableStateOf<String?>(null)
        private set
    /** Set after a pause is finished: shows the done screen. */
    var done by mutableStateOf<DoneInfo?>(null)
        private set
    var installedApps by mutableStateOf<List<GuardedApp>>(emptyList())
        private set
    var guardedPackages by mutableStateOf(appGuard.guardedPackages())
        private set

    init { writePauseText() }

    val surah: Surah? get() = quran.surah(state.selectedSurahId)

    fun update(transform: (AppState) -> AppState) {
        state = transform(state)
        stateStore.save(state)
        writePauseText()
    }

    fun completeOnboarding() = update { it.copy(hasCompletedOnboarding = true, isFirstLaunch = false) }
    fun setGoal(goal: ReadingGoal) = update { it.copy(goal = goal, meaningFirst = goal == ReadingGoal.MEANING) }

    fun selectSurah(id: Int) {
        if (id == state.selectedSurahId) return
        update { it.copy(selectedSurahId = id, currentChunkIndex = 0, timesThroughSurah = 0, reviewItems = emptyMap()) }
    }

    fun showGate(packageName: String?) {
        done = null
        gatePackage = packageName ?: MANUAL_GATE
    }

    fun dismissGate() { gatePackage = null }
    fun refreshApps() { installedApps = appGuard.launcherApps() }

    fun toggleGuard(packageName: String, enabled: Boolean) {
        appGuard.setGuarded(packageName, enabled)
        guardedPackages = appGuard.guardedPackages()
    }

    val isManualGate: Boolean get() = gatePackage == MANUAL_GATE
    val targetApp: String? get() = gatePackage?.takeUnless { it == MANUAL_GATE }

    fun appLabel(packageName: String): String = runCatching {
        val pm = getApplication<Application>().packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    }.getOrDefault("your app")

    /** Get familiar / Read with meaning: the person finished reading [verses]. */
    fun finishReading(verses: List<Verse>) {
        val surah = surah ?: return
        val pass = state.timesThroughSurah + 1
        val (updated, finishedPass) = Stats.recordRead(state, verses.size, surah.chunks.size)
        update { updated }
        val upTo = verses.lastOrNull()?.id ?: 0
        val chip = when {
            finishedPass -> "Finished ${surah.name} · $pass×"
            state.goal == ReadingGoal.FAMILIAR -> "${surah.name} · ${Stats.ordinal(pass)} time through"
            else -> "${surah.name} $upTo/${surah.totalVerses}"
        }
        val keep = verses.lastOrNull { it.translation != null } ?: verses.lastOrNull()
        finish(
            DoneInfo(
                headline = if (verses.size == 1) "1 verse read" else "${verses.size} verses read",
                chip = chip,
                cardLabel = "Take with you",
                cardText = keep?.translation?.let { "“$it”" } ?: keep?.text.orEmpty(),
                cardTextIsArabic = keep?.translation == null,
                cardRef = keep?.let { "${surah.name} ${surah.id}:${it.id}" }.orEmpty(),
            ),
        )
    }

    /** Muraja'ah: the person recalled (or asked to see again) one verse. */
    fun finishReview(verse: Verse, recalled: Boolean) {
        val surah = surah ?: return
        update { Stats.recordReview(it, verse.id, recalled) }
        val now = System.currentTimeMillis()
        val upcoming = state.reviewItems.entries
            .filter { it.value.dueAt > now }
            .sortedBy { it.value.dueAt }
            .take(2)
            .joinToString("\n") { "Ayah ${it.key} · ${Stats.relativeDue(it.value.dueAt)}" }
        finish(
            DoneInfo(
                headline = if (recalled) "Ayah ${verse.id} reviewed" else "We’ll bring ayah ${verse.id} back soon",
                chip = "${Stats.strongVerseCount(surah, state)} of ${surah.totalVerses} strong",
                cardLabel = "Coming up next",
                cardText = upcoming.ifEmpty { "Ayah ${verse.id} · soon" },
                cardTextIsArabic = false,
                cardRef = "Spaced out so every verse stays fresh",
            ),
        )
    }

    private fun finish(info: DoneInfo) {
        appGuard.beginUnlock(targetApp, state.lockDelay.millis)
        done = info
    }

    /** Done screen button: open the app that was paused (if any) and go back to Today. */
    fun closeDone() {
        val target = targetApp
        done = null
        gatePackage = null
        if (target != null) {
            val app = getApplication<Application>()
            app.packageManager.getLaunchIntentForPackage(target)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                app.startActivity(it)
            }
        }
    }

    fun resetProgress() {
        state = stateStore.resetProgress(state)
        writePauseText()
    }

    fun accessibilityEnabled(): Boolean {
        val context = getApplication<Application>()
        val globallyEnabled = Settings.Secure.getInt(context.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1
        if (!globallyEnabled) return false
        val expected = ComponentName(context, AppBlockAccessibilityService::class.java).flattenToString()
        return Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?.split(':')
            ?.any { it.equals(expected, ignoreCase = true) } == true
    }

    /** Duration of the current reading pause, in seconds. */
    fun readingSeconds(verses: List<Verse>): Int {
        val base = verses.sumOf { it.wordCount } * state.readingSpeed.secondsPerWord
        val withMeaning = if (state.goal == ReadingGoal.MEANING) base * 1.6 else base
        return withMeaning.toInt().coerceAtLeast(5)
    }

    fun currentVerses(): List<Verse> {
        val surah = surah ?: return emptyList()
        val chunk = surah.chunks.getOrNull(state.currentChunkIndex) ?: surah.chunks.firstOrNull() ?: return emptyList()
        return chunk.ayahIds.mapNotNull { id -> surah.verses.firstOrNull { it.id == id } }
    }

    private fun writePauseText() {
        val surah = surah ?: return
        val detail = when (state.goal) {
            ReadingGoal.REVIEW -> Stats.nextReviewVerse(surah, state)
                ?.let { "Quick muraja’ah: recall ${surah.name}, ayah ${it.id}. About 15 seconds." }
                ?: "Quick muraja’ah of ${surah.name}."
            else -> {
                val verses = currentVerses()
                val count = if (verses.size == 1) "1 verse" else "${verses.size} verses"
                val meaning = if (state.goal == ReadingGoal.MEANING) ", with meaning," else ""
                val seconds = (readingSeconds(verses) / 5.0).let { Math.round(it).toInt() * 5 }.coerceAtLeast(5)
                "Read $count of ${surah.name}$meaning to open it. About $seconds seconds."
            }
        }
        stateStore.savePauseText(state.goal, detail)
    }

    companion object { const val MANUAL_GATE = "__manual__" }
}
