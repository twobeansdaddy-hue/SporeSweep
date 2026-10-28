import Foundation
import Testing
@testable import Progress

struct CloudGateTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func played() -> GameProgress {
        var progress = GameProgress()
        progress.recordClear(levelID: "seoul-001", stars: 3, score: 1200)
        progress.recordClear(levelID: "seoul-002", stars: 2, score: 900)
        progress.restore(partID: "gate", in: "seoul")
        progress.addBooster("bomb", count: 4)
        return progress
    }

    @Test("새로 설치한 기기는 iCloud의 진행을 보기 전에 올리지 않는다")
    func freshInstallWaits() {
        var fresh = GameProgress()
        fresh.addBooster("bomb")  // 시작 아이템을 받아도 빈 진행이다.
        let gate = CloudGate(local: fresh, now: start)
        #expect(!gate.isOpen)
        #expect(gate.upload(fresh, cloud: nil) == nil)
    }

    @Test("다시 설치한 기기는 iCloud의 진행을 받고, 그보다 적은 것을 올리지 않는다")
    func reinstallKeepsCloud() {
        let cloud = played()
        var fresh = GameProgress()
        fresh.addBooster("bomb")
        var gate = CloudGate(local: fresh, now: start)
        gate.cloudSeen()
        // 이 기기에만 있는 것이 없으니 올릴 것이 없다.
        #expect(gate.upload(fresh, cloud: cloud) == nil)
        // 앱이 합친 진행(iCloud의 별·복원·아이템)을 갖게 된다.
        let merged = fresh.merging(cloud)
        #expect(merged.stars(for: "seoul-001") == 3)
        #expect(merged.restoredParts(in: "seoul") == ["gate"])
        #expect(merged.boosterCount("bomb") == 4)
    }

    @Test("소식이 없으면 기다릴 만큼 기다린 뒤 연다")
    func opensAfterWait() {
        var gate = CloudGate(local: GameProgress(), now: start)
        gate.tick(now: start.addingTimeInterval(CloudGate.maxWait - 1))
        #expect(!gate.isOpen)
        gate.tick(now: start.addingTimeInterval(CloudGate.maxWait))
        #expect(gate.isOpen)
    }

    @Test("이미 기록이 있는 기기는 바로 올리고, iCloud에만 있는 기록도 남긴다")
    func existingDeviceOpens() throws {
        var here = GameProgress()
        here.recordClear(levelID: "seoul-003", stars: 1, score: 300)
        let gate = CloudGate(local: here, now: start)
        #expect(gate.isOpen)
        let upload = try #require(gate.upload(here, cloud: played()))
        #expect(upload.stars(for: "seoul-001") == 3)
        #expect(upload.stars(for: "seoul-003") == 1)
    }

    @Test("iCloud가 이 기기보다 뒤진 진행을 남기면 다시 올리고, 이미 같으면 올리지 않는다")
    func reuploadsWhenCloudIsBehind() throws {
        let here = played()
        var behind = GameProgress()
        behind.recordClear(levelID: "seoul-001", stars: 1, score: 100)
        let gate = CloudGate(local: here, now: start)
        let upload = try #require(gate.upload(here, cloud: behind))
        #expect(upload.stars(for: "seoul-001") == 3)
        #expect(upload.stars(for: "seoul-002") == 2)
        #expect(gate.upload(here, cloud: upload) == nil)
    }

    @Test("두 기기의 생명력이나 일일 보상만 다르면 서로 다시 올리지 않는다")
    func deviceStateDoesNotPingPong() {
        let shared = played()
        var here = shared
        here.lives.set(1, at: start)
        let gate = CloudGate(local: here, now: start)
        #expect(gate.upload(here, cloud: shared) == nil)
    }

    @Test("깬 레벨 수가 같으면 어느 쪽에서 합쳐도 같은 아이템이 남는다")
    func boosterTieConverges() {
        var a = GameProgress()
        a.recordClear(levelID: "seoul-001", stars: 2, score: 100)
        a.addBooster("bomb", count: 1)
        var b = GameProgress()
        b.recordClear(levelID: "seoul-002", stars: 2, score: 100)
        b.addBooster("beam", count: 3)
        #expect(a.merging(b).boosterCount("beam") == 3)
        #expect(b.merging(a).boosterCount("beam") == 3)
        #expect(a.merging(b).boosterCount("bomb") == 0)
        // 한 번 합친 뒤에는 어느 기기도 더 올릴 것이 없다.
        let cloud = a.merging(b)
        let gate = CloudGate(local: a, now: start)
        #expect(gate.upload(a.merging(cloud), cloud: cloud) == nil)
        #expect(gate.upload(b.merging(cloud), cloud: cloud) == nil)
    }

    @Test("레벨을 하나도 깨지 않은 채 다시 설치해도 iCloud의 아이템을 잃지 않는다")
    func zeroClearReinstallKeepsItems() {
        var cloud = GameProgress()
        cloud.addBooster("bomb", count: 2)
        let fresh = GameProgress()
        var gate = CloudGate(local: fresh, now: start)
        gate.cloudSeen()
        #expect(gate.upload(fresh, cloud: cloud) == nil)
        #expect(fresh.merging(cloud).boosterCount("bomb") == 2)
    }

    @Test("같은 레벨 수에서 쓴 아이템은 iCloud의 예전 개수로 되살아나지 않는다")
    func usedItemsDoNotComeBack() throws {
        let cloud = played()
        var here = cloud
        let used = here.useBooster("bomb")
        #expect(used)
        #expect(here.merging(cloud).boosterCount("bomb") == 3)
        #expect(cloud.merging(here).boosterCount("bomb") == 3)
        let upload = try #require(CloudGate(local: here, now: start).upload(here, cloud: cloud))
        #expect(upload.boosterCount("bomb") == 3)
    }

    @Test("부스터 변경 횟수는 저장했다 읽어도 남고, 예전 파일은 0이다")
    func stampSurvivesCoding() throws {
        let progress = played()
        let decoded = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(progress))
        #expect(decoded.boosterStamp == progress.boosterStamp)
        let old = try JSONDecoder().decode(GameProgress.self, from: Data(#"{"stars":{},"bestScores":{}}"#.utf8))
        #expect(old.boosterStamp == 0)
    }

    @Test("시작 아이템은 예전 iCloud 기록(변경 횟수 0)의 아이템을 덮어쓰지 않는다")
    func starterToolsDoNotOverwriteLegacyCloud() throws {
        let legacy = try JSONDecoder().decode(GameProgress.self, from: Data(#"{"stars":{"seoul-001":3},"bestScores":{},"boosters":{"tool_hammer":9}}"#.utf8))
        var fresh = GameProgress()
        fresh.addBooster("tool_hammer", changesStamp: false)
        #expect(fresh.merging(legacy).boosterCount("tool_hammer") == 9)
        #expect(legacy.merging(fresh).boosterCount("tool_hammer") == 9)
    }
}
