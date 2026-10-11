import Testing
@testable import GameCore

@Suite("시작 부스터")
struct BoosterTests {
    func fresh() -> GameState {
        GameState(seed: 21, rows: 16, moves: 30, materials: [pos(2, 0), pos(5, 0)])
    }

    @Test("고른 특수 블록이 처음 보이는 구간의 일반 블록 자리에 놓인다")
    func placesSpecials() {
        let before = fresh()
        var state = before
        let placed = state.apply([.beam, .bomb, .core])
        #expect(placed.count == 3)
        #expect(Set(placed).count == 3)
        for position in placed {
            #expect(state.activeRange.contains(position.row))
            #expect(state.board[position]?.isSpecial == true)
            if case .normal = before.board[position] {} else { Issue.record("일반 블록이 아닌 자리에 놓였다") }
        }
        let specials = state.board.positions.compactMap { state.board[$0] }.filter(\.isSpecial)
        #expect(specials.count == 3)
        #expect(specials.contains(.bomb) && specials.contains(.core))
        #expect(specials.contains { if case .beam = $0 { true } else { false } })
        // 물질과 이동 횟수, 나머지 블록은 그대로다.
        #expect(state.materials == before.materials)
        #expect(state.movesRemaining == 30)
        #expect(before.board.positions.filter { before.board[$0] != state.board[$0] }.count == 3)
    }

    @Test("새 매치가 생기지 않고, 놓인 특수 블록은 바로 밀어 쓸 수 있다")
    func boardStaysValid() {
        var state = fresh()
        let placed = state.apply([.bomb])
        #expect(state.board.findMatches(in: state.activeRange).isEmpty)
        #expect(state.possibleMoves().contains { $0.from == placed[0] || $0.to == placed[0] })
    }

    @Test("이동 추가는 이동 횟수를 5 늘리고 보드는 바꾸지 않는다")
    func extraMoves() {
        var state = fresh()
        let board = state.board
        #expect(state.apply([.extraMoves]).isEmpty)
        #expect(state.movesRemaining == 35)
        #expect(state.board == board)
        #expect(Booster.extraMoveCount == 5)
    }

    @Test("같은 판에 같은 부스터를 쓰면 고른 순서와 상관없이 같은 결과가 난다")
    func deterministic() {
        var first = fresh()
        var second = fresh()
        first.apply([.beam, .bomb, .extraMoves])
        second.apply([.extraMoves, .bomb, .beam])
        #expect(first == second)
    }

    @Test("아무것도 고르지 않으면 판이 그대로다")
    func nothing() {
        var state = fresh()
        state.apply([])
        #expect(state == fresh())
    }
}
