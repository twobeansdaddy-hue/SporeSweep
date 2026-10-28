import Foundation

/// 플레이어의 진행 상황. 레벨별 최고 별 수와 최고 점수, 도시별로 복원한 랜드마크 부위를 담는다(10장).
///
/// Foundation의 `Progress`와 이름이 겹치지 않게 `GameProgress`라 부른다.
public struct GameProgress: Hashable, Sendable, Codable {
    /// 레벨 ID → 그 레벨에서 받은 가장 많은 별(1~3). 클리어하지 못한 레벨은 없다.
    public private(set) var stars: [String: Int]
    /// 레벨 ID → 클리어한 판의 최고 점수.
    public private(set) var bestScores: [String: Int]
    /// 도시 ID → 플레이어가 별을 써서 복원한 랜드마크 부위의 ID.
    public private(set) var restoredParts: [String: Set<String>]
    /// 부스터의 이름 → 가진 개수. 이름은 `GameCore.Booster`의 원시 값이다.
    public private(set) var boosters: [String: Int]
    /// 생명력(6장).
    public var lives: Lives
    /// 일일 보상(6장).
    public var daily: DailyGift

    public init() {
        lives = Lives()
        daily = DailyGift()
        boosters = [:]
        stars = [:]
        bestScores = [:]
        restoredParts = [:]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stars = try container.decode([String: Int].self, forKey: .stars)
        bestScores = try container.decode([String: Int].self, forKey: .bestScores)
        // 복원 기록이 생기기 전에 저장한 파일에는 이 항목이 없다.
        restoredParts = try container.decodeIfPresent([String: Set<String>].self, forKey: .restoredParts) ?? [:]
        // 부스터가 생기기 전에 저장한 파일에는 이 항목이 없다.
        boosters = try container.decodeIfPresent([String: Int].self, forKey: .boosters) ?? [:]
        // 생명력이 생기기 전에 저장한 파일에는 이 항목이 없다. 가득 찬 채로 시작한다.
        lives = try container.decodeIfPresent(Lives.self, forKey: .lives) ?? Lives()
        daily = try container.decodeIfPresent(DailyGift.self, forKey: .daily) ?? DailyGift()
    }

    /// 다른 기기의 진행과 합친다(iCloud). 어느 쪽에서 한 것도 잃지 않게 한다.
    ///
    /// 별과 점수는 레벨마다 높은 쪽을, 복원한 부위는 양쪽을 합친 것을 남긴다.
    /// 부스터와 아이템은 쓰면 줄어드는 것이라 합칠 수 없으므로, 레벨을 더 많이 깬 쪽의 것을 따른다
    /// (같으면 부스터가 더 많은 쪽, `keepsBoosters`).
    /// 생명력과 일일 보상은 기기마다 따로 둔다.
    public func merging(_ other: GameProgress) -> GameProgress {
        var merged = self
        merged.stars.merge(other.stars) { max($0, $1) }
        merged.bestScores.merge(other.bestScores) { max($0, $1) }
        merged.restoredParts.merge(other.restoredParts) { $0.union($1) }
        if Self.keepsBoosters(of: other, over: self) {
            merged.boosters = other.boosters
        }
        return merged
    }

    /// 합칠 때 `candidate`의 부스터를 `current`의 것 대신 남기는지.
    /// 레벨을 더 많이 깬 쪽, 같으면 부스터가 더 많은 쪽, 그래도 같으면 정해진 순서로 고른다.
    /// 어느 쪽에서 합쳐도 같은 쪽을 고르므로 두 기기가 서로 다시 올리기를 되풀이하지 않는다.
    static func keepsBoosters(of candidate: GameProgress, over current: GameProgress) -> Bool {
        if candidate.stars.count != current.stars.count {
            return candidate.stars.count > current.stars.count
        }
        let candidateTotal = candidate.boosters.values.reduce(0, +)
        let currentTotal = current.boosters.values.reduce(0, +)
        if candidateTotal != currentTotal {
            return candidateTotal > currentTotal
        }
        let order = { (boosters: [String: Int]) in boosters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",") }
        return order(candidate.boosters) > order(current.boosters)
    }

    /// 기기마다 따로 두는 것(생명력, 일일 보상)을 빼고 같은지. iCloud에 올릴 것이 있는지 볼 때 쓴다.
    public func sharesProgress(with other: GameProgress) -> Bool {
        stars == other.stars && bestScores == other.bestScores
            && restoredParts == other.restoredParts && boosters == other.boosters
    }

    /// 가진 부스터의 수.
    public func boosterCount(_ name: String) -> Int {
        boosters[name] ?? 0
    }

    /// 부스터를 받는다.
    public mutating func addBooster(_ name: String, count: Int = 1) {
        guard count > 0 else { return }
        boosters[name, default: 0] += count
    }

    /// 부스터 하나를 쓴다.
    /// - Returns: 썼는지. 가진 것이 없으면 `false`다.
    @discardableResult
    public mutating func useBooster(_ name: String) -> Bool {
        guard boosterCount(name) > 0 else { return false }
        boosters[name] = boosterCount(name) - 1
        return true
    }

    /// 도시에서 복원한 부위.
    public func restoredParts(in cityID: String) -> Set<String> {
        restoredParts[cityID] ?? []
    }

    /// 부위를 복원한 것으로 기록한다. 별이 충분한지, 순서가 맞는지는 호출하는 쪽에서 확인한다.
    /// - Returns: 새로 기록했는지. 이미 복원한 부위면 `false`다.
    @discardableResult
    public mutating func restore(partID: String, in cityID: String) -> Bool {
        restoredParts[cityID, default: []].insert(partID).inserted
    }

    public func stars(for levelID: String) -> Int {
        stars[levelID] ?? 0
    }

    public func bestScore(for levelID: String) -> Int {
        bestScores[levelID] ?? 0
    }

    public func isCleared(_ levelID: String) -> Bool {
        stars(for: levelID) > 0
    }

    /// 클리어한 판을 기록한다. 별과 점수는 각각 더 높은 쪽만 남긴다.
    /// - Returns: 기록이 바뀌었는지.
    @discardableResult
    public mutating func recordClear(levelID: String, stars newStars: Int, score: Int) -> Bool {
        let clamped = min(max(newStars, 1), 3)
        var changed = false
        if clamped > stars(for: levelID) {
            stars[levelID] = clamped
            changed = true
        }
        if score > bestScore(for: levelID) || bestScores[levelID] == nil {
            bestScores[levelID] = max(score, 0)
            changed = true
        }
        return changed
    }

    /// 주어진 레벨 가운데 클리어한 수.
    public func clearedCount(in levelIDs: [String]) -> Int {
        levelIDs.count { isCleared($0) }
    }

    /// 주어진 레벨에서 받은 별의 합.
    public func totalStars(in levelIDs: [String]) -> Int {
        levelIDs.map { stars(for: $0) }.reduce(0, +)
    }

    /// 순서대로 놓인 레벨 가운데 `index`번째를 플레이할 수 있는지.
    /// 첫 레벨은 늘 열려 있고, 나머지는 바로 앞 레벨을 클리어해야 열린다.
    public func isUnlocked(index: Int, in levelIDs: [String]) -> Bool {
        guard levelIDs.indices.contains(index) else { return false }
        return index == 0 || isCleared(levelIDs[index - 1])
    }
}
