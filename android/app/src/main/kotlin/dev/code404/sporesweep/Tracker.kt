package dev.code404.sporesweep

import android.content.Context
import android.os.Bundle
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics

/**
 * 플레이 기록을 Firebase로 보낸다(사건의 목록은 :game의 Tracker).
 *
 * Firebase 설정 파일(`app/google-services.json`)이 있어야 보낸다. 디버그 빌드에서는 보내지 않고 로그에만 적으며,
 * 실행 인자 analytics를 주면 디버그 빌드에서도 보낸다.
 */
object FirebaseTracker {
    /** 앱을 시작할 때 한 번 부른다. */
    fun start(context: Context, args: DebugArgs) {
        if (FirebaseApp.getApps(context).isEmpty()) return
        val sends = !BuildConfig.DEBUG || args.bool("analytics")
        // 켜고 끈 값은 다음 실행까지 남으므로, 보내지 않을 때도 끈다고 분명히 적는다.
        val firebase = FirebaseAnalytics.getInstance(context).also { it.setAnalyticsCollectionEnabled(sends) }
        if (!sends) return
        Platform.analytics = { name, parameters ->
            val bundle = Bundle()
            for ((key, value) in parameters) {
                when (value) {
                    is Int -> bundle.putLong(key, value.toLong())
                    is Long -> bundle.putLong(key, value)
                    else -> bundle.putString(key, value.toString())
                }
            }
            firebase.logEvent(name, bundle)
        }
    }
}
