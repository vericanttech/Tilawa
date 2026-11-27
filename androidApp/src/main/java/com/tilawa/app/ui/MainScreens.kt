package com.tilawa.app.ui

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccessibilityNew
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle
import com.tilawa.app.MainViewModel
import com.tilawa.app.data.Features
import com.tilawa.app.data.Language
import com.tilawa.app.data.LockDelay
import com.tilawa.app.data.ReadIn
import com.tilawa.app.data.ReadingGoal
import com.tilawa.app.data.ReadingSpeed
import com.tilawa.app.data.Stats
import com.tilawa.app.data.Surah
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

// MARK: Today

@Composable
fun TodayScreen(vm: MainViewModel) {
    val state = vm.state
    val surah = vm.surah
    var showPicker by remember { mutableStateOf(false) }
    var serviceOn by remember { mutableStateOf(vm.accessibilityEnabled()) }
    var unlockLeft by remember { mutableLongStateOf(0L) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            serviceOn = vm.accessibilityEnabled()
            while (true) {
                unlockLeft = vm.appGuard.unlockRemainingMillis()
                delay(30_000)
            }
        }
    }
    if (showPicker) AppPickerSheet(vm) { showPicker = false }
    var wirdSheet by remember { mutableStateOf(false) }
    if (wirdSheet) WirdEditorSheet(vm, editing = null) { wirdSheet = false }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Column(Modifier.weight(1f)) {
                Text("Assalamu alaikum", color = T.Muted, fontSize = 15.sp)
                ScreenTitle("Today")
            }
            if (state.streakDays > 0) StreakPill("${state.streakDays}", "${state.streakDays}-day streak")
        }

        if (Features.APP_PAUSING && unlockLeft > 0) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(T.AccentTint).padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.LockOpen, null, tint = T.OnAccentTint, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(10.dp))
                Text("Apps open · locking in ${(unlockLeft / 60_000).coerceAtLeast(1)} min", color = T.OnAccentTint, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }

        // A wird due today comes first: it's what pauses read today.
        val wirdDue = com.tilawa.app.data.Wird.dueToday(state).isNotEmpty()
        if (wirdDue) WirdCard(vm) { wirdSheet = true }
        if (surah != null) NowCard(vm, surah)
        if (!wirdDue) WirdCard(vm) { wirdSheet = true }
        ReminderCard(vm)
        WeekCard(vm)

        if (Features.APP_PAUSING) Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Pause my apps", color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Text(
                        if (vm.guardedPackages.isEmpty()) "Choose apps to pause until you read." else "They open after a few verses.",
                        color = T.Muted, fontSize = 13.sp,
                    )
                }
                PlainButton(if (vm.guardedPackages.isEmpty()) "Choose" else "Edit") { showPicker = true }
            }
            vm.guardedPackages.sortedBy { vm.appLabel(it).lowercase() }.forEach { pkg ->
                Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    LauncherIcon(pkg, vm.appLabel(pkg), size = 32)
                    Text(vm.appLabel(pkg), color = T.Ink, fontSize = 15.sp, modifier = Modifier.padding(start = 12.dp).weight(1f))
                    Switch(true, { vm.toggleGuard(pkg, it) }, colors = tilawaSwitchColors())
                }
            }
            if (vm.guardedPackages.isNotEmpty() && !serviceOn) {
                val context = LocalContext.current
                Spacer(Modifier.height(8.dp))
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(T.StreakTint)
                        .clickable { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.AccessibilityNew, null, tint = T.Streak)
                    Text(
                        "App pausing is off. Tap to turn on “Tilawa app guard” in Accessibility.",
                        color = T.Ink, fontSize = 13.sp, modifier = Modifier.padding(start = 10.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun NowCard(vm: MainViewModel, surah: Surah) {
    val state = vm.state
    val goal = state.goal
    val versesRead = surah.chunks.take(state.currentChunkIndex.coerceAtMost(surah.chunks.size)).sumOf { it.ayahIds.size }
    val strong = Stats.strongVerseCount(surah, state)
    val progress = if (goal == ReadingGoal.REVIEW) strong.toFloat() / surah.totalVerses else versesRead.toFloat() / surah.totalVerses
    val subtitle = when (goal) {
        ReadingGoal.REVIEW -> "$strong of ${surah.totalVerses} verses strong"
        ReadingGoal.FAMILIAR -> "${Stats.ordinal(state.timesThroughSurah + 1)} time through · $versesRead of ${surah.totalVerses} verses"
        ReadingGoal.MEANING -> "$versesRead of ${surah.totalVerses} verses, with meaning"
    }
    Card {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Overline(goal.nowLabel)
                Text(surah.name, color = T.Ink, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text(subtitle, color = T.Muted, fontSize = 15.sp)
            }
            Spacer(Modifier.width(12.dp))
            RingProgress(progress)
        }
        Spacer(Modifier.height(18.dp))
        if (goal == ReadingGoal.REVIEW) {
            val due = Stats.versesDueToday(surah, state).take(4)
            Text(if (due.isEmpty()) "Up next" else "Due today", color = T.Muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val shown = due.ifEmpty { listOfNotNull(Stats.nextReviewVerse(surah, state)) }
                shown.forEach { InfoPill("Ayah ${it.id}") }
            }
        } else {
            val next = vm.currentVerses().firstOrNull()
            if (next != null) {
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(T.SurfaceMuted).padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text("Up next · ayah ${next.id}", color = T.Muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    val translation = next.translation
                    if (state.readIn == ReadIn.ENGLISH && translation != null) {
                        Text(translationText(translation), color = T.InkSoft, fontSize = 15.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    } else if (state.readIn == ReadIn.TRANSLITERATION) {
                        Text(next.transliteration, color = T.InkSoft, fontFamily = SerifFont, fontSize = 19.sp, lineHeight = 26.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    } else {
                        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                            Text(
                                next.text, color = T.InkSoft, fontFamily = ArabicFont, fontSize = 22.sp, lineHeight = 38.sp,
                                maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(18.dp))
        PrimaryButton(goal.actionTitle) { vm.showGate(null) }
    }
}

@Composable
private fun WeekCard(vm: MainViewModel) {
    val days = Stats.history(vm.state, 7)
    val today = LocalDate.now()
    val total = days.sum()
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("This week", color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text(if (total == 1) "1 verse" else "$total verses", color = T.Muted, fontSize = 13.sp)
        }
        Spacer(Modifier.height(14.dp))
        Row(Modifier.fillMaxWidth()) {
            days.forEachIndexed { i, count ->
                val date = today.minusDays((6 - i).toLong())
                val isToday = i == 6
                val name = date.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault())
                Column(
                    Modifier.weight(1f).clearAndSetSemantics {
                        contentDescription = "${if (isToday) "Today" else date.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())}: ${if (count > 0) "read" else "not yet"}"
                    },
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(name, color = if (isToday) T.Ink else T.Muted, fontSize = 12.sp, fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal)
                    Spacer(Modifier.height(8.dp))
                    Box(
                        Modifier.size(36.dp)
                            .border(2.dp, if (isToday) T.Accent else Color.Transparent, CircleShape)
                            .padding(3.dp).clip(CircleShape).background(if (count > 0) T.Accent else T.Track),
                        contentAlignment = Alignment.Center,
                    ) { if (count > 0) Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(14.dp)) }
                }
            }
        }
    }
}

// MARK: Surahs

@Composable
fun SurahLibrary(vm: MainViewModel, showTitle: Boolean, onBack: (() -> Unit)? = null, onPicked: () -> Unit = {}) {
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf(0) } // 0 suggested, 1 short, 2 all
    val surahs = remember(query, filter) {
        when {
            query.isNotBlank() -> vm.quran.search(query)
            filter == 0 -> Suggested.library.mapNotNull { vm.quran.surah(it) }
            filter == 1 -> vm.quran.surahs.filter { it.totalVerses <= 20 }
            else -> vm.quran.surahs
        }
    }
    Column(Modifier.fillMaxSize().background(T.Mist).then(if (onBack != null) Modifier.statusBarsPadding() else Modifier)) {
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (onBack != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CircleIconButton(Icons.AutoMirrored.Filled.ArrowBack, "Back", background = T.Surface, onClick = onBack)
                    Spacer(Modifier.width(12.dp))
                    Text("All surahs", color = T.Ink, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
            } else if (showTitle) ScreenTitle("Surahs")
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = T.Muted) },
                trailingIcon = {
                    if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { Icon(Icons.Default.Close, "Clear search", tint = T.Muted) }
                },
                placeholder = { Text("Search by name or number", color = T.Muted) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = T.Track,
                    unfocusedContainerColor = T.Track,
                    focusedBorderColor = T.Accent,
                    unfocusedBorderColor = T.Track,
                    cursorColor = T.Accent,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
            if (query.isEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("Suggested", "Short", "All 114").forEachIndexed { i, label ->
                        val on = filter == i
                        Text(
                            label,
                            color = if (on) Color.White else T.Ink,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clip(CircleShape).background(if (on) T.Accent else T.Surface)
                                .clickable(role = Role.Tab) { filter = i }
                                .semantics { selected = on }
                                .padding(horizontal = 14.dp, vertical = 9.dp),
                        )
                    }
                }
            }
        }
        LazyColumn(
            Modifier.weight(1f).padding(horizontal = 20.dp).clip(RoundedCornerShape(24.dp, 24.dp, 0.dp, 0.dp)).background(T.Surface),
        ) {
            itemsIndexed(surahs, key = { _, s -> s.id }) { index, surah ->
                SurahRow(surah, vm.state.selectedSurahId == surah.id) {
                    vm.selectSurah(surah.id)
                    onPicked()
                }
                if (index < surahs.lastIndex) Box(Modifier.padding(start = 64.dp)) { Hairline() }
            }
            if (surahs.isEmpty()) item {
                Text("No surah matches “$query”.", color = T.Muted, fontSize = 15.sp, modifier = Modifier.padding(20.dp))
            }
        }
    }
}

@Composable
private fun SurahRow(surah: Surah, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.RadioButton, onClick = onClick).semantics { this.selected = selected }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(if (selected) T.Accent else T.SurfaceMuted),
            contentAlignment = Alignment.Center,
        ) { Text(surah.id.toString(), color = if (selected) Color.White else T.MutedStrong, fontSize = 13.sp, fontWeight = FontWeight.Bold) }
        Column(Modifier.weight(1f).padding(start = 14.dp)) {
            Text(surah.name, color = T.Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text(
                "${surah.totalVerses} verses · ${surah.type.replaceFirstChar { it.uppercase() }}${if (selected) " · Current" else ""}",
                color = if (selected) T.Accent else T.Muted, fontSize = 13.sp,
            )
        }
        Text(surah.nameArabic, color = if (selected) T.Accent else T.MutedStrong, fontFamily = ArabicFont, fontSize = 20.sp)
    }
}

// MARK: Progress

@Composable
fun ProgressScreen(vm: MainViewModel) {
    val state = vm.state
    val surah = vm.surah
    val days = Stats.history(state, 28)
    val max = (days.maxOrNull() ?: 1).coerceAtLeast(1)
    val active = days.count { it > 0 }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        ScreenTitle("Progress")
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(56.dp).clip(CircleShape).background(T.StreakTint), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.LocalFireDepartment, null, tint = T.Streak, modifier = Modifier.size(28.dp))
                }
                Column(Modifier.padding(start = 16.dp)) {
                    Text(if (state.streakDays == 1) "1 day" else "${state.streakDays} days", color = T.Ink, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                    Text("Current streak · longest ${maxOf(state.longestStreak, state.streakDays)}", color = T.Muted, fontSize = 13.sp)
                }
            }
        }
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Last 4 weeks", color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text("$active of 28 days", color = T.Muted, fontSize = 13.sp)
            }
            Spacer(Modifier.height(14.dp))
            Column(
                Modifier.clearAndSetSemantics { contentDescription = "Read on $active of the last 28 days" },
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                days.chunked(7).forEachIndexed { week, row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEachIndexed { d, count ->
                            val isToday = week == 3 && d == 6
                            val ratio = count.toFloat() / max
                            val color = when {
                                count == 0 -> T.Heat[0]
                                ratio > .66f -> T.Heat[3]
                                ratio > .33f -> T.Heat[2]
                                else -> T.Heat[1]
                            }
                            Box(
                                Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(6.dp)).background(color)
                                    .border(1.5.dp, if (isToday) T.Ink.copy(alpha = .4f) else Color.Transparent, RoundedCornerShape(6.dp)),
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Less", color = T.Muted, fontSize = 11.sp)
                T.Heat.forEach { Box(Modifier.size(12.dp).clip(RoundedCornerShape(3.dp)).background(it)) }
                Text("More", color = T.Muted, fontSize = 11.sp)
            }
        }
        val stats = when (state.goal) {
            ReadingGoal.REVIEW -> listOf(
                "${surah?.let { Stats.strongVerseCount(it, state) } ?: 0}/${surah?.totalVerses ?: 0}" to "Verses strong",
                "${state.totalReviews}" to "Reviews done",
            )
            ReadingGoal.FAMILIAR -> listOf(
                "${state.timesThroughSurah}×" to "Through ${surah?.name ?: "the surah"}",
                "${state.totalAyahsRead}" to "Verses read",
            )
            ReadingGoal.MEANING -> listOf(
                "${state.totalAyahsRead}" to "Verses understood",
                "${state.surahsCompleted}" to "Surahs finished",
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            stats.forEach { (value, label) ->
                Card(Modifier.weight(1f), padding = 18.dp, radius = 20.dp) {
                    Text(value, color = T.Ink, fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                    Text(label, color = T.Muted, fontSize = 13.sp, maxLines = 2)
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}

// MARK: Settings

@Composable
fun SettingsScreen(vm: MainViewModel) {
    val context = LocalContext.current
    val state = vm.state
    var showApps by remember { mutableStateOf(false) }
    var showReset by remember { mutableStateOf(false) }
    // null = closed; Pair(null) = adding; Pair(item) = editing that item.
    var wirdEditor by remember { mutableStateOf<Pair<com.tilawa.app.data.WirdItem?, Unit>?>(null) }
    var serviceOn by remember { mutableStateOf(vm.accessibilityEnabled()) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle) { lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) { serviceOn = vm.accessibilityEnabled() } }

    if (showApps) AppPickerSheet(vm) { showApps = false }
    wirdEditor?.let { (item, _) -> WirdEditorSheet(vm, editing = item) { wirdEditor = null } }
    if (showReset) AlertDialog(
        onDismissRequest = { showReset = false },
        containerColor = T.Surface,
        title = { Text("Reset progress?") },
        text = { Text("Your streak, totals and muraja’ah progress will be erased.") },
        confirmButton = { TextButton(onClick = { vm.resetProgress(); showReset = false }) { Text("Reset", color = T.Danger) } },
        dismissButton = { TextButton(onClick = { showReset = false }) { Text("Cancel", color = T.Accent) } },
    )

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ScreenTitle("Settings")
        SectionLabel("My goal")
        ReadingGoal.entries.forEach { GoalCard(it, state.goal == it) { vm.setGoal(it) } }

        SectionLabel("My wird")
        WirdSettings(vm) { wirdEditor = it to Unit }

        SectionLabel("Reading")
        Card(padding = 0.dp, radius = 20.dp) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Read in", color = T.Ink, fontSize = 16.sp)
                Text(
                    when (state.readIn) {
                        ReadIn.ARABIC -> "The Arabic is shown large."
                        ReadIn.TRANSLITERATION -> "For when you can’t read the Arabic script yet: Latin letters are shown large."
                        ReadIn.ENGLISH -> "The English meaning is shown large."
                    },
                    color = T.Muted, fontSize = 13.sp, lineHeight = 18.sp,
                )
                Segmented(ReadIn.entries.map { it to it.label }, state.readIn) { v -> vm.update { it.copy(readIn = v) } }
            }
            if (state.readIn != ReadIn.ARABIC) {
                Hairline()
                ToggleRow("Show Arabic", "The verse in Arabic script, smaller.", state.showArabic) { v -> vm.update { it.copy(showArabic = v) } }
            }
            if (state.readIn != ReadIn.TRANSLITERATION) {
                Hairline()
                ToggleRow("Show transliteration", "How it sounds, in Latin letters.", state.showTransliteration) { v -> vm.update { it.copy(showTransliteration = v) } }
            }
            if (state.readIn != ReadIn.ENGLISH) {
                Hairline()
                ToggleRow("Show meaning", "The English translation.", state.showMeaning) { v -> vm.update { it.copy(showMeaning = v) } }
            }
            Hairline()
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Pause length", color = T.Ink, fontSize = 16.sp)
                Segmented(listOf(ReadingSpeed.FAST to "Short", ReadingSpeed.NORMAL to "Medium", ReadingSpeed.SLOW to "Long"), state.readingSpeed) { v ->
                    vm.update { it.copy(readingSpeed = v) }
                }
            }
        }

        SectionLabel("Reminders")
        Card(padding = 0.dp, radius = 20.dp) {
            ToggleRow("Reading reminders", "A few verses every few hours", state.remindersOn) { v -> vm.update { it.copy(remindersOn = v) } }
            if (state.remindersOn) {
                Hairline()
                Column(Modifier.padding(16.dp)) { ReminderOptions(vm) }
                if (!androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                    Column(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp)) { NotificationsBlocked() }
                }
            }
            if ((context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
                Hairline()
                SettingsRow("Send a test reminder", "Test builds only: shows one now") { vm.testReminder() }
            }
        }

        if (Features.APP_PAUSING) SectionLabel("Paused apps")
        if (Features.APP_PAUSING) Card(padding = 0.dp, radius = 20.dp) {
            SettingsRow("Choose apps", "${vm.guardedPackages.size} selected") { showApps = true }
            Hairline()
            SettingsRow(
                "App pausing",
                if (serviceOn) "On · Tilawa can’t read your screen" else "Off · tap to turn on in Accessibility",
            ) { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
            Hairline()
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Pause again after", color = T.Ink, fontSize = 16.sp)
                Segmented(
                    listOf(LockDelay.FIFTEEN_MINUTES to "15m", LockDelay.THIRTY_MINUTES to "30m", LockDelay.SIXTY_MINUTES to "1h", LockDelay.TWO_HOURS to "2h", LockDelay.NONE to "Off"),
                    state.lockDelay,
                ) { v -> vm.update { it.copy(lockDelay = v) } }
            }
        }

        SectionLabel("Language")
        Segmented(listOf(Language.ENGLISH to "English", Language.FRENCH to "Français", Language.ARABIC to "العربية"), state.language) { v ->
            vm.update { it.copy(language = v) }
        }

        Spacer(Modifier.height(8.dp))
        TextButton(onClick = { showReset = true }, modifier = Modifier.fillMaxWidth()) {
            Text("Reset reading progress", color = T.Danger, fontSize = 15.sp)
        }
        Text(
            vm.quran.translationCredit,
            color = T.Muted, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Text(
            "Tilawa for Android · ${context.packageManager.getPackageInfo(context.packageName, 0).versionName}",
            color = T.Muted, fontSize = 12.sp, modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(text, color = T.Muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp, start = 4.dp))
}

@Composable
private fun ToggleRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Switch) { onChange(!checked) }.padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = T.Ink, fontSize = 16.sp)
            Text(subtitle, color = T.Muted, fontSize = 13.sp)
        }
        Switch(checked, null, colors = tilawaSwitchColors())
    }
}

@Composable
private fun SettingsRow(title: String, subtitle: String, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp)) {
        Text(title, color = T.Ink, fontSize = 16.sp)
        Text(subtitle, color = T.Muted, fontSize = 13.sp)
    }
}

