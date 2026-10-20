package dev.code404.sporesweep.stage

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.PaintingStyle
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

// SpriteKit을 흉내 낸 작은 그리기 엔진. iOS 판의 BoardScene을 줄 단위로 옮기기 위해 만들었다.
// Compose의 그리기 도구만 써서 안드로이드와 웹에서 같이 돈다.
//
// - 좌표는 SpriteKit처럼 y가 위쪽이다. 단위는 dp다(iOS의 point와 같은 크기).
// - 노드는 위치, 크기 배율, 회전, 투명도, z를 갖고, 자식의 값은 부모에 쌓인다.
// - 동작(Action)은 SpriteKit의 SKAction과 같은 이름과 뜻을 갖는다. 시간이 흐르면 노드의 값을 바꾼다.
// - 그리는 순서는 조상의 z를 모두 더한 값이고, 같으면 트리 순서다.

/** 색. 0..1 범위의 RGBA다. */
data class SColor(val r: Float, val g: Float, val b: Float, val a: Float = 1f) {
    constructor(white: Float, alpha: Float = 1f) : this(white, white, white, alpha)

    fun withAlpha(alpha: Float) = copy(a = alpha)

    val color: Color
        get() = Color(r.coerceIn(0f, 1f), g.coerceIn(0f, 1f), b.coerceIn(0f, 1f), a.coerceIn(0f, 1f))

    companion object {
        val white = SColor(1f, 1f, 1f)
        val clear = SColor(0f, 0f, 0f, 0f)
    }
}

data class SPoint(val x: Float, val y: Float) {
    companion object {
        val zero = SPoint(0f, 0f)
    }
}

data class SSize(val width: Float, val height: Float)

/** y가 위쪽인 사각형. `y`가 아래 변이다. */
data class SRect(val x: Float, val y: Float, val width: Float, val height: Float) {
    val minX get() = x
    val minY get() = y
    val maxX get() = x + width
    val maxY get() = y + height
    val midX get() = x + width / 2
    val midY get() = y + height / 2
    val size get() = SSize(width, height)
    fun insetBy(dx: Float, dy: Float) = SRect(x + dx, y + dy, width - 2 * dx, height - 2 * dy)
    fun contains(p: SPoint) = p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY
}

enum class Timing { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT;

    fun apply(t: Float): Float = when (this) {
        LINEAR -> t
        EASE_IN -> t * t
        EASE_OUT -> 1 - (1 - t) * (1 - t)
        EASE_IN_OUT -> t * t * (3 - 2 * t)
    }
}

/** 노드가 그릴 곳. 좌표는 이미 노드 자신의 것으로 옮겨 두었다. */
class StageCanvas internal constructor(val canvas: Canvas, val scope: DrawScope)

// MARK: - 노드

open class Node {
    var name: String? = null
    var x = 0f
    var y = 0f
    var z = 0f
    var alpha = 1f
    var xScale = 1f
    var yScale = 1f
    /** 라디안. 반시계 방향이 양수다(SpriteKit의 zRotation). */
    var rotation = 0f
    var isHidden = false
    var parent: Node? = null
        private set
    val children = ArrayList<Node>()
    internal val running = ArrayList<Running>()

    var position: SPoint
        get() = SPoint(x, y)
        set(value) {
            x = value.x
            y = value.y
        }

    fun setScale(scale: Float) {
        xScale = scale
        yScale = scale
    }

    fun addChild(node: Node) {
        node.removeFromParent()
        node.parent = this
        children.add(node)
    }

    fun removeFromParent() {
        parent?.children?.remove(this)
        parent = null
    }

    fun removeAllChildren() {
        for (child in children.toList()) child.removeFromParent()
    }

    /** 이름이 같은 첫 자식. SpriteKit처럼 바로 아래 자식만 본다. */
    fun childNamed(name: String): Node? = children.firstOrNull { it.name == name }

    fun run(action: Action, key: String? = null, completion: (() -> Unit)? = null) {
        if (key != null) removeAction(key)
        running.add(Running(action.start(this), key, completion))
    }

    fun removeAction(key: String) {
        running.removeAll { it.key == key }
    }

    fun hasAction(key: String) = running.any { it.key == key }

    fun removeAllActions() = running.clear()

    /** 이 노드의 내용(자식 빼고)을 그린다. 좌표는 노드 자신의 것이다. */
    open fun draw(target: StageCanvas, alpha: Float) {}

    /** 내용의 폭. SpriteKit의 `frame.width`에 해당한다(배율을 곱한다). */
    open val contentWidth: Float get() = 0f
}

internal class Running(val instance: ActionInstance, val key: String?, val completion: (() -> Unit)?)

/** 그림 한 장 또는 색칠한 네모. 가운데가 위치다. */
class SpriteNode(var image: ImageBitmap?, var width: Float, var height: Float) : Node() {
    constructor(color: SColor, width: Float, height: Float) : this(null, width, height) {
        this.color = color
        colorBlendFactor = 1f
    }

    var color: SColor = SColor.white
    /** 그림을 `color`로 물들이는 정도(0..1). */
    var colorBlendFactor = 0f
    /** 더하기로 그린다(SpriteKit의 `.add`). */
    var additive = false

    private val paint = Paint().apply {
        isAntiAlias = true
        filterQuality = FilterQuality.Medium
    }

    override fun draw(target: StageCanvas, alpha: Float) {
        val canvas = target.canvas
        paint.blendMode = if (additive) BlendMode.Plus else BlendMode.SrcOver
        val bitmap = image
        if (bitmap == null) {
            paint.colorFilter = null
            paint.alpha = 1f
            paint.color = color.withAlpha(color.a * alpha).color
            canvas.drawRect(-width / 2, -height / 2, width / 2, height / 2, paint)
            return
        }
        paint.color = Color.Black
        paint.alpha = alpha.coerceIn(0f, 1f)
        paint.colorFilter = if (colorBlendFactor > 0f) tint(color, colorBlendFactor) else null
        canvas.save()
        // 그림은 y가 아래쪽이므로 뒤집는다. 그림의 화소를 그대로 놓고 배율로 크기를 맞춘다.
        // 화소 단위로 놓아야 정수로 반올림되는 자리가 작아진다.
        canvas.scale(width / bitmap.width, -height / bitmap.height)
        canvas.translate(-bitmap.width / 2f, -bitmap.height / 2f)
        canvas.drawImageRect(bitmap, IntOffset.Zero, IntSize(bitmap.width, bitmap.height), IntOffset.Zero, IntSize(bitmap.width, bitmap.height), paint)
        canvas.restore()
    }

    override val contentWidth get() = width * xScale

    companion object {
        private val tints = HashMap<Pair<SColor, Float>, ColorFilter>()

        fun tint(color: SColor, factor: Float) = tints.getOrPut(color to factor) {
            val keep = 1 - factor
            ColorFilter.colorMatrix(
                ColorMatrix(
                    floatArrayOf(
                        keep, 0f, 0f, 0f, color.r * 255 * factor,
                        0f, keep, 0f, 0f, color.g * 255 * factor,
                        0f, 0f, keep, 0f, color.b * 255 * factor,
                        0f, 0f, 0f, 1f, 0f,
                    ),
                ),
            )
        }
    }
}

enum class HAlign { LEFT, CENTER, RIGHT }

/** 글자. 세로는 가운데 맞춤이다. */
class LabelNode(var text: String = "", var fontSize: Float = 17f, var fontColor: SColor = SColor(0.95f)) : Node() {
    var align = HAlign.CENTER

    private fun layout() = measurer?.measure(
        text,
        TextStyle(fontFamily = fontFamily, fontSize = fontSize.sp),
        softWrap = false,
        // 무대의 좌표가 이미 dp라서 글자 크기를 그대로 쓴다.
        density = Density(1f, 1f),
    )

    override fun draw(target: StageCanvas, alpha: Float) {
        if (text.isEmpty()) return
        val result = layout() ?: return
        val left = when (align) {
            HAlign.LEFT -> 0f
            HAlign.CENTER -> -result.size.width / 2f
            HAlign.RIGHT -> -result.size.width.toFloat()
        }
        target.canvas.save()
        target.canvas.scale(1f, -1f)
        target.scope.drawText(result, fontColor.withAlpha(fontColor.a * alpha).color, Offset(left, -result.size.height / 2f))
        target.canvas.restore()
    }

    override val contentWidth: Float
        get() = (layout()?.size?.width?.toFloat() ?: (text.length * fontSize * 0.6f)) * xScale

    companion object {
        /** 게임 글꼴. 앱이 시작할 때 정한다. */
        var fontFamily: FontFamily = FontFamily.Default
        /** 글자를 재고 놓는 도구. 무대를 띄우는 화면이 정한다. */
        var measurer: TextMeasurer? = null
    }
}

/** 도형. 경로는 y가 위쪽인 노드 좌표로 적는다. SpriteKit처럼 처음에는 채우지 않고 흰 선 1로 그린다. */
class ShapeNode(var path: Path = Path()) : Node() {
    var fillColor: SColor = SColor.clear
    var strokeColor: SColor = SColor.white
    var lineWidth = 1f
    var roundCaps = false
    var additive = false

    private val paint = Paint().apply { isAntiAlias = true }

    override fun draw(target: StageCanvas, alpha: Float) {
        val canvas = target.canvas
        paint.blendMode = if (additive) BlendMode.Plus else BlendMode.SrcOver
        if (fillColor.a > 0f) {
            paint.style = PaintingStyle.Fill
            paint.color = fillColor.withAlpha(fillColor.a * alpha).color
            canvas.drawPath(path, paint)
        }
        if (strokeColor.a > 0f && lineWidth > 0f) {
            paint.style = PaintingStyle.Stroke
            paint.strokeWidth = lineWidth
            paint.strokeCap = if (roundCaps) StrokeCap.Round else StrokeCap.Butt
            paint.strokeJoin = if (roundCaps) StrokeJoin.Round else StrokeJoin.Miter
            paint.color = strokeColor.withAlpha(strokeColor.a * alpha).color
            canvas.drawPath(path, paint)
        }
    }

    override val contentWidth: Float
        get() = path.getBounds().width * xScale

    companion object {
        fun rect(rect: SRect, cornerRadius: Float = 0f) = ShapeNode(Paths.rect(rect, cornerRadius))
        fun circle(radius: Float) = ShapeNode(Paths.ellipse(radius * 2, radius * 2))
        fun ellipse(width: Float, height: Float) = ShapeNode(Paths.ellipse(width, height))
    }
}

/** 경로를 만드는 도구. */
object Paths {
    fun rect(rect: SRect, cornerRadius: Float = 0f) = roundedRect(rect, cornerRadius, cornerRadius)

    fun roundedRect(rect: SRect, cornerWidth: Float, cornerHeight: Float) = Path().apply {
        addRoundRect(RoundRect(rect.minX, rect.minY, rect.maxX, rect.maxY, CornerRadius(cornerWidth, cornerHeight)))
    }

    fun ellipse(width: Float, height: Float) = Path().apply {
        addOval(Rect(-width / 2, -height / 2, width / 2, height / 2))
    }

    fun polyline(points: List<SPoint>, close: Boolean = false) = Path().apply {
        points.forEachIndexed { index, p -> if (index == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y) }
        if (close) close()
    }

    fun star(points: Int, outer: Float, inner: Float) = polyline(
        (0 until points * 2).map { index ->
            val radius = if (index % 2 == 0) outer else inner
            val angle = PI / 2 + index * PI / points
            SPoint((cos(angle) * radius).toFloat(), (sin(angle) * radius).toFloat())
        },
        close = true,
    )
}

/** 자식을 정해진 네모 안으로 잘라 그린다(SpriteKit의 SKCropNode). 네모는 이 노드의 좌표다. */
class CropNode : Node() {
    var mask: SRect? = null
}

// MARK: - 동작

/** 시간이 흐르며 노드를 바꾸는 일. SKAction과 같다. 같은 동작을 여러 노드에 줄 수 있다. */
abstract class Action {
    open var duration: Double = 0.0
    open var timing: Timing = Timing.LINEAR

    internal abstract fun start(node: Node): ActionInstance

    companion object {
        fun moveTo(point: SPoint, duration: Double) = Tween(duration) { node ->
            val sx = node.x
            val sy = node.y
            { t -> node.x = sx + (point.x - sx) * t; node.y = sy + (point.y - sy) * t }
        }

        fun moveBy(dx: Float, dy: Float, duration: Double) = Tween(duration) { node ->
            var lastX = 0f
            var lastY = 0f
            { t ->
                val nx = dx * t
                val ny = dy * t
                node.x += nx - lastX
                node.y += ny - lastY
                lastX = nx
                lastY = ny
            }
        }

        fun scaleTo(scale: Float, duration: Double) = Tween(duration) { node ->
            val sx = node.xScale
            val sy = node.yScale
            { t -> node.xScale = sx + (scale - sx) * t; node.yScale = sy + (scale - sy) * t }
        }

        fun scaleXTo(scale: Float, duration: Double) = Tween(duration) { node ->
            val sx = node.xScale
            { t -> node.xScale = sx + (scale - sx) * t }
        }

        fun scaleYTo(scale: Float, duration: Double) = Tween(duration) { node ->
            val sy = node.yScale
            { t -> node.yScale = sy + (scale - sy) * t }
        }

        fun fadeAlpha(to: Float, duration: Double) = Tween(duration) { node ->
            val start = node.alpha
            { t -> node.alpha = start + (to - start) * t }
        }

        fun fadeIn(duration: Double) = fadeAlpha(1f, duration)
        fun fadeOut(duration: Double) = fadeAlpha(0f, duration)

        fun rotateTo(angle: Float, duration: Double) = Tween(duration) { node ->
            val start = node.rotation
            { t -> node.rotation = start + (angle - start) * t }
        }

        fun rotateBy(angle: Float, duration: Double) = Tween(duration) { node ->
            var last = 0f
            { t ->
                val now = angle * t
                node.rotation += now - last
                last = now
            }
        }

        fun wait(duration: Double) = Tween(duration) { { _: Float -> } }

        fun run(block: () -> Unit) = Instant { block() }

        fun removeFromParent() = Instant { it.removeFromParent() }

        fun sequence(vararg actions: Action) = Sequence(actions.toList())
        fun sequence(actions: List<Action>) = Sequence(actions)
        fun group(vararg actions: Action) = Group(actions.toList())
        fun group(actions: List<Action>) = Group(actions)
        fun repeatForever(action: Action) = RepeatForever(action)
    }
}

internal interface ActionInstance {
    val done: Boolean

    /** 시간을 `dt`초만큼 보낸다. 끝났으면 쓰고 남은 시간을 돌려준다. */
    fun step(dt: Double): Double
}

/** 시간에 따라 값을 바꾸는 동작. `setup`은 시작할 때의 값을 기억하고, 진행 정도(0..1)를 받아 값을 정하는 함수를 돌려준다. */
class Tween(override var duration: Double, private val setup: (Node) -> (Float) -> Unit) : Action() {
    override fun start(node: Node): ActionInstance = object : ActionInstance {
        var apply: ((Float) -> Unit)? = null
        var elapsed = 0.0
        override var done = false

        override fun step(dt: Double): Double {
            val f = apply ?: setup(node).also { apply = it }
            elapsed += dt
            if (duration <= 0 || elapsed >= duration) {
                f(1f)
                done = true
                return if (duration <= 0) dt else elapsed - duration
            }
            f(timing.apply((elapsed / duration).toFloat()))
            return 0.0
        }
    }
}

/** 바로 일어나는 일. */
class Instant(private val block: (Node) -> Unit) : Action() {
    override fun start(node: Node): ActionInstance = object : ActionInstance {
        override var done = false
        override fun step(dt: Double): Double {
            if (!done) {
                done = true
                block(node)
            }
            return dt
        }
    }
}

class Sequence(private val actions: List<Action>) : Action() {
    override var duration: Double
        get() = actions.sumOf { it.duration }
        set(_) {}

    override var timing: Timing
        get() = Timing.LINEAR
        set(value) = actions.forEach { it.timing = value }

    override fun start(node: Node): ActionInstance = object : ActionInstance {
        var index = 0
        var current: ActionInstance? = null
        override val done get() = index >= actions.size

        override fun step(dt: Double): Double {
            var left = dt
            while (index < actions.size) {
                val instance = current ?: actions[index].start(node).also { current = it }
                left = instance.step(left)
                if (!instance.done) return 0.0
                index += 1
                current = null
            }
            return left
        }
    }
}

class Group(private val actions: List<Action>) : Action() {
    override var duration: Double
        get() = actions.maxOfOrNull { it.duration } ?: 0.0
        set(_) {}

    /** 묶음에 준 시간 곡선은 안의 동작에 그대로 준다. */
    override var timing: Timing
        get() = Timing.LINEAR
        set(value) = actions.forEach { it.timing = value }

    override fun start(node: Node): ActionInstance = object : ActionInstance {
        val instances = actions.map { it.start(node) }
        val leftovers = DoubleArray(instances.size) { -1.0 }
        override val done get() = instances.all { it.done }

        override fun step(dt: Double): Double {
            instances.forEachIndexed { i, instance ->
                if (!instance.done) leftovers[i] = instance.step(dt)
                else if (leftovers[i] < 0) leftovers[i] = dt
                else leftovers[i] = dt
            }
            return if (done) leftovers.minOrNull() ?: dt else 0.0
        }
    }
}

class RepeatForever(private val action: Action) : Action() {
    override fun start(node: Node): ActionInstance = object : ActionInstance {
        var current = action.start(node)
        override val done = false

        override fun step(dt: Double): Double {
            var left = dt
            var guard = 0
            while (left >= 0) {
                left = current.step(left)
                if (!current.done) break
                current = action.start(node)
                // 시간이 0인 동작이 끝없이 돌지 않게 한다.
                if (++guard > 8) break
                if (left <= 0) break
            }
            return 0.0
        }
    }
}

// MARK: - 무대

/** 2차원 변환. 점 (x, y)를 (a·x + c·y + tx, b·x + d·y + ty)로 옮긴다. */
internal class Affine(val a: Float, val b: Float, val c: Float, val d: Float, val tx: Float, val ty: Float) {
    /** 이 변환 안에서 먼저 옮긴다(안드로이드 Matrix의 preTranslate). */
    fun translated(x: Float, y: Float) = Affine(a, b, c, d, a * x + c * y + tx, b * x + d * y + ty)

    fun rotated(radians: Float): Affine {
        val cs = cos(radians)
        val sn = sin(radians)
        return Affine(a * cs + c * sn, b * cs + d * sn, -a * sn + c * cs, -b * sn + d * cs, tx, ty)
    }

    fun scaled(sx: Float, sy: Float) = Affine(a * sx, b * sx, c * sy, d * sy, tx, ty)

    fun map(x: Float, y: Float) = Offset(a * x + c * y + tx, b * x + d * y + ty)

    /** 네모를 옮긴 뒤 그것을 감싸는 네모. */
    fun mapRect(left: Float, top: Float, right: Float, bottom: Float): Rect {
        val corners = listOf(map(left, top), map(right, top), map(left, bottom), map(right, bottom))
        return Rect(corners.minOf { it.x }, corners.minOf { it.y }, corners.maxOf { it.x }, corners.maxOf { it.y })
    }

    fun toMatrix() = Matrix().apply {
        values[Matrix.ScaleX] = a
        values[Matrix.SkewY] = b
        values[Matrix.SkewX] = c
        values[Matrix.ScaleY] = d
        values[Matrix.TranslateX] = tx
        values[Matrix.TranslateY] = ty
    }

    companion object {
        val identity = Affine(1f, 0f, 0f, 1f, 0f, 0f)
    }
}

/**
 * 노드 나무 하나와 그것을 돌리는 시계. 화면은 매 프레임 `update`와 `draw`를 부른다.
 * 크기의 단위는 dp다.
 */
open class Stage {
    val root = Node()
    var width = 0f
        private set
    var height = 0f
        private set
    /** 동작의 빠르기. 1이 보통이다(SpriteKit의 `speed`). */
    var speed = 1.0

    /** 크기가 바뀌었을 때. 처음에도 한 번 불린다. */
    open fun didChangeSize() {}

    fun resize(width: Float, height: Float) {
        if (width == this.width && height == this.height) return
        this.width = width
        this.height = height
        didChangeSize()
    }

    /** 나무에 붙은 노드의 동작을 `dt`초만큼 돌린다. */
    fun update(dt: Double) {
        val time = dt * speed
        val nodes = ArrayList<Node>()
        collect(root, nodes)
        for (node in nodes) {
            if (node.running.isEmpty() || !isAttached(node)) continue
            for (run in node.running.toList()) {
                if (run !in node.running) continue
                run.instance.step(time)
                if (run.instance.done) {
                    node.running.remove(run)
                    run.completion?.invoke()
                }
            }
        }
    }

    private fun collect(node: Node, out: MutableList<Node>) {
        out.add(node)
        for (child in node.children.toList()) collect(child, out)
    }

    private fun isAttached(node: Node): Boolean {
        var current: Node? = node
        while (current != null) {
            if (current === root) return true
            current = current.parent
        }
        return false
    }

    private class Item(val node: Node, val matrix: Affine, val alpha: Float, val z: Float, val order: Int, val clips: List<Rect>)

    /** 화면에 그린다. `density`는 dp당 화소 수다. */
    fun draw(scope: DrawScope, density: Float) {
        val items = ArrayList<Item>()
        var order = 0
        fun visit(node: Node, parent: Affine, alpha: Float, z: Float, clips: List<Rect>) {
            if (node.isHidden || alpha <= 0.001f && node.children.isEmpty()) return
            var m = parent.translated(node.x, node.y)
            if (node.rotation != 0f) m = m.rotated(node.rotation)
            if (node.xScale != 1f || node.yScale != 1f) m = m.scaled(node.xScale, node.yScale)
            val a = alpha * node.alpha
            val gz = z + node.z
            items.add(Item(node, m, a, gz, order++, clips))
            var childClips = clips
            if (node is CropNode) {
                node.mask?.let { mask -> childClips = clips + m.mapRect(mask.minX, mask.minY, mask.maxX, mask.maxY) }
            }
            for (child in node.children.toList()) visit(child, m, a, gz, childClips)
        }
        // y가 위쪽인 dp 좌표를 화면의 화소 좌표로 바꾼다.
        val base = Affine(density, 0f, 0f, -density, 0f, height * density).toMatrix()
        visit(root, Affine.identity, 1f, 0f, emptyList())
        items.sortWith(compareBy<Item> { it.z }.thenBy { it.order })
        val canvas = scope.drawContext.canvas
        val target = StageCanvas(canvas, scope)
        for (item in items) {
            if (item.alpha <= 0.001f) continue
            canvas.save()
            canvas.concat(base)
            for (clip in item.clips) canvas.clipRect(clip.left, clip.top, clip.right, clip.bottom, ClipOp.Intersect)
            canvas.concat(item.matrix.toMatrix())
            item.node.draw(target, item.alpha)
            canvas.restore()
        }
    }

    /** 손가락이 닿았을 때, 움직일 때, 뗐을 때. 좌표는 무대의 것이다. */
    open fun touchDown(point: SPoint) {}
    open fun touchMove(point: SPoint) {}
    open fun touchUp() {}

    /** 화면의 화소 좌표를 무대의 좌표로 바꾼다. */
    fun toStage(px: Float, py: Float, density: Float) = SPoint(px / density, height - py / density)
}

/** 화면 밖에서 그린 그림. */
object Bitmaps {
    /** 코드로 그림을 그린다. */
    fun draw(width: Int, height: Int, block: (Canvas) -> Unit): ImageBitmap {
        val bitmap = ImageBitmap(width, height)
        block(Canvas(bitmap))
        return bitmap
    }
}

@Suppress("unused")
private fun clamp(value: Float, low: Float, high: Float) = max(low, min(high, value))
