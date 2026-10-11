import Foundation

/// 생명력(6장). 판에서 실패하면 하나 줄고, 시간이 지나면 하나씩 다시 찬다.
///
/// 시계를 직접 읽지 않고 늘 지금 시각을 받아서 계산한다. 그래야 시험할 수 있다.
public struct Lives: Hashable, Sendable, Codable {
    /// 가질 수 있는 가장 많은 수.
    public static let maximum = 5
    /// 하나가 차는 데 걸리는 시간(초).
    public static let refillInterval: TimeInterval = 30 * 60
    /// 하루에 광고로 받을 수 있는 수.
    public static let dailyAdLimit = 5

    /// 마지막으로 셈한 때의 수. 그 뒤에 찬 것은 `count(at:)`가 더한다.
    private var stored: Int
    /// 회복을 세기 시작한 때. 가득 차 있으면 `nil`이다.
    private var refillStart: Date?
    /// 광고로 받은 날(그날 0시)과 그날 받은 수.
    private var adDay: Date?
    private var adCount: Int

    public init() {
        stored = Self.maximum
        refillStart = nil
        adDay = nil
        adCount = 0
    }

    /// 지금 가진 수.
    public func count(at now: Date) -> Int {
        guard let refillStart else { return min(stored, Self.maximum) }
        // 시계를 뒤로 돌렸으면 지난 시간이 없는 것으로 본다.
        let elapsed = max(now.timeIntervalSince(refillStart), 0)
        return min(stored + Int(elapsed / Self.refillInterval), Self.maximum)
    }

    /// 다음 하나가 차기까지 남은 시간(초). 가득 차 있으면 `nil`이다.
    public func timeUntilNext(at now: Date) -> TimeInterval? {
        guard let refillStart, count(at: now) < Self.maximum else { return nil }
        let elapsed = max(now.timeIntervalSince(refillStart), 0)
        return Self.refillInterval - elapsed.truncatingRemainder(dividingBy: Self.refillInterval)
    }

    /// 그동안 찬 것을 반영해 기준 시각을 옮긴다. 차다 만 시간은 그대로 이어진다.
    private mutating func settle(at now: Date) {
        guard let start = refillStart else { return }
        let elapsed = max(now.timeIntervalSince(start), 0)
        let gained = Int(elapsed / Self.refillInterval)
        stored = min(stored + gained, Self.maximum)
        refillStart = stored >= Self.maximum ? nil : start.addingTimeInterval(Double(gained) * Self.refillInterval)
    }

    /// 하나를 잃는다.
    /// - Returns: 잃었는지. 하나도 없으면 `false`다.
    @discardableResult
    public mutating func lose(at now: Date) -> Bool {
        settle(at: now)
        guard stored > 0 else { return false }
        stored -= 1
        // 가득 차 있다가 처음 잃었을 때부터 회복을 센다.
        if refillStart == nil {
            refillStart = now
        }
        return true
    }

    /// 오늘 광고로 더 받을 수 있는 수.
    public func adGrantsLeft(at now: Date, calendar: Calendar = .current) -> Int {
        guard let adDay, calendar.isDate(adDay, inSameDayAs: now) else { return Self.dailyAdLimit }
        return max(Self.dailyAdLimit - adCount, 0)
    }

    /// 광고를 보고 하나를 받는다.
    /// - Returns: 받았는지. 가득 차 있거나 오늘 받을 수 있는 만큼 다 받았으면 `false`다.
    @discardableResult
    public mutating func addFromAd(at now: Date, calendar: Calendar = .current) -> Bool {
        settle(at: now)
        guard stored < Self.maximum, adGrantsLeft(at: now, calendar: calendar) > 0 else { return false }
        if let adDay, calendar.isDate(adDay, inSameDayAs: now) {
            adCount += 1
        } else {
            adDay = calendar.startOfDay(for: now)
            adCount = 1
        }
        stored += 1
        if stored >= Self.maximum {
            refillStart = nil
        }
        return true
    }

    /// 수를 바로 정한다. 시험과 개발용 실행 인자에 쓴다.
    public mutating func set(_ count: Int, at now: Date) {
        stored = min(max(count, 0), Self.maximum)
        refillStart = stored >= Self.maximum ? nil : now
    }
}
