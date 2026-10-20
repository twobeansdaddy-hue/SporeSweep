import Foundation
import GameCore
import LevelData

/// 봇으로 잰 레벨의 난이도(6장).
public struct Calibration: Hashable, Sendable {
    /// 봇이 열 판 가운데 일곱 판을 클리어하는 이동 횟수. 5 단위로 올리고 범위 안으로 자른 값이다.
    public var moves: Int
    /// 자르기 전의 값. 이 값이 상한보다 크면 레벨이 너무 길거나 어렵다는 뜻이다.
    public var wantedMoves: Int
    /// 별 2개와 별 3개를 받는 점수.
    public var starScores: [Int]
    /// `moves` 안에 클리어한 판의 비율.
    public var clearRate: Double
    /// 클리어한 판에서 쓴 이동 횟수의 중앙값.
    public var medianTurns: Int

    /// 이동 횟수의 범위. 첫 레벨이 빠듯하지 않게 15수 아래로는 내리지 않고, 한 판이 너무 길어지지 않게 60수를 넘기지 않는다.
    public static let moveRange = 15...60
    /// 재는 동안 쓰는 넉넉한 이동 횟수.
    static let cap = 300

    /// 평범하게 두는 봇으로 `playouts`판을 돌려 잰다. 한 판도 클리어하지 못하면 `nil`이다.
    ///
    /// 이동 횟수는 봇이 열 판 가운데 일곱 판을 클리어하는 값이고, 별 2개는 클리어한 판의 절반이 넘는 점수,
    /// 별 3개는 상위 20%가 넘는 점수다. 점수는 100점 단위로 내린다.
    /// 판마다 시작 보드가 다르므로(9장) 판마다 다른 시작 보드로 잰다. `boardSeedOffset`으로 쓸 보드를 바꾼다.
    public static func measure(
        _ level: Level, playouts: Int = 200, greed: Double = 0.5, boardSeedOffset: Int = 0
    ) -> Calibration? {
        guard (try? level.makeState()) != nil else { return nil }
        let results = Mutex([(turns: Int, blocks: Int)]())
        DispatchQueue.concurrentPerform(iterations: playouts) { seed in
            guard var start = try? level.makeState(seed: level.boardSeed(boardSeedOffset + seed)) else { return }
            start.movesRemaining = cap
            let end = Solver.casual(start, policySeed: UInt64(seed), greed: greed)
            guard end.state.status == .won else { return }
            let bonus = (end.state.movesRemaining ?? 0) * GameConstants.scorePerRemainingMove
            results.withLock { $0.append((end.turns, end.state.score - bonus)) }
        }
        // 판이 끝난 순서와 상관없이 같은 결과가 나오도록 정렬해서 쓴다.
        let cleared = results.withLock { $0 }.sorted { ($0.turns, $0.blocks) < ($1.turns, $1.blocks) }
        let turns = cleared.map(\.turns)
        guard !turns.isEmpty else { return nil }
        func percentile(_ sorted: [Int], _ p: Double) -> Int {
            sorted[min(Int(Double(sorted.count) * p), sorted.count - 1)]
        }
        // 클리어하지 못한 판은 이동 횟수가 끝없이 많이 든 것으로 친다.
        let all = turns + Array(repeating: Int.max, count: playouts - turns.count)
        let seventh = percentile(all, 0.7)
        let wanted = seventh == Int.max ? cap : (seventh + 4) / 5 * 5
        let moves = min(max(wanted, moveRange.lowerBound), moveRange.upperBound)
        let scores = cleared.filter { $0.turns <= moves }
            .map { $0.blocks + (moves - $0.turns) * GameConstants.scorePerRemainingMove }
            .sorted()
        guard !scores.isEmpty else { return nil }
        let two = max(percentile(scores, 0.5) / 100 * 100, 100)
        let three = max(percentile(scores, 0.8) / 100 * 100, two + 100)
        return Calibration(
            moves: moves,
            wantedMoves: wanted,
            starScores: [two, three],
            clearRate: Double(scores.count) / Double(playouts),
            medianTurns: percentile(turns, 0.5)
        )
    }
}

/// 여러 스레드에서 함께 쓰는 값.
final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
