import Foundation
import GameCore
import LevelData
import LevelTools

let id = CommandLine.arguments[1]
let url = URL(fileURLWithPath: "Sources/LevelData/Levels/\(id).json")
let level = try LevelLoader.load(contentsOf: url)
let start = try level.makeState()
for index in 0..<200 {
    let end = Solver.casual(start, policySeed: 50_000 + UInt64(index), greed: 0.5)
    if end.state.status != .won, (end.state.movesRemaining ?? 0) > 0 {
        let state = end.state
        var counts: [String: Int] = [:]
        for position in state.board.positions(in: state.activeRange) {
            let name: String
            switch state.board[position] {
            case nil: name = "empty"
            case .normal: name = "normal"
            case .sludge: name = "sludge"
            case .material: name = "material"
            case .wall: name = "wall"
            case .some(let other): name = String(describing: other).prefix(6).description
            }
            counts[name, default: 0] += 1
        }
        print(index, state.status, "moves", state.movesRemaining ?? -1, "turns", end.turns, "top", state.activeTop, counts.sorted { $0.key < $1.key })
    }
}
