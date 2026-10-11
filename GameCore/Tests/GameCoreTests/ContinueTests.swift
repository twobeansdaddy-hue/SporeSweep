import Testing
@testable import GameCore

@Suite("이어 하기")
struct ContinueTests {
    /// 이동 한 번에 지는 판.
    private func lostState() -> GameState {
        var state = GameState(seed: 5, rows: 16, moves: 1, materials: [pos(2, 0)])
        state = state.performTurn(state.greedyMove()).state
        return state
    }

    @Test("이동 횟수를 다 써서 진 판은 이동 횟수를 받아 이어 할 수 있다")
    func continues() {
        var state = lostState()
        #expect(state.status == .lost)
        #expect(state.canContinue)
        let board = state.board
        let score = state.score
        let continued = state.continuePlaying(extraMoves: 5)
        #expect(continued)
        #expect(state.status == .playing)
        #expect(state.movesRemaining == 5)
        #expect(state.board == board)
        #expect(state.score == score)
        // 이어서 둘 수 있다.
        let result = state.performTurn(state.greedyMove())
        #expect(result.state.movesRemaining == 4)
    }

    @Test("하는 중이거나 이긴 판은 이어 할 수 없다")
    func notWhilePlaying() {
        var state = GameState(seed: 5, rows: 16, moves: 10, materials: [pos(2, 0)])
        #expect(!state.canContinue)
        let continued = state.continuePlaying(extraMoves: 5)
        #expect(!continued)
        #expect(state.movesRemaining == 10)
    }
}
