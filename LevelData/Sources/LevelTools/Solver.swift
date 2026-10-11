import GameCore

/// 레벨이 클리어 가능한지 확인하고 난이도를 재는 단순한 봇.
///
/// 매 턴 물질을 가장 많이 내리는 이동을 고른다. 점수가 비슷한 이동 사이에서는 `policySeed`로 정한
/// 난수로 고르므로, 시드를 바꿔 여러 번 돌리면 서로 다른 경로를 시험할 수 있다.
public enum Solver {
    public static func progress(_ state: GameState) -> Int {
        let collected = state.materialsTotal - state.materialsRemaining
        // 큰 물질 아래에 파 놓은 빈칸도 조금씩 진전으로 친다.
        let caves = state.board.positions(in: state.activeRange).count { state.board[$0] == nil }
        return collected * 10_000
            + state.materialPositions.map(\.row).reduce(0, +) * 10
            - state.pendingMaterials.map { $0.depth + 1 }.reduce(0, +) * 10
            + caves
    }

    /// 판이 끝날 때까지 플레이한다. 클리어하면 쓴 이동 횟수를, 실패하면 `nil`을 반환한다.
    public static func playout(_ start: GameState, policySeed: UInt64) -> Int? {
        let (state, turns) = finish(start, policySeed: policySeed)
        return state.status == .won ? turns : nil
    }

    /// 판이 끝날 때까지 플레이하고 마지막 상태와 쓴 이동 횟수를 반환한다.
    public static func finish(_ start: GameState, policySeed: UInt64) -> (state: GameState, turns: Int) {
        var state = start
        var policy = SeededGenerator(seed: policySeed)
        var turns = 0
        while state.status == .playing {
            var best: (swap: Swap, value: Int)?
            for move in state.possibleMoves() {
                let value = progress(state.performTurn(move).state) + policy.nextInt(below: 6)
                if best == nil || value > best!.value {
                    best = (move, value)
                }
            }
            guard let move = best?.swap else { break }
            state = state.performTurn(move).state
            turns += 1
        }
        return (state, turns)
    }

    /// 평범한 사람처럼 두는 봇. 별 기준과 이동 횟수를 잴 때 쓴다(6장).
    ///
    /// `greed`의 확률로는 물질을 가장 많이 내리는 이동을, 나머지는 보이는 이동 가운데 아무거나 고른다.
    public static func casual(_ start: GameState, policySeed: UInt64, greed: Double) -> (state: GameState, turns: Int) {
        var state = start
        var policy = SeededGenerator(seed: policySeed &* 7919 &+ 17)
        var turns = 0
        while state.status == .playing {
            let moves = state.possibleMoves()
            guard !moves.isEmpty else { break }
            var move = moves[policy.nextInt(below: moves.count)]
            if Double(policy.nextInt(below: 1000)) < greed * 1000 {
                var best = Int.min
                for candidate in moves {
                    let value = progress(state.performTurn(candidate).state) + policy.nextInt(below: 6)
                    if value > best {
                        best = value
                        move = candidate
                    }
                }
            }
            state = state.performTurn(move).state
            turns += 1
        }
        return (state, turns)
    }
}
