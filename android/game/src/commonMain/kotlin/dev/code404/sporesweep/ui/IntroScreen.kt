package dev.code404.sporesweep.ui

import dev.code404.sporesweep.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.Assets
import dev.code404.sporesweep.GameTrack
import dev.code404.sporesweep.Music
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.tr
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.sin

private class IntroScene(val image: String, val caption: String, val sound: GameSound, val rains: Boolean = false, val pan: Pair<Float, Float> = 0f to 0f, val zoom: Pair<Float, Float> = 1f to 1.1f)

private val scenes = listOf(
    IntroScene("intro_1", "푸르고 평화롭던 지구.", GameSound.INTRO_EARTH, pan = -0.25f to 0.25f, zoom = 1.08f to 1f),
    IntroScene("intro_2", "어느 날, 장난꾸러기 외계인들이 나타나 끈적한 오염 물질을 마구 뿌렸어요!", GameSound.INTRO_INVASION, rains = true),
    IntroScene("intro_3", "오염 물질은 온 세상으로 번졌고, 나라마다 아끼던 랜드마크가 망가져 버렸어요.", GameSound.INTRO_RUIN, rains = true, pan = -1f to 1f, zoom = 1f to 1f),
    IntroScene("intro_4", "하지만 걱정 마세요. 정화 대원이 출동했으니까요!", GameSound.INTRO_HERO, zoom = 1f to 1.08f),
    IntroScene("intro_5", "첫 번째 목적지는 서울, 숭례문! 오염 물질을 격리 컨테이너로 내려보내고 도시를 되살려 주세요.", GameSound.INTRO_ARRIVAL, pan = -1f to -0.45f, zoom = 1f to 1f),
)

private const val SCENE_SECONDS = 6

/** 인트로. 이야기를 그림 다섯 장으로 보여준다(iOS 판 IntroView). 누르면 다음 장, 언제든 건너뛸 수 있다. */
@Composable
fun IntroScreen(onFinish: () -> Unit) {
    var index by remember { mutableIntStateOf(0) }
    val isLast = index == scenes.size - 1
    fun advance(silently: Boolean = false) {
        if (isLast) return
        if (!silently) Sound.play(GameSound.TAP)
        index += 1
    }
    LaunchedEffect(Unit) { Music.play(GameTrack.INTRO) }
    LaunchedEffect(index) {
        Sound.play(scenes[index].sound)
        if (!isLast) {
            delay(SCENE_SECONDS * 1000L)
            advance(silently = true)
        }
    }
    BackHandler { onFinish() }
    Box(Modifier.fillMaxSize().background(Color.Black).clickable(remember { MutableInteractionSource() }, null) { advance() }) {
        AnimatedContent(index, transitionSpec = { fadeIn(tween(600)) togetherWith fadeOut(tween(600)) }, label = "scene") { i ->
            Box(Modifier.fillMaxSize()) {
                IntroPicture(scenes[i])
                if (scenes[i].rains) SporeRain()
            }
        }
        Column(Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 18.dp).padding(top = 8.dp, bottom = 14.dp)) {
            Row(Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                if (!isLast) ChunkyButton(tr("건너뛰기"), tint = GameTint.SLATE, size = 14f) { Sound.play(GameSound.TAP); onFinish() }
            }
            Spacer(Modifier.weight(1f))
            Column(Modifier.fillMaxWidth().gamePanel(22.dp).padding(18.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                AnimatedContent(index, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "caption") { i -> GameText(tr(scenes[i].caption), 20f, Modifier.fillMaxWidth()) }
                if (isLast) {
                    ChunkyButton(tr("출동!"), tint = GameTint.PINK, size = 20f) { Sound.play(GameSound.TAP); onFinish() }
                } else {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (dot in scenes.indices) Box(Modifier.size(8.dp).background(if (dot == index) Palette.material else Color.White.copy(alpha = 0.3f), CircleShape))
                    }
                }
            }
        }
    }
}

/** 인트로의 그림 한 장. 화면 높이에 맞춰 그리고, 보는 동안 천천히 훑거나 커진다. */
@Composable
private fun IntroPicture(scene: IntroScene) {
    val motion = remember { Animatable(0f) }
    LaunchedEffect(Unit) { motion.animateTo(1f, tween((SCENE_SECONDS + 1) * 1000, easing = FastOutSlowInEasing)) }
    BoxWithConstraints(Modifier.fillMaxSize().clipToBounds()) {
        val width = maxOf(maxHeight * 2 / 3, maxWidth)
        val overflow = (width - maxWidth) / 2
        val t = motion.value
        val position = scene.pan.first + (scene.pan.second - scene.pan.first) * t
        val zoom = scene.zoom.first + (scene.zoom.second - scene.zoom.first) * t
        val height = maxHeight
        Box(Modifier.fillMaxSize().scale(zoom), contentAlignment = Alignment.Center) {
            AssetImage(scene.image, Modifier.requiredSize(width, height).offset(x = -overflow * position))
        }
    }
}

/** 화면 위에서 아래로 떨어지는 포자. */
@Composable
private fun SporeRain() {
    val drops = listOf(
        floatArrayOf(0.08f, 34f, 0.11f, 0.10f, 0f), floatArrayOf(0.22f, 22f, 0.16f, 0.55f, 3f), floatArrayOf(0.35f, 44f, 0.09f, 0.80f, 1f),
        floatArrayOf(0.47f, 18f, 0.19f, 0.30f, 0f), floatArrayOf(0.58f, 30f, 0.13f, 0.65f, 2f), floatArrayOf(0.70f, 24f, 0.17f, 0.05f, 3f),
        floatArrayOf(0.82f, 40f, 0.10f, 0.45f, 0f), floatArrayOf(0.93f, 20f, 0.15f, 0.90f, 4f), floatArrayOf(0.15f, 16f, 0.21f, 0.70f, 0f),
        floatArrayOf(0.64f, 14f, 0.23f, 0.20f, 0f), floatArrayOf(0.40f, 26f, 0.14f, 0.95f, 3f), floatArrayOf(0.88f, 16f, 0.20f, 0.60f, 0f),
    )
    val images = (0..4).associateWith { Assets.image("landmark_spore_$it") }
    val clock = rememberInfiniteTransition(label = "rain")
    val time by clock.animateFloat(0f, 1000f, infiniteRepeatable(tween(1_000_000, easing = LinearEasing)), label = "time")
    Canvas(Modifier.fillMaxSize()) {
        for (d in drops) {
            val image = images[d[4].toInt()] ?: continue
            val size = d[1].dp.toPx()
            val travel = (time * d[2] + d[3]) % 1f
            val y = travel * (this.size.height * 0.8f + size * 2) - size
            val x = d[0] * this.size.width + sin(time * 1.3f + d[3] * 9) * 8.dp.toPx()
            translate(x, y) {
                rotate(sin(time + d[3] * 5) * 12, Offset.Zero) {
                    drawImage(image, srcOffset = IntOffset.Zero, srcSize = IntSize(image.width, image.height), dstOffset = IntOffset((-size / 2).toInt(), (-size / 2).toInt()), dstSize = IntSize(size.toInt(), size.toInt()), alpha = 0.95f)
                }
            }
        }
    }
}

/** 엔딩 화면. 깨끗해진 지구 앞에서 정화 대원이 손을 흔드는 그림 위에 그동안의 기록을 보여준다(iOS 판 EndingView). */
@Composable
fun EndingScreen(model: dev.code404.sporesweep.AppModel, onClose: () -> Unit) {
    var step by remember { mutableIntStateOf(0) }
    val zoom = remember { Animatable(1f) }
    LaunchedEffect(Unit) {
        Music.play(GameTrack.INTRO)
        kotlinx.coroutines.coroutineScope {
            launch { zoom.animateTo(1.08f, tween(12_000)) }
            delay(800)
            Sound.play(GameSound.WIN)
            Sound.haptic(dev.code404.sporesweep.board.GameHaptic.SUCCESS)
            step = 1
            delay(1600)
            step = 2
            delay(1800)
            step = 3
        }
    }
    BackHandler { if (step >= 3) onClose() }
    Box(Modifier.fillMaxSize().background(Color.Black).clipToBounds()) {
        AssetImage("ending", Modifier.fillMaxSize().scale(zoom.value))
        Column(Modifier.fillMaxSize().safeDrawingPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            androidx.compose.animation.AnimatedVisibility(step >= 1, enter = fadeIn() + androidx.compose.animation.scaleIn(initialScale = 0.4f)) {
                GameText(tr("지구 정화 완료!"), 34f, Modifier.padding(top = 40.dp).gamePanel(24.dp).padding(horizontal = 22.dp, vertical = 10.dp), color = Palette.star)
            }
            Spacer(Modifier.weight(1f))
            Column(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 30.dp).alpha(if (step >= 2) 1f else 0f).gamePanel(22.dp).padding(18.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (step >= 2) GameText(tr("외계인들은 꼬리를 내리고 돌아갔어요.\n온 세상의 랜드마크가 다시 빛나요.\n고마워요, 정화 대원!"), 17f)
                if (step >= 3) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val stars = model.totalStars
                        for ((title, value) in listOf(
                            tr("도시") to tr("%lld곳", model.cities.size),
                            tr("모은 별") to "${stars.first}/${stars.second}",
                            tr("복원한 랜드마크") to "${model.restoredLandmarks}/${model.cities.size}",
                        )) {
                            Column(
                                Modifier.weight(1f).background(Color.Black.copy(alpha = 0.28f), androidx.compose.foundation.shape.RoundedCornerShape(10.dp)).padding(vertical = 8.dp),
                                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp),
                            ) {
                                GameText(value, 17f, color = Palette.star)
                                GameText(title, 11f, color = Color.White.copy(alpha = 0.75f))
                            }
                        }
                    }
                    if (model.restoredLandmarks < model.cities.size) {
                        GameText(tr("아직 복원하지 못한 랜드마크가 있어요. 별을 더 모아 마저 되살려 보세요!"), 13f, color = Color.White.copy(alpha = 0.75f))
                    }
                    ChunkyButton(tr("계속하기"), tint = GameTint.PINK, size = 19f) { Sound.play(GameSound.TAP); onClose() }
                }
            }
        }
    }
}
