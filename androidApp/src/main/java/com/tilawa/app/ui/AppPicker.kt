package com.tilawa.app.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tilawa.app.MainViewModel

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun AppPickerSheet(vm: MainViewModel, dismiss: () -> Unit) {
    var query by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { if (vm.installedApps.isEmpty()) vm.refreshApps() }
    val apps = remember(vm.installedApps, query) {
        vm.installedApps.filter { it.label.contains(query.trim(), ignoreCase = true) }
    }
    ModalBottomSheet(
        onDismissRequest = dismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = T.Surface,
        contentColor = T.Ink,
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Apps to pause", color = T.Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Text("${vm.guardedPackages.size} selected", color = T.Muted, fontSize = 13.sp)
                }
                PlainButton("Done", onClick = dismiss)
            }
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                leadingIcon = { Icon(Icons.Default.Search, null) },
                placeholder = { Text("Search apps") },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = T.Track,
                    unfocusedContainerColor = T.Track,
                    focusedBorderColor = T.Accent,
                    unfocusedBorderColor = T.Track,
                    cursorColor = T.Accent,
                ),
                modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth(),
            )
            LazyColumn(Modifier.fillMaxWidth().heightIn(max = 560.dp).padding(horizontal = 12.dp, vertical = 12.dp)) {
                items(apps, key = { it.packageName }) { app ->
                    val checked = app.packageName in vm.guardedPackages
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                            .clickable(role = Role.Checkbox) { vm.toggleGuard(app.packageName, !checked) }
                            .padding(horizontal = 8.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LauncherIcon(app.packageName, app.label)
                        Text(app.label, color = T.Ink, fontSize = 16.sp, modifier = Modifier.padding(start = 14.dp).weight(1f))
                        Checkbox(
                            checked = checked,
                            onCheckedChange = null,
                            colors = CheckboxDefaults.colors(checkedColor = T.Accent, uncheckedColor = T.Outline),
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun LauncherIcon(packageName: String, label: String, size: Int = 40) {
    val context = LocalContext.current
    val bitmap = remember(packageName) {
        runCatching {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: 96
            val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: 96
            Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also { out ->
                drawable.setBounds(0, 0, w, h)
                drawable.draw(Canvas(out))
            }.asImageBitmap()
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(bitmap, contentDescription = null, modifier = Modifier.size(size.dp).clip(RoundedCornerShape(10.dp)))
    } else {
        Box(Modifier.size(size.dp).clip(RoundedCornerShape(10.dp)).background(T.AccentTint), contentAlignment = Alignment.Center) {
            Text(label.take(1).uppercase(), color = T.Accent)
        }
    }
}
