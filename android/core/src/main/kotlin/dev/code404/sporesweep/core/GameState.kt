package dev.code404.sporesweep.core

/**
 * 한 판의 상태. Swift 판의 `GameState`를 옮긴 것이다.
 *
 * Swift 판은 값 타입이라 턴마다 복사본을 만들어 고친다. 여기서는 공개 함수가 `copy()`로 복사본을 만든 뒤
 * 그 복사본만 고쳐서 돌려준다. 원래 상태는 바뀌지 않는다.
 */
class GameState private constructor(
    var board: Board,
    var blockTypes: Int,
    var generator: SeededGenerator,
    var activeTop: Int,
    var movesRemaining: Int?,
    var materials: MutableList<MaterialPiece>,
    var pendingMaterials: MutableList<PendingMaterial>,
    var blocksSlide: Boolean,
    val containerColumns: IntRange?,
    val materialsSlide: Boolean,
    var materialsTotal: Int,
    var status: GameStatus,
) {
    var score = 0
    internal var sludgeClearedThisTurn = false
    var turnsUntilNestSpit = GameConstants.NEST_SPIT_INTERVAL
    var fog: MutableSet<Position> = HashSet()
    var sticky: MutableSet<Position> = HashSet()
    var shields: MutableSet<Position> = HashSet()
    var turnsUntilVentPuff = GameConstants.NEST_SPIT_INTERVAL

    fun copy(): GameState {
        val next = GameState(
            board.copy(), blockTypes, generator.copy(), activeTop, movesRemaining,
            materials.toMutableList(), pendingMaterials.toMutableList(), blocksSlide, containerColumns, materialsSlide,
            materialsTotal, status,
        )
        next.score = score
        next.sludgeClearedThisTurn = sludgeClearedThisTurn
        next.turnsUntilNestSpit = turnsUntilNestSpit
        next.fog = HashSet(fog)
        next.sticky = HashSet(sticky)
        next.shields = HashSet(shields)
        next.turnsUntilVentPuff = turnsUntilVentPuff
        return next
    }

    val activeRange get() = RowRange(activeTop, minOf(activeTop + GameConstants.ACTIVE_ROWS, board.rows))

    val materialsRemaining get() = materials.size + pendingMaterials.size

    val materialPositions get() = board.positions.filter { board[it] == Block.Material }

    fun possibleMoves() = board.possibleMoves(activeRange).filter { !isLocked(it) }

    fun rejection(swap: Swap): SwapRejection? {
        if (status != GameStatus.PLAYING) return SwapRejection.GAME_OVER
        if (board.contains(swap.from) && board.contains(swap.to) && isLocked(swap)) return SwapRejection.IMMOVABLE
        return board.rejection(swap, activeRange)
    }

    private fun isLocked(swap: Swap): Boolean {
        if (swap.from in sticky || swap.to in sticky) return true
        return materials.any { it.isLarge && (it.contains(swap.from) || it.contains(swap.to)) }
    }

    private fun hasPossibleMove(on: Board) = on.possibleMoves(activeRange).any { !isLocked(it) }

    companion object {
        internal const val MAXIMUM_SHUFFLE_ATTEMPTS = 100
        internal const val MAXIMUM_FINAL_DETONATIONS = 8

        /** 이미 만들어진 보드로 상태를 만든다. */
        fun fromBoard(
            board: Board,
            blockTypes: Int = GameConstants.BLOCK_TYPES,
            generator: SeededGenerator,
            activeTop: Int = 0,
            movesRemaining: Int? = null,
            pendingMaterials: List<PendingMaterial> = emptyList(),
            materials: List<MaterialPiece>? = null,
            blocksSlide: Boolean = true,
            containerColumns: IntRange? = null,
            materialsSlide: Boolean = false,
        ): GameState {
            require(blockTypes in GameConstants.BLOCK_TYPE_RANGE) { "블록 종류 수가 범위를 벗어났다" }
            require(pendingMaterials.all { it.column in 0 until board.columns && it.depth >= 0 }) { "대기 물질의 열이나 깊이가 범위를 벗어났다" }
            require(containerColumns?.let { it.first >= 0 && it.last < board.columns } ?: true) { "수거함의 열이 보드 밖이다" }
            val cells = board.positions.filter { board[it] == Block.Material }
            val pieces = materials ?: cells.map { MaterialPiece(it) }
            require(pieces.flatMap { it.cells }.sorted() == cells) { "물질 덩어리가 보드의 물질 칸과 맞지 않는다" }
            return GameState(
                board, blockTypes, generator, activeTop, movesRemaining, pieces.toMutableList(),
                pendingMaterials.toMutableList(), blocksSlide, containerColumns, materialsSlide,
                pieces.size + pendingMaterials.size, GameStatus.PLAYING,
            )
        }

        /** 시드로 새 판을 만든다. 같은 시드는 항상 같은 보드를 만든다. */
        fun fromSeed(
            seed: ULong,
            columns: Int = GameConstants.COLUMNS,
            rows: Int = GameConstants.ACTIVE_ROWS,
            blockTypes: Int = GameConstants.BLOCK_TYPES,
            moves: Int? = null,
            materials: List<Position> = emptyList(),
            pendingMaterials: List<PendingMaterial> = emptyList(),
            materialPieces: List<MaterialPiece> = emptyList(),
            obstacles: List<Obstacle> = emptyList(),
            blocksSlide: Boolean = true,
            containerColumns: IntRange? = null,
            materialsSlide: Boolean = false,
        ): GameState {
            val board = Board(columns, rows)
            val pieces = materials.map { MaterialPiece(it) } + materialPieces
            for (position in pieces.flatMap { it.cells }) {
                require(board.contains(position)) { "물질의 좌표가 보드 밖이다" }
                require(board[position] == null) { "물질이 겹친다" }
                board[position] = Block.Material
            }
            val cages = ArrayList<Position>()
            val timers = LinkedHashMap<Position, Int>()
            val fog = HashSet<Position>()
            val sticky = HashSet<Position>()
            val shields = HashSet<Position>()
            val chains = ArrayList<Position>()
            val ice = ArrayList<Position>()
            for (obstacle in obstacles) {
                val p = obstacle.position
                require(board.contains(p)) { "장애물의 좌표가 보드 밖이다" }
                require(
                    board[p] == null && p !in cages && timers[p] == null && p !in fog && p !in sticky &&
                        p !in shields && p !in chains && p !in ice,
                ) { "장애물이 겹친다" }
                when (val kind = obstacle.kind) {
                    is ObstacleKind.Concrete -> {
                        require(kind.hp >= 1) { "콘크리트의 hp는 1 이상이어야 한다" }
                        board[p] = Block.Concrete(kind.hp)
                    }
                    ObstacleKind.Sludge -> board[p] = Block.Sludge
                    ObstacleKind.Wall -> board[p] = Block.Wall
                    is ObstacleKind.Cocoon -> board[p] = Block.Cocoon(kind.kind)
                    ObstacleKind.Rubble -> board[p] = Block.Rubble
                    is ObstacleKind.Nest -> {
                        require(kind.hp >= 1) { "포자 둥지의 hp는 1 이상이어야 한다" }
                        board[p] = Block.Nest(kind.hp)
                    }
                    ObstacleKind.Cage -> cages.add(p)
                    is ObstacleKind.Timer -> {
                        require(kind.turns >= 1) { "시한 포자의 턴은 1 이상이어야 한다" }
                        timers[p] = kind.turns
                    }
                    ObstacleKind.Fog -> fog.add(p)
                    ObstacleKind.Sticky -> sticky.add(p)
                    ObstacleKind.Egg -> board[p] = Block.Egg
                    ObstacleKind.Boulder -> board[p] = Block.Boulder
                    is ObstacleKind.Vent -> {
                        require(kind.hp >= 1) { "안개 굴뚝의 hp는 1 이상이어야 한다" }
                        board[p] = Block.Vent(kind.hp)
                    }
                    ObstacleKind.Shield -> shields.add(p)
                    ObstacleKind.Chain -> chains.add(p)
                    ObstacleKind.Ice -> ice.add(p)
                }
            }
            val state = fromBoard(
                board, blockTypes, SeededGenerator(seed), movesRemaining = moves, pendingMaterials = pendingMaterials,
                materials = pieces, blocksSlide = blocksSlide, containerColumns = containerColumns, materialsSlide = materialsSlide,
            )
            // 끈끈이 위의 블록은 밀 수 없으므로, 둘 곳이 있는지 볼 때부터 알고 있어야 한다.
            state.sticky = sticky
            state.generateBoard(cages, timers, chains, ice)
            state.fog = fog
            state.shields = shields
            return state
        }
    }

    // MARK: 턴 처리

    /** 스왑 한 번을 처리한다. 유효하지 않으면 상태는 그대로이고 `SwapRejected` 하나만 나온다. */
    fun performTurn(swap: Swap): TurnResult {
        rejection(swap)?.let { return TurnResult(this, listOf(GameEvent.SwapRejected(swap, it))) }
        val next = copy()
        next.sludgeClearedThisTurn = false
        next.movesRemaining?.let { next.movesRemaining = it - 1 }
        next.board.swapAt(swap.from, swap.to)
        next.followSwap(swap)
        val events = mutableListOf<GameEvent>(GameEvent.Swapped(swap))
        val effect = next.swapEffect(swap)
        if (effect != null) {
            events += next.liftingFog(next.activateSwapEffect(effect, swap))
            events += next.dropAndRefill()
            events += next.settleInPlace(null, 2, true)
        } else {
            events += next.settleInPlace(swap, 1, true)
        }
        return TurnResult(next, events)
    }

    /** 한 칸짜리 물질이 스왑으로 옮겨졌으면 위치를 따라 바꾼다. */
    private fun followSwap(swap: Swap) {
        for (index in materials.indices) {
            val piece = materials[index]
            if (piece.origin == swap.from) materials[index] = piece.copy(origin = swap.to)
            else if (piece.origin == swap.to) materials[index] = piece.copy(origin = swap.from)
        }
    }

    val canContinue get() = status == GameStatus.LOST && movesRemaining == 0

    /** 진 판을 이동 횟수를 더 받아 이어 한다. 이 상태를 직접 바꾼다. */
    fun continuePlaying(extraMoves: Int): Boolean {
        if (!canContinue || extraMoves <= 0) return false
        movesRemaining = extraMoves
        status = GameStatus.PLAYING
        return true
    }

    fun settle(): TurnResult {
        val next = copy()
        val events = next.settleInPlace(null, 1, false)
        return TurnResult(next, events)
    }

    private fun settleInPlace(swap: Swap?, firstChain: Int, isPlayerTurn: Boolean): List<GameEvent> {
        val events = mutableListOf<GameEvent>()
        var chain = firstChain
        var currentSwap = swap
        while (true) {
            events += collectMaterials()
            val matches = board.findMatches(activeRange)
            if (matches.isNotEmpty()) {
                events += liftingFog(clear(matches, chain, currentSwap))
                events += dropAndRefill()
                chain += 1
                currentSwap = null
                continue
            }
            val scroll = scrollCamera()
            if (scroll != null) {
                events.add(scroll)
                continue
            }
            break
        }
        if (materialsTotal > 0 && materialsRemaining == 0) {
            events += detonateRemainingSpecials()
            status = GameStatus.WON
            score += (movesRemaining ?: 0) * GameConstants.SCORE_PER_REMAINING_MOVE
            events.add(GameEvent.Won)
            return events
        }
        if (isPlayerTurn && !sludgeClearedThisTurn) spreadSludge()?.let { events.add(it) }
        if (isPlayerTurn) spitFromNests()?.let { events.add(it) }
        if (isPlayerTurn) puffFromVents()?.let { events.add(it) }
        if (isPlayerTurn) events += tickTimers()
        if (movesRemaining == 0) {
            status = GameStatus.LOST
            events.add(GameEvent.Lost)
        } else if (!hasPossibleMove(board)) {
            val shuffled = shuffle()
            if (shuffled != null) {
                events.add(shuffled)
            } else {
                val rescue = rescueWithBomb()
                if (rescue != null) {
                    events.add(rescue)
                } else {
                    status = GameStatus.LOST
                    events.add(GameEvent.Lost)
                }
            }
        }
        return events
    }

    private fun detonateRemainingSpecials(): List<GameEvent> {
        val events = mutableListOf<GameEvent>()
        repeat(MAXIMUM_FINAL_DETONATIONS) {
            val specials = board.positions(activeRange).filter { board[it]?.isSpecial == true }
            if (specials.isEmpty()) return events
            val removed = HashSet<Position>()
            val triggered = HashSet(specials)
            val hits = HashSet<Position>()
            val activations = resolve(
                specials.mapNotNull { p -> board[p]?.effect?.let { p to it } },
                removed, triggered, hits, emptySet(),
            )
            for (p in removed) board[p] = null
            score += removed.size * GameConstants.SCORE_PER_BLOCK
            events.add(GameEvent.SpecialsActivated(activations))
            events += damageObstacles(hits)
            events += dropAndRefill()
            var chain = 1
            while (true) {
                val matches = board.findMatches(activeRange)
                if (matches.isEmpty()) break
                events += clear(matches, chain, null)
                events += dropAndRefill()
                chain += 1
            }
        }
        return events
    }

    private fun dropAndRefill(): List<GameEvent> {
        val events = mutableListOf<GameEvent>()
        while (true) {
            val flows = slideMaterials()
            if (flows.isNotEmpty()) events.add(GameEvent.Slid(flows))
            val falls = board.applyGravity(activeRange, materials)
            if (falls.isNotEmpty()) events.add(GameEvent.Fell(falls))
            val spawns = refill()
            if (spawns.isNotEmpty()) events.add(GameEvent.Refilled(spawns))
            if (!blocksSlide) break
            val slides = slideIntoGaps()
            if (slides.isEmpty()) break
            events.add(GameEvent.Slid(slides))
        }
        return events
    }

    private fun slideIntoGaps(): List<BlockMove> {
        val range = activeRange
        val gaps = board.positions(range).reversed().filter { board[it] == null }
        val moves = mutableListOf<BlockMove>()
        for (gap in gaps) {
            if (!(gap.row - 1 >= range.lower && board[gap] == null)) continue
            val sides = if ((gap.column + gap.row) % 2 == 0) listOf(-1, 1) else listOf(1, -1)
            for (side in sides) {
                val source = Position(gap.column + side, gap.row - 1)
                if (!board.contains(source)) continue
                val block = board[source] ?: continue
                if (!block.canSlide || isUnderLargeMaterial(source)) continue
                board[gap] = block
                board[source] = null
                moves.add(BlockMove(source, gap))
                break
            }
        }
        return moves
    }

    private fun slideMaterials(): List<BlockMove> {
        if (!materialsSlide) return emptyList()
        val range = activeRange
        val moves = mutableListOf<BlockMove>()
        val order = materials.indices.filter { !materials[it].isLarge }.sortedByDescending { materials[it].origin.row }
        for (index in order) {
            val origin = materials[index].origin
            val below = Position(origin.column, origin.row + 1)
            if (origin.row !in range || below.row !in range || board[below] == null) continue
            val target = slideSides(origin.column)
                .map { Position(origin.column + it, below.row) }
                .firstOrNull { board.contains(it) && board[it] == null } ?: continue
            board[target] = Block.Material
            board[origin] = null
            materials[index] = materials[index].copy(origin = target)
            moves.add(BlockMove(origin, target))
        }
        return moves
    }

    private fun slideSides(column: Int): List<Int> {
        containerColumns?.let {
            if (column < it.first) return listOf(1, -1)
            if (column > it.last) return listOf(-1, 1)
        }
        return if (column % 2 == 0) listOf(-1, 1) else listOf(1, -1)
    }

    internal fun isUnderLargeMaterial(position: Position) =
        materials.any { it.isLarge && position.column in it.columns && it.bottomRow < position.row }

    // MARK: 물질과 카메라

    private fun collectMaterials(): List<GameEvent> {
        val events = mutableListOf<GameEvent>()
        val lastRow = board.rows - 1
        fun reachesContainer(piece: MaterialPiece): Boolean {
            if (piece.bottomRow != lastRow) return false
            val container = containerColumns ?: return true
            return piece.columns.all { it in container }
        }
        while (lastRow in activeRange) {
            val collected = materials.filter(::reachesContainer)
            if (collected.isEmpty()) break
            materials.removeAll(::reachesContainer)
            val cells = collected.flatMap { it.cells }.sorted()
            for (p in cells) board[p] = null
            events.add(GameEvent.MaterialsCollected(cells))
            events += dropAndRefill()
        }
        return events
    }

    private fun scrollCamera(): GameEvent? {
        val topmost = materials.minOfOrNull { it.origin.row } ?: return null
        val lowest = maxOf(board.rows - GameConstants.ACTIVE_ROWS, 0)
        val target = minOf(maxOf(topmost - 1, 0), lowest)
        if (target <= activeTop) return null
        for (row in activeTop until target) for (column in 0 until board.columns) board[column, row] = null
        val event = GameEvent.Scrolled(activeTop, target)
        activeTop = target
        return event
    }

    // MARK: 매치 제거와 특수 블록 생성

    private fun clear(matches: List<Match>, chain: Int, swap: Swap?): List<GameEvent> {
        val spawns = mutableListOf<SpecialSpawn>()
        for (match in matches) {
            val special = match.createdSpecial ?: continue
            val position = listOfNotNull(swap?.to, swap?.from).firstOrNull { it in match.positions } ?: match.center
            spawns.add(SpecialSpawn(position, Block.of(special)))
        }

        val removed = HashSet(matches.flatMap { it.positions })
        val triggered = HashSet<Position>()
        val queue = mutableListOf<Pair<Position, SpecialEffect>>()
        for (position in removed.sorted()) {
            val effect = board[position]?.effect ?: continue
            triggered.add(position)
            queue.add(position to effect)
        }
        val hits = HashSet<Position>()
        releaseCaged(removed, hits)
        for (match in matches) {
            for (cell in match.positions) {
                for (neighbor in neighbors(cell)) {
                    val block = board[neighbor] ?: continue
                    if (!block.takesAdjacentHits) continue
                    if (block is Block.Cocoon && block.trapped != match.kind) continue
                    hits.add(neighbor)
                }
            }
        }
        val activations = resolve(queue, removed, triggered, hits, spawns.map { it.position }.toSet())

        for (p in removed) board[p] = null
        for (spawn in spawns) board[spawn.position] = spawn.block
        score += removed.size * GameConstants.SCORE_PER_BLOCK * minOf(chain, GameConstants.MAXIMUM_CHAIN_MULTIPLIER)

        val events = mutableListOf<GameEvent>(GameEvent.MatchesCleared(matches, chain))
        if (activations.isNotEmpty()) events.add(GameEvent.SpecialsActivated(activations))
        events += damageObstacles(hits)
        if (spawns.isNotEmpty()) events.add(GameEvent.SpecialsCreated(spawns))
        return events
    }

    // MARK: 특수 블록 발동

    private fun swapEffect(swap: Swap): SpecialEffect? {
        val first = board[swap.from]?.withoutTimer ?: return null
        val second = board[swap.to]?.withoutTimer ?: return null
        return when {
            first == Block.Core && second == Block.Core -> SpecialEffect.ClearBoard
            (first == Block.Core && second is Block.Beam) || (first is Block.Beam && second == Block.Core) ->
                mostCommonKind(emptySet())?.let { SpecialEffect.CoreBeam(it) } ?: SpecialEffect.Core(null)
            (first == Block.Core && second == Block.Bomb) || (first == Block.Bomb && second == Block.Core) ->
                mostCommonKind(emptySet())?.let { SpecialEffect.CoreBomb(it) } ?: SpecialEffect.Core(null)
            first == Block.Core && second is Block.Normal -> SpecialEffect.Core(second.kind)
            first is Block.Normal && second == Block.Core -> SpecialEffect.Core(first.kind)
            first is Block.Beam && second is Block.Beam -> SpecialEffect.CrossBeam
            (first is Block.Beam && second == Block.Bomb) || (first == Block.Bomb && second is Block.Beam) -> SpecialEffect.WideCrossBeam
            first == Block.Bomb && second == Block.Bomb -> SpecialEffect.BigBomb
            first is Block.Beam && second is Block.Normal -> SpecialEffect.Beam(first.orientation)
            first is Block.Normal && second is Block.Beam -> SpecialEffect.Beam(second.orientation)
            (first == Block.Bomb && second is Block.Normal) || (first is Block.Normal && second == Block.Bomb) -> SpecialEffect.Bomb
            else -> null
        }
    }

    private fun activateSwapEffect(effect: SpecialEffect, swap: Swap): List<GameEvent> {
        val zone = board.positions(activeRange)
        val events = mutableListOf<GameEvent>()
        var removed = HashSet<Position>()
        var hits = HashSet<Position>()
        val triggered = hashSetOf(swap.from, swap.to)
        val corePosition = if (board[swap.to] == Block.Core) swap.to else swap.from
        val specialPosition = if (board[swap.to]?.isSpecial == true) swap.to else swap.from

        when (effect) {
            SpecialEffect.ClearBoard -> {
                val all = zone.filter {
                    val block = board[it]
                    block != null && it !in shields && !block.isIndestructible && !block.takesHits
                }
                removed = HashSet(all)
                hits = HashSet(zone.filter { board[it]?.takesHits == true && it !in shields })
                events.add(GameEvent.SpecialsActivated(listOf(SpecialActivation(swap.to, effect, all))))
            }
            is SpecialEffect.CoreBeam, is SpecialEffect.CoreBomb -> {
                val kind = if (effect is SpecialEffect.CoreBeam) effect.kind else (effect as SpecialEffect.CoreBomb).kind
                removed = hashSetOf(corePosition)
                events.add(GameEvent.SpecialsActivated(listOf(SpecialActivation(corePosition, effect, listOf(corePosition)))))
                val spawns = mutableListOf<SpecialSpawn>()
                for (position in zone) {
                    if (board[position] != Block.Normal(kind)) continue
                    val block: Block = if (effect is SpecialEffect.CoreBeam) {
                        Block.Beam(if ((position.column + position.row) % 2 == 0) Orientation.HORIZONTAL else Orientation.VERTICAL)
                    } else {
                        Block.Bomb
                    }
                    board[position] = block
                    spawns.add(SpecialSpawn(position, block))
                }
                if (spawns.isNotEmpty()) events.add(GameEvent.SpecialsCreated(spawns))
                val partner = if (corePosition == swap.to) swap.from else swap.to
                val queue = mutableListOf<Pair<Position, SpecialEffect>>()
                for (position in (spawns.map { it.position } + partner).sorted()) {
                    val blockEffect = board[position]?.effect ?: continue
                    triggered.add(position)
                    queue.add(position to blockEffect)
                }
                val activations = resolve(queue, removed, triggered, hits, emptySet())
                if (activations.isNotEmpty()) events.add(GameEvent.SpecialsActivated(activations))
            }
            else -> {
                val origin = when (effect) {
                    is SpecialEffect.Core -> corePosition
                    is SpecialEffect.Beam, SpecialEffect.Bomb -> specialPosition
                    else -> swap.to
                }
                val activations = resolve(listOf(origin to effect), removed, triggered, hits, emptySet())
                events.add(GameEvent.SpecialsActivated(activations))
            }
        }

        for (p in removed) board[p] = null
        score += removed.size * GameConstants.SCORE_PER_BLOCK
        events += damageObstacles(hits)
        return events
    }

    /** 효과를 차례로 적용한다. 보드는 바꾸지 않고 `removed`와 `hits`에 모은다. */
    private fun resolve(
        initial: List<Pair<Position, SpecialEffect>>,
        removed: MutableSet<Position>,
        triggered: MutableSet<Position>,
        hits: MutableSet<Position>,
        protected: Set<Position>,
    ): List<SpecialActivation> {
        val queue = initial.toMutableList()
        val activations = mutableListOf<SpecialActivation>()
        var index = 0
        while (index < queue.size) {
            val origin = queue[index].first
            var effect = queue[index].second
            index += 1
            if (effect is SpecialEffect.Core && effect.kind == null) effect = SpecialEffect.Core(mostCommonKind(removed))
            val cleared = mutableListOf<Position>()
            for (target in targets(effect, origin)) {
                if (target in protected) continue
                val block = board[target] ?: continue
                if (block.isIndestructible) continue
                if (block.takesHits) {
                    hits.add(target)
                    continue
                }
                if (removed.add(target)) cleared.add(target)
                val chained = block.effect
                if (chained != null && triggered.add(target)) queue.add(target to chained)
            }
            activations.add(SpecialActivation(origin, effect, cleared))
        }
        return activations
    }

    private fun neighbors(position: Position): List<Position> =
        listOf(0 to -1, 0 to 1, -1 to 0, 1 to 0)
            .map { Position(position.column + it.first, position.row + it.second) }
            .filter { board.contains(it) && it.row in activeRange }

    private fun releaseCaged(removed: MutableSet<Position>, hits: MutableSet<Position>) {
        for (position in removed) {
            val block = board[position]
            if (block is Block.Caged || block is Block.Chained) hits.add(position)
        }
        removed.removeAll(hits)
    }

    private fun damageObstacles(hits: Set<Position>): List<GameEvent> {
        val damaged = mutableListOf<ObstacleHit>()
        for (position in hits.sorted()) {
            when (val block = board[position]) {
                is Block.Concrete -> board[position] = if (block.hp > 1) Block.Concrete(block.hp - 1) else null
                Block.Sludge -> {
                    board[position] = null
                    sludgeClearedThisTurn = true
                }
                is Block.Nest -> board[position] = if (block.hp > 1) Block.Nest(block.hp - 1) else null
                is Block.Cocoon, Block.Rubble, Block.Egg -> board[position] = null
                is Block.Caged -> board[position] = Block.Normal(block.kind)
                is Block.Frozen -> board[position] = Block.Normal(block.trapped)
                is Block.Chained -> board[position] = Block.Caged(block.kind)
                is Block.Vent -> board[position] = if (block.hp > 1) Block.Vent(block.hp - 1) else null
                Block.Boulder -> board[position] = null
                else -> continue
            }
            damaged.add(ObstacleHit(position, board[position]))
        }
        return if (damaged.isEmpty()) emptyList() else listOf(GameEvent.ObstaclesDamaged(damaged))
    }

    private fun spreadSludge(): GameEvent? {
        val zone = board.positions(activeRange)
        if (zone.count { board[it] == Block.Sludge } >= GameConstants.SLUDGE_SPREAD_LIMIT) return null
        val targets = HashSet<Position>()
        for (position in zone) {
            if (board[position] != Block.Sludge) continue
            for (neighbor in neighbors(position)) if (board[neighbor] is Block.Normal) targets.add(neighbor)
        }
        if (targets.isEmpty()) return null
        val target = targets.sorted()[generator.nextInt(targets.size)]
        board[target] = Block.Sludge
        return GameEvent.SludgeSpread(listOf(target))
    }

    private fun spitFromNests(): GameEvent? {
        val nests = board.positions(activeRange).filter { board[it] is Block.Nest }
        if (nests.isEmpty()) {
            turnsUntilNestSpit = GameConstants.NEST_SPIT_INTERVAL
            return null
        }
        turnsUntilNestSpit -= 1
        if (turnsUntilNestSpit > 0) return null
        turnsUntilNestSpit = GameConstants.NEST_SPIT_INTERVAL
        val spits = mutableListOf<NestSpit>()
        for (nest in nests.sorted()) {
            val targets = neighbors(nest).filter { board[it] is Block.Normal }.sorted()
            if (targets.isEmpty()) continue
            val target = targets[generator.nextInt(targets.size)]
            board[target] = Block.Sludge
            spits.add(NestSpit(nest, target))
        }
        return if (spits.isEmpty()) null else GameEvent.NestsSpat(spits)
    }

    private fun liftingFog(events: List<GameEvent>): List<GameEvent> {
        if (fog.isEmpty() && sticky.isEmpty() && shields.isEmpty()) return events
        val touched = HashSet<Position>()
        val matched = HashSet<Position>()
        val struck = HashSet<Position>()
        for (event in events) {
            when (event) {
                is GameEvent.MatchesCleared -> for (cell in event.matches.flatMap { it.positions }) {
                    struck.add(cell)
                    matched.add(cell)
                    touched.add(cell)
                    touched.addAll(neighbors(cell))
                }
                is GameEvent.SpecialsActivated -> for (activation in event.activations) {
                    touched.add(activation.origin)
                    touched.addAll(activation.cleared)
                    struck.add(activation.origin)
                    struck.addAll(activation.cleared)
                }
                is GameEvent.ObstaclesDamaged -> {
                    touched.addAll(event.hits.map { it.position })
                    struck.addAll(event.hits.map { it.position })
                }
                else -> {}
            }
        }
        val out = events.toMutableList()
        val lifted = fog.intersect(touched).sorted()
        if (lifted.isNotEmpty()) {
            fog.removeAll(lifted.toSet())
            out.add(GameEvent.FogLifted(lifted))
        }
        val cleaned = sticky.intersect(struck).sorted()
        if (cleaned.isNotEmpty()) {
            sticky.removeAll(cleaned.toSet())
            out.add(GameEvent.StickyCleared(cleaned))
        }
        val broken = shields.intersect(matched).sorted()
        if (broken.isNotEmpty()) {
            shields.removeAll(broken.toSet())
            out.add(GameEvent.ShieldsBroken(broken))
        }
        return out
    }

    private fun puffFromVents(): GameEvent? {
        val vents = board.positions(activeRange).filter { board[it] is Block.Vent }
        if (vents.isEmpty()) {
            turnsUntilVentPuff = GameConstants.NEST_SPIT_INTERVAL
            return null
        }
        turnsUntilVentPuff -= 1
        if (turnsUntilVentPuff > 0) return null
        turnsUntilVentPuff = GameConstants.NEST_SPIT_INTERVAL
        val puffed = mutableListOf<Position>()
        for (vent in vents.sorted()) {
            val targets = neighbors(vent).filter { it !in fog && board[it] != Block.Wall }.sorted()
            if (targets.isEmpty()) continue
            val target = targets[generator.nextInt(targets.size)]
            fog.add(target)
            puffed.add(target)
        }
        return if (puffed.isEmpty()) null else GameEvent.VentsPuffed(puffed)
    }

    private fun tickTimers(): List<GameEvent> {
        val ticks = mutableListOf<TimerTick>()
        val expired = mutableListOf<Position>()
        for (position in board.positions(activeRange).sorted()) {
            val block = board[position] as? Block.Timed ?: continue
            if (block.turns > 1) {
                board[position] = Block.Timed(block.kind, block.turns - 1)
                ticks.add(TimerTick(position, block.turns - 1))
            } else {
                expired.add(position)
            }
        }
        val bursts = mutableListOf<TimerBurst>()
        for (position in expired) {
            val sludge = mutableListOf(position)
            board[position] = Block.Sludge
            for (neighbor in neighbors(position).sorted()) {
                if (board[neighbor] is Block.Normal) {
                    board[neighbor] = Block.Sludge
                    sludge.add(neighbor)
                }
            }
            bursts.add(TimerBurst(position, sludge))
        }
        val events = mutableListOf<GameEvent>()
        if (ticks.isNotEmpty()) events.add(GameEvent.TimersTicked(ticks))
        if (bursts.isNotEmpty()) events.add(GameEvent.TimersBurst(bursts))
        return events
    }

    private fun targets(effect: SpecialEffect, origin: Position) =
        rawTargets(effect, origin).filter { it !in shields || it == origin }

    private fun rawTargets(effect: SpecialEffect, origin: Position): List<Position> {
        val zone = board.positions(activeRange)
        fun around(reach: Int) = zone.filter {
            it.column in (origin.column - reach)..(origin.column + reach) && it.row in (origin.row - reach)..(origin.row + reach)
        }
        fun cross(thickness: Int): List<Position> {
            val reach = thickness / 2
            return zone.filter { Math.abs(it.column - origin.column) <= reach || Math.abs(it.row - origin.row) <= reach }
        }
        return when (effect) {
            is SpecialEffect.Beam -> if (effect.orientation == Orientation.HORIZONTAL) zone.filter { it.row == origin.row } else zone.filter { it.column == origin.column }
            SpecialEffect.Bomb -> around(1)
            is SpecialEffect.Core -> zone.filter { it == origin || (effect.kind != null && board.kind(it) == effect.kind) }
            SpecialEffect.CrossBeam -> cross(1)
            SpecialEffect.WideCrossBeam -> cross(3)
            SpecialEffect.BigBomb -> around(2)
            is SpecialEffect.CoreBeam, is SpecialEffect.CoreBomb -> listOf(origin)
            SpecialEffect.ClearBoard -> zone
        }
    }

    /** 가장 많이 남은 종류. 수가 같으면 순서가 앞선 쪽이다. */
    private fun mostCommonKind(removed: Set<Position>): BlockKind? {
        val counts = HashMap<BlockKind, Int>()
        for (position in board.positions(activeRange)) {
            if (position in removed) continue
            val kind = board.kind(position) ?: continue
            counts[kind] = (counts[kind] ?: 0) + 1
        }
        return counts.entries.maxWithOrNull(compareBy<Map.Entry<BlockKind, Int>> { it.value }.thenBy { -it.key.ordinal })?.key
    }

    // MARK: 보충

    private fun refill(): List<Spawn> {
        val spawns = mutableListOf<Spawn>()
        for (column in 0 until board.columns) {
            val open = activeRange.takeWhile { board[column, it] == null }
            for (row in open.reversed()) {
                val position = Position(column, row)
                val index = pendingMaterials.indexOfFirst { it.column == column && it.depth == 0 }
                if (index >= 0) {
                    pendingMaterials.removeAt(index)
                    board[position] = Block.Material
                    materials.add(MaterialPiece(position))
                } else {
                    board[position] = Block.Normal(BlockKind.entries[generator.nextInt(blockTypes)])
                    for (i in pendingMaterials.indices) {
                        if (pendingMaterials[i].column == column) pendingMaterials[i] = pendingMaterials[i].copy(depth = pendingMaterials[i].depth - 1)
                    }
                }
                spawns.add(Spawn(position, board[position]!!))
            }
        }
        return spawns
    }

    // MARK: 아이템

    fun canHammer(position: Position): Boolean {
        if (status != GameStatus.PLAYING || !board.contains(position) || position.row !in activeRange) return false
        val block = board[position] ?: return false
        return !block.isIndestructible
    }

    /** 정화 망치를 쓴다. 쓸 수 없는 칸이면 `null`이다. */
    fun hammering(position: Position): TurnResult? {
        if (!canHammer(position)) return null
        val block = board[position] ?: return null
        val next = copy()
        val events = mutableListOf<GameEvent>()
        if (block.takesHits) {
            events += next.damageObstacles(setOf(position))
        } else {
            next.board[position] = null
            next.score += GameConstants.SCORE_PER_BLOCK
            events.add(GameEvent.Hammered(position))
        }
        if (next.fog.remove(position)) events.add(GameEvent.FogLifted(listOf(position)))
        if (next.sticky.remove(position)) events.add(GameEvent.StickyCleared(listOf(position)))
        if (next.shields.remove(position)) events.add(GameEvent.ShieldsBroken(listOf(position)))
        events += next.dropAndRefill()
        events += next.settleInPlace(null, 1, false)
        return TurnResult(next, events)
    }

    fun canFreeSwap(swap: Swap): Boolean {
        if (status != GameStatus.PLAYING) return false
        val rejection = rejection(swap) ?: return true
        return rejection == SwapRejection.NO_MATCH
    }

    fun freeSwapping(swap: Swap): TurnResult? {
        if (!canFreeSwap(swap)) return null
        val next = copy()
        next.board.swapAt(swap.from, swap.to)
        next.followSwap(swap)
        val events = mutableListOf<GameEvent>(GameEvent.Swapped(swap))
        val effect = next.swapEffect(swap)
        if (effect != null) {
            events += next.liftingFog(next.activateSwapEffect(effect, swap))
            events += next.dropAndRefill()
            events += next.settleInPlace(null, 2, false)
        } else {
            events += next.settleInPlace(swap, 1, false)
        }
        return TurnResult(next, events)
    }

    fun shuffling(): TurnResult? {
        if (status != GameStatus.PLAYING) return null
        val next = copy()
        val shuffled = next.shuffle() ?: return null
        return TurnResult(next, listOf(shuffled))
    }

    private fun rescueWithBomb(): GameEvent? {
        val candidates = board.positions(activeRange).filter { position ->
            if (board[position] !is Block.Normal) return@filter false
            val trial = board.copy()
            trial[position] = Block.Bomb
            trial.possibleMoves(activeRange).any { !isLocked(it) && (it.from == position || it.to == position) }
        }.sorted()
        if (candidates.isEmpty()) return null
        val position = candidates[generator.nextInt(candidates.size)]
        board[position] = Block.Bomb
        return GameEvent.SpecialsCreated(listOf(SpecialSpawn(position, Block.Bomb)))
    }

    // MARK: 셔플

    private fun shuffle(): GameEvent? {
        val range = activeRange
        val normals = board.positions(range).filter { board[it] is Block.Normal }
        repeat(MAXIMUM_SHUFFLE_ATTEMPTS) {
            val pool = normals.toMutableList()
            for (i in pool.size - 1 downTo 1) {
                val j = generator.nextInt(i + 1)
                val t = pool[i]
                pool[i] = pool[j]
                pool[j] = t
            }
            val candidate = board.copy()
            for (target in normals) candidate[target] = null
            val moves = mutableListOf<BlockMove>()
            for (target in normals) {
                val index = pool.indexOfFirst { !candidate.completesRun(board.kind(it)!!, target, range) }
                if (index < 0) break
                val source = pool.removeAt(index)
                candidate[target] = board[source]
                if (source != target) moves.add(BlockMove(source, target))
            }
            if (pool.isEmpty() && candidate.findMatches(range).isEmpty() && hasPossibleMove(candidate)) {
                board = candidate
                return GameEvent.Shuffled(moves)
            }
        }
        val savedBoard = board.copy()
        val savedGenerator = generator.copy()
        repeat(MAXIMUM_SHUFFLE_ATTEMPTS) {
            fill(normals, range)
            if (board.findMatches(range).isEmpty() && hasPossibleMove(board)) {
                return GameEvent.Regenerated(normals.map { Spawn(it, Block.Normal(board.kind(it)!!)) })
            }
        }
        board = savedBoard
        generator = savedGenerator
        return null
    }

    // MARK: 보드 생성

    private fun generateBoard(cages: List<Position>, timers: Map<Position, Int>, chains: List<Position>, ice: List<Position>) {
        val short = minOf(board.columns, board.rows)
        val long = maxOf(board.columns, board.rows)
        require(long >= 4 || (long >= 3 && short >= 2)) { "가능한 이동이 있을 수 없는 보드 크기다" }
        val cells = board.positions.filter { board[it] == null }
        do {
            fill(cells, RowRange(0, board.rows))
            for (p in cages) board[p] = Block.Caged(board.kind(p)!!)
            for ((p, turns) in timers) board[p] = Block.Timed(board.kind(p)!!, turns)
            for (p in chains) board[p] = Block.Chained(board.kind(p)!!)
            for (p in ice) board[p] = Block.Frozen(board.kind(p)!!)
        } while (!hasPossibleMove(board))
    }

    private fun fill(cells: List<Position>, range: RowRange) {
        for (p in cells) board[p] = null
        val kinds = BlockKind.entries.take(blockTypes)
        for (p in cells) {
            val candidates = kinds.filter { !board.completesRun(it, p, range) }
            board[p] = Block.Normal(candidates[generator.nextInt(candidates.size)])
        }
    }

    // MARK: 시작 부스터

    /** 고른 부스터를 판에 적용한다. 판을 시작하기 전에 한 번만 부른다. 이 상태를 직접 바꾼다. */
    fun apply(boosters: List<Booster>): List<Position> {
        val placed = mutableListOf<Position>()
        for (booster in boosters.sortedBy { it.id }) {
            if (booster == Booster.EXTRA_MOVES) {
                movesRemaining?.let { movesRemaining = it + Booster.EXTRA_MOVE_COUNT }
                continue
            }
            val candidates = board.positions(activeRange).filter { board[it] is Block.Normal }
            if (candidates.isEmpty()) continue
            val position = candidates[generator.nextInt(candidates.size)]
            board[position] = when (booster) {
                Booster.BEAM -> Block.Beam(if (generator.nextInt(2) == 0) Orientation.HORIZONTAL else Orientation.VERTICAL)
                Booster.BOMB -> Block.Bomb
                else -> Block.Core
            }
            placed.add(position)
        }
        return placed
    }
}
