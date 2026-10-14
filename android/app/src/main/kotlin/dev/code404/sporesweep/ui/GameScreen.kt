package dev.code404.sporesweep.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.QuestionMark
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.Tracker
import dev.code404.sporesweep.board.BoardScene
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.core.Block
import dev.code404.sporesweep.core.BlockKind
import dev.code404.sporesweep.core.Booster
import dev.code404.sporesweep.core.GameState
import dev.code404.sporesweep.core.GameStatus
import dev.code404.sporesweep.core.Level
import dev.code404.sporesweep.core.Orientation
import dev.code404.sporesweep.core.Position
import dev.code404.sporesweep.core.Tool
import dev.code404.sporesweep.stage.StageView
import dev.code404.sporesweep.tr
import java.text.NumberFormat

/** 결과 화면에 보여줄 내용. */
data class GameResult(
    val won: Boolean,
    val stars: Int,
    val score: Int,
    val isNewBest: Boolean,
    val movesRemaining: Int,
    val materialsRemaining: Int,
    val availableStars: Int,
    val rewards: List<Booster>,
)

fun formatted(value: Int): String = NumberFormat.getIntegerInstance().format(value)

/** 게임 화면. 레벨 하나를 플레이하고, 끝나면 결과를 보여준다(iOS 판 GameView). */
@Composable
fun GameScreen(model: AppModel, startIndex: Int, onExit: () -> Unit) {
    var levelIndex by remember { mutableIntStateOf(startIndex) }
    var scene by remember { mutableStateOf<BoardScene?>(null) }
    var result by remember { mutableStateOf<GameResult?>(null) }
    var problem by remember { mutableStateOf<String?>(null) }
    var tutorial by remember { mutableStateOf<String?>(null) }
    var showsStartCard by remember { mutableStateOf(false) }
    var chosenBoosters by remember { mutableStateOf(setOf<Booster>()) }
    var lostState by remember { mutableStateOf<GameState?>(null) }
    var usedContinue by remember { mutableStateOf(false) }
    var initialMoves by remember { mutableStateOf<Int?>(null) }
    var showsAd by remember { mutableStateOf(false) }
    var showsLives by remember { mutableStateOf(false) }
    var showsQuitConfirm by remember { mutableStateOf(false) }
    var armedTool by remember { mutableStateOf<Tool?>(null) }
    var adTool by remember { mutableStateOf<Tool?>(null) }
    var hudTick by remember { mutableIntStateOf(0) }
    model.revision

    val starGoal = model.levels.getOrNull(levelIndex)?.starScores ?: emptyList()
    // 판이 끝났을 때 부르는 함수 안에서도 그때의 씬을 보도록 값이 아니라 함수로 둔다.
    fun isTracked() = (scene?.autoPlays != true || model.args.bool("trackAutoplay")) && !model.isLabMode && levelIndex in model.levels.indices
    fun skipsContinueOffer() = scene?.autoPlays == true && !model.args.bool("offerContinue")

    fun logStart(boosters: Int) {
        if (!isTracked()) return
        Tracker.log(Tracker.Event.LevelStart(model.levels[levelIndex].city, levelIndex + 1, boosters))
    }

    fun logEnd(state: GameState?, outcome: String) {
        if (!isTracked() || state == null) return
        val level = model.levels[levelIndex]
        Tracker.log(
            Tracker.Event.LevelEnd(
                level.city, levelIndex + 1, outcome, if (outcome == "won") level.stars(state.score) else 0, state.score,
                state.movesRemaining ?: 0, state.materialsRemaining, usedContinue,
            ),
        )
    }

    fun conclude(state: GameState, level: Level) {
        logEnd(state, if (state.status == GameStatus.WON) "won" else "lost")
        if (state.status == GameStatus.LOST) model.loseLife()
        val bestBefore = model.progress.bestScore(level.id)
        val stars = model.record(state, level)
        result = GameResult(
            won = state.status == GameStatus.WON,
            stars = stars,
            score = state.score,
            isNewBest = state.status == GameStatus.WON && state.score > bestBefore,
            movesRemaining = state.movesRemaining ?: 0,
            materialsRemaining = state.materialsRemaining,
            availableStars = if (model.isFullyRestored) 0 else model.availableStars,
            rewards = model.lastRewards,
        )
    }

    fun finish(state: GameState, level: Level) {
        if (state.canContinue && !usedContinue && !skipsContinueOffer()) {
            if (isTracked()) Tracker.log(Tracker.Event.ContinueOffer(level.city, levelIndex + 1, state.materialsRemaining))
            lostState = state
        } else {
            conclude(state, level)
        }
    }

    fun start(boosters: List<Booster>, showsCard: Boolean) {
        result = null
        lostState = null
        usedContinue = false
        val level = model.levels.getOrNull(levelIndex)
        if (level == null) {
            scene = null
            problem = tr("레벨을 찾지 못했어요.")
            return
        }
        try {
            val state = level.makeState()
            state.apply(boosters)
            val autoPlays = model.args.bool("autoplay")
            val moves = model.args.int("moves").takeIf { it > 0 } ?: model.debugMoves
            if (moves > 0) state.movesRemaining = moves
            if (model.args.bool("showcase")) {
                val kinds = BlockKind.entries
                val rows = listOf(
                    listOf(Block.Timed(BlockKind.BRICK, 7), Block.Nest(2), Block.Timed(BlockKind.GLASS, 2), Block.Rubble, Block.Cocoon(BlockKind.BRICK), Block.Cocoon(BlockKind.GLASS), Block.Sludge, Block.Concrete(1)),
                    listOf(Block.Beam(Orientation.HORIZONTAL), Block.Beam(Orientation.VERTICAL), Block.Bomb, Block.Core) + kinds.take(3).map { Block.Caged(it) } + listOf(Block.Concrete(2)),
                    listOf(Block.Chained(BlockKind.BRICK), Block.Chained(BlockKind.GLASS), Block.Frozen(BlockKind.SCRAP), Block.Frozen(BlockKind.WOOD), Block.Boulder, Block.Vent(2), Block.Vent(1), Block.Egg),
                )
                state.shields = hashSetOf(Position(0, 5), Position(1, 5))
                rows.forEachIndexed { offset, row ->
                    row.forEachIndexed { column, block -> if (column < state.board.columns) state.board[column, 2 + offset] = block }
                }
            }
            val next = BoardScene(state)
            next.feedback = Sound
            next.starScores = level.starScores
            next.hintDelay = if (levelIndex == 0) 2.0 else 5.0
            next.autoPlays = autoPlays
            val speed = model.args.double("sceneSpeed")
            if (speed > 0) next.speed = speed
            next.onToolUsed = { tool ->
                if (isTracked()) Tracker.log(Tracker.Event.ToolUse(tool.name.lowercase(), level.city, levelIndex + 1))
                model.useTool(tool)
                armedTool = null
            }
            next.onFinish = { final -> finish(final, level) }
            next.onChange = { hudTick += 1 }
            armedTool = null
            scene = next
            initialMoves = state.movesRemaining
            problem = null
            if (showsCard) {
                tutorial = if (model.shouldShowTutorial(level)) level.tutorial else null
                chosenBoosters = emptySet()
                val ownsBooster = !model.isLabMode && Booster.entries.any { model.boosterCount(it) > 0 }
                showsStartCard = !autoPlays && (tutorial != null || ownsBooster)
                if (autoPlays) tutorial = null
                if (!showsStartCard) logStart(0)
            }
        } catch (e: Exception) {
            scene = null
            problem = "${tr("레벨 %lld을 열지 못했어요", levelIndex + 1)}: $e"
        }
    }

    fun begin() {
        model.levels.getOrNull(levelIndex)?.let { model.markTutorialSeen(it) }
        val used = model.useBoosters(chosenBoosters)
        chosenBoosters = emptySet()
        if (used.isNotEmpty()) start(used, showsCard = false)
        logStart(used.size)
        showsStartCard = false
        tutorial = null
    }

    fun resume() {
        if (lostState == null || scene?.continuePlaying(Booster.EXTRA_MOVE_COUNT) != true) return
        usedContinue = true
        lostState = null
    }

    fun giveUp() {
        val state = lostState ?: return
        val level = model.levels.getOrNull(levelIndex) ?: return
        lostState = null
        conclude(state, level)
    }

    val hasPlayed: Boolean = run {
        val s = scene ?: return@run false
        if (result != null || lostState != null || showsStartCard || s.state.status != GameStatus.PLAYING) false
        else s.state.score > 0 || s.state.movesRemaining != initialMoves
    }

    fun tapTool(tool: Tool) {
        val s = scene ?: return
        if (!s.canUseTools || result != null || lostState != null || showsStartCard) return
        Sound.play(GameSound.TAP)
        val count = if (model.isLabMode) 9 else model.toolCount(tool)
        if (count <= 0) {
            if (model.adToolsLeft > 0) adTool = tool
            return
        }
        if (tool == Tool.SHUFFLE) {
            armedTool = null
            s.useShuffle()
        } else {
            armedTool = if (armedTool == tool) null else tool
            s.armedTool = armedTool
        }
    }

    fun back() {
        Sound.play(GameSound.TAP)
        if (hasPlayed && model.usesLives) showsQuitConfirm = true else onExit()
    }

    LaunchedEffect(Unit) { if (scene == null) start(emptyList(), showsCard = true) }
    BackHandler { back() }

    Box(Modifier.fillMaxSize()) {
        // 그 도시의 풍경을 흐리게 깔아 둔다. 맑은 하늘을 복원했으면 밝은 풍경이, 아니면 오염된 풍경이 나온다.
        val art = model.city?.let { LandmarkArt.of(it.id) }
        if (!model.isLabMode && art != null) {
            AssetImage("${art.prefix}_bg_${if ("sky" in model.restoredParts) "restored" else "ruined"}", Modifier.fillMaxSize().blur(3.dp))
            Box(Modifier.fillMaxSize().background(Palette.backdrop, alpha = 0.3f))
        }
        Column(Modifier.fillMaxSize().safeDrawingPadding(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            GameHeader(
                tr("레벨 %lld", levelIndex + 1),
                leading = { IconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "도시로 돌아가기") { back() } },
                trailing = {
                    val text = model.levels.getOrNull(levelIndex)?.tutorial
                    if (text != null && result == null && !showsStartCard) {
                        IconButton(Icons.Filled.QuestionMark, "설명 보기") {
                            Sound.play(GameSound.TAP)
                            tutorial = text
                        }
                    }
                },
            )
            val current = scene
            if (current != null) {
                StageView(current, Modifier.fillMaxWidth().weight(1f))
                hudTick
                ToolBar(
                    counts = Tool.entries.associateWith { if (model.isLabMode) 9 else model.toolCount(it) },
                    armed = armedTool,
                    canGetByAd = model.adToolsLeft > 0,
                    onTap = ::tapTool,
                    modifier = Modifier.padding(horizontal = 14.dp).padding(bottom = 6.dp),
                )
            } else {
                Spacer(Modifier.weight(1f))
                problem?.let { GameText(it, 15f, Modifier.padding(16.dp)) }
                Spacer(Modifier.weight(1f))
            }
        }
        result?.let { r ->
            ResultView(
                r, starGoal, r.won && levelIndex + 1 in model.levels.indices, if (model.usesLives) model.lives() else null,
                onRetry = { if (model.canStartLevel) start(emptyList(), true) else showsLives = true },
                onNext = { levelIndex += 1; start(emptyList(), true) },
                onExit = onExit,
            )
        }
        lostState?.let { state ->
            ContinueCard(state.materialsRemaining, onWatch = { Sound.play(GameSound.TAP); showsAd = true }, onGiveUp = { Sound.play(GameSound.TAP); giveUp() })
        }
        if (showsQuitConfirm) {
            QuitCard(
                onStay = { Sound.play(GameSound.TAP); showsQuitConfirm = false },
                onQuit = {
                    Sound.play(GameSound.TAP)
                    logEnd(scene?.state, "quit")
                    model.loseLife()
                    onExit()
                },
            )
        }
        adTool?.let { tool ->
            RewardedAdView("tool_${tool.name.lowercase()}", tool.title) { watched ->
                adTool = null
                if (watched && model.grantToolFromAd(tool)) Sound.play(GameSound.RESTORE)
            }
        }
        AnimatedVisibility(showsLives, enter = fadeIn(), exit = fadeOut()) { LivesPopup(model) { showsLives = false } }
        if (showsAd) {
            RewardedAdView("moves", tr("이동 +%lld", Booster.EXTRA_MOVE_COUNT)) { watched ->
                showsAd = false
                if (watched) resume()
            }
        }
        if (showsStartCard) {
            StartCard(
                tr("레벨 %lld", levelIndex + 1), tutorial, starGoal,
                counts = if (model.isLabMode) emptyMap() else Booster.entries.associateWith { model.boosterCount(it) },
                chosen = chosenBoosters, onChange = { chosenBoosters = it },
            ) {
                Sound.play(GameSound.TAP)
                begin()
            }
        } else {
            tutorial?.let { text ->
                TutorialCard(tr("레벨 %lld", levelIndex + 1), text, starGoal) {
                    Sound.play(GameSound.TAP)
                    tutorial = null
                }
            }
        }
    }
}

/** 결과 화면. 판이 끝나면 게임 화면 위에 뜬다. */
@Composable
fun ResultView(result: GameResult, goal: List<Int>, hasNextLevel: Boolean, lives: Int?, onRetry: () -> Unit, onNext: () -> Unit, onExit: () -> Unit) {
    CardOverlay {
        GameText(if (result.won) tr("정화 완료!") else tr("아쉬워요!"), 32f, color = if (result.won) Palette.star else Color.White)
        if (result.won) {
            StarsView(result.stars, 40f)
            GameText(tr("%@점", formatted(result.score)), 26f)
            GameText(
                if (result.isNewBest) tr("최고 기록! · 남은 이동 %lld", result.movesRemaining) else tr("남은 이동 %lld", result.movesRemaining),
                13f, color = Color.White.copy(alpha = 0.65f),
            )
            StarGoalView(goal, result.stars)
            if (result.rewards.isNotEmpty()) {
                Column(
                    Modifier.background(Color.Black.copy(alpha = 0.28f), RoundedCornerShape(14.dp)).padding(horizontal = 14.dp, vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    GameText(tr("선물을 받았어요!"), 14f, color = Palette.star)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { for (b in result.rewards) BoosterIcon(b, 40f) }
                }
            }
            if (result.availableStars > 0) GameText(tr("별 %lld개로 랜드마크를 복원할 수 있어요", result.availableStars), 14f, color = Palette.star)
        } else {
            GameText(tr("이동 횟수를 다 썼어요. 물질이 %lld개 남았어요.", result.materialsRemaining), 15f, color = Color.White.copy(alpha = 0.75f))
            if (lives != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Icon(if (lives > 0) Icons.Filled.Favorite else Icons.Filled.HeartBroken, null, tint = GameTint.PINK.top, modifier = Modifier.size(15.dp))
                    GameText(tr("생명 −1 · 남은 생명 %lld개", lives), 14f, color = GameTint.PINK.top)
                }
            }
        }
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (hasNextLevel) ChunkyButton(tr("다음 레벨"), tint = GameTint.PINK, size = 19f, fills = true, onClick = onNext)
            ChunkyButton(if (result.won) tr("한 번 더") else tr("다시 도전"), tint = if (result.won) GameTint.BLUE else GameTint.PINK, fills = true, onClick = onRetry)
            ChunkyButton(tr("도시로 돌아가기"), tint = GameTint.SLATE, fills = true, onClick = onExit)
        }
    }
}

/** 이동 횟수를 다 써서 졌을 때 이어 할지 묻는 카드. */
@Composable
fun ContinueCard(materialsRemaining: Int, onWatch: () -> Unit, onGiveUp: () -> Unit) {
    CardOverlay {
        GameText(tr("아쉬워요!"), 30f)
        GameText(tr("물질이 %lld개 남았어요!", materialsRemaining), 18f, color = Palette.star)
        GameText(tr("이동 %lld번을 더 받아 이어 할 수 있어요.\n한 판에 한 번만 돼요.", Booster.EXTRA_MOVE_COUNT), 14f, color = Color.White.copy(alpha = 0.7f))
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            WideButton(GameTint.PINK, onClick = onWatch) {
                Spacer(Modifier.weight(1f))
                Icon(Icons.Filled.PlayCircle, null, tint = Color.White, modifier = Modifier.size(20.dp))
                GameText(tr("광고 보고 이동 +%lld", Booster.EXTRA_MOVE_COUNT), 19f)
                Spacer(Modifier.weight(1f))
            }
            ChunkyButton(tr("그만하기"), tint = GameTint.SLATE, fills = true, onClick = onGiveUp)
        }
    }
}

/** 하던 판을 두고 나갈 때 확인하는 카드. 나가면 생명 하나를 잃는다. */
@Composable
fun QuitCard(onStay: () -> Unit, onQuit: () -> Unit) {
    CardOverlay {
        GameText(tr("그만할까요?"), 26f)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(Icons.Filled.HeartBroken, null, tint = GameTint.PINK.top, modifier = Modifier.size(16.dp))
            GameText(tr("지금 나가면 생명이 하나 줄어요"), 15f, color = GameTint.PINK.top)
        }
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ChunkyButton(tr("계속하기"), tint = GameTint.PINK, size = 19f, fills = true, onClick = onStay)
            ChunkyButton(tr("나가기"), tint = GameTint.SLATE, fills = true, onClick = onQuit)
        }
    }
}

/** 판을 하는 중에 물음표를 눌러 다시 보는 설명. */
@Composable
fun TutorialCard(title: String, text: String, goal: List<Int>, onStart: () -> Unit) {
    CardOverlay(dim = 0.6f, maxWidth = 600.dp, radius = 22.dp) {
        GameText(title, 22f, color = Palette.star)
        GameText(text, 16f, align = TextAlign.Start, modifier = Modifier.fillMaxWidth())
        if ("아이템" in text || "items" in text) ToolShowcase()
        StarGoalView(goal)
        ChunkyButton(tr("시작!"), tint = GameTint.PINK, size = 19f, onClick = onStart)
    }
}

/** 별 기준. 별 1개는 클리어, 별 2개와 별 3개는 점수로 받는다. */
@Composable
fun StarGoalView(scores: List<Int>, earned: Int = 3) {
    if (scores.size != 2) return
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        for ((stars, text) in listOf(1 to tr("클리어"), 2 to tr("%@점", formatted(scores[0])), 3 to tr("%@점", formatted(scores[1])))) {
            Column(
                Modifier.weight(1f).background(Color.Black.copy(alpha = 0.28f), RoundedCornerShape(10.dp)).padding(vertical = 6.dp).alpha(if (stars <= earned) 1f else 0.45f),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Row { repeat(stars) { Icon(Icons.Filled.Star, null, tint = Palette.star, modifier = Modifier.size(11.dp)) } }
                GameText(text, 12f)
            }
        }
    }
}

/** 설명 카드에 넣는 아이템 세 개의 그림과 이름. */
@Composable
fun ToolShowcase() {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (tool in Tool.entries) {
            Column(
                Modifier.weight(1f).background(Color.Black.copy(alpha = 0.28f), RoundedCornerShape(12.dp)).padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                ToolIcon(tool, 52f)
                GameText(tool.shortTitle, 13f)
            }
        }
    }
}

/** 판을 하는 중에 쓰는 아이템 세 개. 보드 아래에 둔다. */
@Composable
fun ToolBar(counts: Map<Tool, Int>, armed: Tool?, canGetByAd: Boolean, onTap: (Tool) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.height(16.dp)) { GameText(armed?.hint ?: " ", 13f, color = Palette.star) }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (tool in Tool.entries) {
                val count = counts[tool] ?: 0
                val isArmed = armed == tool
                val isEmpty = count == 0
                val pop by animateFloatAsState(if (isArmed) 1f else 0f, spring(), label = "armed")
                Box(
                    Modifier.weight(1f).scale(1 + 0.06f * pop).alpha(if (isEmpty && !canGetByAd) 0.5f else 1f)
                        .padding(bottom = 3.dp).chunky(GameTint.SLATE, radius = 16.dp, depth = 3.dp)
                        .border(3.dp * pop, Palette.star, RoundedCornerShape(16.dp))
                        .selectable(false, role = Role.Button) { onTap(tool) }.heightIn(min = 50.dp).padding(horizontal = 6.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box {
                            ToolIcon(
                                tool, 40f,
                                Modifier.rotate(-12f * pop).scale(1 + 0.15f * pop)
                                    .then(if (isEmpty) Modifier.alpha(0.6f) else Modifier),
                            )
                            Box(
                                Modifier.align(Alignment.BottomEnd).offset(6.dp, 3.dp)
                                    .background(Color(0.1f, 0.1f, 0.22f), RoundedCornerShape(50)).border(1.dp, Color.White.copy(alpha = 0.6f), RoundedCornerShape(50))
                                    .heightIn(min = 18.dp).padding(horizontal = 5.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                if (isEmpty) {
                                    Icon(if (canGetByAd) Icons.Filled.PlayCircle else Icons.Filled.Remove, null, tint = Color.White, modifier = Modifier.size(11.dp))
                                } else {
                                    GameText("$count", 12f)
                                }
                            }
                        }
                        GameText(tool.shortTitle, 14f)
                    }
                }
            }
        }
    }
}

/** 레벨을 시작하기 전의 카드. 처음 하는 레벨이면 설명을, 늘 별 기준을 보여주고, 가진 시작 부스터를 고르게 한다. */
@Composable
fun StartCard(title: String, text: String?, goal: List<Int>, counts: Map<Booster, Int>, chosen: Set<Booster>, onChange: (Set<Booster>) -> Unit, onStart: () -> Unit) {
    CardOverlay(dim = 0.6f, maxWidth = 600.dp, radius = 22.dp) {
        GameText(title, 22f, color = Palette.star)
        if (text != null) {
            GameText(text, 16f, align = TextAlign.Start, modifier = Modifier.fillMaxWidth())
            if ("아이템" in text || "items" in text) ToolShowcase()
        }
        StarGoalView(goal)
        if (counts.values.any { it > 0 }) {
            GameText(tr("시작 부스터를 골라 보세요"), 13f, color = Color.White.copy(alpha = 0.7f))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (booster in Booster.entries) {
                    val count = counts[booster] ?: 0
                    val isChosen = booster in chosen
                    Box(
                        Modifier.weight(1f).alpha(if (count == 0) 0.35f else 1f)
                            .background(if (isChosen) GameTint.GREEN.lip.copy(alpha = 0.55f) else Color.Black.copy(alpha = 0.28f), RoundedCornerShape(12.dp))
                            .border(2.dp, if (isChosen) GameTint.GREEN.top else Color.Transparent, RoundedCornerShape(12.dp))
                            .selectable(false, enabled = count > 0, role = Role.Button) {
                                Sound.play(GameSound.TAP)
                                onChange(if (isChosen) chosen - booster else chosen + booster)
                            }
                            .padding(vertical = 8.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Box {
                                BoosterIcon(booster, 40f)
                                if (isChosen) Icon(Icons.Filled.CheckCircle, null, tint = GameTint.GREEN.top, modifier = Modifier.align(Alignment.TopEnd).offset(6.dp, (-6).dp).size(18.dp))
                            }
                            GameText(if (isChosen) tr("사용") else tr("%lld개", count), 12f, color = if (isChosen) GameTint.GREEN.top else Color.White)
                        }
                    }
                }
            }
        }
        ChunkyButton(tr("시작!"), tint = GameTint.PINK, size = 19f, onClick = onStart)
    }
}

