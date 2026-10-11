import Foundation
import LevelData
import Testing

private func part(_ id: String, _ cost: Int, requires: [String] = []) -> Landmark.Part {
    Landmark.Part(id: id, name: id, cost: cost, requires: requires)
}

private func city(_ parts: [Landmark.Part]) -> City {
    City(id: "test", name: "테스트", landmark: Landmark(id: "tower", name: "탑", parts: parts))
}

private func error(_ city: City, levelCount: Int = 12) -> CityError? {
    do {
        try city.validate(levelCount: levelCount)
        return nil
    } catch {
        return error
    }
}

@Suite("별을 써서 복원하는 랜드마크")
struct LandmarkRestorationTests {
    let landmark = Landmark(id: "tower", name: "탑", parts: [
        part("gate", 3), part("wallLeft", 3), part("floor1", 5), part("floor2", 6, requires: ["floor1"]),
    ])

    @Test("전체 복원에 필요한 별은 부위 비용의 합이다")
    func totalCost() {
        #expect(landmark.totalCost == 17)
    }

    @Test("복원한 부위의 비용만큼 별을 쓴 것이다")
    func spentAndAvailable() {
        #expect(landmark.spentStars(restored: []) == 0)
        #expect(landmark.spentStars(restored: ["gate", "floor1"]) == 8)
        #expect(landmark.availableStars(earned: 10, restored: ["gate", "floor1"]) == 2)
        #expect(landmark.availableStars(earned: 10, restored: []) == 10)
        // 모르는 ID는 세지 않고, 음수가 되지 않는다.
        #expect(landmark.spentStars(restored: ["ghost"]) == 0)
        #expect(landmark.availableStars(earned: 2, restored: ["gate"]) == 0)
    }

    @Test("별이 충분하면 원하는 부위를 고를 수 있다")
    func canChooseAnyAffordablePart() {
        #expect(landmark.blocker(for: "gate", earned: 3, restored: []) == nil)
        #expect(landmark.blocker(for: "wallLeft", earned: 3, restored: []) == nil)
        #expect(landmark.blocker(for: "floor1", earned: 5, restored: []) == nil)
    }

    @Test("별이 모자라면 복원할 수 없다")
    func notEnoughStars() {
        #expect(landmark.blocker(for: "gate", earned: 2, restored: []) == .notEnoughStars(short: 1))
        // 이미 쓴 별은 다시 쓸 수 없다.
        #expect(landmark.blocker(for: "wallLeft", earned: 5, restored: ["gate"]) == .notEnoughStars(short: 1))
        #expect(landmark.blocker(for: "wallLeft", earned: 6, restored: ["gate"]) == nil)
    }

    @Test("먼저 복원해야 하는 부위가 있으면 그것부터다")
    func prerequisites() {
        #expect(landmark.blocker(for: "floor2", earned: 36, restored: []) == .requires("floor1"))
        #expect(landmark.blocker(for: "floor2", earned: 36, restored: ["floor1"]) == nil)
    }

    @Test("이미 복원한 부위와 없는 부위는 복원할 수 없다")
    func alreadyOrUnknown() {
        #expect(landmark.blocker(for: "gate", earned: 36, restored: ["gate"]) == .alreadyRestored)
        #expect(landmark.blocker(for: "moat", earned: 36, restored: []) == .unknownPart)
    }

    @Test("모든 부위를 복원하면 랜드마크가 완성된다")
    func fullRestoration() {
        #expect(!landmark.isFullyRestored([]))
        #expect(!landmark.isFullyRestored(["gate", "wallLeft", "floor1"]))
        #expect(landmark.isFullyRestored(["gate", "wallLeft", "floor1", "floor2"]))
    }
}

@Suite("도시 데이터 검증")
struct CityValidationTests {
    @Test("올바른 계획은 통과한다")
    func valid() {
        #expect(error(city([part("a", 3), part("b", 6, requires: ["a"])])) == nil)
    }

    @Test("부위가 없거나 ID가 겹치면 거부한다")
    func partsAndIDs() {
        #expect(error(city([])) == .noParts)
        #expect(error(city([part("a", 3), part("a", 6)])) == .duplicatePart("a"))
    }

    @Test("비용은 1 이상이어야 한다")
    func cost() {
        #expect(error(city([part("a", 0)])) == .invalidCost(part: "a", cost: 0))
    }

    @Test("먼저 복원할 부위는 목록에서 앞에 있어야 한다")
    func requirements() {
        #expect(error(city([part("a", 3, requires: ["b"]), part("b", 3)])) == .invalidRequirement(part: "a", requires: "b"))
        #expect(error(city([part("a", 3, requires: ["a"])])) == .invalidRequirement(part: "a", requires: "a"))
        #expect(error(city([part("a", 3, requires: ["ghost"])])) == .invalidRequirement(part: "a", requires: "ghost"))
    }

    @Test("도시의 레벨로 모을 수 있는 별보다 비싸면 거부한다")
    func affordable() {
        #expect(error(city([part("a", 36)]), levelCount: 12) == nil)
        #expect(error(city([part("a", 30), part("b", 7)]), levelCount: 12) == .unaffordable(totalCost: 37, available: 36))
    }
}

@Suite("서울")
struct SeoulCityTests {
    @Test("서울의 랜드마크는 숭례문이고 별 36개 가운데 30개로 전체를 복원한다")
    func seoul() throws {
        let city = try LevelCatalog.city("seoul")
        #expect(city.id == "seoul")
        #expect(city.name == "서울")
        #expect(city.landmark.id == "sungnyemun")
        #expect(city.landmark.name == "숭례문")
        #expect(city.landmark.totalCost == 30)
        #expect(try LevelCatalog.seoul().count * 3 == 36)
    }

    @Test("부위와 비용")
    func parts() throws {
        let landmark = try LevelCatalog.city("seoul").landmark
        #expect(landmark.parts.map(\.id) == [
            "gate", "wallLeft", "wallRight", "floor1", "floor2", "pollution", "ground", "greenery", "sky",
        ])
        #expect(landmark.parts.first { $0.id == "gate" }?.cost == 3)
        #expect(landmark.parts.first { $0.id == "wallLeft" }?.cost == 3)
        #expect(landmark.parts.first { $0.id == "floor2" }?.cost == 6)
        #expect(landmark.parts.first { $0.id == "floor2" }?.requires == ["floor1"])
    }

    @Test("어떤 순서로 골라도 30개로 끝까지 복원할 수 있다")
    func anyOrderCompletes() throws {
        let landmark = try LevelCatalog.city("seoul").landmark
        // 고를 수 있는 것 가운데 목록의 뒤쪽부터 고르는 순서와 앞쪽부터 고르는 순서를 모두 본다.
        for reversed in [false, true] {
            var restored: Set<String> = []
            while !landmark.isFullyRestored(restored) {
                let candidates = reversed ? landmark.parts.reversed() : landmark.parts
                guard let next = candidates.first(where: {
                    landmark.blocker(for: $0.id, earned: 30, restored: restored) == nil
                }) else {
                    Issue.record("더 고를 수 있는 부위가 없다: \(restored)")
                    break
                }
                restored.insert(next.id)
            }
            #expect(landmark.spentStars(restored: restored) == 30)
            #expect(landmark.availableStars(earned: 30, restored: restored) == 0)
        }
    }

    @Test("없는 도시는 읽지 못한다")
    func missingCity() {
        #expect(throws: (any Error).self) {
            try LevelCatalog.city("atlantis")
        }
    }
}
