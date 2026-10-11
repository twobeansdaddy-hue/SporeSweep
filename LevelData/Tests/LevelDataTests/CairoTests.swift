import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("일곱 번째 도시 카이로")
struct CairoTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "cairo")
        #expect(levels.map(\.id) == (1...16).map { String(format: "cairo-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("카이로의 새 장애물은 끈끈이 바닥이다. 첫 레벨에서 설명과 함께 나오고, 앞 도시의 장애물도 섞여 나온다")
    func sticky() throws {
        let levels = try LevelCatalog.levels(city: "cairo")
        #expect(levels[0].obstacles.contains { $0.type == "sticky" })
        #expect(levels[0].tutorial?.contains("끈끈이") == true)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "sticky" } }.count >= 6)
        let state = try levels[0].makeState()
        #expect(!state.sticky.isEmpty)
        #expect(state.sticky.allSatisfy { state.board[$0] != nil })
        #expect(!state.possibleMoves().isEmpty)
    }

    @Test("피라미드와 스핑크스는 열 부위이고, 별 48개 가운데 43개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("cairo")
        #expect(city.name == "카이로")
        #expect(city.landmark.parts.count == 10)
        #expect(city.landmark.totalCost == 43)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["middle"] == ["base"])
        #expect(requires["peak"] == ["middle"])
        #expect(requires["sphinx"] == [])
        #expect(RegionCatalog.region(ofCity: "cairo")?.id == "mideastafrica")
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "cairo") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
