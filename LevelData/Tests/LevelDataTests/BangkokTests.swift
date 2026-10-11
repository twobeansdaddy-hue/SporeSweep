import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("다섯 번째 도시 방콕")
struct BangkokTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "bangkok")
        #expect(levels.map(\.id) == (1...16).map { String(format: "bangkok-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("방콕의 새 장애물은 시한 포자다. 첫 레벨에서 설명과 함께 나오고, 앞 도시의 장애물도 섞여 나온다")
    func timer() throws {
        let levels = try LevelCatalog.levels(city: "bangkok")
        #expect(levels[0].obstacles.contains { $0.type == "timer" })
        #expect(levels[0].tutorial?.contains("시한 포자") == true)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "timer" } }.count >= 6)
        #expect(levels.contains { $0.obstacles.contains { $0.type == "nest" } })
        let state = try levels[0].makeState()
        #expect(state.board.positions.contains {
            if case .timed = state.board[$0] { true } else { false }
        })
    }

    @Test("시한 포자의 턴은 정해진 범위 안이어야 한다")
    func timerTurns() throws {
        var level = try LevelCatalog.levels(city: "bangkok")[0]
        let index = try #require(level.obstacles.firstIndex { $0.type == "timer" })
        level.obstacles[index].turns = 2
        #expect(throws: LevelError.self) { try level.validate() }
        level.obstacles[index].turns = nil
        try level.validate()
    }

    @Test("왓 아룬은 아홉 부위이고, 별 48개 가운데 40개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("bangkok")
        #expect(city.name == "방콕")
        #expect(city.landmark.name == "왓 아룬")
        #expect(city.landmark.parts.count == 9)
        #expect(city.landmark.totalCost == 40)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["prangLeft"] == ["base"])
        #expect(requires["spire"] == ["tiers"])
        #expect(requires["base"] == [])
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "bangkok") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
