import Testing
@testable import GameCore

@Suite("포자 알")
struct EggTests {
    @Test("움직이지 않고 스왑할 수 없으며, 옆 매치에 피해를 입지 않는다")
    func properties() {
        #expect(Block.egg.isFixed)
        #expect(!Block.egg.isSwappable)
        #expect(!Block.egg.canSlide)
        #expect(Block.egg.kind == nil)
        #expect(!Block.egg.takesAdjacentHits)
        #expect(!Block.egg.isIndestructible)
        #expect(Block.concrete(hp: 1).takesAdjacentHits)
    }

    @Test("옆에서 매치해도 깨지지 않는다")
    func survivesAdjacentMatch() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.egg, at: (2, 8))
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(result.state.board[pos(2, 8)] == .egg)
        #expect(!result.events.contains { if case .obstaclesDamaged = $0 { true } else { false } })
    }

    @Test("특수 효과가 닿으면 깨진다")
    func brokenByEffect() {
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.egg, at: (6, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events.contains { event in
            if case .obstaclesDamaged(let hits) = event {
                return hits.contains { $0.position == pos(6, 5) && $0.remaining == nil }
            }
            return false
        })
    }

    @Test("정화 망치로 깨진다")
    func brokenByHammer() throws {
        let board = Board.deadlocked(rows: 16).placing(.egg, at: (3, 5))
        let result = try #require(GameState(board: board).hammering(pos(3, 5)))
        #expect(result.events.contains(.obstaclesDamaged([ObstacleHit(position: pos(3, 5), remaining: nil)])))
    }

    @Test("레벨에 놓을 수 있다")
    func placed() {
        let state = GameState(
            seed: 3, rows: 16, moves: 30, materials: [pos(2, 0)],
            obstacles: [Obstacle(kind: .egg, position: pos(4, 5))]
        )
        #expect(state.board[pos(4, 5)] == .egg)
    }
}
