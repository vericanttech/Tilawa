package com.tilawa.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.draw.scale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.DpOffset
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
import androidx.compose.ui.graphics.drawscope.Stroke
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
import com.tilawa.app.Segment
import androidx.compose.foundation.ScrollState
import androidx.compose.runtime.mutableStateListOf
import com.tilawa.app.data.DoneInfo
import com.tilawa.app.data.ReadIn
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
        // A wird is read, even when the goal is Muraja'ah.
        vm.state.goal == ReadingGoal.REVIEW && vm.gateWirdId == null -> RecallScreen(vm)
        else -> ReadingScreen(vm)
    }
}

/** Quiet header on the paper: a small letterspaced title, with close and text settings kept faint. */
@Composable
private fun GateHeader(title: String, onClose: (() -> Unit)?, trailing: @Composable () -> Unit = { Spacer(Modifier.size(44.dp)) }) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onClose != null) {
            QuietIcon("Close", onClose) { Icon(Icons.Default.Close, null, tint = T.Muted, modifier = Modifier.size(20.dp)) }
        } else {
            Spacer(Modifier.size(44.dp))
        }
        Text(
            title.uppercase(),
            color = T.Accent,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 2.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.weight(1f),
        )
        trailing()
    }
}

@Composable
private fun QuietIcon(description: String, onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        Modifier.size(44.dp).clip(CircleShape)
            .clickable(onClickLabel = description, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { content() }
}

/** The one place to act, set apart from the reading surface by a hairline. */
@Composable
private fun BottomBar(label: String? = null, trailingLabel: String? = null, content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(T.Paper)
            .drawBehind { drawLine(T.PaperLine, Offset(0f, 0f), Offset(size.width, 0f), 1.dp.toPx()) }
            .padding(start = 24.dp, end = 24.dp, top = 14.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (label != null) {
            Row(Modifier.fillMaxWidth()) {
                Text(label.uppercase(), color = T.Muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp, modifier = Modifier.weight(1f))
                if (trailingLabel != null) Text(trailingLabel, color = T.Muted, fontSize = 12.sp)
            }
        }
        content()
    }
}

@Composable
private fun ArabicText(text: String, size: Int, color: Color, modifier: Modifier = Modifier) {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        Text(
            text,
            color = color,
            fontFamily = ReadingArabicFont,
            fontSize = size.sp,
            lineHeight = (size * 1.45).sp,
            textAlign = TextAlign.Center,
            modifier = modifier.fillMaxWidth(),
        )
    }
}

/** Small outlined verse number, centered above the verse. */
@Composable
private fun VerseMark(number: Int) {
    Box(
        Modifier.size(28.dp)
            .drawBehind { drawCircle(T.Accent.copy(alpha = 0.45f), radius = size.minDimension / 2 - 0.5.dp.toPx(), style = Stroke(1.dp.toPx())) }
            .semantics { contentDescription = "Ayah $number" },
        contentAlignment = Alignment.Center,
    ) { Text(number.toString(), color = T.Accent, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }
}

@Composable
private fun VerseDivider() {
    Box(Modifier.padding(vertical = 22.dp).width(56.dp).height(1.dp).background(T.PaperLine))
}

// MARK: Reading

/**
 * A reading pause, one page at a time. After the first page, "Keep reading" turns to the next one
 * (the rest of a wird, the next wird due today, then the main surah), and every page read counts.
 */
@Composable
private fun ReadingScreen(vm: MainViewModel) {
    val state = vm.state
    var page by remember { mutableStateOf(vm.firstSegment()) }
    val current = page ?: return
    // Pages already counted in this pause, and surahs finished along the way.
    val read = remember { mutableStateListOf<Segment>() }
    val finished = remember { mutableStateListOf<String>() }
    val verses = current.verses
    val surah = current.surah
    val duration = remember(current, state.readingSpeed) { vm.readingSeconds(verses) }
    var elapsed by remember(current) { mutableIntStateOf(0) }
    val ready = elapsed >= duration
    val canClose = vm.isManualGate
    var menu by remember { mutableStateOf(false) }
    val scroll = remember(current) { ScrollState(0) }
    val next = remember(current, ready) { if (ready) vm.nextSegment(current) else null }

    BackHandler { if (canClose) vm.dismissGate() }
    LaunchedEffect(current) { while (elapsed < duration) { delay(1_000); elapsed += 1 } }

    fun recordCurrent() {
        vm.recordSegment(current)?.let { finished += it }
        read += current
    }

    val range = when {
        verses.isEmpty() -> ""
        verses.size == 1 -> "Ayah ${verses.first().id} of ${surah.totalVerses}"
        else -> "Ayahs ${verses.first().id}–${verses.last().id} of ${surah.totalVerses}"
    }
    val sessionCount = read.sumOf { it.verses.size }

    Column(Modifier.fillMaxSize().background(T.Paper).statusBarsPadding().navigationBarsPadding()) {
        GateHeader("Surah ${surah.name}", if (canClose) vm::dismissGate else null) {
            Box {
                QuietIcon("Text settings", { menu = true }) {
                    Text("Aa", color = T.Muted, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                }
                DropdownMenu(
                    expanded = menu,
                    onDismissRequest = { menu = false },
                    offset = DpOffset((-8).dp, 4.dp),
                    shape = RoundedCornerShape(20.dp),
                    containerColor = T.Surface,
                    tonalElevation = 0.dp,
                    shadowElevation = 8.dp,
                    border = BorderStroke(1.dp, T.PaperLine),
                ) {
                    TextSettings(vm)
                }
            }
        }

        Column(
            Modifier.weight(1f).verticalScroll(scroll).padding(horizontal = 28.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (current.wirdId != null && verses.firstOrNull()?.id == 1) {
                Text("TODAY’S WIRD", color = T.Muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp)
                Spacer(Modifier.height(16.dp))
            }
            if (state.readIn == ReadIn.ENGLISH && verses.any { it.translation == null }) {
                Text("English meaning isn’t available for this surah yet.", color = T.Muted, fontSize = 13.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.height(16.dp))
            }
            verses.forEachIndexed { index, verse ->
                if (index > 0) VerseDivider()
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    VerseMark(verse.id)
                    VerseLines(verse, state.readIn, state.showArabic, state.showTransliteration, state.showMeaning)
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        val left = (duration - elapsed).coerceAtLeast(0)
        val label = when {
            sessionCount > 0 -> if (sessionCount == 1) "1 verse read" else "$sessionCount verses read"
            current.wirdId != null -> "Today’s wird"
            canClose -> "Reading"
            else -> "Reading moment"
        }
        BottomBar(
            label = label,
            trailingLabel = if (ready) range else "$range · %d:%02d".format(left / 60, left % 60),
        ) {
            ThinProgress(if (duration > 0) elapsed.toFloat() / duration else 1f)
            when {
                ready && next != null -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SoftButton(if (next.surah.id != surah.id) "Next: ${next.surah.name}" else "Keep reading", Modifier.weight(1f)) {
                        recordCurrent()
                        page = vm.nextSegment(current)
                    }
                    Box(Modifier.weight(1f)) {
                        PrimaryButton("Done") { recordCurrent(); vm.finishSession(read.toList(), finished.toList()) }
                    }
                }
                ready -> PrimaryButton(if (read.isEmpty()) "Done reading" else "Done") {
                    recordCurrent()
                    vm.finishSession(read.toList(), finished.toList())
                }
                // Mid-page after reading more: stop here, counting only the pages finished.
                read.isNotEmpty() -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { WaitBar("Reading…", "Keep reading. $left seconds left") }
                    SoftButton("Stop here", Modifier.weight(1f)) { vm.finishSession(read.toList(), finished.toList()) }
                }
                else -> WaitBar("Reading…", "Keep reading. $left seconds left")
            }
        }
    }
}

@Composable
private fun ThinProgress(value: Float) {
    Box(Modifier.fillMaxWidth().height(2.dp).background(T.PaperLine)) {
        Box(Modifier.fillMaxWidth(value.coerceIn(0f, 1f)).height(2.dp).background(T.Accent))
    }
}

@Composable
private fun Translit(text: String, size: Int) {
    Text(text, color = T.Muted, fontFamily = SerifItalicFont, fontSize = size.sp, lineHeight = (size * 1.4).sp, textAlign = TextAlign.Center)
}

/** One verse: the text the person reads, large; the others smaller underneath. */
@Composable
private fun VerseLines(verse: Verse, readIn: ReadIn, showArabic: Boolean, showTranslit: Boolean, showMeaning: Boolean) {
    val translation = verse.translation
    // Without a translation, an English reader still gets the Arabic.
    val main = if (readIn == ReadIn.ENGLISH && translation == null) ReadIn.ARABIC else readIn
    when (main) {
        ReadIn.ARABIC -> ArabicText(verse.text, 44, T.Ink)
        ReadIn.TRANSLITERATION -> Text(verse.transliteration, color = T.Ink, fontFamily = SerifFont, fontSize = 28.sp, lineHeight = 38.sp, textAlign = TextAlign.Center)
        ReadIn.ENGLISH -> Text(translationText(translation!!), color = T.Ink, fontFamily = SerifFont, fontSize = 23.sp, lineHeight = 32.sp, textAlign = TextAlign.Center)
    }
    if (main != ReadIn.ARABIC && showArabic) ArabicText(verse.text, if (main == ReadIn.TRANSLITERATION) 28 else 30, T.MutedStrong)
    if (main != ReadIn.TRANSLITERATION && showTranslit) Translit(verse.transliteration, if (main == ReadIn.ARABIC) 20 else 17)
    if (main != ReadIn.ENGLISH && showMeaning && translation != null) {
        Text(translationText(translation), color = T.InkSoft, fontSize = 15.sp, lineHeight = 22.sp, textAlign = TextAlign.Center)
    }
    if (translation != null && (main == ReadIn.ENGLISH || showMeaning)) Footnotes(verse.footnotes)
}

/** The "Aa" card: which text to read in, and what else to show with it. */
@Composable
private fun TextSettings(vm: MainViewModel) {
    val state = vm.state
    Column(Modifier.width(300.dp).padding(horizontal = 20.dp, vertical = 10.dp)) {
        MenuLabel("Read in")
        Spacer(Modifier.height(8.dp))
        Segmented(ReadIn.entries.map { it to it.short }, state.readIn) { v -> vm.update { it.copy(readIn = v) } }
        Spacer(Modifier.height(16.dp))
        MenuLabel("Also show")
        val others = ReadIn.entries.filter { it != state.readIn }
        others.forEachIndexed { i, other ->
            if (i > 0) Box(Modifier.fillMaxWidth().height(1.dp).background(T.PaperLine))
            when (other) {
                ReadIn.ARABIC -> MenuToggle("Arabic", "The verse in Arabic script", state.showArabic) { v -> vm.update { it.copy(showArabic = v) } }
                ReadIn.TRANSLITERATION -> MenuToggle("Transliteration", "How it sounds, in Latin letters", state.showTransliteration) { v -> vm.update { it.copy(showTransliteration = v) } }
                ReadIn.ENGLISH -> MenuToggle("Meaning", "The English translation", state.showMeaning) { v -> vm.update { it.copy(showMeaning = v) } }
            }
        }
    }
}

@Composable
private fun MenuLabel(text: String) {
    Text(text.uppercase(), color = T.Muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp, modifier = Modifier.padding(top = 6.dp))
}

@Composable
private fun MenuToggle(label: String, detail: String, checked: Boolean, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
            .toggleable(value = checked, enabled = enabled, role = Role.Switch, onValueChange = onChange)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, color = if (enabled) T.Ink else T.Muted, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            Text(detail, color = T.Muted, fontSize = 12.sp, lineHeight = 16.sp)
        }
        Spacer(Modifier.width(12.dp))
        Switch(
            checked = checked,
            onCheckedChange = null,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = T.Accent,
                checkedBorderColor = T.Accent,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = T.Track,
                uncheckedBorderColor = T.Outline,
                disabledCheckedThumbColor = Color.White,
                disabledCheckedTrackColor = T.Accent.copy(alpha = 0.4f),
                disabledCheckedBorderColor = Color.Transparent,
            ),
            thumbContent = null,
            modifier = Modifier.scale(0.85f),
        )
    }
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

    Column(Modifier.fillMaxSize().background(T.Paper).statusBarsPadding().navigationBarsPadding()) {
        GateHeader("Muraja’ah · ${surah.name}", if (canClose) vm::dismissGate else null)

        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 28.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            VerseMark(verse.id)
            Text(caption, color = T.Muted, fontSize = 14.sp, textAlign = TextAlign.Center)
            // People who don't read the Arabic script recall the transliteration instead.
            val arabic = state.readIn == ReadIn.ARABIC
            FadingVerse(if (arabic) verse.words else verse.transliterationWords, stage, revealed, arabic)
            if (stage == 0 && arabic && state.showTransliteration) Translit(verse.transliteration, 20)
            if (stage == 0 && !arabic && state.showArabic) ArabicText(verse.text, 28, T.MutedStrong)
            VerseDivider()
            Overline(if (stage == 3 && !revealed) "Recall the verse that means" else "Meaning", color = T.Muted)
            Text(translationText(verse.translation ?: "Ayah ${verse.id} of ${surah.name}"), color = T.InkSoft, fontFamily = SerifFont, fontSize = 20.sp, lineHeight = 28.sp, textAlign = TextAlign.Center)
            if (revealed || stage < 3) Footnotes(verse.footnotes)
        }

        BottomBar(label = "Review", trailingLabel = "Ayah ${verse.id} of ${surah.totalVerses}") {
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

/** The verse word by word (Arabic right to left, or transliteration left to right), with words faded or hidden by stage. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FadingVerse(words: List<String>, stage: Int, revealed: Boolean, arabic: Boolean) {
    val label = when {
        revealed || stage == 0 -> words.joinToString(" ")
        stage == 2 && words.isNotEmpty() -> "${words.first()}, then recall the rest"
        else -> "Recall this verse"
    }
    CompositionLocalProvider(LocalLayoutDirection provides if (arabic) LayoutDirection.Rtl else LayoutDirection.Ltr) {
        FlowRow(
            Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = label },
            horizontalArrangement = Arrangement.spacedBy(if (arabic) 12.dp else 8.dp, Alignment.CenterHorizontally),
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
                    fontFamily = if (arabic) ReadingArabicFont else SerifFont,
                    fontSize = if (arabic) 42.sp else 28.sp,
                    lineHeight = if (arabic) 62.sp else 40.sp,
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
            else Text(translationText(info.cardText), color = T.InkSoft, fontSize = 16.sp, lineHeight = 23.sp)
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
