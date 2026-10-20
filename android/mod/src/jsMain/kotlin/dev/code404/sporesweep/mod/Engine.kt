package dev.code404.sporesweep.mod

import dev.code404.sporesweep.core.Block
import dev.code404.sporesweep.core.GameEvent
import dev.code404.sporesweep.core.GameState
import dev.code404.sporesweep.core.GameStatus
import dev.code404.sporesweep.core.Level
import dev.code404.sporesweep.core.Orientation
import dev.code404.sporesweep.core.Position
import dev.code404.sporesweep.core.SpecialEffect
import dev.code404.sporesweep.core.Swap

// Claude Code의 mods가 부르는 규칙 엔진. 규칙은 iOS·안드로이드·웹과 같은 :core 그대로다.
// 자바스크립트에서 다루기 쉽게 보드는 칸마다 짧은 글자 코드로, 턴의 결과는 몇 가지 숫자로 넘긴다.

/** 한 판. 레벨 JSON과 시작 시드로 만든다. */
@JsExport
class SporeGame(levelJson: String, seed: Double) {
    private val level = Level.parse(levelJson)
    private var state: GameState = level.makeState(if (seed > 0) seed.toLong().toULong() else level.seed)

    val levelId: String get() = level.id
    val city: String get() = level.city
    val tutorial: String? get() = level.tutorial
    val columns: Int get() = state.board.columns
    val rows: Int get() = state.board.rows
    /** 화면에 보이는 맨 위 행. 활성 구간은 여기서부터 10행이다. */
    val activeTop: Int get() = state.activeTop
    val activeRows: Int get() = state.activeRange.upper - state.activeRange.lower
    val moves: Int get() = state.movesRemaining ?: 0
    val score: Int get() = state.score
    val materialsLeft: Int get() = state.materialsRemaining
    val materialsTotal: Int get() = state.materialsTotal
    /** `playing`, `won`, `lost`. */
    val status: String get() = state.status.name.lowercase()
    val starScores: Array<Int> get() = level.starScores.toTypedArray()

    /** 판이 끝났을 때의 별 수. 이기지 못했으면 0이다. */
    fun stars(): Int = if (state.status == GameStatus.WON) level.stars(state.score) else 0

    /**
     * 활성 구간의 칸을 위 행부터 차례로 짧은 코드로 준다. 안개가 덮은 칸은 `?`다.
     * 코드: `.` 빈칸, `0`~`5` 일반 블록, `H`/`V` 빔, `X` 폭탄, `C` 코어, `D` 드론, `M` 물질, `W` 벽,
     * `K1`/`K2` 콘크리트, `G0` 철망에 갇힌 블록, `S` 슬러지, `O0` 고치, `R` 잔해, `N` 둥지, `T0` 시한 포자,
     * `E` 알, `L0` 쇠사슬, `U` 운석, `F` 굴뚝, `I0` 얼음.
     */
    fun cells(): Array<String> {
        val range = state.activeRange
        val out = ArrayList<String>()
        for (row in range.lower until range.upper) {
            for (column in 0 until state.board.columns) {
                val position = Position(column, row)
                out.add(if (position in state.fog) "?" else code(state.board[position]))
            }
        }
        return out.toTypedArray()
    }

    /** 끈끈이와 보호막이 깔린 칸(활성 구간 기준 번호). */
    fun marks(): Array<String> {
        val range = state.activeRange
        val out = ArrayList<String>()
        for (row in range.lower until range.upper) {
            for (column in 0 until state.board.columns) {
                val position = Position(column, row)
                out.add(
                    when {
                        position in state.shields -> "shield"
                        position in state.sticky -> "sticky"
                        else -> ""
                    },
                )
            }
        }
        return out.toTypedArray()
    }

    /**
     * 활성 구간의 칸 (column, row)에서 옆 칸으로 민다. `row`는 활성 구간 안의 번호(0부터)다.
     * 받아들이지 않으면 거절 이유를, 받아들이면 `ok`를 돌려준다.
     */
    fun swap(column: Int, row: Int, toColumn: Int, toRow: Int): String {
        val swap = Swap(Position(column, state.activeTop + row), Position(toColumn, state.activeTop + toRow))
        state.rejection(swap)?.let { return it.name.lowercase() }
        val result = state.performTurn(swap)
        state = result.state
        last = summarize(result.events)
        return "ok"
    }

    /** 마지막 턴에 일어난 일을 사람이 읽을 짧은 글로. 화면 아래 한 줄에 쓴다. */
    var last: String = ""
        private set

    /** 둘 수 있는 수 하나(활성 구간 기준 [열, 행, 열, 행]). 없으면 빈 배열이다. */
    fun hint(): Array<Int> {
        val move = state.possibleMoves().firstOrNull() ?: return emptyArray()
        return arrayOf(move.from.column, move.from.row - state.activeTop, move.to.column, move.to.row - state.activeTop)
    }

    private fun summarize(events: List<GameEvent>): String {
        val parts = ArrayList<String>()
        var chain = 0
        var drones = 0
        var specials = 0
        var collected = 0
        for (event in events) {
            when (event) {
                is GameEvent.MatchesCleared -> chain = maxOf(chain, event.chain)
                is GameEvent.SpecialsActivated -> for (activation in event.activations) {
                    specials += 1
                    when (activation.effect) {
                        is SpecialEffect.Drone, is SpecialEffect.DroneSwarm, is SpecialEffect.DroneBeam, is SpecialEffect.DroneBomb -> drones += 1
                        else -> {}
                    }
                }
                is GameEvent.MaterialsCollected -> collected += event.positions.size
                else -> {}
            }
        }
        if (chain >= 2) parts.add("연쇄 $chain")
        if (drones > 0) parts.add("드론 출동 ${drones}번")
        else if (specials > 0) parts.add("특수 효과 ${specials}번")
        if (collected > 0) parts.add("물질 ${collected}개 수거!")
        return parts.joinToString(" · ")
    }

    companion object {
        fun code(block: Block?): String = when (block) {
            null -> "."
            is Block.Normal -> block.kind.ordinal.toString()
            is Block.Beam -> if (block.orientation == Orientation.HORIZONTAL) "H" else "V"
            Block.Bomb -> "X"
            Block.Core -> "C"
            Block.Drone -> "D"
            Block.Material -> "M"
            Block.Wall -> "W"
            is Block.Concrete -> "K${block.hp}"
            is Block.Caged -> "G${block.kind.ordinal}"
            Block.Sludge -> "S"
            is Block.Cocoon -> "O${block.trapped.ordinal}"
            Block.Rubble -> "R"
            is Block.Nest -> "N"
            is Block.Timed -> "T${block.kind.ordinal}"
            Block.Egg -> "E"
            is Block.Chained -> "L${block.kind.ordinal}"
            Block.Boulder -> "U"
            is Block.Vent -> "F"
            is Block.Frozen -> "I${block.trapped.ordinal}"
        }
    }
}
