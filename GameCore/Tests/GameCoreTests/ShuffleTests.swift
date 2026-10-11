import Testing
@testable import GameCore

@Suite("셔플")
struct ShuffleTests {
    @Test("가능한 이동이 없으면 섞는다")
    func shufflesDeadlockedBoard() {
        let state = GameState(board: .deadlocked)
        let result = state.settle()

        #expect(result.events.count == 1)
        guard case .shuffled(let moves) = result.events[0] else {
            Issue.record("셔플 이벤트가 없다: \(result.events)")
            return
        }
        let shuffled = result.state.board
        #expect(shuffled != state.board)
        #expect(shuffled.findMatches().isEmpty)
        #expect(shuffled.hasPossibleMove)
        #expect(shuffled.isFull)

        // 블록을 새로 만들지 않고 자리만 바꾼다.
        #expect(shuffled.kindCounts == state.board.kindCounts)
        #expect(Set(moves.map(\.from)) == Set(moves.map(\.to)))
        for move in moves {
            #expect(shuffled[move.to] == state.board[move.from])
        }
        let moved = Set(moves.map(\.to))
        for position in shuffled.positions where !moved.contains(position) {
            #expect(shuffled[position] == state.board[position])
        }
    }

    @Test("가능한 이동이 있으면 섞지 않는다")
    func doesNotShuffleWhenMovesExist() {
        let state = GameState(seed: 5)
        let result = state.settle()
        #expect(result.events.isEmpty)
        #expect(result.state == state)
    }

    @Test("같은 시드는 같은 셔플 결과를 낸다")
    func shuffleIsDeterministic() {
        let a = GameState(board: .deadlocked, seed: 42).settle()
        let b = GameState(board: .deadlocked, seed: 42).settle()
        let c = GameState(board: .deadlocked, seed: 43).settle()
        #expect(a == b)
        #expect(a.state.board != c.state.board)
    }

    @Test("일반적인 8×10 보드는 시드와 상관없이 재생성 없이 섞인다")
    func shuffleSucceedsForManySeeds() {
        for seed in 0..<200 as Range<UInt64> {
            let result = GameState(board: .deadlocked, seed: seed).settle()
            guard case .shuffled = result.events.last, result.events.count == 1 else {
                Issue.record("seed \(seed): \(result.events.count)개 이벤트")
                continue
            }
            #expect(result.state.board.findMatches().isEmpty)
            #expect(result.state.board.hasPossibleMove)
            #expect(result.state.board.kindCounts == Board.deadlocked.kindCounts)
        }
    }

    @Test("어떻게 섞어도 유효한 배치가 없으면 보드를 새로 만든다")
    func regeneratesWhenShuffleCannotHelp() {
        // 네 칸이 모두 다른 종류라 어떻게 섞어도 가능한 이동이 생기지 않는다.
        let board = Board(text: ["ABCD"])
        #expect(board.findMatches().isEmpty)
        #expect(!board.hasPossibleMove)

        let result = GameState(board: board).settle()
        #expect(result.state.board.findMatches().isEmpty)
        #expect(result.state.board.hasPossibleMove)
        #expect(result.state.board.isFull)
        guard case .regenerated(let spawns) = result.events.last else {
            Issue.record("재생성 이벤트가 없다: \(result.events)")
            return
        }
        #expect(spawns.count == 4)
    }
}
