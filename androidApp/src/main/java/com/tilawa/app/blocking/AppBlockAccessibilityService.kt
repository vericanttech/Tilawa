package com.tilawa.app.blocking

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.tilawa.app.MainActivity

class AppBlockAccessibilityService : AccessibilityService() {
    private val guard by lazy { AppGuardRepository(this) }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastIntercepted: String? = null
    private var lastInterceptedAt = 0L
    private var pendingGatePackage: String? = null

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
        if (lastIntercepted == packageName && now - lastInterceptedAt < 2_000) return
        lastIntercepted = packageName
        lastInterceptedAt = now

        Log.i(TAG, "Opening reading gate for $packageName")
        openGateReliably(packageName)
    }

    /**
     * Some Android skins let a guarded app's next Activity win the foreground
     * race after an accessibility service starts the gate. Sending Home first
     * backgrounds the whole guarded task, then Tilawa can be brought forward
     * deterministically without relying on overlay permission.
     */
    private fun openGateReliably(packageName: String) {
        if (pendingGatePackage == packageName) return
        pendingGatePackage = packageName
        performGlobalAction(GLOBAL_ACTION_HOME)
        mainHandler.postDelayed({
            runCatching {
                startActivity(
                    Intent(this, MainActivity::class.java)
                        .putExtra(MainActivity.EXTRA_GATE_PACKAGE, packageName)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                )
            }.onFailure { Log.e(TAG, "Could not open reading gate", it) }
            mainHandler.postDelayed({
                if (pendingGatePackage == packageName) pendingGatePackage = null
            }, 1_500)
        }, 250)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onInterrupt() = Unit

    companion object { private const val TAG = "TilawaGuard" }
}
