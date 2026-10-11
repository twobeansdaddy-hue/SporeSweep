import Foundation
import GameCore
import Testing
@testable import LevelData
import LevelTools

/// 이동 횟수와 별 기준을 재는 도구(6장). 평소에는 돌지 않는다.
///
/// 사용법: CALIBRATE=1 swift test --filter Calibration
@Suite("기준 재기")
struct CalibrationTests {
    static let runs = 200
    /// 재는 동안 쓰는 넉넉한 이동 횟수.
    static let cap = 400
    static let minimumMoves = 15
    static let maximumMoves = 60

    static func percentile(_ sorted: [Int], _ p: Double) -> Int {
        sorted[min(Int(Double(sorted.count) * p), sorted.count - 1)]
    }

    /// 한 레벨을 재서 결과를 한 줄로 만든다.
    static func measure(_ level: Level, greed: Double) throws -> String {
        var state = try level.makeState()
        state.movesRemaining = cap
        // (쓴 이동 횟수, 블록으로 얻은 점수). 클리어한 판만 모은다.
        var results: [(turns: Int, blocks: Int)] = []
        for seed in 0..<UInt64(runs) {
            let end = Solver.casual(state, policySeed: seed, greed: greed)
            guard end.state.status == .won else { continue }
            let bonus = (end.state.movesRemaining ?? 0) * GameConstants.scorePerRemainingMove
            results.append((end.turns, end.state.score - bonus))
        }
        let turns = results.map(\.turns).sorted()
        guard !turns.isEmpty else { return "\(level.id) 클리어 없음" }
        // 열 판 가운데 일곱 판을 클리어하는 이동 횟수. 5 단위로 올린다.
        // 첫 레벨이 빠듯하지 않게 15수 아래로는 내리지 않고, 한 판이 너무 길어지지 않게 60수를 넘기지 않는다.
        let moves = min(max((percentile(turns, 0.7) + 4) / 5 * 5, minimumMoves), maximumMoves)
        let scores = results.filter { $0.turns <= moves }
            .map { $0.blocks + (moves - $0.turns) * GameConstants.scorePerRemainingMove }.sorted()
        let two = percentile(scores, 0.5) / 100 * 100
        let three = max(percentile(scores, 0.8) / 100 * 100, two + 100)
        let rate = Double(scores.count) / Double(runs)
        return "\(level.id) 지금 \(level.moves)수 → \(moves)수 클리어율 \(String(format: "%.2f", rate)) 이동 중앙값 \(percentile(turns, 0.5))"
            + " 별2 \(two) 별3 \(three) 최저 \(scores.first ?? 0) 최고 \(scores.last ?? 0)"
    }

    @Test("평범한 봇으로 이동 횟수와 별 기준을 잰다", .enabled(if: ProcessInfo.processInfo.environment["CALIBRATE"] != nil))
    func calibrate() async throws {
        let greeds = (ProcessInfo.processInfo.environment["GREED"] ?? "0.5").split(separator: ",").compactMap { Double($0) }
        let levels = try LevelCatalog.levels(city: ProcessInfo.processInfo.environment["CITY"] ?? "seoul")
        for greed in greeds {
            // 레벨마다 따로 돌려 시간을 줄인다.
            let lines = try await withThrowingTaskGroup(of: String.self) { group in
                for level in levels {
                    group.addTask { try Self.measure(level, greed: greed) }
                }
                var lines: [String] = []
                for try await line in group {
                    lines.append(line)
                }
                return lines.sorted()
            }
            let text = "=== greed \(greed)\n" + lines.joined(separator: "\n") + "\n"
            print(text)
            if let path = ProcessInfo.processInfo.environment["CALIBRATE_OUT"] {
                let old = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
                try (old + text).write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
    }
}
