package com.tilawa.app.blocking

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
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
        if (lastIntercepted == packageName && now - lastInterceptedAt < 2_000) return
        lastIntercepted = packageName
        lastInterceptedAt = now

        Log.i(TAG, "Guarding $packageName and posting reading notification")
        sendHomeAndNotify(packageName)
    }

    /**
     * Android skins such as MIUI do not reliably allow an accessibility service
     * to open an Activity from the background. We therefore background the
     * guarded task and let the user open the reading gate from a notification.
     */
    private fun sendHomeAndNotify(packageName: String) {
        performGlobalAction(GLOBAL_ACTION_HOME)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel(manager)

        val appLabel = runCatching {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0)).toString()
        }.getOrDefault("your app")
        val gateIntent = Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_GATE_PACKAGE, packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (!manager.areNotificationsEnabled()) {
            Log.w(TAG, "Notifications are disabled; falling back to opening the gate directly")
            runCatching { startActivity(gateIntent) }
                .onFailure { Log.e(TAG, "Could not open reading gate fallback", it) }
            return
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            packageName.hashCode(),
            gateIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = "$appLabel is paused"
        val message = "Tap to read your next ayahs in Tilawa. When you finish, $appLabel will open."
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(com.tilawa.app.R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(
                Notification.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText(message)
                    .setSummaryText("Tilawa · Quran reading gate"),
            )
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setColor(0xFFB8860B.toInt())
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, com.tilawa.app.R.drawable.ic_notification),
                    "READ NOW",
                    contentIntent,
                ).build(),
            )
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Reading gate",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Shown when a guarded app requires Quran reading"
                },
            )
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onInterrupt() = Unit

    companion object {
        private const val TAG = "TilawaGuard"
        private const val CHANNEL_ID = "tilawa_reading_gate"
        private const val NOTIFICATION_ID = 4107
    }
}
