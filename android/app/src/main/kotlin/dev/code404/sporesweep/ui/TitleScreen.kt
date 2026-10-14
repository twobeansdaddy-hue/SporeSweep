package dev.code404.sporesweep.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.tr

/** 타이틀 화면. 앱을 켜면 처음 보이고, "시작"을 누르면 게임으로 들어간다(iOS 판 TitleView). */
@Composable
fun TitleScreen(onStart: () -> Unit) {
    val float = rememberInfiniteTransition(label = "float")
    val t by float.animateFloat(0f, 1f, infiniteRepeatable(tween(1600), RepeatMode.Reverse), label = "t")
    Box(Modifier.fillMaxSize()) {
        AssetImage("title_art", Modifier.fillMaxSize())
        Column(Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            AssetImage(
                "logo",
                Modifier.padding(top = 28.dp).offset(y = (5 - 10 * t).dp).widthIn(max = 330.dp),
                scale = ContentScale.Fit,
            )
            Spacer(Modifier.weight(1f))
            ChunkyButton(tr("시작"), Modifier.scale(0.98f + 0.06f * t).padding(bottom = 44.dp), tint = GameTint.PINK, size = 26f, onClick = onStart)
        }
    }
}
