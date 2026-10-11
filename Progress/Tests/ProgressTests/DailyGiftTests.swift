import Foundation
import Testing
@testable import Progress

@Suite("일일 보상과 합치기")
struct DailyGiftTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func day(_ offset: Double) -> Date {
        start.addingTimeInterval(offset * 86_400)
    }

    @Test("하루에 한 번만 받는다")
    func oncePerDay() {
        var gift = DailyGift()
        #expect(gift.canClaim(at: start, calendar: calendar))
        let first = gift.claim(at: start, calendar: calendar)
        #expect(first == DailyGift.rewards[0])
        #expect(!gift.canClaim(at: start.addingTimeInterval(3600), calendar: calendar))
        let again = gift.claim(at: start.addingTimeInterval(3600), calendar: calendar)
        #expect(again == nil)
    }

    @Test("날마다 이어서 받으면 다음 날의 선물로 넘어가고, 이레 뒤에는 첫날로 돈다")
    func streak() {
        var gift = DailyGift()
        for index in 0..<8 {
            #expect(gift.nextDay(at: day(Double(index)), calendar: calendar) == index % 7 + 1)
            let reward = gift.claim(at: day(Double(index)), calendar: calendar)
            #expect(reward == DailyGift.rewards[index % 7])
        }
    }

    @Test("하루를 거르면 첫날로 돌아간다")
    func missedDay() {
        var gift = DailyGift()
        _ = gift.claim(at: day(0), calendar: calendar)
        _ = gift.claim(at: day(1), calendar: calendar)
        #expect(gift.nextDay(at: day(3), calendar: calendar) == 1)
        let reward = gift.claim(at: day(3), calendar: calendar)
        #expect(reward == DailyGift.rewards[0])
    }

    @Test("시계를 뒤로 돌려도 다시 받을 수 없다")
    func clockRollback() {
        var gift = DailyGift()
        _ = gift.claim(at: day(2), calendar: calendar)
        #expect(!gift.canClaim(at: day(0), calendar: calendar))
    }

    @Test("이레째에는 생명과 아이템 세 가지를 받는다")
    func seventhDay() {
        #expect(DailyGift.rewards.count == DailyGift.cycle)
        #expect(DailyGift.rewards[6].contains("lives"))
        #expect(DailyGift.rewards[6].filter { $0.hasPrefix("tool:") }.count == 3)
    }

    @Test("두 기기의 진행을 합치면 별은 높은 쪽, 복원은 양쪽을 합친 것이 남는다")
    func merging() {
        var here = GameProgress()
        here.recordClear(levelID: "a", stars: 3, score: 100)
        here.recordClear(levelID: "b", stars: 1, score: 500)
        here.restore(partID: "gate", in: "seoul")
        here.addBooster("bomb", count: 2)
        var there = GameProgress()
        there.recordClear(levelID: "a", stars: 1, score: 900)
        there.recordClear(levelID: "b", stars: 2, score: 50)
        there.recordClear(levelID: "c", stars: 2, score: 70)
        there.restore(partID: "roof", in: "seoul")
        there.addBooster("beam", count: 1)
        let merged = here.merging(there)
        #expect(merged.stars(for: "a") == 3)
        #expect(merged.stars(for: "b") == 2)
        #expect(merged.stars(for: "c") == 2)
        #expect(merged.bestScore(for: "a") == 900)
        #expect(merged.restoredParts(in: "seoul") == ["gate", "roof"])
        // 레벨을 더 많이 깬 쪽의 부스터를 따른다.
        #expect(merged.boosterCount("beam") == 1)
        #expect(merged.boosterCount("bomb") == 0)
        // 합치는 순서가 바뀌어도 별과 복원은 같다.
        let reversed = there.merging(here)
        #expect(reversed.stars(for: "a") == 3)
        #expect(reversed.restoredParts(in: "seoul") == ["gate", "roof"])
    }

    @Test("예전 저장 파일에는 일일 보상이 없어도 읽힌다")
    func decodesOldFile() throws {
        let old = try JSONDecoder().decode(GameProgress.self, from: Data(#"{"stars":{},"bestScores":{}}"#.utf8))
        #expect(old.daily.canClaim(at: start, calendar: calendar))
    }
}
