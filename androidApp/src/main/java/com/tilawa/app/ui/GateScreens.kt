package com.tilawa.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tilawa.app.MainViewModel
import com.tilawa.app.data.DoneInfo
import com.tilawa.app.data.ReadingGoal
import com.tilawa.app.data.Stats
import com.tilawa.app.data.Verse
import kotlinx.coroutines.delay

/** The pause: reading (Get familiar / Read with meaning) or recall (Muraja'ah), then the done screen. */
@Composable
fun GateScreen(vm: MainViewModel) {
    val done = vm.done
    when {
        done != null -> DoneScreen(vm, done)
        vm.state.goal == ReadingGoal.REVIEW -> RecallScreen(vm)
        else -> ReadingScreen(vm)
    }
}

@Composable
private fun GateHeader(title: String, subtitle: String, onClose: (() -> Unit)?, trailing: @Composable () -> Unit = { Spacer(Modifier.size(44.dp)) }) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onClose != null) CircleIconButton(Icons.Default.Close, "Close", onClick = onClose) else Spacer(Modifier.size(44.dp))
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, color = T.Muted, fontSize = 12.sp)
        }
        trailing()
    }
}

@Composable
private fun BottomBar(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(T.Surface)
            .drawBehind { drawLine(T.Hairline, Offset(0f, 0f), Offset(size.width, 0f), 1.dp.toPx()) }
            .padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) { content() }
}

@Composable
private fun ArabicText(text: String, size: Int, color: Color, modifier: Modifier = Modifier) {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        Text(
            text,
            color = color,
            fontFamily = ArabicFont,
            fontSize = size.sp,
            lineHeight = (size * 1.75).sp,
            textAlign = TextAlign.Start,
            modifier = modifier.fillMaxWidth(),
        )
    }
}

// MARK: Reading

@Composable
private fun ReadingScreen(vm: MainViewModel) {
    val state = vm.state
    val surah = vm.surah ?: return
    val verses = remember(state.selectedSurahId, state.currentChunkIndex) { vm.currentVerses() }
    val duration = remember(verses, state.goal, state.readingSpeed) { vm.readingSeconds(verses) }
    var elapsed by remember(verses) { mutableIntStateOf(0) }
    val ready = elapsed >= duration
    val meaningFirst = state.meaningFirst || state.goal == ReadingGoal.MEANING
    val canClose = vm.isManualGate
    var menu by remember { mutableStateOf(false) }

    BackHandler { if (canClose) vm.dismissGate() }
    LaunchedEffect(verses) { while (elapsed < duration) { delay(1_000); elapsed += 1 } }

    val range = when {
        verses.isEmpty() -> ""
        verses.size == 1 -> "Ayah ${verses.first().id} of ${surah.totalVerses}"
        else -> "Ayahs ${verses.first().id}–${verses.last().id} of ${surah.totalVerses}"
    }

    Column(Modifier.fillMaxSize().background(T.Surface).statusBarsPadding().navigationBarsPadding()) {
        GateHeader(surah.name, range, if (canClose) vm::dismissGate else null) {
            Box {
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(T.SurfaceMuted)
                        .clickable(onClickLabel = "Text settings") { menu = true }
                        .semantics { contentDescription = "Text settings" },
                    contentAlignment = Alignment.Center,
                ) { Text("Aa", color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    MenuToggle("Meaning first", state.meaningFirst) { v -> vm.update { it.copy(meaningFirst = v) } }
                    MenuToggle("Show transliteration", state.showTransliteration) { v -> vm.update { it.copy(showTransliteration = v) } }
                }
            }
        }

        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            if (state.goal == ReadingGoal.MEANING && verses.any { it.translation == null }) {
                Text("English meaning isn’t available for this surah yet.", color = T.Muted, fontSize = 13.sp)
            }
            verses.forEach { verse ->
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    VerseBadge(verse.id)
                    val translation = verse.translation
                    if (meaningFirst && translation != null) {
                        Text(translation, color = T.Ink, fontSize = 20.sp, fontWeight = FontWeight.Medium, lineHeight = 28.sp)
                        ArabicText(verse.text, 22, T.MutedStrong)
                        if (state.showTransliteration) Translit(verse.transliteration, 13)
                    } else {
                        ArabicText(verse.text, 30, T.Ink)
                        if (state.showTransliteration) Translit(verse.transliteration, 14)
                        if (translation != null) Text(translation, color = T.InkSoft, fontSize = 16.sp, lineHeight = 23.sp)
                    }
                }
            }
        }

        BottomBar {
            LineProgress(if (duration > 0) elapsed.toFloat() / duration else 1f)
            if (ready) {
                PrimaryButton("Done reading") { vm.finishReading(verses) }
            } else {
                val left = (duration - elapsed).coerceAtLeast(0)
                WaitBar("Take your time · %d:%02d".format(left / 60, left % 60), "Keep reading. $left seconds left")
            }
        }
    }
}

@Composable
private fun Translit(text: String, size: Int) {
    Text(text, color = T.Muted, fontSize = size.sp, fontStyle = FontStyle.Italic, lineHeight = (size * 1.45).sp)
}

@Composable
private fun MenuToggle(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    DropdownMenuItem(
        text = { Text(label, color = T.Ink) },
        trailingIcon = {
            Switch(checked, onChange, colors = tilawaSwitchColors())
        },
        onClick = { onChange(!checked) },
    )
}

// MARK: Recall (Muraja'ah)

@Composable
private fun RecallScreen(vm: MainViewModel) {
    val state = vm.state
    val surah = vm.surah ?: return
    // Chosen once per pause, so recording the review doesn't swap the verse underneath.
    val verse = remember { Stats.nextReviewVerse(surah, state) } ?: return
    val stage = remember { Stats.reviewStage(verse.id, state) }
    var revealed by remember { mutableStateOf(false) }
    val minimum = remember {
        if (stage == 3) 0 else (verse.durationSeconds * state.readingSpeed.secondsPerWord / 0.65).toInt().coerceAtLeast(5)
    }
    var elapsed by remember { mutableIntStateOf(0) }
    val canClose = vm.isManualGate

    BackHandler { if (canClose) vm.dismissGate() }
    LaunchedEffect(Unit) { while (elapsed < minimum) { delay(1_000); elapsed += 1 } }

    val caption = when {
        revealed && stage == 3 -> "Words you recalled are shown in green."
        revealed -> "Here’s the full verse."
        stage == 0 -> "Read the whole verse, so it becomes familiar."
        stage == 1 -> "Some words have faded. Fill them in as you read."
        stage == 2 -> "Just the first word. Recite the rest in your head."
        else -> "Recall the whole verse, then check yourself."
    }

    Column(Modifier.fillMaxSize().background(T.Surface).statusBarsPadding().navigationBarsPadding()) {
        GateHeader("Muraja’ah · ${surah.name}", "Ayah ${verse.id} · review", if (canClose) vm::dismissGate else null)

        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            Text(caption, color = T.Muted, fontSize = 14.sp)
            FadingVerse(verse.words, stage, revealed)
            if (stage == 0 && state.showTransliteration) Translit(verse.transliteration, 14)
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(T.Mist).padding(horizontal = 16.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Overline(if (stage == 3 && !revealed) "Recall the verse that means" else "Meaning")
                Text(verse.translation ?: "Ayah ${verse.id} of ${surah.name}", color = T.InkSoft, fontSize = 16.sp, lineHeight = 23.sp)
            }
        }

        BottomBar {
            when {
                stage == 3 && !revealed -> PrimaryButton("Tap to check") { revealed = true }
                stage == 3 -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SoftButton("Review again soon", Modifier.weight(1f)) { vm.finishReview(verse, recalled = false) }
                    Box(Modifier.weight(1f)) { PrimaryButton("I knew it") { vm.finishReview(verse, recalled = true) } }
                }
                elapsed < minimum -> {
                    val left = (minimum - elapsed).coerceAtLeast(0)
                    WaitBar("Take your time · ${left}s", "Keep reading. $left seconds left")
                }
                else -> {
                    PrimaryButton("Done") { vm.finishReview(verse, recalled = !revealed) }
                    if (stage > 0 && !revealed) PlainButton("Show the full verse") { revealed = true }
                }
            }
            Text("Your app opens either way", color = T.Muted, fontSize = 12.sp)
        }
    }
}

/** Arabic verse word by word, right to left, with words faded or hidden by stage. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FadingVerse(words: List<String>, stage: Int, revealed: Boolean) {
    val label = when {
        revealed || stage == 0 -> words.joinToString(" ")
        stage == 2 && words.isNotEmpty() -> "${words.first()}, then recall the rest"
        else -> "Recall this verse"
    }
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        FlowRow(
            Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = label },
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            words.forEachIndexed { index, word ->
                val hidden = (stage == 2 && index > 0) || stage == 3
                val faded = stage == 1 && index % 2 == 1
                val target = when {
                    revealed && (hidden || faded) -> T.Accent
                    hidden -> Color.Transparent
                    faded -> T.Outline
                    else -> T.Ink
                }
                val color by animateColorAsState(target, label = "word")
                val underline = hidden && !revealed
                Text(
                    word,
                    color = color,
                    fontFamily = ArabicFont,
                    fontSize = 32.sp,
                    lineHeight = 54.sp,
                    modifier = Modifier.drawBehind {
                        if (underline) {
                            drawLine(
                                T.Outline,
                                Offset(0f, size.height - 4.dp.toPx()),
                                Offset(size.width, size.height - 4.dp.toPx()),
                                strokeWidth = 2.dp.toPx(),
                                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 6.dp.toPx())),
                            )
                        }
                    },
                )
            }
        }
    }
}

// MARK: Done

@Composable
private fun DoneScreen(vm: MainViewModel, info: DoneInfo) {
    val target = vm.targetApp
    val appName = target?.let { vm.appLabel(it) }
    val ms = vm.state.lockDelay.millis
    val unlock = when {
        target == null -> "Well done. Your next pause will pick up from here."
        ms == null -> "$appName is open."
        else -> {
            val minutes = ms / 60_000
            val span = if (minutes >= 60) (if (minutes == 60L) "hour" else "${minutes / 60} hours") else "$minutes minutes"
            "$appName is open for the next $span."
        }
    }
    BackHandler { vm.closeDone() }

    Column(Modifier.fillMaxSize().background(T.Mist).statusBarsPadding().navigationBarsPadding()) {
        Column(
            Modifier.weight(1f).fillMaxWidth().padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.size(88.dp).clip(CircleShape).background(T.AccentTint), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Check, null, tint = T.Accent, modifier = Modifier.size(40.dp))
            }
            Spacer(Modifier.height(20.dp))
            Text(info.headline, color = T.Ink, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Spacer(Modifier.height(8.dp))
            Text(unlock, color = T.Muted, fontSize = 16.sp, textAlign = TextAlign.Center)
            Spacer(Modifier.height(20.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                val days = vm.state.streakDays
                StreakPill(if (days == 1) "1-day streak" else "$days-day streak")
                InfoPill(info.chip)
            }
        }

        Card(Modifier.padding(horizontal = 24.dp), radius = 20.dp) {
            Overline(info.cardLabel)
            Spacer(Modifier.height(8.dp))
            if (info.cardTextIsArabic) ArabicText(info.cardText, 22, T.InkSoft)
            else Text(info.cardText, color = T.InkSoft, fontSize = 16.sp, lineHeight = 23.sp)
            Spacer(Modifier.height(8.dp))
            Text(info.cardRef, color = T.Muted, fontSize = 13.sp)
        }
        Spacer(Modifier.height(24.dp))
        Box(Modifier.padding(horizontal = 24.dp)) {
            PrimaryButton(if (appName != null) "Continue to $appName" else "Done") { vm.closeDone() }
        }
        Spacer(Modifier.height(24.dp))
    }
}
