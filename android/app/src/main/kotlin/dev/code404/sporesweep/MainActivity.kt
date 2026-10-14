package dev.code404.sporesweep

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import dev.code404.sporesweep.ui.GameBackground
import dev.code404.sporesweep.ui.GameText
import dev.code404.sporesweep.ui.TitleScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Assets.install(this)
        setContent {
            var started by remember { mutableStateOf(false) }
            GameBackground {
                if (!started) TitleScreen { started = true } else GameText("도시 화면은 아직 없어요", 20f)
            }
        }
    }
}
