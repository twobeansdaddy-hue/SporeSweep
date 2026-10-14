package dev.code404.sporesweep

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import dev.code404.sporesweep.board.BoardScene
import dev.code404.sporesweep.stage.StageView
import dev.code404.sporesweep.ui.GameBackground
import dev.code404.sporesweep.ui.TitleScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Assets.install(this)
        // 개발용: `adb shell am start ... --es city tokyo --ei level 2 --ez autoplay true`
        val city = intent.getStringExtra("city") ?: "seoul"
        val levelNumber = intent.getIntExtra("level", 1)
        val autoplay = intent.getBooleanExtra("autoplay", false)
        val skipTitle = intent.hasExtra("level")
        setContent {
            var started by remember { mutableStateOf(skipTitle) }
            GameBackground {
                if (!started) {
                    TitleScreen { started = true }
                } else {
                    val scene = remember {
                        val level = Assets.levels(city)[levelNumber - 1]
                        BoardScene(level.makeState()).also {
                            it.starScores = level.starScores
                            it.autoPlays = autoplay
                        }
                    }
                    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                        StageView(scene, Modifier.fillMaxWidth().weight(1f))
                    }
                }
            }
        }
    }
}
