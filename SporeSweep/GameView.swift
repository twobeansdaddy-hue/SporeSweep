import GameCore
import GameScene
import LevelData
import SpriteKit
import SwiftUI

/// 게임 화면. 레벨 하나를 플레이하고, 끝나면 결과를 보여준다.
struct GameView: View {
    @Environment(AppModel.self) private var model
    @State private var levelIndex: Int
    @State private var scene: BoardScene?
    @State private var result: GameResult?
    @State private var problem: String?
    /// 화면에 띄운 레벨 설명. 없으면 `nil`이다.
    @State private var tutorial: String?
    /// 레벨을 시작하기 전의 카드를 띄웠는지. 설명과 별 기준을 보여주고 시작 부스터를 고른다.
    @State private var showsStartCard = false
    /// 시작 카드에서 고른 부스터.
    @State private var chosenBoosters: Set<Booster> = []
    /// 이동 횟수를 다 써서 진 판. 이어 할지 묻는 동안 들고 있는다.
    @State private var lostState: GameState?
    /// 이번 판에서 이미 이어 했는지. 한 판에 한 번만 이어 할 수 있다.
    @State private var usedContinue = false
    /// 판을 시작할 때의 이동 횟수. 한 번이라도 뒀는지 알아보는 데 쓴다.
    @State private var initialMoves: Int?
    /// 이 판을 시작한 시드(9장). 플레이 기록에 남긴다.
    @State private var boardSeed: UInt64 = 0
    @State private var showsAd = false
    @State private var showsLives = false
    @State private var showsQuitConfirm = false
    /// 쓰려고 든 아이템.
    @State private var armedTool: Tool?
    /// 광고를 보고 받으려는 아이템.
    @State private var adTool: Tool?
    var onExit: () -> Void

    init(levelIndex: Int, onExit: @escaping () -> Void) {
        _levelIndex = State(initialValue: levelIndex)
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                // 화면 왼쪽 끝을 밀어 뒤로 가는 동작은 없다. 블록을 오른쪽으로 밀다가 도시 화면으로
                // 나가 버리지 않게, 나갈 때는 이 버튼만 쓴다.
                GameHeader(title: String(localized: "레벨 \(levelIndex + 1)")) {
                    IconButton(systemName: "chevron.left", label: "도시로 돌아가기") {
                        GameFeedback.shared.play(.tap)
                        // 승패가 정해지고 끝나는 연출을 보는 중이면 연출을 건너뛰고 결과를 띄운다.
                        // 그냥 나가면 깬 판이 기록되지 않고, 진 판의 생명도 줄지 않는다.
                        if scene?.deliverPendingResult() == true {
                            return
                        }
                        // 하던 판을 두고 나가면 진 것으로 친다. 한 번도 두지 않았으면 그냥 나간다.
                        if hasPlayed, model.usesLives {
                            withAnimation { showsQuitConfirm = true }
                        } else {
                            onExit()
                        }
                    }
                } trailing: {
                    // 설명이 있는 레벨에서는 언제든 다시 볼 수 있다.
                    if model.levels.indices.contains(levelIndex), let text = model.levels[levelIndex].tutorial, result == nil, !showsStartCard {
                        IconButton(systemName: "questionmark", label: "설명 보기") {
                            GameFeedback.shared.play(.tap)
                            withAnimation { tutorial = text }
                        }
                    }
                }
                // 안전 영역 안쪽만 씬에 넘긴다. 씬은 받은 크기로 보드를 배치한다.
                if let scene {
                    // 씬 객체만 바꿔서는 SpriteView가 이전 씬을 계속 보여준다.
                    // 씬마다 id를 달리해 뷰를 새로 만들게 한다.
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .id(ObjectIdentifier(scene))
                    ToolBar(
                        counts: Dictionary(uniqueKeysWithValues: Tool.allCases.map { ($0, model.isLabMode ? 9 : model.toolCount($0)) }),
                        armed: armedTool,
                        canGetByAd: model.adToolsLeft > 0,
                        onTap: tapTool
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                } else if let problem {
                    Spacer()
                    Text(problem)
                        .font(.game(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding()
                    Spacer()
                } else {
                    Spacer()
                }
            }
            if let result {
                ResultView(
                    result: result,
                    goal: starGoal,
                    hasNextLevel: result.won && model.levels.indices.contains(levelIndex + 1),
                    lives: model.usesLives ? model.lives() : nil,
                    onRetry: {
                        // 생명이 없으면 다시 할 수 없다.
                        if model.canStartLevel {
                            start()
                        } else {
                            withAnimation { showsLives = true }
                        }
                    },
                    onNext: {
                        levelIndex += 1
                        start()
                    },
                    onExit: onExit
                )
                .transition(.opacity)
            }
            if let lostState {
                ContinueCard(
                    materialsRemaining: lostState.materialsRemaining,
                    onWatch: {
                        GameFeedback.shared.play(.tap)
                        showsAd = true
                    },
                    onGiveUp: {
                        GameFeedback.shared.play(.tap)
                        giveUp()
                    }
                )
                .transition(.opacity)
            }
            if showsQuitConfirm {
                QuitCard(
                    onStay: {
                        GameFeedback.shared.play(.tap)
                        withAnimation { showsQuitConfirm = false }
                    },
                    onQuit: {
                        GameFeedback.shared.play(.tap)
                        logEnd(scene?.state, result: "quit")
                        model.loseLife()
                        onExit()
                    }
                )
                .transition(.opacity)
            }
            if let tool = adTool {
                RewardedAdView(id: "tool_\(tool)", reward: tool.title) { watched in
                    adTool = nil
                    if watched, model.grantToolFromAd(tool) {
                        GameFeedback.shared.play(.restore)
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
            if showsLives {
                LivesPopup {
                    withAnimation { showsLives = false }
                }
                .transition(.opacity)
            }
            if showsAd {
                RewardedAdView(id: "moves", reward: String(localized: "이동 +\(Booster.extraMoveCount)")) { watched in
                    showsAd = false
                    if watched {
                        resume()
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
            if showsStartCard {
                StartCard(
                    title: String(localized: "레벨 \(levelIndex + 1)"),
                    text: tutorial,
                    goal: starGoal,
                    counts: model.isLabMode ? [:] : Dictionary(uniqueKeysWithValues: Booster.allCases.map { ($0, model.boosterCount($0)) }),
                    chosen: $chosenBoosters
                ) {
                    GameFeedback.shared.play(.tap)
                    begin()
                }
                .transition(.opacity)
            } else if let tutorial {
                // 판을 하는 중에 물음표를 눌러 다시 보는 설명.
                TutorialCard(title: String(localized: "레벨 \(levelIndex + 1)"), text: tutorial, goal: starGoal) {
                    GameFeedback.shared.play(.tap)
                    withAnimation { self.tutorial = nil }
                }
                .transition(.opacity)
            }
        }
        .background {
            // 그 도시의 풍경을 흐리게 깔아 둔다. 맑은 하늘을 복원했으면 밝은 풍경이, 아니면 오염된 풍경이 나온다.
            if !model.isLabMode, let city = model.city, let art = LandmarkArt.art(for: city.id) {
                Image("\(art.prefix)_bg_\(model.restoredParts.contains("sky") ? "restored" : "ruined")")
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 3)
                    .overlay(Palette.backdrop.opacity(0.3))
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .gameBackground()
        // 시스템 내비게이션 바를 숨기면 화면 끝을 밀어 뒤로 가는 동작도 꺼진다.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 다른 화면이 잠깐 덮었다가 걷혀도 하던 판을 새로 시작하지 않는다.
            if scene == nil {
                start()
            }
        }
    }

    /// 이 레벨에서 별 2개와 별 3개를 받는 점수. 설명 카드와 결과 화면에 보여준다.
    private var starGoal: [Int] {
        model.levels.indices.contains(levelIndex) ? model.levels[levelIndex].starScores : []
    }

    /// 스스로 두는 판(디버그)에서는 이어 할지 묻지 않고 바로 결과로 간다.
    /// 실행 인자 `-offerContinue 1`을 함께 주면 그래도 묻는다.
    private var skipsContinueOffer: Bool {
        #if DEBUG
        return scene?.autoPlays == true && !UserDefaults.standard.bool(forKey: "offerContinue")
        #else
        return false
        #endif
    }

    /// 아이템 단추를 눌렀을 때. 가진 것이 있으면 들고(섞기는 바로 쓰고), 없으면 광고를 보고 받는다.
    private func tapTool(_ tool: Tool) {
        guard let scene, scene.canUseTools, result == nil, lostState == nil, !showsStartCard else { return }
        GameFeedback.shared.play(.tap)
        let count = model.isLabMode ? 9 : model.toolCount(tool)
        guard count > 0 else {
            if model.adToolsLeft > 0 {
                adTool = tool
            }
            return
        }
        if tool == .shuffle {
            armedTool = nil
            scene.useShuffle()
        } else {
            // 든 것을 다시 누르면 내려놓는다.
            armedTool = armedTool == tool ? nil : tool
            scene.armedTool = armedTool
        }
    }

    /// 이번 판에서 한 번이라도 뒀고 아직 끝나지 않았는지.
    private var hasPlayed: Bool {
        guard let scene, result == nil, lostState == nil, !showsStartCard, scene.state.status == .playing else { return false }
        return scene.state.score > 0 || scene.state.movesRemaining != initialMoves
    }

    /// 광고를 다 보고 판을 이어 한다.
    private func resume() {
        guard lostState != nil, scene?.continuePlaying(extraMoves: Booster.extraMoveCount) == true else { return }
        usedContinue = true
        withAnimation { lostState = nil }
    }

    /// 이어 하지 않고 진 것으로 끝낸다.
    private func giveUp() {
        guard let state = lostState, model.levels.indices.contains(levelIndex) else { return }
        lostState = nil
        conclude(state, level: model.levels[levelIndex])
    }

    /// 시작 카드에서 "시작"을 눌렀을 때. 고른 부스터를 쓰고 판을 연다.
    private func begin() {
        if model.levels.indices.contains(levelIndex) {
            model.markTutorialSeen(for: model.levels[levelIndex])
        }
        let used = model.useBoosters(chosenBoosters)
        chosenBoosters = []
        if !used.isEmpty {
            // 부스터를 적용한 판으로 다시 만든다.
            start(boosters: used, showsCard: false)
        }
        logStart(boosters: used.count)
        withAnimation {
            showsStartCard = false
            tutorial = nil
        }
    }

    /// 지금 레벨을 처음부터 시작한다. 같은 레벨은 늘 같은 보드로 시작한다.
    private func start() {
        start(boosters: [], showsCard: true)
    }

    private func start(boosters: [Booster], showsCard: Bool) {
        withAnimation { result = nil }
        lostState = nil
        usedContinue = false
        guard model.levels.indices.contains(levelIndex) else {
            scene = nil
            problem = String(localized: "레벨을 찾지 못했어요.")
            return
        }
        let level = model.levels[levelIndex]
        do {
            // 판마다 시작 보드가 다르다. 레벨 설명이 있는 판만 늘 같은 보드로 시작한다(9장).
            var seed = level.hasFixedStart ? level.seed : UInt64.random(in: 1...UInt64(Int32.max))
            #if DEBUG
            // 실행 인자 `-seed 숫자`로 같은 판을 다시 본다.
            if let forced = UserDefaults.standard.string(forKey: "seed").flatMap(UInt64.init), forced > 0 {
                seed = forced
            }
            #endif
            boardSeed = seed
            var state = try level.makeState(seed: seed)
            state.apply(boosters)
            var autoPlays = false
            #if DEBUG
            // 실행 인자 `-autoplay 1`을 주면 스스로 판을 진행하고, `-moves 숫자`로 이동 횟수를 바꾼다.
            autoPlays = UserDefaults.standard.bool(forKey: "autoplay")
            if UserDefaults.standard.integer(forKey: "moves") > 0 {
                state.movesRemaining = UserDefaults.standard.integer(forKey: "moves")
            }
            // 실행 인자 `-showcase 1`을 주면 그림을 한눈에 보도록 셋째 줄부터 블록과 장애물을 종류별로 늘어놓는다.
            if UserDefaults.standard.bool(forKey: "showcase") {
                let kinds = BlockKind.allCases
                let rows: [[Block]] = [
                    [.timed(.brick, turns: 7), .nest(hp: 2), .timed(.glass, turns: 2), .rubble, .cocoon(.brick), .cocoon(.glass), .sludge, .concrete(hp: 1)],
                    [.beam(.horizontal), .beam(.vertical), .bomb, .core, .drone] + kinds.prefix(2).map(Block.caged) + [.concrete(hp: 2)],
                    [.chained(.brick), .chained(.glass), .frozen(.scrap), .frozen(.wood), .boulder, .vent(hp: 2), .vent(hp: 1), .egg],
                ]
                // 넷째 줄의 일반 블록 둘에는 보호막을 씌운다.
                state.shields = [Position(column: 0, row: 5), Position(column: 1, row: 5)]
                for (offset, row) in rows.enumerated() {
                    for (column, block) in row.enumerated() where column < state.board.columns {
                        state.board[column, 2 + offset] = block
                    }
                }
            }
            #endif
            let scene = BoardScene(state: state, size: CGSize(width: 390, height: 700))
            scene.feedback = .shared
            scene.starScores = level.starScores
            // 첫 레벨에서는 무엇을 밀면 되는지 금방 보여준다.
            scene.hintDelay = levelIndex == 0 ? 2 : 5
            #if DEBUG
            scene.autoPlays = autoPlays
            // 실행 인자 `-sceneSpeed 0.2`를 주면 씬의 연출을 느리게 돌려 볼 수 있다.
            let speed = UserDefaults.standard.double(forKey: "sceneSpeed")
            if speed > 0 {
                scene.speed = speed
            }
            #endif
            scene.onToolUsed = { tool in
                if isTracked {
                    Tracker.log(.toolUse(tool: "\(tool)", city: level.city, level: levelIndex + 1))
                }
                model.useTool(tool)
                armedTool = nil
            }
            armedTool = nil
            scene.onFinish = { final in
                finish(final, level: level)
            }
            self.scene = scene
            initialMoves = state.movesRemaining
            problem = nil
            if showsCard {
                // 설명은 처음 하는 레벨에서만 카드에 함께 보여준다.
                tutorial = model.shouldShowTutorial(for: level) ? level.tutorial : nil
                chosenBoosters = []
                // 보여줄 설명도 없고 고를 부스터도 없으면 카드를 건너뛰고 바로 시작한다.
                let ownsBooster = !model.isLabMode && Booster.allCases.contains { model.boosterCount($0) > 0 }
                showsStartCard = !autoPlays && (tutorial != nil || ownsBooster)
                if autoPlays { tutorial = nil }
                // 카드가 없으면 여기서 바로 시작한 것이다.
                if !showsStartCard { logStart(boosters: 0) }
            }
        } catch {
            scene = nil
            problem = "레벨 \(levelIndex + 1)을 열지 못했어요: \(error)"
        }
    }

    /// 판이 끝났을 때. 이동 횟수를 다 써서 졌고 아직 이어 하지 않았으면 이어 할지 먼저 묻는다.
    private func finish(_ state: GameState, level: Level) {
        if state.canContinue, !usedContinue, !skipsContinueOffer {
            if isTracked {
                Tracker.log(.continueOffer(city: level.city, level: levelIndex + 1, materialsLeft: state.materialsRemaining))
            }
            withAnimation { lostState = state }
        } else {
            conclude(state, level: level)
        }
    }

    /// 측정 도구에 남길 판인지. 시험판과 스스로 두는 판은 남기지 않는다.
    private var isTracked: Bool {
        #if DEBUG
        // 스스로 두는 판은 남기지 않는다. 실행 인자 `-trackAutoplay 1`을 주면 남긴다. 기록이 찍히는지 볼 때 쓴다.
        if scene?.autoPlays == true, !UserDefaults.standard.bool(forKey: "trackAutoplay") {
            return false
        }
        #endif
        return !model.isLabMode && model.levels.indices.contains(levelIndex)
    }

    private func logStart(boosters: Int) {
        guard isTracked else { return }
        Tracker.log(.levelStart(city: model.levels[levelIndex].city, level: levelIndex + 1, boosters: boosters, seed: Int(boardSeed)))
    }

    private func logEnd(_ state: GameState?, result: String) {
        guard isTracked, let state else { return }
        let level = model.levels[levelIndex]
        Tracker.log(.levelEnd(
            city: level.city, level: levelIndex + 1, result: result,
            stars: result == "won" ? level.stars(forScore: state.score) : 0, score: state.score,
            movesLeft: state.movesRemaining ?? 0, materialsLeft: state.materialsRemaining, continued: usedContinue
        ))
    }

    /// 끝난 판을 기록하고 결과 화면을 띄운다. 졌으면 생명 하나를 잃는다.
    private func conclude(_ state: GameState, level: Level) {
        logEnd(state, result: state.status == .won ? "won" : "lost")
        if state.status == .lost {
            model.loseLife()
        }
        let bestBefore = model.progress.bestScore(for: level.id)
        let stars = model.record(state, for: level)
        withAnimation {
            result = GameResult(
                won: state.status == .won,
                stars: stars,
                score: state.score,
                isNewBest: state.status == .won && state.score > bestBefore,
                movesRemaining: state.movesRemaining ?? 0,
                materialsRemaining: state.materialsRemaining,
                availableStars: model.isFullyRestored ? 0 : model.availableStars,
                rewards: model.lastRewards
            )
        }
    }
}

/// 결과 화면에 보여줄 내용.
struct GameResult: Equatable {
    var won: Bool
    var stars: Int
    var score: Int
    var isNewBest: Bool
    var movesRemaining: Int
    var materialsRemaining: Int
    /// 랜드마크 복원에 쓸 수 있는 별. 복원을 다 끝냈으면 0이다.
    var availableStars: Int
    /// 이 레벨을 처음 클리어해 받은 부스터.
    var rewards: [Booster] = []
}

/// 결과 화면(10장 AppUI). 판이 끝나면 게임 화면 위에 뜬다.
struct ResultView: View {
    var result: GameResult
    /// 별 2개와 별 3개를 받는 점수.
    var goal: [Int] = []
    var hasNextLevel: Bool
    /// 남은 생명. 생명력을 쓰지 않는 판이면 `nil`이다.
    var lives: Int?
    var onRetry: () -> Void
    var onNext: () -> Void
    var onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(result.won ? "정화 완료!" : "아쉬워요!")
                    .font(.game(32))
                    .foregroundStyle(result.won ? Palette.star : .white)
                if result.won {
                    StarsView(count: result.stars, size: 40)
                        .padding(.vertical, 2)
                    Text("\(result.score.formatted())점")
                        .font(.game(26).monospacedDigit())
                    Text(result.isNewBest ? "최고 기록! · 남은 이동 \(result.movesRemaining)" : "남은 이동 \(result.movesRemaining)")
                        .font(.game(13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                    StarGoalView(scores: goal, earned: result.stars)
                    if !result.rewards.isEmpty {
                        VStack(spacing: 6) {
                            Text("선물을 받았어요!")
                                .font(.game(14))
                                .foregroundStyle(Palette.star)
                            HStack(spacing: 8) {
                                ForEach(Array(result.rewards.enumerated()), id: \.offset) { _, booster in
                                    BoosterIcon(booster: booster, size: 40)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if result.availableStars > 0 {
                        Text("별 \(result.availableStars)개로 랜드마크를 복원할 수 있어요")
                            .font(.game(14))
                            .foregroundStyle(Palette.star)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                } else {
                    Text("이동 횟수를 다 썼어요. 물질이 \(result.materialsRemaining)개 남았어요.")
                        .font(.game(15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                    if let lives {
                        Label("생명 −1 · 남은 생명 \(lives)개", systemImage: lives > 0 ? "heart.fill" : "heart.slash.fill")
                            .font(.game(14))
                            .foregroundStyle(GameTint.pink.top)
                    }
                }
                VStack(spacing: 10) {
                    if hasNextLevel {
                        Button("다음 레벨", action: onNext)
                            .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19, fills: true))
                    }
                    Button(result.won ? "한 번 더" : "다시 도전", action: onRetry)
                        .buttonStyle(ChunkyButtonStyle(tint: result.won ? .blue : .pink, fills: true))
                    Button("도시로 돌아가기", action: onExit)
                        .buttonStyle(ChunkyButtonStyle(tint: .slate, fills: true))
                }
                .padding(.top, 10)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 320)
            .gamePanel(radius: 24)
            .padding(28)
        }
    }
}

/// 이동 횟수를 다 써서 졌을 때 이어 할지 묻는 카드(6장). 광고를 보면 이동 횟수를 더 받는다.
struct ContinueCard: View {
    var materialsRemaining: Int
    var onWatch: () -> Void
    var onGiveUp: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("아쉬워요!")
                    .font(.game(30))
                Text("물질이 \(materialsRemaining)개 남았어요!")
                    .font(.game(18))
                    .foregroundStyle(Palette.star)
                Text("이동 \(Booster.extraMoveCount)번을 더 받아 이어 할 수 있어요.\n한 판에 한 번만 돼요.")
                    .font(.game(14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Button(action: onWatch) {
                        Label("광고 보고 이동 +\(Booster.extraMoveCount)", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19, fills: true))
                    Button("그만하기", action: onGiveUp)
                        .buttonStyle(ChunkyButtonStyle(tint: .slate, fills: true))
                }
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 320)
            .gamePanel(radius: 24)
            .padding(28)
        }
    }
}

/// 하던 판을 두고 나갈 때 확인하는 카드. 나가면 생명 하나를 잃는다.
struct QuitCard: View {
    var onStay: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("그만할까요?")
                    .font(.game(26))
                Label("지금 나가면 생명이 하나 줄어요", systemImage: "heart.slash.fill")
                    .font(.game(15))
                    .foregroundStyle(GameTint.pink.top)
                VStack(spacing: 10) {
                    Button("계속하기", action: onStay)
                        .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19, fills: true))
                    Button("나가기", action: onQuit)
                        .buttonStyle(ChunkyButtonStyle(tint: .slate, fills: true))
                }
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 320)
            .gamePanel(radius: 24)
            .padding(28)
        }
    }
}

/// 레벨에서 처음 나오는 규칙의 설명(튜토리얼). 레벨을 처음 시작할 때 게임 화면 위에 뜬다.
struct TutorialCard: View {
    var title: String
    var text: String
    /// 별 2개와 별 3개를 받는 점수.
    var goal: [Int] = []
    var onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(title)
                    .font(.game(22))
                    .foregroundStyle(Palette.star)
                Text(text)
                    .font(.game(16, weight: .semibold))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if (text.contains("아이템") || text.contains("items")) {
                    ToolShowcase()
                }
                StarGoalView(scores: goal)
                Button("시작!", action: onStart)
                    .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19))
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .padding(22)
            .gamePanel(radius: 22)
            .padding(28)
        }
    }
}

/// 별 기준. 별 1개는 클리어, 별 2개와 별 3개는 점수로 받는다는 것을 칸 세 개로 보여준다.
struct StarGoalView: View {
    var scores: [Int]
    /// 이번 판에 받은 별. 결과 화면에서는 받은 칸을 밝게 한다.
    var earned: Int = 3

    var body: some View {
        if scores.count == 2 {
            HStack(spacing: 6) {
                chip(stars: 1, text: "클리어")
                chip(stars: 2, text: String(localized: "\(scores[0].formatted())점"))
                chip(stars: 3, text: String(localized: "\(scores[1].formatted())점"))
            }
            .accessibilityElement()
            .accessibilityLabel("별 1개 클리어, 별 2개 \(scores[0])점, 별 3개 \(scores[1])점")
        }
    }

    private func chip(stars: Int, text: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 1) {
                ForEach(0..<stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .black))
                }
            }
            .foregroundStyle(Palette.star)
            Text(LocalizedStringKey(text))
                .font(.game(12))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
        .opacity(stars <= earned ? 1 : 0.45)
    }
}

extension Tool {
    /// 화면에 보여줄 이름.
    var title: String {
        switch self {
        case .hammer: String(localized: "정화 망치")
        case .swap: String(localized: "자리 바꾸기")
        case .shuffle: String(localized: "섞기")
        }
    }

    /// 단추에 적는 짧은 이름.
    var shortTitle: String {
        switch self {
        case .hammer: String(localized: "망치")
        case .swap: String(localized: "바꾸기")
        case .shuffle: String(localized: "섞기")
        }
    }

    /// 그림의 이름. 보드의 그림과 같은 묶음에 들어 있다.
    var spriteName: String {
        "tool_" + rawValue
    }

    /// 들었을 때 보여주는 안내.
    var hint: String {
        switch self {
        case .hammer: String(localized: "부술 칸을 눌러 주세요")
        case .swap: String(localized: "바꿀 블록을 옆으로 밀어 주세요")
        case .shuffle: ""
        }
    }

    var tint: GameTint {
        switch self {
        case .hammer: .gold
        case .swap: .blue
        case .shuffle: .green
        }
    }
}

/// 아이템의 그림.
struct ToolIcon: View {
    var tool: Tool
    var size: CGFloat

    var body: some View {
        Group {
            if let image = SpriteImage.image(named: tool.spriteName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 설명 카드에 넣는 아이템 세 개의 그림과 이름.
struct ToolShowcase: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Tool.allCases, id: \.self) { tool in
                VStack(spacing: 4) {
                    ToolIcon(tool: tool, size: 52)
                    Text(tool.shortTitle)
                        .font(.game(13))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

/// 판을 하는 중에 쓰는 아이템 세 개(6장). 보드 아래에 둔다.
struct ToolBar: View {
    var counts: [Tool: Int]
    var armed: Tool?
    /// 가진 것이 없을 때 광고를 보고 받을 수 있는지.
    var canGetByAd: Bool
    var onTap: (Tool) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(armed?.hint ?? " ")
                .font(.game(13))
                .foregroundStyle(Palette.star)
                .frame(height: 16)
            HStack(spacing: 10) {
                ForEach(Tool.allCases, id: \.self) { tool in
                    button(tool)
                }
            }
        }
    }

    private func button(_ tool: Tool) -> some View {
        let count = counts[tool] ?? 0
        let isArmed = armed == tool
        let isEmpty = count == 0
        return Button {
            onTap(tool)
        } label: {
            // 폭이 좁은 화면에서도 단추 셋이 화면을 넘지 않게, 개수는 그림 귀퉁이에 얹고 이름은 줄어들 수 있게 한다.
            HStack(spacing: 6) {
                ToolIcon(tool: tool, size: 40)
                    .saturation(isEmpty ? 0.25 : 1)
                    .rotationEffect(.degrees(isArmed ? -12 : 0))
                    .scaleEffect(isArmed ? 1.15 : 1)
                    .overlay(alignment: .bottomTrailing) {
                        Group {
                            if isEmpty {
                                Image(systemName: canGetByAd ? "play.rectangle.fill" : "minus")
                                    .font(.system(size: 9, weight: .black))
                            } else {
                                Text("\(count)")
                                    .font(.game(12).monospacedDigit())
                            }
                        }
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 2)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.22), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                        .offset(x: 6, y: 3)
                    }
                Text(tool.shortTitle)
                    .font(.game(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(ChunkyShape(tint: .slate, radius: 16, depth: 3))
            .padding(.bottom, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Palette.star, lineWidth: isArmed ? 3 : 0)
                    .padding(.bottom, 3)
            )
            .scaleEffect(isArmed ? 1.06 : 1)
            .opacity(isEmpty && !canGetByAd ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isArmed)
        .accessibilityLabel("\(tool.title), \(count)개\(isArmed ? ", 들고 있음" : "")")
    }
}

extension Booster {
    /// 화면에 보여줄 이름.
    var title: String {
        switch self {
        case .beam: String(localized: "제염 빔")
        case .bomb: String(localized: "중화 폭탄")
        case .core: String(localized: "정화 코어")
        case .extraMoves: String(localized: "이동 +\(Booster.extraMoveCount)")
        }
    }

    /// 보드에서 쓰는 그림의 이름. 이동 추가는 그림이 없다.
    var spriteName: String? {
        switch self {
        case .beam: "block_beam_h"
        case .bomb: "block_bomb"
        case .core: "block_core"
        case .extraMoves: nil
        }
    }
}

/// 부스터의 그림. 특수 블록은 보드의 그림을 그대로 쓰고, 이동 추가는 숫자로 그린다.
struct BoosterIcon: View {
    var booster: Booster
    var size: CGFloat

    var body: some View {
        Group {
            if let name = booster.spriteName, let image = SpriteImage.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("+\(Booster.extraMoveCount)")
                    .font(.game(size * 0.5))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.9, height: size * 0.9)
                    .background(
                        LinearGradient(colors: [GameTint.green.top, GameTint.green.bottom], startPoint: .top, endPoint: .bottom),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(GameTint.green.lip, lineWidth: 2))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(booster.title)
    }
}

/// 레벨을 시작하기 전의 카드. 처음 하는 레벨이면 설명을, 늘 별 기준을 보여주고, 가진 시작 부스터를 고르게 한다.
struct StartCard: View {
    var title: String
    /// 처음 하는 레벨의 설명. 이미 본 레벨이면 `nil`이다.
    var text: String?
    var goal: [Int] = []
    /// 가진 부스터의 수. 비어 있으면 부스터를 고르는 줄을 보여주지 않는다.
    var counts: [Booster: Int]
    @Binding var chosen: Set<Booster>
    var onStart: () -> Void

    private var ownsAny: Bool {
        counts.values.contains { $0 > 0 }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(title)
                    .font(.game(22))
                    .foregroundStyle(Palette.star)
                if let text {
                    Text(text)
                        .font(.game(16, weight: .semibold))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    // 아이템을 소개하는 설명에는 그림을 함께 보여준다.
                    if (text.contains("아이템") || text.contains("items")) {
                        ToolShowcase()
                    }
                }
                StarGoalView(scores: goal)
                if ownsAny {
                    VStack(spacing: 8) {
                        Text("시작 부스터를 골라 보세요")
                            .font(.game(13))
                            .foregroundStyle(.white.opacity(0.7))
                        HStack(spacing: 8) {
                            ForEach(Booster.allCases, id: \.self) { booster in
                                slot(booster)
                            }
                        }
                    }
                }
                Button("시작!", action: onStart)
                    .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19))
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .padding(22)
            .gamePanel(radius: 22)
            .padding(28)
        }
    }

    /// 부스터 한 칸. 누르면 고르고, 다시 누르면 뺀다. 가진 것이 없으면 누를 수 없다.
    private func slot(_ booster: Booster) -> some View {
        let count = counts[booster] ?? 0
        let isChosen = chosen.contains(booster)
        return Button {
            GameFeedback.shared.play(.tap)
            if isChosen {
                chosen.remove(booster)
            } else {
                chosen.insert(booster)
            }
        } label: {
            VStack(spacing: 3) {
                BoosterIcon(booster: booster, size: 40)
                    .overlay(alignment: .topTrailing) {
                        if isChosen {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(GameTint.green.top, .white)
                                .offset(x: 6, y: -6)
                        }
                    }
                Text(isChosen ? "사용" : "\(count)개")
                    .font(.game(12))
                    .foregroundStyle(isChosen ? GameTint.green.top : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isChosen ? GameTint.green.lip.opacity(0.55) : Color.black.opacity(0.28),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isChosen ? GameTint.green.top : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.35 : 1)
        .accessibilityLabel("\(booster.title), \(count)개\(isChosen ? ", 고름" : "")")
    }
}
