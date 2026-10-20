package dev.code404.sporesweep

/**
 * 플레이 기록(iOS 판 Tracker.swift). 사건의 이름과 값은 iOS 판과 같다.
 * 보내는 곳은 플랫폼이 정한다(Platform.analytics). 정하지 않았으면 개발 빌드에서 로그에만 적는다.
 */
object Tracker {
    sealed class Event(val name: String, val parameters: Map<String, Any> = emptyMap()) {
        data object IntroDone : Event("intro_done")
        class LevelStart(city: String, level: Int, boosters: Int, seed: Long) :
            Event("level_start", mapOf("city" to city, "level" to level, "boosters" to boosters, "seed" to seed))
        class LevelEnd(city: String, level: Int, result: String, stars: Int, score: Int, movesLeft: Int, materialsLeft: Int, continued: Boolean) :
            Event("level_end", mapOf("city" to city, "level" to level, "result" to result, "stars" to stars, "score" to score, "moves_left" to movesLeft, "materials_left" to materialsLeft, "continued" to if (continued) 1 else 0))
        class ContinueOffer(city: String, level: Int, materialsLeft: Int) : Event("continue_offer", mapOf("city" to city, "level" to level, "materials_left" to materialsLeft))
        class AdReward(reward: String) : Event("ad_reward", mapOf("reward" to reward))
        class AdSkip(reward: String) : Event("ad_skip", mapOf("reward" to reward))
        class AdFail(reward: String) : Event("ad_fail", mapOf("reward" to reward))
        data object LivesOut : Event("lives_out")
        class ToolUse(tool: String, city: String, level: Int) : Event("tool_use", mapOf("tool" to tool, "city" to city, "level" to level))
        class DailyGift(day: Int) : Event("daily_gift", mapOf("day" to day))
        class LandmarkRestore(city: String, part: String, completed: Boolean) : Event("landmark_restore", mapOf("city" to city, "part" to part, "completed" to if (completed) 1 else 0))
        class CityClear(city: String) : Event("city_clear", mapOf("city" to city))
        class Ending(first: Boolean) : Event("ending", mapOf("first" to if (first) 1 else 0))
    }

    fun log(event: Event) {
        val send = Platform.analytics
        if (send == null) {
            if (Platform.isDebug) Platform.log("기록", "${event.name} ${event.parameters}")
            return
        }
        send(event.name, event.parameters)
    }
}
