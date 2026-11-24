package com.tilawa.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import com.tilawa.app.R

/** Calm & modern palette (Tilawa redesign, Nov 2026). Same tokens as iOS DesignTokens. */
object T {
    val Mist = Color(0xFFF5F6F2)
    val Surface = Color(0xFFFFFFFF)
    val SurfaceMuted = Color(0xFFF2F4F3)
    val Track = Color(0xFFE6EAE8)
    val Hairline = Color(0xFFEEF1EF)
    val Outline = Color(0xFFD5DDDB)

    val Ink = Color(0xFF17262A)
    val InkSoft = Color(0xFF24363A)
    val Muted = Color(0xFF56656A)
    val MutedStrong = Color(0xFF3E4D51)

    val Accent = Color(0xFF1D6B62)
    val AccentTint = Color(0xFFE2EEEA)
    val OnAccentTint = Color(0xFF24413D)

    val Streak = Color(0xFF9A5B13)
    val StreakTint = Color(0xFFF6EBDD)
    val Danger = Color(0xFFB4432A)

    /** Warm reading paper for the pause screens: one quiet surface, nothing else. */
    val Paper = Color(0xFFFAF7F0)
    val PaperLine = Color(0xFFEAE4D6)

    val Heat = listOf(Color(0xFFE6EAE8), Color(0xFFA8CFC7), Color(0xFF5E9F95), Color(0xFF1D6B62))
}

val ArabicFont = FontFamily(Font(R.font.amiri_regular))
/** Large, open Arabic for the reading surface. */
val ReadingArabicFont = FontFamily(Font(R.font.lateef_regular))
val SerifFont = FontFamily(Font(R.font.cormorant_garamond_regular))
val SerifItalicFont = FontFamily(Font(R.font.cormorant_garamond_italic))

private val colors = lightColorScheme(
    primary = T.Accent,
    onPrimary = Color.White,
    primaryContainer = T.AccentTint,
    background = T.Mist,
    onBackground = T.Ink,
    surface = T.Surface,
    onSurface = T.Ink,
    surfaceVariant = T.SurfaceMuted,
    onSurfaceVariant = T.Muted,
    outline = T.Outline,
)

@Composable
fun TilawaTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = colors, content = content)
}
