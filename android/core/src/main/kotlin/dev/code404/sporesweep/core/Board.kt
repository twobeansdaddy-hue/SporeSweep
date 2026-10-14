package dev.code404.sporesweep.core

/** 블록이 놓인 격자. 빈칸은 `null`이다. Swift 판과 달리 값 타입이 아니므로 복사할 때는 `copy()`를 쓴다. */
class Board private constructor(val columns: Int, val rows: Int, private val cells: Array<Block?>) {
    constructor(columns: Int = GameConstants.COLUMNS, rows: Int = GameConstants.ACTIVE_ROWS) :
        this(columns, rows, arrayOfNulls(columns * rows)) {
        require(columns > 0 && rows > 0) { "보드 크기는 1 이상이어야 한다" }
    }

    fun copy() = Board(columns, rows, cells.copyOf())

    operator fun get(column: Int, row: Int): Block? = cells[row * columns + column]
    operator fun set(column: Int, row: Int, block: Block?) {
        cells[row * columns + column] = block
    }

    operator fun get(position: Position) = get(position.column, position.row)
    operator fun set(position: Position, block: Block?) = set(position.column, position.row, block)

    fun kind(at: Position): BlockKind? = this[at]?.kind

    fun contains(position: Position) = position.column in 0 until columns && position.row in 0 until rows

    val positions: List<Position> get() = positions(null)

    fun positions(range: RowRange?): List<Position> {
        val r = rowRange(range)
        val out = ArrayList<Position>()
        for (row in r) for (column in 0 until columns) out.add(Position(column, row))
        return out
    }

    fun rowRange(range: RowRange?): RowRange = (range ?: RowRange(0, rows)).clamped(RowRange(0, rows))

    val isFull get() = cells.none { it == null }

    fun swapAt(a: Position, b: Position) {
        val block = this[a]
        this[a] = this[b]
        this[b] = block
    }

    override fun equals(other: Any?) =
        other is Board && other.columns == columns && other.rows == rows && other.cells.contentEquals(cells)

    override fun hashCode() = cells.contentHashCode()

    // MARK: 낙하

    /** 빈칸 위의 블록을 아래로 떨어뜨린다. 큰 물질은 한 몸으로 다룬다. `pieces`의 위치는 낙하에 맞춰 바뀐다. */
    fun applyGravity(range: RowRange? = null, pieces: MutableList<MaterialPiece> = mutableListOf()): List<BlockMove> {
        val r = rowRange(range)
        // 지금 칸 → 처음 있던 칸. 움직인 블록만 들어 있다.
        val origins = HashMap<Position, Position>()
        fun shift(from: Position, to: Position) {
            this[to] = this[from]
            this[from] = null
            origins[to] = origins.remove(from) ?: from
        }

        var moved = true
        while (moved) {
            moved = false
            for (row in (r.upper - 1) downTo r.lower) {
                if (row + 1 >= r.upper) continue
                for (column in 0 until columns) {
                    val position = Position(column, row)
                    val block = this[position] ?: continue
                    if (block.isFixed) continue
                    val index = if (block == Block.Material) pieces.indexOfFirst { it.contains(position) }.takeIf { it >= 0 } else null

                    if (index != null && pieces[index].isLarge) {
                        val piece = pieces[index]
                        if (position != Position(piece.origin.column, piece.bottomRow)) continue
                        val below = piece.columns.map { Position(it, piece.bottomRow + 1) }
                        if (!below.all { this[it] == null }) continue
                        for (cell in piece.cells.reversed()) shift(cell, Position(cell.column, cell.row + 1))
                        pieces[index] = piece.copy(origin = Position(piece.origin.column, piece.origin.row + 1))
                        moved = true
                    } else {
                        val below = Position(column, row + 1)
                        if (this[below] != null) continue
                        shift(position, below)
                        if (index != null) pieces[index] = pieces[index].copy(origin = below)
                        moved = true
                    }
                }
            }
        }

        return origins.map { BlockMove(it.value, it.key) }
            .sortedWith(compareBy<BlockMove> { it.from.column }.thenBy { -it.from.row })
    }

    // MARK: 매치

    private class Run(val orientation: Orientation, val positions: List<Position>)

    /** 보드에 성립한 매치를 모두 찾는다. 한 칸을 공유하는 가로줄과 세로줄은 하나로 합친다. */
    fun findMatches(range: RowRange? = null): List<Match> {
        val runs = findRuns(rowRange(range))
        if (runs.isEmpty()) return emptyList()

        val group = IntArray(runs.size) { it }
        fun root(index: Int): Int {
            var i = index
            while (group[i] != i) i = group[i]
            return i
        }
        val firstRunAt = HashMap<Position, Int>()
        runs.forEachIndexed { index, run ->
            for (position in run.positions) {
                val other = firstRunAt[position]
                if (other != null) {
                    val a = root(index)
                    val b = root(other)
                    group[maxOf(a, b)] = minOf(a, b)
                } else {
                    firstRunAt[position] = index
                }
            }
        }

        val runsByGroup = LinkedHashMap<Int, MutableList<Run>>()
        runs.forEachIndexed { index, run -> runsByGroup.getOrPut(root(index)) { mutableListOf() }.add(run) }

        return runsByGroup.values
            .map { groupRuns ->
                val positions = groupRuns.flatMap { it.positions }.toSet()
                val (shape, crossing) = shape(groupRuns)
                Match.of(
                    kind = kind(groupRuns[0].positions[0])!!,
                    shape = shape,
                    positions = positions.toList(),
                    longestLine = groupRuns.maxOf { it.positions.size },
                    crossing = crossing,
                )
            }
            .sortedBy { it.positions[0] }
    }

    /** 주어진 칸의 블록이 3개 이상의 줄에 들어 있는지. */
    fun hasMatch(at: Position, range: RowRange? = null): Boolean {
        val r = rowRange(range)
        if (at.row !in r) return false
        val kind = kind(at) ?: return false
        fun count(dc: Int, dr: Int): Int {
            var n = 0
            var p = Position(at.column + dc, at.row + dr)
            while (contains(p) && p.row in r && kind(p) == kind) {
                n += 1
                p = Position(p.column + dc, p.row + dr)
            }
            return n
        }
        val minimum = GameConstants.MINIMUM_MATCH_LENGTH
        return count(-1, 0) + 1 + count(1, 0) >= minimum || count(0, -1) + 1 + count(0, 1) >= minimum
    }

    private fun findRuns(range: RowRange): List<Run> {
        val runs = ArrayList<Run>()
        fun scan(orientation: Orientation, line: List<Position>) {
            var start = 0
            while (start < line.size) {
                var end = start + 1
                val kind = kind(line[start])
                if (kind != null) {
                    while (end < line.size && kind(line[end]) == kind) end += 1
                    if (end - start >= GameConstants.MINIMUM_MATCH_LENGTH) runs.add(Run(orientation, line.subList(start, end).toList()))
                }
                start = end
            }
        }
        for (row in range) scan(Orientation.HORIZONTAL, (0 until columns).map { Position(it, row) })
        for (column in 0 until columns) scan(Orientation.VERTICAL, range.map { Position(column, it) })
        return runs
    }

    private fun shape(runs: List<Run>): Pair<MatchShape, Position?> {
        if (runs.size == 1) return MatchShape.Line(runs[0].orientation, runs[0].positions.size) to null
        fun isEnd(position: Position, run: Run) = position == run.positions.first() || position == run.positions.last()
        val horizontals = runs.filter { it.orientation == Orientation.HORIZONTAL }
        val verticals = runs.filter { it.orientation == Orientation.VERTICAL }
        var firstCrossing: Position? = null
        var shape: MatchShape = MatchShape.LShape
        for (horizontal in horizontals) {
            for (vertical in verticals) {
                val crossing = horizontal.positions.firstOrNull { it in vertical.positions } ?: continue
                firstCrossing = firstCrossing ?: crossing
                if (!isEnd(crossing, horizontal) || !isEnd(crossing, vertical)) shape = MatchShape.TShape
            }
        }
        return shape to firstCrossing
    }

    // MARK: 스왑

    /** 스왑을 검증한다. 유효하면 `null`이다. */
    fun rejection(swap: Swap, range: RowRange? = null): SwapRejection? {
        val r = rowRange(range)
        if (!contains(swap.from) || !contains(swap.to) || swap.from.row !in r || swap.to.row !in r) return SwapRejection.OUT_OF_BOUNDS
        if (!swap.isAdjacent) return SwapRejection.NOT_ADJACENT
        val first = this[swap.from] ?: return SwapRejection.EMPTY_CELL
        val second = this[swap.to] ?: return SwapRejection.EMPTY_CELL
        if (!first.isSwappable || !second.isSwappable) return SwapRejection.IMMOVABLE
        if (first != Block.Material && second != Block.Material) {
            if (first.isSpecial || second.isSpecial) return null
        }
        val swapped = copy()
        swapped.swapAt(swap.from, swap.to)
        if (!swapped.hasMatch(swap.from, r) && !swapped.hasMatch(swap.to, r)) return SwapRejection.NO_MATCH
        return null
    }

    fun isValid(swap: Swap, range: RowRange? = null) = rejection(swap, range) == null

    fun possibleMoves(range: RowRange? = null) = adjacentPairs(range).filter { isValid(it, range) }

    fun hasPossibleMove(range: RowRange?) = adjacentPairs(range).any { isValid(it, range) }

    private fun adjacentPairs(range: RowRange?): List<Swap> {
        val r = rowRange(range)
        return positions(r).flatMap { from ->
            listOf(Position(from.column + 1, from.row), Position(from.column, from.row + 1))
                .filter { contains(it) && it.row in r }
                .map { Swap(from, it) }
        }
    }

    /** 위에서 아래로, 왼쪽에서 오른쪽으로 채울 때 이 칸에 `kind`를 놓으면 3개 줄이 되는지. */
    internal fun completesRun(kind: BlockKind, at: Position, range: RowRange): Boolean {
        val (column, row) = at
        if (column >= 2 && kind == kind(Position(column - 1, row)) && kind == kind(Position(column - 2, row))) return true
        if (row - 2 >= range.lower && kind == kind(Position(column, row - 1)) && kind == kind(Position(column, row - 2))) return true
        return false
    }
}
