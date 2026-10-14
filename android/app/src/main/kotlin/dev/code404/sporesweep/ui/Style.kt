package dev.code404.sporesweep.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.code404.sporesweep.Assets
import androidx.compose.foundation.text.BasicText

// iOS 판 GameStyle.swift의 게임풍 모양을 옮긴 것이다.

/** 앱 전체에서 쓰는 색. */
object Palette {
    val background = Color(0.09f, 0.11f, 0.14f)
    val panel = Color(0.17f, 0.19f, 0.31f)
    val backdrop = Brush.verticalGradient(listOf(Color(0.08f, 0.10f, 0.20f), Color(0.17f, 0.10f, 0.27f)))
    val star = Color(0.98f, 0.80f, 0.25f)
    val material = Color(1.0f, 0.22f, 0.58f)
}

/** 버튼의 색. 윗면의 위아래 색과, 아래로 비어져 나온 두께의 색이다. */
enum class GameTint(val top: Color, val bottom: Color, val lip: Color) {
    PINK(Color(1.00f, 0.42f, 0.70f), Color(0.96f, 0.20f, 0.55f), Color(0.66f, 0.08f, 0.36f)),
    BLUE(Color(0.36f, 0.66f, 1.00f), Color(0.20f, 0.48f, 0.94f), Color(0.10f, 0.28f, 0.66f)),
    SLATE(Color(0.42f, 0.47f, 0.62f), Color(0.30f, 0.34f, 0.48f), Color(0.17f, 0.20f, 0.31f)),
    GOLD(Color(1.00f, 0.84f, 0.30f), Color(0.98f, 0.66f, 0.14f), Color(0.72f, 0.42f, 0.05f)),
    GREEN(Color(0.42f, 0.86f, 0.48f), Color(0.20f, 0.70f, 0.36f), Color(0.10f, 0.44f, 0.22f));

    val text get() = if (this == GOLD) Color(0.36f, 0.20f, 0.02f) else Color.White
}

/** 게임 글꼴(주아)로 쓴 글자. iOS 판처럼 같은 크기의 시스템 글꼴보다 조금 키운다. */
@Composable
fun GameText(
    text: String,
    size: Float,
    modifier: Modifier = Modifier,
    color: Color = Color.White,
    align: TextAlign = TextAlign.Center,
    lineHeight: TextUnit = TextUnit.Unspecified,
) {
    BasicText(
        text = text,
        modifier = modifier,
        style = TextStyle(fontFamily = Assets.gameFont, fontSize = (size * 1.08f).sp, color = color, textAlign = align, lineHeight = lineHeight),
    )
}

/** 두께가 있는 통통한 판. 버튼과 칸의 바탕으로 쓴다. */
fun Modifier.chunky(tint: GameTint, radius: Dp = 14.dp, depth: Dp = 4.dp, pressed: Boolean = false): Modifier = drawBehind {
    val r = CornerRadius(radius.toPx())
    val d = depth.toPx()
    drawRoundRect(tint.lip, topLeft = Offset(0f, d), size = size, cornerRadius = r)
    val top = if (pressed) d - 1 else 0f
    drawRoundRect(Brush.verticalGradient(listOf(tint.top, tint.bottom), startY = top, endY = top + size.height), topLeft = Offset(0f, top), size = size, cornerRadius = r)
    drawRoundRect(
        Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.35f), Color.Transparent), startY = top, endY = top + size.height / 2),
        topLeft = Offset(1.5f, top + 1.5f), size = Size(size.width - 3f, size.height - 3f), cornerRadius = r, style = Stroke(1.5.dp.toPx()),
    )
}

/** 통통한 버튼. 누르면 내려앉는다. */
@Composable
fun ChunkyButton(
    label: String,
    modifier: Modifier = Modifier,
    tint: GameTint = GameTint.PINK,
    size: Float = 17f,
    fills: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shown = if (enabled) tint else GameTint.SLATE
    val sink by animateFloatAsState(if (pressed) 3f else 0f, tween(80), label = "sink")
    Box(
        modifier
            .padding(bottom = 4.dp)
            .then(if (fills) Modifier.fillMaxWidth() else Modifier)
            .chunky(shown, radius = (size * 0.8f).dp, pressed = pressed)
            .selectable(selected = false, enabled = enabled, role = Role.Button, interactionSource = interaction, indication = null) { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        GameText(
            label, size, color = shown.text.copy(alpha = if (enabled) 1f else 0.45f),
            modifier = Modifier.offset(y = sink.dp).padding(horizontal = size.dp, vertical = (size * 0.62f).dp),
        )
    }
}

/** 둥근 판. 내용을 담는다. */
fun Modifier.gamePanel(radius: Dp = 18.dp): Modifier =
    clip(RoundedCornerShape(radius)).background(Palette.panel).border(1.5.dp, Color.White.copy(alpha = 0.10f), RoundedCornerShape(radius))

/** 화면 전체의 바탕. */
@Composable
fun GameBackground(content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.fillMaxSize().background(Palette.backdrop), content = content)
}

/** 앱에 든 그림을 채워서 그린다. 그림이 없으면 아무것도 그리지 않는다. */
@Composable
fun AssetImage(name: String, modifier: Modifier = Modifier, scale: ContentScale = ContentScale.Crop) {
    val bitmap = remember(name) { Assets.image(name) } ?: return
    Image(bitmap, contentDescription = null, modifier = modifier, contentScale = scale)
}
