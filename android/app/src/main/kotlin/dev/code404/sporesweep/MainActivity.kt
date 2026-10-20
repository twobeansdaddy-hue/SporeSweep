package dev.code404.sporesweep

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.code404.sporesweep.ui.GameBackground
import dev.code404.sporesweep.ui.RootScreen

class MainActivity : ComponentActivity() {
    private lateinit var model: AppModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        AndroidPlatform.install(this, BuildConfig.DEBUG)
        Assets.install()
        Sound.install()
        val started = System.nanoTime()
        val extras = intent.extras
        val args = DebugArgs(extras?.keySet()?.associateWith { extras.get(it).toString() } ?: emptyMap())
        FirebaseTracker.start(this, args)
        RewardedAds.start(this, fake = args.bool("fakeAds"))
        RewardedAds.activity = this
        Platform.ads = RewardedAds
        model = AppModel(args)
        android.util.Log.i("시작", "AppModel ${(System.nanoTime() - started) / 1_000_000}ms")
        setContent {
            GameBackground { RootScreen(model) }
        }
    }

    override fun onResume() {
        super.onResume()
        Music.refresh()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (RewardedAds.activity === this) RewardedAds.activity = null
    }

    override fun onPause() {
        super.onPause()
        Music.suspend()
    }
}
