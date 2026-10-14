package dev.code404.sporesweep.core

// iOS 판의 GameCore(Swift)를 옮긴 것이다. 규칙이 한 글자라도 다르면 parity 시험이 실패한다.
// 규칙을 고칠 때는 Swift 쪽을 먼저 고치고, paritygen으로 기준 기록을 다시 만든 뒤 여기를 맞춘다.

/** DESIGN.md 3장의 보드 규격. */
object GameConstants {
    const val COLUMNS = 8
    const val ACTIVE_ROWS = 10
    const val BLOCK_TYPES = 5
    val BLOCK_TYPE_RANGE = 4..6
    const val MINIMUM_MATCH_LENGTH = 3
    const val SCORE_PER_BLOCK = 10
    const val MAXIMUM_CHAIN_MULTIPLIER = 3
    const val SCORE_PER_REMAINING_MOVE = 100
    const val NEST_SPIT_INTERVAL = 3
    const val SLUDGE_SPREAD_LIMIT = 12
}

/** 시드로 초기화하는 난수 생성기(SplitMix64). Swift 판과 같은 수열을 낸다. */
class SeededGenerator(private var state: ULong) {
    fun copy() = SeededGenerator(state)

    fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }

    /** `0 until bound`에서 균등하게 하나를 뽑는다. */
    fun nextInt(bound: Int): Int {
        require(bound > 0) { "bound는 1 이상이어야 한다" }
        val upper = bound.toULong()
        val limit = ULong.MAX_VALUE - ULong.MAX_VALUE % upper
        var value = next()
        while (value >= limit) value = next()
        return (value % upper).toInt()
    }

    override fun equals(other: Any?) = other is SeededGenerator && other.state == state
    override fun hashCode() = state.hashCode()
}

/** 반열린 행 범위 `lower until upper`. Swift의 `Range<Int>`에 해당한다. */
data class RowRange(val lower: Int, val upper: Int) : Iterable<Int> {
    val isEmpty get() = upper <= lower
    operator fun contains(row: Int) = row >= lower && row < upper
    override fun iterator() = (lower until upper).iterator()
    fun clamped(to: RowRange) = RowRange(lower.coerceIn(to.lower, to.upper), upper.coerceIn(to.lower, to.upper))
}

/** 일반 블록의 종류. `ordinal`이 Swift의 `rawValue`다. */
enum class BlockKind(val id: String) {
    BRICK("brick"), SCRAP("scrap"), GLASS("glass"), WOOD("wood"), PLASTIC("plastic"), SOIL("soil");

    companion object {
        fun byName(name: String) = entries.firstOrNull { it.id == name }
    }
}

enum class Orientation { HORIZONTAL, VERTICAL }

/** 특수 블록의 종류(4장). */
sealed interface Special {
    data class Beam(val orientation: Orientation) : Special
    data object Bomb : Special
    data object Core : Special
}

/** 보드 한 칸에 놓이는 블록. 각 경우의 뜻은 Swift 판 `Block`의 주석에 있다. */
sealed interface Block {
    data class Normal(override val kind: BlockKind) : Block
    data class Beam(val orientation: Orientation) : Block
    data object Bomb : Block
    data object Core : Block
    data object Material : Block
    data class Concrete(val hp: Int) : Block
    data class Caged(override val kind: BlockKind) : Block
    data object Sludge : Block
    data object Wall : Block
    /** `trapped`는 고치에 갇힌 블록의 종류다. 고치 자체는 종류가 없어 매치에 들지 않는다. */
    data class Cocoon(val trapped: BlockKind) : Block
    data object Rubble : Block
    data class Nest(val hp: Int) : Block
    data class Timed(override val kind: BlockKind, val turns: Int) : Block
    data object Egg : Block
    data class Chained(override val kind: BlockKind) : Block
    data object Boulder : Block
    data class Vent(val hp: Int) : Block
    /** `trapped`는 얼어붙은 블록의 종류다. 얼음은 종류가 없어 매치에 들지 않는다. */
    data class Frozen(val trapped: BlockKind) : Block

    /** 매치에 쓰이는 종류. 일반 블록, 철망, 시한 포자, 쇠사슬만 있다. */
    val kind: BlockKind? get() = null

    val special: Special?
        get() = when (this) {
            is Beam -> Special.Beam(orientation)
            Bomb -> Special.Bomb
            Core -> Special.Core
            else -> null
        }

    val isSpecial get() = special != null

    /** 제자리에 고정된 칸인지. 떨어지지 않는다. */
    val isFixed: Boolean
        get() = when (this) {
            is Concrete, Sludge, Wall, is Cocoon, is Nest, Egg, is Vent, is Frozen -> true
            else -> false
        }

    val isSwappable: Boolean
        get() = when (this) {
            is Concrete, is Caged, Sludge, Wall, is Cocoon, Rubble, is Nest, Egg, is Chained, Boulder, is Vent, is Frozen -> false
            else -> true
        }

    val canSlide: Boolean
        get() = when (this) {
            is Normal, is Beam, Bomb, Core, is Timed -> true
            else -> false
        }

    /** 옆에서 매치하면 피해를 입는 장애물인지. */
    val takesAdjacentHits get() = (isFixed && this != Egg) || this == Rubble

    val withoutTimer: Block get() = if (this is Timed) Normal(kind) else this

    val isIndestructible get() = this == Material || this == Wall

    /** 이 블록이 매치에 들거나 다른 효과에 맞았을 때 내는 효과. */
    val effect: SpecialEffect?
        get() = when (this) {
            is Beam -> SpecialEffect.Beam(orientation)
            Bomb -> SpecialEffect.Bomb
            Core -> SpecialEffect.Core(null)
            else -> null
        }

    /** 매치나 효과에 바로 지워지지 않고 피해를 한 번 입는 블록인지. */
    val takesHits: Boolean
        get() {
            if (this is Caged || this is Chained) return true
            return (isFixed && this != Wall) || this == Rubble || this == Boulder
        }

    companion object {
        fun of(special: Special): Block = when (special) {
            is Special.Beam -> Beam(special.orientation)
            Special.Bomb -> Bomb
            Special.Core -> Core
        }
    }
}

/** 보드의 한 칸. 행 0이 맨 위다. 위에서 아래로, 같은 행에서는 왼쪽에서 오른쪽으로 정렬한다. */
data class Position(val column: Int, val row: Int) : Comparable<Position> {
    override fun compareTo(other: Position) =
        if (row != other.row) row.compareTo(other.row) else column.compareTo(other.column)
}

data class Swap(val from: Position, val to: Position) {
    val isAdjacent get() = Math.abs(from.column - to.column) + Math.abs(from.row - to.row) == 1
}

data class BlockMove(val from: Position, val to: Position)

/** 보드에 나와 있는 오염 물질 한 덩어리. */
data class MaterialPiece(val origin: Position, val width: Int = 1, val height: Int = 1) {
    init {
        require(width >= 1 && height >= 1) { "물질의 크기는 1 이상이어야 한다" }
    }

    val columns get() = origin.column until origin.column + width
    val rows get() = origin.row until origin.row + height
    val bottomRow get() = origin.row + height - 1
    val isLarge get() = width * height > 1
    val cells get() = rows.flatMap { row -> columns.map { Position(it, row) } }
    fun contains(position: Position) = position.column in columns && position.row in rows
}

data class PendingMaterial(val column: Int, val depth: Int)

enum class Tool { HAMMER, SWAP, SHUFFLE }

/** 시작 부스터(6장). `id`가 Swift의 `rawValue`다. */
enum class Booster(val id: String) {
    BEAM("beam"), BOMB("bomb"), CORE("core"), EXTRA_MOVES("extraMoves");

    companion object {
        const val EXTRA_MOVE_COUNT = 5
        fun byName(name: String) = entries.firstOrNull { it.id == name }
    }
}

/** 레벨에 놓는 장애물의 종류(7장). */
sealed interface ObstacleKind {
    data class Concrete(val hp: Int) : ObstacleKind
    data object Cage : ObstacleKind
    data object Sludge : ObstacleKind
    data object Wall : ObstacleKind
    data class Cocoon(val kind: BlockKind) : ObstacleKind
    data object Rubble : ObstacleKind
    data class Nest(val hp: Int) : ObstacleKind
    data class Timer(val turns: Int) : ObstacleKind
    data object Fog : ObstacleKind
    data object Sticky : ObstacleKind
    data object Egg : ObstacleKind
    data object Chain : ObstacleKind
    data object Shield : ObstacleKind
    data object Boulder : ObstacleKind
    data class Vent(val hp: Int) : ObstacleKind
    data object Ice : ObstacleKind
}

data class Obstacle(val kind: ObstacleKind, val position: Position)
