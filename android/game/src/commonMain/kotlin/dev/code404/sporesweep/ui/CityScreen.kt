package dev.code404.sporesweep.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.core.Landmark
import dev.code404.sporesweep.core.RestoreBlocker
import dev.code404.sporesweep.tr

/** 도시 화면. 위에 랜드마크를 고정해 두고, 그 아래에 복원 버튼과 레벨 목록을 둔다(iOS 판 CityView). */
@Composable
fun CityScreen(model: AppModel, onSelect: (Int) -> Unit, onRestore: () -> Unit, onSettings: () -> Unit) {
    model.revision
    var showsLives by remember { mutableStateOf(false) }
    var showsDailyGift by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (model.canClaimDailyGift && model.pendingFlight == null && !model.wantsEnding && model.mapScreen == null) showsDailyGift = true
    }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().safeDrawingPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            GameHeader(
                if (model.isLabMode) tr("시험판") else model.city?.name ?: "",
                leading = {
                    IconButton(Icons.Filled.Map, "지도") {
                        Sound.play(GameSound.TAP)
                        model.mapScreen = model.currentRegion?.let { AppModel.MapScreen.RegionMap(it.id) } ?: AppModel.MapScreen.World
                    }
                },
                trailing = {
                    IconButton(Icons.Filled.Settings, "설정") {
                        Sound.play(GameSound.TAP)
                        onSettings()
                    }
                },
            )
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                model.problem?.let {
                    GameText(it, 13f, Modifier.fillMaxWidth().background(Color.Red.copy(alpha = 0.35f), RoundedCornerShape(10.dp)).padding(10.dp), align = TextAlign.Start)
                }
                LandmarkPanel(model)
                model.city?.landmark?.let { landmark ->
                    LandmarkHeader(model, landmark)
                    if (model.isFullyRestored) {
                        Row(
                            Modifier.background(GameTint.GREEN.lip.copy(alpha = 0.45f), RoundedCornerShape(50))
                                .border(1.5.dp, GameTint.GREEN.top.copy(alpha = 0.5f), RoundedCornerShape(50))
                                .padding(horizontal = 18.dp, vertical = 9.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Icon(Icons.Filled.Verified, null, tint = GameTint.GREEN.top, modifier = Modifier.size(18.dp))
                            GameText(tr("복원 완료!"), 17f, color = GameTint.GREEN.top)
                        }
                    } else {
                        val canRestore = landmark.parts.any { model.blocker(it) == null }
                        WideButton(
                            tint = if (canRestore) GameTint.PINK else GameTint.BLUE,
                            onClick = { Sound.play(GameSound.TAP); onRestore() },
                        ) {
                            Icon(Icons.Filled.Build, null, tint = Color.White, modifier = Modifier.size(18.dp))
                            GameText(tr("복원하러 가기"), 17f)
                            if (canRestore) {
                                GameText(tr("지금 할 수 있어요!"), 12f, Modifier.background(Color.White.copy(alpha = 0.28f), RoundedCornerShape(50)).padding(horizontal = 8.dp, vertical = 3.dp))
                            }
                            Spacer(Modifier.weight(1f))
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.White)
                        }
                    }
                }
            }
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GameText(if (model.isLabMode) tr("시험판 레벨") else tr("레벨"), 18f)
                    Spacer(Modifier.weight(1f))
                    if (model.usesLives) {
                        Box(
                            Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.3f))
                                .selectable(false, role = Role.Button) { Sound.play(GameSound.TAP); showsDailyGift = true }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                        ) {
                            Icon(Icons.Filled.CardGiftcard, tr("오늘의 선물"), tint = if (model.canClaimDailyGift) Palette.star else Color.White.copy(alpha = 0.55f), modifier = Modifier.size(16.dp))
                        }
                        Box(Modifier.selectable(false, role = Role.Button) { Sound.play(GameSound.TAP); showsLives = true }) { LivesBadge(model) }
                    }
                }
                model.levels.indices.chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        for (index in row) {
                            LevelCell(index + 1, model.progress.stars(model.levels[index].id), model.isUnlocked(index), Modifier.weight(1f)) {
                                Sound.play(GameSound.TAP)
                                if (model.canStartLevel) onSelect(index) else showsLives = true
                            }
                        }
                        repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
        AnimatedVisibility(showsDailyGift, enter = fadeIn(), exit = fadeOut()) { DailyGiftView(model) { showsDailyGift = false } }
        AnimatedVisibility(showsLives, enter = fadeIn(), exit = fadeOut()) { LivesPopup(model) { showsLives = false } }
    }
}

/** 가로를 꽉 채우는 통통한 버튼. 안에 아이콘과 글자를 늘어놓는다. */
@Composable
fun WideButton(tint: GameTint, enabled: Boolean = true, onClick: () -> Unit, content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shown = if (enabled) tint else GameTint.SLATE
    Box(
        Modifier.fillMaxWidth().padding(bottom = 4.dp).chunky(shown, radius = 14.dp, pressed = pressed)
            .selectable(false, enabled = enabled, interactionSource = interaction, indication = null, role = Role.Button) { onClick() }
            .alpha(if (enabled) 1f else 0.7f),
    ) {
        Row(
            Modifier.offset(y = if (pressed) 3.dp else 0.dp).padding(horizontal = 17.dp, vertical = 10.5.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), content = content,
        )
    }
}

/** 복원 화면. 위에 랜드마크를 고정해 두고, 그 아래의 부위 목록만 움직인다. */
@Composable
fun RestorationScreen(model: AppModel, onBack: () -> Unit) {
    model.revision
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().safeDrawingPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            GameHeader(tr("%@ 복원", model.city?.landmark?.name ?: ""), leading = {
                IconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "도시로 돌아가기") { Sound.play(GameSound.TAP); onBack() }
            })
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                LandmarkPanel(model)
                model.city?.landmark?.let { LandmarkHeader(model, it) }
            }
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val landmark = model.city?.landmark
                if (landmark != null) for (part in landmark.parts) RestorationRow(model, landmark, part)
            }
        }
        AnimatedVisibility(model.justCompletedLandmark, enter = fadeIn(), exit = fadeOut()) {
            CardOverlay(dim = 0.6f) {
                GameText(tr("복원 완료!"), 26f, color = Palette.star)
                GameText(tr("%@을 되살렸어요. 선물로 시작 부스터를 받았어요!", model.city?.landmark?.name ?: ""), 15f)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { for (b in AppModel.completionRewards) BoosterIcon(b, 44f) }
                ChunkyButton(tr("좋아요!"), size = 18f) {
                    Sound.play(GameSound.TAP)
                    model.justCompletedLandmark = false
                }
            }
        }
    }
}

@Composable
private fun RestorationRow(model: AppModel, landmark: Landmark, part: Landmark.Part) {
    val blocker = model.blocker(part)
    Row(Modifier.fillMaxWidth().gamePanel(14.dp).padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            GameText(part.name, 17f, align = TextAlign.Start)
            val note = when (blocker) {
                is RestoreBlocker.Requires -> tr("%@부터 복원해야 해요", landmark.parts.firstOrNull { it.id == blocker.partID }?.name ?: blocker.partID)
                is RestoreBlocker.NotEnoughStars -> tr("별이 %lld개 더 필요해요", blocker.short)
                else -> null
            }
            note?.let { GameText(it, 12f, color = Color.White.copy(alpha = 0.6f), align = TextAlign.Start) }
        }
        if (blocker == RestoreBlocker.AlreadyRestored) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Filled.CheckCircle, null, tint = GameTint.GREEN.top, modifier = Modifier.size(16.dp))
                GameText(tr("복원 완료"), 14f, color = GameTint.GREEN.top)
            }
        } else {
            ChunkyButton("★ ${part.cost} ${tr("복원")}", tint = GameTint.GOLD, size = 14f, enabled = blocker == null) {
                Sound.play(GameSound.RESTORE)
                Sound.haptic(GameHaptic.SUCCESS)
                model.restore(part)
            }
        }
    }
}

/** 랜드마크 그림. 도시 화면과 복원 화면 위에 같은 크기로 놓는다. */
@Composable
fun LandmarkPanel(model: AppModel) {
    val art = model.city?.let { LandmarkArt.of(it.id) }
    val shown = model.args.string("landmarkParts")?.let { list ->
        if (list == "all") art?.partIDs ?: emptySet() else list.split(",").toSet()
    } ?: model.restoredParts
    Box(
        Modifier.fillMaxWidth().aspectRatio(1.5f).clip(RoundedCornerShape(18.dp)).background(Palette.panel)
            .border(2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(18.dp)),
    ) {
        if (art != null) LandmarkView(shown, art, Modifier.fillMaxSize())
    }
}

@Composable
private fun LandmarkHeader(model: AppModel, landmark: Landmark) {
    val restored = landmark.parts.count { it.id in model.restoredParts }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
        GameText(if (model.isFullyRestored) landmark.name else tr("%@ · %lld/%lld 복원", landmark.name, restored, landmark.parts.size), 20f)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(Icons.Filled.Star, null, tint = Palette.star, modifier = Modifier.size(15.dp))
            GameText(tr("쓸 수 있는 별 %lld개", model.availableStars), 14f, color = Palette.star)
            GameText(tr("· 모은 별 %lld/%lld", model.earnedStars, model.levels.size * 3), 14f, color = Color.White.copy(alpha = 0.6f))
        }
    }
}

@Composable
private fun LevelCell(number: Int, stars: Int, isUnlocked: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val tint = if (!isUnlocked) GameTint.SLATE else if (stars == 0) GameTint.PINK else GameTint.BLUE
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Box(
        modifier.padding(bottom = 4.dp).chunky(tint, radius = 16.dp, pressed = pressed)
            .selectable(false, enabled = isUnlocked, interactionSource = interaction, indication = null, role = Role.Button) { onClick() }
            .alpha(if (isUnlocked) 1f else 0.55f).heightIn(min = 66.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(Modifier.offset(y = if (pressed) 3.dp else 0.dp).padding(vertical = 6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (isUnlocked) {
                GameText("$number", 26f)
                StarsView(stars, 13f)
            } else {
                Icon(Icons.Filled.Lock, null, tint = Color.White, modifier = Modifier.size(20.dp))
                GameText("$number", 13f)
            }
        }
    }
}
