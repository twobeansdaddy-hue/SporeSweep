package dev.code404.sporesweep.ui

import dev.code404.sporesweep.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.GameTrack
import dev.code404.sporesweep.Music
import dev.code404.sporesweep.Tracker
import dev.code404.sporesweep.core.RegionCatalog

/** 도시 화면 위에 쌓이는 화면. */
sealed interface Screen {
    data object City : Screen
    data class Game(val index: Int) : Screen
    data object Restoration : Screen
}

private enum class Phase { TITLE, INTRO, MAIN }

/**
 * 앱의 뼈대(iOS 판 RootView). 타이틀에서 시작해, 처음이면 인트로를 거쳐 도시 화면으로 간다.
 * 도시 화면에서 레벨을 고르면 게임 화면으로 들어간다.
 */
@Composable
fun RootScreen(model: AppModel) {
    val args = model.args
    var phase by remember {
        mutableStateOf(
            when {
                args.bool("intro") -> Phase.INTRO
                args.bool("skipTitle") || args.int("level") > 0 || args.bool("allStars") || args.has("landmarkParts") ||
                    args.has("city") || args.bool("map") || args.has("flight") || args.bool("world") || args.has("region") || args.bool("ending") -> Phase.MAIN
                else -> Phase.TITLE
            },
        )
    }
    var screen by remember { mutableStateOf<Screen>(if (args.int("level") > 0) Screen.Game(args.int("level") - 1) else Screen.City) }
    var showsSettings by remember { mutableStateOf(false) }

    LaunchedEffect(phase, screen) {
        Music.play(
            when {
                phase != Phase.MAIN -> GameTrack.INTRO
                screen is Screen.Game -> GameTrack.GAME
                else -> GameTrack.CITY
            },
        )
    }
    LaunchedEffect(model.wantsIntro) {
        if (model.wantsIntro) {
            model.wantsIntro = false
            screen = Screen.City
            phase = Phase.INTRO
        }
    }

    Box(Modifier.fillMaxSize()) {
        AnimatedContent(phase, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "phase") { current ->
            when (current) {
                Phase.TITLE -> TitleScreen {
                    phase = if (model.preferences.getBoolean(AppModel.SEEN_INTRO, false)) Phase.MAIN else Phase.INTRO
                }
                Phase.INTRO -> IntroScreen {
                    if (!model.preferences.getBoolean(AppModel.SEEN_INTRO, false)) Tracker.log(Tracker.Event.IntroDone)
                    model.preferences.edit().putBoolean(AppModel.SEEN_INTRO, true).apply()
                    phase = Phase.MAIN
                }
                Phase.MAIN -> AnimatedContent(screen, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "screen") { shown ->
                    when (shown) {
                        Screen.City -> CityScreen(model, onSelect = { screen = Screen.Game(it) }, onRestore = { screen = Screen.Restoration }, onSettings = { showsSettings = true })
                        is Screen.Game -> GameScreen(model, shown.index) { screen = Screen.City }
                        Screen.Restoration -> {
                            BackHandler { screen = Screen.City }
                            RestorationScreen(model) { screen = Screen.City }
                        }
                    }
                }
            }
        }
        if (phase == Phase.MAIN) {
            // 엔딩. 결과 화면을 닫고 도시 화면으로 돌아온 뒤에 뜬다.
            AnimatedVisibility(model.wantsEnding && screen == Screen.City, enter = fadeIn(), exit = fadeOut()) {
                LaunchedEffect(Unit) { Tracker.log(Tracker.Event.Ending(model.isFirstEnding)) }
                EndingScreen(model) {
                    model.wantsEnding = false
                    model.isFirstEnding = false
                    Music.play(GameTrack.CITY)
                }
            }
            // 지도. 도시를 고를 때와, 도시의 레벨을 모두 깨서 다음 도시로 날아갈 때 뜬다.
            val flight = model.pendingFlight
            val shownMap: AppModel.MapScreen? = if (flight != null && screen == Screen.City) {
                val region = RegionCatalog.regionOfCity(flight.from)
                if (model.crossesRegions(flight)) AppModel.MapScreen.World else region?.let { AppModel.MapScreen.RegionMap(it.id) }
            } else {
                model.mapScreen
            }
            val close = {
                model.pendingFlight = null
                model.mapScreen = null
                screen = Screen.City
            }
            AnimatedVisibility(shownMap != null, enter = fadeIn(), exit = fadeOut()) {
                when (val map = shownMap) {
                    AppModel.MapScreen.World -> WorldScreen(model, model.pendingFlight?.takeIf { model.crossesRegions(it) }, close)
                    is AppModel.MapScreen.RegionMap -> model.regions.firstOrNull { it.id == map.id }?.let { MapScreen(model, it, model.pendingFlight, close) }
                    null -> {}
                }
            }
            AnimatedVisibility(showsSettings, enter = fadeIn(), exit = fadeOut()) {
                BackHandler { showsSettings = false }
                SettingsScreen(model) { showsSettings = false }
            }
        }
    }
}
