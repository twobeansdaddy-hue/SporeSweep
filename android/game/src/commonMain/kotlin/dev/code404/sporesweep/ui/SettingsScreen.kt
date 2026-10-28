package dev.code404.sporesweep.ui

import dev.code404.sporesweep.Platform
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Music
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.tr

/** 설정 화면(iOS 판 SettingsView). iCloud 저장 대신 안드로이드는 Play 게임즈에 저장한다. */
@Composable
fun SettingsScreen(model: AppModel, onClose: () -> Unit) {
    var music by remember { mutableStateOf(Music.isMusicEnabled) }
    var sound by remember { mutableStateOf(Sound.isSoundEnabled) }
    var haptics by remember { mutableStateOf(Sound.isHapticsEnabled) }
    var cloud by remember { mutableStateOf(model.isCloudEnabled) }
    var confirmsReset by remember { mutableStateOf(false) }
    var didResetTutorials by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxSize().background(Palette.backdrop)) {
        Column(Modifier.fillMaxSize().safeDrawingPadding(), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Box(Modifier.padding(top = 10.dp)) {
                GameHeader(tr("설정"), trailing = { IconButton(Icons.Filled.Close, "닫기") { Sound.play(GameSound.TAP); onClose() } })
            }
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Column(Modifier.fillMaxWidth().gamePanel().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        ChunkyToggle(tr("배경 음악"), music) { music = it; Music.isMusicEnabled = it }
                        ChunkyToggle(tr("효과음"), sound) { sound = it; Sound.isSoundEnabled = it; Sound.play(GameSound.TAP) }
                        ChunkyToggle(tr("진동"), haptics) { haptics = it; Sound.isHapticsEnabled = it; Sound.haptic(GameHaptic.LIGHT) }
                    }
                    Note(tr("다른 앱으로 음악을 듣고 있으면 배경 음악은 나오지 않아요."))
                }
                if (model.isCloudAvailable) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Column(Modifier.fillMaxWidth().gamePanel().padding(16.dp)) {
                            ChunkyToggle(tr("Google Play 게임즈에 저장"), cloud) { cloud = it; model.isCloudEnabled = it }
                        }
                        Note(tr("앱을 지웠다 다시 설치하거나 기기를 바꿔도 진행이 이어져요. 같은 Google 계정의 Play 게임즈로 맞춰져요."))
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    ChunkyButton(if (didResetTutorials) tr("다음 판부터 다시 보여 드려요") else tr("레벨 설명 다시 보기"), tint = GameTint.BLUE, fills = true, enabled = !didResetTutorials) {
                        Sound.play(GameSound.TAP)
                        model.resetTutorials()
                        didResetTutorials = true
                    }
                    Note(tr("새 규칙이 나오는 레벨을 시작할 때 설명이 다시 떠요."))
                }
                ChunkyButton(tr("인트로 다시 보기"), tint = GameTint.BLUE, fills = true) {
                    Sound.play(GameSound.TAP)
                    onClose()
                    model.wantsIntro = true
                }
                if (model.hasClearedEverything) {
                    ChunkyButton(tr("엔딩 다시 보기"), tint = GameTint.BLUE, fills = true) {
                        Sound.play(GameSound.TAP)
                        onClose()
                        model.wantsEnding = true
                    }
                }
                if (Platform.isDebug) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        ChunkyButton(if (model.isLabMode) tr("서울로 돌아가기") else tr("시험판 레벨 해 보기"), tint = GameTint.GOLD, fills = true) {
                            Sound.play(GameSound.TAP)
                            model.setLabMode(!model.isLabMode)
                            onClose()
                        }
                        ChunkyButton(tr("엔딩 보기"), tint = GameTint.GOLD, fills = true) {
                            Sound.play(GameSound.TAP)
                            onClose()
                            model.wantsEnding = true
                        }
                    }
                    Column(Modifier.fillMaxWidth().gamePanel().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        GameText("광고 시험", 15f, Modifier.fillMaxWidth(), align = TextAlign.Start)
                        var notice by remember { mutableStateOf("") }
                        ChunkyButton("생명 비우기", tint = GameTint.GOLD, size = 14f, fills = true) {
                            Sound.play(GameSound.TAP)
                            model.drainLives()
                            notice = "생명을 비웠어요. 레벨을 누르거나 하트를 누르면 '광고 보고 생명 +1'이 나와요."
                        }
                        ChunkyButton("아이템 비우기", tint = GameTint.GOLD, size = 14f, fills = true) {
                            Sound.play(GameSound.TAP)
                            model.drainTools()
                            notice = "아이템을 비웠어요. 판에서 아이템 단추를 누르면 광고가 나와요(하루 2번)."
                        }
                        ChunkyButton(if (model.debugMoves > 0) "이동 2번으로 시작: 켜짐" else "이동 2번으로 시작: 꺼짐", tint = if (model.debugMoves > 0) GameTint.PINK else GameTint.GOLD, size = 14f, fills = true) {
                            Sound.play(GameSound.TAP)
                            model.debugMoves = if (model.debugMoves > 0) 0 else 2
                            notice = if (model.debugMoves > 0) "다음 판부터 이동 2번으로 시작해요. 다 쓰면 '광고 보고 이동 +5'가 나와요." else "이동 횟수를 레벨대로 되돌렸어요."
                        }
                        if (notice.isNotEmpty()) Note(notice)
                        Note("시험 광고만 나와요. 생명과 아이템을 비운 것은 진행에 저장돼요. 개발용 빌드에만 있어요.")
                    }
                    Column(Modifier.fillMaxWidth().gamePanel().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        GameText(tr("도시 바로 가기"), 15f, Modifier.fillMaxWidth(), align = TextAlign.Start)
                        model.cities.chunked(3).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                for (city in row) {
                                    Box(Modifier.weight(1f)) {
                                        ChunkyButton(city.name, tint = if (model.city?.id == city.id) GameTint.PINK else GameTint.GOLD, size = 14f, fills = true) {
                                            Sound.play(GameSound.TAP)
                                            model.visit(city.id)
                                            onClose()
                                        }
                                    }
                                }
                                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                        Note(tr("잠금과 상관없이 그 도시로 가고, 그 도시의 레벨이 모두 열려요. 앱을 다시 켜면 원래대로 돌아가요. 거기서 깬 판의 기록은 남아요. 개발용 빌드에만 있어요."))
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    ChunkyButton(tr("처음부터 다시 하기"), tint = GameTint.SLATE, fills = true) { Sound.play(GameSound.TAP); confirmsReset = true }
                    Note(tr("레벨 기록과 복원한 랜드마크가 모두 지워져요."))
                }
            }
        }
        AnimatedVisibility(confirmsReset, enter = fadeIn(), exit = fadeOut()) {
            CardOverlay(dim = 0.6f, radius = 20.dp) {
                GameText(tr("정말 처음부터 다시 할까요?"), 19f)
                GameText(tr("레벨 기록과 복원한 랜드마크가 사라지고 되돌릴 수 없어요."), 14f, color = Color.White.copy(alpha = 0.7f))
                Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { ChunkyButton(tr("그만두기"), tint = GameTint.BLUE, size = 15f, fills = true) { Sound.play(GameSound.TAP); confirmsReset = false } }
                    Box(Modifier.weight(1f)) {
                        ChunkyButton(tr("모두 지우기"), tint = GameTint.PINK, size = 15f, fills = true) {
                            Sound.play(GameSound.TAP)
                            model.resetProgress()
                            onClose()
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Note(text: String) = GameText(text, 12f, Modifier.fillMaxWidth().padding(horizontal = 6.dp), color = Color.White.copy(alpha = 0.55f), align = TextAlign.Start)

/** 통통한 스위치. */
@Composable
fun ChunkyToggle(label: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    val knob by animateDpAsState(if (isOn) 29.dp else 3.dp, label = "knob")
    Row(Modifier.fillMaxWidth().toggleable(isOn, role = Role.Switch) { onChange(it) }, verticalAlignment = Alignment.CenterVertically) {
        GameText(label, 17f, align = TextAlign.Start)
        Spacer(Modifier.weight(1f))
        Box(Modifier.width(58.dp).height(32.dp).background(if (isOn) GameTint.GREEN.bottom else Color.Black.copy(alpha = 0.35f), RoundedCornerShape(50))) {
            Box(Modifier.offset(x = knob, y = 3.dp).size(26.dp).background(Color.White, CircleShape))
        }
    }
}
