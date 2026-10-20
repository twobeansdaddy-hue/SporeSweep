package dev.code404.sporesweep.core

/** 매치의 모양. */
sealed interface MatchShape {
    data class Line(val orientation: Orientation, val length: Int) : MatchShape
    data object LShape : MatchShape
    data object TShape : MatchShape
    /** 줄 없이 2×2 정사각형만으로 된 매치. */
    data object Square : MatchShape
}

/** 한 번에 제거되는 같은 종류 블록의 묶음. `positions`는 정렬돼 있다. */
data class Match(
    val kind: BlockKind,
    val shape: MatchShape,
    val positions: List<Position>,
    val longestLine: Int,
    val crossing: Position?,
    /** 2×2 정사각형을 품었는지. 줄이 만드는 특수 블록이 없으면 청소 드론을 남긴다(4장). */
    val hasSquare: Boolean = shape == MatchShape.Square,
) {
    /** 이 매치가 만드는 특수 블록(4장). */
    val createdSpecial: Special?
        get() {
            if (longestLine >= 5) return Special.Core
            return when {
                shape == MatchShape.LShape || shape == MatchShape.TShape -> Special.Bomb
                shape is MatchShape.Line && shape.length == 4 -> Special.Beam(shape.orientation)
                hasSquare -> Special.Drone
                else -> null
            }
        }

    val center get() = crossing ?: positions[(positions.size - 1) / 2]

    companion object {
        fun of(
            kind: BlockKind, shape: MatchShape, positions: List<Position>, longestLine: Int? = null, crossing: Position? = null,
            hasSquare: Boolean? = null,
        ) =
            Match(
                kind, shape, positions.sorted(),
                longestLine ?: when (shape) {
                    is MatchShape.Line -> shape.length
                    MatchShape.Square -> 2
                    else -> GameConstants.MINIMUM_MATCH_LENGTH
                },
                crossing,
                hasSquare ?: (shape == MatchShape.Square),
            )
    }
}

data class Spawn(val position: Position, val block: Block)

sealed interface SpecialEffect {
    data class Beam(val orientation: Orientation) : SpecialEffect
    data object Bomb : SpecialEffect
    data class Core(val kind: BlockKind?) : SpecialEffect
    data object CrossBeam : SpecialEffect
    data object WideCrossBeam : SpecialEffect
    data object BigBomb : SpecialEffect
    data class CoreBeam(val kind: BlockKind) : SpecialEffect
    data class CoreBomb(val kind: BlockKind) : SpecialEffect
    data object ClearBoard : SpecialEffect
    /** 청소 드론: 제자리와 상하좌우, 그리고 날아가 맞히는 목표 칸. 발동할 때 목표를 정한다(4장). */
    data class Drone(val target: Position?) : SpecialEffect
    /** 청소 드론 + 청소 드론: 서로 다른 목표 셋. */
    data class DroneSwarm(val targets: List<Position>) : SpecialEffect
    /** 청소 드론 + 제염 빔: 목표 칸을 지나는 그 방향의 줄. */
    data class DroneBeam(val orientation: Orientation, val target: Position?) : SpecialEffect
    /** 청소 드론 + 중화 폭탄: 목표 칸 둘레 3×3. */
    data class DroneBomb(val target: Position?) : SpecialEffect
    /** 정화 코어 + 청소 드론: 해당 종류를 모두 청소 드론으로 바꿔 발동. */
    data class CoreDrone(val kind: BlockKind) : SpecialEffect
}

data class SpecialActivation(val origin: Position, val effect: SpecialEffect, val cleared: List<Position>)
data class SpecialSpawn(val position: Position, val block: Block)
data class ObstacleHit(val position: Position, val remaining: Block?)
data class NestSpit(val nest: Position, val target: Position)
data class TimerTick(val position: Position, val turns: Int)
data class TimerBurst(val position: Position, val sludge: List<Position>)

enum class SwapRejection { OUT_OF_BOUNDS, NOT_ADJACENT, EMPTY_CELL, NO_MATCH, GAME_OVER, IMMOVABLE }

enum class GameStatus { PLAYING, WON, LOST }

/** 한 턴 동안 일어난 일. 화면은 이 목록을 순서대로 재생한다. */
sealed interface GameEvent {
    data class Swapped(val swap: Swap) : GameEvent
    data class SwapRejected(val swap: Swap, val rejection: SwapRejection) : GameEvent
    data class MatchesCleared(val matches: List<Match>, val chain: Int) : GameEvent
    data class SpecialsActivated(val activations: List<SpecialActivation>) : GameEvent
    data class SpecialsCreated(val spawns: List<SpecialSpawn>) : GameEvent
    data class Fell(val moves: List<BlockMove>) : GameEvent
    data class Slid(val moves: List<BlockMove>) : GameEvent
    data class Refilled(val spawns: List<Spawn>) : GameEvent
    data class Shuffled(val moves: List<BlockMove>) : GameEvent
    data class Regenerated(val spawns: List<Spawn>) : GameEvent
    data class ObstaclesDamaged(val hits: List<ObstacleHit>) : GameEvent
    data class SludgeSpread(val positions: List<Position>) : GameEvent
    data class NestsSpat(val spits: List<NestSpit>) : GameEvent
    data class TimersTicked(val ticks: List<TimerTick>) : GameEvent
    data class TimersBurst(val bursts: List<TimerBurst>) : GameEvent
    data class FogLifted(val positions: List<Position>) : GameEvent
    data class StickyCleared(val positions: List<Position>) : GameEvent
    data class ShieldsBroken(val positions: List<Position>) : GameEvent
    data class VentsPuffed(val positions: List<Position>) : GameEvent
    data class Hammered(val position: Position) : GameEvent
    data class MaterialsCollected(val positions: List<Position>) : GameEvent
    data class Scrolled(val from: Int, val to: Int) : GameEvent
    data object Won : GameEvent
    data object Lost : GameEvent
}

class TurnResult(val state: GameState, val events: List<GameEvent>)
