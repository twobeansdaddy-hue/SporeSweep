import Testing
@testable import GameCore

@Suite("오염 고치")
struct CocoonTests {
    /// 맨 아래 행에서 soil 3개를 맞추는 보드. 그 매치 바로 위 (2,8)에 `lock`을 둔다.
    func result(lock kind: BlockKind) -> TurnResult {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.cocoon(kind), at: (2, 8))
        return GameState(board: board).performTurn(swap((3, 9), (2, 9)))
    }

    @Test("고정돼 있고 스왑할 수 없고 매치에 들지 않는다")
    func properties() {
        let lock = Block.cocoon(.glass)
        #expect(lock.isFixed)
        #expect(!lock.isSwappable)
        #expect(!lock.canSlide)
        #expect(lock.kind == nil)
        #expect(!lock.isIndestructible)
    }

    @Test("옆에서 고치에 갇힌 것과 같은 종류를 맞추면 터진다")
    func opensWithMatchingKind() {
        let outcome = result(lock: .soil)
        #expect(outcome.events.contains(.obstaclesDamaged([ObstacleHit(position: pos(2, 8), remaining: nil)])))
        #expect(!outcome.state.board.positions.contains { outcome.state.board[$0] == .cocoon(.soil) })
    }

    @Test("옆에서 다른 종류를 맞추면 터지지 않는다")
    func staysWithOtherKind() {
        let outcome = result(lock: .glass)
        #expect(outcome.state.board[2, 8] == .cocoon(.glass))
        #expect(!outcome.events.contains { if case .obstaclesDamaged = $0 { true } else { false } })
    }

    @Test("특수 효과가 닿으면 종류와 상관없이 터진다")
    func opensWithEffects() {
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.cocoon(.glass), at: (6, 5))
        let outcome = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(outcome.events.contains { event in
            if case .obstaclesDamaged(let hits) = event { return hits.contains { $0.position == pos(6, 5) && $0.remaining == nil } }
            return false
        })
    }

    @Test("이름으로 종류를 읽는다")
    func kindNames() {
        for kind in BlockKind.allCases {
            #expect(BlockKind(name: kind.name) == kind)
        }
        #expect(BlockKind(name: "nothing") == nil)
    }

    @Test("오염 고치가 놓인 판을 만들 수 있고, 고치 위의 블록은 얹혀 있다")
    func generatesBoard() {
        let state = GameState(
            seed: 5, rows: 16, moves: 30, materials: [pos(2, 0)],
            obstacles: [Obstacle(kind: .cocoon(.scrap), position: pos(4, 6))]
        )
        #expect(state.board[4, 6] == .cocoon(.scrap))
        #expect(state.board.findMatches(in: state.activeRange).isEmpty)
        #expect(state.board[4, 5] != nil)
    }
}
