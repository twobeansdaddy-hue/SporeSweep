package dev.code404.sporesweep.web

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.window.ComposeViewport
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Assets
import dev.code404.sporesweep.DebugArgs
import dev.code404.sporesweep.Platform
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.stage.LabelNode
import dev.code404.sporesweep.ui.GameBackground
import dev.code404.sporesweep.ui.LandmarkArt
import dev.code404.sporesweep.ui.RootScreen
import kotlinx.browser.document

/** 처음 화면에 바로 필요한 그림. 나머지는 쓰일 때 받는다. */
private val firstImages = listOf("title_art", "logo") + (0..4).map { "landmark_spore_$it" } + (1..5).map { "intro_$it" }

/** 앱을 띄운 뒤 쉬는 동안 받아 둘 그림(지도, 엔딩). */
private val laterImages = listOf("map_world", "map_world_polluted", "ending") +
    listOf("east_asia", "south_asia", "mideast_africa", "south_europe", "west_europe", "north_america", "south_america", "oceania")
        .flatMap { listOf("map_$it", "map_${it}_polluted") }

private val landmarkLayers = listOf("bg_restored", "bg_ruined", "building_restored", "building_ruined", "trees_restored", "trees_ruined")

private fun jsReady(): Unit = js("window.sporeReady && window.sporeReady()")

@OptIn(ExperimentalComposeUiApi::class)
fun main() {
    WebPlatform.install()
    ComposeViewport(document.getElementById("game")!!) { WebApp() }
}

@Composable
private fun WebApp() {
    var model by remember { mutableStateOf<AppModel?>(null) }
    LaunchedEffect(Unit) {
        WebAssets.start()
        WebAssets.load(
            listOf("fonts/Jua-Regular.ttf") + Platform.assets.list("sprites").map { "sprites/$it" } +
                firstImages.mapNotNull { name -> Platform.assets.list("images").firstOrNull { it.substringBeforeLast('.') == name }?.let { "images/$it" } },
        )
        Assets.install()
        LabelNode.fontFamily = Assets.gameFont
        Sound.install()
        val created = AppModel(DebugArgs(WebPlatform.query))
        // 지금 도시의 랜드마크 그림을 먼저 받아 둔다. 도시 화면이 바로 뜬다.
        val prefix = created.city?.let { LandmarkArt.of(it.id)?.prefix }
        if (prefix != null) WebAssets.load(landmarkLayers.mapNotNull { layer -> imagePath("${prefix}_$layer") })
        model = created
        jsReady()
        Assets.prefetchImages(laterImages)
    }
    val current = model ?: return
    GameBackground { RootScreen(current) }
}

private fun imagePath(name: String) = Platform.assets.list("images").firstOrNull { it.substringBeforeLast('.') == name }?.let { "images/$it" }
