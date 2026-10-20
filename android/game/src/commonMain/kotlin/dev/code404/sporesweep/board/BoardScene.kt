package dev.code404.sporesweep.board

import dev.code404.sporesweep.core.Block
import dev.code404.sporesweep.core.BlockKind
import dev.code404.sporesweep.core.GameConstants
import dev.code404.sporesweep.core.GameEvent
import dev.code404.sporesweep.core.GameState
import dev.code404.sporesweep.core.GameStatus
import dev.code404.sporesweep.core.Orientation
import dev.code404.sporesweep.core.PendingMaterial
import dev.code404.sporesweep.core.Position
import dev.code404.sporesweep.core.SpecialActivation
import dev.code404.sporesweep.core.SpecialEffect
import dev.code404.sporesweep.core.Swap
import dev.code404.sporesweep.core.SwapRejection
import dev.code404.sporesweep.core.Tool
import dev.code404.sporesweep.core.TurnResult
import dev.code404.sporesweep.stage.Action
import dev.code404.sporesweep.stage.CropNode
import dev.code404.sporesweep.stage.HAlign
import dev.code404.sporesweep.stage.LabelNode
import dev.code404.sporesweep.stage.Node
import dev.code404.sporesweep.stage.Paths
import dev.code404.sporesweep.stage.SColor
import dev.code404.sporesweep.stage.SPoint
import dev.code404.sporesweep.stage.SRect
import dev.code404.sporesweep.stage.ShapeNode
import dev.code404.sporesweep.stage.SpriteNode
import dev.code404.sporesweep.stage.Stage
import dev.code404.sporesweep.stage.Timing
import dev.code404.sporesweep.tr
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * 보드를 그리고 밀기를 받는 씬. iOS 판 BoardScene.swift를 거의 줄 단위로 옮긴 것이다.
 *
 * 규칙은 모두 core가 처리한다. 씬은 스왑을 넘기고, 돌아온 이벤트 목록을 순서대로 재생한다.
 */
class BoardScene(initial: GameState) : Stage() {
    var state: GameState = initial
        private set
    var sceneLayout = SceneLayout(0f, 0f, initial.board.columns, initial.activeRange.let { it.upper - it.lower })
        private set
    var isAnimating = false
        private set
    var isPreviewing = false
        private set
    var isShowingResult = false
        private set
    /** 판이 끝났을 때. */
    var onFinish: ((GameState) -> Unit)? = null
    /** 판이 끝났는데 아직 [onFinish]로 알리지 않았는지. 끝나는 연출이 버려져도 결과를 잃지 않으려고 따로 둔다. */
    var hasPendingResult = false
        private set
    /** 쓰려고 든 아이템. */
    var armedTool: Tool? = null
    var onToolUsed: ((Tool) -> Unit)? = null
    /** 화면을 다시 그려야 할 때. 이동 횟수 같은 바깥 표시를 바꾼다. */
    var onChange: (() -> Unit)? = null
    var starScores: List<Int> = emptyList()
        set(value) {
            field = value
            buildStarBar()
            updateHUD()
        }
    var feedback: Feedback? = null
    var hintDelay = 5.0
    /** 사람 대신 스스로 판을 둔다(개발용). */
    var autoPlays = false

    val layout get() = sceneLayout.board

    private val initialState = initial.copy()
    private val boardNode = Node()
    private val fogNodes = HashMap<Position, Node>()
    private val stickyNodes = HashMap<Position, Node>()
    private val shieldNodes = HashMap<Position, Node>()
    private val cropNode = CropNode()
    private val worldNode = Node()
    private val blocks = HashMap<Position, Node>()
    private var dragStart: Pair<SPoint, Position>? = null

    private var movesLabel = LabelNode()
    private var scoreLabel = LabelNode()
    private var starBarNode = Node()
    private var hudNode = Node()
    private var starFill = ShapeNode()
    private val starMarks = ArrayList<LabelNode>()
    private val starsLit = ArrayList<Boolean>()
    private var materialsLabel = LabelNode()
    private var containerNode = Node()
    private val containerLamps = ArrayList<ShapeNode>()
    private var minimapNode = Node()
    private var minimapViewport = ShapeNode()
    private var collectedShown = 0
    private var displayedScore = 0
    private var scoreSteps = IntArray(0)
    private var finalBonus = 0
    private var movesShown: Int? = null
    private var queueNode = Node()
    private var pendingShown = ArrayList<PendingMaterial>()
    private var hintRunner = Node()

    private object T {
        const val swap = 0.15
        const val clear = 0.18
        const val fallUnit = 0.12
        const val stagger = 0.025
        const val flowStep = 0.1
        const val carryFactor = 0.75
        const val shuffle = 0.35
        const val effect = 0.3
        const val pop = 0.26
        const val beamStep = 0.045
        const val beamHold = 0.12
        const val beamFade = 0.28
        const val bombStep = 0.07
        const val coreStep = 0.035
        const val create = 0.15
        const val slide = 0.14
        const val scrollPerRow = 0.16
        const val collect = 0.35
    }

    private object P {
        val text = SColor(0.95f)
        val panel = SColor(0.17f, 0.19f, 0.31f)
        val material = SColor(1.0f, 0.22f, 0.58f)
        val container = SColor(0.98f, 0.80f, 0.25f)
    }

    init {
        root.addChild(boardNode)
        root.addChild(hintRunner)
    }

    override fun didChangeSize() {
        rebuild()
        scheduleHint()
        autoPlayIfNeeded()
    }

    private val activeRowCount get() = state.activeRange.upper - state.activeRange.lower

    // MARK: - 힌트

    val hintSwap: Swap? get() = if (state.status == GameStatus.PLAYING) state.possibleMoves().firstOrNull() else null

    private fun scheduleHint() {
        hintRunner.removeAction("hint")
        if (hintDelay <= 0) return
        hintRunner.run(Action.sequence(Action.wait(hintDelay), Action.run { showHint() }), "hint")
    }

    private fun cancelHint() {
        hintRunner.removeAction("hint")
        for (node in blocks.values) {
            node.removeAction("hintShake")
            node.rotation = 0f
        }
    }

    private fun showHint() {
        val swap = hintSwap
        if (isAnimating || isPreviewing || isShowingResult || swap == null) return
        val angle = 0.14f
        for (position in listOf(swap.from, swap.to)) {
            val shake = Action.sequence(
                Action.rotateTo(angle, 0.07), Action.rotateTo(-angle, 0.14), Action.rotateTo(angle, 0.14),
                Action.rotateTo(-angle, 0.14), Action.rotateTo(0f, 0.07),
            )
            blocks[position]?.run(shake, "hintShake")
        }
        scheduleHint()
    }

    // MARK: - 그리기

    private fun rebuild() {
        boardNode.removeAllActions()
        boardNode.removeAllChildren()
        cropNode.removeAllChildren()
        worldNode.removeAllActions()
        worldNode.removeAllChildren()
        blocks.clear()
        fogNodes.clear()
        stickyNodes.clear()
        shieldNodes.clear()
        isAnimating = false
        isPreviewing = false
        isShowingResult = false
        dragStart = null
        collectedShown = state.materialsTotal - state.materialsRemaining
        displayedScore = state.score
        scoreSteps = IntArray(0)
        finalBonus = 0
        movesShown = null
        pendingShown = ArrayList(state.pendingMaterials)

        val board = state.board
        sceneLayout = SceneLayout(width, height, board.columns, activeRowCount)
        if (layout.cellSize <= 0) return

        cropNode.mask = layout.frame
        cropNode.addChild(worldNode)
        val bed = layout.frame.insetBy(-5f, -5f)
        val panel = ShapeNode.rect(bed, layout.cellSize * 0.22f)
        panel.fillColor = SColor(0.07f, 0.08f, 0.19f, 0.82f)
        panel.strokeColor = SColor(0.62f, 0.68f, 1f, 0.55f)
        panel.lineWidth = 3f
        panel.z = -2f
        boardNode.addChild(panel)
        val rim = ShapeNode.rect(bed.insetBy(-4f, -4f), layout.cellSize * 0.28f)
        rim.fillColor = SColor.clear
        rim.strokeColor = SColor(0.05f, 0.05f, 0.14f, 0.7f)
        rim.lineWidth = 4f
        rim.z = -3f
        boardNode.addChild(rim)
        boardNode.addChild(cropNode)
        worldNode.position = worldOffset(state.activeTop.toFloat())

        for (position in board.positions) {
            val tile = SpriteNode(SColor(1f, if ((position.column + position.row) % 2 == 0) 0.07f else 0.04f), layout.cellSize, layout.cellSize)
            tile.position = layout.center(position)
            worldNode.addChild(tile)
        }
        for (position in board.positions) {
            val block = board[position]
            if (block != null && block != Block.Material) addBlock(block, position, position)
        }
        for (piece in state.materials) {
            val node = BlockSprite.makeMaterialNode(piece.width, piece.height, layout.cellSize)
            node.z = 1f
            worldNode.addChild(node)
            for (cell in piece.cells) blocks[cell] = node
            node.position = centroid(node)
        }
        for (position in state.sticky) {
            val node = BlockSprite.makeSticky(layout.cellSize)
            node.position = layout.center(position)
            node.z = 0.5f
            worldNode.addChild(node)
            stickyNodes[position] = node
        }
        for (position in state.shields) {
            val node = BlockSprite.makeShield(layout.cellSize)
            node.position = layout.center(position)
            node.z = 5f
            worldNode.addChild(node)
            shieldNodes[position] = node
            node.run(Action.repeatForever(Action.sequence(Action.fadeAlpha(0.7f, 0.9), Action.fadeAlpha(1f, 0.9))))
        }
        for (position in state.fog) addFog(position)

        buildHUD()
        queueNode = Node()
        boardNode.addChild(queueNode)
        updateQueue()
        buildContainer()
        buildMinimap()
        // 이미 알린 결과는 또 알리지 않는다. 끝나는 연출이 버려졌으면 여기서 알린다.
        if (state.status != GameStatus.PLAYING) showResult(notify = hasPendingResult)
    }

    private fun worldOffset(top: Float) = SPoint(0f, top * layout.cellSize)

    private fun addBlock(block: Block, position: Position, start: Position): Node {
        val node = BlockSprite.makeNode(block, layout.cellSize)
        node.position = layout.center(start)
        node.z = 1f
        worldNode.addChild(node)
        blocks[position] = node
        if (block.isSpecial) addShimmer(node, block)
        return node
    }

    private fun addFog(position: Position): Node {
        val node = BlockSprite.makeFog(layout.cellSize)
        node.position = layout.center(position)
        node.z = 6f
        worldNode.addChild(node)
        fogNodes[position] = node
        val beat = 1.4 + ((position.column * 3 + position.row * 5) % 7) * 0.12
        node.run(Action.repeatForever(Action.sequence(Action.scaleTo(1.06f, beat), Action.scaleTo(0.98f, beat))))
        return node
    }

    private fun addShimmer(node: Node, block: Block) {
        val color = when (block) {
            Block.Bomb -> SColor(1f, 0.7f, 0.3f)
            Block.Core -> SColor.white
            else -> SColor(0.5f, 0.9f, 1f)
        }
        val side = layout.cellSize * 1.5f
        val glow = SpriteNode(EffectTexture.glow, side, side)
        glow.color = color
        glow.colorBlendFactor = 1f
        glow.additive = true
        glow.z = -0.1f
        glow.alpha = 0.25f
        node.addChild(glow)
        glow.run(Action.repeatForever(Action.sequence(Action.fadeAlpha(0.7f, 0.8), Action.fadeAlpha(0.25f, 0.8))))
    }

    private fun centroid(node: Node): SPoint {
        val centers = blocks.filter { it.value === node }.map { layout.center(it.key) }
        if (centers.isEmpty()) return node.position
        return SPoint(centers.map { it.x }.average().toFloat(), centers.map { it.y }.average().toFloat())
    }

    private fun makeLabel(size: Float, align: HAlign = HAlign.CENTER): LabelNode {
        val label = LabelNode("", size, P.text)
        label.align = align
        return label
    }

    private fun buildHUD() {
        hudNode.removeFromParent()
        hudNode = Node()
        val frame = sceneLayout.hudFrame
        val pillHeight = minOf(frame.height, 34f)
        val moves = makePill(86f, pillHeight)
        moves.position = SPoint(frame.minX + 43, frame.midY)
        hudNode.addChild(moves)
        val materials = makePill(98f, pillHeight)
        materials.position = SPoint(frame.maxX - 49, frame.midY)
        hudNode.addChild(materials)

        movesLabel = makeLabel(17f)
        movesLabel.position = moves.position
        materialsLabel = makeLabel(17f)
        materialsLabel.position = materials.position
        scoreLabel = makeLabel(18f)
        scoreLabel.position = SPoint(frame.midX, frame.midY)
        for (label in listOf(movesLabel, scoreLabel, materialsLabel)) {
            label.z = 0.2f
            hudNode.addChild(label)
        }
        boardNode.addChild(hudNode)
        buildStarBar()
        updateHUD()
    }

    private fun makePill(width: Float, height: Float): ShapeNode {
        val pill = ShapeNode.rect(SRect(-width / 2, -height / 2, width, height), height / 2)
        pill.fillColor = P.panel
        pill.strokeColor = SColor(1f, 0.14f)
        pill.lineWidth = 1.5f
        return pill
    }

    private fun makeStar(size: Float): Pair<Node, LabelNode> {
        val node = Node()
        val shadow = makeLabel(size)
        shadow.text = "★"
        shadow.fontColor = SColor(0.08f, 0.09f, 0.18f)
        shadow.y = -2f
        val face = makeLabel(size)
        face.text = "★"
        face.z = 0.1f
        node.addChild(shadow)
        node.addChild(face)
        return node to face
    }

    private fun buildStarBar() {
        starBarNode.removeFromParent()
        starBarNode = Node()
        starFill = ShapeNode()
        starMarks.clear()
        starsLit.clear()
        val frame = sceneLayout.hudFrame
        scoreLabel.position = SPoint(frame.midX, frame.midY)
        if (starScores.size != 2 || state.materialsTotal <= 0) return
        val width = STAR_BAR_WIDTH
        val height = STAR_BAR_HEIGHT
        scoreLabel.position = SPoint(frame.midX, frame.midY + 11)
        starBarNode.position = SPoint(frame.midX - width / 2, frame.midY - 10)
        val track = ShapeNode.rect(SRect(0f, -height / 2, width, height), height / 2)
        track.fillColor = SColor(0.08f, 0.09f, 0.18f)
        track.strokeColor = SColor(1f, 0.16f)
        track.lineWidth = 1.5f
        starBarNode.addChild(track)
        starFill.fillColor = P.container
        starFill.strokeColor = SColor.clear
        starFill.z = 0.1f
        starBarNode.addChild(starFill)
        for (fraction in listOf(0f, starScores[0].toFloat() / starScores[1], 1f)) {
            val (node, face) = makeStar(21f)
            node.position = SPoint(width * fraction, 1f)
            node.z = 0.2f
            starBarNode.addChild(node)
            starMarks.add(face)
            starsLit.add(false)
        }
        hudNode.addChild(starBarNode)
    }

    val starsShown: Int
        get() {
            if (starScores.size != 2) return 0
            val cleared = if (state.status == GameStatus.WON) 1 else 0
            return cleared + starScores.count { displayedScore >= it }
        }

    val starBarFraction: Float
        get() = if (starScores.size != 2) 0f else minOf(displayedScore.toFloat() / starScores[1], 1f)

    /** 화면 밖의 표시(앱의 정보 줄)가 쓰는 값. */
    val movesText get() = (movesShown ?: state.movesRemaining)?.let { tr("이동 %lld", it) } ?: ""

    private fun updateHUD() {
        movesLabel.text = movesText
        scoreLabel.text = if (state.materialsTotal > 0) tr("%lld점", displayedScore) else ""
        materialsLabel.text = if (state.materialsTotal > 0) tr("물질 %lld/%lld", collectedShown, state.materialsTotal) else ""
        onChange?.invoke()
        if (starMarks.isEmpty()) return
        val height = STAR_BAR_HEIGHT - 4
        val filled = if (starBarFraction > 0) maxOf((STAR_BAR_WIDTH - 4) * starBarFraction, height) else 0f
        starFill.path = Paths.roundedRect(SRect(2f, -height / 2, filled, height), minOf(height, filled) / 2, height / 2)
        val won = state.status == GameStatus.WON
        starMarks.forEachIndexed { index, star ->
            val lit = if (index == 0) won else displayedScore >= starScores[index - 1]
            star.fontColor = if (lit) P.container else SColor(0.36f, 0.39f, 0.54f)
            if (lit && !starsLit[index]) {
                star.parent?.run(Action.sequence(Action.scaleTo(1.6f, 0.12), Action.scaleTo(1f, 0.18)))
            }
            starsLit[index] = lit
        }
    }

    private fun updateQueue() {
        queueNode.removeAllChildren()
        val frame = sceneLayout.queueFrame
        val countByColumn = HashMap<Int, Int>()
        for (pending in pendingShown) {
            val index = countByColumn[pending.column] ?: 0
            countByColumn[pending.column] = index + 1
            val x = layout.center(Position(pending.column, 0)).x
            val marker = Node()
            marker.position = SPoint(x + index * layout.cellSize * 0.3f, frame.midY)
            val icon = BlockSprite.makeNode(Block.Material, frame.height)
            icon.x = -layout.cellSize * 0.2f
            marker.addChild(icon)
            val label = makeLabel(frame.height * 0.75f, HAlign.LEFT)
            label.text = "${pending.depth + 1}"
            label.fontColor = P.material
            label.x = -layout.cellSize * 0.2f + frame.height * 0.55f
            marker.addChild(label)
            queueNode.addChild(marker)
        }
    }

    val containerDrawFrame: SRect
        get() {
            var frame = sceneLayout.containerFrame
            state.containerColumns?.let { columns ->
                val cell = layout.cellSize
                frame = SRect(frame.minX + columns.first * cell, frame.minY, (columns.last - columns.first + 1) * cell, frame.height)
            }
            val texture = BlockSprite.texture(CONTAINER_SPRITE) ?: return frame
            val natural = frame.width * texture.height / texture.width
            val height = maxOf(minOf(natural * 1.3f, frame.maxY - 2), frame.height)
            return SRect(frame.minX, frame.maxY - height, frame.width, height)
        }

    private fun buildContainer() {
        containerNode = Node()
        containerLamps.clear()
        if (state.materialsTotal <= 0) return
        val frame = containerDrawFrame
        containerNode.position = SPoint(frame.midX, frame.midY)
        val size = frame.size
        val texture = BlockSprite.texture(CONTAINER_SPRITE)
        if (texture != null) {
            val sprite = SpriteNode(texture, size.width, size.height)
            sprite.name = CONTAINER_SPRITE
            containerNode.addChild(sprite)
            val glow = SpriteNode(SColor(0.6f, 0.95f, 1f), size.width * 0.8f, size.height * 0.22f)
            glow.y = size.height * 0.27f
            glow.additive = true
            glow.alpha = 0.05f
            glow.z = 0.1f
            glow.run(Action.repeatForever(Action.sequence(Action.fadeAlpha(0.3f, 0.9), Action.fadeAlpha(0.05f, 0.9))))
            containerNode.addChild(glow)
        }
        val count = state.materialsTotal
        val radius = minOf(size.height * 0.2f, size.width / (count * 4))
        val spacing = radius * 2.9f
        for (index in 0 until count) {
            val lamp = ShapeNode.circle(radius)
            lamp.position = SPoint((index - (count - 1) / 2f) * spacing, -size.height * 0.17f)
            lamp.lineWidth = maxOf(radius * 0.3f, 1f)
            lamp.z = 0.2f
            containerNode.addChild(lamp)
            containerLamps.add(lamp)
        }
        updateContainerLamps()
        containerNode.alpha = if (isAtBoardEnd(state.activeTop)) 1f else 0.35f
        boardNode.addChild(containerNode)
    }

    private fun updateContainerLamps() {
        containerLamps.forEachIndexed { index, lamp ->
            val lit = index < collectedShown
            lamp.fillColor = if (lit) P.material else SColor(0.08f, 0.09f, 0.18f)
            lamp.strokeColor = if (lit) SColor(1f, 0.75f, 0.88f) else SColor(1f, 0.25f)
            if (!lit || lamp.childNamed("blob") != null) return@forEachIndexed
            val texture = BlockSprite.texture(BlockSprite.MATERIAL_NAME) ?: return@forEachIndexed
            val side = lamp.contentWidth * 1.25f
            val blob = SpriteNode(texture, side, side)
            blob.name = "blob"
            blob.z = 0.1f
            lamp.addChild(blob)
            val beat = 0.7 + (index % 3) * 0.15
            blob.run(
                Action.repeatForever(
                    Action.sequence(
                        Action.group(Action.scaleXTo(1.08f, beat), Action.scaleYTo(0.92f, beat), Action.rotateBy(0.25f, beat)),
                        Action.group(Action.scaleXTo(0.94f, beat), Action.scaleYTo(1.06f, beat), Action.rotateBy(-0.25f, beat)),
                    ),
                ),
            )
        }
    }

    private fun gulp(newlyLit: IntRange) {
        val size = containerDrawFrame.size
        containerNode.run(
            Action.sequence(
                Action.wait(T.collect * 0.7),
                Action.group(Action.scaleXTo(1.05f, 0.07), Action.scaleYTo(0.86f, 0.07)),
                Action.group(Action.scaleXTo(0.98f, 0.09), Action.scaleYTo(1.1f, 0.09)),
                Action.scaleTo(1f, 0.1),
            ),
        )
        val flash = SpriteNode(SColor(0.75f, 1f, 1f), size.width * 0.86f, size.height * 0.5f)
        flash.y = size.height * 0.2f
        flash.additive = true
        flash.alpha = 0f
        flash.z = 0.3f
        containerNode.addChild(flash)
        flash.run(Action.sequence(Action.wait(T.collect * 0.7), Action.fadeAlpha(0.8f, 0.05), Action.fadeOut(0.3), Action.removeFromParent()))
        for (index in newlyLit) {
            if (index !in containerLamps.indices) continue
            containerLamps[index].run(Action.sequence(Action.wait(T.collect * 0.7), Action.scaleTo(1.8f, 0.1), Action.scaleTo(1f, 0.18)))
        }
    }

    private fun isAtBoardEnd(top: Int) = top + activeRowCount >= state.board.rows

    // MARK: - 미니맵

    private fun buildMinimap() {
        minimapNode = Node()
        if (state.board.rows <= activeRowCount) return
        val frame = sceneLayout.minimapFrame
        val track = ShapeNode.rect(frame, 3f)
        track.fillColor = SColor(1f, 0.08f)
        track.strokeColor = SColor.clear
        minimapNode.addChild(track)
        minimapViewport = ShapeNode()
        minimapViewport.fillColor = SColor(1f, 0.22f)
        minimapViewport.strokeColor = SColor(1f, 0.7f)
        minimapViewport.lineWidth = 1f
        minimapNode.addChild(minimapViewport)
        boardNode.addChild(minimapNode)
        updateMinimap(state.activeTop.toFloat())
    }

    private fun minimapY(row: Float): Float {
        val frame = sceneLayout.minimapFrame
        return frame.maxY - row / state.board.rows * frame.height
    }

    private fun updateMinimap(top: Float) {
        if (minimapNode.parent == null) return
        val frame = sceneLayout.minimapFrame
        val visible = activeRowCount.toFloat()
        minimapViewport.path = Paths.rect(SRect(frame.minX, minimapY(top + visible), frame.width, minimapY(top) - minimapY(top + visible)))
        minimapNode.children.filter { it.name == "dot" }.forEach { it.removeFromParent() }
        val rowsByNode = LinkedHashMap<Node, MutableList<Int>>()
        for ((position, node) in blocks) {
            if (node.name == BlockSprite.MATERIAL_NAME) rowsByNode.getOrPut(node) { mutableListOf() }.add(position.row)
        }
        for (rows in rowsByNode.values) {
            val row = rows.sum().toFloat() / rows.size
            val dot = ShapeNode.circle(frame.width * 0.45f)
            dot.name = "dot"
            dot.fillColor = P.material
            dot.strokeColor = SColor.clear
            dot.position = SPoint(frame.midX, minimapY(row + 0.5f))
            dot.z = 1f
            minimapNode.addChild(dot)
        }
        val obstacleRows = blocks.filter { it.value.name?.startsWith("obstacle_") == true }.map { it.key.row }.toSet()
        for (row in obstacleRows) {
            val mark = SpriteNode(SColor(0.75f, 0.9f), frame.width, maxOf(frame.height / state.board.rows * 0.5f, 2f))
            mark.name = "dot"
            mark.position = SPoint(frame.midX, minimapY(row + 0.5f))
            mark.z = 0.5f
            minimapNode.addChild(mark)
        }
        for (index in pendingShown.indices) {
            val ring = ShapeNode.circle(frame.width * 0.38f)
            ring.name = "dot"
            ring.fillColor = SColor.clear
            ring.strokeColor = P.material
            ring.lineWidth = 1.5f
            ring.position = SPoint(frame.midX, frame.maxY + 8 + index * (frame.width + 2))
            minimapNode.addChild(ring)
        }
    }

    private fun preview(point: SPoint) {
        val frame = sceneLayout.minimapFrame
        val visible = activeRowCount.toFloat()
        val row = (frame.maxY - point.y) / frame.height * state.board.rows - visible / 2
        val top = minOf(maxOf(row, state.activeTop.toFloat()), state.board.rows - visible)
        worldNode.removeAllActions()
        worldNode.position = worldOffset(top)
        updateMinimap(top)
    }

    // MARK: - 입력

    fun beginDrag(point: SPoint) {
        if (isAnimating) return
        cancelHint()
        scheduleHint()
        if (isShowingResult) {
            if (onFinish == null) restart()
            return
        }
        if (minimapNode.parent != null && sceneLayout.minimapFrame.insetBy(-14f, 0f).contains(point)) {
            isPreviewing = true
            preview(point)
            return
        }
        val visible = layout.position(point) ?: return
        if (armedTool == Tool.HAMMER) {
            val target = Position(visible.column, visible.row + state.activeTop)
            val result = state.hammering(target)
            if (result != null) {
                armedTool = null
                addHammerStrike(target)
                onToolUsed?.invoke(Tool.HAMMER)
                run(result)
            } else {
                feedback?.play(GameSound.REJECT)
            }
            return
        }
        dragStart = point to Position(visible.column, visible.row + state.activeTop)
    }

    override fun touchDown(point: SPoint) = beginDrag(point)
    override fun touchMove(point: SPoint) = continueDrag(point)
    override fun touchUp() = endDrag()

    /** 손가락이 칸의 1/3 이상 움직이면 그 방향의 이웃 칸과 스왑한다. */
    fun continueDrag(point: SPoint) {
        if (isPreviewing) {
            preview(point)
            return
        }
        val start = dragStart
        if (isAnimating || start == null) return
        val dx = point.x - start.first.x
        val dy = point.y - start.first.y
        if (maxOf(abs(dx), abs(dy)) < layout.cellSize / 3) return
        dragStart = null
        var target = start.second
        target = if (abs(dx) > abs(dy)) target.copy(column = target.column + if (dx > 0) 1 else -1)
        else target.copy(row = target.row + if (dy > 0) -1 else 1)
        if (!state.board.contains(target) || target.row !in state.activeRange) return
        perform(Swap(start.second, target))
    }

    fun endDrag() {
        dragStart = null
        if (isPreviewing) {
            isPreviewing = false
            worldNode.run(Action.moveTo(worldOffset(state.activeTop.toFloat()), 0.2).apply { timing = Timing.EASE_OUT })
            updateMinimap(state.activeTop.toFloat())
        }
    }

    fun perform(swap: Swap) {
        if (isAnimating || isPreviewing || isShowingResult) return
        if (armedTool == Tool.SWAP) {
            if (state.rejection(swap) == SwapRejection.NO_MATCH) {
                val result = state.freeSwapping(swap)
                if (result != null) {
                    armedTool = null
                    onToolUsed?.invoke(Tool.SWAP)
                    run(result)
                    return
                }
            }
            if (state.rejection(swap) != null) {
                feedback?.play(GameSound.REJECT)
                return
            }
            armedTool = null
        }
        run(state.performTurn(swap))
    }

    private fun run(result: TurnResult) {
        cancelHint()
        val before = state.score
        state = result.state
        if (state.status != GameStatus.PLAYING) hasPendingResult = true
        isAnimating = true
        planScore(result.events, before)
        updateHUD()
        play(result.events, 0)
    }

    fun useShuffle(): Boolean {
        if (isAnimating || isPreviewing || isShowingResult) return false
        val result = state.shuffling() ?: return false
        armedTool = null
        onToolUsed?.invoke(Tool.SHUFFLE)
        run(result)
        return true
    }

    val canUseTools get() = !isAnimating && !isPreviewing && !isShowingResult && state.status == GameStatus.PLAYING

    private fun addHammerStrike(position: Position) {
        val cell = layout.cellSize
        val center = layout.center(position)
        val texture = BlockSprite.texture("tool_hammer")
        val hammer: Node = if (texture != null) SpriteNode(texture, cell * 1.2f, cell * 1.2f) else LabelNode("🔨", cell * 0.9f)
        hammer.position = SPoint(center.x + cell * 0.5f, center.y + cell * 1.1f)
        hammer.rotation = -0.9f
        hammer.z = 9f
        worldNode.addChild(hammer)
        val swing = Action.group(Action.moveTo(SPoint(center.x + cell * 0.2f, center.y + cell * 0.2f), 0.1), Action.rotateTo(0.5f, 0.1))
        swing.timing = Timing.EASE_IN
        hammer.run(Action.sequence(swing, Action.wait(0.06), Action.group(Action.fadeOut(0.15), Action.moveBy(0f, cell * 0.3f, 0.15)), Action.removeFromParent()))
        val ring = ShapeNode.circle(cell * 0.3f)
        ring.position = center
        ring.strokeColor = SColor.white
        ring.lineWidth = cell * 0.1f
        ring.fillColor = SColor.clear
        ring.additive = true
        ring.alpha = 0f
        ring.z = 8f
        worldNode.addChild(ring)
        ring.run(Action.sequence(Action.wait(0.1), Action.fadeAlpha(1f, 0.01), Action.group(Action.scaleTo(2.6f, 0.25), Action.fadeOut(0.25)), Action.removeFromParent()))
        shakeBoard(6f)
    }

    /** 진 판을 이동 횟수를 더 받아 이어 한다. */
    fun continuePlaying(extraMoves: Int): Boolean {
        if (!isShowingResult || isAnimating) return false
        val next = state.copy()
        if (!next.continuePlaying(extraMoves)) return false
        state = next
        isShowingResult = false
        val result = state.settle()
        state = result.state
        if (state.status != GameStatus.PLAYING) hasPendingResult = true
        updateHUD()
        if (result.events.isEmpty()) {
            scheduleHint()
        } else {
            isAnimating = true
            play(result.events, 0)
        }
        return true
    }

    fun restart() {
        state = initialState.copy()
        hasPendingResult = false
        rebuild()
        scheduleHint()
        autoPlayIfNeeded()
    }

    // MARK: - 이벤트 재생

    private fun planScore(events: List<GameEvent>, before: Int) {
        finalBonus = if (state.status == GameStatus.WON) (state.movesRemaining ?: 0) * GameConstants.SCORE_PER_REMAINING_MOVE else 0
        val gained = state.score - before - finalBonus
        val weights = events.map { event ->
            when (event) {
                is GameEvent.MatchesCleared -> event.matches.flatMap { it.positions }.toSet().size * minOf(event.chain, GameConstants.MAXIMUM_CHAIN_MULTIPLIER)
                is GameEvent.SpecialsActivated -> event.activations.flatMap { it.cleared }.toSet().size
                is GameEvent.Hammered -> 1
                else -> 0
            }
        }
        val total = weights.sum()
        scoreSteps = IntArray(weights.size) { if (total > 0) gained * weights[it] / total else 0 }
        val last = weights.indexOfLast { it > 0 }
        if (last >= 0) scoreSteps[last] += gained - scoreSteps.sum()
        if (width <= 0f) {
            displayedScore = state.score
            scoreSteps = IntArray(0)
            finalBonus = 0
        }
    }

    private fun addScore(amount: Int) {
        if (amount == 0) return
        displayedScore += amount
        updateHUD()
        scoreLabel.removeAction("pop")
        scoreLabel.setScale(1f)
        scoreLabel.run(Action.sequence(Action.scaleTo(1.25f, 0.07), Action.scaleTo(1f, 0.13)), "pop")
    }

    private fun play(events: List<GameEvent>, index: Int) {
        val event = events.firstOrNull()
        if (event == null) {
            isAnimating = false
            updateHUD()
            scheduleHint()
            autoPlayIfNeeded()
            return
        }
        val flow = events.takeWhile { isMotion(it) }
        if (flow.isEmpty() && index in scoreSteps.indices) addScore(scoreSteps[index])
        val duration = if (flow.isEmpty()) animate(event) else animateFlow(flow)
        val consumed = maxOf(flow.size, 1)
        val remaining = events.drop(consumed)
        boardNode.run(Action.wait(duration)) { play(remaining, index + consumed) }
    }

    private fun giveFeedback(event: GameEvent) {
        val feedback = feedback ?: return
        when (event) {
            is GameEvent.Swapped -> { feedback.play(GameSound.SWAP); feedback.haptic(GameHaptic.LIGHT) }
            is GameEvent.SwapRejected -> { feedback.play(GameSound.REJECT); feedback.haptic(GameHaptic.WARNING) }
            is GameEvent.MatchesCleared -> {
                feedback.play(GameSound.clear(event.chain))
                feedback.haptic(if (event.chain >= 3) GameHaptic.MEDIUM else GameHaptic.LIGHT)
            }
            is GameEvent.SpecialsActivated -> { feedback.play(GameSound.SPECIAL); feedback.haptic(GameHaptic.HEAVY) }
            is GameEvent.SpecialsCreated -> feedback.play(GameSound.CREATE)
            is GameEvent.ObstaclesDamaged -> { feedback.play(GameSound.CRACK); feedback.haptic(GameHaptic.MEDIUM) }
            is GameEvent.MaterialsCollected -> { feedback.play(GameSound.COLLECT); feedback.haptic(GameHaptic.SUCCESS) }
            GameEvent.Won -> { feedback.play(GameSound.WIN); feedback.haptic(GameHaptic.SUCCESS) }
            GameEvent.Lost -> { feedback.play(GameSound.LOSE); feedback.haptic(GameHaptic.FAILURE) }
            is GameEvent.Hammered -> { feedback.play(GameSound.CRACK); feedback.haptic(GameHaptic.HEAVY) }
            is GameEvent.NestsSpat -> { feedback.play(GameSound.CRACK); feedback.haptic(GameHaptic.LIGHT) }
            is GameEvent.TimersBurst -> { feedback.play(GameSound.SPECIAL); feedback.haptic(GameHaptic.HEAVY) }
            else -> {}
        }
    }

    /** 이벤트 하나의 애니메이션을 시작하고 걸리는 시간을 돌려준다. */
    private fun animate(event: GameEvent): Double {
        giveFeedback(event)
        when (event) {
            is GameEvent.Swapped -> {
                val first = blocks[event.swap.from]
                val second = blocks[event.swap.to]
                first?.run(move(event.swap.to, T.swap))
                second?.run(move(event.swap.from, T.swap))
                setBlock(event.swap.from, second)
                setBlock(event.swap.to, first)
                return T.swap
            }
            is GameEvent.SwapRejected -> {
                if (event.rejection != SwapRejection.NO_MATCH) return 0.0
                for ((from, to) in listOf(event.swap.from to event.swap.to, event.swap.to to event.swap.from)) {
                    blocks[from]?.run(Action.sequence(move(to, T.swap), move(from, T.swap)))
                }
                return T.swap * 2
            }
            is GameEvent.MatchesCleared -> {
                val popped = LinkedHashMap<Position, Double>()
                val tints = LinkedHashMap<Position, SColor>()
                for (position in event.matches.flatMap { it.positions }) {
                    val name = blocks[position]?.name
                    if (name?.endsWith("_caged") == true || name?.endsWith("_chained") == true) continue
                    popped[position] = 0.0
                    tints[position] = tint(position)
                    removeBlock(position, 0.2f, T.clear)
                }
                for ((position, color) in tints) addPop(position, 0.0, color, bright = false)
                addSparks(popped, tints)
                if (event.chain >= 3) showPraise(event.chain)
                return T.clear
            }
            is GameEvent.SpecialsActivated -> return animateActivations(event.activations)
            is GameEvent.SpecialsCreated -> {
                for (spawn in event.spawns) {
                    blocks.remove(spawn.position)?.removeFromParent()
                    val node = addBlock(spawn.block, spawn.position, spawn.position)
                    node.setScale(0.3f)
                    node.run(Action.scaleTo(1f, T.create))
                }
                return T.create
            }
            is GameEvent.Fell, is GameEvent.Slid, is GameEvent.Refilled -> return animateFlow(listOf(event))
            is GameEvent.ObstaclesDamaged -> {
                for (hit in event.hits) {
                    removeBlock(hit.position, 1.2f, T.clear)
                    hit.remaining?.let { addBlock(it, hit.position, hit.position) }
                }
                updateMinimap(displayedTop)
                return T.clear
            }
            is GameEvent.SludgeSpread -> {
                for (position in event.positions) {
                    blocks.remove(position)?.removeFromParent()
                    val node = addBlock(Block.Sludge, position, position)
                    node.setScale(0.3f)
                    node.run(Action.scaleTo(1f, T.create))
                }
                updateMinimap(displayedTop)
                return T.create
            }
            is GameEvent.NestsSpat -> {
                val flight = T.create
                for (spit in event.spits) {
                    blocks[spit.nest]?.run(Action.sequence(Action.scaleTo(1.25f, flight * 0.4), Action.scaleTo(1f, flight * 0.6)))
                    val blob = BlockSprite.makeNode(Block.Sludge, layout.cellSize)
                    blob.position = layout.center(spit.nest)
                    blob.setScale(0.3f)
                    blob.z = 20f
                    worldNode.addChild(blob)
                    val target = spit.target
                    blob.run(
                        Action.sequence(
                            Action.group(Action.moveTo(layout.center(target), flight), Action.scaleTo(0.8f, flight)),
                            Action.removeFromParent(),
                            Action.run {
                                blocks.remove(target)?.removeFromParent()
                                val node = addBlock(Block.Sludge, target, target)
                                node.setScale(0.8f)
                                node.run(Action.scaleTo(1f, T.create * 0.5))
                            },
                        ),
                    )
                }
                boardNode.run(Action.sequence(Action.wait(flight * 1.5), Action.run { updateMinimap(displayedTop) }))
                return flight * 1.6
            }
            is GameEvent.Hammered -> {
                val color = tint(event.position)
                removeBlock(event.position, 1.6f, T.pop, 0.1)
                addPop(event.position, 0.1, color, bright = true)
                addSparks(mapOf(event.position to 0.1), mapOf(event.position to color))
                return 0.1 + T.pop
            }
            is GameEvent.ShieldsBroken -> {
                for (position in event.positions) {
                    val node = shieldNodes.remove(position) ?: continue
                    node.removeAllActions()
                    node.run(Action.sequence(Action.group(Action.scaleTo(1.5f, T.clear), Action.fadeOut(T.clear)), Action.removeFromParent()))
                }
                return 0.0
            }
            is GameEvent.VentsPuffed -> {
                for (position in event.positions) {
                    if (fogNodes[position] != null) continue
                    val node = addFog(position)
                    node.alpha = 0f
                    node.run(Action.fadeIn(T.create * 2))
                }
                return T.create
            }
            is GameEvent.StickyCleared -> {
                for (position in event.positions) {
                    val node = stickyNodes.remove(position) ?: continue
                    node.run(Action.sequence(Action.group(Action.scaleTo(0.2f, T.clear * 1.4), Action.fadeOut(T.clear * 1.4)), Action.removeFromParent()))
                }
                return 0.0
            }
            is GameEvent.FogLifted -> {
                for (position in event.positions) {
                    val node = fogNodes.remove(position) ?: continue
                    node.removeAllActions()
                    node.run(Action.sequence(Action.group(Action.scaleTo(1.5f, T.clear * 1.4), Action.fadeOut(T.clear * 1.4)), Action.removeFromParent()))
                }
                return 0.0
            }
            is GameEvent.TimersTicked -> {
                for (tick in event.ticks) {
                    val node = blocks[tick.position] ?: continue
                    BlockSprite.setTimer(tick.turns, node)
                    val badge = node.childNamed(BlockSprite.TIMER_NAME)
                    val scale = if (tick.turns <= 2) 1.45f else 1.2f
                    badge?.run(Action.sequence(Action.scaleTo(scale, T.create * 0.4), Action.scaleTo(1f, T.create * 0.6)))
                }
                return T.create * 0.6
            }
            is GameEvent.TimersBurst -> {
                for (burst in event.bursts) {
                    val ring = ShapeNode.circle(layout.cellSize * 0.4f)
                    ring.position = layout.center(burst.position)
                    ring.strokeColor = SColor(1.0f, 0.3f, 0.6f)
                    ring.lineWidth = layout.cellSize * 0.12f
                    ring.fillColor = SColor.clear
                    ring.z = 20f
                    worldNode.addChild(ring)
                    ring.run(Action.sequence(Action.group(Action.scaleTo(3.4f, T.create), Action.fadeOut(T.create)), Action.removeFromParent()))
                    for (position in burst.sludge) {
                        blocks.remove(position)?.removeFromParent()
                        val node = addBlock(Block.Sludge, position, burst.position)
                        node.setScale(0.3f)
                        node.run(Action.group(Action.moveTo(layout.center(position), T.create), Action.scaleTo(1f, T.create)))
                    }
                }
                shakeBoard(10f)
                updateMinimap(displayedTop)
                return T.create * 1.2
            }
            is GameEvent.Shuffled -> {
                val before = HashMap(blocks)
                for (blockMove in event.moves) {
                    val node = before[blockMove.from] ?: continue
                    blocks[blockMove.to] = node
                    node.run(move(blockMove.to, T.shuffle, Timing.EASE_IN_OUT))
                }
                return T.shuffle
            }
            is GameEvent.Regenerated -> {
                for (spawn in event.spawns) {
                    blocks.remove(spawn.position)?.removeFromParent()
                    val node = addBlock(spawn.block, spawn.position, spawn.position)
                    node.alpha = 0f
                    node.run(Action.fadeIn(T.shuffle))
                }
                return T.shuffle
            }
            is GameEvent.MaterialsCollected -> {
                val container = containerDrawFrame
                val collected = LinkedHashSet<Node>()
                for (position in event.positions) blocks.remove(position)?.let { collected.add(it) }
                for (node in collected) {
                    val start = SPoint(node.x + worldNode.x, node.y + worldNode.y)
                    node.removeFromParent()
                    node.position = start
                    node.z = 5f
                    boardNode.addChild(node)
                    node.run(
                        Action.sequence(
                            Action.group(Action.moveTo(SPoint(start.x, container.midY), T.collect), Action.scaleTo(0.4f, T.collect)),
                            Action.removeFromParent(),
                        ),
                    )
                }
                val before = collectedShown
                collectedShown += collected.size
                gulp(before until collectedShown)
                updateContainerLamps()
                updateHUD()
                updateMinimap(displayedTop)
                return T.collect
            }
            is GameEvent.Scrolled -> {
                val duration = minOf(T.scrollPerRow * (event.to - event.from), 0.8)
                worldNode.run(Action.moveTo(worldOffset(event.to.toFloat()), duration).apply { timing = Timing.EASE_IN_OUT })
                for ((position, node) in blocks.toList()) {
                    if (position.row >= event.to) continue
                    blocks.remove(position)
                    node.run(Action.sequence(Action.wait(duration), Action.removeFromParent()))
                }
                updateMinimap(event.to.toFloat())
                if (isAtBoardEnd(event.to)) containerNode.run(Action.fadeAlpha(1f, duration))
                return duration
            }
            GameEvent.Won, GameEvent.Lost -> {
                val duration = tallyRemainingMoves()
                boardNode.run(Action.wait(duration)) {
                    displayedScore = state.score
                    movesShown = null
                    updateHUD()
                    showResult(notify = true)
                }
                return duration
            }
        }
    }

    /** 노드를 칸에 둔다. 노드가 없으면 칸을 비운다. */
    private fun setBlock(position: Position, node: Node?) {
        if (node == null) blocks.remove(position) else blocks[position] = node
    }

    private fun tallyRemainingMoves(): Double {
        val moves = state.movesRemaining ?: 0
        if (finalBonus <= 0 || moves <= 0) {
            displayedScore = state.score
            updateHUD()
            return 0.25
        }
        val step = minOf(0.08, 1.2 / moves)
        val perMove = finalBonus / moves
        movesShown = moves
        for (index in 0 until moves) {
            boardNode.run(Action.wait((index + 1) * step)) {
                movesShown = moves - index - 1
                addScore(perMove)
                if (index % 2 == 0) feedback?.play(GameSound.TAP)
            }
        }
        return moves * step + 0.45
    }

    private val displayedTop get() = if (layout.cellSize > 0) worldNode.y / layout.cellSize else 0f

    /**
     * 끝나는 연출을 기다리는 결과를 연출을 건너뛰고 바로 알린다. 연출 도중에 화면을 나갈 때 쓴다.
     * @return 알렸는지. 알릴 결과가 없으면 `false`다.
     */
    fun deliverPendingResult(): Boolean {
        if (!hasPendingResult) return false
        // 끝난 상태로 다시 그리면 남은 연출이 버려지고, 그 끝에서 결과를 알린다.
        rebuild()
        return true
    }

    private fun showResult(notify: Boolean) {
        isShowingResult = true
        if (notify) {
            hasPendingResult = false
            onFinish?.invoke(state)
        }
    }

    private fun isMotion(event: GameEvent) = event is GameEvent.Fell || event is GameEvent.Slid || event is GameEvent.Refilled

    private class Segment(val start: Double, val duration: Double, val point: SPoint)

    /** 낙하, 흘러내림, 보충을 블록마다 하나의 이어진 움직임으로 재생한다. */
    private fun animateFlow(events: List<GameEvent>): Double {
        val tracks = LinkedHashMap<Node, MutableList<Segment>>()
        var eventStart = 0.0
        fun add(node: Node, duration: Double, order: Int) {
            val previous = tracks[node]?.lastOrNull()
            val start = maxOf(eventStart + T.stagger * order, previous?.let { it.start + it.duration } ?: 0.0)
            tracks.getOrPut(node) { mutableListOf() }.add(Segment(start, if (previous == null) duration else duration * T.carryFactor, centroid(node)))
        }

        for (event in events) {
            when (event) {
                is GameEvent.Fell -> {
                    val moved = mutableListOf<Triple<Node, Int, Int>>()
                    val seen = HashSet<Node>()
                    val orderInColumn = HashMap<Int, Int>()
                    for (blockMove in event.moves) {
                        val node = blocks.remove(blockMove.from) ?: continue
                        blocks[blockMove.to] = node
                        if (!seen.add(node)) continue
                        val order = orderInColumn[blockMove.from.column] ?: 0
                        orderInColumn[blockMove.from.column] = order + 1
                        moved.add(Triple(node, blockMove.to.row - blockMove.from.row, order))
                    }
                    for ((node, cells, order) in moved) add(node, fallDuration(cells), order)
                }
                is GameEvent.Slid -> {
                    event.moves.forEachIndexed { order, blockMove ->
                        val node = blocks.remove(blockMove.from) ?: return@forEachIndexed
                        blocks[blockMove.to] = node
                        add(node, T.slide, order)
                    }
                }
                is GameEvent.Refilled -> {
                    val countByColumn = event.spawns.groupingBy { it.position.column }.eachCount()
                    val orderInColumn = HashMap<Int, Int>()
                    for (spawn in event.spawns) {
                        val column = spawn.position.column
                        if (spawn.block == Block.Material) {
                            val index = pendingShown.indexOfFirst { it.column == column && it.depth == 0 }
                            if (index >= 0) pendingShown.removeAt(index)
                        } else {
                            for (i in pendingShown.indices) {
                                if (pendingShown[i].column == column) pendingShown[i] = pendingShown[i].copy(depth = maxOf(pendingShown[i].depth - 1, 0))
                            }
                        }
                        val count = countByColumn[column] ?: 1
                        val start = Position(column, spawn.position.row - count)
                        val node = addBlock(spawn.block, spawn.position, start)
                        val order = orderInColumn[column] ?: 0
                        orderInColumn[column] = order + 1
                        add(node, fallDuration(count), order)
                    }
                }
                else -> {}
            }
            eventStart += T.flowStep
        }

        var total = 0.0
        for ((node, segments) in tracks) {
            val actions = mutableListOf<Action>()
            var clock = 0.0
            segments.forEachIndexed { index, segment ->
                if (segment.start > clock) actions.add(Action.wait(segment.start - clock))
                actions.add(Action.moveTo(segment.point, segment.duration).apply { timing = if (index == 0) Timing.EASE_IN else Timing.LINEAR })
                clock = segment.start + segment.duration
            }
            if (blocks.values.count { it === node } <= 1) {
                actions.add(
                    Action.sequence(
                        Action.group(Action.scaleXTo(1.12f, 0.05), Action.scaleYTo(0.86f, 0.05)),
                        Action.group(Action.scaleXTo(0.96f, 0.07), Action.scaleYTo(1.05f, 0.07)),
                        Action.group(Action.scaleXTo(1f, 0.06), Action.scaleYTo(1f, 0.06)),
                    ),
                )
            }
            node.run(Action.sequence(actions))
            total = maxOf(total, clock)
        }
        updateQueue()
        updateMinimap(displayedTop)
        return total
    }

    // MARK: - 특수 효과의 연출

    private class Blast(val activation: SpecialActivation, val start: Double, val reach: Double)

    private fun animateActivations(activations: List<SpecialActivation>): Double {
        val delays = LinkedHashMap<Position, Double>()
        val burned = HashSet<Position>()
        val blasts = mutableListOf<Blast>()
        for (activation in activations) {
            val origin = activation.origin
            val start = delays[origin] ?: 0.0
            val ordered = activation.cleared.sortedBy { distance(it, origin) }
            var reach = 0.0
            ordered.forEachIndexed { order, cell ->
                val offset = when (activation.effect) {
                    is SpecialEffect.Beam, SpecialEffect.CrossBeam, SpecialEffect.WideCrossBeam -> distance(cell, origin) * T.beamStep
                    SpecialEffect.Bomb, SpecialEffect.BigBomb -> {
                        burned.add(cell)
                        distance(cell, origin) * T.bombStep
                    }
                    else -> order * minOf(T.coreStep, 0.5 / maxOf(ordered.size, 1))
                }
                reach = maxOf(reach, offset)
                delays[cell] = minOf(delays[cell] ?: Double.POSITIVE_INFINITY, start + offset)
            }
            blasts.add(Blast(activation, start, reach))
        }
        val tints = HashMap<Position, SColor>()
        for (position in delays.keys) tints[position] = tint(position)
        for (blast in blasts) addBlast(blast.activation, blast.start, blast.reach, tints)
        for ((position, delay) in delays) {
            blocks[position]?.run(Action.sequence(Action.wait(maxOf(delay - 0.07, 0.0)), Action.scaleTo(1.22f, 0.07)))
            removeBlock(position, 1.7f, T.pop, delay)
            addPop(position, delay, tints[position] ?: SColor.white, bright = position !in burned)
        }
        addSparks(delays, tints)
        val cleared = delays.keys.toSet()
        knockBack(activations.map { it.origin }, cleared)
        shakeBoard(minOf(cleared.size.toFloat(), 24f))
        for (blast in blasts) {
            when (blast.activation.effect) {
                SpecialEffect.BigBomb, SpecialEffect.WideCrossBeam, is SpecialEffect.CoreBeam, is SpecialEffect.CoreBomb -> flashBoard(0.16f, blast.start)
                SpecialEffect.ClearBoard -> flashBoard(0.3f, blast.start)
                SpecialEffect.CrossBeam, is SpecialEffect.Core -> flashBoard(0.07f, blast.start)
                else -> {}
            }
        }
        return (delays.values.maxOrNull() ?: 0.0) + T.pop
    }

    private fun showPraise(chain: Int) {
        val words = listOf("좋아요!", "멋져요!", "굉장해요!", "환상적이에요!").map { tr(it) }
        val node = Node()
        node.position = SPoint(layout.frame.midX, layout.frame.midY + layout.cellSize * 1.5f)
        node.z = 9f
        val size = layout.cellSize * (0.85f + minOf(chain - 3, 3) * 0.1f)
        for ((offset, color) in listOf(SPoint(0f, -size * 0.07f) to SColor(0.45f, 0.1f, 0.3f), SPoint.zero to SColor(1f, 0.88f, 0.35f))) {
            val label = makeLabel(size)
            label.text = words[minOf(chain - 3, words.size - 1)]
            label.fontColor = color
            label.position = offset
            node.addChild(label)
        }
        val width = (node.children.maxOfOrNull { it.contentWidth } ?: size * 4) + size * 1.2f
        val backing = ShapeNode.rect(SRect(-width / 2, -size * 0.75f, width, size * 1.5f), size * 0.75f)
        backing.fillColor = SColor(0.1f, 0.08f, 0.22f, 0.78f)
        backing.strokeColor = SColor(1f, 0.88f, 0.35f, 0.9f)
        backing.lineWidth = maxOf(size * 0.06f, 1.5f)
        backing.z = -1f
        node.addChild(backing)
        node.setScale(0.3f)
        node.alpha = 0f
        boardNode.addChild(node)
        val pop = Action.scaleTo(1.15f, 0.14).apply { timing = Timing.EASE_OUT }
        node.run(
            Action.sequence(
                Action.group(Action.fadeIn(0.08), pop),
                Action.scaleTo(1f, 0.08),
                Action.wait(0.35),
                Action.group(Action.moveBy(0f, layout.cellSize * 0.8f, 0.3), Action.fadeOut(0.3)),
                Action.removeFromParent(),
            ),
        )
    }

    private fun tint(position: Position): SColor {
        val name = blocks[position]?.name ?: return SColor.white
        for (kind in BlockKind.entries) if (name.startsWith(BlockSprite.name(kind))) return BlockSprite.color(kind)
        return SColor(1f, 0.9f, 0.5f)
    }

    private fun light(texture: androidx.compose.ui.graphics.ImageBitmap, color: SColor, width: Float, height: Float, at: SPoint, z: Float = 3f): SpriteNode {
        val node = SpriteNode(texture, width, height)
        node.color = color
        node.colorBlendFactor = 1f
        node.additive = true
        node.position = at
        node.z = z
        node.alpha = 0f
        worldNode.addChild(node)
        return node
    }

    private fun addPop(position: Position, delay: Double, tint: SColor, bright: Boolean) {
        val cell = layout.cellSize
        val center = layout.center(position)
        val glow = light(EffectTexture.glow, tint, cell * 1.5f, cell * 1.5f, center, 2.5f)
        glow.setScale(0.5f)
        glow.run(
            Action.sequence(
                Action.wait(delay), Action.fadeAlpha(if (bright) 0.7f else 0.5f, 0.03),
                Action.group(Action.scaleTo(1.7f, T.pop * 1.3), Action.fadeOut(T.pop * 1.3)), Action.removeFromParent(),
            ),
        )
        if (!bright) return
        val star = light(EffectTexture.sparkle, SColor.white, cell * 1.3f, cell * 1.3f, center, 3.4f)
        star.setScale(0.2f)
        star.rotation = ((position.column * 7 + position.row * 13) % 8) * PI.toFloat() / 8
        val grow = Action.scaleTo(1.15f, T.pop * 0.45).apply { timing = Timing.EASE_OUT }
        star.run(
            Action.sequence(
                Action.wait(delay), Action.fadeAlpha(1f, 0.02),
                Action.group(Action.sequence(grow, Action.scaleTo(0f, T.pop * 0.75)), Action.rotateBy(PI.toFloat() / 2, T.pop * 1.2)),
                Action.removeFromParent(),
            ),
        )
    }

    private fun flashBoard(alpha: Float, delay: Double) {
        val flash = SpriteNode(SColor.white, layout.frame.width, layout.frame.height)
        flash.position = SPoint(layout.frame.midX, layout.frame.midY)
        flash.z = 8f
        flash.additive = true
        flash.alpha = 0f
        boardNode.addChild(flash)
        flash.run(Action.sequence(Action.wait(delay), Action.fadeAlpha(alpha, 0.04), Action.fadeOut(0.3), Action.removeFromParent()))
    }

    private fun distance(first: Position, second: Position) = maxOf(abs(first.column - second.column), abs(first.row - second.row))

    private fun addBlast(activation: SpecialActivation, start: Double, reach: Double, tints: Map<Position, SColor>) {
        val center = layout.center(activation.origin)
        val cell = layout.cellSize
        val boardWidth = layout.frame.width
        val warm = SColor(1f, 0.78f, 0.3f)
        val cool = SColor(0.55f, 0.95f, 1f)

        fun beam(orientation: Orientation, thickness: Float) {
            val length = if (orientation == Orientation.HORIZONTAL) boardWidth * 2 else GameConstants.ACTIVE_ROWS * cell * 2
            val angle = if (orientation == Orientation.HORIZONTAL) 0f else (PI / 2).toFloat()
            val ax = cos(angle)
            val ay = sin(angle)
            val travel = maxOf(reach, 0.12)
            val layers = listOf(
                Triple(thickness * 2.6f, SColor(0.2f, 0.75f, 1f), 0.55f),
                Triple(thickness * 1.3f, cool, 0.95f),
                Triple(thickness * 0.5f, SColor.white, 1f),
            )
            for ((w, color, a) in layers) {
                val bar = light(EffectTexture.beam, color, length, cell * w, center)
                bar.rotation = angle
                bar.xScale = 0.02f
                val grow = Action.scaleXTo(1f, travel).apply { timing = Timing.EASE_OUT }
                val flicker = Action.sequence(Action.scaleYTo(1.25f, T.beamHold / 2), Action.scaleYTo(0.9f, T.beamHold / 2))
                bar.run(
                    Action.sequence(
                        Action.wait(start), Action.fadeAlpha(a, 0.02), grow, flicker,
                        Action.group(Action.scaleYTo(0.05f, T.beamFade), Action.fadeOut(T.beamFade)), Action.removeFromParent(),
                    ),
                )
            }
            for (side in listOf(-1f, 1f)) {
                val root = sqrt(thickness)
                val head = light(EffectTexture.glow, SColor.white, cell * 2.2f * root, cell * 1.5f * root, center, 3.2f)
                head.rotation = angle
                val run = Action.moveBy(ax * side * length / 2, ay * side * length / 2, travel).apply { timing = Timing.EASE_OUT }
                head.run(Action.sequence(Action.wait(start), Action.fadeAlpha(1f, 0.02), run, Action.fadeOut(0.12), Action.removeFromParent()))
                for (index in 0 until 7) {
                    val lane = (((index * 5) % 7) / 6f - 0.5f) * cell * thickness * 1.5f
                    val streak = light(
                        EffectTexture.glow, if (index % 2 == 0) SColor.white else cool,
                        cell * (0.9f + (index % 3) * 0.4f), cell * 0.1f,
                        SPoint(center.x - ay * lane, center.y + ax * lane), 3.3f,
                    )
                    streak.rotation = angle
                    val fly = Action.moveBy(ax * side * length * 0.45f, ay * side * length * 0.45f, travel + T.beamHold + 0.15).apply { timing = Timing.EASE_OUT }
                    streak.run(
                        Action.sequence(
                            Action.wait(start + index * 0.025), Action.fadeAlpha(0.9f, 0.02),
                            Action.group(fly, Action.sequence(Action.wait(travel), Action.fadeOut(T.beamHold + 0.15))),
                            Action.removeFromParent(),
                        ),
                    )
                }
            }
            val muzzle = light(EffectTexture.glow, SColor.white, cell * 2, cell * 2, center, 3.4f)
            muzzle.setScale(0.4f)
            muzzle.run(Action.sequence(Action.wait(start), Action.fadeAlpha(1f, 0.03), Action.group(Action.scaleTo(1.6f * sqrt(thickness), 0.3), Action.fadeOut(0.3)), Action.removeFromParent()))
            val star = light(EffectTexture.sparkle, SColor.white, cell * 2.6f, cell * 2.6f, center, 3.5f)
            star.setScale(0.2f)
            star.run(
                Action.sequence(
                    Action.wait(start), Action.fadeAlpha(1f, 0.02),
                    Action.group(Action.sequence(Action.scaleTo(sqrt(thickness) * 1.2f, 0.14), Action.scaleTo(0f, 0.26)), Action.rotateBy((PI / 2).toFloat(), 0.4)),
                    Action.removeFromParent(),
                ),
            )
        }

        fun shockwave(reachCells: Float, color: SColor) {
            val duration = maxOf(reach + T.pop, 0.35)
            for ((lag, w) in listOf(0.0 to 0.26f, 0.08 to 0.12f)) {
                val ring = ShapeNode.circle(cell * 0.5f)
                ring.position = center
                ring.z = 3f
                ring.strokeColor = color
                ring.lineWidth = cell * w
                ring.fillColor = SColor.clear
                ring.additive = true
                ring.alpha = 0f
                ring.setScale(0.3f)
                worldNode.addChild(ring)
                val grow = Action.scaleTo(reachCells * 2, duration).apply { timing = Timing.EASE_OUT }
                ring.run(
                    Action.sequence(
                        Action.wait(start + lag), Action.fadeAlpha(1f, 0.02),
                        Action.group(grow, Action.sequence(Action.wait(duration * 0.4), Action.fadeOut(duration * 0.6))), Action.removeFromParent(),
                    ),
                )
            }
            val core = ShapeNode.circle(cell * 0.6f)
            core.position = center
            core.z = 3.1f
            core.fillColor = SColor.white
            core.strokeColor = SColor.clear
            core.additive = true
            core.alpha = 0f
            worldNode.addChild(core)
            core.run(Action.sequence(Action.wait(start), Action.fadeAlpha(1f, 0.03), Action.group(Action.scaleTo(reachCells, 0.22), Action.fadeOut(0.22)), Action.removeFromParent()))
        }

        fun charge(duration: Double) {
            val orbit = Node()
            orbit.position = center
            orbit.z = 3.3f
            worldNode.addChild(orbit)
            BlockKind.entries.forEachIndexed { index, kind ->
                val angle = index * 2 * PI / BlockKind.entries.size
                val orb = SpriteNode(EffectTexture.glow, cell * 0.9f, cell * 0.9f)
                orb.color = BlockSprite.color(kind)
                orb.colorBlendFactor = 1f
                orb.additive = true
                orb.position = SPoint((cos(angle) * cell * 1.1f).toFloat(), (sin(angle) * cell * 1.1f).toFloat())
                orbit.addChild(orb)
                orb.run(Action.moveTo(SPoint.zero, duration).apply { timing = Timing.EASE_IN })
            }
            orbit.alpha = 0f
            orbit.run(Action.sequence(Action.wait(start), Action.fadeIn(0.03), Action.rotateBy((PI * 2.5).toFloat(), duration), Action.fadeOut(0.08), Action.removeFromParent()))
            val halo = light(EffectTexture.glow, SColor.white, cell * 2.4f, cell * 2.4f, center, 3.2f)
            halo.setScale(0.4f)
            halo.run(
                Action.sequence(
                    Action.wait(start), Action.fadeAlpha(0.9f, 0.03), Action.scaleTo(1.3f, duration),
                    Action.group(Action.scaleTo(2f, 0.2), Action.fadeOut(0.2)), Action.removeFromParent(),
                ),
            )
        }

        fun rays() {
            val targets = activation.cleared.filter { it != activation.origin }.sortedBy { distance(it, activation.origin) }
            val step = minOf(T.coreStep, 0.5 / maxOf(activation.cleared.size, 1))
            charge(maxOf(minOf(targets.size, 40) * step, 0.25))
            targets.take(40).forEachIndexed { order, target ->
                val end = layout.center(target)
                val color = tints[target] ?: cool
                val points = mutableListOf(center)
                val length = hypot(end.x - center.x, end.y - center.y)
                val nx = if (length > 0) -(end.y - center.y) / length else 0f
                val ny = if (length > 0) (end.x - center.x) / length else 0f
                val bends = maxOf((length / (cell * 1.2f)).toInt(), 2)
                for (bend in 1 until bends) {
                    val t = bend.toFloat() / bends
                    val sway = sin((target.column * 31 + target.row * 17 + bend * 7).toFloat()) * cell * 0.32f
                    points.add(SPoint(center.x + (end.x - center.x) * t + nx * sway, center.y + (end.y - center.y) * t + ny * sway))
                }
                points.add(end)
                val strike = start + (order + 1) * step
                for ((w, stroke, a) in listOf(Triple(0.24f, color, 0.75f), Triple(0.08f, SColor.white, 1f))) {
                    val bolt = ShapeNode(Paths.polyline(points))
                    bolt.strokeColor = stroke
                    bolt.lineWidth = maxOf(cell * w, 1.5f)
                    bolt.roundCaps = true
                    bolt.z = 3f
                    bolt.additive = true
                    bolt.alpha = 0f
                    worldNode.addChild(bolt)
                    bolt.run(
                        Action.sequence(
                            Action.wait(strike), Action.fadeAlpha(a, 0.02), Action.fadeAlpha(a * 0.4f, 0.05),
                            Action.fadeAlpha(a, 0.03), Action.fadeOut(0.18), Action.removeFromParent(),
                        ),
                    )
                }
                val impact = light(EffectTexture.glow, color, cell * 1.8f, cell * 1.8f, end, 3.1f)
                impact.setScale(0.3f)
                impact.run(Action.sequence(Action.wait(strike), Action.fadeAlpha(1f, 0.02), Action.group(Action.scaleTo(1.2f, 0.22), Action.fadeOut(0.22)), Action.removeFromParent()))
            }
        }

        fun explosion(reachCells: Float) {
            val radius = cell * reachCells
            val seed = (activation.origin.column * 53 + activation.origin.row * 97).toFloat()
            fun wobble(index: Int, scale: Float) = sin(seed + index * 2.4f) * scale
            fun blob(color: SColor, size: Float, offset: SPoint, delay: Double, life: Double, additive: Boolean, z: Float) {
                val node = ShapeNode.circle(cell * 0.5f)
                node.position = SPoint(center.x + offset.x, center.y + offset.y)
                node.z = z
                node.fillColor = color
                node.strokeColor = SColor.clear
                node.additive = additive
                node.alpha = 0f
                node.setScale(0.2f)
                worldNode.addChild(node)
                val grow = Action.scaleTo(size / (cell * 0.5f), life).apply { timing = Timing.EASE_OUT }
                node.run(
                    Action.sequence(
                        Action.wait(start + delay), Action.fadeAlpha(1f, 0.02),
                        Action.group(grow, Action.sequence(Action.wait(life * 0.35), Action.fadeOut(life * 0.65))), Action.removeFromParent(),
                    ),
                )
            }
            for (index in 0 until 7) {
                val angle = index * 0.9f + seed
                val offset = SPoint(cos(angle) * radius * 0.45f, sin(angle) * radius * 0.4f + radius * 0.15f)
                blob(SColor(0.22f, 0.2f, 0.26f, 0.75f), radius * (0.42f + abs(wobble(index, 0.12f))), offset, 0.12 + index * 0.02, 0.6, false, 2.9f)
            }
            blob(SColor(1f, 0.35f, 0.1f), radius * 1.0f, SPoint.zero, 0.0, 0.38, true, 3f)
            blob(SColor(1f, 0.7f, 0.2f), radius * 0.78f, SPoint.zero, 0.02, 0.32, true, 3.1f)
            blob(SColor.white, radius * 0.5f, SPoint.zero, 0.0, 0.22, true, 3.2f)
            for (index in 0 until 6) {
                val angle = index * 1.05f + seed * 0.7f
                val dist = radius * (0.5f + abs(wobble(index, 0.25f)))
                blob(
                    if (index % 2 == 0) SColor(1f, 0.5f, 0.12f) else warm, radius * (0.3f + abs(wobble(index + 3, 0.14f))),
                    SPoint(cos(angle) * dist, sin(angle) * dist), 0.04 + index * 0.025, 0.3, true, 3.05f,
                )
            }
            for (index in 0 until 14) {
                val angle = index * (2 * PI.toFloat() / 14) + wobble(index, 0.3f)
                val ember = SpriteNode(if (index % 3 == 0) SColor.white else warm, cell * 0.28f, cell * 0.08f)
                ember.position = center
                ember.z = 3.3f
                ember.rotation = angle
                ember.additive = true
                ember.alpha = 0f
                worldNode.addChild(ember)
                val dist = radius * (1.1f + abs(wobble(index + 5, 0.5f)))
                val life = 0.45 + abs(wobble(index, 0.15f))
                val fly = Action.moveBy(cos(angle) * dist, sin(angle) * dist, life).apply { timing = Timing.EASE_OUT }
                val drop = Action.moveBy(0f, -cell * 0.5f, life).apply { timing = Timing.EASE_IN }
                ember.run(
                    Action.sequence(
                        Action.wait(start), Action.fadeAlpha(1f, 0.01),
                        Action.group(fly, drop, Action.sequence(Action.wait(life * 0.5), Action.fadeOut(life * 0.5))), Action.removeFromParent(),
                    ),
                )
            }
            val burst = light(EffectTexture.glow, SColor(1f, 0.95f, 0.75f), radius * 3.4f, radius * 3.4f, center, 3.25f)
            burst.setScale(0.3f)
            burst.run(Action.sequence(Action.wait(start), Action.fadeAlpha(1f, 0.02), Action.group(Action.scaleTo(1f, 0.3), Action.fadeOut(0.3)), Action.removeFromParent()))
            for (index in 0 until 8) {
                val angle = index * (PI.toFloat() / 4) + seed * 0.3f
                val star = light(EffectTexture.sparkle, if (index % 2 == 0) SColor.white else warm, cell * 0.9f, cell * 0.9f, center, 3.4f)
                star.setScale(0.3f)
                val dist = radius * (0.9f + abs(wobble(index + 9, 0.5f)))
                val fly = Action.moveBy(cos(angle) * dist, sin(angle) * dist, 0.5).apply { timing = Timing.EASE_OUT }
                star.run(
                    Action.sequence(
                        Action.wait(start + 0.03), Action.fadeAlpha(1f, 0.02),
                        Action.group(fly, Action.rotateBy(PI.toFloat(), 0.5), Action.sequence(Action.scaleTo(1f, 0.18), Action.scaleTo(0f, 0.32))),
                        Action.removeFromParent(),
                    ),
                )
            }
            for ((wait, color, lw, target, dur, a) in listOf(
                Ring(0.12, warm, 0.16f, reachCells * 2.1f, 0.45, 0.8f),
                Ring(0.0, SColor(1f, 0.92f, 0.7f), 0.08f, reachCells * 2.6f, 0.4, 0.9f),
            )) {
                val ring = ShapeNode.circle(cell * 0.5f)
                ring.position = center
                ring.z = 3f
                ring.strokeColor = color
                ring.lineWidth = cell * lw
                ring.fillColor = SColor.clear
                ring.additive = true
                ring.alpha = 0f
                ring.setScale(0.3f)
                worldNode.addChild(ring)
                val widen = Action.scaleTo(target, dur).apply { timing = Timing.EASE_OUT }
                ring.run(Action.sequence(Action.wait(start + wait), Action.fadeAlpha(a, 0.02), Action.group(widen, Action.fadeOut(dur)), Action.removeFromParent()))
            }
        }

        when (val effect = activation.effect) {
            is SpecialEffect.Beam -> beam(effect.orientation, 0.7f)
            SpecialEffect.CrossBeam -> {
                beam(Orientation.HORIZONTAL, 0.7f)
                beam(Orientation.VERTICAL, 0.7f)
            }
            SpecialEffect.WideCrossBeam -> {
                beam(Orientation.HORIZONTAL, 2.6f)
                beam(Orientation.VERTICAL, 2.6f)
            }
            SpecialEffect.Bomb -> explosion(1.9f)
            SpecialEffect.BigBomb -> explosion(3.1f)
            is SpecialEffect.Core, is SpecialEffect.CoreBeam, is SpecialEffect.CoreBomb -> {
                shockwave(1.4f, cool)
                rays()
            }
            SpecialEffect.ClearBoard -> {
                shockwave(9f, cool)
                shockwave(5f, warm)
            }
        }
    }

    private data class Ring(val wait: Double, val color: SColor, val lineWidth: Float, val target: Float, val duration: Double, val alpha: Float)

    private fun addSparks(cells: Map<Position, Double>, tints: Map<Position, SColor> = emptyMap()) {
        val perCell = if (cells.size > 24) 3 else if (cells.size > 10) 5 else 7
        val cell = layout.cellSize
        for ((position, delay) in cells) {
            val center = layout.center(position)
            val tint = tints[position] ?: SColor(1f, 0.9f, 0.45f)
            val base = ((position.column * 37 + position.row * 91) % 360) * PI.toFloat() / 180
            for (index in 0 until perCell) {
                val angle = base + index * 2 * PI.toFloat() / perCell
                val side = cell * (0.26f + (index % 3) * 0.08f)
                val spark = light(EffectTexture.glow, if (index % 3 == 0) SColor.white else tint, side, side, center)
                val dist = cell * (0.9f + (index % 3) * 0.35f)
                val life = T.pop * 2
                val fly = Action.moveBy(cos(angle) * dist, sin(angle) * dist, life).apply { timing = Timing.EASE_OUT }
                val drop = Action.moveBy(0f, -cell * 0.45f, life).apply { timing = Timing.EASE_IN }
                spark.run(
                    Action.sequence(
                        Action.wait(delay), Action.fadeAlpha(1f, 0.01),
                        Action.group(fly, drop, Action.sequence(Action.wait(life * 0.4), Action.fadeOut(life * 0.6)), Action.scaleTo(0.35f, life)),
                        Action.removeFromParent(),
                    ),
                )
            }
        }
    }

    private fun knockBack(origins: List<Position>, cleared: Set<Position>) {
        if (cleared.isEmpty()) return
        val cell = layout.cellSize
        val seen = HashSet<Node>()
        for ((position, node) in blocks) {
            if (position in cleared || !seen.add(node)) continue
            if (node.name == BlockSprite.name(Block.Wall)) continue
            val gap = cleared.minOfOrNull { maxOf(abs(it.column - position.column), abs(it.row - position.row)) } ?: 9
            if (gap > 2) continue
            val home = node.position
            val origin = origins.minByOrNull { abs(it.column - position.column) + abs(it.row - position.row) } ?: position
            val from = layout.center(origin)
            var dx = home.x - from.x
            var dy = home.y - from.y
            val length = maxOf(hypot(dx, dy), 1f)
            dx /= length
            dy /= length
            val push = cell * if (gap == 1) 0.2f else 0.1f
            val out = Action.moveTo(SPoint(home.x + dx * push, home.y + dy * push), T.pop * 0.3).apply { timing = Timing.EASE_OUT }
            val back = Action.moveTo(home, T.pop * 0.55).apply { timing = Timing.EASE_IN_OUT }
            node.run(Action.group(Action.sequence(out, back), Action.sequence(Action.scaleTo(0.9f, T.pop * 0.3), Action.scaleTo(1f, T.pop * 0.55))))
        }
    }

    private fun shakeBoard(strength: Float) {
        val amplitude = 2 + strength * 0.3f
        val step = T.effect / 5
        val moves = mutableListOf<Action>()
        var ox = 0f
        var oy = 0f
        listOf(1f to 0.6f, -1f to -0.8f, 0.7f to 0.9f, -0.5f to -0.4f).forEachIndexed { index, (dirX, dirY) ->
            val fade = 1 - index * 0.2f
            val tx = dirX * amplitude * fade
            val ty = dirY * amplitude * fade
            moves.add(Action.moveBy(tx - ox, ty - oy, step))
            ox = tx
            oy = ty
        }
        moves.add(Action.moveBy(-ox, -oy, step))
        cropNode.removeAction("shake")
        cropNode.position = SPoint.zero
        cropNode.run(Action.sequence(moves), "shake")
    }

    private fun removeBlock(position: Position, scale: Float, duration: Double, delay: Double = 0.0) {
        blocks.remove(position)?.run(
            Action.sequence(Action.wait(delay), Action.group(Action.scaleTo(scale, duration), Action.fadeOut(duration)), Action.removeFromParent()),
        )
    }

    private fun move(position: Position, duration: Double, timing: Timing = Timing.EASE_OUT) =
        Action.moveTo(layout.center(position), duration).apply { this.timing = timing }

    private fun fallDuration(cells: Int) = T.fallUnit * sqrt(maxOf(cells, 1).toDouble())

    // MARK: - 자동 플레이 (개발용)

    private fun autoPlayIfNeeded() {
        if (!autoPlays || width <= 0f || isAnimating || state.status != GameStatus.PLAYING) return
        boardNode.run(Action.wait(0.25)) {
            val swap = autoMove() ?: return@run
            perform(swap)
        }
    }

    private fun autoMove(): Swap? {
        fun progress(s: GameState): Int {
            val collected = s.materialsTotal - s.materialsRemaining
            val caves = s.board.positions(s.activeRange).count { s.board[it] == null }
            return collected * 10_000 + s.materialPositions.sumOf { it.row } * 10 - s.pendingMaterials.sumOf { it.depth + 1 } * 10 + caves
        }
        var best: Pair<Swap, Int>? = null
        for (swap in state.possibleMoves()) {
            val value = progress(state.performTurn(swap).state)
            if (best == null || value > best.second) best = swap to value
        }
        return best?.first
    }

    companion object {
        const val STAR_BAR_WIDTH = 132f
        const val STAR_BAR_HEIGHT = 12f
        const val CONTAINER_SPRITE = "container"
    }
}
