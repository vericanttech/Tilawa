package com.tilawa.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.withStyle

@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = T.Accent,
            contentColor = Color.White,
            disabledContainerColor = T.Track,
            disabledContentColor = T.Muted,
        ),
        modifier = modifier.fillMaxWidth().height(56.dp),
    ) { Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold) }
}

@Composable
fun SoftButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = T.AccentTint, contentColor = T.OnAccentTint),
        modifier = modifier.height(56.dp),
    ) { Text(text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center) }
}

@Composable
fun PlainButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = modifier) {
        Text(text, color = T.Accent, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** Calm "wait" bar shown before the main button unlocks. */
@Composable
fun WaitBar(text: String, description: String) {
    Box(
        Modifier.fillMaxWidth().height(56.dp).clip(RoundedCornerShape(16.dp)).background(T.AccentTint)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Text(text, color = T.Accent, fontSize = 16.sp, fontWeight = FontWeight.SemiBold) }
}

@Composable
fun Card(
    modifier: Modifier = Modifier,
    padding: Dp = 20.dp,
    radius: Dp = 24.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(radius)).background(T.Surface).padding(padding),
        content = content,
    )
}

@Composable
fun Overline(text: String, color: Color = T.Accent) {
    Text(text.uppercase(), color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
}

@Composable
fun StreakPill(text: String, description: String? = null) {
    Row(
        Modifier.clip(CircleShape).background(T.StreakTint).padding(horizontal = 12.dp, vertical = 6.dp)
            .then(if (description != null) Modifier.semantics(mergeDescendants = true) { contentDescription = description } else Modifier),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.LocalFireDepartment, null, tint = T.Streak, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, color = T.Streak, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun InfoPill(text: String) {
    Text(
        text,
        color = T.OnAccentTint,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.clip(CircleShape).background(T.AccentTint).padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Composable
fun LineProgress(value: Float, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(T.Track)) {
        Box(Modifier.fillMaxHeight().fillMaxWidth(value.coerceIn(0f, 1f)).clip(CircleShape).background(T.Accent))
    }
}

@Composable
fun RingProgress(value: Float, size: Dp = 64.dp) {
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(size)) {
        CircularProgressIndicator(
            progress = { 1f },
            color = T.Track,
            strokeWidth = 6.dp,
            modifier = Modifier.size(size),
        )
        CircularProgressIndicator(
            progress = { value.coerceIn(0f, 1f) },
            color = T.Accent,
            trackColor = Color.Transparent,
            strokeWidth = 6.dp,
            strokeCap = StrokeCap.Round,
            modifier = Modifier.size(size),
        )
        Text("${(value * 100).toInt()}%", color = T.Ink, fontSize = 13.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun StepBars(current: Int, total: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(total) { i ->
            Box(Modifier.width(28.dp).height(4.dp).clip(CircleShape).background(if (i < current) T.Accent else T.Track))
        }
    }
}

@Composable
fun VerseBadge(number: Int) {
    Box(Modifier.size(30.dp).clip(CircleShape).background(T.AccentTint), contentAlignment = Alignment.Center) {
        Text(number.toString(), color = T.Accent, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun CircleIconButton(icon: ImageVector, description: String, background: Color = T.SurfaceMuted, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).clip(CircleShape).background(background)
            .clickable(role = Role.Button, onClickLabel = description, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = T.Ink, modifier = Modifier.size(20.dp)) }
}

/** Pill-style segmented control. */
@Composable
fun <V> Segmented(options: List<Pair<V, String>>, selected: V, onSelect: (V) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(T.Track).padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEach { (value, label) ->
            val on = value == selected
            Box(
                Modifier.weight(1f).height(40.dp).clip(RoundedCornerShape(10.dp))
                    .background(if (on) T.Surface else Color.Transparent)
                    .clickable(role = Role.Tab) { onSelect(value) }
                    .semantics { this.selected = on },
                contentAlignment = Alignment.Center,
            ) {
                Text(label, color = if (on) T.Ink else T.Muted, fontSize = 14.sp, fontWeight = if (on) FontWeight.SemiBold else FontWeight.Normal)
            }
        }
    }
}

@Composable
fun ScreenTitle(title: String, modifier: Modifier = Modifier) {
    Text(title, color = T.Ink, fontSize = 30.sp, fontWeight = FontWeight.Bold, modifier = modifier)
}

@Composable
fun Hairline() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(T.Hairline))
}

@Composable
fun tilawaSwitchColors() = androidx.compose.material3.SwitchDefaults.colors(
    checkedThumbColor = Color.White,
    checkedTrackColor = T.Accent,
    checkedBorderColor = T.Accent,
    uncheckedThumbColor = T.Muted,
    uncheckedTrackColor = T.Track,
    uncheckedBorderColor = T.Outline,
)

private val footnoteMarker = Regex("""\[\d+]""")

/** Translation text with footnote markers like "[2]" kept (the text must not change) but drawn small and raised. */
fun translationText(text: String): androidx.compose.ui.text.AnnotatedString =
    androidx.compose.ui.text.buildAnnotatedString {
        var last = 0
        footnoteMarker.findAll(text).forEach { m ->
            append(text.substring(last, m.range.first))
            withStyle(
                androidx.compose.ui.text.SpanStyle(
                    fontSize = 10.sp,
                    color = T.Accent,
                    baselineShift = androidx.compose.ui.text.style.BaselineShift.Superscript,
                ),
            ) { append(m.value.trim('[', ']')) }
            last = m.range.last + 1
        }
        append(text.substring(last))
    }

/** The translator's footnotes for a verse: collapsed behind a small link so a pause stays short. */
@Composable
fun Footnotes(text: String?) {
    if (text.isNullOrBlank()) return
    val notes = text.lines().filter { it.isNotBlank() }.map { it.trim() }
    var open by androidx.compose.runtime.saveable.rememberSaveable(text) { androidx.compose.runtime.mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            if (open) "Hide translator’s notes" else "Translator’s notes (${notes.size})",
            color = T.Accent,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.clip(RoundedCornerShape(8.dp))
                .clickable(role = Role.Button) { open = !open }
                .padding(vertical = 4.dp),
        )
        if (open) notes.forEach { Text(it, color = T.Muted, fontSize = 12.sp, lineHeight = 17.sp) }
    }
}
