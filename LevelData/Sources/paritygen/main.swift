import Foundation
import GameCore
import LevelData

// 안드로이드 판(Kotlin)이 규칙을 똑같이 따르는지 보기 위한 기준 기록을 만든다.
//
// 레벨마다 시작 상태에서 정해진 순서로 수를 두고, 수마다 이벤트와 상태를 한 줄씩 적는다.
// Kotlin 쪽 시험은 같은 레벨에 같은 수를 두고 이 기록과 글자 하나까지 같은지 본다.
// 글의 형식은 android/core/src/test/kotlin/.../ParityFormat.kt와 짝이다. 한쪽을 바꾸면 다른 쪽도 바꾼다.
//
// 사용법: swift run -c release paritygen <출력 폴더> [수의 개수=24]

// MARK: - 글로 적기

func text(_ p: Position) -> String { "\(p.column):\(p.row)" }
func text(_ ps: [Position]) -> String { "[" + ps.map(text).joined(separator: ",") + "]" }
func text(_ o: Orientation) -> String { o == .horizontal ? "h" : "v" }
func text(_ k: BlockKind?) -> String { k.map { String($0.rawValue) } ?? "-" }

func text(_ block: Block?) -> String {
    guard let block else { return "." }
    switch block {
    case .normal(let k): return "N\(k.rawValue)"
    case .beam(let o): return "B\(text(o))"
    case .bomb: return "X"
    case .core: return "C"
    case .material: return "M"
    case .concrete(let hp): return "K\(hp)"
    case .caged(let k): return "G\(k.rawValue)"
    case .sludge: return "S"
    case .wall: return "W"
    case .cocoon(let k): return "O\(k.rawValue)"
    case .rubble: return "R"
    case .nest(let hp): return "T\(hp)"
    case .timed(let k, let turns): return "Z\(k.rawValue).\(turns)"
    case .egg: return "E"
    case .chained(let k): return "H\(k.rawValue)"
    case .boulder: return "U"
    case .vent(let hp): return "V\(hp)"
    case .frozen(let k): return "I\(k.rawValue)"
    }
}

func text(_ effect: SpecialEffect) -> String {
    switch effect {
    case .beam(let o): return "beam" + text(o)
    case .bomb: return "bomb"
    case .core(let k): return "core" + text(k)
    case .crossBeam: return "cross"
    case .wideCrossBeam: return "wide"
    case .bigBomb: return "big"
    case .coreBeam(let k): return "coreBeam\(k.rawValue)"
    case .coreBomb(let k): return "coreBomb\(k.rawValue)"
    case .clearBoard: return "clear"
    }
}

func text(_ shape: MatchShape) -> String {
    switch shape {
    case .line(let o, let length): return "line\(text(o))\(length)"
    case .lShape: return "L"
    case .tShape: return "T"
    }
}

func text(_ moves: [BlockMove]) -> String {
    "[" + moves.map { text($0.from) + ">" + text($0.to) }.joined(separator: ",") + "]"
}

func text(_ rejection: SwapRejection) -> String {
    switch rejection {
    case .outOfBounds: "outOfBounds"
    case .notAdjacent: "notAdjacent"
    case .emptyCell: "emptyCell"
    case .noMatch: "noMatch"
    case .gameOver: "gameOver"
    case .immovable: "immovable"
    }
}

func text(_ event: GameEvent) -> String {
    switch event {
    case .swapped(let s): return "swapped(\(text(s.from))-\(text(s.to)))"
    case .swapRejected(let s, let r): return "rejected(\(text(s.from))-\(text(s.to)),\(text(r)))"
    case .matchesCleared(let matches, let chain):
        let body = matches.map {
            "\(text($0.kind))/\(text($0.shape))/\($0.longestLine)/\($0.crossing.map(text) ?? "-")/\(text($0.positions))"
        }
        return "matches(\(chain);" + body.joined(separator: ";") + ")"
    case .specialsActivated(let list):
        return "specials(" + list.map { "\(text($0.origin))/\(text($0.effect))/\(text($0.cleared))" }.joined(separator: ";") + ")"
    case .specialsCreated(let list):
        return "created(" + list.map { "\(text($0.position))=\(text($0.block))" }.joined(separator: ",") + ")"
    case .fell(let moves): return "fell" + text(moves)
    case .slid(let moves): return "slid" + text(moves)
    case .refilled(let spawns): return "refilled(" + spawns.map { "\(text($0.position))=\(text($0.block))" }.joined(separator: ",") + ")"
    case .shuffled(let moves): return "shuffled" + text(moves)
    case .regenerated(let spawns): return "regenerated(" + spawns.map { "\(text($0.position))=\(text($0.block))" }.joined(separator: ",") + ")"
    case .obstaclesDamaged(let hits): return "damaged(" + hits.map { "\(text($0.position))=\(text($0.remaining))" }.joined(separator: ",") + ")"
    case .sludgeSpread(let ps): return "sludge" + text(ps)
    case .nestsSpat(let spits): return "spat(" + spits.map { "\(text($0.nest))>\(text($0.target))" }.joined(separator: ",") + ")"
    case .timersTicked(let ticks): return "ticked(" + ticks.map { "\(text($0.position))=\($0.turns)" }.joined(separator: ",") + ")"
    case .timersBurst(let bursts): return "burst(" + bursts.map { "\(text($0.position))>\(text($0.sludge))" }.joined(separator: ",") + ")"
    case .fogLifted(let ps): return "fog" + text(ps)
    case .stickyCleared(let ps): return "sticky" + text(ps)
    case .shieldsBroken(let ps): return "shields" + text(ps)
    case .ventsPuffed(let ps): return "puffed" + text(ps)
    case .hammered(let p): return "hammered(\(text(p)))"
    case .materialsCollected(let ps): return "collected" + text(ps)
    case .scrolled(let from, let to): return "scrolled(\(from)>\(to))"
    case .won: return "won"
    case .lost: return "lost"
    }
}

func text(_ status: GameStatus) -> String {
    switch status {
    case .playing: "playing"
    case .won: "won"
    case .lost: "lost"
    }
}

func text(_ state: GameState) -> String {
    var generator = state.generator
    let board = (0..<state.board.rows).map { row in
        (0..<state.board.columns).map { text(state.board[$0, row]) }.joined(separator: " ")
    }.joined(separator: "|")
    let materials = state.materials.map { "\(text($0.origin))x\($0.width)x\($0.height)" }.joined(separator: ",")
    let pending = state.pendingMaterials.map { "\($0.column):\($0.depth)" }.joined(separator: ",")
    return [
        "status=\(text(state.status))",
        "score=\(state.score)",
        "moves=\(state.movesRemaining.map(String.init) ?? "-")",
        "top=\(state.activeTop)",
        "nest=\(state.turnsUntilNestSpit)",
        "vent=\(state.turnsUntilVentPuff)",
        "total=\(state.materialsTotal)",
        "next=\(generator.next())",
        "materials=[\(materials)]",
        "pending=[\(pending)]",
        "fog=\(text(state.fog.sorted()))",
        "sticky=\(text(state.sticky.sorted()))",
        "shields=\(text(state.shields.sorted()))",
        "board=\(board)",
    ].joined(separator: " ; ")
}

// MARK: - 수 고르기


/// 다음에 둘 수와 그 결과. `picker`는 수를 고르는 데만 쓰는 난수로, 판의 난수와 따로 둔다.
/// 기록에 수를 그대로 적으므로 Kotlin 쪽은 수 고르기를 따라 할 필요가 없다.
func play(_ state: GameState, step: Int, picker: inout SeededGenerator) -> (action: String, result: TurnResult?, next: GameState) {
    if state.canContinue {
        var next = state
        next.continuePlaying(extraMoves: Booster.extraMoveCount)
        return ("continue 5", nil, next)
    }
    let zone = state.board.positions(in: state.activeRange)
    let roll = picker.nextInt(below: 20)
    // 가끔은 아이템을 쓰거나 틀린 수를 둔다.
    if roll == 0, let position = zone.filter(state.canHammer).randomElement(using: &picker) {
        let result = state.hammering(position)!
        return ("hammer \(position.column) \(position.row)", result, result.state)
    }
    if roll == 1 {
        let swaps = zone.flatMap { p in
            [Swap(from: p, to: Position(column: p.column + 1, row: p.row)),
             Swap(from: p, to: Position(column: p.column, row: p.row + 1))]
        }.filter { state.board.contains($0.to) && state.canFreeSwap($0) && state.rejection(for: $0) != nil }
        if let swap = swaps.randomElement(using: &picker) {
            let result = state.freeSwapping(swap)!
            return ("free \(swap.from.column) \(swap.from.row) \(swap.to.column) \(swap.to.row)", result, result.state)
        }
    }
    if roll == 2, let result = state.shuffling() {
        return ("shuffle", result, result.state)
    }
    if roll == 3, let position = zone.randomElement(using: &picker) {
        // 붙어 있지 않은 칸이나 막힌 칸으로 두는 틀린 수.
        let swap = Swap(from: position, to: Position(column: position.column + 1, row: position.row + (step % 2)))
        let result = state.performTurn(swap)
        return ("swap \(swap.from.column) \(swap.from.row) \(swap.to.column) \(swap.to.row)", result, result.state)
    }
    let moves = state.possibleMoves()
    guard !moves.isEmpty else { return ("stop", nil, state) }
    // 특수 블록을 쓰는 수를 조금 더 자주 고른다. 조합 효과도 시험에 들어가게 한다.
    let special = moves.filter { state.board[$0.from]?.isSpecial == true || state.board[$0.to]?.isSpecial == true }
    let swap = (!special.isEmpty && picker.nextInt(below: 2) == 0 ? special : moves)
        .randomElement(using: &picker)!
    let result = state.performTurn(swap)
    return ("swap \(swap.from.column) \(swap.from.row) \(swap.to.column) \(swap.to.row)", result, result.state)
}

// MARK: - 실행

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("사용법: paritygen <출력 폴더> [수의 개수]")
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1])
let stepCount = arguments.count >= 3 ? Int(arguments[2]) ?? 24 : 24
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let cities = LevelCatalog.cityIDs + ["lab", "sample"]
var written = 0
var picker = SeededGenerator(seed: 0x5EED)
for city in cities {
    var lines: [String] = []
    for (index, level) in try LevelCatalog.levels(city: city).enumerated() {
        var state = try level.makeState()
        // 레벨마다 시작 부스터를 다르게 써 본다.
        let boosterSets: [[Booster]] = [[], [.beam], [.bomb, .extraMoves], [.core], [.beam, .bomb, .core], [.core, .core]]
        let boosters = boosterSets[index % boosterSets.count]
        state.apply(boosters)
        lines.append("level \(level.id) boosters=\(boosters.map(\.rawValue).joined(separator: ","))")
        lines.append("state " + text(state))
        for step in 0..<stepCount {
            let (action, result, next) = play(state, step: step, picker: &picker)
            if action == "stop" { break }
            lines.append("do " + action)
            if let result {
                lines.append("events " + result.events.map(text).joined(separator: " "))
            }
            lines.append("state " + text(next))
            state = next
            if state.status == .won { break }
        }
    }
    let data = Data((lines.joined(separator: "\n") + "\n").utf8)
    try data.write(to: output.appendingPathComponent("\(city).txt"))
    written += lines.count
}
print("기록 \(written)줄을 \(output.path)에 적었다")
