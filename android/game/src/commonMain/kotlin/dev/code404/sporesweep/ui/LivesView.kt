package dev.code404.sporesweep.ui

import dev.code404.sporesweep.Platform
import dev.code404.sporesweep.AdService
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.Tracker
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.core.Lives
import dev.code404.sporesweep.tr
import kotlinx.coroutines.delay
import kotlin.time.Instant
import kotlin.math.ceil

/** 1초마다 바뀌는 지금 시각. 생명이 저절로 차는 것을 보여줄 때 쓴다. */
@Composable
fun rememberClock(): Instant {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            now = System.currentTimeMillis()
        }
    }
    return Instant.fromEpochMilliseconds(now)
}

/** 남은 시간을 `분:초`로 적는다. */
fun clock(seconds: Double): String {
    val total = maxOf(ceil(seconds).toInt(), 0)
    return "%d:%02d".format(total / 60, total % 60)
}

/** 생명력 표시. 하트와 개수, 가득 차지 않았으면 다음 하나까지 남은 시간(iOS 판 LivesBadge). */
@Composable
fun LivesBadge(model: AppModel) {
    model.revision
    val now = rememberClock()
    val count = model.lives(now)
    Row(
        Modifier.background(Color.Black.copy(alpha = 0.3f), RoundedCornerShape(50)).padding(horizontal = 11.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(if (count > 0) Icons.Filled.Favorite else Icons.Filled.HeartBroken, null, tint = GameTint.PINK.top, modifier = Modifier.size(15.dp))
        GameText("$count", 15f)
        model.timeUntilNextLife(now)?.let { GameText(clock(it), 12f, color = Color.White.copy(alpha = 0.65f)) }
    }
}

/** 생명력 창. 모자라면 광고를 보고 하나를 받게 한다(iOS 판 LivesPopup). */
@Composable
fun LivesPopup(model: AppModel, onClose: () -> Unit) {
    model.revision
    var showsAd by remember { mutableStateOf(false) }
    val now = rememberClock()
    val count = model.lives(now)
    val left = model.adLivesLeft(now)
    Box(Modifier.fillMaxSize()) {
        CardOverlay(onDismiss = onClose) {
            GameText(if (count > 0) tr("생명") else tr("생명이 다 떨어졌어요"), 24f, color = Palette.star)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (index in 0 until Lives.MAXIMUM) {
                    Icon(Icons.Filled.Favorite, null, tint = if (index < count) GameTint.PINK.top else Color.White.copy(alpha = 0.18f), modifier = Modifier.size(30.dp))
                }
            }
            val wait = model.timeUntilNextLife(now)
            GameText(if (wait != null) tr("다음 생명까지 %@", clock(wait)) else tr("가득 찼어요"), 15f, color = Color.White.copy(alpha = 0.8f))
            GameText(tr("판에서 지면 하나 줄고, %lld분마다 하나씩 차요.", (Lives.REFILL_INTERVAL / 60).toInt()), 13f, color = Color.White.copy(alpha = 0.6f))
            Column(Modifier.padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (count < Lives.MAXIMUM) {
                    WideButton(GameTint.PINK, enabled = left > 0, onClick = { Sound.play(GameSound.TAP); showsAd = true }) {
                        Icon(Icons.Filled.PlayCircle, null, tint = Color.White, modifier = Modifier.size(18.dp))
                        GameText(if (left > 0) tr("광고 보고 생명 +1") else tr("오늘은 광고로 더 받을 수 없어요"), 17f)
                    }
                }
                ChunkyButton(tr("닫기"), tint = GameTint.SLATE, fills = true) {
                    Sound.play(GameSound.TAP)
                    onClose()
                }
            }
        }
        if (showsAd) {
            RewardedAdView("life", tr("생명 +1")) { watched ->
                showsAd = false
                if (watched && model.grantLifeFromAd()) {
                    Sound.play(GameSound.RESTORE)
                    Sound.haptic(GameHaptic.SUCCESS)
                }
            }
        }
    }
}

/**
 * 보상형 광고(iOS 판 RewardedAdView). 실제 광고는 RewardedAds가 이 화면 위에 띄운다.
 * 이 화면은 그 뒤에 깔리는 검은 바탕이고, 광고를 불러오는 동안과 불러오지 못했을 때의 안내를 보여준다.
 * 디버그 빌드에서는 광고를 불러오지 못하면 3초짜리 자리 표시 광고로 대신하고 보상을 준다.
 */
@Composable
fun RewardedAdView(id: String, reward: String, onFinish: (Boolean) -> Unit) {
    var phase by remember { mutableStateOf("loading") }
    var remaining by remember { mutableIntStateOf(3) }
    LaunchedEffect(Unit) {
        if (Platform.ads.isEnabled && Platform.ads.waitUntilReady(6.0)) {
            phase = "showing"
            dev.code404.sporesweep.Music.pause()
            Platform.ads.show { outcome ->
                dev.code404.sporesweep.Music.resume()
                when (outcome) {
                    AdService.Outcome.REWARDED -> { Tracker.log(Tracker.Event.AdReward(id)); onFinish(true) }
                    AdService.Outcome.SKIPPED -> { Tracker.log(Tracker.Event.AdSkip(id)); onFinish(false) }
                    AdService.Outcome.FAILED -> { Tracker.log(Tracker.Event.AdFail(id)); phase = "failed" }
                }
            }
            return@LaunchedEffect
        }
        // 개발 빌드와 광고가 없는 웹판은 자리 표시 화면을 보여주고 보상을 준다.
        if (Platform.isDebug || Platform.adsArePlaceholders) {
            phase = "placeholder"
            while (remaining > 0) {
                delay(1000)
                remaining -= 1
            }
            Tracker.log(Tracker.Event.AdReward(id))
            onFinish(true)
        } else {
            Tracker.log(Tracker.Event.AdFail(id))
            phase = "failed"
        }
    }
    Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            when (phase) {
                "loading" -> {
                    CircularProgressIndicator(color = Color.White)
                    GameText(tr("광고를 불러오는 중이에요"), 17f)
                }
                "placeholder" -> {
                    Icon(Icons.Filled.PlayCircle, null, tint = Color.White.copy(alpha = 0.5f), modifier = Modifier.size(54.dp))
                    GameText(tr("광고 자리예요"), 24f)
                    GameText(tr("아직 실제 광고는 나오지 않아요.\n%lld초 뒤에 %@을 받아요.", remaining, reward), 15f, color = Color.White.copy(alpha = 0.7f))
                }
                "failed" -> {
                    Icon(Icons.Filled.WifiOff, null, tint = Color.White.copy(alpha = 0.5f), modifier = Modifier.size(44.dp))
                    GameText(tr("광고를 불러오지 못했어요"), 22f)
                    GameText(tr("잠시 뒤에 다시 해 보세요."), 15f, color = Color.White.copy(alpha = 0.7f))
                    ChunkyButton(tr("닫기"), tint = GameTint.SLATE) { Sound.play(GameSound.TAP); onFinish(false) }
                }
                else -> {}
            }
        }
    }
}
