package com.tilawa.app.ui

import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccessibilityNew
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle
import com.tilawa.app.MainViewModel
import com.tilawa.app.data.ReadingGoal
import com.tilawa.app.data.ReadingSpeed
import com.tilawa.app.data.Surah

/** Starter surahs suggested in onboarding and the library. */
object Suggested {
    val starters = listOf(1 to "A gentle start", 67 to "Often read at night", 36 to null, 18 to "Often read on Fridays")
    val library = listOf(67, 1, 36, 18, 55, 56, 112, 113, 114)
}

fun ReadingGoal.icon(): ImageVector = when (this) {
    ReadingGoal.FAMILIAR -> Icons.Default.Repeat
    ReadingGoal.REVIEW -> Icons.Default.Psychology
    ReadingGoal.MEANING -> Icons.Default.Translate
}

@Composable
fun OnboardingScreen(vm: MainViewModel) {
    var step by rememberSaveable { mutableIntStateOf(0) }
    var browsing by rememberSaveable { mutableStateOf(false) }
    BackHandler(enabled = step > 0 || browsing) { if (browsing) browsing = false else step -= 1 }

    if (browsing) {
        SurahLibrary(vm, showTitle = true, onBack = { browsing = false }, onPicked = { browsing = false })
        return
    }
    when (step) {
        0 -> Welcome { step = 1 }
        1 -> GoalStep(vm, back = { step = 0 }) { step = 2 }
        2 -> AppsStep(vm, back = { step = 1 }) { step = 3 }
        else -> SurahStep(vm, back = { step = 2 }, browse = { browsing = true }) { vm.completeOnboarding() }
    }
}

@Composable
private fun Welcome(next: () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(T.Mist).statusBarsPadding().navigationBarsPadding().padding(24.dp),
    ) {
        Spacer(Modifier.weight(1f))
        Box(
            Modifier.size(96.dp).clip(RoundedCornerShape(28.dp)).background(T.Accent),
            contentAlignment = Alignment.Center,
        ) { Text("اقرأ", color = androidx.compose.ui.graphics.Color.White, fontFamily = ArabicFont, fontSize = 34.sp) }
        Spacer(Modifier.height(28.dp))
        Text("Turn the moments you’d scroll into time with the Quran.", color = T.Ink, fontSize = 30.sp, fontWeight = FontWeight.Bold, lineHeight = 36.sp)
        Spacer(Modifier.height(12.dp))
        Text("Each time you reach for a distracting app, Tilawa gives you a few verses first.", color = T.Muted, fontSize = 17.sp, lineHeight = 24.sp)
        Spacer(Modifier.height(24.dp))
        listOf("Get familiar with a surah you love", "Keep what you’ve memorized fresh", "Read the meaning, even without Arabic").forEach {
            Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(24.dp).clip(CircleShape).background(T.AccentTint), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Check, null, tint = T.Accent, modifier = Modifier.size(14.dp))
                }
                Spacer(Modifier.width(12.dp))
                Text(it, color = T.InkSoft, fontSize = 16.sp)
            }
        }
        Spacer(Modifier.weight(1f))
        PrimaryButton("Get started", onClick = next)
        Text("Setup takes about a minute", color = T.Muted, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 12.dp))
    }
}

@Composable
private fun StepScaffold(
    current: Int,
    title: String,
    subtitle: String,
    back: () -> Unit,
    footer: @Composable () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(Modifier.fillMaxSize().background(T.Mist).statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CircleIconButton(Icons.AutoMirrored.Filled.ArrowBack, "Back", background = T.Surface, onClick = back)
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                StepBars(current, 3)
                Text("Step $current of 3", color = T.Muted, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
            }
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(title, color = T.Ink, fontSize = 28.sp, fontWeight = FontWeight.Bold, lineHeight = 34.sp)
            Text(subtitle, color = T.Muted, fontSize = 16.sp, lineHeight = 22.sp)
            Spacer(Modifier.height(8.dp))
            content()
        }
        Column(Modifier.padding(horizontal = 24.dp, vertical = 12.dp)) { footer() }
    }
}

@Composable
private fun GoalStep(vm: MainViewModel, back: () -> Unit, next: () -> Unit) {
    StepScaffold(
        1,
        "What brings you to Tilawa?",
        "This shapes what you see at each pause. You can switch anytime.",
        back,
        footer = { PrimaryButton("Continue", onClick = next) },
    ) {
        ReadingGoal.entries.forEach { goal -> GoalCard(goal, vm.state.goal == goal) { vm.setGoal(goal) } }
    }
}

@Composable
fun GoalCard(goal: ReadingGoal, on: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(T.Surface)
            .border(2.dp, if (on) T.Accent else T.Surface, RoundedCornerShape(20.dp))
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics { selected = on }
            .padding(18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(if (on) T.Accent else T.AccentTint),
            contentAlignment = Alignment.Center,
        ) { Icon(goal.icon(), null, tint = if (on) androidx.compose.ui.graphics.Color.White else T.Accent) }
        Column(Modifier.weight(1f).padding(start = 14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(goal.title, color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                if (goal == ReadingGoal.REVIEW) Text("  مراجعة", color = T.Muted, fontFamily = ArabicFont, fontSize = 16.sp)
            }
            Text(goal.summary, color = T.Muted, fontSize = 14.sp, lineHeight = 19.sp)
        }
    }
}

@Composable
private fun AppsStep(vm: MainViewModel, back: () -> Unit, next: () -> Unit) {
    val context = LocalContext.current
    var showPicker by rememberSaveable { mutableStateOf(false) }
    var serviceOn by rememberSaveable { mutableStateOf(vm.accessibilityEnabled()) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) { serviceOn = vm.accessibilityEnabled() }
    }
    if (showPicker) AppPickerSheet(vm) { showPicker = false }
    val count = vm.guardedPackages.size

    StepScaffold(
        2,
        "Which apps pull you in?",
        "Each time you open one, you’ll spend a few seconds with the Quran first. You can change them anytime.",
        back,
        footer = {
            PrimaryButton(if (count == 0) "Skip for now" else "Continue", onClick = next)
        },
    ) {
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(if (count == 0) "No apps chosen yet" else "$count app${if (count == 1) "" else "s"} chosen", color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Text("Social media, video, games…", color = T.Muted, fontSize = 14.sp)
                }
            }
            if (count > 0) {
                Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    vm.guardedPackages.take(6).forEach { LauncherIcon(it, it, size = 36) }
                }
            }
            Spacer(Modifier.height(14.dp))
            SoftButton(if (count == 0) "Choose apps" else "Add or remove apps", Modifier.fillMaxWidth()) { showPicker = true }
        }
        Card {
            Row(verticalAlignment = Alignment.Top) {
                Icon(Icons.Default.AccessibilityNew, null, tint = T.Accent)
                Column(Modifier.padding(start = 12.dp).weight(1f)) {
                    Text(if (serviceOn) "App pausing is on" else "Turn on app pausing", color = T.Ink, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "Android needs Accessibility access to notice when a paused app opens. Tilawa can’t read your screen and never stores or sends what you use.",
                        color = T.Muted, fontSize = 13.sp, lineHeight = 18.sp,
                    )
                    if (!serviceOn) {
                        Text(
                            "Open Accessibility settings",
                            color = T.Accent, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(top = 10.dp, bottom = 4.dp)
                                .clickable(role = Role.Button) { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) },
                        )
                        Text("Find “Tilawa app guard” under Downloaded apps.", color = T.Muted, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun SurahStep(vm: MainViewModel, back: () -> Unit, browse: () -> Unit, start: () -> Unit) {
    val goal = vm.state.goal
    val title = when (goal) {
        ReadingGoal.FAMILIAR -> "Which surah do you want to know well?"
        ReadingGoal.REVIEW -> "Which surah have you memorized?"
        ReadingGoal.MEANING -> "What would you like to read?"
    }
    val subtitle = when (goal) {
        ReadingGoal.FAMILIAR -> "You’ll read it in small pieces, over and over, until it feels familiar."
        ReadingGoal.REVIEW -> "Each pause asks you to recall one verse. Verses you know well come back less often."
        ReadingGoal.MEANING -> "Each pause continues where you left off, with the English meaning first."
    }
    StepScaffold(3, title, subtitle, back, footer = { PrimaryButton("Start", onClick = start) }) {
        val ids = Suggested.starters.map { it.first }.let { if (vm.state.selectedSurahId in it) it else listOf(vm.state.selectedSurahId) + it }
        ids.forEach { id ->
            val surah = vm.quran.surah(id) ?: return@forEach
            SurahChoice(surah, Suggested.starters.firstOrNull { it.first == id }?.second, vm.state.selectedSurahId == id) { vm.selectSurah(id) }
        }
        PlainButton("Browse all 114 surahs", onClick = browse)
        if (goal != ReadingGoal.REVIEW) {
            Spacer(Modifier.height(4.dp))
            Text("How long is each pause?", color = T.Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Segmented(
                listOf(ReadingSpeed.FAST to "Short", ReadingSpeed.NORMAL to "Medium", ReadingSpeed.SLOW to "Long"),
                vm.state.readingSpeed,
            ) { v -> vm.update { it.copy(readingSpeed = v) } }
        }
    }
}

@Composable
private fun SurahChoice(surah: Surah, note: String?, on: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(T.Surface)
            .border(2.dp, if (on) T.Accent else T.Surface, RoundedCornerShape(18.dp))
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics { selected = on }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(surah.name, color = T.Ink, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(listOfNotNull("${surah.totalVerses} verses", note).joinToString(" · "), color = T.Muted, fontSize = 13.sp)
        }
        Text(surah.nameArabic, color = if (on) T.Accent else T.MutedStrong, fontFamily = ArabicFont, fontSize = 22.sp)
    }
}

