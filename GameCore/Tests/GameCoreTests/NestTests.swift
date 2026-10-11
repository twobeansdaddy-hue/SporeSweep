import Testing
@testable import GameCore

@Suite("포자 둥지")
struct NestTests {
    /// 둥지에서 멀리 떨어진 맨 아래 행의 매치.
    let farMove = swap((3, 9), (2, 9))
    var board: Board {
        Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)]).placing(.nest(hp: 2), at: (6, 2))
    }

    private func spits(_ events: [GameEvent]) -> [NestSpit] {
        events.flatMap { event -> [NestSpit] in
            if case .nestsSpat(let spits) = event { return spits }
            return []
        }
    }

    @Test("움직이지 않고 스왑할 수 없으며 옆 매치에 피해를 입는다")
    func properties() {
        #expect(Block.nest(hp: 2).isFixed)
        #expect(!Block.nest(hp: 2).isSwappable)
        #expect(!Block.nest(hp: 2).canSlide)
        #expect(Block.nest(hp: 2).kind == nil)
        #expect(Block.nest(hp: 2).takesAdjacentHits)
    }

    @Test("뱉을 차례가 아닌 턴에는 턴만 센다")
    func countsDown() {
        let result = GameState(board: board).performTurn(farMove)
        #expect(spits(result.events).isEmpty)
        #expect(result.state.turnsUntilNestSpit == GameConstants.nestSpitInterval - 1)
    }

    @Test("차례가 되면 옆 칸의 블록 하나를 슬러지로 바꾸고 다시 센다")
    func spitsOnInterval() {
        var state = GameState(board: board)
        state.turnsUntilNestSpit = 1
        let result = state.performTurn(farMove)
        let spat = spits(result.events)
        #expect(spat.count == 1)
        #expect(spat[0].nest == pos(6, 2))
        #expect([pos(6, 1), pos(6, 3), pos(5, 2), pos(7, 2)].contains(spat[0].target))
        #expect(result.state.board[spat[0].target] == .sludge)
        #expect(result.state.turnsUntilNestSpit == GameConstants.nestSpitInterval)
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("둥지마다 한 칸씩 뱉는다")
    func everyNestSpits() {
        // 매치가 떨어뜨리는 열에서 먼 곳에 둔다.
        let board = board.placing(.nest(hp: 2), at: (6, 6))
        var state = GameState(board: board)
        state.turnsUntilNestSpit = 1
        let result = state.performTurn(farMove)
        #expect(Set(spits(result.events).map(\.nest)) == [pos(6, 2), pos(6, 6)])
    }

    @Test("둥지가 없으면 세지 않는다")
    func noNestNoCount() {
        let board = Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
        var state = GameState(board: board)
        state.turnsUntilNestSpit = 1
        let result = state.performTurn(farMove)
        #expect(spits(result.events).isEmpty)
        #expect(result.state.turnsUntilNestSpit == GameConstants.nestSpitInterval)
    }

    @Test("옆에서 두 번 매치해야 부서진다")
    func takesTwoHits() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.nest(hp: 2), at: (2, 8))
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(result.events.contains(.obstaclesDamaged([ObstacleHit(position: pos(2, 8), remaining: .nest(hp: 1))])))
        let weak = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.nest(hp: 1), at: (2, 8))
        let second = GameState(board: weak).performTurn(swap((3, 9), (2, 9)))
        #expect(second.events.contains(.obstaclesDamaged([ObstacleHit(position: pos(2, 8), remaining: nil)])))
    }

    @Test("특수 효과가 닿으면 피해를 입는다")
    func damagedByEffects() {
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.nest(hp: 2), at: (6, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events.contains { event in
            if case .obstaclesDamaged(let hits) = event {
                return hits.contains { $0.position == pos(6, 5) && $0.remaining == .nest(hp: 1) }
            }
            return false
        })
    }

    @Test("둥지가 놓인 판을 끝까지 플레이할 수 있다")
    func playsToEnd() {
        var state = GameState(
            seed: 8, rows: 16, moves: 400, materials: [pos(2, 0), pos(5, 0)],
            obstacles: [(1, 4), (5, 6)].map { Obstacle(kind: .nest(hp: 2), position: pos($0.0, $0.1)) }
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
