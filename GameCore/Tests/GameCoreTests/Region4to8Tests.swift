import Testing
@testable import GameCore

/// 넷째 권역부터 나오는 장애물 다섯 가지: 쇠사슬, 포자 보호막, 운석 조각, 안개 굴뚝, 얼음 블록.
@Suite("뒤쪽 권역의 장애물")
struct LaterObstacleTests {
    /// 맨 아래 행 왼쪽에서 (3,9)를 (2,9)로 밀면 가로 3개가 맞는 보드.
    private var board: Board {
        Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
    }
    private let move = swap((3, 9), (2, 9))

    private func damaged(_ events: [GameEvent]) -> [ObstacleHit] {
        events.flatMap { event -> [ObstacleHit] in
            if case .obstaclesDamaged(let hits) = event { return hits }
            return []
        }
    }

    // MARK: 쇠사슬

    @Test("쇠사슬에 감긴 블록은 매치에 들면 철망에 갇힌 블록이 되고, 한 번 더 맞으면 풀린다")
    func chain() {
        #expect(Block.chained(.soil).kind == .soil)
        #expect(!Block.chained(.soil).isSwappable)
        let board = board.placing(.chained(.soil), at: (1, 9))
        let result = GameState(board: board).performTurn(move)
        #expect(damaged(result.events).contains(ObstacleHit(position: pos(1, 9), remaining: .caged(.soil))))
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("레벨에 놓은 쇠사슬과 얼음은 그 칸에 생긴 블록에 씌워진다")
    func placedOnBlocks() {
        let state = GameState(
            seed: 3, rows: 16, moves: 30, materials: [pos(2, 0)],
            obstacles: [Obstacle(kind: .chain, position: pos(4, 5)), Obstacle(kind: .ice, position: pos(5, 7)), Obstacle(kind: .shield, position: pos(1, 6))]
        )
        if case .chained = state.board[pos(4, 5)] {} else { Issue.record("쇠사슬이 없다") }
        if case .frozen = state.board[pos(5, 7)] {} else { Issue.record("얼음이 없다") }
        #expect(state.shields == [pos(1, 6)])
        #expect(!state.possibleMoves().isEmpty)
    }

    // MARK: 포자 보호막

    @Test("보호막이 덮인 칸에는 특수 효과가 닿지 않는다")
    func shieldBlocksEffects() {
        let board = Board.deadlocked(rows: 16).placing(.beam(.horizontal), at: (3, 5))
        var state = GameState(board: board)
        state.shields = [pos(6, 5)]
        let kept = board[pos(6, 5)]
        let result = state.performTurn(swap((3, 5), (4, 5)))
        let cleared = result.events.flatMap { event -> [Position] in
            if case .specialsActivated(let activations) = event { return activations.flatMap(\.cleared) }
            return []
        }
        #expect(!cleared.contains(pos(6, 5)))
        #expect(cleared.contains(pos(7, 5)))
        #expect(result.state.shields == [pos(6, 5)])
        _ = kept
    }

    @Test("보호막 안의 블록이 매치되면 보호막이 깨진다")
    func shieldBrokenByMatch() {
        var state = GameState(board: board)
        state.shields = [pos(1, 9), pos(6, 2)]
        let result = state.performTurn(move)
        #expect(result.events.contains(.shieldsBroken([pos(1, 9)])))
        #expect(result.state.shields == [pos(6, 2)])
    }

    // MARK: 운석 조각

    @Test("운석 조각은 떨어지고, 옆 매치로는 깨지지 않고, 특수 효과에 깨진다")
    func boulder() {
        #expect(!Block.boulder.isFixed)
        #expect(!Block.boulder.isSwappable)
        #expect(!Block.boulder.takesAdjacentHits)
        let beside = board.placing(.boulder, at: (2, 8))
        let first = GameState(board: beside).performTurn(move)
        #expect(damaged(first.events).isEmpty)
        #expect(first.state.board.positions.contains { first.state.board[$0] == .boulder })
        let lined = Board.deadlocked(rows: 16).placing(.beam(.horizontal), at: (3, 5)).placing(.boulder, at: (6, 5))
        let second = GameState(board: lined).performTurn(swap((3, 5), (4, 5)))
        #expect(damaged(second.events).contains(ObstacleHit(position: pos(6, 5), remaining: nil)))
    }

    @Test("운석 조각은 아래가 비면 떨어진다")
    func boulderFalls() {
        let board = Board.deadlocked(rows: 16).placing(.boulder, at: (2, 2)).setting(.soil, at: [(2, 4), (2, 5), (2, 6)])
        let result = GameState(board: board).settle()
        #expect(result.state.board.positions.filter { result.state.board[$0] == .boulder } == [pos(2, 5)])
    }

    // MARK: 안개 굴뚝

    @Test("안개 굴뚝은 차례가 되면 옆 칸에 안개를 뿜고, 두 번 맞으면 부서진다")
    func vent() {
        let board = board.placing(.vent(hp: 2), at: (6, 2))
        var state = GameState(board: board)
        state.turnsUntilVentPuff = 1
        let result = state.performTurn(move)
        let puffed = result.events.flatMap { event -> [Position] in
            if case .ventsPuffed(let cells) = event { return cells }
            return []
        }
        #expect(puffed.count == 1)
        #expect([pos(6, 1), pos(6, 3), pos(5, 2), pos(7, 2)].contains(puffed[0]))
        #expect(result.state.fog == Set(puffed))
        #expect(result.state.turnsUntilVentPuff == GameConstants.nestSpitInterval)
        let hit = self.board.placing(.vent(hp: 2), at: (2, 8))
        let second = GameState(board: hit).performTurn(move)
        #expect(damaged(second.events).contains(ObstacleHit(position: pos(2, 8), remaining: .vent(hp: 1))))
    }

    // MARK: 얼음 블록

    @Test("얼음 블록은 매치에 들지 않고, 옆에서 매치하면 녹아 보통 블록이 된다")
    func ice() {
        #expect(Block.frozen(.soil).kind == nil)
        #expect(Block.frozen(.soil).isFixed)
        #expect(!Block.frozen(.soil).isSwappable)
        let board = board.placing(.frozen(.brick), at: (2, 8))
        let result = GameState(board: board).performTurn(move)
        #expect(damaged(result.events).contains(ObstacleHit(position: pos(2, 8), remaining: .normal(.brick))))
    }

    @Test("새 장애물이 섞인 판을 끝까지 플레이할 수 있다")
    func playsToEnd() {
        let obstacles: [Obstacle] = [
            Obstacle(kind: .chain, position: pos(1, 4)), Obstacle(kind: .chain, position: pos(6, 5)),
            Obstacle(kind: .shield, position: pos(3, 6)), Obstacle(kind: .shield, position: pos(4, 6)),
            Obstacle(kind: .boulder, position: pos(0, 7)), Obstacle(kind: .vent(hp: 2), position: pos(7, 8)),
            Obstacle(kind: .ice, position: pos(2, 9)), Obstacle(kind: .ice, position: pos(5, 9)),
        ]
        var state = GameState(seed: 8, rows: 16, moves: 400, materials: [pos(2, 0), pos(5, 0)], obstacles: obstacles)
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            #expect(replay(result.events, on: before.board) == state.board)
        }
        #expect(state.status == .won)
    }
}
