package com.tilawa.app.ui

import android.content.pm.ApplicationInfo
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tilawa.app.MainViewModel
import com.tilawa.app.data.Stats
import com.tilawa.app.data.Wird
import com.tilawa.app.data.WirdItem
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

// MARK: Today

/** Today's wird: what's due, how far along, and a button to read it now. */
@Composable
fun WirdCard(vm: MainViewModel, onSetUp: () -> Unit) {
    val state = vm.state
    val items = Wird.activeItems(state)
    if (items.isEmpty()) {
        Card {
            Overline("My wird")
            Spacer(Modifier.height(8.dp))
            Text("Read Al-Kahf every Friday", color = T.Ink, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(
                "Add the surahs you read regularly. On their day, your reminders go through them, a few verses at a time.",
                color = T.Muted, fontSize = 14.sp, lineHeight = 20.sp, modifier = Modifier.padding(top = 4.dp),
            )
            Spacer(Modifier.height(16.dp))
            SoftButton("Set up my wird", Modifier.fillMaxWidth(), onClick = onSetUp)
        }
        return
    }
    val due = Wird.dueToday(state)
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Overline(if (due.isEmpty()) "My wird" else "Today’s wird")
            Spacer(Modifier.weight(1f))
            Text(
                "Edit", color = T.Accent, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(role = Role.Button, onClick = onSetUp).padding(4.dp),
            )
        }
        if (due.isEmpty()) {
            val next = items.mapNotNull { item -> Wird.nextDueDay(item)?.let { item to it } }.minByOrNull { it.second }
            Spacer(Modifier.height(6.dp))
            Text("Nothing due today", color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            if (next != null) {
                val name = vm.quran.surah(next.first.surahId)?.name.orEmpty()
                Text("Next: $name · ${dayName(next.second)}", color = T.Muted, fontSize = 14.sp)
            }
            return@Card
        }
        due.forEachIndexed { i, item ->
            val surah = vm.quran.surah(item.surahId) ?: return@forEachIndexed
            val upTo = Wird.upTo(state, item).coerceAtMost(surah.totalVerses)
            val done = upTo >= surah.totalVerses
            if (i > 0) Hairline()
            Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(surah.name, color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                        Text("  ${surah.nameArabic}", color = T.Muted, fontFamily = ArabicFont, fontSize = 16.sp)
                    }
                    Text(
                        if (done) "Done for today · ${surah.totalVerses} verses" else "$upTo of ${surah.totalVerses} verses",
                        color = T.Muted, fontSize = 13.sp,
                    )
                    LineProgress(upTo.toFloat() / surah.totalVerses)
                }
                Spacer(Modifier.width(14.dp))
                if (done) {
                    Box(Modifier.size(40.dp).clip(CircleShape).background(T.Accent), contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Check, "Done", tint = Color.White, modifier = Modifier.size(20.dp))
                    }
                } else {
                    Text(
                        if (upTo == 0) "Read" else "Continue",
                        color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clip(CircleShape).background(T.Accent)
                            .clickable(role = Role.Button) { vm.showGate(null, wirdId = item.id) }
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                    )
                }
            }
        }
        Text(
            "Reminders today go through this first. Tap Keep reading to finish it in one sitting.",
            color = T.Muted, fontSize = 12.sp, lineHeight = 16.sp,
        )
    }
}

private fun dayName(day: Long): String {
    val today = Stats.today()
    return when (day - today) {
        1L -> "tomorrow"
        else -> LocalDate.ofEpochDay(day).dayOfWeek.getDisplayName(TextStyle.FULL, Locale.ENGLISH)
    }
}

// MARK: Settings

/** "My wird" in Settings: the list, in reading order, plus adding and Tilawa Plus. */
@Composable
fun WirdSettings(vm: MainViewModel, onEdit: (WirdItem?) -> Unit) {
    val state = vm.state
    val context = LocalContext.current
    val debuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    Card(padding = 0.dp, radius = 20.dp) {
        state.wird.forEachIndexed { i, item ->
            val surah = vm.quran.surah(item.surahId)
            val locked = !state.isPro && i >= Wird.FREE_LIMIT
            if (i > 0) Hairline()
            Row(
                Modifier.fillMaxWidth().clickable { onEdit(item) }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(surah?.name.orEmpty(), color = if (locked) T.Muted else T.Ink, fontSize = 16.sp)
                    Text(if (locked) "${item.scheduleLabel} · needs Tilawa Plus" else item.scheduleLabel, color = T.Muted, fontSize = 13.sp)
                }
                Text(surah?.nameArabic.orEmpty(), color = if (locked) T.Outline else T.Accent, fontFamily = ArabicFont, fontSize = 20.sp)
            }
        }
        if (state.wird.isNotEmpty()) Hairline()
        Row(
            Modifier.fillMaxWidth().clickable { onEdit(null) }.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Add, null, tint = T.Accent, modifier = Modifier.size(20.dp))
            Text("Add to my wird", color = T.Accent, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 10.dp).weight(1f))
            if (!Wird.canAdd(state)) PlusBadge()
        }
        if (state.wird.size > 1) {
            Text(
                "On a day with more than one, they’re read in this order. Open one to move it.",
                color = T.Muted, fontSize = 12.sp, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 14.dp),
            )
        }
    }
    if (debuggable) {
        // Billing isn't built yet: lets us try Plus on test builds only.
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(T.StreakTint)
                .clickable { vm.update { it.copy(isPro = !it.isPro) } }.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Tilawa Plus (test builds only)", color = T.Ink, fontSize = 14.sp, modifier = Modifier.weight(1f))
            Switch(state.isPro, null, colors = tilawaSwitchColors())
        }
    }
}

@Composable
private fun PlusBadge() {
    Row(
        Modifier.clip(CircleShape).background(T.StreakTint).padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Star, null, tint = T.Streak, modifier = Modifier.size(12.dp))
        Text(" Plus", color = T.Streak, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

// MARK: Add / edit sheet

private enum class EditorStep { PRESETS, SURAHS, SCHEDULE }

/** Adds a surah to the wird (presets or any surah, then its days), or edits one when [editing] is set. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WirdEditorSheet(vm: MainViewModel, editing: WirdItem?, dismiss: () -> Unit) {
    val state = vm.state
    var step by remember { mutableStateOf(if (editing != null) EditorStep.SCHEDULE else EditorStep.PRESETS) }
    var surahId by remember { mutableIntStateOf(editing?.surahId ?: 18) }
    var byWeekday by remember { mutableStateOf(editing?.let { it.everyDays == 0 } ?: true) }
    var weekdays by remember { mutableStateOf(editing?.weekdays ?: setOf(5)) }
    var everyDays by remember { mutableIntStateOf(editing?.everyDays?.takeIf { it > 0 } ?: 2) }
    var query by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = dismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = T.Surface,
        contentColor = T.Ink,
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 16.dp)) {
            if (editing == null && !Wird.canAdd(state)) {
                PlusUpsell(dismiss)
                return@Column
            }
            when (step) {
                EditorStep.PRESETS -> {
                    Text("Add to my wird", color = T.Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Text("Reminders go through it on its days.", color = T.Muted, fontSize = 14.sp, modifier = Modifier.padding(top = 2.dp, bottom = 14.dp))
                    val taken = state.wird.map { it.surahId }.toSet()
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Wird.presets.filter { it.surahId !in taken }.forEach { preset ->
                            val surah = vm.quran.surah(preset.surahId) ?: return@forEach
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(T.SurfaceMuted)
                                    .clickable {
                                        vm.addWird(preset.surahId, preset.weekdays, preset.everyDays)
                                        dismiss()
                                    }
                                    .padding(horizontal = 16.dp, vertical = 14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(preset.note, color = T.Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                                    Text("${surah.totalVerses} verses", color = T.Muted, fontSize = 13.sp)
                                }
                                Text(surah.nameArabic, color = T.Accent, fontFamily = ArabicFont, fontSize = 20.sp)
                            }
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                    PlainButton("Choose another surah") { step = EditorStep.SURAHS }
                }

                EditorStep.SURAHS -> {
                    SheetBack("Choose a surah") { step = EditorStep.PRESETS }
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        leadingIcon = { Icon(Icons.Default.Search, null) },
                        placeholder = { Text("Search surahs") },
                        singleLine = true,
                        shape = RoundedCornerShape(14.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedContainerColor = T.Track,
                            unfocusedContainerColor = T.Track,
                            focusedBorderColor = T.Accent,
                            unfocusedBorderColor = T.Track,
                        ),
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    )
                    val list = vm.quran.surahs.filter {
                        query.isBlank() || it.name.contains(query.trim(), ignoreCase = true) || it.id.toString() == query.trim()
                    }
                    LazyColumn(Modifier.heightIn(max = 420.dp)) {
                        items(list, key = { it.id }) { surah ->
                            Row(
                                Modifier.fillMaxWidth().clickable {
                                    surahId = surah.id
                                    step = EditorStep.SCHEDULE
                                }.padding(vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text("${surah.id}", color = T.Muted, fontSize = 13.sp, modifier = Modifier.width(36.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(surah.name, color = T.Ink, fontSize = 16.sp)
                                    Text("${surah.totalVerses} verses", color = T.Muted, fontSize = 12.sp)
                                }
                                Text(surah.nameArabic, color = T.MutedStrong, fontFamily = ArabicFont, fontSize = 18.sp)
                            }
                        }
                    }
                }

                EditorStep.SCHEDULE -> {
                    val surah = vm.quran.surah(surahId)
                    if (editing == null) SheetBack(surah?.name.orEmpty()) { step = EditorStep.SURAHS }
                    else Text(surah?.name.orEmpty(), color = T.Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 8.dp))
                    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Text("When do you read it?", color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                        Segmented(listOf(true to "On certain days", false to "Every few days"), byWeekday) { byWeekday = it }
                        if (byWeekday) {
                            WeekdayPicker(weekdays) { weekdays = it }
                            Text(
                                if (weekdays.size == 7) "Every day" else WirdItem(0, 0, weekdays).scheduleLabel,
                                color = T.Muted, fontSize = 13.sp,
                            )
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Every", color = T.Ink, fontSize = 16.sp)
                                Spacer(Modifier.width(12.dp))
                                StepperButton(Icons.Default.Remove, "Fewer days") { everyDays = (everyDays - 1).coerceAtLeast(1) }
                                Text("$everyDays", color = T.Ink, fontSize = 20.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.width(44.dp))
                                StepperButton(Icons.Default.Add, "More days") { everyDays = (everyDays + 1).coerceAtMost(14) }
                                Spacer(Modifier.width(12.dp))
                                Text(if (everyDays == 1) "day" else "days", color = T.Ink, fontSize = 16.sp)
                            }
                            Text("Starting today.", color = T.Muted, fontSize = 13.sp)
                        }
                        val valid = !byWeekday || weekdays.isNotEmpty()
                        PrimaryButton(if (editing == null) "Add to my wird" else "Save", enabled = valid) {
                            val days = if (byWeekday) weekdays else emptySet()
                            val every = if (byWeekday) 0 else everyDays
                            if (editing == null) {
                                vm.addWird(surahId, days, every)
                            } else {
                                val restart = every != editing.everyDays
                                vm.updateWird(editing.copy(weekdays = days, everyDays = every, startDay = if (restart) Stats.today() else editing.startDay))
                            }
                            dismiss()
                        }
                        if (editing != null) {
                            if (state.wird.size > 1) {
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    SoftButton("Read earlier", Modifier.weight(1f)) { vm.moveWird(editing.id, -1) }
                                    SoftButton("Read later", Modifier.weight(1f)) { vm.moveWird(editing.id, 1) }
                                }
                            }
                            Text(
                                "Remove from my wird",
                                color = T.Danger, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                                    .clickable(role = Role.Button) { vm.removeWird(editing.id); dismiss() }
                                    .padding(vertical = 12.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetBack(title: String, back: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 4.dp)) {
        CircleIconButton(Icons.AutoMirrored.Filled.ArrowBack, "Back", onClick = back)
        Text(title, color = T.Ink, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 12.dp))
    }
}

@Composable
private fun StepperButton(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(40.dp).clip(CircleShape).background(T.AccentTint)
            .clickable(role = Role.Button, onClickLabel = description, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = T.Accent, modifier = Modifier.size(18.dp)) }
}

/** Seven round day toggles, Monday first. */
@Composable
private fun WeekdayPicker(selected: Set<Int>, onChange: (Set<Int>) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        (1..7).forEach { day ->
            val on = day in selected
            val name = java.time.DayOfWeek.of(day).getDisplayName(TextStyle.FULL, Locale.ENGLISH)
            Box(
                Modifier.size(40.dp).clip(CircleShape)
                    .background(if (on) T.Accent else T.Surface)
                    .border(1.5.dp, if (on) T.Accent else T.Outline, CircleShape)
                    .clickable(role = Role.Checkbox) { onChange(if (on) selected - day else selected + day) }
                    .semantics { contentDescription = name; this.selected = on },
                contentAlignment = Alignment.Center,
            ) {
                Text(name.take(1), color = if (on) Color.White else T.Ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun PlusUpsell(dismiss: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        PlusBadge()
        Text("Read more with Tilawa Plus", color = T.Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(
            "Your first wird is free. Plus lets you add as many as you like, like Al-Mulk every night or Ya-Sin every two days, each on its own days.",
            color = T.Muted, fontSize = 15.sp, lineHeight = 21.sp,
        )
        Text("Reading itself is always free.", color = T.Muted, fontSize = 15.sp)
        Spacer(Modifier.height(4.dp))
        PrimaryButton("Coming soon", enabled = false) {}
        PlainButton("Not now", Modifier.fillMaxWidth(), onClick = dismiss)
    }
}
