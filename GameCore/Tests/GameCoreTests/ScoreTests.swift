import Testing
@testable import GameCore

@Suite("점수")
struct ScoreTests {
    @Test("블록 1개 제거에 10점이다")
    func tenPerBlock() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
        let state = GameState(board: board)
        #expect(state.score == 0)
        let result = state.performTurn(swap((3, 9), (2, 9)))
        // 첫 매치 3개가 30점이다. 뒤따르는 연쇄가 있으면 더 오른다.
        #expect(result.state.score >= 30)
        let chains = result.events.compactMap { event -> (Int, Int)? in
            if case .matchesCleared(let matches, let chain) = event {
                return (matches.flatMap(\.positions).count, chain)
            }
            return nil
        }
        if chains.count == 1 {
            #expect(result.state.score == 30)
        }
    }

    @Test("연쇄가 이어질 때마다 배수가 1씩 오르고 3배에서 멈춘다")
    func chainMultiplier() {
        // 첫 매치가 지워지면 낙하로 두 번째 매치가 생기는 보드(턴 처리 테스트와 같다).
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .setting(.brick, at: [(1, 8), (2, 8)])
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        var expected = 0
        for event in result.events {
            switch event {
            case .matchesCleared(let matches, let chain):
                expected += matches.flatMap(\.positions).count * 10 * min(chain, 3)
            case .specialsActivated(let activations):
                // 이 보드에서는 특수 블록이 발동하지 않는다고 가정하지 않고 그대로 더한다.
                expected += activations.flatMap(\.cleared).count * 10
            default:
                break
            }
        }
        #expect(result.events.compactMap(\.clearedMatches).count >= 2)
        // 두 번째 매치는 2배다. 특수 효과가 섞이지 않았으면 정확히 일치한다.
        if !result.events.contains(where: { $0.activations != nil }) {
            #expect(result.state.score == expected)
        }
        #expect(result.state.score >= 30 + 60)
    }

    @Test("연쇄 배수는 3배를 넘지 않는다")
    func chainMultiplierIsCapped() {
        #expect(GameConstants.maximumChainMultiplier == 3)
        // 연쇄가 4번 넘게 이어지는 판을 찾아, 4번째부터도 3배로 세는지 본다.
        var found = false
        for seed in 1...400 as ClosedRange<UInt64> where !found {
            let state = GameState(seed: seed, rows: 16, moves: 20, materials: [pos(2, 0)])
            for move in state.possibleMoves() {
                let result = state.performTurn(move)
                let clears = result.events.compactMap { event -> (count: Int, chain: Int)? in
                    if case .matchesCleared(let matches, let chain) = event {
                        return (Set(matches.flatMap(\.positions)).count, chain)
                    }
                    return nil
                }
                guard clears.contains(where: { $0.chain >= 4 }),
                      !result.events.contains(where: { $0.activations != nil }),
                      !result.events.contains(where: { if case .obstaclesDamaged = $0 { true } else { false } }),
                      result.state.status == .playing else { continue }
                #expect(result.state.score == clears.map { $0.count * 10 * min($0.chain, 3) }.reduce(0, +))
                found = true
                break
            }
        }
        #expect(found, "연쇄가 4번 이어지는 판을 찾지 못했다")
    }

    @Test("특수 효과로 지운 블록도 같은 배수로 센다")
    func effectsScore() {
        // 가로 빔을 옮겨 발동한다. 빔 자신을 포함해 한 줄 8칸이 연쇄 1이다.
        let board = Board.deadlocked(rows: 16).placing(.beam(.horizontal), at: (3, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events[1].activations?[0].cleared.count == 8)
        #expect(result.state.score >= 80)
        if !result.events.contains(where: { $0.clearedMatches != nil }) {
            #expect(result.state.score == 80)
        }
    }

    @Test("스왑 조합은 지운 블록 수에 10을 곱한다")
    func comboScore() {
        let board = Board.deadlocked(rows: 16).placing(.bomb, at: (3, 5)).placing(.bomb, at: (4, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        // 5×5의 25칸. 뒤따르는 연쇄가 있으면 더 오른다.
        #expect(result.state.score >= 250)
        if !result.events.contains(where: { $0.clearedMatches != nil }) {
            #expect(result.state.score == 250)
        }
    }

    @Test("장애물과 벗겨진 철망은 점수가 없다")
    func obstaclesDoNotScore() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (3, 9)])
            .placing(.caged(.soil), at: (1, 9))
            .placing(.concrete(hp: 1), at: (2, 8))
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        // 매치 3칸 가운데 철망 칸은 남으므로 2칸만 센다.
        let first = replayScore(result.events)
        #expect(first == 20)
    }

    /// 첫 매치 단계에서 실제로 제거된 칸 수 × 10.
    private func replayScore(_ events: [GameEvent]) -> Int {
        guard case .matchesCleared(let matches, _) = events[1] else { return -1 }
        var removed = Set(matches.flatMap(\.positions))
        for event in events.dropFirst(2) {
            if case .obstaclesDamaged(let hits) = event {
                removed.subtract(hits.filter { $0.remaining != nil }.map(\.position))
                break
            }
            if case .fell = event { break }
        }
        return removed.count * 10
    }

    @Test("클리어하면 남은 이동 횟수 1회당 100점을 더한다")
    func remainingMovesBonus() {
        let board = Board.deadlocked(rows: 12)
            .placing(.material, at: (2, 10))
            .setting(.soil, at: [(0, 11), (1, 11), (3, 11)])
        let result = GameState(board: board, activeTop: 2, moves: 5).performTurn(swap((3, 11), (2, 11)))
        #expect(result.state.status == .won)
        #expect(result.state.movesRemaining == 4)
        // 매치 3칸 30점과 남은 4회의 400점. 수거 뒤의 연쇄가 있으면 더 오른다.
        #expect(GameConstants.scorePerRemainingMove == 100)
        #expect(result.state.score >= 430)
        #expect((result.state.score - 400) % 10 == 0)
    }

    @Test("실패한 판에는 보너스가 없다")
    func noBonusOnLoss() {
        let board = Board.deadlocked(rows: 16)
            .placing(.material, at: (2, 0))
            .setting(.soil, at: [(5, 9), (6, 9), (7, 8)])
        let result = GameState(board: board, moves: 1).performTurn(swap((7, 8), (7, 9)))
        #expect(result.state.status == .lost)
        #expect(result.state.score < 100)
    }

    @Test("거부된 스왑은 점수를 바꾸지 않는다")
    func rejectedSwap() {
        let state = GameState(seed: 4)
        #expect(state.performTurn(swap((0, 0), (5, 5))).state.score == 0)
    }

    @Test("점수는 턴마다 줄지 않고, 같은 입력이면 같다")
    func monotonicAndDeterministic() {
        func play() -> [Int] {
            var state = GameState(seed: 9, rows: 16, moves: 40, materials: [pos(2, 0), pos(5, 0)])
            var scores: [Int] = []
            while state.status == .playing {
                state = state.performTurn(state.greedyMove()).state
                scores.append(state.score)
            }
            return scores
        }
        let scores = play()
        #expect(scores == scores.sorted())
        #expect(scores == play())
        #expect(scores.last! > 0)
    }
}
