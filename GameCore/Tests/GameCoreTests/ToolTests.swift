import Testing
@testable import GameCore

@Suite("아이템")
struct ToolTests {
    @Test("정화 망치는 블록 하나를 부수고 이동 횟수를 쓰지 않는다")
    func hammerBreaksBlock() throws {
        let board = Board.deadlocked(rows: 16)
        var state = GameState(board: board)
        state.movesRemaining = 7
        let result = try #require(state.hammering(pos(3, 5)))
        #expect(result.events.first == .hammered(pos(3, 5)))
        #expect(result.state.movesRemaining == 7)
        #expect(result.state.score >= GameConstants.scorePerBlock)
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("정화 망치로 장애물을 치면 한 번 때린 것으로 친다")
    func hammerHitsObstacle() throws {
        let board = Board.deadlocked(rows: 16).placing(.concrete(hp: 2), at: (3, 5)).placing(.nest(hp: 1), at: (5, 5))
        let first = try #require(GameState(board: board).hammering(pos(3, 5)))
        #expect(first.state.board[pos(3, 5)] == .concrete(hp: 1))
        let second = try #require(GameState(board: board).hammering(pos(5, 5)))
        #expect(second.events.contains(.obstaclesDamaged([ObstacleHit(position: pos(5, 5), remaining: nil)])))
    }

    @Test("정화 망치는 오염 물질과 벽, 빈칸에는 쓸 수 없다")
    func hammerLimits() {
        let board = Board.deadlocked(rows: 16).placing(.wall, at: (3, 5)).placing(.material, at: (4, 5)).setting(nil, at: [(5, 0)])
        let state = GameState(board: board)
        #expect(state.hammering(pos(3, 5)) == nil)
        #expect(state.hammering(pos(4, 5)) == nil)
        #expect(!state.canHammer(pos(5, 0)))
        // 화면 밖의 칸.
        #expect(!state.canHammer(pos(3, 14)))
    }

    @Test("정화 망치로 친 칸의 안개가 걷힌다")
    func hammerLiftsFog() throws {
        var state = GameState(board: Board.deadlocked(rows: 16))
        state.fog = [pos(3, 5), pos(6, 2)]
        let result = try #require(state.hammering(pos(3, 5)))
        #expect(result.events.contains(.fogLifted([pos(3, 5)])))
        #expect(result.state.fog == [pos(6, 2)])
    }

    @Test("시한 포자가 붙은 블록을 망치로 부수면 터지지 않는다")
    func hammerDefusesTimer() throws {
        let board = Board.deadlocked(rows: 16).placing(.timed(.brick, turns: 1), at: (3, 5))
        let result = try #require(GameState(board: board).hammering(pos(3, 5)))
        #expect(!result.events.contains { if case .timersBurst = $0 { true } else { false } })
        #expect(!result.state.board.positions.contains { result.state.board[$0] == .sludge })
    }

    @Test("자리 바꾸기는 매치가 되지 않아도 바꾸고 이동 횟수를 쓰지 않는다")
    func freeSwap() throws {
        let board = Board.deadlocked(rows: 16)
        var state = GameState(board: board)
        state.movesRemaining = 7
        let swap = swap((3, 5), (4, 5))
        #expect(state.rejection(for: swap) == .noMatch)
        let result = try #require(state.freeSwapping(swap))
        #expect(result.state.movesRemaining == 7)
        // 둘 곳이 없는 보드라 바꾼 뒤에 섞일 수 있다. 바꿨다는 것은 이벤트로 본다.
        #expect(result.events.first == .swapped(swap))
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("자리 바꾸기로도 장애물은 옮길 수 없다")
    func freeSwapLimits() {
        let board = Board.deadlocked(rows: 16).placing(.concrete(hp: 1), at: (3, 5))
        #expect(GameState(board: board).freeSwapping(swap((3, 5), (4, 5))) == nil)
    }

    @Test("섞기는 일반 블록을 다시 섞고 이동 횟수를 쓰지 않는다")
    func shuffle() throws {
        var state = GameState(seed: 4, rows: 16, moves: 9, materials: [pos(2, 0)])
        state.movesRemaining = 9
        let result = try #require(state.shuffling())
        #expect(result.state.movesRemaining == 9)
        #expect(result.state.board[pos(2, 0)] == .material)
        #expect(result.state.board.findMatches(in: result.state.activeRange).isEmpty)
    }
}
