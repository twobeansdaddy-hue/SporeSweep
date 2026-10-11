import Testing
@testable import GameCore

@Suite("잔해 더미")
struct RubbleTests {
    @Test("스왑할 수 없고 매치에 들지 않지만, 고정돼 있지 않다")
    func properties() {
        #expect(!Block.rubble.isFixed)
        #expect(!Block.rubble.isSwappable)
        #expect(!Block.rubble.canSlide)
        #expect(Block.rubble.kind == nil)
        #expect(Block.rubble.takesAdjacentHits)
        #expect(Block.concrete(hp: 1).takesAdjacentHits)
        #expect(!Block.normal(.brick).takesAdjacentHits)
    }

    @Test("옆에서 매치하면 치워진다")
    func clearedByAdjacentMatch() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.rubble, at: (2, 8))
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(result.events.contains(.obstaclesDamaged([ObstacleHit(position: pos(2, 8), remaining: nil)])))
        #expect(!result.state.board.positions.contains { result.state.board[$0] == .rubble })
    }

    @Test("아래가 비면 블록처럼 떨어진다")
    func falls() {
        // 잔해 아래의 세로 3칸이 한 번에 지워진다. 잔해는 그 매치와 붙어 있지 않게 한 칸 띄운다.
        let board = Board.deadlocked(rows: 16)
            .placing(.rubble, at: (2, 2))
            .setting(.soil, at: [(2, 4), (2, 5), (2, 6)])
        let result = GameState(board: board).settle()
        let rubble = result.state.board.positions.filter { result.state.board[$0] == .rubble }
        #expect(rubble == [pos(2, 5)])
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("특수 효과가 닿으면 치워진다")
    func clearedByEffects() {
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.rubble, at: (6, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events.contains { event in
            if case .obstaclesDamaged(let hits) = event { return hits.contains { $0.position == pos(6, 5) } }
            return false
        })
    }

    @Test("잔해가 놓인 판을 끝까지 플레이할 수 있다")
    func playsToEnd() {
        var state = GameState(
            seed: 8, rows: 16, moves: 300, materials: [pos(2, 0), pos(5, 0)],
            obstacles: [(1, 4), (2, 5), (5, 4), (6, 6)].map { Obstacle(kind: .rubble, position: pos($0.0, $0.1)) }
        )
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            #expect(replay(result.events, on: before.board) == state.board)
        }
        #expect(state.status == .won)
    }
}
