import Testing
@testable import GameCore

@Suite("스왑 검증")
struct SwapTests {
    /// (3,9)의 soil을 왼쪽으로 옮기면 맨 아래 행에 가로 3개가 된다.
    let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9)])

    @Test("매치가 생기는 스왑은 유효하다")
    func validSwap() {
        #expect(board.rejection(for: swap((3, 9), (2, 9))) == nil)
        #expect(board.isValid(swap((3, 9), (2, 9))))
    }

    @Test("방향을 뒤집어도 같은 스왑이다")
    func validSwapReversed() {
        #expect(board.isValid(swap((2, 9), (3, 9))))
    }

    @Test("세로 스왑")
    func verticalSwap() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (2, 8)])
        #expect(board.isValid(swap((2, 8), (2, 9))))
    }

    @Test("매치가 생기지 않으면 거부한다")
    func noMatch() {
        #expect(board.rejection(for: swap((5, 5), (6, 5))) == .noMatch)
    }

    @Test("붙어 있지 않은 칸은 거부한다", arguments: [
        swap((3, 9), (1, 9)),
        swap((3, 9), (2, 8)),
        swap((3, 9), (3, 9)),
    ])
    func notAdjacent(swap: Swap) {
        #expect(board.rejection(for: swap) == .notAdjacent)
    }

    @Test("보드 밖은 거부한다", arguments: [
        swap((7, 9), (8, 9)),
        swap((0, 9), (0, 10)),
        swap((-1, 0), (0, 0)),
    ])
    func outOfBounds(swap: Swap) {
        #expect(board.rejection(for: swap) == .outOfBounds)
    }

    @Test("빈칸과는 교환할 수 없다")
    func emptyCell() {
        let holed = board.setting(nil, at: [(2, 9)])
        #expect(holed.rejection(for: swap((3, 9), (2, 9))) == .emptyCell)
    }

    @Test("거부된 스왑은 보드를 바꾸지 않고 난수도 쓰지 않는다")
    func rejectedSwapLeavesStateUnchanged() {
        let state = GameState(board: board)
        let rejected = swap((5, 5), (6, 5))
        let result = state.performTurn(rejected)
        #expect(result.state == state)
        #expect(result.events == [.swapRejected(rejected, .noMatch)])
    }
}

@Suite("가능한 이동 탐색")
struct PossibleMovesTests {
    @Test("이동이 없는 보드")
    func deadlocked() {
        #expect(Board.deadlocked.possibleMoves().isEmpty)
        #expect(!Board.deadlocked.hasPossibleMove)
    }

    @Test("이동이 하나뿐인 보드에서 그 이동을 찾는다")
    func singleMove() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
        #expect(board.possibleMoves() == [swap((2, 9), (3, 9))])
        #expect(board.hasPossibleMove)
    }

    @Test("가로와 세로 이동을 모두 찾는다")
    func horizontalAndVertical() {
        // (2,9) 자리에 soil이 오면 매치다. 오른쪽과 위쪽에서 올 수 있다.
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9), (2, 8)])
        #expect(Set(board.possibleMoves()) == [swap((2, 9), (3, 9)), swap((2, 8), (2, 9))])
    }

    @Test("찾은 이동은 모두 유효하고, 유효한 이동은 모두 찾는다")
    func agreesWithValidation() {
        for seed in 0..<20 as Range<UInt64> {
            let board = GameState(seed: seed).board
            let found = Set(board.possibleMoves())
            #expect(!found.isEmpty)
            for from in board.positions {
                for to in [pos(from.column + 1, from.row), pos(from.column, from.row + 1)] {
                    let candidate = Swap(from: from, to: to)
                    #expect(found.contains(candidate) == board.isValid(candidate))
                }
            }
        }
    }
}
