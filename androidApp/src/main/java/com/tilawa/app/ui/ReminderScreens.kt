package com.tilawa.app.ui

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import com.tilawa.app.MainViewModel
import com.tilawa.app.data.AppState
import com.tilawa.app.data.ReadIn
import com.tilawa.app.data.ReadingGoal
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** "8 AM", "12 PM", "Midnight". */
fun hourLabel(hour: Int): String = when (hour) {
    0, 24 -> "Midnight"
    12 -> "Noon"
    else -> "${if (hour % 12 == 0) 12 else hour % 12} ${if (hour < 12) "AM" else "PM"}"
}

/** "Every 2 hours · 8 AM – 10 PM". */
fun reminderSummary(state: AppState): String {
    val every = if (state.remindEveryHours == 1) "Every hour" else "Every ${state.remindEveryHours} hours"
    return "$every · ${hourLabel(state.remindFrom)} – ${hourLabel(state.remindUntil)}"
}

private fun nextLabel(at: Long): String {
    val zone = ZoneId.systemDefault()
    val time = Instant.ofEpochMilli(at).atZone(zone)
    val clock = time.format(DateTimeFormatter.ofPattern("h:mm a", Locale.ENGLISH))
    return when (time.toLocalDate()) {
        LocalDate.now(zone) -> "Next at $clock"
        LocalDate.now(zone).plusDays(1) -> "Next tomorrow at $clock"
        else -> "Next ${time.format(DateTimeFormatter.ofPattern("EEEE", Locale.ENGLISH))} at $clock"
    }
}

/** Today: when the next reminder comes, or a way to turn them on. */
@Composable
fun ReminderCard(vm: MainViewModel) {
    val state = vm.state
    val context = LocalContext.current
    val allowed = NotificationManagerCompat.from(context).areNotificationsEnabled()
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Reminders", color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Text(
                    if (state.remindersOn) reminderSummary(state) else "Off · a few verses every few hours",
                    color = T.Muted, fontSize = 13.sp,
                )
            }
            Switch(state.remindersOn, { on -> vm.update { it.copy(remindersOn = on) } }, colors = tilawaSwitchColors())
        }
        if (state.remindersOn) {
            val next = vm.nextReminderAt
            if (!allowed) {
                Spacer(Modifier.height(12.dp))
                NotificationsBlocked()
            } else if (next != null) {
                Text(nextLabel(next), color = T.Accent, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

/** Notifications are switched off for Tilawa in system settings: only the person can turn them back on. */
@Composable
fun NotificationsBlocked() {
    val context = LocalContext.current
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(T.StreakTint)
            .clickable {
                context.startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                )
            }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.NotificationsOff, null, tint = T.Streak)
        Text(
            "Notifications are off for Tilawa, so reminders can’t reach you. Tap to allow them.",
            color = T.Ink, fontSize = 13.sp, modifier = Modifier.padding(start = 10.dp),
        )
    }
}

/** How often, and between which hours. Used in onboarding and Settings. */
@Composable
fun ReminderOptions(vm: MainViewModel) {
    val state = vm.state
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("How often", color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Segmented(listOf(1 to "1 hour", 2 to "2 hours", 3 to "3 hours", 4 to "4 hours"), state.remindEveryHours) { v ->
            vm.update { it.copy(remindEveryHours = v) }
        }
        Text("Between", color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
        HourStepper("From", state.remindFrom,
            down = { vm.update { it.copy(remindFrom = (it.remindFrom - 1).coerceAtLeast(0)) } },
            up = { vm.update { it.copy(remindFrom = (it.remindFrom + 1).coerceAtMost(it.remindUntil - 1)) } },
        )
        HourStepper("Until", state.remindUntil,
            down = { vm.update { it.copy(remindUntil = (it.remindUntil - 1).coerceAtLeast(it.remindFrom + 1)) } },
            up = { vm.update { it.copy(remindUntil = (it.remindUntil + 1).coerceAtMost(24)) } },
        )
        Text("Quiet the rest of the time. Reading in the app moves the next reminder later.", color = T.Muted, fontSize = 13.sp, lineHeight = 18.sp)
    }
}

@Composable
private fun HourStepper(label: String, hour: Int, down: () -> Unit, up: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(T.SurfaceMuted).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = T.Muted, fontSize = 15.sp, modifier = Modifier.weight(1f))
        RoundStep(Icons.Default.Remove, "Earlier", down)
        Text(hourLabel(hour), color = T.Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, modifier = Modifier.width(92.dp))
        RoundStep(Icons.Default.Add, "Later", up)
    }
}

@Composable
private fun RoundStep(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(36.dp).clip(CircleShape).background(T.Surface)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = T.Accent, modifier = Modifier.size(18.dp)) }
}

/** What a reminder looks like, with the person's own next verse. */
@Composable
fun ReminderPreview(vm: MainViewModel) {
    val state = vm.state
    val surah = vm.surah ?: return
    val verse = vm.currentVerses().firstOrNull() ?: return
    val review = state.goal == ReadingGoal.REVIEW
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(T.Surface).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(20.dp).clip(RoundedCornerShape(6.dp)).background(T.Accent), contentAlignment = Alignment.Center) {
                Text("ا", color = Color.White, fontFamily = ArabicFont, fontSize = 12.sp)
            }
            Text("  Tilawa · now", color = T.Muted, fontSize = 12.sp)
        }
        Text(
            if (review) "Quick muraja’ah · ${surah.name}" else "A few verses of ${surah.name}",
            color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
        )
        if (review) {
            Text("Can you recall the next ayah? About 15 seconds.", color = T.Muted, fontSize = 14.sp)
        } else when (state.readIn) {
            ReadIn.ARABIC -> CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Text(verse.text, color = T.InkSoft, fontFamily = ArabicFont, fontSize = 18.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth())
            }
            ReadIn.TRANSLITERATION -> Text(verse.transliteration, color = T.InkSoft, fontSize = 14.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
            ReadIn.ENGLISH -> Text(verse.translation ?: verse.transliteration, color = T.InkSoft, fontSize = 14.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}
