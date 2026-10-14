package com.tilawa.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import com.tilawa.app.R

val Parchment = Color(0xFFF5EDD8)
val ParchmentDark = Color(0xFFEAD9B2)
val Ink = Color(0xFF1E1408)
val InkMid = Color(0xFF4A3520)
val InkLight = Color(0xFF7A5C35)
val ChromeBg = Color(0xFF2A1F0F)
val ChromeCard = Color(0xFF332613)
val ChromeCard2 = Color(0xFF3A2C18)
val ChromeText = Color(0xFFC8A86A)
val ChromeMuted = Color(0xFF9A7A50)
val Gold = Color(0xFFB8860B)
val GoldLight = Color(0xFFD4A843)
val GoldPale = Color(0xFFF0D898)
val Danger = Color(0xFFC96B5C)

val ArabicFont = FontFamily(Font(R.font.lateef_regular))
val DisplayFont = FontFamily(
    Font(R.font.cormorant_garamond_regular),
    Font(R.font.cormorant_garamond_italic, style = FontStyle.Italic),
)

private val colors = darkColorScheme(
    primary = Gold,
    onPrimary = Ink,
    background = ChromeBg,
    onBackground = ChromeText,
    surface = ChromeCard,
    onSurface = ChromeText,
)

@Composable
fun TilawaTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = colors, content = content)
}
