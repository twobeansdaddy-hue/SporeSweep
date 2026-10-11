import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("네 번째 도시 뉴델리")
struct NewDelhiTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "newdelhi")
        #expect(levels.map(\.id) == (1...16).map { String(format: "newdelhi-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("뉴델리의 새 장애물은 포자 둥지다. 첫 레벨에서 설명과 함께 나오고, 앞 도시의 장애물도 섞여 나온다")
    func nest() throws {
        let levels = try LevelCatalog.levels(city: "newdelhi")
        #expect(levels[0].obstacles.contains { $0.type == "nest" })
        #expect(levels[0].tutorial?.contains("포자 둥지") == true)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "nest" } }.count >= 4)
        #expect(levels.contains { $0.obstacles.contains { $0.type == "rubble" } })
        #expect(levels.contains { $0.obstacles.contains { $0.type == "cocoon" } })
        let state = try levels[0].makeState()
        #expect(state.board.positions.contains { state.board[$0] == .nest(hp: 2) })
    }

    @Test("포자 둥지의 hp는 1이나 2여야 한다")
    func nestHP() throws {
        var level = try LevelCatalog.levels(city: "newdelhi")[0]
        let index = try #require(level.obstacles.firstIndex { $0.type == "nest" })
        level.obstacles[index].hp = 3
        #expect(throws: LevelError.self) { try level.validate() }
    }

    @Test("인디아 게이트는 열 부위이고, 별 48개 가운데 44개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("newdelhi")
        #expect(city.name == "뉴델리")
        #expect(city.landmark.name == "인디아 게이트")
        #expect(city.landmark.parts.count == 10)
        #expect(city.landmark.totalCost == 44)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["arch"] == ["pierLeft", "pierRight"])
        #expect(requires["crown"] == ["arch"])
        #expect(requires["wallLeft"] == [])
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "newdelhi") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
