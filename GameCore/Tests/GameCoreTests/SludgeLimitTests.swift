import Testing
@testable import GameCore

@Suite("슬러지의 상한")
struct SludgeLimitTests {
    @Test("화면의 슬러지가 상한에 이르면 더 번지지 않는다")
    func stopsAtLimit() {
        var board = Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
        // 위쪽 두 줄에 슬러지를 상한만큼 깐다.
        var placed = 0
        for row in 0..<2 {
            for column in 0..<8 where placed < GameConstants.sludgeSpreadLimit {
                board[column, row] = .sludge
                placed += 1
            }
        }
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(!result.events.contains { if case .sludgeSpread = $0 { true } else { false } })
        let count = result.state.board.positions.count { result.state.board[$0] == .sludge }
        #expect(count == GameConstants.sludgeSpreadLimit)
    }
}
