import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("세 번째 도시 베이징")
struct BeijingTests {
    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "beijing")
        #expect(levels.map(\.id) == (1...16).map { String(format: "beijing-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("베이징의 새 장애물은 잔해 더미다. 첫 레벨에서 설명과 함께 나오고, 앞 도시의 오염 고치도 섞여 나온다")
    func rubble() throws {
        let levels = try LevelCatalog.levels(city: "beijing")
        #expect(levels[0].obstacles.contains { $0.type == "rubble" })
        #expect(levels[0].tutorial?.contains("잔해 더미") == true)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(levels.filter { $0.obstacles.contains { $0.type == "rubble" } }.count >= 4)
        #expect(levels.contains { $0.obstacles.contains { $0.type == "cocoon" } })
        #expect(try levels[0].makeState().board.positions.contains { _ in true })
    }

    @Test("만리장성은 아홉 부위이고, 별 48개 가운데 40개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("beijing")
        #expect(city.name == "베이징")
        #expect(city.landmark.name == "만리장성")
        #expect(city.landmark.parts.count == 9)
        #expect(city.landmark.totalCost == 40)
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["tower"] == ["gate"])
        #expect(requires["roof"] == ["tower"])
        #expect(requires["wallLeft"] == [])
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "beijing") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
