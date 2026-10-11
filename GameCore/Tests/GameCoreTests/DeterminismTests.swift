import Foundation
import Testing
@testable import GameCore

@Suite("난수 생성기")
struct SeededGeneratorTests {
    @Test("같은 시드는 같은 수열을 낸다")
    func sameSeedSameSequence() {
        var a = SeededGenerator(seed: 1004)
        var b = SeededGenerator(seed: 1004)
        for _ in 0..<100 {
            #expect(a.next() == b.next())
        }
    }

    @Test("SplitMix64 기준값과 일치한다")
    func knownValues() {
        var generator = SeededGenerator(seed: 0)
        #expect(generator.next() == 0xE220_A839_7B1D_CDAF)
        #expect(generator.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(generator.next() == 0x06C4_5D18_8009_454F)
    }

    @Test("범위 추출은 범위를 벗어나지 않고 모든 값이 나온다")
    func nextIntStaysInRange() {
        var generator = SeededGenerator(seed: 9)
        var seen: Set<Int> = []
        for _ in 0..<1000 {
            let value = generator.nextInt(below: 5)
            #expect((0..<5).contains(value))
            seen.insert(value)
        }
        #expect(seen == Set(0..<5))
    }
}

@Suite("보드 생성")
struct BoardGenerationTests {
    @Test("기본 보드는 8×10, 5종류다")
    func defaults() {
        let state = GameState(seed: 1)
        #expect(state.board.columns == 8)
        #expect(state.board.rows == 10)
        #expect(state.blockTypes == 5)
        #expect(state.board.isFull)
        #expect(Set(state.board.kindCounts.keys).isSubset(of: Set(BlockKind.allCases.prefix(5))))
    }

    @Test("시작 보드에는 매치가 없고 가능한 이동이 있다")
    func startsStable() {
        for seed in 0..<300 as Range<UInt64> {
            let board = GameState(seed: seed).board
            #expect(board.findMatches().isEmpty, "seed \(seed)")
            #expect(board.hasPossibleMove, "seed \(seed)")
        }
    }

    @Test("블록 종류 수를 지킨다", arguments: [4, 5, 6])
    func respectsBlockTypes(blockTypes: Int) {
        let board = GameState(seed: 77, blockTypes: blockTypes).board
        #expect(Set(board.kindCounts.keys) == Set(BlockKind.allCases.prefix(blockTypes)))
    }

    @Test("같은 시드는 같은 보드를, 다른 시드는 다른 보드를 만든다")
    func seedDeterminesBoard() {
        #expect(GameState(seed: 1004) == GameState(seed: 1004))
        #expect(GameState(seed: 1004).board != GameState(seed: 1005).board)
    }
}

@Suite("결정론")
struct DeterminismTests {
    /// 매 턴 가능한 이동 중 하나를 골라 진행하고 모든 결과를 모은다.
    func play(seed: UInt64, turns: Int) -> [TurnResult] {
        var state = GameState(seed: seed)
        var results: [TurnResult] = []
        for turn in 0..<turns {
            let moves = state.board.possibleMoves()
            let result = state.performTurn(moves[(turn * 13) % moves.count])
            results.append(result)
            state = result.state
        }
        return results
    }

    @Test("같은 시드와 같은 입력은 같은 상태와 이벤트를 낸다")
    func sameSeedSameInputsSameResults() {
        #expect(play(seed: 2026, turns: 100) == play(seed: 2026, turns: 100))
    }

    @Test("시드가 다르면 결과가 달라진다")
    func differentSeedsDiverge() {
        #expect(play(seed: 2026, turns: 20).last?.state.board != play(seed: 2027, turns: 20).last?.state.board)
    }

    @Test("같은 상태에 같은 스왑을 다시 적용해도 결과가 같다")
    func turnIsPureFunction() {
        let state = GameState(seed: 8)
        let move = state.board.possibleMoves()[0]
        #expect(state.performTurn(move) == state.performTurn(move))
    }

    @Test("상태를 저장했다가 불러와도 이어지는 결과가 같다")
    func survivesCoding() throws {
        let state = play(seed: 5, turns: 10).last!.state
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        #expect(restored == state)
        let move = state.board.possibleMoves()[0]
        #expect(restored.performTurn(move) == state.performTurn(move))
    }
}
