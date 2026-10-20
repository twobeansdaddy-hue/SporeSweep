package dev.code404.sporesweep

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import kotlinx.coroutines.delay

/**
 * 보상형 광고(iOS 판 RewardedAds). 광고 SDK는 이 파일에서만 부른다.
 * 광고를 미리 하나 불러 두고, 보여주고 나면 다음 것을 다시 불러 둔다.
 *
 * 디버그 빌드와 `-PtestAds`로 만든 빌드는 구글의 시험용 광고 단위를 쓴다. 개발하거나 시험하면서
 * 실제 광고를 보거나 누르면 무효 트래픽으로 계정이 정지될 수 있기 때문이다.
 */
object RewardedAds : AdService {

    /** 실제 광고를 쓰는지. 디버그 빌드에서 실행 인자 fakeAds를 주면 자리 표시 광고만 쓴다. */
    override var isEnabled = true
        private set

    private val unitID get() = if (BuildConfig.DEBUG || BuildConfig.TEST_ADS) BuildConfig.TEST_REWARDED_AD_UNIT else BuildConfig.REWARDED_AD_UNIT

    private lateinit var context: Context
    /** 광고를 띄울 화면. MainActivity가 정한다. */
    var activity: Activity? = null
    private var ad: RewardedAd? = null
    private var isLoading = false
    /** 잇달아 실패한 횟수. 실패하면 조금씩 더 기다렸다가 다시 부른다. */
    private var failures = 0
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    fun start(context: Context, fake: Boolean) {
        this.context = context.applicationContext
        isEnabled = !fake
        if (!isEnabled) return
        MobileAds.initialize(context) {}
        load()
    }

    val isReady get() = ad != null

    fun load() {
        if (!isEnabled || ad != null || isLoading) return
        isLoading = true
        RewardedAd.load(context, unitID, AdRequest.Builder().build(), object : RewardedAdLoadCallback() {
            override fun onAdLoaded(loaded: RewardedAd) {
                ad = loaded
                isLoading = false
                failures = 0
                note("불러옴")
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                isLoading = false
                failures += 1
                note("불러오지 못함: ${error.message}")
                // 앱을 막 켰을 때 광고의 실행 환경이 덜 준비돼 실패하는 일이 있다. 세 번까지 점점 늦춰 다시 부른다.
                if (failures <= 3) handler.postDelayed({ load() }, failures * 3_000L)
            }
        })
    }

    /** 준비될 때까지 잠깐 기다린다. 준비됐으면 참. */
    override suspend fun waitUntilReady(seconds: Double): Boolean {
        load()
        val end = System.currentTimeMillis() + (seconds * 1000).toLong()
        while (ad == null && isLoading && System.currentTimeMillis() < end) delay(200)
        return ad != null
    }

    /** 불러 둔 광고를 띄운다. 끝나면 결과를 알린다. */
    override fun show(onFinish: (AdService.Outcome) -> Unit) {
        val current = ad
        val host = activity
        if (current == null || host == null) {
            onFinish(AdService.Outcome.FAILED)
            return
        }
        ad = null
        var earned = false
        current.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                note(if (earned) "닫음, 보상 있음" else "닫음, 보상 없음")
                onFinish(if (earned) AdService.Outcome.REWARDED else AdService.Outcome.SKIPPED)
                load()
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                note("띄우지 못함: ${error.message}")
                onFinish(AdService.Outcome.FAILED)
                load()
            }
        }
        note("띄움")
        current.show(host) {
            note("보상 받음")
            earned = true
        }
    }

    private fun note(text: String) {
        if (BuildConfig.DEBUG) Log.i("광고", text)
    }
}
