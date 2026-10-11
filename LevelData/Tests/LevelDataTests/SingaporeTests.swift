import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("여섯 번째 도시 싱가포르")
struct SingaporeTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "singapore")
        #expect(levels.map(\.id) == (1...16).map { String(format: "singapore-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("싱가포르의 새 장애물은 오염 안개다. 첫 레벨에서 설명과 함께 나오고, 앞 도시의 장애물도 섞여 나온다")
    func fog() throws {
        let levels = try LevelCatalog.levels(city: "singapore")
        #expect(levels[0].obstacles.contains { $0.type == "fog" })
        #expect(levels[0].tutorial?.contains("오염 안개") == true)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "fog" } }.count >= 6)
        #expect(levels.contains { $0.obstacles.contains { $0.type == "timer" } })
        let state = try levels[0].makeState()
        #expect(!state.fog.isEmpty)
        // 안개 낀 칸에도 블록이 있다.
        #expect(state.fog.allSatisfy { state.board[$0] != nil })
    }

    @Test("마리나 베이 샌즈는 아홉 부위이고, 별 48개 가운데 40개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("singapore")
        #expect(city.name == "싱가포르")
        #expect(city.landmark.name == "마리나 베이 샌즈")
        #expect(city.landmark.parts.count == 9)
        #expect(city.landmark.totalCost == 40)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["towerLeft"] == ["podium"])
        #expect(requires["skypark"] == ["towerLeft", "towerCenter", "towerRight"])
        #expect(requires["podium"] == [])
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "singapore") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
