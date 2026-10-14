package com.tilawa.app.blocking

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.tilawa.app.data.GuardedApp

class AppGuardRepository(private val context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun guardedPackages(): Set<String> = prefs.getStringSet(KEY_PACKAGES, emptySet())?.toSet().orEmpty()

    fun setGuarded(packageName: String, guarded: Boolean) {
        val updated = guardedPackages().toMutableSet().apply {
            if (guarded) add(packageName) else remove(packageName)
        }
        prefs.edit().putStringSet(KEY_PACKAGES, updated).apply()
    }

    fun launcherApps(): List<GuardedApp> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            .asSequence()
            .filter { it.activityInfo.packageName != context.packageName }
            .map { GuardedApp(it.activityInfo.packageName, it.loadLabel(context.packageManager).toString()) }
            .distinctBy { it.packageName }
            .sortedBy { it.label.lowercase() }
            .toList()
    }

    fun beginUnlock(packageName: String?, delayMillis: Long?) {
        prefs.edit()
            .putString(KEY_ALLOWED_PACKAGE, packageName)
            .putLong(KEY_UNLOCK_UNTIL, delayMillis?.let { System.currentTimeMillis() + it } ?: Long.MAX_VALUE)
            .apply()
    }

    fun isTemporarilyAllowed(packageName: String): Boolean =
        prefs.getString(KEY_ALLOWED_PACKAGE, null) == packageName &&
            System.currentTimeMillis() < prefs.getLong(KEY_UNLOCK_UNTIL, 0)

    companion object {
        const val PREFS = "tilawa_guard"
        const val KEY_PACKAGES = "guarded_packages"
        const val KEY_ALLOWED_PACKAGE = "allowed_package"
        const val KEY_UNLOCK_UNTIL = "unlock_until"
    }
}
