package dev.code404.sporesweep

import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import dev.code404.sporesweep.core.Booster
import dev.code404.sporesweep.core.City
import dev.code404.sporesweep.core.DailyGift
import dev.code404.sporesweep.core.GameProgress
import dev.code404.sporesweep.core.GameState
import dev.code404.sporesweep.core.GameStatus
import dev.code404.sporesweep.core.Landmark
import dev.code404.sporesweep.core.Level
import dev.code404.sporesweep.core.LevelCatalog
import dev.code404.sporesweep.core.Lives
import dev.code404.sporesweep.core.ProgressStore
import dev.code404.sporesweep.core.Region
import dev.code404.sporesweep.core.RegionCatalog
import dev.code404.sporesweep.core.RestoreBlocker
import dev.code404.sporesweep.core.Tool
import java.io.File
import java.time.Instant
import java.time.LocalDate

/**
 * 개발용 실행 인자. iOS 판의 실행 인자와 이름이 같다. 디버그 빌드에서만 읽는다.
 *
 * `adb shell am start -n dev.code404.sporesweep/.MainActivity --es city tokyo --ei level 2 --ez autoplay true`
 */
class DebugArgs(private val extras: Bundle?) {
    private val on = BuildConfig.DEBUG && extras != null

    fun has(key: String) = on && extras!!.containsKey(key)
    fun bool(key: String) = on && (extras!!.get(key)?.toString()?.let { it == "true" || it == "1" } ?: false)
    fun int(key: String) = if (on) extras!!.get(key)?.toString()?.toIntOrNull() ?: 0 else 0
    fun double(key: String) = if (on) extras!!.get(key)?.toString()?.toDoubleOrNull() ?: 0.0 else 0.0
    fun string(key: String): String? = if (on) extras!!.get(key)?.toString() else null
}

/**
 * 앱 전체가 함께 보는 상태. iOS 판 AppModel.swift를 옮긴 것이다.
 *
 * 진행이 바뀔 때마다 `revision`이 올라서, 그것을 읽는 화면이 다시 그려진다.
 */
class AppModel(context: Context, val args: DebugArgs) {
    /** 바뀔 때마다 1씩 오른다. 화면은 이 값을 읽어 다시 그려진다. */
    var revision by mutableIntStateOf(0)
        private set

    private fun changed() {
        revision += 1
    }

    private val prefs: SharedPreferences = context.getSharedPreferences("spore", Context.MODE_PRIVATE)
    private val store = ProgressStore(File(context.filesDir, "progress.json"))

    var city: City? = null
        private set
    var cities: List<City> = emptyList()
        private set
    /** 도시 ID → 레벨 ID. 시작할 때 파일 이름만 보고 채운다. */
    private val levelIDsByCity = HashMap<String, List<String>>()
    /** 도시 ID → 레벨. 그 도시를 처음 열 때 읽는다. 앱을 빨리 띄우려고 미룬다. */
    private val levelCache = HashMap<String, List<Level>>()

    private fun levelsOf(cityID: String): List<Level> = levelCache.getOrPut(cityID) {
        Assets.levels(cityID).map { it.copy(tutorial = it.tutorial?.let { t -> tr(t) }) }
    }

    /** 다음 도시로 날아가는 연출을 보여줘야 하면 출발과 도착 도시. */
    var pendingFlight by mutableStateOf<Flight?>(null)
    /** 띄운 지도 화면. */
    var mapScreen by mutableStateOf<MapScreen?>(null)

    sealed interface MapScreen {
        data object World : MapScreen
        data class RegionMap(val id: String) : MapScreen
    }

    data class Flight(val from: String, val to: String)

    /** 권역 목록. 이름은 기기의 언어로 바꿔 둔다. */
    val regions: List<Region> = RegionCatalog.all.map { it.copy(name = tr(it.name)) }

    fun crossesRegions(flight: Flight) = RegionCatalog.regionOfCity(flight.from)?.id != RegionCatalog.regionOfCity(flight.to)?.id

    var levels: List<Level> = emptyList()
        private set
    private var cityLevels: List<Level> = emptyList()
    var isLabMode = false
        private set
    var progress: GameProgress
        private set
    var problem: String? = null
        private set
    var wantsIntro by mutableStateOf(false)
    var wantsEnding by mutableStateOf(false)
    var isFirstEnding = false
    var lastRewards: List<Booster> = emptyList()
        private set
    var justCompletedLandmark by mutableStateOf(false)
    private var seenTutorials: MutableSet<String>
    private var canSave = true
    private var forcedCityID: String? = null

    val levelIDs get() = levels.map { it.id }

    companion object {
        private const val CURRENT_CITY = "currentCity"
        private const val SEEN_TUTORIALS = "seenTutorials"
        private const val SEEN_ENDING = "seenEnding"
        private const val STARTER_TOOLS = "grantedStarterTools"
        private const val AD_TOOL_DAY = "adToolDay"
        private const val AD_TOOL_COUNT = "adToolCount"
        const val SEEN_INTRO = "seenIntro"
        const val DAILY_AD_TOOLS = 2
        val completionRewards = Booster.entries

        fun key(tool: Tool) = "tool_" + tool.name.lowercase()
    }

    val preferences get() = prefs

    init {
        seenTutorials = prefs.getStringSet(SEEN_TUTORIALS, emptySet())!!.toMutableSet()
        if (args.bool("resetProgress")) {
            prefs.edit().remove(STARTER_TOOLS).apply()
            store.reset()
        }
        var loadFailed = false
        progress = try {
            store.load()
        } catch (e: Exception) {
            canSave = false
            loadFailed = true
            GameProgress()
        }
        val problems = mutableListOf<String>()
        if (loadFailed) problems.add(tr("저장된 진행을 읽지 못했어요. 이번에 한 기록은 저장되지 않아요."))
        val loaded = mutableListOf<City>()
        for (id in LevelCatalog.cityIDs) {
            try {
                val raw = City.parse(Assets.text("levels/$id.json"))
                val city = raw.copy(
                    name = tr(raw.name),
                    landmark = raw.landmark.copy(name = tr(raw.landmark.name), parts = raw.landmark.parts.map { it.copy(name = tr(it.name)) }),
                )
                levelIDsByCity[id] = Assets.levelIDs(id)
                loaded.add(city)
            } catch (e: Exception) {
                problems.add("${id}의 도시나 레벨 데이터를 읽지 못했어요.")
            }
        }
        cities = loaded
        if (args.bool("allStars") || args.bool("restoreAll")) {
            for (id in levelIDsByCity.values.flatten()) progress.recordClear(id, 3, 0)
            if (args.bool("restoreAll")) for (c in cities) for (part in c.landmark.parts) progress.restore(part.id, c.id)
            canSave = false
        }
        args.string("clearedCities")?.let { ids ->
            for (c in ids.split(",")) for (level in levelIDsByCity[c] ?: emptyList()) progress.recordClear(level, 1, 0)
            canSave = false
        }
        val clearedLevels = args.int("clearedLevels")
        val forcedCity = args.string("city")
        if (clearedLevels > 0 && forcedCity != null) {
            for (level in (levelIDsByCity[forcedCity] ?: emptyList()).take(clearedLevels)) progress.recordClear(level, 1, 0)
            canSave = false
        }
        problem = problems.takeIf { it.isNotEmpty() }?.joinToString("\n")
        var startID = prefs.getString(CURRENT_CITY, "") ?: ""
        if (forcedCity != null && cities.any { it.id == forcedCity }) {
            startID = forcedCity
            forcedCityID = forcedCity
        }
        val start = cities.firstOrNull { it.id == startID && isUnlocked(it.id) } ?: cities.firstOrNull()
        city = start
        levels = start?.let { levelsOf(it.id) } ?: emptyList()
        cityLevels = levels
        val extra = args.int("boosters")
        if (extra > 0) {
            for (b in Booster.entries) progress.addBooster(b.id, extra)
            canSave = false
        }
        if (args.has("tools")) {
            val count = args.int("tools")
            for (tool in Tool.entries) {
                while (progress.useBooster(key(tool))) {}
                progress.addBooster(key(tool), count)
            }
            canSave = false
        }
        if (args.has("lives")) {
            progress.lives.set(args.int("lives"), Instant.now())
            canSave = false
        }
        if (args.bool("map")) currentRegion?.let { mapScreen = MapScreen.RegionMap(it.id) }
        if (args.bool("world")) mapScreen = MapScreen.World
        args.string("region")?.let { id -> if (regions.any { it.id == id }) mapScreen = MapScreen.RegionMap(id) }
        val leg = args.int("flight")
        if (leg >= 1 && leg in cities.indices) {
            for (level in levelIDsByCity[cities[leg - 1].id] ?: emptyList()) if (!progress.isCleared(level)) progress.recordClear(level, 1, 0)
            canSave = false
            pendingFlight = Flight(cities[leg - 1].id, cities[leg].id)
            forcedCityID = cities[leg].id
        }
        if (args.bool("ending")) wantsEnding = true
        if (args.bool("lab")) setLabMode(true)
        grantStarterTools()
        if (args.bool("dailyGift")) {
            progress.daily = DailyGift()
            canSave = false
        }
    }

    // MARK: 도시

    fun visit(cityID: String) {
        if (cities.none { it.id == cityID }) return
        if (isLabMode) setLabMode(false)
        forcedCityID = cityID
        select(cityID)
    }

    fun isUnlocked(cityID: String): Boolean {
        val index = cities.indexOfFirst { it.id == cityID }
        if (index < 0) return false
        if (cityID == forcedCityID) return true
        return index == 0 || hasClearedAllLevels(cities[index - 1].id)
    }

    fun hasClearedAllLevels(cityID: String): Boolean {
        val ids = levelIDsByCity[cityID] ?: emptyList()
        return ids.isNotEmpty() && ids.all { progress.isCleared(it) }
    }

    fun isFullyRestored(cityID: String): Boolean {
        val c = cities.firstOrNull { it.id == cityID } ?: return false
        return c.landmark.isFullyRestored(progress.restoredParts(cityID))
    }

    fun stars(cityID: String): Pair<Int, Int> {
        val ids = levelIDsByCity[cityID] ?: emptyList()
        return progress.totalStars(ids) to ids.size * 3
    }

    val hasClearedEverything get() = cities.isNotEmpty() && cities.all { hasClearedAllLevels(it.id) }

    val totalStars: Pair<Int, Int>
        get() {
            val ids = cities.flatMap { levelIDsByCity[it.id] ?: emptyList() }
            return progress.totalStars(ids) to ids.size * 3
        }

    val restoredLandmarks get() = cities.count { isFullyRestored(it.id) }

    // MARK: 권역

    val currentRegion: Region? get() = city?.let { c -> regions.firstOrNull { c.id in it.cityIDs } } ?: regions.firstOrNull()

    fun isUnlockedRegion(regionID: String): Boolean {
        val index = regions.indexOfFirst { it.id == regionID }
        if (index < 0) return false
        if (index == 0) return true
        val previous = regions[index - 1]
        return previous.isPlayable && previous.cityIDs.all { hasClearedAllLevels(it) }
    }

    fun starsInRegion(regionID: String): Pair<Int, Int> {
        val ids = regions.firstOrNull { it.id == regionID }?.cityIDs ?: emptyList()
        return ids.map { stars(it) }.fold(0 to 0) { a, b -> (a.first + b.first) to (a.second + b.second) }
    }

    fun select(cityID: String) {
        if (!isUnlocked(cityID)) return
        val next = cities.firstOrNull { it.id == cityID } ?: return
        city = next
        levels = levelsOf(cityID)
        cityLevels = levels
        isLabMode = false
        prefs.edit().putString(CURRENT_CITY, cityID).apply()
        changed()
    }

    val nextCity: City?
        get() {
            val index = cities.indexOf(city ?: return null)
            return cities.getOrNull(index + 1)
        }

    fun setLabMode(isOn: Boolean) {
        val lab = if (isOn) runCatching { Assets.levels("lab") }.getOrDefault(emptyList()) else emptyList()
        if (isOn && lab.isNotEmpty()) {
            levels = lab + runCatching { Assets.levels("sample") }.getOrDefault(emptyList())
            isLabMode = true
        } else {
            levels = cityLevels
            isLabMode = false
        }
        changed()
    }

    // MARK: 별과 복원

    val earnedStars get() = progress.totalStars(levelIDs)
    val restoredParts: Set<String> get() = city?.let { progress.restoredParts(it.id) } ?: emptySet()
    val availableStars get() = city?.landmark?.availableStars(earnedStars, restoredParts) ?: 0
    val isFullyRestored get() = city?.landmark?.isFullyRestored(restoredParts) ?: false

    fun blocker(part: Landmark.Part): RestoreBlocker? {
        val c = city ?: return RestoreBlocker.UnknownPart
        return c.landmark.blocker(part.id, earnedStars, restoredParts)
    }

    fun restore(part: Landmark.Part) {
        val c = city ?: return
        if (blocker(part) != null) return
        if (progress.restore(part.id, c.id)) {
            if (isFullyRestored) {
                for (b in completionRewards) progress.addBooster(b.id)
                for (tool in Tool.entries) progress.addBooster(key(tool))
                justCompletedLandmark = true
            }
            Tracker.log(Tracker.Event.LandmarkRestore(c.id, part.id, isFullyRestored))
            save()
        }
    }

    // MARK: 생명력

    val usesLives get() = !isLabMode
    fun lives(now: Instant = Instant.now()) = progress.lives.count(now)
    fun timeUntilNextLife(now: Instant = Instant.now()) = progress.lives.timeUntilNext(now)
    val canStartLevel get() = !usesLives || lives() > 0

    fun loseLife() {
        if (!usesLives || !progress.lives.lose(Instant.now())) return
        if (lives() == 0) Tracker.log(Tracker.Event.LivesOut)
        save()
    }

    fun adLivesLeft(now: Instant = Instant.now()) = progress.lives.adGrantsLeft(now)

    fun grantLifeFromAd(): Boolean {
        if (!progress.lives.addFromAd(Instant.now())) return false
        save()
        return true
    }

    // MARK: 일일 보상

    val canClaimDailyGift get() = !isLabMode && progress.daily.canClaim(Instant.now())

    val dailyGiftDay get() = if (progress.daily.canClaim(Instant.now())) progress.daily.nextDay(Instant.now()) else maxOf(progress.daily.streak, 1)

    fun claimDailyGift(): List<String>? {
        val items = progress.daily.claim(Instant.now()) ?: return null
        Tracker.log(Tracker.Event.DailyGift(progress.daily.streak))
        for (item in items) {
            val parts = item.split(":")
            when (parts[0]) {
                "booster" -> progress.addBooster(parts[1])
                "tool" -> progress.addBooster("tool_" + parts[1])
                else -> progress.lives.set(Lives.MAXIMUM, Instant.now())
            }
        }
        save()
        return items
    }

    // MARK: 아이템

    fun toolCount(tool: Tool) = progress.boosterCount(key(tool))

    fun useTool(tool: Tool) {
        if (isLabMode || !progress.useBooster(key(tool))) return
        save()
    }

    private fun grantStarterTools() {
        if (!canSave || prefs.getBoolean(STARTER_TOOLS, false)) return
        for (tool in Tool.entries) progress.addBooster(key(tool))
        prefs.edit().putBoolean(STARTER_TOOLS, true).apply()
        save()
    }

    val adToolsLeft: Int
        get() {
            val day = prefs.getString(AD_TOOL_DAY, null)
            if (day != LocalDate.now().toString()) return DAILY_AD_TOOLS
            return maxOf(DAILY_AD_TOOLS - prefs.getInt(AD_TOOL_COUNT, 0), 0)
        }

    fun grantToolFromAd(tool: Tool): Boolean {
        val left = adToolsLeft
        if (left <= 0) return false
        prefs.edit().putString(AD_TOOL_DAY, LocalDate.now().toString()).putInt(AD_TOOL_COUNT, DAILY_AD_TOOLS - left + 1).apply()
        progress.addBooster(key(tool))
        save()
        return true
    }

    // MARK: 시작 부스터

    fun boosterCount(booster: Booster) = progress.boosterCount(booster.id)

    fun useBoosters(boosters: Set<Booster>): List<Booster> {
        val used = Booster.entries.filter { it in boosters && progress.useBooster(it.id) }
        if (used.isNotEmpty()) save()
        return used
    }

    // MARK: 튜토리얼과 초기화

    fun shouldShowTutorial(level: Level) = level.tutorial != null && level.id !in seenTutorials

    fun markTutorialSeen(level: Level) {
        if (!seenTutorials.add(level.id)) return
        prefs.edit().putStringSet(SEEN_TUTORIALS, seenTutorials.toSet()).apply()
    }

    fun resetTutorials() {
        seenTutorials.clear()
        prefs.edit().remove(SEEN_TUTORIALS).apply()
    }

    fun resetProgress() {
        store.reset()
        progress = GameProgress()
        canSave = true
        problem = null
        prefs.edit().remove(STARTER_TOOLS).apply()
        grantStarterTools()
        cities.firstOrNull()?.let { select(it.id) }
        changed()
    }

    // MARK: 광고 시험 (개발용)

    /** 다음 판을 이 이동 횟수로 시작한다. 이어하기 광고를 빨리 보려고 쓴다. 0이면 레벨대로다. */
    var debugMoves by mutableIntStateOf(0)

    /** 생명을 모두 비운다. 생명 광고를 보려고 쓴다. 진행에 저장된다. */
    fun drainLives() {
        progress.lives.set(0, Instant.now())
        save()
    }

    /** 아이템을 모두 비운다. 아이템 광고를 보려고 쓴다. 진행에 저장된다. */
    fun drainTools() {
        for (tool in Tool.entries) while (progress.useBooster(key(tool))) {}
        prefs.edit().remove(AD_TOOL_DAY).remove(AD_TOOL_COUNT).apply()
        save()
    }

    // MARK: 레벨

    fun isUnlocked(index: Int): Boolean {
        if (city?.id == forcedCityID && forcedCityID != null) return true
        return isLabMode || progress.isUnlocked(index, levelIDs)
    }

    /** 끝난 판을 기록한다. 이번 판에서 받은 별 수를 돌려준다. */
    fun record(state: GameState, level: Level): Int {
        lastRewards = emptyList()
        if (state.status != GameStatus.WON) return 0
        val stars = level.stars(state.score)
        if (isLabMode) return stars
        val isFirstClear = !progress.isCleared(level.id)
        val hadClearedAll = hasClearedAllLevels(level.city)
        if (progress.recordClear(level.id, stars, state.score)) {
            if (isFirstClear) {
                for (b in level.rewards) progress.addBooster(b.id)
                lastRewards = level.rewards
            }
            save()
            if (!hadClearedAll && hasClearedAllLevels(level.city)) {
                Tracker.log(Tracker.Event.CityClear(level.city))
                nextCity?.let { pendingFlight = Flight(level.city, it.id) }
            }
            if (hasClearedEverything && !prefs.getBoolean(SEEN_ENDING, false)) {
                prefs.edit().putBoolean(SEEN_ENDING, true).apply()
                isFirstEnding = true
                wantsEnding = true
            }
        }
        return stars
    }

    private fun save() {
        changed()
        if (!canSave) return
        try {
            store.save(progress)
        } catch (e: Exception) {
            problem = tr("진행을 저장하지 못했어요.")
        }
    }
}
