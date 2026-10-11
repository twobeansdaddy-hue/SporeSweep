import Foundation
import LevelData
import LevelTools

// 레벨 생성기의 명령줄 도구.
//
// 사용법: swift run -c release levelgen <도시> <개수> [--from 0.2] [--to 0.6] [--seed 1]
//           [--features concrete,cage,wall] [--first 1] [--playouts 120] [--out <폴더>]
// `--out`을 주지 않으면 파일을 쓰지 않고 결과만 보여준다.
let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2, let count = Int(arguments[1]), count > 0 else {
    print("usage: levelgen <city> <count> [--from d] [--to d] [--seed n] [--features a,b] [--first n] [--playouts n] [--out dir]")
    exit(1)
}
func value(_ name: String) -> String? {
    arguments.firstIndex(of: name).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
}
var options = LevelGenerator.Options(city: arguments[0], count: count)
let from = value("--from").flatMap(Double.init) ?? 0.2
let to = value("--to").flatMap(Double.init) ?? 0.6
options.difficulty = min(from, to)...max(from, to)
options.seed = value("--seed").flatMap { UInt64($0) } ?? 1
options.firstNumber = value("--first").flatMap(Int.init) ?? 1
options.playouts = value("--playouts").flatMap(Int.init) ?? 120
if let list = value("--features") {
    let names = list.split(separator: ",").map(String.init)
    let unknown = names.filter { LevelGenerator.Feature(rawValue: $0) == nil }
    guard unknown.isEmpty else {
        print("모르는 요소: \(unknown.joined(separator: ", ")). 쓸 수 있는 것: \(LevelGenerator.Feature.allCases.map(\.rawValue).joined(separator: ", "))")
        exit(1)
    }
    options.features = Set(names.compactMap(LevelGenerator.Feature.init))
}

// `--spotlight cocoon`은 이 도시에서 처음 나오는 장애물을, `--tutorial "cocoon=설명"`은 그 장애물이 처음 나오는 레벨의 설명을 정한다.
options.spotlight = value("--spotlight")
if let tutorial = value("--tutorial"), let split = tutorial.firstIndex(of: "=") {
    options.tutorials[String(tutorial[..<split])] = String(tutorial[tutorial.index(after: split)...])
}

let results = LevelGenerator.generate(options)
for result in results {
    let level = result.level
    let rate = String(format: "%.0f%%", result.calibration.clearRate * 100)
    print("\(level.id)  \(level.rows)행  블록 \(level.blockTypes)종  이동 \(level.moves)  클리어율 \(rate)  "
        + "별 \(level.starScores[0])/\(level.starScores[1])  시도 \(result.attempts)  \(result.patterns.joined(separator: ", "))")
}
if let out = value("--out") {
    try LevelGenerator.write(results, to: URL(fileURLWithPath: out, isDirectory: true))
    print("\(results.count)개를 \(out)에 썼다")
}
