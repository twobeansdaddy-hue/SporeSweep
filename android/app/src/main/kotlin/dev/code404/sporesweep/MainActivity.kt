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
        Assets.install(this)
        Sound.install(this)
        Music.install(this)
        val started = System.nanoTime()
        val args = DebugArgs(intent.extras)
        Tracker.start(this, args)
        RewardedAds.start(this, fake = args.bool("fakeAds"))
        RewardedAds.activity = this
        model = AppModel(this, args)
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
