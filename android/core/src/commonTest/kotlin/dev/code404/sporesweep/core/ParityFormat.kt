package dev.code404.sporesweep.core

// 상태와 이벤트를 글로 적는다. LevelData/Sources/paritygen/main.swift의 text(...)와 짝이다.
// 한쪽을 바꾸면 다른 쪽도 똑같이 바꾼다.

object ParityFormat {
    fun p(p: Position) = "${p.column}:${p.row}"
    fun ps(list: List<Position>) = "[" + list.joinToString(",") { p(it) } + "]"
    fun o(o: Orientation) = if (o == Orientation.HORIZONTAL) "h" else "v"
    fun k(k: BlockKind?) = k?.ordinal?.toString() ?: "-"

    fun block(b: Block?): String = when (b) {
        null -> "."
        is Block.Normal -> "N${b.kind.ordinal}"
        is Block.Beam -> "B${o(b.orientation)}"
        Block.Bomb -> "X"
        Block.Core -> "C"
        Block.Material -> "M"
        is Block.Concrete -> "K${b.hp}"
        is Block.Caged -> "G${b.kind.ordinal}"
        Block.Sludge -> "S"
        Block.Wall -> "W"
        is Block.Cocoon -> "O${b.trapped.ordinal}"
        Block.Rubble -> "R"
        is Block.Nest -> "T${b.hp}"
        is Block.Timed -> "Z${b.kind.ordinal}.${b.turns}"
        Block.Egg -> "E"
        is Block.Chained -> "H${b.kind.ordinal}"
        Block.Boulder -> "U"
        is Block.Vent -> "V${b.hp}"
        is Block.Frozen -> "I${b.trapped.ordinal}"
    }

    fun effect(e: SpecialEffect) = when (e) {
        is SpecialEffect.Beam -> "beam" + o(e.orientation)
        SpecialEffect.Bomb -> "bomb"
        is SpecialEffect.Core -> "core" + k(e.kind)
        SpecialEffect.CrossBeam -> "cross"
        SpecialEffect.WideCrossBeam -> "wide"
        SpecialEffect.BigBomb -> "big"
        is SpecialEffect.CoreBeam -> "coreBeam${e.kind.ordinal}"
        is SpecialEffect.CoreBomb -> "coreBomb${e.kind.ordinal}"
        SpecialEffect.ClearBoard -> "clear"
    }

    fun shape(s: MatchShape) = when (s) {
        is MatchShape.Line -> "line${o(s.orientation)}${s.length}"
        MatchShape.LShape -> "L"
        MatchShape.TShape -> "T"
    }

    fun moves(list: List<BlockMove>) = "[" + list.joinToString(",") { p(it.from) + ">" + p(it.to) } + "]"

    fun rejection(r: SwapRejection) = when (r) {
        SwapRejection.OUT_OF_BOUNDS -> "outOfBounds"
        SwapRejection.NOT_ADJACENT -> "notAdjacent"
        SwapRejection.EMPTY_CELL -> "emptyCell"
        SwapRejection.NO_MATCH -> "noMatch"
        SwapRejection.GAME_OVER -> "gameOver"
        SwapRejection.IMMOVABLE -> "immovable"
    }

    fun event(e: GameEvent): String = when (e) {
        is GameEvent.Swapped -> "swapped(${p(e.swap.from)}-${p(e.swap.to)})"
        is GameEvent.SwapRejected -> "rejected(${p(e.swap.from)}-${p(e.swap.to)},${rejection(e.rejection)})"
        is GameEvent.MatchesCleared -> "matches(${e.chain};" + e.matches.joinToString(";") {
            "${k(it.kind)}/${shape(it.shape)}/${it.longestLine}/${it.crossing?.let(::p) ?: "-"}/${ps(it.positions)}"
        } + ")"
        is GameEvent.SpecialsActivated -> "specials(" + e.activations.joinToString(";") { "${p(it.origin)}/${effect(it.effect)}/${ps(it.cleared)}" } + ")"
        is GameEvent.SpecialsCreated -> "created(" + e.spawns.joinToString(",") { "${p(it.position)}=${block(it.block)}" } + ")"
        is GameEvent.Fell -> "fell" + moves(e.moves)
        is GameEvent.Slid -> "slid" + moves(e.moves)
        is GameEvent.Refilled -> "refilled(" + e.spawns.joinToString(",") { "${p(it.position)}=${block(it.block)}" } + ")"
        is GameEvent.Shuffled -> "shuffled" + moves(e.moves)
        is GameEvent.Regenerated -> "regenerated(" + e.spawns.joinToString(",") { "${p(it.position)}=${block(it.block)}" } + ")"
        is GameEvent.ObstaclesDamaged -> "damaged(" + e.hits.joinToString(",") { "${p(it.position)}=${block(it.remaining)}" } + ")"
        is GameEvent.SludgeSpread -> "sludge" + ps(e.positions)
        is GameEvent.NestsSpat -> "spat(" + e.spits.joinToString(",") { "${p(it.nest)}>${p(it.target)}" } + ")"
        is GameEvent.TimersTicked -> "ticked(" + e.ticks.joinToString(",") { "${p(it.position)}=${it.turns}" } + ")"
        is GameEvent.TimersBurst -> "burst(" + e.bursts.joinToString(",") { "${p(it.position)}>${ps(it.sludge)}" } + ")"
        is GameEvent.FogLifted -> "fog" + ps(e.positions)
        is GameEvent.StickyCleared -> "sticky" + ps(e.positions)
        is GameEvent.ShieldsBroken -> "shields" + ps(e.positions)
        is GameEvent.VentsPuffed -> "puffed" + ps(e.positions)
        is GameEvent.Hammered -> "hammered(${p(e.position)})"
        is GameEvent.MaterialsCollected -> "collected" + ps(e.positions)
        is GameEvent.Scrolled -> "scrolled(${e.from}>${e.to})"
        GameEvent.Won -> "won"
        GameEvent.Lost -> "lost"
    }

    fun status(s: GameStatus) = when (s) {
        GameStatus.PLAYING -> "playing"
        GameStatus.WON -> "won"
        GameStatus.LOST -> "lost"
    }

    fun state(s: GameState): String {
        val next = s.generator.copy().next()
        val board = (0 until s.board.rows).joinToString("|") { row ->
            (0 until s.board.columns).joinToString(" ") { block(s.board[it, row]) }
        }
        val materials = s.materials.joinToString(",") { "${p(it.origin)}x${it.width}x${it.height}" }
        val pending = s.pendingMaterials.joinToString(",") { "${it.column}:${it.depth}" }
        return listOf(
            "status=${status(s.status)}",
            "score=${s.score}",
            "moves=${s.movesRemaining?.toString() ?: "-"}",
            "top=${s.activeTop}",
            "nest=${s.turnsUntilNestSpit}",
            "vent=${s.turnsUntilVentPuff}",
            "total=${s.materialsTotal}",
            "next=$next",
            "materials=[$materials]",
            "pending=[$pending]",
            "fog=${ps(s.fog.sorted())}",
            "sticky=${ps(s.sticky.sorted())}",
            "shields=${ps(s.shields.sorted())}",
            "board=$board",
        ).joinToString(" ; ")
    }
}
