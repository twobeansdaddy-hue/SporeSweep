import GameCore
import Testing
@testable import LevelData
import LevelTools

@Suite("레벨 생성기")
struct LevelGeneratorTests {
    /// 빨리 끝나도록 적은 판 수로 잰다.
    func options(_ features: Set<LevelGenerator.Feature> = Set(LevelGenerator.Feature.allCases)) -> LevelGenerator.Options {
        LevelGenerator.Options(city: "test", count: 4, difficulty: 0.2...0.6, features: features, seed: 3, playouts: 30)
    }

    @Test("개수만큼 만들고, 모두 검증을 통과하며, 번호가 이어진다")
    func makesValidLevels() throws {
        var options = options()
        options.firstNumber = 5
        let results = LevelGenerator.generate(options)
        #expect(results.map(\.level.id) == ["test-005", "test-006", "test-007", "test-008"])
        for result in results {
            try result.level.validate()
            _ = try result.level.makeState()
            #expect(result.level.city == "test")
            #expect(Calibration.moveRange.contains(result.level.moves))
            #expect(result.level.moves % 5 == 0)
            #expect(result.level.starScores.allSatisfy { $0 % 100 == 0 })
            #expect(result.level.moves == result.calibration.moves)
        }
    }

    @Test("같은 설정은 같은 레벨을 만든다")
    func deterministic() {
        #expect(LevelGenerator.generate(options()).map(\.level) == LevelGenerator.generate(options()).map(\.level))
    }

    @Test("시드가 다르면 다른 레벨을 만든다")
    func seedMatters() {
        var other = options()
        other.seed = 4
        #expect(LevelGenerator.generate(options()).map(\.level) != LevelGenerator.generate(other).map(\.level))
    }

    @Test("풀어 준 요소만 쓴다")
    func respectsFeatures() {
        for result in LevelGenerator.generate(options([])) {
            #expect(result.level.obstacles.isEmpty)
            #expect(result.level.pendingMaterials.isEmpty)
            #expect(result.level.materials.allSatisfy { $0.width == 1 && $0.height == 1 })
        }
        for result in LevelGenerator.generate(options([.concrete, .cage])) {
            #expect(result.level.obstacles.allSatisfy { ["concrete", "cage"].contains($0.type) })
            #expect(result.level.obstacles.allSatisfy { ($0.hp ?? 1) == 1 })
        }
    }

    @Test("새 장애물을 정하면 첫 레벨에 나오고, 처음 나오는 레벨에 설명이 붙는다")
    func spotlight() {
        var options = options()
        options.spotlight = "cocoon"
        options.tutorials = ["cocoon": "오염 고치 설명"]
        let levels = LevelGenerator.generate(options).map(\.level)
        #expect(levels[0].obstacles.contains { $0.type == "cocoon" })
        #expect(levels[0].tutorial == "오염 고치 설명")
        #expect(levels.dropFirst().allSatisfy { $0.tutorial == nil })
        // 풀어 주지 않으면 나오지 않는다.
        options.features.remove(.cocoon)
        #expect(LevelGenerator.generate(options).allSatisfy { !$0.level.obstacles.contains { $0.type == "cocoon" } })
    }

    @Test("큰 물질이 있는 판에는 벽을 놓지 않고 블록을 4종으로 한다")
    func largeMaterialRules() {
        var options = options()
        options.count = 12
        let large = LevelGenerator.generate(options).map(\.level).filter { $0.materials.contains { $0.width > 1 } }
        #expect(!large.isEmpty)
        for level in large {
            #expect(level.blockTypes == 4)
            #expect(!level.obstacles.contains { $0.type == "wall" })
        }
    }

    @Test("다섯 레벨마다 부스터를 주고 마지막 레벨은 네 가지를 준다")
    func rewards() {
        var options = options([])
        options.count = 6
        let levels = LevelGenerator.generate(options).map(\.level)
        #expect(levels[4].rewards.count == 1)
        #expect(Set(levels[5].rewards) == Set(Booster.allCases))
        #expect(levels[0].rewards.isEmpty)
    }

    @Test("잰 결과는 봇이 실제로 그 이동 횟수 안에 깨는 비율과 맞는다")
    func calibrationMatchesPlayouts() throws {
        let level = try #require(try LevelCatalog.seoul().first)
        let calibration = try #require(Calibration.measure(level, playouts: 60))
        #expect(calibration.clearRate > 0.6)
        #expect(calibration.starScores[0] < calibration.starScores[1])
        // 같은 레벨을 다시 재면 같은 값이 나온다.
        #expect(Calibration.measure(level, playouts: 60) == calibration)
    }

    @Test("생성기로 만든 견본 레벨 16개가 앱에 들어 있고 모두 받아들일 만하다")
    func samples() throws {
        let samples = try LevelCatalog.samples()
        #expect(samples.count == 16)
        #expect(samples.map(\.id) == (1...16).map { String(format: "sample-%03d", $0) })
        for level in samples {
            try level.validate()
            #expect(Calibration.moveRange.contains(level.moves))
        }
        // 뒤로 갈수록 보드가 길어진다.
        #expect(samples.last!.rows > samples.first!.rows)
    }
}
