import Testing
@testable import GameCore

@Suite("오염 안개")
struct FogTests {
    private func lifted(_ events: [GameEvent]) -> [Position] {
        events.flatMap { event -> [Position] in
            if case .fogLifted(let positions) = event { return positions }
            return []
        }
    }

    /// 맨 아래 행 왼쪽에서 가로 3개가 맞는 보드.
    private var board: Board {
        Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
    }

    @Test("레벨에 놓으면 칸에 붙고, 그 칸에는 블록이 그대로 생긴다")
    func placed() {
        let state = GameState(
            seed: 3, rows: 16, moves: 30, materials: [pos(2, 0)],
            obstacles: [Obstacle(kind: .fog, position: pos(4, 5)), Obstacle(kind: .fog, position: pos(5, 5))]
        )
        #expect(state.fog == [pos(4, 5), pos(5, 5)])
        #expect(state.board[pos(4, 5)]?.kind != nil)
    }

    @Test("안개 낀 칸의 블록도 밀 수 있고, 매치된 칸과 그 옆의 안개가 걷힌다")
    func liftedByMatch() {
        var state = GameState(board: board)
        // 매치되는 칸, 그 바로 위, 멀리 떨어진 칸.
        state.fog = [pos(3, 9), pos(1, 8), pos(6, 2)]
        let result = state.performTurn(swap((3, 9), (2, 9)))
        #expect(Set(lifted(result.events)) == [pos(3, 9), pos(1, 8)])
        #expect(result.state.fog == [pos(6, 2)])
    }

    @Test("먼 곳의 매치로는 걷히지 않는다")
    func staysWhenFar() {
        var state = GameState(board: board)
        state.fog = [pos(6, 2)]
        let result = state.performTurn(swap((3, 9), (2, 9)))
        #expect(lifted(result.events).isEmpty)
        #expect(result.state.fog == [pos(6, 2)])
    }

    @Test("특수 효과가 닿은 칸의 안개가 걷힌다")
    func liftedByEffect() {
        let board = Board.deadlocked(rows: 16).placing(.beam(.horizontal), at: (3, 5))
        var state = GameState(board: board)
        state.fog = [pos(6, 5), pos(6, 7)]
        let result = state.performTurn(swap((3, 5), (4, 5)))
        #expect(lifted(result.events).contains(pos(6, 5)))
        #expect(result.state.fog.contains(pos(6, 7)) || lifted(result.events).contains(pos(6, 7)))
        #expect(!result.state.fog.contains(pos(6, 5)))
    }

    @Test("안개는 칸에 붙어 있어서 블록이 떨어져도 따라가지 않는다")
    func staysOnCell() {
        var state = GameState(board: board)
        state.fog = [pos(1, 4)]
        let result = state.performTurn(swap((3, 9), (2, 9)))
        #expect(result.state.fog == [pos(1, 4)])
    }

    @Test("안개가 낀 판을 끝까지 플레이할 수 있다")
    func playsToEnd() {
        let fog = (2...5).flatMap { column in (4...6).map { Obstacle(kind: .fog, position: pos(column, $0)) } }
        var state = GameState(seed: 8, rows: 16, moves: 400, materials: [pos(2, 0), pos(5, 0)], obstacles: fog)
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            #expect(replay(result.events, on: before.board) == state.board)
        }
        #expect(state.status == .won)
    }
}
