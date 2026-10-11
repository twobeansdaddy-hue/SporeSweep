import Foundation
import Testing
@testable import Progress

private let levels = (1...12).map { "seoul-" + String(format: "%03d", $0) }

@Suite("진행 상황")
struct GameProgressTests {
    @Test("부스터를 받고 쓰면 개수가 바뀌고, 없는 것은 쓸 수 없다")
    func boosters() {
        var progress = GameProgress()
        #expect(progress.boosterCount("bomb") == 0)
        let usedNothing = progress.useBooster("bomb")
        #expect(!usedNothing)
        progress.addBooster("bomb")
        progress.addBooster("bomb", count: 2)
        progress.addBooster("beam", count: 0)
        #expect(progress.boosterCount("bomb") == 3)
        #expect(progress.boosterCount("beam") == 0)
        let used = progress.useBooster("bomb")
        #expect(used)
        #expect(progress.boosterCount("bomb") == 2)
    }

    @Test("부스터가 생기기 전에 저장한 파일도 읽고, 부스터는 저장했다 읽어도 그대로다")
    func boostersPersist() throws {
        let old = #"{"stars":{"seoul-001":2},"bestScores":{"seoul-001":900}}"#
        let decoded = try JSONDecoder().decode(GameProgress.self, from: Data(old.utf8))
        #expect(decoded.boosterCount("bomb") == 0)
        #expect(decoded.stars(for: "seoul-001") == 2)
        var progress = GameProgress()
        progress.addBooster("core", count: 2)
        let again = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(progress))
        #expect(again == progress)
        #expect(again.boosterCount("core") == 2)
    }

    @Test("처음에는 아무 레벨도 클리어하지 않았다")
    func empty() {
        let progress = GameProgress()
        #expect(progress.stars(for: "seoul-001") == 0)
        #expect(progress.bestScore(for: "seoul-001") == 0)
        #expect(!progress.isCleared("seoul-001"))
        #expect(progress.clearedCount(in: levels) == 0)
        #expect(progress.totalStars(in: levels) == 0)
    }

    @Test("클리어하면 별과 점수가 기록된다")
    func recordClear() {
        var progress = GameProgress()
        let changed1 = progress.recordClear(levelID: "seoul-001", stars: 2, score: 9000)
        #expect(changed1)
        #expect(progress.stars(for: "seoul-001") == 2)
        #expect(progress.bestScore(for: "seoul-001") == 9000)
        #expect(progress.isCleared("seoul-001"))
        #expect(progress.clearedCount(in: levels) == 1)
    }

    @Test("별과 점수는 각각 더 높은 쪽만 남는다")
    func keepsBest() {
        var progress = GameProgress()
        progress.recordClear(levelID: "seoul-001", stars: 2, score: 9000)
        // 별은 낮고 점수는 높은 판.
        let changed2 = progress.recordClear(levelID: "seoul-001", stars: 1, score: 9500)
        #expect(changed2)
        #expect(progress.stars(for: "seoul-001") == 2)
        #expect(progress.bestScore(for: "seoul-001") == 9500)
        // 둘 다 낮으면 바뀌지 않는다.
        let changed3 = progress.recordClear(levelID: "seoul-001", stars: 1, score: 100)
        #expect(!changed3)
        let changed4 = progress.recordClear(levelID: "seoul-001", stars: 3, score: 100)
        #expect(changed4)
        #expect(progress.stars(for: "seoul-001") == 3)
        #expect(progress.bestScore(for: "seoul-001") == 9500)
    }

    @Test("별은 1~3개로 제한한다")
    func clampsStars() {
        var progress = GameProgress()
        progress.recordClear(levelID: "a", stars: 0, score: 10)
        progress.recordClear(levelID: "b", stars: 7, score: 10)
        #expect(progress.stars(for: "a") == 1)
        #expect(progress.stars(for: "b") == 3)
    }

    @Test("첫 레벨은 열려 있고, 나머지는 앞 레벨을 클리어해야 열린다")
    func unlocking() {
        var progress = GameProgress()
        #expect(progress.isUnlocked(index: 0, in: levels))
        #expect(!progress.isUnlocked(index: 1, in: levels))
        progress.recordClear(levelID: levels[0], stars: 1, score: 1)
        #expect(progress.isUnlocked(index: 1, in: levels))
        #expect(!progress.isUnlocked(index: 2, in: levels))
        #expect(!progress.isUnlocked(index: 12, in: levels))
        #expect(!progress.isUnlocked(index: -1, in: levels))
    }

    @Test("별의 합을 센다")
    func totalStars() {
        var progress = GameProgress()
        progress.recordClear(levelID: levels[0], stars: 3, score: 1)
        progress.recordClear(levelID: levels[1], stars: 2, score: 1)
        progress.recordClear(levelID: "other-001", stars: 3, score: 1)
        #expect(progress.totalStars(in: levels) == 5)
        #expect(progress.clearedCount(in: levels) == 2)
    }
}

@Suite("복원 기록")
struct RestoredPartsTests {
    @Test("처음에는 복원한 부위가 없다")
    func empty() {
        #expect(GameProgress().restoredParts(in: "seoul").isEmpty)
    }

    @Test("복원한 부위를 도시별로 기록한다")
    func restore() {
        var progress = GameProgress()
        let first = progress.restore(partID: "gate", in: "seoul")
        let second = progress.restore(partID: "wallLeft", in: "seoul")
        let other = progress.restore(partID: "gate", in: "busan")
        #expect(first && second && other)
        #expect(progress.restoredParts(in: "seoul") == ["gate", "wallLeft"])
        #expect(progress.restoredParts(in: "busan") == ["gate"])
    }

    @Test("같은 부위를 두 번 복원해도 한 번만 기록된다")
    func restoreTwice() {
        var progress = GameProgress()
        progress.restore(partID: "gate", in: "seoul")
        let again = progress.restore(partID: "gate", in: "seoul")
        #expect(!again)
        #expect(progress.restoredParts(in: "seoul").count == 1)
    }

    @Test("복원 기록이 없는 예전 저장 파일도 읽는다")
    func decodesOldFile() throws {
        let old = #"{ "stars": { "seoul-001": 2 }, "bestScores": { "seoul-001": 9000 } }"#
        let progress = try JSONDecoder().decode(GameProgress.self, from: Data(old.utf8))
        #expect(progress.stars(for: "seoul-001") == 2)
        #expect(progress.restoredParts(in: "seoul").isEmpty)
    }
}

@Suite("진행 저장")
struct ProgressStoreTests {
    func temporaryStore() -> ProgressStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProgressTests-\(UUID().uuidString)")
        return ProgressStore(url: directory.appendingPathComponent("nested/progress.json"))
    }

    @Test("파일이 없으면 빈 진행 상황이다")
    func missingFile() throws {
        #expect(try temporaryStore().load() == GameProgress())
    }

    @Test("저장한 뒤 새로 읽어도 같다")
    func roundTrip() throws {
        let store = temporaryStore()
        var progress = GameProgress()
        progress.recordClear(levelID: "seoul-001", stars: 3, score: 12000)
        progress.recordClear(levelID: "seoul-002", stars: 1, score: 4000)
        progress.restore(partID: "gate", in: "seoul")
        try store.save(progress)

        // 앱을 껐다 켠 것처럼 같은 파일을 가리키는 새 저장소로 읽는다.
        let reopened = ProgressStore(url: store.url)
        let loaded = try reopened.load()
        #expect(loaded == progress)
        #expect(loaded.totalStars(in: levels) == 4)
        #expect(loaded.restoredParts(in: "seoul") == ["gate"])
        #expect(loaded.isUnlocked(index: 2, in: levels))
    }

    @Test("다시 저장하면 덮어쓴다")
    func overwrite() throws {
        let store = temporaryStore()
        var progress = GameProgress()
        progress.recordClear(levelID: "seoul-001", stars: 1, score: 100)
        try store.save(progress)
        progress.recordClear(levelID: "seoul-001", stars: 3, score: 900)
        try store.save(progress)
        #expect(try store.load().stars(for: "seoul-001") == 3)
    }

    @Test("깨진 파일은 빈 진행으로 바꾸지 않고 오류를 낸다")
    func corruptFile() throws {
        let store = temporaryStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ broken".utf8).write(to: store.url)
        #expect(throws: (any Error).self) {
            try store.load()
        }
        // 파일은 그대로 남아 있다.
        #expect(FileManager.default.fileExists(atPath: store.url.path))
    }

    @Test("초기화하면 파일이 없어진다")
    func reset() throws {
        let store = temporaryStore()
        var progress = GameProgress()
        progress.recordClear(levelID: "seoul-001", stars: 2, score: 100)
        try store.save(progress)
        try store.reset()
        #expect(try store.load() == GameProgress())
        try store.reset()
    }

    @Test("기본 저장 파일은 Application Support에 있다")
    func standardLocation() {
        #expect(ProgressStore.standard().url.lastPathComponent == "progress.json")
        #expect(ProgressStore.standard().url.path.contains("Application Support"))
    }
}
