import Testing
@testable import GameCore

@Suite("둘 곳이 없을 때")
struct RescueTests {
    @Test("장애물에 막혀 섞어도 둘 곳이 없으면 중화 폭탄을 놓아 주고 판을 잇는다")
    func rescues() {
        // 일반 블록이 두 개뿐이라 어떻게 섞어도 매치를 만들 수 없다.
        var board = Board(columns: 8, rows: 10)
        for position in board.positions {
            board[position] = .wall
        }
        board[pos(3, 4)] = .normal(.brick)
        board[pos(4, 4)] = .normal(.scrap)
        board[pos(3, 5)] = .material
        var state = GameState(board: board)
        state.movesRemaining = 5
        let result = state.settle()
        #expect(result.state.status == .playing)
        #expect(result.events.contains { event in
            if case .specialsCreated(let spawns) = event { return spawns.contains { $0.block == .bomb } }
            return false
        })
        #expect(!result.state.possibleMoves().isEmpty)
    }
}
