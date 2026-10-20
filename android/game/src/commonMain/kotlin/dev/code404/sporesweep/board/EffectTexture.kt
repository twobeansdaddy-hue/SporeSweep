package dev.code404.sporesweep.board

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.LinearGradientShader
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.RadialGradientShader
import dev.code404.sporesweep.stage.Bitmaps
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** 효과에 쓰는 빛 그림. 코드로 한 번 그려 두고 색만 입혀 쓴다(iOS 판 EffectTexture). */
object EffectTexture {
    private fun white(alpha: Float) = Color(1f, 1f, 1f, alpha)

    private fun radial(canvas: Canvas, size: Int, stops: List<Pair<Float, Float>>) {
        val paint = Paint().apply {
            isAntiAlias = true
            shader = RadialGradientShader(
                Offset(size / 2f, size / 2f), size / 2f,
                stops.map { white(it.second) }, stops.map { it.first },
            )
        }
        canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), paint)
    }

    /** 가운데가 밝고 가장자리로 갈수록 흐려지는 둥근 빛. */
    val glow: ImageBitmap by lazy {
        Bitmaps.draw(128, 128) { radial(it, 128, listOf(0f to 1f, 0.25f to 0.75f, 0.6f to 0.22f, 1f to 0f)) }
    }

    /** 가운데 줄이 밝고 위아래로 흐려지는 띠. 가로로 늘여 빛줄기로 쓴다. */
    val beam: ImageBitmap by lazy {
        Bitmaps.draw(8, 64) { canvas ->
            val paint = Paint().apply {
                shader = LinearGradientShader(
                    Offset(0f, 0f), Offset(0f, 64f),
                    listOf(0f, 0.35f, 1f, 1f, 0.35f, 0f).map { white(it) },
                    listOf(0f, 0.25f, 0.44f, 0.56f, 0.75f, 1f),
                )
            }
            canvas.drawRect(0f, 0f, 8f, 64f, paint)
        }
    }

    /** 네 갈래로 뻗는 반짝임. */
    val sparkle: ImageBitmap by lazy {
        Bitmaps.draw(128, 128) { canvas ->
            radial(canvas, 128, listOf(0f to 0.9f, 0.3f to 0.25f, 0.6f to 0f))
            val center = 64f
            val long = 64f
            val short = 128 * 0.045f
            val path = Path()
            for (index in 0 until 8) {
                val angle = index * PI / 4
                val radius = if (index % 2 == 0) long else short
                val x = (center + cos(angle) * radius).toFloat()
                val y = (center + sin(angle) * radius).toFloat()
                if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close()
            canvas.drawPath(path, Paint().apply { isAntiAlias = true; color = white(1f) })
        }
    }
}
