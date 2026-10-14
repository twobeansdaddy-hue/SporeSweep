import CoreGraphics
import GameCore
import SpriteKit
import Testing
@testable import GameScene

@MainActor
@Suite("보드 씬")
struct BoardSceneTests {
    let size = CGSize(width: 402, height: 780)

    /// `swap.from`의 중심에서 `swap.to`의 중심까지 끈다.
    func drag(_ scene: BoardScene, _ swap: Swap) {
        scene.beginDrag(at: scene.layout.center(of: swap.from))
        scene.continueDrag(to: scene.layout.center(of: swap.to))
        scene.endDrag()
    }

    @Test("모든 칸에 종류에 맞는 이름의 블록 노드가 있다")
    func drawsEveryBlock() {
        let state = GameState(seed: 1)
        let scene = BoardScene(state: state, size: size)
        for position in state.board.positions {
            #expect(scene.spriteName(at: position) == BlockSprite.name(for: state.board[position]!))
        }
    }

    @Test("블록 종류와 특수 블록마다 스프라이트 이름이 다르다")
    func spriteNamesAreUnique() {
        var blocks: [Block] = [.core, .beam(.horizontal), .beam(.vertical), .bomb]
        for kind in BlockKind.allCases {
            blocks += [.normal(kind), .caged(kind)]
        }
        #expect(Set(blocks.map { BlockSprite.name(for: $0) }).count == blocks.count)
        #expect(BlockSprite.name(for: .normal(.brick)) == "block_brick")
        #expect(BlockSprite.name(for: .core) == "block_core")
    }

    @Test("특수 블록은 종류와 상관없는 하나의 그림으로 그린다")
    func specialBlocksAreStandaloneSprites() {
        #expect(BlockSprite.name(for: .beam(.horizontal)) == "block_beam_h")
        #expect(BlockSprite.name(for: .beam(.vertical)) == "block_beam_v")
        #expect(BlockSprite.name(for: .bomb) == "block_bomb")
        for block in [Block.beam(.horizontal), .beam(.vertical), .bomb, .core] {
            let node = BlockSprite.makeNode(block: block, cellSize: 48)
            #expect(node is SKSpriteNode)
            #expect(node.children.isEmpty)
            #expect(node.frame.width <= 48 && node.frame.height <= 48)
        }
    }

    @Test("특수 블록이 놓인 보드를 그대로 그린다")
    func drawsSpecialBlocks() {
        var state = GameState(seed: 1)
        state.board[2, 3] = .beam(.vertical)
        state.board[5, 6] = .bomb
        state.board[0, 0] = .core
        let scene = BoardScene(state: state, size: size)
        #expect(scene.spriteName(at: Position(column: 2, row: 3)) == "block_beam_v")
        #expect(scene.spriteName(at: Position(column: 5, row: 6)) == "block_bomb")
        #expect(scene.spriteName(at: Position(column: 0, row: 0)) == "block_core")
    }

    @Test("특수 블록 조합 스와이프도 GameCore의 결과를 반영한다")
    func comboSwipe() {
        var state = GameState(seed: 1)
        state.board[3, 5] = .bomb
        state.board[4, 5] = .bomb
        let swap = Swap(from: Position(column: 3, row: 5), to: Position(column: 4, row: 5))
        let scene = BoardScene(state: state, size: size)
        drag(scene, swap)
        #expect(scene.state == state.performTurn(swap).state)
        #expect(scene.state != state)
    }

    @Test("유효한 스와이프는 GameCore의 턴 결과를 그대로 반영한다", arguments: [0, 1, 2, 3])
    func validSwipe(moveIndex: Int) {
        let state = GameState(seed: 21)
        let moves = state.board.possibleMoves()
        let swap = moves[moveIndex % moves.count]
        let scene = BoardScene(state: state, size: size)
        drag(scene, swap)
        #expect(scene.state == state.performTurn(swap).state)
        #expect(scene.state != state)
        #expect(scene.isAnimating)
    }

    @Test("반대 방향으로 끌어도 같은 스왑이다")
    func reversedSwipe() {
        let state = GameState(seed: 21)
        let swap = state.board.possibleMoves()[0]
        let scene = BoardScene(state: state, size: size)
        drag(scene, Swap(from: swap.to, to: swap.from))
        #expect(scene.state.board == state.performTurn(swap).state.board)
    }

    @Test("매치가 없는 스와이프는 상태를 바꾸지 않는다")
    func invalidSwipe() {
        let state = GameState(seed: 21)
        let valid = Set(state.board.possibleMoves())
        let invalid = state.board.positions
            .map { Swap(from: $0, to: Position(column: $0.column + 1, row: $0.row)) }
            .first { state.board.contains($0.to) && !valid.contains($0) }!
        let scene = BoardScene(state: state, size: size)
        drag(scene, invalid)
        #expect(scene.state == state)
    }

    @Test("보드 밖으로 끄는 스와이프는 무시한다")
    func swipeOffBoard() {
        let state = GameState(seed: 21)
        let scene = BoardScene(state: state, size: size)
        let corner = scene.layout.center(of: Position(column: 0, row: 0))
        scene.beginDrag(at: corner)
        scene.continueDrag(to: CGPoint(x: corner.x - scene.layout.cellSize, y: corner.y))
        #expect(scene.state == state)
        #expect(!scene.isAnimating)
    }

    @Test("칸의 1/3보다 짧게 움직이면 스왑하지 않는다")
    func shortDragDoesNothing() {
        let state = GameState(seed: 21)
        let swap = state.board.possibleMoves()[0]
        let scene = BoardScene(state: state, size: size)
        let start = scene.layout.center(of: swap.from)
        let end = scene.layout.center(of: swap.to)
        scene.beginDrag(at: start)
        scene.continueDrag(to: CGPoint(x: start.x + (end.x - start.x) * 0.2, y: start.y + (end.y - start.y) * 0.2))
        #expect(scene.state == state)
    }

    @Test("애니메이션 재생 중에는 입력을 받지 않는다")
    func ignoresInputWhileAnimating() {
        let scene = BoardScene(state: GameState(seed: 21), size: size)
        drag(scene, scene.state.board.possibleMoves()[0])
        let afterFirst = scene.state
        drag(scene, afterFirst.board.possibleMoves()[0])
        #expect(scene.state == afterFirst)
    }

    @Test("씬 크기가 바뀌면 같은 상태로 다시 배치한다")
    func resizeRebuilds() {
        let state = GameState(seed: 1)
        let scene = BoardScene(state: state, size: size)
        scene.size = CGSize(width: 800, height: 376)
        #expect(scene.sceneLayout == SceneLayout(size: CGSize(width: 800, height: 376)))
        #expect(scene.state == state)
        for position in state.board.positions {
            #expect(scene.spriteName(at: position) == BlockSprite.name(for: state.board[position]!))
        }
    }

    // MARK: - 긴 보드

    func level(moves: Int = 25) -> GameState {
        GameState(
            seed: 1004,
            rows: 16,
            moves: moves,
            materials: [Position(column: 2, row: 0), Position(column: 5, row: 0)]
        )
    }

    @Test("긴 보드도 화면에는 8×10만 배치한다")
    func tallBoardShowsTenRows() {
        let scene = BoardScene(state: level(), size: size)
        #expect(scene.layout.rows == 10)
        #expect(scene.layout.columns == 8)
        #expect(scene.spriteName(at: Position(column: 2, row: 0)) == "material")
        // 화면 아래의 행도 미리 만들어져 있다.
        #expect(scene.spriteName(at: Position(column: 0, row: 15)) != nil)
    }

    @Test("이동 횟수와 물질 수를 표시한다")
    func hud() {
        let scene = BoardScene(state: level(), size: size)
        #expect(scene.hudText.moves == "이동 25")
        #expect(scene.hudText.materials == "물질 0/2")
        drag(scene, scene.state.possibleMoves()[0])
        #expect(scene.hudText.moves == "이동 24")
    }

    @Test("제한이 없는 판은 이동 횟수와 물질 수를 표시하지 않는다")
    func hudHiddenInFreePlay() {
        let scene = BoardScene(state: GameState(seed: 1), size: size)
        #expect(scene.hudText.moves == "")
        #expect(scene.hudText.materials == "")
    }

    @Test("카메라가 내려간 뒤에는 화면의 칸이 보드의 아래쪽 행에 대응한다")
    func dragUsesActiveZoneRows() {
        // 카메라가 3행까지 내려간 상태로 시작한다.
        var board = level().board
        for position in board.positions(in: 0..<3) { board[position] = nil }
        board[2, 4] = .material
        board[5, 4] = .material
        var state = GameState(board: board, generator: SeededGenerator(seed: 1), activeTop: 3, movesRemaining: 25)
        state = state.settle().state
        #expect(state.activeTop == 3)

        let move = state.possibleMoves()[0]
        #expect(move.from.row >= 3)
        let scene = BoardScene(state: state, size: size)
        // 화면에서는 3행 위쪽에 보인다.
        let visible = { (position: Position) in
            scene.layout.center(of: Position(column: position.column, row: position.row - 3))
        }
        scene.beginDrag(at: visible(move.from))
        scene.continueDrag(to: visible(move.to))
        scene.endDrag()
        #expect(scene.state == state.performTurn(move).state)
    }

    @Test("미니맵을 누르고 있는 동안에는 블록을 움직일 수 없다")
    func minimapPreviewBlocksInput() {
        let state = level()
        let scene = BoardScene(state: state, size: size)
        let minimap = scene.sceneLayout.minimapFrame
        scene.beginDrag(at: CGPoint(x: minimap.midX, y: minimap.minY + 10))
        #expect(scene.isPreviewing)
        scene.perform(state.possibleMoves()[0])
        #expect(scene.state == state)
        scene.endDrag()
        #expect(!scene.isPreviewing)
        // 손을 떼면 다시 움직일 수 있다.
        drag(scene, state.possibleMoves()[0])
        #expect(scene.state != state)
    }

    @Test("화면 길이의 보드에는 미니맵 미리 보기가 없다")
    func noPreviewOnShortBoard() {
        let scene = BoardScene(state: GameState(seed: 1), size: size)
        let minimap = scene.sceneLayout.minimapFrame
        scene.beginDrag(at: CGPoint(x: minimap.midX, y: minimap.midY))
        #expect(!scene.isPreviewing)
    }

    @Test("끝난 판은 결과를 보여주고 스왑을 받지 않는다")
    func resultAndRestart() {
        let state = level(moves: 1)
        let scene = BoardScene(state: state, size: size)
        drag(scene, state.possibleMoves()[0])
        #expect(scene.state.status == .lost)

        // 결과 화면은 이벤트 재생이 끝나야 뜬다. 끝난 상태로 만든 씬에서 확인한다.
        let finished = BoardScene(state: scene.state, size: size)
        #expect(finished.isShowingResult)
        finished.perform(Swap(from: Position(column: 0, row: 0), to: Position(column: 1, row: 0)))
        #expect(finished.state == scene.state)
    }

    @Test("다시 시작하면 처음 상태로 돌아간다")
    func restartRestoresInitialState() {
        let state = level()
        let scene = BoardScene(state: state, size: size)
        drag(scene, state.possibleMoves()[0])
        #expect(scene.state != state)
        scene.restart()
        #expect(scene.state == state)
        #expect(!scene.isAnimating)
        #expect(scene.hudText.moves == "이동 25")
    }

    // MARK: - 대기 물질

    @Test("대기 물질은 보드에 그리지 않고 수와 대기 표시로만 보여준다")
    func pendingMaterialsAreShownAsMarkers() {
        let state = GameState(
            seed: 1004,
            rows: 16,
            moves: 30,
            materials: [Position(column: 2, row: 0)],
            pendingMaterials: [PendingMaterial(column: 5, depth: 6)]
        )
        let scene = BoardScene(state: state, size: size)
        #expect(scene.hudText.materials == "물질 0/2")
        #expect(scene.pendingShown == [PendingMaterial(column: 5, depth: 6)])
        #expect(scene.spriteName(at: Position(column: 5, row: 0)) != "material")
        #expect(scene.spriteName(at: Position(column: 2, row: 0)) == "material")
    }

    @Test("대기 물질이 있는 판도 GameCore의 턴 결과를 그대로 반영한다")
    func pendingMaterialTurn() {
        let state = GameState(
            seed: 3,
            rows: 16,
            moves: 30,
            pendingMaterials: [PendingMaterial(column: 0, depth: 0), PendingMaterial(column: 7, depth: 0)]
        )
        let swap = state.possibleMoves()[0]
        let scene = BoardScene(state: state, size: size)
        drag(scene, swap)
        #expect(scene.state == state.performTurn(swap).state)
    }

    // MARK: - 큰 물질

    func largeLevel() -> GameState {
        GameState(
            seed: 4,
            rows: 16,
            moves: 60,
            materialPieces: [
                MaterialPiece(origin: Position(column: 1, row: 0), width: 2, height: 1),
                MaterialPiece(origin: Position(column: 5, row: 0), width: 2, height: 2),
            ]
        )
    }

    @Test("큰 물질은 덮은 칸 전체를 노드 하나로 그린다")
    func largePieceIsOneNode() {
        let scene = BoardScene(state: largeLevel(), size: size)
        #expect(scene.hudText.materials == "물질 0/2")
        let square = [(5, 0), (6, 0), (5, 1), (6, 1)].map { Position(column: $0.0, row: $0.1) }
        for cell in square {
            #expect(scene.spriteName(at: cell) == "material")
            #expect(scene.sharesNode(square[0], cell))
        }
        #expect(scene.sharesNode(Position(column: 1, row: 0), Position(column: 2, row: 0)))
        #expect(!scene.sharesNode(Position(column: 2, row: 0), Position(column: 5, row: 0)))
    }

    @Test("큰 물질 노드는 덮은 칸만큼 크다")
    func largePieceNodeSize() {
        let wide = BlockSprite.makeMaterialNode(width: 2, height: 1, cellSize: 48)
        let square = BlockSprite.makeMaterialNode(width: 2, height: 2, cellSize: 48)
        let single = BlockSprite.makeMaterialNode(width: 1, height: 1, cellSize: 48)
        #expect(wide.frame.width > 80 && wide.frame.width <= 96)
        #expect(wide.frame.height > 36 && wide.frame.height <= 48)
        #expect(square.frame.width > 80 && square.frame.height > 80)
        #expect(single.frame.width <= 48)
        // 그림이 있는 크기는 그림 한 장이고, 없는 크기는 칸마다 핵을 그린다.
        #expect(wide is SKSpriteNode)
        #expect(square is SKSpriteNode)
        #expect(BlockSprite.makeMaterialNode(width: 3, height: 1, cellSize: 48).children.count == 3)
        #expect(square.frame.width <= 96 && square.frame.height <= 96)
    }

    @Test("큰 물질을 끄는 스와이프는 상태를 바꾸지 않는다")
    func largePieceCannotBeDragged() {
        let state = largeLevel()
        let scene = BoardScene(state: state, size: size)
        drag(scene, Swap(from: Position(column: 2, row: 0), to: Position(column: 3, row: 0)))
        #expect(scene.state == state)
        drag(scene, Swap(from: Position(column: 5, row: 2), to: Position(column: 5, row: 1)))
        #expect(scene.state == state)
    }

    @Test("큰 물질이 있는 판도 GameCore의 턴 결과를 그대로 반영한다")
    func largePieceTurn() {
        let state = largeLevel()
        let swap = state.possibleMoves()[0]
        let scene = BoardScene(state: state, size: size)
        drag(scene, swap)
        #expect(scene.state == state.performTurn(swap).state)
    }

    @Test("흘러내림을 켠 판도 GameCore의 턴 결과를 그대로 반영한다")
    func slidingTurn() {
        var state = largeLevel()
        state.blocksSlide = true
        let scene = BoardScene(state: state, size: size)
        for _ in 0..<1 {
            let swap = state.possibleMoves()[0]
            drag(scene, swap)
            #expect(scene.state == state.performTurn(swap).state)
            #expect(scene.state.blocksSlide)
        }
    }

    // MARK: - 장애물

    @Test("장애물마다 스프라이트 이름과 모습이 다르다")
    func obstacleSprites() {
        #expect(BlockSprite.name(for: .concrete(hp: 1)) == "obstacle_concrete_1")
        #expect(BlockSprite.name(for: .concrete(hp: 2)) == "obstacle_concrete_2")
        #expect(BlockSprite.name(for: .caged(.glass)) == "block_glass_caged")
        #expect(BlockSprite.name(for: .sludge) == "obstacle_sludge")
        // 콘크리트 두 종류는 서로 다른 그림이고, 철망은 블록 위에 격자가 덮인다.
        #expect(BlockSprite.makeNode(block: .concrete(hp: 1), cellSize: 48) is SKSpriteNode)
        #expect(BlockSprite.makeNode(block: .concrete(hp: 2), cellSize: 48) is SKSpriteNode)
        #expect(BlockSprite.texture(named: "obstacle_concrete_1") !== BlockSprite.texture(named: "obstacle_concrete_2"))
        #expect(BlockSprite.makeNode(block: .caged(.glass), cellSize: 48).children.map(\.name) == ["cage"])
        #expect(BlockSprite.makeNode(block: .concrete(hp: 1), cellSize: 48).frame.width <= 48)
    }

    func obstacleLevel() -> GameState {
        GameState(
            seed: 2,
            rows: 16,
            moves: 40,
            materials: [Position(column: 2, row: 0)],
            obstacles: [
                Obstacle(kind: .concrete(hp: 2), position: Position(column: 3, row: 6)),
                Obstacle(kind: .cage, position: Position(column: 5, row: 4)),
                Obstacle(kind: .sludge, position: Position(column: 7, row: 8)),
            ]
        )
    }

    @Test("장애물이 놓인 보드를 그대로 그린다")
    func drawsObstacles() {
        let scene = BoardScene(state: obstacleLevel(), size: size)
        #expect(scene.spriteName(at: Position(column: 3, row: 6)) == "obstacle_concrete_2")
        #expect(scene.spriteName(at: Position(column: 5, row: 4))?.hasSuffix("_caged") == true)
        #expect(scene.spriteName(at: Position(column: 7, row: 8)) == "obstacle_sludge")
    }

    @Test("장애물을 끄는 스와이프는 상태를 바꾸지 않는다")
    func obstaclesCannotBeDragged() {
        let state = obstacleLevel()
        let scene = BoardScene(state: state, size: size)
        for cell in [Position(column: 3, row: 6), Position(column: 5, row: 4), Position(column: 7, row: 8)] {
            drag(scene, Swap(from: cell, to: Position(column: cell.column - 1, row: cell.row)))
            #expect(scene.state == state)
        }
    }

    @Test("장애물이 있는 판도 GameCore의 턴 결과를 그대로 반영한다")
    func obstacleTurn() {
        let state = obstacleLevel()
        let swap = state.possibleMoves()[0]
        let scene = BoardScene(state: state, size: size)
        drag(scene, swap)
        #expect(scene.state == state.performTurn(swap).state)
    }

    // MARK: - 점수와 결과 알림

    @Test("점수를 표시한다")
    func scoreLabel() {
        let state = level()
        let scene = BoardScene(state: state, size: size)
        #expect(scene.hudText.score == "0점")
        let swap = state.possibleMoves()[0]
        drag(scene, swap)
        #expect(scene.hudText.score == "\(state.performTurn(swap).state.score)점")
        #expect(BoardScene(state: GameState(seed: 1), size: size).hudText.score == "")
    }

    @Test("앱이 결과 화면을 맡으면 끝난 판에서 탭해도 다시 시작하지 않는다")
    func appOwnedResult() {
        let lost = level(moves: 1).performTurn(level(moves: 1).possibleMoves()[0]).state
        #expect(lost.status == .lost)
        let scene = BoardScene(state: lost, size: size)
        var notified = 0
        scene.onFinish = { _ in notified += 1 }
        // 이미 끝난 상태로 만든 씬은 다시 알리지 않는다.
        scene.size = CGSize(width: 800, height: 376)
        #expect(notified == 0)
        #expect(scene.isShowingResult)
        scene.beginDrag(at: CGPoint(x: 200, y: 200))
        #expect(scene.state == lost)
        #expect(scene.isShowingResult)
    }

    @Test("끝나는 연출 도중 씬 크기가 바뀌어도 결과를 한 번 알린다")
    func resizeDuringFinishNotifiesOnce() {
        let state = level(moves: 1)
        let scene = BoardScene(state: state, size: size)
        var notified = 0
        scene.onFinish = { _ in notified += 1 }
        drag(scene, state.possibleMoves()[0])
        #expect(scene.state.status == .lost)
        // 연출을 재생하는 동안에는 아직 알리지 않았다.
        #expect(notified == 0)
        // 다시 그리면 연출이 버려지므로, 그때 알린다.
        scene.size = CGSize(width: 800, height: 376)
        #expect(notified == 1)
        scene.size = CGSize(width: 390, height: 700)
        #expect(notified == 1)
        #expect(scene.deliverPendingResult() == false)
        #expect(notified == 1)
    }

    @Test("끝나는 연출 도중 나가려 하면 결과를 바로 알린다")
    func leavingDuringFinishDeliversResult() {
        let state = level(moves: 1)
        let scene = BoardScene(state: state, size: size)
        var notified = 0
        scene.onFinish = { _ in notified += 1 }
        #expect(scene.deliverPendingResult() == false)
        drag(scene, state.possibleMoves()[0])
        #expect(scene.deliverPendingResult())
        #expect(notified == 1)
        #expect(scene.isShowingResult)
        #expect(scene.deliverPendingResult() == false)
        #expect(notified == 1)
    }

    // MARK: - 힌트

    @Test("힌트는 가능한 이동 가운데 하나를 가리킨다")
    func hintIsAValidMove() {
        let state = level()
        let scene = BoardScene(state: state, size: size)
        #expect(scene.hintDelay == 5)
        let hint = scene.hintSwap
        #expect(hint != nil)
        #expect(state.possibleMoves().contains(hint!))
        #expect(state.rejection(for: hint!) == nil)
    }

    @Test("끝난 판에는 힌트가 없다")
    func noHintWhenFinished() {
        let lost = level(moves: 1).performTurn(level(moves: 1).possibleMoves()[0]).state
        #expect(BoardScene(state: lost, size: size).hintSwap == nil)
    }

    // MARK: - 그림

    @Test("일반 블록 6종은 그림으로 그린다")
    func blocksUseImages() {
        for kind in BlockKind.allCases {
            let name = BlockSprite.name(for: kind)
            #expect(BlockSprite.texture(named: name) != nil, "\(name).png가 없다")
            let node = BlockSprite.makeNode(block: .normal(kind), cellSize: 48)
            #expect(node is SKSpriteNode)
            #expect(node.name == name)
            // 칸을 넘지 않는다.
            #expect(node.frame.width <= 48 && node.frame.height <= 48)
        }
    }

    @Test("철망은 종류의 그림 위에 얹는다")
    func cageDecoratesImages() {
        let caged = BlockSprite.makeNode(block: .caged(.wood), cellSize: 48)
        #expect(caged is SKSpriteNode)
        #expect(caged.name == "block_wood_caged")
        #expect(caged.children.map(\.name) == ["cage"])
        #expect(caged.children.first is SKSpriteNode)
    }

    @Test("그림이 없는 것은 도형으로 그린다")
    func fallsBackToShapes() {
        #expect(BlockSprite.texture(named: "no_such_sprite") == nil)
        // 가로 3칸 물질은 그림이 없다.
        #expect(BlockSprite.makeMaterialNode(width: 3, height: 1, cellSize: 48) is SKShapeNode)
    }

    @Test("물질은 그림으로 그린다")
    func materialsUseImages() {
        #expect(BlockSprite.makeNode(block: .material, cellSize: 48) is SKSpriteNode)
        #expect(BlockSprite.makeNode(block: .material, cellSize: 48).name == "material")
        #expect(BlockSprite.makeMaterialNode(width: 2, height: 2, cellSize: 48).name == "material")
        #expect(BlockSprite.makeMaterialNode(width: 2, height: 1, cellSize: 48).name == "material")
    }

    @Test("격리 컨테이너는 그림으로 그리고, 보드 아래에서 벗어나지 않는다")
    func containerUsesImage() {
        let scene = BoardScene(state: GameState(seed: 1, rows: 16, moves: 20, materials: [Position(column: 2, row: 0)]), size: size)
        let frame = scene.containerDrawFrame
        #expect(BlockSprite.texture(named: BoardScene.containerSpriteName) != nil)
        #expect(frame.maxY == scene.sceneLayout.containerFrame.maxY)
        #expect(frame.width == scene.sceneLayout.board.frame.width)
        #expect(frame.minY >= 0 && frame.height >= scene.sceneLayout.containerFrame.height)
    }

    @Test("특수 블록과 장애물은 그림으로 그린다")
    func specialsAndObstaclesUseImages() {
        for name in ["block_beam_h", "block_beam_v", "block_bomb", "block_core", "obstacle_concrete_1", "obstacle_concrete_2", "obstacle_sludge"] {
            #expect(BlockSprite.texture(named: name) != nil, "\(name).png가 없다")
        }
        #expect(BlockSprite.makeNode(block: .sludge, cellSize: 48).name == "obstacle_sludge")
    }

    // MARK: - 별 막대

    @Test("별 막대는 점수가 별 3개 기준에 가까워질수록 차고, 기준을 넘긴 별만 센다")
    func starBar() {
        var state = GameState(seed: 1, rows: 16, moves: 20, materials: [Position(column: 2, row: 0)])
        let scene = BoardScene(state: state, size: size)
        // 기준을 주기 전에는 막대가 없다.
        #expect(scene.starsShown == 0)
        #expect(scene.starBarFraction == 0)
        scene.starScores = [100, 400]
        #expect(scene.starsShown == 0)
        #expect(scene.starBarFraction == 0)

        // 한 수 두어 점수를 얻은 판으로 다시 만든다.
        state = state.performTurn(state.possibleMoves()[0]).state
        #expect(state.score > 0)
        let played = BoardScene(state: state, size: size)
        played.starScores = [state.score, state.score * 2]
        #expect(played.starsShown == 1)
        #expect(played.starBarFraction == 0.5)
        played.starScores = [1, state.score]
        #expect(played.starsShown == 2)
        #expect(played.starBarFraction == 1)
    }

    @Test("수거함의 등은 수거한 물질 수만큼 켜진다")
    func containerLamps() {
        var state = GameState(seed: 4, rows: 12, moves: 20, materials: [Position(column: 2, row: 0), Position(column: 5, row: 0)])
        #expect(BoardScene(state: state, size: size).litContainerLamps == 0)
        // 물질 하나를 수거한 것으로 만든다.
        let collected = state.materials.removeFirst()
        state.board[collected.origin] = .normal(.brick)
        #expect(state.materialsTotal - state.materialsRemaining == 1)
        #expect(BoardScene(state: state, size: size).litContainerLamps == 1)
    }
}
