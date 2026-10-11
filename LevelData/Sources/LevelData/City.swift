import Foundation

/// 도시 하나. 레벨을 플레이해 모은 별을 써서 랜드마크를 부위별로 복원한다(8장).
public struct City: Hashable, Sendable, Codable, Identifiable {
    public var id: String
    public var name: String
    public var landmark: Landmark

    public init(id: String, name: String, landmark: Landmark) {
        self.id = id
        self.name = name
        self.landmark = landmark
    }
}

/// 랜드마크와 복원할 부위들.
///
/// 플레이어는 모은 별을 써서 복원할 부위를 직접 고른다. 모든 부위를 복원하면 랜드마크가 완성된다.
public struct Landmark: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var parts: [Part]

    /// 복원할 부위 하나.
    public struct Part: Hashable, Sendable, Codable, Identifiable {
        public var id: String
        public var name: String
        /// 복원하는 데 쓰는 별 수.
        public var cost: Int
        /// 먼저 복원해야 하는 부위의 ID. 2층은 1층이 있어야 올릴 수 있는 식이다.
        public var requires: [String]

        public init(id: String, name: String, cost: Int, requires: [String] = []) {
            self.id = id
            self.name = name
            self.cost = cost
            self.requires = requires
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            cost = try container.decode(Int.self, forKey: .cost)
            requires = try container.decodeIfPresent([String].self, forKey: .requires) ?? []
        }
    }

    public init(id: String, name: String, parts: [Part]) {
        self.id = id
        self.name = name
        self.parts = parts
    }

    /// 전체를 복원하는 데 필요한 별 수.
    public var totalCost: Int {
        parts.map(\.cost).reduce(0, +)
    }

    /// 이미 복원한 부위에 쓴 별 수.
    public func spentStars(restored: Set<String>) -> Int {
        parts.filter { restored.contains($0.id) }.map(\.cost).reduce(0, +)
    }

    /// 모은 별 가운데 아직 쓰지 않은 별 수.
    public func availableStars(earned: Int, restored: Set<String>) -> Int {
        max(earned - spentStars(restored: restored), 0)
    }

    public func isFullyRestored(_ restored: Set<String>) -> Bool {
        !parts.isEmpty && parts.allSatisfy { restored.contains($0.id) }
    }

    /// 부위를 지금 복원할 수 없는 이유. 복원할 수 있으면 `nil`이다.
    public func blocker(for partID: String, earned: Int, restored: Set<String>) -> RestoreBlocker? {
        guard let part = parts.first(where: { $0.id == partID }) else { return .unknownPart }
        if restored.contains(partID) {
            return .alreadyRestored
        }
        if let missing = part.requires.first(where: { !restored.contains($0) }) {
            return .requires(missing)
        }
        let available = availableStars(earned: earned, restored: restored)
        if available < part.cost {
            return .notEnoughStars(short: part.cost - available)
        }
        return nil
    }
}

/// 부위를 복원할 수 없는 이유.
public enum RestoreBlocker: Hashable, Sendable {
    /// 랜드마크에 없는 부위다.
    case unknownPart
    /// 이미 복원했다.
    case alreadyRestored
    /// 먼저 복원해야 하는 부위가 있다. 값은 그 부위의 ID다.
    case requires(String)
    /// 별이 모자란다. 값은 모자란 개수다.
    case notEnoughStars(short: Int)
}

/// 도시 데이터가 잘못된 이유.
public enum CityError: Error, Hashable, Sendable {
    /// 복원할 부위가 없다.
    case noParts
    /// 부위 ID가 겹친다.
    case duplicatePart(String)
    /// 복원 비용이 1보다 작다.
    case invalidCost(part: String, cost: Int)
    /// 먼저 복원해야 하는 부위가 목록에서 자기보다 앞에 없다.
    case invalidRequirement(part: String, requires: String)
    /// 도시의 레벨을 모두 별 3개로 깨도 전체를 복원할 수 없다.
    case unaffordable(totalCost: Int, available: Int)
}

extension City {
    /// 복원 계획을 검증한다. `levelCount`는 이 도시의 레벨 수다.
    public func validate(levelCount: Int) throws(CityError) {
        let parts = landmark.parts
        guard !parts.isEmpty else { throw .noParts }
        var seen: Set<String> = []
        for part in parts {
            guard !seen.contains(part.id) else { throw .duplicatePart(part.id) }
            guard part.cost >= 1 else { throw .invalidCost(part: part.id, cost: part.cost) }
            // 앞에 나온 부위만 가리키게 해서 서로 맞물려 영영 복원할 수 없는 일을 막는다.
            for required in part.requires where !seen.contains(required) {
                throw .invalidRequirement(part: part.id, requires: required)
            }
            seen.insert(part.id)
        }
        guard landmark.totalCost <= levelCount * 3 else {
            throw .unaffordable(totalCost: landmark.totalCost, available: levelCount * 3)
        }
    }
}
