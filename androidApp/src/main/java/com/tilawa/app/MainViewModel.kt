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
import com.tilawa.app.data.ReadIn
import com.tilawa.app.data.ReadingGoal
import com.tilawa.app.data.StateStore
import com.tilawa.app.data.Stats
import com.tilawa.app.data.Surah
import com.tilawa.app.data.Verse
import com.tilawa.app.data.Wird
import com.tilawa.app.data.WirdItem

/** One page of reading in a pause: a few verses of the main surah, or of a wird surah. */
data class Segment(val surah: Surah, val wirdId: Long?, val verses: List<Verse>)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val stateStore = StateStore(application)
    val quran = QuranRepository(application)
    val appGuard = AppGuardRepository(application)

    var state by mutableStateOf(stateStore.load())
        private set
    /** Package that sent the person here (or [MANUAL_GATE]); null when no pause is showing. */
    var gatePackage by mutableStateOf<String?>(null)
        private set
    /** The wird this pause reads, or null for the main surah. */
    var gateWirdId by mutableStateOf<Long?>(null)
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
    /** Read with meaning starts in English; leaving it goes back to Arabic. A reader who picked transliteration keeps it. */
    fun setGoal(goal: ReadingGoal) = update {
        val readIn = when {
            goal == ReadingGoal.MEANING -> ReadIn.ENGLISH
            it.readIn == ReadIn.ENGLISH -> ReadIn.ARABIC
            else -> it.readIn
        }
        it.copy(goal = goal, readIn = readIn)
    }

    fun selectSurah(id: Int) {
        if (id == state.selectedSurahId) return
        update { it.copy(selectedSurahId = id, currentChunkIndex = 0, timesThroughSurah = 0, reviewItems = emptyMap()) }
    }

    /**
     * Opens a pause. Pauses from a paused app (or its notification) read today's wird first, if one is due;
     * "Read now" on Today reads the main surah, and a wird card passes its own [wirdId].
     */
    fun showGate(packageName: String?, wirdId: Long? = null, useWird: Boolean = packageName != null) {
        done = null
        gatePackage = packageName ?: MANUAL_GATE
        gateWirdId = wirdId ?: if (useWird) Wird.current(state, quran)?.id else null
    }

    fun dismissGate() { gatePackage = null; gateWirdId = null }
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

    // MARK: Reading sessions (a pause, plus any "Keep reading")

    /** The first page of this pause. */
    fun firstSegment(): Segment? =
        gateWirdId?.let { wirdSegment(it, after = null) } ?: mainSegment(state.currentChunkIndex)

    /**
     * What "Keep reading" shows after [after]: the rest of that wird surah, then the next wird due today,
     * then the main surah (not in Muraja'ah, which reviews one verse at a time).
     */
    fun nextSegment(after: Segment): Segment? {
        val lastId = after.verses.lastOrNull()?.id ?: 0
        if (after.wirdId != null) {
            wirdSegment(after.wirdId, after = lastId)?.let { return it }
            Wird.dueToday(state)
                .filter { it.id != after.wirdId }
                .firstNotNullOfOrNull { wirdSegment(it.id, after = null) }
                ?.let { return it }
        }
        if (state.goal == ReadingGoal.REVIEW) return null
        val main = surah ?: return null
        if (after.wirdId != null) return mainSegment(state.currentChunkIndex)
        val index = main.chunks.indexOfFirst { lastId in it.ayahIds }
        return mainSegment(if (index < 0) state.currentChunkIndex else (index + 1) % main.chunks.size.coerceAtLeast(1))
    }

    /** Counts [segment] as read. Returns the surah name if this finished it (a pass, or today's wird). */
    fun recordSegment(segment: Segment): String? {
        if (segment.wirdId != null) {
            val item = state.wird.firstOrNull { it.id == segment.wirdId } ?: return null
            val (updated, finished) = Wird.record(state, item, segment.surah, segment.verses)
            update { updated }
            return segment.surah.name.takeIf { finished }
        }
        val (updated, finishedPass) = Stats.recordRead(state, segment.verses.size, segment.surah.chunks.size)
        update { updated }
        return segment.surah.name.takeIf { finishedPass }
    }

    /** Ends the pause after [read] pages (already recorded) and shows the done screen. */
    fun finishSession(read: List<Segment>, finished: List<String>) {
        val last = read.lastOrNull() ?: return dismissGate()
        val count = read.sumOf { it.verses.size }
        val chip = when {
            finished.isNotEmpty() -> "Finished ${finished.last()}"
            last.wirdId != null -> {
                val item = state.wird.firstOrNull { it.id == last.wirdId }
                val upTo = item?.let { Wird.upTo(state, it) } ?: last.verses.last().id
                "${last.surah.name} $upTo/${last.surah.totalVerses}"
            }
            state.goal == ReadingGoal.FAMILIAR -> "${last.surah.name} · ${Stats.ordinal(state.timesThroughSurah + 1)} time through"
            else -> "${last.surah.name} ${last.verses.last().id}/${last.surah.totalVerses}"
        }
        val keep = last.verses.lastOrNull { it.translation != null } ?: last.verses.lastOrNull()
        finish(
            DoneInfo(
                headline = if (count == 1) "1 verse read" else "$count verses read",
                chip = chip,
                cardLabel = "Take with you",
                cardText = keep?.translation?.let { "“$it”" } ?: keep?.text.orEmpty(),
                cardTextIsArabic = keep?.translation == null,
                cardRef = keep?.let { "${last.surah.name} ${last.surah.id}:${it.id}" }.orEmpty(),
            ),
        )
    }

    private fun mainSegment(chunkIndex: Int): Segment? {
        val main = surah ?: return null
        val chunk = main.chunks.getOrNull(chunkIndex) ?: main.chunks.firstOrNull() ?: return null
        val verses = chunk.ayahIds.mapNotNull { id -> main.verses.firstOrNull { it.id == id } }
        return Segment(main, null, verses).takeIf { verses.isNotEmpty() }
    }

    /** Next page of a wird surah, after ayah [after] (or after today's progress when null). */
    private fun wirdSegment(id: Long, after: Int?): Segment? {
        val item = state.wird.firstOrNull { it.id == id } ?: return null
        val wirdSurah = quran.surah(item.surahId) ?: return null
        val from = maxOf(after ?: 0, Wird.upTo(state, item))
        val verses = Wird.nextVerses(wirdSurah, from)
        return Segment(wirdSurah, id, verses).takeIf { verses.isNotEmpty() }
    }

    // MARK: Wird

    fun addWird(surahId: Int, weekdays: Set<Int>, everyDays: Int) {
        if (!Wird.canAdd(state)) return
        val item = WirdItem(System.currentTimeMillis(), surahId, weekdays, everyDays, Stats.today())
        update { it.copy(wird = it.wird + item) }
    }

    fun updateWird(item: WirdItem) = update { s -> s.copy(wird = s.wird.map { if (it.id == item.id) item else it }) }

    fun removeWird(id: Long) = update { s -> s.copy(wird = s.wird.filterNot { it.id == id }, wirdProgress = s.wirdProgress - id) }

    fun moveWird(id: Long, by: Int) = update { s ->
        val list = s.wird.toMutableList()
        val i = list.indexOfFirst { it.id == id }
        val j = (i + by).coerceIn(0, list.lastIndex)
        if (i >= 0 && i != j) list.add(j, list.removeAt(i))
        s.copy(wird = list)
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
        Wird.current(state, quran)?.let { item ->
            val wirdSurah = quran.surah(item.surahId) ?: return@let
            val verses = Wird.nextVerses(wirdSurah, Wird.upTo(state, item))
            val count = if (verses.size == 1) "1 verse" else "${verses.size} verses"
            stateStore.savePauseText(ReadingGoal.FAMILIAR, "Today’s wird: read $count of ${wirdSurah.name} to open it.")
            return
        }
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
