import Foundation
import GameCore
import LevelData
import LevelTools

// 모든 도시의 레벨을 봇으로 돌려 보고 이상한 레벨을 찾는다(9장).
//
// 사용법: swift run -c release levelaudit [--playouts 200] [--fix | --recalibrate] [--csv 파일] [--levels 폴더]
//   레벨을 만들 때와 다른 시드로 돌린다. 만들 때 잰 값이 우연이었는지 가려내기 위해서다.
//   판마다 시작 보드가 다르므로(9장) 판마다 다른 시작 보드로 돈다. 잴 때와 다른 보드다.
//   --fix를 주면 걸린 레벨의 이동 횟수와 별 점수를 다시 재어 파일을 고친다.
//   --recalibrate를 주면 걸렸는지와 상관없이 모든 레벨을 다시 잰다. 규칙을 바꾼 뒤에 쓴다.

let arguments = CommandLine.arguments
func value(_ name: String) -> String? {
    arguments.firstIndex(of: name).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
}
let playouts = value("--playouts").flatMap(Int.init) ?? 200
let recalibrates = arguments.contains("--recalibrate")
let fixes = arguments.contains("--fix") || recalibrates
let folder = value("--levels") ?? "Sources/LevelData/Levels"
/// 만들 때 쓴 시드(0부터)와 겹치지 않는 시드.
let seedBase: UInt64 = 50_000

struct Row {
    var id: String
    var rows: Int
    var moves: Int
    var clearRate: Double
    var weakRate: Double
    var stars: [Double]
    var medianTurns: Int
    var stuck: Int
    var firstMoves: Int
    var flags: [String]
}

final class Box<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    init(_ value: Value) { self.value = value }
    func with<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

func audit(_ level: Level) -> Row? {
    guard let start = try? level.makeState() else { return nil }
    /// 판마다 다른 시작 보드. 잴 때 쓰는 보드(0부터)와 겹치지 않게 뒤쪽 번호를 쓴다.
    func board(_ index: Int) -> GameState {
        (try? level.makeState(seed: level.boardSeed(Int(seedBase) + index))) ?? start
    }
    let outcomes = Box([(won: Bool, stars: Int, turns: Int, stuck: Bool)]())
    let weakWins = Box(0)
    DispatchQueue.concurrentPerform(iterations: playouts) { index in
        let end = Solver.casual(board(index), policySeed: seedBase + UInt64(index), greed: 0.5)
        let won = end.state.status == .won
        // 이동 횟수가 남았는데 졌으면 둘 곳이 없어서 진 것이다.
        let stuck = !won && (end.state.movesRemaining ?? 0) > 0
        outcomes.with { $0.append((won, won ? level.stars(forScore: end.state.score) : 0, end.turns, stuck)) }
        // 거의 아무렇게나 두는 봇. 이 봇도 잘 깨면 생각할 것이 없는 판이다.
        if Solver.casual(board(index), policySeed: seedBase + UInt64(index), greed: 0.15).state.status == .won {
            weakWins.with { $0 += 1 }
        }
    }
    let all = outcomes.with { $0 }
    let wins = all.filter(\.won)
    let total = Double(playouts)
    let clearRate = Double(wins.count) / total
    let stars = (1...3).map { count in wins.isEmpty ? 0 : Double(wins.count { $0.stars == count }) / Double(wins.count) }
    let turns = wins.map(\.turns).sorted()
    let firstMoves = start.possibleMoves().count
    var flags: [String] = []
    if clearRate < 0.55 { flags.append("어려움") }
    if clearRate > 0.92 { flags.append("쉬움") }
    if !wins.isEmpty, stars[2] < 0.05 { flags.append("별3 드묾") }
    if !wins.isEmpty, stars[2] > 0.5 { flags.append("별3 흔함") }
    if !wins.isEmpty, stars[0] > 0.8 { flags.append("별1뿐") }
    if all.count(where: \.stuck) > playouts / 20 { flags.append("막힘") }
    if firstMoves < 3 { flags.append("첫 수 적음") }
    // 설명이 붙은 레벨은 그 장애물이 첫 화면에 보여야 한다.
    if level.tutorial != nil, !level.obstacles.isEmpty,
       !level.obstacles.contains(where: { $0.row < GameConstants.activeRows }) {
        flags.append("설명한 장애물이 첫 화면에 없음")
    }
    return Row(
        id: level.id, rows: level.rows, moves: level.moves, clearRate: clearRate,
        weakRate: Double(weakWins.with { $0 }) / total, stars: stars,
        medianTurns: turns.isEmpty ? 0 : turns[turns.count / 2],
        stuck: all.count(where: \.stuck), firstMoves: firstMoves, flags: flags
    )
}

var rows: [Row] = []
var fixed: [String] = []
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
for city in LevelCatalog.cityIDs {
    let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
        .filter { $0.hasPrefix(city + "-") && $0.hasSuffix(".json") }.sorted()
    for file in files {
        let url = URL(fileURLWithPath: folder).appendingPathComponent(file)
        guard var level = try? LevelLoader.load(contentsOf: url), var row = audit(level) else {
            print("읽지 못함: \(file)")
            continue
        }
        let needsFix = recalibrates || row.flags.contains { ["어려움", "쉬움", "별3 드묾", "별3 흔함", "별1뿐"].contains($0) }
        if fixes, needsFix, let measured = Calibration.measure(level, playouts: 400) {
            // 만들 때의 판과 점검할 때의 판을 합친 400판으로 다시 잰다.
            level.moves = measured.moves
            level.starScores = measured.starScores
            if let data = try? encoder.encode(level) {
                try? data.write(to: url)
                fixed.append("\(level.id): 이동 \(row.moves)→\(level.moves)")
                if let again = audit(level) {
                    row = again
                    row.flags.append("고침")
                }
            }
        }
        rows.append(row)
    }
    let mine = rows.filter { $0.id.hasPrefix(city + "-") }
    let average = mine.map(\.clearRate).reduce(0, +) / Double(max(mine.count, 1))
    print("\(city)  \(mine.count)개  평균 클리어율 \(Int(average * 100))%  걸린 것 \(mine.count { !$0.flags.filter { $0 != "고침" }.isEmpty })개")
}

func percent(_ value: Double) -> String { String(Int((value * 100).rounded())) }
if let path = value("--csv") {
    var text = "레벨,보드 행,이동 횟수,클리어율(%),대충 두는 봇의 클리어율(%),별1(%),별2(%),별3(%),클리어한 판의 이동 중앙값,막힌 판,첫 화면의 가능한 수,걸린 점\n"
    for row in rows {
        text += "\(row.id),\(row.rows),\(row.moves),\(percent(row.clearRate)),\(percent(row.weakRate)),"
        text += row.stars.map(percent).joined(separator: ",")
        text += ",\(row.medianTurns),\(row.stuck),\(row.firstMoves),\(row.flags.joined(separator: " / "))\n"
    }
    try? text.write(toFile: path, atomically: true, encoding: .utf8)
}
print("\n레벨 \(rows.count)개, 걸린 레벨 \(rows.count { !$0.flags.filter { $0 != "고침" }.isEmpty })개")
for row in rows where !row.flags.isEmpty {
    print("  \(row.id)  이동 \(row.moves)  클리어 \(percent(row.clearRate))%  별3 \(percent(row.stars[2]))%  \(row.flags.joined(separator: ", "))")
}
if !fixed.isEmpty {
    print("\n고친 레벨 \(fixed.count)개")
}
