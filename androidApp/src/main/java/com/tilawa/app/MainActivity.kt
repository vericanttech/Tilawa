package com.tilawa.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels

class MainActivity : ComponentActivity() {
    private val viewModel by viewModels<MainViewModel>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleIntent(intent)
        setContent { TilawaApp(viewModel) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        when {
            intent?.hasExtra(EXTRA_GATE_PACKAGE) == true -> viewModel.showGate(intent.getStringExtra(EXTRA_GATE_PACKAGE))
            intent?.data?.scheme == "tilawa" -> viewModel.showGate(null)
        }
    }

    companion object { const val EXTRA_GATE_PACKAGE = "com.tilawa.app.GATE_PACKAGE" }
}
