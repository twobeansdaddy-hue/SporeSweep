package dev.code404.sporesweep.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

// iOS 판 LevelData의 City.swift, Region.swift를 옮긴 것이다.

/** 도시 하나. 레벨을 플레이해 모은 별을 써서 랜드마크를 부위별로 복원한다(8장). */
data class City(val id: String, val name: String, val landmark: Landmark) {
    companion object {
        /** 도시 JSON(`도시.json`)을 읽는다. */
        fun parse(text: String): City {
            val o = Json.parseToJsonElement(text).jsonObject
            val l = o["landmark"]!!.jsonObject
            return City(
                id = o["id"]!!.jsonPrimitive.content,
                name = o["name"]!!.jsonPrimitive.content,
                landmark = Landmark(
                    id = l["id"]!!.jsonPrimitive.content,
                    name = l["name"]!!.jsonPrimitive.content,
                    parts = l["parts"]!!.jsonArray.map { e ->
                        val p = e.jsonObject
                        Landmark.Part(
                            id = p["id"]!!.jsonPrimitive.content,
                            name = p["name"]!!.jsonPrimitive.content,
                            cost = p["cost"]!!.jsonPrimitive.int,
                            requires = p["requires"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList(),
                        )
                    },
                ),
            )
        }
    }
}

/** 부위를 복원할 수 없는 이유. */
sealed interface RestoreBlocker {
    data object UnknownPart : RestoreBlocker
    data object AlreadyRestored : RestoreBlocker
    data class Requires(val partID: String) : RestoreBlocker
    data class NotEnoughStars(val short: Int) : RestoreBlocker
}

/** 랜드마크와 복원할 부위들. */
data class Landmark(val id: String, val name: String, val parts: List<Part>) {
    data class Part(val id: String, val name: String, val cost: Int, val requires: List<String> = emptyList())

    val totalCost get() = parts.sumOf { it.cost }

    fun spentStars(restored: Set<String>) = parts.filter { it.id in restored }.sumOf { it.cost }

    fun availableStars(earned: Int, restored: Set<String>) = maxOf(earned - spentStars(restored), 0)

    fun isFullyRestored(restored: Set<String>) = parts.isNotEmpty() && parts.all { it.id in restored }

    fun blocker(partID: String, earned: Int, restored: Set<String>): RestoreBlocker? {
        val part = parts.firstOrNull { it.id == partID } ?: return RestoreBlocker.UnknownPart
        if (partID in restored) return RestoreBlocker.AlreadyRestored
        part.requires.firstOrNull { it !in restored }?.let { return RestoreBlocker.Requires(it) }
        val available = availableStars(earned, restored)
        if (available < part.cost) return RestoreBlocker.NotEnoughStars(part.cost - available)
        return null
    }
}

/** 권역 하나. 도시 여러 곳을 묶는다. 자리는 그림의 가로와 세로를 0..1로 본 비율이다. */
data class Region(
    val id: String,
    val name: String,
    val mapImage: String,
    val cityIDs: List<String>,
    val cityPositions: Map<String, Spot>,
    val worldSpot: Spot,
    val mapAnchor: Double,
    val worldRadius: Double = 0.1,
) {
    data class Spot(val x: Double, val y: Double)

    val isPlayable get() = cityIDs.isNotEmpty()

    companion object {
        /** 도시 하나를 정화했을 때 권역 지도에서 초록으로 돌아오는 넓이. */
        const val CITY_RADIUS = 0.21
    }
}

/** 게임의 권역 목록. 이 순서대로 열린다. */
object RegionCatalog {
    private fun s(x: Double, y: Double) = Region.Spot(x, y)

    val all = listOf(
        Region(
            "eastasia", "동아시아", "map_east_asia", listOf("seoul", "tokyo", "beijing"),
            mapOf("seoul" to s(0.488, 0.404), "tokyo" to s(0.780, 0.540), "beijing" to s(0.264, 0.326)),
            s(0.877, 0.39), 0.58, 0.15,
        ),
        Region(
            "southasia", "남아시아", "map_south_asia", listOf("newdelhi", "bangkok", "singapore"),
            mapOf("newdelhi" to s(0.23, 0.20), "bangkok" to s(0.625, 0.345), "singapore" to s(0.645, 0.505)),
            s(0.73, 0.50), 0.5, 0.11,
        ),
        Region(
            "mideastafrica", "중동·아프리카", "map_mideast_africa", listOf("cairo", "dubai", "capetown"),
            mapOf("cairo" to s(0.58, 0.18), "dubai" to s(0.86, 0.30), "capetown" to s(0.47, 0.84)),
            s(0.54, 0.55), 0.8, 0.13,
        ),
        Region(
            "southeurope", "남유럽", "map_south_europe", listOf("rome", "athens", "barcelona"),
            mapOf("rome" to s(0.50, 0.40), "athens" to s(0.72, 0.55), "barcelona" to s(0.22, 0.34)),
            s(0.51, 0.37), 0.25, 0.07,
        ),
        Region(
            "westeurope", "서유럽", "map_west_europe", listOf("paris", "london", "amsterdam"),
            mapOf("paris" to s(0.58, 0.58), "london" to s(0.50, 0.40), "amsterdam" to s(0.71, 0.41)),
            s(0.47, 0.28), 0.7, 0.07,
        ),
        Region(
            "northamerica", "북미", "map_north_america", listOf("newyork", "sanfrancisco", "washington"),
            mapOf("newyork" to s(0.74, 0.33), "sanfrancisco" to s(0.25, 0.44), "washington" to s(0.66, 0.45)),
            s(0.17, 0.33), 0.38, 0.14,
        ),
        Region(
            "southamerica", "남미", "map_south_america", listOf("rio", "buenosaires", "easterisland"),
            mapOf("rio" to s(0.70, 0.52), "buenosaires" to s(0.62, 0.68), "easterisland" to s(0.18, 0.55)),
            s(0.28, 0.68), 0.38, 0.11,
        ),
        Region(
            "oceania", "오세아니아·극지", "map_oceania", listOf("sydney", "auckland", "antarctica"),
            mapOf("sydney" to s(0.72, 0.44), "auckland" to s(0.84, 0.61), "antarctica" to s(0.55, 0.88)),
            s(0.86, 0.74), 0.75, 0.11,
        ),
    )

    fun regionOfCity(cityID: String) = all.firstOrNull { cityID in it.cityIDs }

    val cityIDs get() = all.flatMap { it.cityIDs }
}
