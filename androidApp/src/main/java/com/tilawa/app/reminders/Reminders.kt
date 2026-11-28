package com.tilawa.app.reminders

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.util.Log
import com.tilawa.app.MainActivity
import com.tilawa.app.R
import com.tilawa.app.data.AppState
import com.tilawa.app.data.QuranRepository
import com.tilawa.app.data.ReadIn
import com.tilawa.app.data.ReadingGoal
import com.tilawa.app.data.StateStore
import com.tilawa.app.data.Stats
import com.tilawa.app.data.Verse
import com.tilawa.app.data.Wird
import java.time.LocalTime
import java.time.ZonedDateTime
import kotlin.concurrent.thread

/**
 * Gentle reading reminders: every few hours inside the person's waking window, a notification with the next
 * few verses. Scheduled on the phone (no server); reading in the app pushes the next one a full interval out.
 */
object Reminders {
    private const val TAG = "TilawaReminders"
    private const val CHANNEL_ID = "tilawa_reminders"
    private const val NOTIFICATION_ID = 4108
    private const val KEY_NEXT_AT = "reminderNextAt"
    private const val EXTRA_WIRD = "wirdId"

    /** The next time a wird has its own reminder (on its days, skipping one already read today). */
    fun nextWirdAt(state: AppState, quran: QuranRepository?, now: ZonedDateTime = ZonedDateTime.now()): Pair<ZonedDateTime, Long>? {
        val today = now.toLocalDate()
        return (0L..8L).asSequence().flatMap { offset ->
            val date = today.plusDays(offset)
            val day = date.toEpochDay()
            Wird.activeItems(state).asSequence().filter { it.remindAt != null && it.isDue(day) }.mapNotNull { item ->
                val minutes = item.remindAt ?: return@mapNotNull null
                val at = date.atTime(minutes / 60, minutes % 60).atZone(now.zone)
                if (!at.isAfter(now)) return@mapNotNull null
                if (offset == 0L) {
                    val surah = quran?.surah(item.surahId)
                    if (surah != null && Wird.isFinished(state, item, surah, day)) return@mapNotNull null
                }
                at to item.id
            }
        }.minByOrNull { it.first }
    }

    /** The next reminder after [from], inside the window. */
    fun nextAt(state: AppState, from: ZonedDateTime = ZonedDateTime.now()): ZonedDateTime {
        val candidate = from.plusHours(state.remindEveryHours.toLong()).withSecond(0).withNano(0)
        val day = candidate.toLocalDate()
        val start = day.atTime(LocalTime.of(state.remindFrom.coerceIn(0, 23), 0)).atZone(candidate.zone)
        val endHour = state.remindUntil.coerceIn(1, 24)
        val end = if (endHour == 24) day.plusDays(1).atStartOfDay(candidate.zone) else day.atTime(endHour, 0).atZone(candidate.zone)
        return when {
            candidate.isBefore(start) -> start            // night: first thing in the morning
            !candidate.isBefore(end) -> start.plusDays(1) // past the window: tomorrow morning
            else -> candidate
        }
    }

    /** Sets the next reminder a full interval from now (after reading, opening the app, or a reminder firing). */
    fun reschedule(context: Context, state: AppState = StateStore(context).load()) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        alarms.cancel(alarmIntent(context, null))
        val prefs = context.getSharedPreferences(StateStore.PREFS, Context.MODE_PRIVATE)
        // The regular reminder, or a wird's own time if that comes first (that one rings even with regular ones off).
        val regular = if (state.remindersOn) nextAt(state) else null
        val wird = nextWirdAt(state, QuranRepository(context))
        val useWird = wird != null && (regular == null || wird.first.isBefore(regular))
        val next = if (useWird) wird!!.first else regular
        if (next == null || !state.hasCompletedOnboarding) {
            prefs.edit().remove(KEY_NEXT_AT).apply()
            return
        }
        val pending = alarmIntent(context, if (useWird) wird!!.second else null)
        val at = next.toInstant().toEpochMilli()
        // Within 10 minutes is close enough for a gentle reminder, and needs no exact-alarm permission
        // (a plain inexact alarm was allowed to drift by up to an hour).
        alarms.setWindow(AlarmManager.RTC_WAKEUP, at, 10 * 60_000L, pending)
        prefs.edit().putLong(KEY_NEXT_AT, at).apply()
        Log.i(TAG, "Next reminder at ${java.time.Instant.ofEpochMilli(at)}")
    }

    /** Makes sure a reminder is waiting (e.g. after the phone restarts or the alarm was lost). */
    fun ensureScheduled(context: Context) {
        val state = StateStore(context).load()
        val next = context.getSharedPreferences(StateStore.PREFS, Context.MODE_PRIVATE).getLong(KEY_NEXT_AT, 0)
        if (next < System.currentTimeMillis()) reschedule(context, state)
    }

    /** When the next reminder comes, or null if they're off. */
    fun nextTime(context: Context): Long? =
        context.getSharedPreferences(StateStore.PREFS, Context.MODE_PRIVATE).getLong(KEY_NEXT_AT, 0).takeIf { it > 0 }

    /** Posts a reminder now with the next verses to read. */
    fun post(context: Context, wirdId: Long? = null) {
        val state = StateStore(context).load()
        val quran = QuranRepository(context)
        val content = wirdId?.let { wirdContent(state, quran, it) } ?: content(state, quran) ?: return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Reading reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "A few verses every few hours"
            },
        )
        val open = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            Intent(context, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_REMINDER, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(content.title)
            .setContentText(content.text)
            .setStyle(Notification.BigTextStyle().bigText(content.bigText))
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setColor(0xFF1D6B62.toInt())
            .setAutoCancel(true)
            .addAction(Notification.Action.Builder(Icon.createWithResource(context, R.drawable.ic_notification), content.action, open).build())
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun clear(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
    }

    private data class Content(val title: String, val text: String, val bigText: String, val action: String)

    /** A wird's own reminder at its time. */
    private fun wirdContent(state: AppState, quran: QuranRepository, id: Long): Content? {
        val item = state.wird.firstOrNull { it.id == id } ?: return null
        val surah = quran.surah(item.surahId) ?: return null
        val upTo = Wird.upTo(state, item)
        val verses = Wird.nextVerses(surah, upTo)
        if (verses.isEmpty()) return null
        val title = if (upTo == 0) "Time for your wird · ${surah.name}" else "Continue your wird · ${surah.name}"
        return reading(title, surah.name, surah.id, verses, state)
    }

    /** The verses the reminder offers: today's wird first, else the main surah (a recall in muraja'ah). */
    private fun content(state: AppState, quran: QuranRepository): Content? {
        Wird.current(state, quran)?.let { item ->
            val surah = quran.surah(item.surahId) ?: return@let
            val verses = Wird.nextVerses(surah, Wird.upTo(state, item))
            if (verses.isEmpty()) return@let
            return reading("Today’s wird · ${surah.name}", surah.name, surah.id, verses, state)
        }
        val surah = quran.surah(state.selectedSurahId) ?: return null
        if (state.goal == ReadingGoal.REVIEW) {
            val verse = Stats.nextReviewVerse(surah, state) ?: return null
            val text = "Can you recall ayah ${verse.id}? About 15 seconds."
            return Content("Quick muraja’ah · ${surah.name}", text, text, "Review now")
        }
        val chunk = surah.chunks.getOrNull(state.currentChunkIndex) ?: surah.chunks.firstOrNull() ?: return null
        val verses = chunk.ayahIds.mapNotNull { id -> surah.verses.firstOrNull { it.id == id } }
        if (verses.isEmpty()) return null
        return reading("A few verses of ${surah.name}", surah.name, surah.id, verses, state)
    }

    private fun reading(title: String, name: String, surahId: Int, verses: List<Verse>, state: AppState): Content {
        val first = verses.first()
        // The verse as the person reads it. The translation is shown as it is (QuranEnc asks it isn't changed).
        val line = when (state.readIn) {
            ReadIn.ARABIC -> first.text
            ReadIn.TRANSLITERATION -> first.transliteration
            ReadIn.ENGLISH -> first.translation ?: first.transliteration
        }
        val range = if (verses.size == 1) "$surahId:${first.id}" else "$surahId:${first.id}–${verses.last().id}"
        val count = if (verses.size == 1) "1 verse" else "${verses.size} verses"
        return Content(
            title = title,
            text = line,
            bigText = "$line\n\n$name $range · $count",
            action = "Read",
        )
    }

    private fun alarmIntent(context: Context, wirdId: Long?): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, ReminderReceiver::class.java).setAction(ReminderReceiver.ACTION_REMIND)
            .apply { if (wirdId != null) putExtra(EXTRA_WIRD, wirdId) },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun wirdIdOf(intent: Intent): Long? = intent.getLongExtra(EXTRA_WIRD, -1).takeIf { it >= 0 }
}

/** Fires a reminder and sets the next one; after a restart, sets the next one again. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val result = goAsync()
        // Reading the Quran data takes a moment: off the main thread.
        thread {
            try {
                val state = StateStore(context).load()
                val wirdId = Reminders.wirdIdOf(intent)
                if (intent.action == ACTION_REMIND && state.hasCompletedOnboarding && (state.remindersOn || wirdId != null)) {
                    Reminders.post(context, wirdId)
                }
                Reminders.reschedule(context, state)
            } finally {
                result.finish()
            }
        }
    }

    companion object { const val ACTION_REMIND = "com.tilawa.app.REMIND" }
}
