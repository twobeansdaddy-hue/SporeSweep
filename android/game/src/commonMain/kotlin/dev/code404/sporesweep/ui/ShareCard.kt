package dev.code404.sporesweep.ui

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.sp
import dev.code404.sporesweep.Assets
import dev.code404.sporesweep.tr

/**
 * 랜드마크를 다 복원하면 자랑할 수 있는 그림(iOS 판 ShareCard). 오염된 모습과 되살린 모습을 위아래로 놓는다.
 * 인스타그램 스토리 크기(1080×1920)로 그린다.
 */
object ShareCard {
    const val WIDTH = 1080
    const val HEIGHT = 1920
    private const val PANEL_W = 960f
    private const val PANEL_H = 640f

    fun render(art: LandmarkArt, landmarkName: String, measurer: TextMeasurer): ImageBitmap {
        val bitmap = ImageBitmap(WIDTH, HEIGHT)
        val density = Density(1f)
        CanvasDrawScope().draw(density, LayoutDirection.Ltr, Canvas(bitmap), Size(WIDTH.toFloat(), HEIGHT.toFloat())) {
            drawRect(Brush.verticalGradient(listOf(Color(0xFF120F59), Color(0xFF52149E))))
            // 글이 maxHeight보다 크면 글자를 줄인다(iOS 판의 minimumScaleFactor).
            fun text(value: String, size: Float, color: Color, x: Float, y: Float, width: Float, align: TextAlign = TextAlign.Center, maxHeight: Float = Float.MAX_VALUE) {
                var fontSize = size
                while (true) {
                    val layout = measurer.measure(
                        value,
                        TextStyle(fontFamily = Assets.gameFont, fontSize = fontSize.sp, color = color, textAlign = align),
                        constraints = Constraints(maxWidth = width.toInt()),
                        density = density,
                    )
                    if (layout.size.height <= maxHeight || fontSize <= size / 2) {
                        drawText(layout, topLeft = Offset(x, y + (if (maxHeight == Float.MAX_VALUE) 0f else (maxHeight - layout.size.height) / 2)))
                        return
                    }
                    fontSize -= 4f
                }
            }
            text(tr("%@ 복원 완료!", landmarkName), 84f, Palette.star, 60f, 100f, WIDTH - 120f, maxHeight = 150f)
            val left = (WIDTH - PANEL_W) / 2
            panel(art, emptySet(), left, 280f)
            text(tr("포자가 뒤덮은 모습"), 38f, Color.White, left + 50f, 316f, PANEL_W, TextAlign.Start)
            panel(art, art.partIDs, left, 960f)
            text(tr("내가 되살린 모습"), 38f, Color.White, left + 50f, 996f, PANEL_W, TextAlign.Start)

            Assets.image("share_icon")?.let { icon ->
                val box = RoundRect(190f, 1640f, 340f, 1790f, CornerRadius(34f))
                clipPath(Path().apply { addRoundRect(box) }) {
                    drawImage(icon, IntOffset.Zero, IntSize(icon.width, icon.height), IntOffset(190, 1640), IntSize(150, 150))
                }
            }
            text(tr("포자 대청소"), 64f, Color.White, 370f, 1640f, 680f, TextAlign.Start)
            text(tr("블록을 맞춰 세계의 랜드마크를 되살려요"), 32f, Color.White.copy(alpha = 0.75f), 370f, 1730f, 680f, TextAlign.Start)
        }
        return bitmap
    }

    /** 랜드마크 그림 한 칸. 위에 이름표를 얹을 자리를 어둡게 깐다. */
    private fun DrawScope.panel(art: LandmarkArt, restored: Set<String>, x: Float, y: Float) {
        val shape = Path().apply { addRoundRect(RoundRect(x, y, x + PANEL_W, y + PANEL_H, CornerRadius(44f))) }
        clipPath(shape) {
            translate(x, y) {
                val images = listOf("bg_restored", "bg_ruined", "building_restored", "building_ruined", "trees_restored", "trees_ruined")
                    .associateWith { Assets.image("${art.prefix}_$it") }
                clipPath(Path().apply { addRect(androidx.compose.ui.geometry.Rect(0f, 0f, PANEL_W, PANEL_H)) }) {
                    drawLandmarkIn(art, restored, images)
                }
                // 복원하지 않은 부위의 포자는 붙어 있다.
                for (spore in art.spores) {
                    if (spore.part in restored) continue
                    val image = Assets.image("landmark_spore_${spore.shape}") ?: continue
                    val side = spore.radius * 2.4f * PANEL_W
                    val center = Offset(spore.x * PANEL_W, spore.y * PANEL_H)
                    rotate(spore.degrees, center) {
                        drawImage(
                            image, IntOffset.Zero, IntSize(image.width, image.height),
                            IntOffset((center.x - side / 2).toInt(), (center.y - side / 2).toInt()), IntSize(side.toInt(), side.toInt()),
                        )
                    }
                }
            }
            // 이름표 바탕.
            drawRoundRect(Color.Black.copy(alpha = 0.75f), Offset(x + 24f, y + 24f), Size(420f, 76f), CornerRadius(38f))
        }
        drawPath(shape, Color.White.copy(alpha = 0.25f), style = Stroke(6f))
    }

    /** 칸 크기(PANEL_W×PANEL_H)에 맞춰 랜드마크를 그린다. */
    private fun DrawScope.drawLandmarkIn(art: LandmarkArt, restored: Set<String>, images: Map<String, ImageBitmap?>) {
        val scope = this
        CanvasDrawScope().draw(scope.drawContext.density, scope.layoutDirection, scope.drawContext.canvas, Size(PANEL_W, PANEL_H)) {
            drawLandmark(art, restored, images)
        }
    }
}
