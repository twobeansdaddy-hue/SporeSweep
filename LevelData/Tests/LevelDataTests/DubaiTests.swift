import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("여덟 번째 도시 두바이")
struct DubaiTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "dubai")
        #expect(levels.map(\.id) == (1...16).map { String(format: "dubai-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("두바이의 새 장애물은 포자 알이다. 첫 레벨에서 설명과 함께 나온다")
    func egg() throws {
        let levels = try LevelCatalog.levels(city: "dubai")
        #expect(levels[0].obstacles.contains { $0.type == "egg" })
        #expect(levels[0].tutorial?.contains("포자 알") == true)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "egg" } }.count >= 5)
        let state = try levels[0].makeState()
        #expect(state.board.positions.contains { state.board[$0] == .egg })
        // 알은 한 줄을 다 막지 않는다.
        for level in levels {
            let rows = Dictionary(grouping: level.obstacles.filter { $0.type == "egg" }, by: \.row)
            #expect(rows.values.allSatisfy { $0.count <= 3 }, "\(level.id)")
        }
    }

    @Test("돛 모양 호텔은 아홉 부위이고, 별 48개 가운데 40개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("dubai")
        #expect(city.name == "두바이")
        #expect(city.landmark.parts.count == 9)
        #expect(city.landmark.totalCost == 40)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["lower"] == ["island"])
        #expect(requires["mast"] == ["upper"])
        #expect(RegionCatalog.region(ofCity: "dubai")?.id == "mideastafrica")
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "dubai") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
