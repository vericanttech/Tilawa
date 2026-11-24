package com.tilawa.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.Column
import com.tilawa.app.ui.GateScreen
import com.tilawa.app.ui.OnboardingScreen
import com.tilawa.app.ui.ProgressScreen
import com.tilawa.app.ui.SettingsScreen
import com.tilawa.app.ui.SurahLibrary
import com.tilawa.app.ui.T
import com.tilawa.app.ui.TilawaTheme
import com.tilawa.app.ui.TodayScreen

private enum class Tab(val label: String) { TODAY("Today"), SURAHS("Surahs"), PROGRESS("Progress"), SETTINGS("Settings") }

@Composable
fun TilawaApp(vm: MainViewModel) = TilawaTheme {
    when {
        !vm.state.hasCompletedOnboarding -> OnboardingScreen(vm)
        vm.gatePackage != null -> GateScreen(vm)
        else -> MainTabs(vm)
    }
}

@Composable
private fun MainTabs(vm: MainViewModel) {
    var tab by rememberSaveable { mutableStateOf(Tab.TODAY) }
    Scaffold(
        containerColor = T.Mist,
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            Column {
                HorizontalDivider(color = T.Hairline)
                NavigationBar(containerColor = T.Surface) {
                    Tab.entries.forEach { item ->
                        val icon = when (item) {
                            Tab.TODAY -> Icons.Default.WbSunny
                            Tab.SURAHS -> Icons.AutoMirrored.Filled.MenuBook
                            Tab.PROGRESS -> Icons.Default.BarChart
                            Tab.SETTINGS -> Icons.Default.Settings
                        }
                        NavigationBarItem(
                            selected = tab == item,
                            onClick = { tab = item },
                            icon = { Icon(icon, null) },
                            label = { Text(item.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = T.Accent,
                                selectedTextColor = T.Accent,
                                indicatorColor = T.AccentTint,
                                unselectedIconColor = T.Muted,
                                unselectedTextColor = T.Muted,
                            ),
                        )
                    }
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize().statusBarsPadding()) {
            when (tab) {
                Tab.TODAY -> TodayScreen(vm)
                Tab.SURAHS -> SurahLibrary(vm, showTitle = true)
                Tab.PROGRESS -> ProgressScreen(vm)
                Tab.SETTINGS -> SettingsScreen(vm)
            }
        }
    }
}

