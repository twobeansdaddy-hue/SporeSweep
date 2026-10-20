package dev.code404.sporesweep.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.daysUntil
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Instant

// Swift 판 Progress 패키지(GameProgress, Lives, DailyGift, ProgressStore)를 옮긴 것이다.
// 시계를 직접 읽지 않고 늘 지금 시각과 시간대를 받아서 계산한다. 그래야 시험할 수 있다.

/** 생명력(6장). 판에서 실패하면 하나 줄고, 시간이 지나면 하나씩 다시 찬다. */
class Lives private constructor(
    private var stored: Int,
    private var refillStart: Instant?,
    private var adDay: LocalDate?,
    private var adCount: Int,
) {
    constructor() : this(MAXIMUM, null, null, 0)

    companion object {
        const val MAXIMUM = 5
        /** 하나가 차는 데 걸리는 시간(초). */
        const val REFILL_INTERVAL = 30 * 60.0
        const val DAILY_AD_LIMIT = 5

        internal fun fromJson(o: JsonObject) = Lives(
            o["stored"]?.jsonPrimitive?.int ?: MAXIMUM,
            o["refillStart"]?.takeIf { it != JsonNull }?.jsonPrimitive?.content?.let { Instant.parse(it) },
            o["adDay"]?.takeIf { it != JsonNull }?.jsonPrimitive?.content?.let { LocalDate.parse(it) },
            o["adCount"]?.jsonPrimitive?.int ?: 0,
        )
    }

    fun copy() = Lives(stored, refillStart, adDay, adCount)

    internal fun toJson() = buildJsonObject {
        put("stored", stored)
        put("refillStart", refillStart?.toString())
        put("adDay", adDay?.toString())
        put("adCount", adCount)
    }

    private fun elapsed(now: Instant, start: Instant) = maxOf((now.toEpochMilliseconds() - start.toEpochMilliseconds()) / 1000.0, 0.0)

    /** 지금 가진 수. */
    fun count(now: Instant): Int {
        val start = refillStart ?: return minOf(stored, MAXIMUM)
        return minOf(stored + (elapsed(now, start) / REFILL_INTERVAL).toInt(), MAXIMUM)
    }

    /** 다음 하나가 차기까지 남은 시간(초). 가득 차 있으면 `null`이다. */
    fun timeUntilNext(now: Instant): Double? {
        val start = refillStart ?: return null
        if (count(now) >= MAXIMUM) return null
        return REFILL_INTERVAL - elapsed(now, start) % REFILL_INTERVAL
    }

    private fun settle(now: Instant) {
        val start = refillStart ?: return
        val gained = (elapsed(now, start) / REFILL_INTERVAL).toInt()
        stored = minOf(stored + gained, MAXIMUM)
        refillStart = if (stored >= MAXIMUM) null else start + (gained * REFILL_INTERVAL * 1000).toLong().milliseconds
    }

    /** 하나를 잃는다. 하나도 없으면 `false`다. */
    fun lose(now: Instant): Boolean {
        settle(now)
        if (stored <= 0) return false
        stored -= 1
        if (refillStart == null) refillStart = now
        return true
    }

    fun adGrantsLeft(now: Instant, zone: TimeZone = TimeZone.currentSystemDefault()): Int {
        val day = adDay
        if (day == null || day != now.toLocalDateTime(zone).date) return DAILY_AD_LIMIT
        return maxOf(DAILY_AD_LIMIT - adCount, 0)
    }

    /** 광고를 보고 하나를 받는다. 가득 차 있거나 오늘 받을 만큼 다 받았으면 `false`다. */
    fun addFromAd(now: Instant, zone: TimeZone = TimeZone.currentSystemDefault()): Boolean {
        settle(now)
        if (stored >= MAXIMUM || adGrantsLeft(now, zone) <= 0) return false
        val today = now.toLocalDateTime(zone).date
        if (adDay == today) {
            adCount += 1
        } else {
            adDay = today
            adCount = 1
        }
        stored += 1
        if (stored >= MAXIMUM) refillStart = null
        return true
    }

    /** 수를 바로 정한다. 시험과 개발용에 쓴다. */
    fun set(count: Int, now: Instant) {
        stored = count.coerceIn(0, MAXIMUM)
        refillStart = if (stored >= MAXIMUM) null else now
    }

    override fun equals(other: Any?) = other is Lives && other.stored == stored && other.refillStart == refillStart &&
        other.adDay == adDay && other.adCount == adCount

    override fun hashCode() = listOf(stored, refillStart, adDay, adCount).hashCode()
}

/** 일일 보상(6장). 하루에 한 번 받고, 날마다 이어서 받으면 선물이 커진다. 이레가 한 바퀴다. */
class DailyGift private constructor(lastDay: LocalDate?, streak: Int) {
    constructor() : this(null, 0)

    var lastDay: LocalDate? = lastDay
        private set
    var streak: Int = streak
        private set

    companion object {
        const val CYCLE = 7
        val REWARDS = listOf(
            listOf("booster:extraMoves"),
            listOf("tool:hammer"),
            listOf("booster:bomb"),
            listOf("tool:swap"),
            listOf("booster:beam", "tool:shuffle"),
            listOf("booster:core"),
            listOf("lives", "tool:hammer", "tool:swap", "tool:shuffle"),
        )

        internal fun fromJson(o: JsonObject) = DailyGift(
            o["lastDay"]?.takeIf { it != JsonNull }?.jsonPrimitive?.content?.let { LocalDate.parse(it) },
            o["streak"]?.jsonPrimitive?.int ?: 0,
        )
    }

    fun copy() = DailyGift(lastDay, streak)

    internal fun toJson() = buildJsonObject {
        put("lastDay", lastDay?.toString())
        put("streak", streak)
    }

    fun canClaim(now: Instant, zone: TimeZone = TimeZone.currentSystemDefault()): Boolean {
        val last = lastDay ?: return true
        // 시계를 뒤로 돌려 마지막으로 받은 날보다 앞이 되어도 다시 받을 수 없다.
        return now.toLocalDateTime(zone).date > last
    }

    /** 지금 받으면 몇째 날의 선물인지(1부터). 하루라도 거르면 첫날로 돌아간다. */
    fun nextDay(now: Instant, zone: TimeZone = TimeZone.currentSystemDefault()): Int {
        val last = lastDay ?: return 1
        if (streak <= 0) return 1
        val gap = last.daysUntil(now.toLocalDateTime(zone).date)
        if (gap > 1) return 1
        return streak % CYCLE + 1
    }

    /** 오늘의 선물을 받는다. 오늘 이미 받았으면 `null`이다. */
    fun claim(now: Instant, zone: TimeZone = TimeZone.currentSystemDefault()): List<String>? {
        if (!canClaim(now, zone)) return null
        val day = nextDay(now, zone)
        streak = day
        lastDay = now.toLocalDateTime(zone).date
        return REWARDS[day - 1]
    }

    override fun equals(other: Any?) = other is DailyGift && other.lastDay == lastDay && other.streak == streak
    override fun hashCode() = listOf(lastDay, streak).hashCode()
}

/** 플레이어의 진행 상황. 레벨별 최고 별과 점수, 도시별 복원한 부위, 부스터, 생명, 일일 보상. */
class GameProgress {
    private val stars = HashMap<String, Int>()
    private val bestScores = HashMap<String, Int>()
    private val restoredParts = HashMap<String, MutableSet<String>>()
    private val boosters = HashMap<String, Int>()
    var lives = Lives()
    var daily = DailyGift()

    fun copy(): GameProgress {
        val next = GameProgress()
        next.stars.putAll(stars)
        next.bestScores.putAll(bestScores)
        restoredParts.forEach { (k, v) -> next.restoredParts[k] = v.toMutableSet() }
        next.boosters.putAll(boosters)
        next.lives = lives.copy()
        next.daily = daily.copy()
        return next
    }

    fun boosterCount(name: String) = boosters[name] ?: 0

    fun addBooster(name: String, count: Int = 1) {
        if (count <= 0) return
        boosters[name] = boosterCount(name) + count
    }

    fun useBooster(name: String): Boolean {
        if (boosterCount(name) <= 0) return false
        boosters[name] = boosterCount(name) - 1
        return true
    }

    /** 복원한 부위. Swift 판처럼 복사본을 준다. 안을 바꾸는 묶음을 그대로 주면 화면이 바뀐 줄 모른다. */
    fun restoredParts(cityID: String): Set<String> = restoredParts[cityID]?.toSet() ?: emptySet()

    fun restore(partID: String, cityID: String) = restoredParts.getOrPut(cityID) { HashSet() }.add(partID)

    fun stars(levelID: String) = stars[levelID] ?: 0
    fun bestScore(levelID: String) = bestScores[levelID] ?: 0
    fun isCleared(levelID: String) = stars(levelID) > 0

    /** 클리어한 판을 기록한다. 별과 점수는 각각 더 높은 쪽만 남긴다. 기록이 바뀌었으면 `true`다. */
    fun recordClear(levelID: String, earned: Int, score: Int): Boolean {
        val clamped = earned.coerceIn(1, 3)
        var changed = false
        if (clamped > stars(levelID)) {
            stars[levelID] = clamped
            changed = true
        }
        if (score > bestScore(levelID) || bestScores[levelID] == null) {
            bestScores[levelID] = maxOf(score, 0)
            changed = true
        }
        return changed
    }

    fun clearedCount(levelIDs: List<String>) = levelIDs.count { isCleared(it) }
    fun totalStars(levelIDs: List<String>) = levelIDs.sumOf { stars(it) }

    fun isUnlocked(index: Int, levelIDs: List<String>): Boolean {
        if (index !in levelIDs.indices) return false
        return index == 0 || isCleared(levelIDs[index - 1])
    }

    /** 다른 진행과 합친다. 별과 점수는 높은 쪽, 복원은 합친 것, 부스터는 레벨을 더 깬 쪽. */
    fun merging(other: GameProgress): GameProgress {
        val merged = copy()
        other.stars.forEach { (k, v) -> merged.stars[k] = maxOf(merged.stars[k] ?: v, v) }
        other.bestScores.forEach { (k, v) -> merged.bestScores[k] = maxOf(merged.bestScores[k] ?: v, v) }
        other.restoredParts.forEach { (k, v) -> merged.restoredParts.getOrPut(k) { HashSet() }.addAll(v) }
        if (other.stars.size > stars.size) {
            merged.boosters.clear()
            merged.boosters.putAll(other.boosters)
        }
        return merged
    }

    fun toJson(): String = Json { prettyPrint = true }.encodeToString(
        JsonObject.serializer(),
        buildJsonObject {
            putJsonObject("stars") { stars.entries.sortedBy { it.key }.forEach { (k, v) -> put(k, v) } }
            putJsonObject("bestScores") { bestScores.entries.sortedBy { it.key }.forEach { (k, v) -> put(k, v) } }
            putJsonObject("restoredParts") {
                restoredParts.entries.sortedBy { it.key }.forEach { (k, v) -> putJsonArray(k) { v.sorted().forEach { add(JsonPrimitive(it)) } } }
            }
            putJsonObject("boosters") { boosters.entries.sortedBy { it.key }.forEach { (k, v) -> put(k, v) } }
            put("lives", lives.toJson())
            put("daily", daily.toJson())
        },
    )

    override fun equals(other: Any?) = other is GameProgress && other.stars == stars && other.bestScores == bestScores &&
        other.restoredParts == restoredParts && other.boosters == boosters && other.lives == lives && other.daily == daily

    override fun hashCode() = listOf(stars, bestScores, restoredParts, boosters).hashCode()

    companion object {
        /** 저장한 글을 읽는다. 뒤에 생긴 항목이 없는 예전 글도 읽는다. 형식이 틀리면 예외를 던진다. */
        fun fromJson(text: String): GameProgress {
            val o = Json.parseToJsonElement(text).jsonObject
            val progress = GameProgress()
            fun ints(e: JsonElement?) = e?.jsonObject?.mapValues { it.value.jsonPrimitive.int } ?: emptyMap()
            progress.stars.putAll(ints(o["stars"] ?: error("stars가 없다")))
            progress.bestScores.putAll(ints(o["bestScores"] ?: error("bestScores가 없다")))
            o["restoredParts"]?.jsonObject?.forEach { (k, v) ->
                progress.restoredParts[k] = v.jsonArray.map { it.jsonPrimitive.content }.toMutableSet()
            }
            progress.boosters.putAll(ints(o["boosters"]))
            o["lives"]?.jsonObject?.let { progress.lives = Lives.fromJson(it) }
            o["daily"]?.jsonObject?.let { progress.daily = DailyGift.fromJson(it) }
            return progress
        }
    }
}
