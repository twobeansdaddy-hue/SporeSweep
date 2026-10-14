package dev.code404.sporesweep.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.Assets
import dev.code404.sporesweep.core.Booster
import dev.code404.sporesweep.core.Tool
import dev.code404.sporesweep.tr

/** 둥근 아이콘 버튼. 뒤로 가기, 설정, 설명 보기에 쓴다. */
@Composable
fun IconButton(icon: ImageVector, label: String, tint: GameTint = GameTint.SLATE, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val sink by animateFloatAsState(if (pressed) 3f else 0f, tween(80), label = "sink")
    Box(
        Modifier
            .padding(bottom = 4.dp)
            .chunky(tint, radius = 21.dp, pressed = pressed)
            .selectable(false, interactionSource = interaction, indication = null, role = Role.Button) { onClick() }
            .padding(11.dp),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = tr(label), tint = tint.text, modifier = Modifier.size(20.dp).offset(y = sink.dp))
    }
}

/** 화면 위쪽의 제목 줄. */
@Composable
fun GameHeader(title: String, leading: @Composable () -> Unit = {}, trailing: @Composable () -> Unit = {}) {
    Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 6.dp), contentAlignment = Alignment.Center) {
        GameText(
            title, 19f,
            Modifier
                .background(Palette.panel, RoundedCornerShape(50))
                .border(1.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(50))
                .padding(horizontal = 18.dp, vertical = 7.dp),
        )
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            leading()
            Spacer(Modifier.weight(1f))
            trailing()
        }
    }
}

/** 별 세 개. 받은 만큼 채운다. */
@Composable
fun StarsView(count: Int, size: Float = 12f) {
    Row(horizontalArrangement = Arrangement.spacedBy((size * 0.12f).dp)) {
        for (index in 0 until 3) {
            Icon(
                Icons.Filled.Star, null,
                tint = if (index < count) Palette.star else Color.Black.copy(alpha = 0.35f),
                modifier = Modifier.size((size * 1.15f).dp).offset(y = if (index == 1) (-size * 0.12f).dp else 0.dp),
            )
        }
    }
}

/** 화면을 어둡게 덮고 가운데에 둥근 판을 띄운다. 카드와 창에 쓴다. */
@Composable
fun CardOverlay(dim: Float = 0.65f, maxWidth: Dp = 320.dp, radius: Dp = 24.dp, onDismiss: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = dim))
            .then(if (onDismiss != null) Modifier.clickable(remember { MutableInteractionSource() }, null) { onDismiss() } else Modifier.clickable(remember { MutableInteractionSource() }, null) {}),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier
                .padding(28.dp)
                .widthIn(max = maxWidth)
                .gamePanel(radius)
                .clickable(remember { MutableInteractionSource() }, null) {}
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

/** 보드의 조각 그림(`block_bomb`, `tool_hammer` 등). */
@Composable
fun SpriteImage(name: String, size: Dp, modifier: Modifier = Modifier) {
    val bitmap = remember(name) { Assets.sprite(name) }
    if (bitmap == null) {
        Spacer(modifier.size(size))
        return
    }
    Image(bitmap, null, modifier.size(size), contentScale = ContentScale.Fit)
}

val Tool.title get() = when (this) {
    Tool.HAMMER -> tr("정화 망치")
    Tool.SWAP -> tr("자리 바꾸기")
    Tool.SHUFFLE -> tr("섞기")
}

val Tool.shortTitle get() = when (this) {
    Tool.HAMMER -> tr("망치")
    Tool.SWAP -> tr("바꾸기")
    Tool.SHUFFLE -> tr("섞기")
}

val Tool.spriteName get() = "tool_" + name.lowercase()

val Tool.hint get() = when (this) {
    Tool.HAMMER -> tr("부술 칸을 눌러 주세요")
    Tool.SWAP -> tr("바꿀 블록을 옆으로 밀어 주세요")
    Tool.SHUFFLE -> ""
}

val Booster.title get() = when (this) {
    Booster.BEAM -> tr("제염 빔")
    Booster.BOMB -> tr("중화 폭탄")
    Booster.CORE -> tr("정화 코어")
    Booster.EXTRA_MOVES -> tr("이동 +%lld", Booster.EXTRA_MOVE_COUNT)
}

val Booster.spriteName get() = when (this) {
    Booster.BEAM -> "block_beam_h"
    Booster.BOMB -> "block_bomb"
    Booster.CORE -> "block_core"
    Booster.EXTRA_MOVES -> null
}

/** 부스터의 그림. 이동 추가는 숫자로 그린다. */
@Composable
fun BoosterIcon(booster: Booster, size: Float) {
    val name = booster.spriteName
    if (name != null) {
        SpriteImage(name, size.dp)
    } else {
        Box(Modifier.size(size.dp), contentAlignment = Alignment.Center) {
            Box(
                Modifier.size((size * 0.9f).dp)
                    .background(Brush.verticalGradient(listOf(GameTint.GREEN.top, GameTint.GREEN.bottom)), CircleShape)
                    .border(2.dp, GameTint.GREEN.lip, CircleShape),
                contentAlignment = Alignment.Center,
            ) { GameText("+${Booster.EXTRA_MOVE_COUNT}", size * 0.5f) }
        }
    }
}

/** 아이템의 그림. */
@Composable
fun ToolIcon(tool: Tool, size: Float, modifier: Modifier = Modifier) = SpriteImage(tool.spriteName, size.dp, modifier)

/** 둥근 판 위에 내용을 담은 작은 칸. 별 기준이나 아이템 소개에 쓴다. */
@Composable
fun Chip(modifier: Modifier = Modifier, alpha: Float = 1f, content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier.background(Color.Black.copy(alpha = 0.28f), RoundedCornerShape(10.dp)).padding(vertical = 6.dp),
        contentAlignment = Alignment.Center, content = content,
    )
}
