import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("아홉 번째 도시 케이프타운")
struct CapeTownTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "capetown")
        #expect(levels.map(\.id) == (1...16).map { String(format: "capetown-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("새 장애물이 없는 총정리 도시다. 설명이 없고, 이 권역에서 배운 끈끈이 바닥과 포자 알이 섞여 나온다")
    func finale() throws {
        let levels = try LevelCatalog.levels(city: "capetown")
        #expect(levels.allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "sticky" } }.count >= 3)
        #expect(levels.filter { $0.obstacles.contains { $0.type == "egg" } }.count >= 3)
        let known: Set<String> = ["concrete", "cage", "sludge", "wall", "cocoon", "rubble", "nest", "timer", "fog", "sticky", "egg"]
        #expect(levels.allSatisfy { $0.obstacles.allSatisfy { known.contains($0.type) } })
    }

    @Test("테이블마운틴 케이블카는 여덟 부위이고, 별 48개 가운데 39개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("capetown")
        #expect(city.name == "케이프타운")
        #expect(city.landmark.parts.count == 8)
        #expect(city.landmark.totalCost == 39)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["upper"] == ["pylon"])
        #expect(requires["cabin"] == ["lower", "upper"])
        let region = try #require(RegionCatalog.region(ofCity: "capetown"))
        #expect(region.id == "mideastafrica")
        #expect(region.planned.isEmpty)
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "capetown") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
