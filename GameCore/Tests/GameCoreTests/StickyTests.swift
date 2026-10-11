import Testing
@testable import GameCore

@Suite("끈끈이 바닥")
struct StickyTests {
    private func cleaned(_ events: [GameEvent]) -> [Position] {
        events.flatMap { event -> [Position] in
            if case .stickyCleared(let positions) = event { return positions }
            return []
        }
    }

    /// 맨 아래 행 왼쪽에서 (3,9)를 (2,9)로 밀면 가로 3개가 맞는 보드.
    private var board: Board {
        Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
    }

    @Test("레벨에 놓으면 칸에 붙고, 그 칸에는 블록이 그대로 생긴다")
    func placed() {
        let state = GameState(
            seed: 3, rows: 16, moves: 30, materials: [pos(2, 0)],
            obstacles: [Obstacle(kind: .sticky, position: pos(4, 5)), Obstacle(kind: .sticky, position: pos(5, 5))]
        )
        #expect(state.sticky == [pos(4, 5), pos(5, 5)])
        #expect(state.board[pos(4, 5)]?.kind != nil)
        #expect(!state.possibleMoves().isEmpty)
    }

    @Test("끈끈이 위의 블록은 밀 수 없고, 그 칸으로 밀어 넣을 수도 없다")
    func locked() {
        var state = GameState(board: board)
        state.sticky = [pos(3, 9)]
        #expect(state.rejection(for: swap((3, 9), (2, 9))) == .immovable)
        #expect(state.rejection(for: swap((2, 9), (3, 9))) == .immovable)
        #expect(!state.possibleMoves().contains { $0.from == pos(3, 9) || $0.to == pos(3, 9) })
    }

    @Test("그 칸의 블록이 매치되면 없어진다. 옆 칸의 매치로는 없어지지 않는다")
    func clearedByMatch() {
        var state = GameState(board: board)
        // 매치되는 칸 하나, 매치 바로 위의 칸 하나.
        state.sticky = [pos(1, 9), pos(1, 8)]
        let result = state.performTurn(swap((3, 9), (2, 9)))
        #expect(cleaned(result.events) == [pos(1, 9)])
        #expect(result.state.sticky == [pos(1, 8)])
    }

    @Test("특수 효과가 닿으면 없어진다")
    func clearedByEffect() {
        let board = Board.deadlocked(rows: 16).placing(.beam(.horizontal), at: (3, 5))
        var state = GameState(board: board)
        state.sticky = [pos(6, 5), pos(6, 7)]
        let result = state.performTurn(swap((3, 5), (4, 5)))
        #expect(cleaned(result.events).contains(pos(6, 5)))
        #expect(!result.state.sticky.contains(pos(6, 5)))
    }

    @Test("정화 망치로 치면 없어지고, 자리 바꾸기로는 옮길 수 없다")
    func tools() throws {
        var state = GameState(board: Board.deadlocked(rows: 16))
        state.sticky = [pos(3, 5)]
        #expect(state.freeSwapping(swap((3, 5), (4, 5))) == nil)
        let result = try #require(state.hammering(pos(3, 5)))
        #expect(result.events.contains(.stickyCleared([pos(3, 5)])))
        #expect(result.state.sticky.isEmpty)
    }

    @Test("끈끈이가 깔린 판을 끝까지 플레이할 수 있다")
    func playsToEnd() {
        let sticky = (2...5).flatMap { column in (4...6).map { Obstacle(kind: .sticky, position: pos(column, $0)) } }
        var state = GameState(seed: 8, rows: 16, moves: 400, materials: [pos(2, 0), pos(5, 0)], obstacles: sticky)
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            #expect(replay(result.events, on: before.board) == state.board)
        }
        #expect(state.status == .won)
    }
}
