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
        model = AppModel(this, DebugArgs(intent.extras))
        android.util.Log.i("시작", "AppModel ${(System.nanoTime() - started) / 1_000_000}ms")
        setContent {
            GameBackground { RootScreen(model) }
        }
    }

    override fun onResume() {
        super.onResume()
        Music.refresh()
    }

    override fun onPause() {
        super.onPause()
        Music.suspend()
    }
}
