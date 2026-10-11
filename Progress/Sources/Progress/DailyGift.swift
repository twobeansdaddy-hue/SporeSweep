import Foundation

/// 일일 보상(6장). 하루에 한 번 받고, 날마다 이어서 받으면 선물이 커진다. 이레가 한 바퀴다.
///
/// 시계를 직접 읽지 않고 늘 지금 시각을 받아서 계산한다.
public struct DailyGift: Hashable, Sendable, Codable {
    /// 한 바퀴의 날 수.
    public static let cycle = 7
    /// 날마다 받는 것. `booster:이름`, `tool:이름`, `lives`(생명을 가득 채운다)로 적는다.
    public static let rewards: [[String]] = [
        ["booster:extraMoves"],
        ["tool:hammer"],
        ["booster:bomb"],
        ["tool:swap"],
        ["booster:beam", "tool:shuffle"],
        ["booster:core"],
        ["lives", "tool:hammer", "tool:swap", "tool:shuffle"],
    ]

    /// 마지막으로 받은 날(그날 0시).
    public private(set) var lastDay: Date?
    /// 이어서 받은 날 수. 받은 적이 없으면 0이다.
    public private(set) var streak: Int

    public init() {
        lastDay = nil
        streak = 0
    }

    /// 오늘 받을 수 있는지.
    public func canClaim(at now: Date, calendar: Calendar = .current) -> Bool {
        guard let lastDay else { return true }
        // 시계를 뒤로 돌려 마지막으로 받은 날보다 앞이 되어도 다시 받을 수 없다.
        return calendar.startOfDay(for: now) > lastDay
    }

    /// 지금 받으면 몇째 날의 선물인지(1부터). 어제 받았으면 이어지고, 하루라도 거르면 첫날로 돌아간다.
    public func nextDay(at now: Date, calendar: Calendar = .current) -> Int {
        guard let lastDay, streak > 0,
              let gap = calendar.dateComponents([.day], from: lastDay, to: calendar.startOfDay(for: now)).day,
              gap <= 1 else { return 1 }
        return streak % Self.cycle + 1
    }

    /// 오늘의 선물을 받는다.
    /// - Returns: 받은 것. 오늘 이미 받았으면 `nil`이다.
    public mutating func claim(at now: Date, calendar: Calendar = .current) -> [String]? {
        guard canClaim(at: now, calendar: calendar) else { return nil }
        let day = nextDay(at: now, calendar: calendar)
        streak = day
        lastDay = calendar.startOfDay(for: now)
        return Self.rewards[day - 1]
    }
}
