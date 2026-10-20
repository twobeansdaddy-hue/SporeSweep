package dev.code404.sporesweep.board

import androidx.compose.ui.graphics.ImageBitmap
import dev.code404.sporesweep.Assets
import dev.code404.sporesweep.core.Block
import dev.code404.sporesweep.core.BlockKind
import dev.code404.sporesweep.core.Orientation
import dev.code404.sporesweep.stage.LabelNode
import dev.code404.sporesweep.stage.Node
import dev.code404.sporesweep.stage.SColor
import dev.code404.sporesweep.stage.SRect
import dev.code404.sporesweep.stage.ShapeNode
import dev.code404.sporesweep.stage.SpriteNode
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * 블록의 모습(iOS 판 BlockSprite). 모든 블록과 장애물의 그림이 있어서, 그림이 없을 때의 도형은
 * 그림이 없는 큰 물질에만 쓴다.
 */
object BlockSprite {
    fun name(kind: BlockKind) = "block_" + kind.id

    fun texture(name: String): ImageBitmap? = Assets.sprite(name)

    private fun spriteNode(name: String, cellSize: Float): SpriteNode? {
        val texture = texture(name) ?: return null
        return SpriteNode(texture, cellSize, cellSize).also { it.name = name }
    }

    fun color(kind: BlockKind): SColor = when (kind) {
        BlockKind.BRICK -> SColor(0.86f, 0.33f, 0.27f)
        BlockKind.SCRAP -> SColor(0.62f, 0.67f, 0.74f)
        BlockKind.GLASS -> SColor(0.30f, 0.78f, 0.90f)
        BlockKind.WOOD -> SColor(0.93f, 0.69f, 0.29f)
        BlockKind.PLASTIC -> SColor(0.45f, 0.80f, 0.42f)
        BlockKind.SOIL -> SColor(0.67f, 0.48f, 0.86f)
    }

    fun name(block: Block): String = when (block) {
        is Block.Normal -> name(block.kind)
        is Block.Beam -> if (block.orientation == Orientation.HORIZONTAL) "block_beam_h" else "block_beam_v"
        Block.Bomb -> "block_bomb"
        Block.Core -> "block_core"
        Block.Drone -> "block_drone"
        Block.Material -> MATERIAL_NAME
        is Block.Concrete -> "obstacle_concrete_${block.hp}"
        is Block.Caged -> name(block.kind) + "_caged"
        Block.Sludge -> "obstacle_sludge"
        Block.Wall -> "obstacle_wall"
        Block.Rubble -> "obstacle_rubble"
        is Block.Nest -> "obstacle_nest_${minOf(block.hp, 2)}"
        is Block.Timed -> name(block.kind) + "_timed"
        Block.Egg -> "obstacle_egg"
        is Block.Chained -> name(block.kind) + "_chained"
        Block.Boulder -> "obstacle_boulder"
        is Block.Vent -> "obstacle_vent_${minOf(block.hp, 2)}"
        is Block.Frozen -> name(block.trapped) + "_frozen"
        is Block.Cocoon -> "obstacle_cocoon_" + name(block.trapped)
    }

    const val MATERIAL_NAME = "material"
    const val CAGE_NAME = "obstacle_cage"
    const val TIMER_NAME = "timer"
    private const val TIMER_LABEL_NAME = "timerLabel"

    /** 블록 노드를 만든다. */
    fun makeNode(block: Block, cellSize: Float): Node {
        spriteNode(name(block), cellSize)?.let { return it }
        if (block is Block.Cocoon) return makeCocoon(block.trapped, cellSize)
        if (block is Block.Frozen) {
            val base = spriteNode(name(block.trapped), cellSize) ?: SpriteNode(color(block.trapped), cellSize * 0.8f, cellSize * 0.8f)
            base.name = name(block)
            base.addChild(iceOverlay(cellSize))
            return base
        }
        val kind = block.kind
        if (kind != null) {
            val base = spriteNode(name(kind), cellSize) ?: SpriteNode(color(kind), cellSize * 0.8f, cellSize * 0.8f)
            base.name = name(block)
            decorate(base, block, cellSize)
            return base
        }
        if (block == Block.Drone) return makeDrone(cellSize)
        // 여기까지 오는 것은 그림이 빠진 경우뿐이다. 칸 색 네모로 그린다.
        return SpriteNode(SColor(0.5f), cellSize * 0.8f, cellSize * 0.8f).also { it.name = name(block) }
    }

    /** 그림이 없을 때의 청소 드론(iOS 판과 같다). 청록색 원판 위에 대각선으로 놓인 흰 날개 넷. */
    private fun makeDrone(cellSize: Float): Node {
        val radius = cellSize * 0.4f
        val disc = ShapeNode.circle(radius)
        disc.name = name(Block.Drone)
        disc.fillColor = SColor(0.12f, 0.62f, 0.66f)
        disc.strokeColor = SColor(0f, 0f, 0f, 0.35f)
        disc.lineWidth = maxOf(cellSize * 0.04f, 1f)
        val long = radius * 0.78f
        val wide = radius * 0.2f
        for (index in 0 until 4) {
            val angle = index * PI.toFloat() / 2 + PI.toFloat() / 4
            val c = cos(angle)
            val s = sin(angle)
            fun rotate(x: Float, y: Float) = dev.code404.sporesweep.stage.SPoint(x * c - y * s, x * s + y * c)
            val x0 = wide * 0.6f
            val corners = listOf(rotate(x0, -wide / 2), rotate(x0 + long, -wide / 2), rotate(x0 + long, wide / 2), rotate(x0, wide / 2))
            val blade = ShapeNode(dev.code404.sporesweep.stage.Paths.polyline(corners, close = true))
            blade.fillColor = SColor.white
            blade.strokeColor = SColor.clear
            blade.z = 0.1f
            disc.addChild(blade)
        }
        val hub = ShapeNode.circle(radius * 0.22f)
        hub.fillColor = SColor.white
        hub.strokeColor = SColor.clear
        hub.z = 0.1f
        disc.addChild(hub)
        return disc
    }

    private fun decorate(node: Node, block: Block, cellSize: Float) {
        if (block is Block.Caged) node.addChild(cageOverlay(cellSize))
        if (block is Block.Chained) {
            node.addChild(cageOverlay(cellSize))
            spriteNode("obstacle_chain", cellSize)?.let {
                it.name = "chain"
                it.z = 0.25f
                node.addChild(it)
            }
        }
        if (block is Block.Timed) node.addChild(timerOverlay(block.turns, cellSize))
    }

    private fun iceOverlay(cellSize: Float): Node {
        val ice = spriteNode("obstacle_ice", cellSize * 1.04f) ?: SpriteNode(SColor(0.72f, 0.9f, 1f, 0.6f), cellSize * 0.94f, cellSize * 0.94f)
        ice.name = "ice"
        ice.z = 0.3f
        return ice
    }

    /** 포자 보호막. 블록 위에 얹는다. */
    fun makeShield(cellSize: Float): Node {
        val ring = spriteNode("obstacle_shield", cellSize * 1.08f) ?: SpriteNode(SColor(0.3f, 0.95f, 0.9f, 0.2f), cellSize, cellSize)
        val film = ShapeNode.circle(cellSize * 0.4f)
        film.fillColor = SColor(0.4f, 0.95f, 1f, 0.22f)
        film.strokeColor = SColor.clear
        film.z = -0.1f
        ring.addChild(film)
        return ring
    }

    /** 끈끈이 바닥. 블록 아래에 깔린다. */
    fun makeSticky(cellSize: Float): Node {
        val texture = texture("obstacle_sticky")
        val node = if (texture != null) SpriteNode(texture, cellSize * 1.06f, cellSize * 1.06f) else SpriteNode(SColor(0.1f, 0.75f, 0.75f), cellSize * 0.98f, cellSize * 0.98f)
        node.name = "obstacle_sticky"
        return node
    }

    /** 오염 안개. 칸을 다 덮는다. */
    fun makeFog(cellSize: Float): Node {
        val texture = texture("obstacle_fog")
        val node = if (texture != null) SpriteNode(texture, cellSize * 1.08f, cellSize * 1.08f) else SpriteNode(SColor(0.45f, 0.25f, 0.6f), cellSize * 0.98f, cellSize * 0.98f)
        node.name = "obstacle_fog"
        return node
    }

    /** 블록의 오른쪽 아래에 붙는 시한 포자. 남은 턴을 적는다. */
    private fun timerOverlay(turns: Int, cellSize: Float): Node {
        val side = cellSize * 0.62f
        val texture = texture("obstacle_timer")
        val badge: Node = if (texture != null) {
            SpriteNode(texture, side * texture.width / maxOf(texture.height, 1), side)
        } else {
            SpriteNode(SColor(1f, 0.22f, 0.58f), side, side)
        }
        badge.name = TIMER_NAME
        badge.x = cellSize * 0.19f
        badge.y = -cellSize * 0.17f
        badge.z = 0.3f
        val label = LabelNode("", side * 0.44f)
        label.name = TIMER_LABEL_NAME
        label.y = -side * 0.05f
        label.z = 0.1f
        badge.addChild(label)
        setTimer(turns, badge)
        return badge
    }

    /** 시한 포자의 숫자를 바꾼다. 얼마 남지 않으면 빨갛게 적는다. */
    fun setTimer(turns: Int, node: Node) {
        val badge = if (node.name == TIMER_NAME) node else node.childNamed(TIMER_NAME)
        val label = badge?.childNamed(TIMER_LABEL_NAME) as? LabelNode ?: return
        label.text = "$turns"
        label.fontColor = if (turns <= 2) SColor(1f, 0.35f, 0.3f) else SColor.white
    }

    private fun makeCocoon(kind: BlockKind, cellSize: Float): Node {
        val texture = texture("obstacle_cocoon")
        val node: Node = if (texture != null) SpriteNode(texture, cellSize, cellSize) else SpriteNode(SColor(1f, 0.36f, 0.66f), cellSize * 0.94f, cellSize * 0.94f)
        node.name = name(Block.Cocoon(kind))
        val icon = makeNode(Block.Normal(kind), cellSize * 0.46f)
        icon.name = "cocoonKind"
        icon.y = cellSize * 0.02f
        icon.z = 0.1f
        node.addChild(icon)
        return node
    }

    private fun cageOverlay(cellSize: Float): Node {
        val cage = spriteNode(CAGE_NAME, cellSize) ?: SpriteNode(SColor(0.92f, 0.9f), cellSize * 0.9f, cellSize * 0.9f)
        cage.name = "cage"
        // 은청색 고철 위에서 묻히지 않도록 창살을 조금 어둡게 누른다.
        cage.color = SColor(0.16f, 0.18f, 0.28f)
        cage.colorBlendFactor = 0.5f
        cage.z = 0.2f
        return cage
    }

    /** 물질 덩어리 하나를 그린다. 크기에 맞는 그림이 없으면 둥근 네모에 칸마다 핵을 둔다. */
    fun makeMaterialNode(width: Int, height: Int, cellSize: Float): Node {
        if (width * height <= 1) return makeNode(Block.Material, cellSize)
        texture("${MATERIAL_NAME}_${width}x$height")?.let {
            return SpriteNode(it, width * cellSize, height * cellSize).also { node -> node.name = MATERIAL_NAME }
        }
        val w = (width - 0.16f) * cellSize
        val h = (height - 0.16f) * cellSize
        val node = ShapeNode.rect(SRect(-w / 2, -h / 2, w, h), cellSize * 0.3f)
        node.name = MATERIAL_NAME
        node.fillColor = SColor(1f, 0.22f, 0.58f)
        node.strokeColor = SColor(0f, 0.35f)
        node.lineWidth = maxOf(cellSize * 0.04f, 1f)
        val core = cellSize * 0.16f
        for (row in 0 until height) for (column in 0 until width) {
            val nucleus = ShapeNode.circle(core)
            nucleus.fillColor = SColor(0.25f, 0.02f, 0.16f)
            nucleus.strokeColor = SColor.clear
            nucleus.z = 0.1f
            nucleus.x = (column - (width - 1) / 2f) * cellSize
            nucleus.y = ((height - 1) / 2f - row) * cellSize
            node.addChild(nucleus)
        }
        return node
    }
}
