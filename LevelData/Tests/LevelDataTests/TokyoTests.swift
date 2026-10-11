import GameCore
import LevelTools
import Testing
@testable import LevelData

@Suite("두 번째 도시 도쿄")
struct TokyoTests {
    @Test("도시는 서울, 도쿄, 베이징으로 시작한다")
    func order() {
        #expect(Array(LevelCatalog.cityIDs.prefix(3)) == ["seoul", "tokyo", "beijing"])
    }

    @Test("레벨 16개가 있고 모두 검증을 통과한다")
    func levels() throws {
        let levels = try LevelCatalog.levels(city: "tokyo")
        #expect(levels.map(\.id) == (1...16).map { String(format: "tokyo-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(level.city == "tokyo")
            #expect(Calibration.moveRange.contains(level.moves))
        }
        // 마지막 레벨은 부스터 네 가지를 모두 준다.
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
    }

    @Test("도쿄의 새 장애물은 오염 고치다. 첫 레벨에서 설명과 함께 나오고 서울에는 없다")
    func cocoons() throws {
        let levels = try LevelCatalog.levels(city: "tokyo")
        #expect(levels[0].obstacles.contains { $0.type == "cocoon" })
        #expect(levels[0].tutorial?.contains("오염 고치") == true)
        #expect(levels.filter { $0.obstacles.contains { $0.type == "cocoon" } }.count >= 4)
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        #expect(try LevelCatalog.seoul().allSatisfy { !$0.obstacles.contains { $0.type == "cocoon" } })
        // 다음 도시의 장애물은 아직 나오지 않는다.
        #expect(levels.allSatisfy { !$0.obstacles.contains { $0.type == "rubble" } })
        // 고치에 갇힌 종류는 그 레벨에 나오는 블록이다.
        for level in levels {
            for cocoon in level.obstacles where cocoon.type == "cocoon" {
                let kind = try #require(cocoon.kind.flatMap(BlockKind.init(name:)))
                #expect(kind.rawValue < level.blockTypes)
            }
        }
    }

    @Test("이 레벨에 나오지 않는 종류의 오염 고치는 거부한다")
    func rejectsUnopenableCocoons() throws {
        var level = try LevelCatalog.levels(city: "tokyo")[0]
        #expect(level.blockTypes == 4)
        level.obstacles = [.init(type: "cocoon", column: 3, row: 6, kind: "soil")]
        #expect(throws: LevelError.invalidCocoonKind(column: 3, row: 6)) { try level.validate() }
        level.obstacles = [.init(type: "cocoon", column: 3, row: 6)]
        #expect(throws: LevelError.invalidCocoonKind(column: 3, row: 6)) { try level.validate() }
        level.obstacles = [.init(type: "cocoon", column: 3, row: 6, kind: "glass")]
        try level.validate()
        #expect(try level.makeState().board[3, 6] == .cocoon(.glass))
    }

    @Test("도쿄타워는 아홉 부위이고, 별 48개 가운데 40개면 다 복원한다")
    func landmark() throws {
        let city = try LevelCatalog.city("tokyo")
        #expect(city.name == "도쿄")
        #expect(city.landmark.name == "도쿄타워")
        #expect(city.landmark.parts.count == 9)
        #expect(city.landmark.totalCost == 40)
        // 탑은 아래에서 위로만 올릴 수 있다.
        let requires = Dictionary(uniqueKeysWithValues: city.landmark.parts.map { ($0.id, $0.requires) })
        #expect(requires["deck1"] == ["base"])
        #expect(requires["body"] == ["deck1"])
        #expect(requires["deck2"] == ["body"])
        #expect(requires["antenna"] == ["deck2"])
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다")
    func clearable() throws {
        for level in try LevelCatalog.levels(city: "tokyo") {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
