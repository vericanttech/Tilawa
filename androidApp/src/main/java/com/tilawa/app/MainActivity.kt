package com.tilawa.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.graphics.Color
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.content.ContextCompat

class MainActivity : ComponentActivity() {
    private val viewModel by viewModels<MainViewModel>()
    private val notificationPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Light app: dark status/navigation icons regardless of the system dark mode.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.WHITE, Color.WHITE),
        )
        handleIntent(intent)
        // New people are asked in onboarding, with the reminder settings in front of them.
        if (viewModel.state.hasCompletedOnboarding && viewModel.state.remindersOn) requestNotificationPermissionIfNeeded()
        setContent { TilawaApp(viewModel) }
    }

    override fun onResume() {
        super.onResume()
        viewModel.refreshNextReminder()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        when {
            intent?.hasExtra(EXTRA_GATE_PACKAGE) == true -> viewModel.showGate(intent.getStringExtra(EXTRA_GATE_PACKAGE))
            // A reading reminder: today's wird first, then the main surah.
            intent?.getBooleanExtra(EXTRA_REMINDER, false) == true -> {
                intent.removeExtra(EXTRA_REMINDER)
                viewModel.showGate(null, useWird = true)
            }
            // The "Read now" notification after a pause: reads today's wird first, like the pause itself.
            intent?.data?.scheme == "tilawa" -> viewModel.showGate(null, useWird = true)
        }
    }

    fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    companion object {
        const val EXTRA_GATE_PACKAGE = "com.tilawa.app.GATE_PACKAGE"
        const val EXTRA_REMINDER = "com.tilawa.app.REMINDER"
    }
}
