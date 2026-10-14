package com.tilawa.app.blocking

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.tilawa.app.MainActivity

class AppBlockAccessibilityService : AccessibilityService() {
    private val guard by lazy { AppGuardRepository(this) }
    private var lastIntercepted: String? = null
    private var lastInterceptedAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        Log.d(TAG, "Foreground package changed to $packageName")
        if (packageName == this.packageName) return
        if (packageName !in guard.guardedPackages()) return
        if (guard.isTemporarilyAllowed(packageName)) {
            Log.d(TAG, "$packageName is inside its unlock window")
            return
        }

        val now = System.currentTimeMillis()
        if (lastIntercepted == packageName && now - lastInterceptedAt < 1_000) return
        lastIntercepted = packageName
        lastInterceptedAt = now

        Log.i(TAG, "Opening reading gate for $packageName")
        runCatching {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .putExtra(MainActivity.EXTRA_GATE_PACKAGE, packageName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            )
        }.onFailure { Log.e(TAG, "Could not open reading gate", it) }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onInterrupt() = Unit

    companion object { private const val TAG = "TilawaGuard" }
}
