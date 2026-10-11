import Testing
@testable import GameCore

@Suite("보드 모델")
struct BoardTests {
    @Test("상수는 3장의 값이다")
    func constants() {
        #expect(GameConstants.columns == 8)
        #expect(GameConstants.activeRows == 10)
        #expect(GameConstants.blockTypes == 5)
        #expect(GameConstants.blockTypeRange == 4...6)
        #expect(BlockKind.allCases.count == 6)
    }

    @Test("기본 보드는 8×10이고 비어 있다")
    func defaultSize() {
        let board = Board()
        #expect(board.columns == 8)
        #expect(board.rows == 10)
        #expect(board.positions.count == 80)
        #expect(board.positions.allSatisfy { board[$0] == nil })
    }

    @Test("행 0이 맨 위다")
    func rowZeroIsTop() {
        let board = Board(text: ["AB", "CD"])
        #expect(board[0, 0] == .normal(.brick))
        #expect(board[1, 0] == .normal(.scrap))
        #expect(board[0, 1] == .normal(.glass))
        #expect(board[pos(1, 1)] == .normal(.wood))
        #expect(board.kind(at: pos(1, 1)) == .wood)
    }

    @Test("보드 범위 검사")
    func contains() {
        let board = Board()
        #expect(board.contains(pos(0, 0)))
        #expect(board.contains(pos(7, 9)))
        #expect(!board.contains(pos(8, 0)))
        #expect(!board.contains(pos(0, 10)))
        #expect(!board.contains(pos(-1, 0)))
    }

    @Test("칸 교환")
    func swapAt() {
        var board = Board(text: ["AB"])
        board.swapAt(pos(0, 0), pos(1, 0))
        #expect(board == Board(text: ["BA"]))
    }
}

@Suite("낙하")
struct GravityTests {
    @Test("빈칸 위의 블록이 아래로 떨어진다")
    func blocksFall() {
        var board = Board(text: [
            "A.C",
            "B..",
            "..D",
            "E.."
        ])
        let moves = board.applyGravity()
        #expect(board == Board(text: [
            "...",
            "A..",
            "B.C",
            "E.D"
        ]))
        #expect(moves == [
            BlockMove(from: pos(0, 1), to: pos(0, 2)),
            BlockMove(from: pos(0, 0), to: pos(0, 1)),
            BlockMove(from: pos(2, 2), to: pos(2, 3)),
            BlockMove(from: pos(2, 0), to: pos(2, 2)),
        ])
    }

    @Test("빈칸이 없으면 아무것도 움직이지 않는다")
    func fullBoardDoesNotMove() {
        var board = Board.deadlocked
        #expect(board.applyGravity().isEmpty)
        #expect(board == .deadlocked)
    }

    @Test("바닥에 닿은 블록은 그대로다")
    func settledBlocksStay() {
        var board = Board(text: ["..", "..", "AB"])
        #expect(board.applyGravity().isEmpty)
    }

    @Test("8×10 보드에서 한 줄을 지우면 그 위가 한 칸씩 내려온다")
    func rowClearOnFullBoard() {
        let original = Board.deadlocked
        var board = original.setting(nil, at: [(2, 9), (3, 9), (4, 9)])
        let moves = board.applyGravity()
        #expect(moves.count == 27)
        for column in 2...4 {
            #expect(board[column, 0] == nil)
            for row in 1...9 {
                #expect(board[column, row] == original[column, row - 1])
            }
        }
        #expect(board[1, 9] == original[1, 9])
    }
}
