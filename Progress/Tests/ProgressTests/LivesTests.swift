import Foundation
import Testing
@testable import Progress

@Suite("생명력")
struct LivesTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    @Test("가득 찬 채로 시작하고, 가득 차 있으면 기다릴 것이 없다")
    func startsFull() {
        let lives = Lives()
        #expect(lives.count(at: start) == 5)
        #expect(lives.timeUntilNext(at: start) == nil)
    }

    @Test("잃으면 하나 줄고, 30분 뒤에 다시 찬다")
    func refills() {
        var lives = Lives()
        let result1 = lives.lose(at: start)
        #expect(result1)
        #expect(lives.count(at: start) == 4)
        #expect(lives.timeUntilNext(at: minutes(10)) == TimeInterval(20 * 60))
        #expect(lives.count(at: minutes(29)) == 4)
        #expect(lives.count(at: minutes(30)) == 5)
        #expect(lives.timeUntilNext(at: minutes(30)) == nil)
    }

    @Test("회복은 처음 잃은 때부터 세고, 더 잃어도 처음부터 다시 세지 않는다")
    func keepsTimer() {
        var lives = Lives()
        lives.lose(at: start)
        lives.lose(at: minutes(20))
        #expect(lives.count(at: minutes(20)) == 3)
        // 첫 번째는 30분에, 두 번째는 60분에 찬다.
        #expect(lives.timeUntilNext(at: minutes(20)) == TimeInterval(10 * 60))
        #expect(lives.count(at: minutes(30)) == 4)
        #expect(lives.count(at: minutes(60)) == 5)
    }

    @Test("차는 도중에 잃어도 차다 만 시간이 이어진다")
    func settlesPartialTime() {
        var lives = Lives()
        lives.lose(at: start)
        lives.lose(at: start)
        // 45분 뒤: 하나가 찼고 다음 것은 15분이 지났다.
        lives.lose(at: minutes(45))
        #expect(lives.count(at: minutes(45)) == 3)
        #expect(lives.timeUntilNext(at: minutes(45)) == TimeInterval(15 * 60))
    }

    @Test("하나도 없으면 더 잃지 않는다")
    func cannotGoBelowZero() {
        var lives = Lives()
        for _ in 0..<5 { lives.lose(at: start) }
        #expect(lives.count(at: start) == 0)
        let result2 = lives.lose(at: start)
        #expect(!result2)
        // 오래 지나도 최대를 넘지 않는다.
        #expect(lives.count(at: minutes(60 * 24)) == 5)
    }

    @Test("시계를 뒤로 돌려도 늘거나 줄지 않는다")
    func clockRollback() {
        var lives = Lives()
        lives.lose(at: start)
        #expect(lives.count(at: minutes(-120)) == 4)
        #expect(lives.timeUntilNext(at: minutes(-120)) == TimeInterval(30 * 60))
    }

    @Test("광고로 하나를 받는다. 가득 차 있으면 받지 않는다")
    func adGrant() {
        var lives = Lives()
        let result3 = lives.addFromAd(at: start, calendar: calendar)
        #expect(!result3)
        lives.lose(at: start)
        lives.lose(at: start)
        let result4 = lives.addFromAd(at: minutes(1), calendar: calendar)
        #expect(result4)
        #expect(lives.count(at: minutes(1)) == 4)
        // 회복 시간은 이어진다.
        #expect(lives.timeUntilNext(at: minutes(1)) == TimeInterval(29 * 60))
        let result5 = lives.addFromAd(at: minutes(2), calendar: calendar)
        #expect(result5)
        #expect(lives.timeUntilNext(at: minutes(2)) == nil)
    }

    @Test("광고로는 하루에 다섯 번까지만 받고, 다음 날 다시 받을 수 있다")
    func dailyAdLimit() {
        var lives = Lives()
        for index in 0..<5 {
            lives.set(0, at: minutes(Double(index)))
            let result6 = lives.addFromAd(at: minutes(Double(index)), calendar: calendar)
            #expect(result6)
        }
        lives.set(0, at: minutes(6))
        #expect(lives.adGrantsLeft(at: minutes(6), calendar: calendar) == 0)
        let result7 = lives.addFromAd(at: minutes(6), calendar: calendar)
        #expect(!result7)
        let tomorrow = minutes(60 * 24)
        #expect(lives.adGrantsLeft(at: tomorrow, calendar: calendar) == 5)
        lives.set(0, at: tomorrow)
        let result8 = lives.addFromAd(at: tomorrow, calendar: calendar)
        #expect(result8)
    }

    @Test("저장했다가 읽어도 그대로이고, 예전 저장 파일은 가득 찬 채로 읽힌다")
    func codable() throws {
        var progress = GameProgress()
        progress.lives.lose(at: start)
        let data = try JSONEncoder().encode(progress)
        let loaded = try JSONDecoder().decode(GameProgress.self, from: data)
        #expect(loaded.lives.count(at: start) == 4)
        let old = try JSONDecoder().decode(GameProgress.self, from: Data(#"{"stars":{},"bestScores":{}}"#.utf8))
        #expect(old.lives.count(at: start) == 5)
    }
}
