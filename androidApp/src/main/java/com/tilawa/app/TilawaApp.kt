package com.tilawa.app

import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessibilityNew
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tilawa.app.data.Language
import com.tilawa.app.data.LockDelay
import com.tilawa.app.data.ReadingSpeed
import com.tilawa.app.data.Surah
import com.tilawa.app.ui.ArabicFont
import com.tilawa.app.ui.ChromeBg
import com.tilawa.app.ui.ChromeCard
import com.tilawa.app.ui.ChromeCard2
import com.tilawa.app.ui.ChromeMuted
import com.tilawa.app.ui.ChromeText
import com.tilawa.app.ui.Danger
import com.tilawa.app.ui.DisplayFont
import com.tilawa.app.ui.Gold
import com.tilawa.app.ui.GoldLight
import com.tilawa.app.ui.Ink
import com.tilawa.app.ui.InkLight
import com.tilawa.app.ui.InkMid
import com.tilawa.app.ui.Parchment
import com.tilawa.app.ui.TilawaTheme
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

private enum class Tab { HOME, SURAH, SETTINGS }

@Composable
fun TilawaApp(vm: MainViewModel) = TilawaTheme {
    var selectedTab by remember { mutableStateOf(if (vm.state.isFirstLaunch) Tab.SURAH else Tab.HOME) }
    val gate = vm.gatePackage
    if (gate != null) {
        GateScreen(vm)
        return@TilawaTheme
    }

    Scaffold(
        containerColor = ChromeBg,
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            NavigationBar(containerColor = Parchment, modifier = Modifier.navigationBarsPadding()) {
                listOf(
                    Triple(Tab.HOME, Icons.Default.Home, copy(vm.state.language, "Home", "Accueil", "الرئيسية")),
                    Triple(Tab.SURAH, Icons.Default.Book, copy(vm.state.language, "Surah", "Sourate", "السورة")),
                    Triple(Tab.SETTINGS, Icons.Default.Settings, copy(vm.state.language, "Settings", "Réglages", "الإعدادات")),
                ).forEach { (tab, icon, label) ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = { Icon(icon, null) },
                        label = { Text(label, fontFamily = DisplayFont) },
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize().statusBarsPadding()) {
            when (selectedTab) {
                Tab.HOME -> HomeScreen(vm) { selectedTab = Tab.SETTINGS }
                Tab.SURAH -> SurahScreen(vm) {
                    vm.completeFirstLaunch()
                    selectedTab = Tab.HOME
                }
                Tab.SETTINGS -> SettingsScreen(vm)
            }
        }
    }
}

@Composable
private fun ScreenTitle(title: String, subtitle: String? = null) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 18.dp)) {
        Text(title, color = ChromeText, fontFamily = DisplayFont, fontSize = 28.sp)
        if (subtitle != null) Text(subtitle, color = ChromeMuted, fontFamily = DisplayFont, fontStyle = FontStyle.Italic, fontSize = 14.sp)
    }
}

@Composable
private fun HomeScreen(vm: MainViewModel, openSettings: () -> Unit) {
    val state = vm.state
    val surah = vm.quran.surah(state.selectedSurahId) ?: return
    val chunk = surah.chunks.getOrNull(state.currentChunkIndex) ?: return
    val nextVerse = surah.verses.firstOrNull { it.id == chunk.ayahIds.firstOrNull() }
    val guardedCount = vm.appGuard.guardedPackages().size

    LazyColumn(Modifier.fillMaxSize()) {
        item { ScreenTitle("Tilawa", copy(state.language, "A pause for recitation", "Une pause pour réciter", "وقفة للتلاوة")) }
        if (!vm.accessibilityEnabled() && guardedCount > 0) {
            item {
                ActionCard(
                    icon = { Icon(Icons.Default.AccessibilityNew, null, tint = Gold) },
                    title = copy(state.language, "Enable app guarding", "Activer la protection", "فعّل حماية التطبيقات"),
                    body = copy(state.language, "Android requires Accessibility access to notice when a guarded app opens.", "Android nécessite l’accès d’accessibilité pour détecter une application protégée.", "يتطلب أندرويد إذن تسهيلات الاستخدام لاكتشاف فتح تطبيق محمي."),
                    button = copy(state.language, "Open settings", "Ouvrir les réglages", "فتح الإعدادات"),
                ) {
                    openSettings()
                }
            }
        }
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = Parchment),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.padding(20.dp).fillMaxWidth(),
            ) {
                Column(Modifier.padding(22.dp)) {
                    Text(copy(state.language, "CURRENT SURAH", "SOURATE ACTUELLE", "السورة الحالية"), color = Gold, fontSize = 11.sp, letterSpacing = 2.sp)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(surah.transliteration, color = Ink, fontFamily = DisplayFont, fontSize = 28.sp)
                            Text(surah.nameArabic, color = InkMid, fontFamily = ArabicFont, fontSize = 28.sp)
                        }
                        Text("${chunk.ayahIds.first()} / ${surah.totalVerses}", color = InkLight, fontFamily = DisplayFont)
                    }
                    Spacer(Modifier.height(14.dp))
                    LinearProgressIndicator(
                        progress = { chunk.ayahIds.first().toFloat() / surah.totalVerses.coerceAtLeast(1) },
                        color = Gold,
                        trackColor = Gold.copy(alpha = .15f),
                        modifier = Modifier.fillMaxWidth().height(4.dp),
                    )
                    if (nextVerse != null) {
                        HorizontalDivider(Modifier.padding(vertical = 18.dp), color = Gold.copy(alpha = .2f))
                        Text(copy(state.language, "UP NEXT · AYAH ${nextVerse.id}", "À SUIVRE · AYAH ${nextVerse.id}", "التالي · الآية ${nextVerse.id}"), color = Gold, fontSize = 10.sp, letterSpacing = 1.5.sp)
                        Text(nextVerse.text, color = Ink, fontFamily = ArabicFont, fontSize = 25.sp, textAlign = TextAlign.End, modifier = Modifier.fillMaxWidth())
                        if (state.showTransliteration) Text(nextVerse.transliteration, color = InkLight, fontFamily = DisplayFont, fontStyle = FontStyle.Italic, fontSize = 14.sp)
                    }
                }
            }
        }
        item {
            Row(Modifier.padding(horizontal = 20.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(state.totalAyahsRead.toString(), copy(state.language, "Ayahs", "Ayahs", "آيات"), Modifier.weight(1f))
                StatCard(state.streakDays.toString(), copy(state.language, "Streak", "Série", "السلسلة"), Modifier.weight(1f), GoldLight)
                StatCard(state.todayAyahsRead.toString(), copy(state.language, "Today", "Aujourd’hui", "اليوم"), Modifier.weight(1f))
            }
        }
        item {
            Column(Modifier.padding(20.dp)) {
                Text(copy(state.language, "GUARDED APPS", "APPLICATIONS PROTÉGÉES", "التطبيقات المحمية"), color = ChromeMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Spacer(Modifier.height(10.dp))
                Text(
                    if (guardedCount == 0) copy(state.language, "No apps selected yet", "Aucune application sélectionnée", "لم يتم تحديد تطبيقات")
                    else copy(state.language, "$guardedCount app${if (guardedCount == 1) "" else "s"} guarded", "$guardedCount application(s) protégée(s)", "$guardedCount تطبيقات محمية"),
                    color = ChromeText,
                    fontFamily = DisplayFont,
                    fontSize = 18.sp,
                )
                Spacer(Modifier.height(12.dp))
                Button(onClick = { vm.showGate(null) }, colors = ButtonDefaults.buttonColors(containerColor = Gold), modifier = Modifier.fillMaxWidth().height(52.dp)) {
                    Text(copy(state.language, "Read the next ayahs", "Lire les prochains ayahs", "اقرأ الآيات التالية"), color = Ink, fontFamily = DisplayFont, fontSize = 17.sp)
                }
            }
        }
    }
}

@Composable
private fun StatCard(value: String, label: String, modifier: Modifier, valueColor: Color = ChromeText) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = ChromeCard), border = BorderStroke(1.dp, Gold.copy(alpha = .18f))) {
        Column(Modifier.padding(vertical = 15.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, color = valueColor, fontFamily = DisplayFont, fontSize = 27.sp)
            Text(label.uppercase(), color = ChromeMuted, fontSize = 9.sp, letterSpacing = 1.2.sp)
        }
    }
}

@Composable
private fun SurahScreen(vm: MainViewModel, done: () -> Unit) {
    var query by remember { mutableStateOf("") }
    val state = vm.state
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(copy(state.language, "Choose your surah", "Choisissez votre sourate", "اختر سورتك"), color = ChromeText, fontFamily = DisplayFont, fontSize = 25.sp, modifier = Modifier.weight(1f))
            TextButton(onClick = done) { Text(copy(state.language, "Done", "Terminé", "تم"), color = Gold) }
        }
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            leadingIcon = { Icon(Icons.Default.Search, null) },
            placeholder = { Text(copy(state.language, "Search by name", "Rechercher par nom", "البحث بالاسم")) },
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
            singleLine = true,
            modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        LazyColumn(Modifier.weight(1f).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            items(vm.quran.search(query), key = { it.id }) { surah ->
                SurahRow(surah, state.selectedSurahId == surah.id) {
                    vm.update { it.copy(selectedSurahId = surah.id, currentChunkIndex = 0) }
                }
            }
        }
    }
}

@Composable
private fun SurahRow(surah: Surah, selected: Boolean, select: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))
            .background(if (selected) Gold.copy(alpha = .12f) else ChromeCard)
            .border(1.dp, if (selected) Gold else Gold.copy(alpha = .15f), RoundedCornerShape(10.dp))
            .clickable(onClick = select).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(surah.id.toString(), color = ChromeMuted, fontSize = 11.sp, modifier = Modifier.width(32.dp))
        Column(Modifier.weight(1f)) {
            Text(surah.transliteration, color = ChromeText, fontFamily = DisplayFont, fontSize = 17.sp)
            Text("${surah.totalVerses} ayahs · ${surah.type}", color = ChromeMuted, fontSize = 11.sp)
        }
        Text(surah.nameArabic, color = if (selected) GoldLight else ChromeMuted, fontFamily = ArabicFont, fontSize = 23.sp)
        if (selected) Icon(Icons.Default.Check, null, tint = Gold, modifier = Modifier.padding(start = 8.dp).size(20.dp))
    }
}

@Composable
private fun SettingsScreen(vm: MainViewModel) {
    val context = LocalContext.current
    val state = vm.state
    var showApps by remember { mutableStateOf(false) }
    var showReset by remember { mutableStateOf(false) }
    var serviceEnabled by remember { mutableStateOf(vm.accessibilityEnabled()) }

    if (showApps) AppPickerDialog(vm) { showApps = false }
    if (showReset) AlertDialog(
        onDismissRequest = { showReset = false },
        title = { Text(copy(state.language, "Reset progress?", "Réinitialiser ?", "إعادة ضبط التقدم؟")) },
        text = { Text(copy(state.language, "Your reading totals and streak will be erased.", "Vos totaux et votre série seront effacés.", "سيتم مسح إجمالي القراءة والسلسلة.")) },
        confirmButton = { TextButton(onClick = { vm.resetProgress(); showReset = false }) { Text(copy(state.language, "Reset", "Réinitialiser", "إعادة ضبط"), color = Danger) } },
        dismissButton = { TextButton(onClick = { showReset = false }) { Text(copy(state.language, "Cancel", "Annuler", "إلغاء")) } },
    )

    LazyColumn(Modifier.fillMaxSize()) {
        item { ScreenTitle(copy(state.language, "Settings", "Réglages", "الإعدادات"), copy(state.language, "Make Tilawa yours", "Personnalisez Tilawa", "خصص تلاوة")) }
        item {
            Section(copy(state.language, "APP GUARD", "PROTECTION", "حماية التطبيقات")) {
                SettingsButton(Icons.Default.Add, copy(state.language, "Choose guarded apps", "Choisir les applications", "اختر التطبيقات المحمية"), "${vm.appGuard.guardedPackages().size} selected") {
                    vm.refreshApps(); showApps = true
                }
                HorizontalDivider(color = Gold.copy(alpha = .12f))
                SettingsButton(Icons.Default.AccessibilityNew, copy(state.language, "Accessibility service", "Service d’accessibilité", "خدمة تسهيلات الاستخدام"), if (serviceEnabled) "Enabled" else "Required") {
                    context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    serviceEnabled = vm.accessibilityEnabled()
                }
            }
        }
        item {
            Section(copy(state.language, "READING", "LECTURE", "القراءة")) {
                ChoiceRow(copy(state.language, "Reading speed", "Vitesse de lecture", "سرعة القراءة"), ReadingSpeed.entries, state.readingSpeed) { vm.update { s -> s.copy(readingSpeed = it) } }
                HorizontalDivider(color = Gold.copy(alpha = .12f))
                ToggleRow(copy(state.language, "Show transliteration", "Afficher la translittération", "إظهار النقحرة"), state.showTransliteration) { vm.update { s -> s.copy(showTransliteration = it) } }
            }
        }
        item {
            Section(copy(state.language, "LOCK AGAIN AFTER", "VERROUILLER APRÈS", "إعادة القفل بعد")) {
                ChoiceRow("", LockDelay.entries, state.lockDelay) { vm.update { s -> s.copy(lockDelay = it) } }
            }
        }
        item {
            Section(copy(state.language, "LANGUAGE", "LANGUE", "اللغة")) {
                ChoiceRow("", Language.entries, state.language) { vm.update { s -> s.copy(language = it) } }
            }
        }
        item {
            OutlinedButton(onClick = { showReset = true }, border = BorderStroke(1.dp, Danger.copy(alpha = .5f)), modifier = Modifier.padding(20.dp).fillMaxWidth()) {
                Icon(Icons.Default.Refresh, null, tint = Danger)
                Spacer(Modifier.width(8.dp))
                Text(copy(state.language, "Reset reading progress", "Réinitialiser la progression", "إعادة ضبط تقدم القراءة"), color = Danger)
            }
        }
        item { Text("Tilawa for Android · 1.0.0", color = ChromeMuted, fontFamily = DisplayFont, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(24.dp)) }
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.padding(horizontal = 20.dp, vertical = 10.dp)) {
        Text(title, color = ChromeMuted, fontSize = 10.sp, letterSpacing = 2.sp)
        Spacer(Modifier.height(9.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(ChromeCard).border(1.dp, Gold.copy(alpha = .16f), RoundedCornerShape(10.dp)), content = content)
    }
}

@Composable
private fun SettingsButton(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = Gold, modifier = Modifier.size(24.dp))
        Column(Modifier.padding(start = 13.dp).weight(1f)) {
            Text(title, color = ChromeText, fontSize = 16.sp)
            Text(subtitle, color = ChromeMuted, fontSize = 12.sp)
        }
    }
}

@Composable
private fun ToggleRow(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, color = ChromeText, fontSize = 16.sp, modifier = Modifier.weight(1f))
        Switch(checked, onChange, colors = SwitchDefaults.colors(checkedTrackColor = Gold, checkedThumbColor = Ink))
    }
}

@Composable
private fun <T : Enum<T>> ChoiceRow(title: String, choices: List<T>, selected: T, onSelect: (T) -> Unit) {
    Column(Modifier.padding(16.dp)) {
        if (title.isNotBlank()) Text(title, color = ChromeText, fontSize = 16.sp, modifier = Modifier.padding(bottom = 10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            choices.forEach { choice ->
                val active = choice == selected
                Text(
                    choiceLabel(choice),
                    color = if (active) Ink else ChromeMuted,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f).clip(RoundedCornerShape(6.dp))
                        .background(if (active) Gold else ChromeCard2)
                        .clickable { onSelect(choice) }.padding(horizontal = 3.dp, vertical = 10.dp),
                )
            }
        }
    }
}

private fun choiceLabel(value: Enum<*>): String = when (value) {
    ReadingSpeed.SLOW -> "Slow"
    ReadingSpeed.NORMAL -> "Normal"
    ReadingSpeed.FAST -> "Fast"
    LockDelay.FIFTEEN_MINUTES -> "15 min"
    LockDelay.THIRTY_MINUTES -> "30 min"
    LockDelay.SIXTY_MINUTES -> "60 min"
    LockDelay.TWO_HOURS -> "2 hours"
    LockDelay.NONE -> "Never"
    Language.ENGLISH -> "English"
    Language.FRENCH -> "Français"
    Language.ARABIC -> "العربية"
    else -> value.name
}

@Composable
private fun AppPickerDialog(vm: MainViewModel, dismiss: () -> Unit) {
    var selected by remember { mutableStateOf(vm.appGuard.guardedPackages()) }
    AlertDialog(
        onDismissRequest = dismiss,
        title = { Text("Choose apps to guard") },
        text = {
            LazyColumn(Modifier.fillMaxHeight(.68f)) {
                items(vm.installedApps, key = { it.packageName }) { app ->
                    Row(Modifier.fillMaxWidth().clickable {
                        val enabled = app.packageName !in selected
                        vm.toggleGuard(app.packageName, enabled)
                        selected = vm.appGuard.guardedPackages()
                    }.padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(38.dp).clip(CircleShape).background(Gold.copy(alpha = .2f)), contentAlignment = Alignment.Center) {
                            Text(app.label.take(1).uppercase(), color = Gold)
                        }
                        Column(Modifier.padding(start = 11.dp).weight(1f)) {
                            Text(app.label)
                            Text(app.packageName, fontSize = 10.sp, color = Color.Gray)
                        }
                        Checkbox(app.packageName in selected, null, colors = CheckboxDefaults.colors(checkedColor = Gold))
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = dismiss) { Text("Done", color = Gold) } },
    )
}

@Composable
private fun ActionCard(icon: @Composable () -> Unit, title: String, body: String, button: String, action: () -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = Gold.copy(alpha = .08f)), border = BorderStroke(1.dp, Gold.copy(alpha = .3f)), modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth()) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.Top) {
            icon()
            Column(Modifier.padding(start = 12.dp).weight(1f)) {
                Text(title, color = ChromeText, fontWeight = FontWeight.SemiBold)
                Text(body, color = ChromeMuted, fontSize = 13.sp)
                TextButton(onClick = action, contentPadding = ButtonDefaults.TextButtonContentPadding) { Text(button, color = Gold) }
            }
        }
    }
}

@Composable
private fun GateScreen(vm: MainViewModel) {
    val state = vm.state
    val surah = vm.quran.surah(state.selectedSurahId) ?: return
    val chunk = surah.chunks.getOrNull(state.currentChunkIndex) ?: return
    val verses = chunk.ayahIds.mapNotNull { id -> surah.verses.firstOrNull { it.id == id } }
    val duration = verses.sumOf { it.wordCount }.times(state.readingSpeed.secondsPerWord).roundToInt().coerceAtLeast(3)
    var elapsed by remember(state.selectedSurahId, state.currentChunkIndex) { mutableIntStateOf(0) }
    val ready = elapsed >= duration
    BackHandler(enabled = true) { }
    LaunchedEffect(state.selectedSurahId, state.currentChunkIndex) {
        while (elapsed < duration) { delay(1_000); elapsed += 1 }
    }

    Column(Modifier.fillMaxSize().background(ChromeBg).statusBarsPadding().navigationBarsPadding()) {
        LazyColumn(Modifier.weight(1f).fillMaxWidth().background(Parchment).padding(horizontal = 28.dp)) {
            item {
                Text("SURAH ${surah.transliteration.uppercase()}", color = Gold, fontSize = 11.sp, letterSpacing = 2.sp, modifier = Modifier.fillMaxWidth().padding(top = 32.dp, bottom = 20.dp), textAlign = TextAlign.Center)
            }
            items(verses, key = { it.id }) { verse ->
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(25.dp).border(1.dp, Gold.copy(alpha = .45f), CircleShape), contentAlignment = Alignment.Center) { Text(verse.id.toString(), color = Gold, fontSize = 10.sp) }
                    Text(verse.text, color = Ink, fontFamily = ArabicFont, fontSize = 32.sp, lineHeight = 51.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
                    AnimatedVisibility(state.showTransliteration) {
                        Text(verse.transliteration, color = InkLight, fontFamily = DisplayFont, fontStyle = FontStyle.Italic, fontSize = 15.sp, lineHeight = 23.sp, textAlign = TextAlign.Center)
                    }
                    HorizontalDivider(Modifier.padding(vertical = 22.dp), color = Gold.copy(alpha = .2f))
                }
            }
        }
        Column(Modifier.fillMaxWidth().background(ChromeBg).padding(horizontal = 22.dp, vertical = 18.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Lock, null, tint = ChromeMuted, modifier = Modifier.size(18.dp))
                Text(copy(state.language, "  READING MOMENT", "  MOMENT DE LECTURE", "  لحظة قراءة"), color = ChromeMuted, fontSize = 10.sp, letterSpacing = 1.5.sp, modifier = Modifier.weight(1f))
                Text("${elapsed.coerceAtMost(duration)} / ${duration}s", color = ChromeMuted, fontSize = 11.sp)
            }
            Spacer(Modifier.height(12.dp))
            LinearProgressIndicator(progress = { elapsed.toFloat() / duration }, color = GoldLight, trackColor = Color.White.copy(alpha = .08f), modifier = Modifier.fillMaxWidth().height(3.dp))
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = vm::recordReadAndUnlock,
                enabled = ready,
                colors = ButtonDefaults.buttonColors(containerColor = Gold, contentColor = Ink, disabledContainerColor = Color.Transparent, disabledContentColor = Color.White.copy(alpha = .22f)),
                border = if (ready) null else BorderStroke(1.dp, Color.White.copy(alpha = .08f)),
                modifier = Modifier.fillMaxWidth().height(52.dp),
            ) { Text(if (ready) copy(state.language, "Continue to app ↗", "Continuer vers l’application ↗", "متابعة إلى التطبيق ↗") else copy(state.language, "Reading…", "Lecture…", "جارٍ القراءة…"), fontFamily = DisplayFont, fontSize = 17.sp) }
            Row(Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                Text("${state.totalAyahsRead}  AYAH", color = ChromeMuted, fontSize = 10.sp)
                Text("${state.streakDays}  STREAK", color = ChromeMuted, fontSize = 10.sp)
                Text("${state.todayAyahsRead}  TODAY", color = ChromeMuted, fontSize = 10.sp)
            }
        }
    }
}

private fun copy(language: Language, english: String, french: String, arabic: String): String = when (language) {
    Language.ENGLISH -> english
    Language.FRENCH -> french
    Language.ARABIC -> arabic
}
