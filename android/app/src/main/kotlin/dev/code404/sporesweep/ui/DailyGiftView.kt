package dev.code404.sporesweep.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.core.Booster
import dev.code404.sporesweep.core.DailyGift
import dev.code404.sporesweep.core.Tool
import dev.code404.sporesweep.tr

/** 일일 보상 창. 이레치 선물을 늘어놓고 오늘 것을 받게 한다(iOS 판 DailyGiftView). */
@Composable
fun DailyGiftView(model: AppModel, onClose: () -> Unit) {
    var claimedDay by remember { mutableStateOf<Int?>(null) }
    val today = claimedDay ?: model.dailyGiftDay
    CardOverlay(maxWidth = 340.dp, onDismiss = onClose) {
        GameText(tr("오늘의 선물"), 24f, color = Palette.star)
        (1..DailyGift.CYCLE).chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (day in row) Tile(day, today, claimedDay != null, Modifier.weight(1f))
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        GameText(tr("매일 들르면 선물이 커져요. 하루를 거르면 처음부터예요."), 12f, color = Color.White.copy(alpha = 0.65f))
        if (claimedDay == null) {
            ChunkyButton(tr("선물 받기"), size = 19f, fills = true) {
                if (model.claimDailyGift() != null) {
                    Sound.play(GameSound.RESTORE)
                    Sound.haptic(GameHaptic.SUCCESS)
                    claimedDay = today
                }
            }
        } else {
            ChunkyButton(tr("내일 또 만나요!"), tint = GameTint.BLUE, fills = true) {
                Sound.play(GameSound.TAP)
                onClose()
            }
        }
    }
}

@Composable
private fun Tile(day: Int, today: Int, claimed: Boolean, modifier: Modifier) {
    val isToday = day == today
    val isPast = day < today || (isToday && claimed)
    Box(modifier.alpha(if (isPast) 0.55f else 1f)) {
        Column(
            Modifier.fillMaxWidth()
                .background(if (isToday) GameTint.PINK.lip.copy(alpha = 0.55f) else Color.Black.copy(alpha = 0.28f), RoundedCornerShape(12.dp))
                .border(2.dp, if (isToday) GameTint.PINK.top else Color.Transparent, RoundedCornerShape(12.dp))
                .padding(vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            GameText(if (isToday) tr("오늘") else tr("%lld일째", day), 11f, color = if (isToday) Palette.star else Color.White.copy(alpha = 0.7f))
            val items = DailyGift.REWARDS[day - 1]
            Row(Modifier.height(30.dp), verticalAlignment = Alignment.CenterVertically) {
                for (item in items) GiftIcon(item, if (items.size > 2) 17f else 28f)
            }
        }
        if (isPast) {
            Icon(Icons.Filled.CheckCircle, null, tint = GameTint.GREEN.top, modifier = Modifier.align(Alignment.TopEnd).offset(4.dp, (-4).dp).size(16.dp))
        }
    }
}

@Composable
private fun GiftIcon(item: String, size: Float) {
    val parts = item.split(":")
    when (parts[0]) {
        "booster" -> Booster.byName(parts[1])?.let { BoosterIcon(it, size) }
        "tool" -> Tool.entries.firstOrNull { it.name.lowercase() == parts[1] }?.let { ToolIcon(it, size) }
        else -> Icon(Icons.Filled.Favorite, tr("생명 가득"), tint = GameTint.PINK.top, modifier = Modifier.size((size * 0.8f).dp))
    }
}
