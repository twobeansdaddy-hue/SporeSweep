import GameCore
import LevelTools
import Testing
@testable import LevelData

/// 넷째 권역부터의 도시 15곳. 권역의 첫 도시에만 새 장애물과 설명이 있다.
@Suite("넷째 권역부터의 도시")
struct LaterCitiesTests {
    static let cities = [
        "rome", "athens", "barcelona", "paris", "london", "amsterdam",
        "newyork", "sanfrancisco", "washington", "rio", "buenosaires", "easterisland",
        "sydney", "auckland", "antarctica",
    ]
    /// 권역의 첫 도시와 거기서 처음 나오는 장애물.
    static let debuts = ["rome": "chain", "paris": "shield", "newyork": "boulder", "rio": "vent", "sydney": "ice"]

    @Test("도시는 스물네 곳이고 권역마다 세 곳이다")
    func catalog() {
        #expect(LevelCatalog.cityIDs.count == 24)
        #expect(RegionCatalog.cityIDs == LevelCatalog.cityIDs)
        #expect(RegionCatalog.all.allSatisfy { $0.cityIDs.count == 3 && $0.planned.isEmpty && !$0.mapImage.isEmpty })
    }

    @Test("레벨 16개가 있고 모두 검증을 통과한다", arguments: cities)
    func levels(city: String) throws {
        let levels = try LevelCatalog.levels(city: city)
        #expect(levels.map(\.id) == (1...16).map { String(format: "\(city)-%03d", $0) })
        for level in levels {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        #expect(Set(levels[15].rewards) == Set(Booster.allCases))
        if let debut = Self.debuts[city] {
            #expect(levels[0].obstacles.contains { $0.type == debut })
            #expect(levels[0].tutorial != nil)
            #expect(levels.filter { $0.obstacles.contains { $0.type == debut } }.count >= 3)
        } else {
            #expect(levels[0].tutorial == nil)
        }
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
    }

    @Test("랜드마크는 건물 다섯 부위와 환경 네 부위이고, 별 40개면 다 복원한다", arguments: cities)
    func landmark(city: String) throws {
        let landmark = try LevelCatalog.city(city).landmark
        #expect(landmark.parts.count == 9)
        #expect(landmark.parts.suffix(4).map(\.id) == ["pollution", "ground", "greenery", "sky"])
        #expect(landmark.totalCost == 40)
        // 처음부터 복원할 수 있는 건물 부위가 하나는 있다.
        #expect(landmark.parts.prefix(5).contains { $0.requires.isEmpty })
    }

    @Test("봇이 모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다", arguments: cities)
    func clearable(city: String) throws {
        for level in try LevelCatalog.levels(city: city) {
            let state = try level.makeState()
            var cleared = false
            for policySeed in 0..<30 as Range<UInt64> where !cleared {
                cleared = Solver.playout(state, policySeed: policySeed) != nil
            }
            #expect(cleared, "\(level.id)")
        }
    }
}
