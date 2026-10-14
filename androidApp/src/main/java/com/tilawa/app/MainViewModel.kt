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
import com.tilawa.app.data.GuardedApp
import com.tilawa.app.data.QuranRepository
import com.tilawa.app.data.StateStore

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val stateStore = StateStore(application)
    val quran = QuranRepository(application)
    val appGuard = AppGuardRepository(application)

    var state by mutableStateOf(stateStore.load())
        private set
    var gatePackage by mutableStateOf<String?>(null)
        private set
    var installedApps by mutableStateOf<List<GuardedApp>>(emptyList())
        private set

    fun update(transform: (AppState) -> AppState) {
        state = transform(state)
        stateStore.save(state)
    }

    fun completeFirstLaunch() = update { it.copy(isFirstLaunch = false) }
    fun showGate(packageName: String?) { gatePackage = packageName ?: MANUAL_GATE }
    fun dismissGate() { gatePackage = null }
    fun refreshApps() { installedApps = appGuard.launcherApps() }
    fun toggleGuard(packageName: String, enabled: Boolean) = appGuard.setGuarded(packageName, enabled)

    fun recordReadAndUnlock() {
        val surah = quran.surah(state.selectedSurahId) ?: return
        val chunk = surah.chunks.getOrNull(state.currentChunkIndex) ?: return
        state = stateStore.recordRead(state, chunk.ayahIds.size, surah.chunks.size)
        val target = gatePackage?.takeUnless { it == MANUAL_GATE }
        appGuard.beginUnlock(target, state.lockDelay.millis)
        gatePackage = null
        if (target != null) {
            getApplication<Application>().packageManager.getLaunchIntentForPackage(target)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                getApplication<Application>().startActivity(it)
            }
        }
    }

    fun resetProgress() { state = stateStore.resetProgress(state) }

    fun accessibilityEnabled(): Boolean {
        val context = getApplication<Application>()
        val expected = ComponentName(context, AppBlockAccessibilityService::class.java).flattenToString()
        return Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?.split(':')
            ?.any { it.equals(expected, ignoreCase = true) } == true
    }

    companion object { const val MANUAL_GATE = "__manual__" }
}
