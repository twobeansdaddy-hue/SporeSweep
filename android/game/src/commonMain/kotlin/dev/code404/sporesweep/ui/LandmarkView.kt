package dev.code404.sporesweep.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.Assets
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * 랜드마크 그림 한 벌(iOS 판 LandmarkArt). 부위의 영역은 iOS 코드를 실행해 뽑은 `assets/landmarks.json`에서 읽는다
 * (`Tools/landmark_export.sh`). 영역의 좌표는 그림의 가로와 세로를 0..1로 본 비율이다.
 */
class LandmarkArt(val prefix: String, val horizon: Float, val parts: List<Part>, val spores: List<Spore>) {
    class Part(val id: String, val region: Path, val hole: Path?)
    class Spore(val x: Float, val y: Float, val radius: Float, val degrees: Float, val part: String, val shape: Int)

    val partIDs: Set<String> get() = parts.map { it.id }.toSet() + ENVIRONMENT

    companion object {
        val ENVIRONMENT = listOf("pollution", "sky", "ground", "greenery")

        private val all: Map<String, LandmarkArt> by lazy {
            val root = Json.parseToJsonElement(Assets.text("landmarks.json")).jsonObject
            root.mapValues { (_, value) ->
                val o = value.jsonObject
                LandmarkArt(
                    prefix = o["prefix"]!!.jsonPrimitive.content,
                    horizon = o["horizon"]!!.jsonPrimitive.double.toFloat(),
                    parts = o["parts"]!!.jsonArray.map { e ->
                        val p = e.jsonObject
                        Part(p["id"]!!.jsonPrimitive.content, path(p["region"]!!.jsonArray), p["hole"]?.jsonArray?.let(::path))
                    },
                    spores = o["spores"]!!.jsonArray.map { e ->
                        val s = e.jsonObject
                        Spore(
                            s["x"]!!.jsonPrimitive.double.toFloat(), s["y"]!!.jsonPrimitive.double.toFloat(),
                            s["radius"]!!.jsonPrimitive.double.toFloat(), s["degrees"]!!.jsonPrimitive.double.toFloat(),
                            s["part"]!!.jsonPrimitive.content, s["shape"]!!.jsonPrimitive.int,
                        )
                    },
                )
            }
        }

        fun of(cityID: String): LandmarkArt? = all[cityID]

        private fun path(commands: JsonArray): Path {
            val path = Path()
            for (c in commands) {
                val v = c.jsonArray.map { it.jsonPrimitive.double.toFloat() }
                when (v[0].toInt()) {
                    0 -> path.moveTo(v[1], v[2])
                    1 -> path.lineTo(v[1], v[2])
                    2 -> path.cubicTo(v[1], v[2], v[3], v[4], v[5], v[6])
                    3 -> path.quadraticTo(v[1], v[2], v[3], v[4])
                    4 -> path.close()
                }
            }
            return path
        }
    }
}

/** 채도를 `saturation`로 바꾸고 색마다 `scale`배 한 뒤 `offset`(0..255)을 더하는 거르개(안드로이드 ColorMatrix.setSaturation과 같은 계수). */
private fun saturationFilter(saturation: Float, scale: FloatArray = floatArrayOf(1f, 1f, 1f), offset: Float = 0f): ColorFilter {
    val inverse = 1 - saturation
    val r = 0.213f * inverse
    val g = 0.715f * inverse
    val b = 0.072f * inverse
    val rows = arrayOf(floatArrayOf(r + saturation, g, b), floatArrayOf(r, g + saturation, b), floatArrayOf(r, g, b + saturation))
    val values = FloatArray(20)
    for (i in 0 until 3) {
        for (j in 0 until 3) values[i * 5 + j] = rows[i][j] * scale[i]
        values[i * 5 + 4] = offset
    }
    values[18] = 1f
    return ColorFilter.colorMatrix(ColorMatrix(values))
}

private val filterSkyPolluted: ColorFilter by lazy { saturationFilter(0.15f, offset = 30f) }

private val filterSoil: ColorFilter by lazy { saturationFilter(0f, floatArrayOf(0.95f, 0.76f, 0.56f)) }

/** 도시의 랜드마크. 복원한 부위만 온전한 모습으로 그린다(iOS 판 LandmarkView). */
@Composable
fun LandmarkView(restored: Set<String>, art: LandmarkArt, modifier: Modifier = Modifier) {
    val images = listOf("bg_restored", "bg_ruined", "building_restored", "building_ruined", "trees_restored", "trees_ruined")
        .associateWith { Assets.image("${art.prefix}_$it") }
    BoxWithConstraints(modifier) {
        Canvas(Modifier.fillMaxSize()) {
            drawLandmark(art, restored, images)
        }
        art.spores.forEachIndexed { index, spore ->
            SporeView(spore, index, spore.part in restored, maxWidth.value, maxHeight.value)
        }
        if (art.partIDs.all { it in restored }) Sparkles(maxWidth.value, maxHeight.value)
    }
}

private fun DrawScope.drawLandmark(art: LandmarkArt, restored: Set<String>, images: Map<String, ImageBitmap?>) {
    fun has(id: String) = id in restored
    val width = size.width
    val height = size.height
    val scale = Matrix().apply { scale(width, height) }
    fun paint(name: String, clip: Path, hole: Path? = null, filter: ColorFilter? = null) {
        val bitmap = images[name] ?: return
        var region = Path().apply { addPath(clip) }.also { it.transform(scale) }
        if (hole != null) {
            val cut = Path().apply { addPath(hole) }.also { it.transform(scale) }
            region = Path().apply { op(region, cut, PathOperation.Difference) }
        }
        clipPath(region) {
            drawImage(
                bitmap, IntOffset.Zero, IntSize(bitmap.width, bitmap.height),
                IntOffset.Zero, IntSize(width.toInt(), height.toInt()), colorFilter = filter,
            )
        }
    }
    fun band(top: Float, bottom: Float) = Path().apply { addRect(Rect(0f, top, 1f, bottom)) }

    val sky = band(0f, art.horizon)
    when {
        has("sky") -> paint("bg_restored", sky)
        has("pollution") -> paint("bg_ruined", sky, filter = filterSkyPolluted)
        else -> paint("bg_ruined", sky)
    }
    val ground = band(art.horizon, 1f)
    when {
        has("greenery") -> paint("bg_restored", ground)
        has("ground") -> paint("bg_restored", ground, filter = filterSoil)
        else -> paint("bg_ruined", ground)
    }
    val everything = band(0f, 1f)
    if (has("greenery")) paint("trees_restored", everything) else if (!has("ground")) paint("trees_ruined", everything)
    for (part in art.parts) paint(if (has(part.id)) "building_restored" else "building_ruined", part.region, part.hole)
}

/** 그림 위에 붙은 포자 하나. 딸린 부위가 복원되면 부풀며 터지고 분홍 방울이 튄다. */
@Composable
private fun SporeView(spore: LandmarkArt.Spore, index: Int, popped: Boolean, width: Float, height: Float) {
    val progress = remember { Animatable(if (popped) 1f else 0f) }
    LaunchedEffect(popped) {
        val target = if (popped) 1f else 0f
        if (progress.value != target) {
            kotlinx.coroutines.delay(((index % 4) * 500 * 0.36).toLong())
            progress.animateTo(target, tween(500))
        }
    }
    val p = progress.value
    if (p >= 1f) return
    val side = spore.radius * 2.4f * width
    val image = Assets.image("landmark_spore_${spore.shape}")
    Box(Modifier.offset((spore.x * width - side / 2).dp, (spore.y * height - side / 2).dp).size(side.dp)) {
        if (image != null) {
            Image(
                image, null,
                Modifier.fillMaxSize().rotate(spore.degrees).scale(1 + 0.45f * p).alpha(1 - p),
                contentScale = ContentScale.Fit,
            )
        }
        if (p > 0f) {
            val droplets = sin(p * PI).toFloat()
            Canvas(Modifier.fillMaxSize().alpha(droplets)) {
                val s = size.minDimension
                for (i in 0 until 7) {
                    val angle = i / 7.0 * 2 * PI + 0.4
                    val distance = s * (0.25f + 0.75f * p)
                    drawCircle(
                        Palette.material, radius = s * 0.08f * (1 - 0.6f * p),
                        center = androidx.compose.ui.geometry.Offset(size.width / 2 + (cos(angle) * distance).toFloat(), size.height / 2 + (sin(angle) * distance).toFloat()),
                    )
                }
            }
        }
    }
}

/** 다 복원한 랜드마크 위에서 차례로 반짝이는 별빛. */
@Composable
private fun Sparkles(width: Float, height: Float) {
    val spots = listOf(
        floatArrayOf(0.36f, 0.20f, 0.050f, 0.0f), floatArrayOf(0.63f, 0.14f, 0.060f, 0.9f), floatArrayOf(0.50f, 0.06f, 0.045f, 1.7f),
        floatArrayOf(0.30f, 0.48f, 0.040f, 2.4f), floatArrayOf(0.70f, 0.42f, 0.050f, 0.5f), floatArrayOf(0.44f, 0.34f, 0.035f, 3.1f),
        floatArrayOf(0.58f, 0.58f, 0.040f, 1.3f), floatArrayOf(0.22f, 0.30f, 0.030f, 2.0f), floatArrayOf(0.79f, 0.26f, 0.035f, 2.8f),
    )
    val clock = rememberInfiniteTransition(label = "sparkle")
    val time by clock.animateFloat(0f, 3f, infiniteRepeatable(tween(3000, easing = LinearEasing), RepeatMode.Restart), label = "time")
    for (spot in spots) {
        val beat = ((time / 3 + spot[3] / 3.6f) % 1f)
        val glow = maxOf(0f, 1 - abs(beat - 0.15f) / 0.15f)
        val side = spot[2] * width
        Icon(
            Icons.Filled.AutoAwesome, null, tint = Color.White,
            modifier = Modifier.offset((spot[0] * width - side / 2).dp, (spot[1] * height - side / 2).dp).size(side.dp)
                .scale(0.3f + glow * 0.9f).rotate(glow * 45).alpha(glow),
        )
    }
}

