package dev.code404.sporesweep.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** JSON 파일 하나로 정의한 레벨(9장). Swift 판 `Level`을 옮긴 것이다. */
data class Level(
    val id: String,
    val city: String,
    val columns: Int,
    val rows: Int,
    val blockTypes: Int,
    val moves: Int,
    val seed: ULong,
    val tutorial: String?,
    val materials: List<LevelMaterial>,
    val pendingMaterials: List<PendingMaterial>,
    val obstacles: List<ObstacleEntry>,
    val starScores: List<Int>,
    val rewards: List<Booster>,
    val container: IntRange?,
    val materialsSlide: Boolean,
) {
    data class LevelMaterial(val column: Int, val row: Int, val width: Int = 1, val height: Int = 1)

    data class ObstacleEntry(val type: String, val column: Int, val row: Int, val hp: Int? = null, val kind: String? = null, val turns: Int? = null)

    class LevelException(message: String) : Exception(message)

    companion object {
        const val DEFAULT_TIMER_TURNS = 8
        val TIMER_TURN_RANGE = 3..20
        val ROW_RANGE = 12..40
        val MATERIAL_COUNT_RANGE = 1..4

        private val json = Json { ignoreUnknownKeys = true }

        /** JSON 글에서 레벨 하나를 읽고 검증한다. */
        fun parse(text: String): Level {
            val o = json.parseToJsonElement(text).jsonObject
            fun int(key: String) = o[key]!!.jsonPrimitive.int
            fun intOrNull(obj: JsonObject, key: String) = obj[key]?.jsonPrimitive?.content?.toIntOrNull()
            val level = Level(
                id = o["id"]!!.jsonPrimitive.content,
                city = o["city"]!!.jsonPrimitive.content,
                columns = int("columns"),
                rows = int("rows"),
                blockTypes = int("blockTypes"),
                moves = int("moves"),
                seed = o["seed"]!!.jsonPrimitive.content.toULong(),
                tutorial = o["tutorial"]?.jsonPrimitive?.content,
                materials = o["materials"]?.jsonArray?.map {
                    val m = it.jsonObject
                    LevelMaterial(intOrNull(m, "column")!!, intOrNull(m, "row")!!, intOrNull(m, "width") ?: 1, intOrNull(m, "height") ?: 1)
                } ?: emptyList(),
                pendingMaterials = o["pendingMaterials"]?.jsonArray?.map {
                    val m = it.jsonObject
                    PendingMaterial(intOrNull(m, "column")!!, intOrNull(m, "depth")!!)
                } ?: emptyList(),
                obstacles = o["obstacles"]?.jsonArray?.map {
                    val m = it.jsonObject
                    ObstacleEntry(
                        m["type"]!!.jsonPrimitive.content, intOrNull(m, "column")!!, intOrNull(m, "row")!!,
                        intOrNull(m, "hp"), m["kind"]?.jsonPrimitive?.content, intOrNull(m, "turns"),
                    )
                } ?: emptyList(),
                starScores = o["starScores"]!!.jsonArray.map { it.jsonPrimitive.int },
                rewards = o["rewards"]?.jsonArray?.map { Booster.byName(it.jsonPrimitive.content)!! } ?: emptyList(),
                container = o["container"]?.jsonObject?.let { intOrNull(it, "from")!!..intOrNull(it, "to")!! },
                materialsSlide = o["materialsSlide"]?.jsonPrimitive?.boolean ?: true,
            )
            level.validate()
            return level
        }
    }

    /** 잘못된 데이터를 거부한다. 규칙은 Swift 판 `Level.validate()`와 같다. */
    fun validate() {
        fun fail(message: String): Nothing = throw LevelException("$id: $message")
        if (columns != GameConstants.COLUMNS) fail("invalidColumns($columns)")
        if (rows !in ROW_RANGE) fail("invalidRows($rows)")
        if (blockTypes !in GameConstants.BLOCK_TYPE_RANGE) fail("invalidBlockTypes($blockTypes)")
        if (moves <= 0) fail("invalidMoves($moves)")
        val materialCount = materials.size + pendingMaterials.size
        if (materialCount !in MATERIAL_COUNT_RANGE) fail("invalidMaterialCount($materialCount)")

        val occupied = HashSet<Position>()
        fun claim(column: Int, row: Int) {
            if (column !in 0 until columns || row !in 0 until rows) fail("outOfBounds($column, $row)")
            if (!occupied.add(Position(column, row))) fail("overlap($column, $row)")
        }
        for (m in materials) {
            if (m.width < 1 || m.height < 1) fail("invalidMaterialSize(${m.column}, ${m.row})")
            for (row in m.row until m.row + m.height) for (column in m.column until m.column + m.width) claim(column, row)
            if (m.row + m.height > GameConstants.ACTIVE_ROWS) fail("materialBelowStartZone(${m.column}, ${m.row})")
        }
        for (p in pendingMaterials) if (p.column !in 0 until columns || p.depth < 0) fail("invalidPending(${p.column}, ${p.depth})")
        for (o in obstacles) {
            when (o.type) {
                "concrete" -> (o.hp ?: 1).let { if (it !in 1..2) fail("invalidHP($it)") }
                "nest", "vent" -> (o.hp ?: 2).let { if (it !in 1..2) fail("invalidHP($it)") }
                "timer" -> (o.turns ?: DEFAULT_TIMER_TURNS).let { if (it !in TIMER_TURN_RANGE) fail("invalidTimerTurns($it)") }
                "cage", "sludge", "wall", "rubble", "fog", "sticky", "egg", "chain", "shield", "boulder", "ice" -> {}
                "cocoon" -> {
                    val kind = o.kind?.let { BlockKind.byName(it) }
                    if (kind == null || kind.ordinal >= blockTypes) fail("invalidCocoonKind(${o.column}, ${o.row})")
                }
                else -> fail("unknownObstacle(${o.type})")
            }
            claim(o.column, o.row)
        }
        if (starScores.size != 2 || starScores[0] >= starScores[1] || starScores.any { it <= 0 }) fail("invalidStarScores")
        val walls = obstacles.filter { it.type == "wall" }.map { Position(it.column, it.row) }.toSet()
        if (walls.isNotEmpty()) {
            val reachable = HashSet<Position>()
            for (row in 0 until rows) for (column in 0 until columns) {
                val cell = Position(column, row)
                if (cell in walls) continue
                val fromAbove = listOf(0, -1, 1).any { Position(column + it, row - 1) in reachable }
                if (row != 0 && !fromAbove) fail("unreachableCell($column, $row)")
                reachable.add(cell)
            }
        }
        container?.let { c ->
            if (c.first < 0 || c.last >= columns || c.first > c.last) fail("invalidContainer")
            if (c.first > 0 || c.last < columns - 1) {
                if (!materialsSlide || !materials.all { it.width == 1 && it.height == 1 }) fail("narrowContainerNeedsFlowingMaterials")
                val floor = obstacles.filter { it.type == "wall" && it.row == rows - 1 }.map { it.column }.toSet()
                for (column in 0 until columns) if (column !in c && column !in floor) fail("openFloorOutsideContainer($column)")
            }
        }
    }

    /** 클리어한 판의 점수로 별 수를 정한다(6장). */
    fun stars(score: Int) = 1 + starScores.count { score >= it }

    /** 판마다 시작 보드가 같은지(9장). 레벨 설명이 있는 판은 설명과 첫 화면이 어긋나지 않게 늘 `seed`로 시작한다. */
    val hasFixedStart get() = tutorial != null

    /** `index`번째 판의 시작 시드(Swift 판 `boardSeed`). 시작이 고정된 판이거나 `index`가 0이면 레벨의 `seed`다. */
    fun boardSeed(index: Int): ULong =
        if (hasFixedStart || index == 0) seed else seed * 6_364_136_223_846_793_005uL + index.toULong() * 1_442_695_040_888_963_407uL

    /** 이 레벨의 시작 상태를 만든다. `seed`를 주지 않으면 레벨의 `seed`로 만든다. */
    fun makeState(seed: ULong? = null): GameState {
        validate()
        return GameState.fromSeed(
            seed = seed ?: this.seed,
            columns = columns,
            rows = rows,
            blockTypes = blockTypes,
            moves = moves,
            pendingMaterials = pendingMaterials,
            materialPieces = materials.map { MaterialPiece(Position(it.column, it.row), it.width, it.height) },
            obstacles = obstacles.map { e ->
                val kind = when (e.type) {
                    "cage" -> ObstacleKind.Cage
                    "sludge" -> ObstacleKind.Sludge
                    "wall" -> ObstacleKind.Wall
                    "rubble" -> ObstacleKind.Rubble
                    "nest" -> ObstacleKind.Nest(e.hp ?: 2)
                    "timer" -> ObstacleKind.Timer(e.turns ?: DEFAULT_TIMER_TURNS)
                    "fog" -> ObstacleKind.Fog
                    "sticky" -> ObstacleKind.Sticky
                    "egg" -> ObstacleKind.Egg
                    "chain" -> ObstacleKind.Chain
                    "shield" -> ObstacleKind.Shield
                    "boulder" -> ObstacleKind.Boulder
                    "vent" -> ObstacleKind.Vent(e.hp ?: 2)
                    "ice" -> ObstacleKind.Ice
                    "cocoon" -> ObstacleKind.Cocoon(e.kind?.let { BlockKind.byName(it) } ?: BlockKind.BRICK)
                    else -> ObstacleKind.Concrete(e.hp ?: 1)
                }
                Obstacle(kind, Position(e.column, e.row))
            },
            blocksSlide = true,
            containerColumns = container,
            materialsSlide = materialsSlide,
        )
    }
}

/** 레벨 목록. 도시의 순서대로 열린다(8장). */
object LevelCatalog {
    val cityIDs = listOf(
        "seoul", "tokyo", "beijing", "newdelhi", "bangkok", "singapore", "cairo", "dubai", "capetown",
        "rome", "athens", "barcelona", "paris", "london", "amsterdam",
        "newyork", "sanfrancisco", "washington", "rio", "buenosaires", "easterisland",
        "sydney", "auckland", "antarctica",
    )
}
