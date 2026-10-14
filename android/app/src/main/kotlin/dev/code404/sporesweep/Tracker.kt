package dev.code404.sporesweep

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics

/**
 * 플레이 기록(iOS 판 Tracker.swift). 사건의 이름과 값은 iOS 판과 같다.
 *
 * Firebase 설정 파일(`app/google-services.json`)이 있어야 보낸다. 디버그 빌드에서는 보내지 않고 로그에만 적으며,
 * 실행 인자 analytics를 주면 디버그 빌드에서도 보낸다.
 */
object Tracker {
    sealed class Event(val name: String, val parameters: Map<String, Any> = emptyMap()) {
        data object IntroDone : Event("intro_done")
        class LevelStart(city: String, level: Int, boosters: Int) : Event("level_start", mapOf("city" to city, "level" to level, "boosters" to boosters))
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

    private var analytics: FirebaseAnalytics? = null

    /** 앱을 시작할 때 한 번 부른다. */
    fun start(context: Context, args: DebugArgs) {
        if (FirebaseApp.getApps(context).isEmpty()) return
        val sends = !BuildConfig.DEBUG || args.bool("analytics")
        if (!sends) return
        analytics = FirebaseAnalytics.getInstance(context).also { it.setAnalyticsCollectionEnabled(true) }
    }

    fun log(event: Event) {
        val firebase = analytics
        if (firebase == null) {
            if (BuildConfig.DEBUG) Log.i("기록", "${event.name} ${event.parameters}")
            return
        }
        val bundle = Bundle()
        for ((key, value) in event.parameters) {
            when (value) {
                is Int -> bundle.putLong(key, value.toLong())
                else -> bundle.putString(key, value.toString())
            }
        }
        firebase.logEvent(event.name, bundle)
    }
}
