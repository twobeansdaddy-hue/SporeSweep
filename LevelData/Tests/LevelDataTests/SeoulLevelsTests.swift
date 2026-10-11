import GameCore
import LevelTools
import LevelData
import Testing

@Suite("서울 레벨 12개")
struct SeoulLevelsTests {
    let levels: [Level]

    init() throws {
        levels = try LevelCatalog.seoul()
    }

    private func types(_ level: Level) -> Set<String> {
        Set(level.obstacles.map(\.type))
    }

    @Test("12개가 번호 순서로 들어 있다")
    func catalog() {
        #expect(levels.count == 12)
        #expect(levels.map(\.id) == (1...12).map { "seoul-" + String(format: "%03d", $0) })
        #expect(levels.allSatisfy { $0.city == "seoul" })
    }

    @Test("모두 검증을 통과하고 판을 만들 수 있다")
    func allValid() throws {
        for level in levels {
            try level.validate()
            let state = try level.makeState()
            #expect(state.board.findMatches().isEmpty, "\(level.id)")
            #expect(!state.possibleMoves().isEmpty, "\(level.id)")
            #expect(state.movesRemaining == level.moves)
            #expect(state.blocksSlide)
        }
    }

    @Test("레벨 1~3에는 장애물이 없다")
    func firstThreeHaveNoObstacles() {
        for level in levels.prefix(3) {
            #expect(level.obstacles.isEmpty, "\(level.id)")
            #expect(level.materials.allSatisfy { $0.width == 1 && $0.height == 1 }, "\(level.id)")
            #expect(level.pendingMaterials.isEmpty, "\(level.id)")
        }
    }

    @Test("장애물은 기획서의 도입 레벨부터 나온다")
    func obstacleIntroduction() {
        for (index, level) in levels.enumerated() {
            let number = index + 1
            if number < 4 { #expect(!types(level).contains("concrete"), "\(level.id)") }
            if number < 8 { #expect(!types(level).contains("cage"), "\(level.id)") }
            if number < 12 { #expect(!types(level).contains("sludge"), "\(level.id)") }
            if number < 9 { #expect(!types(level).contains("wall"), "\(level.id)") }
            // 물질이 흘러가는 것은 모든 레벨의 기본 규칙이다.
            #expect(level.materialsSlide, "\(level.id)")
        }
        #expect(types(levels[3]).contains("concrete"))
        #expect(types(levels[7]).contains("cage"))
        #expect(types(levels[8]).contains("wall"))
        #expect(types(levels[10]).contains("wall"))
        #expect(types(levels[11]).contains("sludge"))
    }

    @Test("대기 물질과 큰 물질을 쓰는 레벨이 있다")
    func usesNewMaterialKinds() {
        #expect(levels.contains { !$0.pendingMaterials.isEmpty })
        #expect(levels.contains { $0.materials.contains { $0.width == 2 && $0.height == 1 } })
        #expect(levels.contains { $0.materials.contains { $0.width == 2 && $0.height == 2 } })
    }

    @Test("별 기준은 100점 단위이고, 평범한 봇이 별 2개와 별 3개를 모두 받을 수 있다")
    func starScoresAreReachable() throws {
        for level in levels {
            #expect(level.starScores.count == 2)
            #expect(level.starScores.allSatisfy { $0 % 100 == 0 }, "\(level.id): \(level.starScores)")
            let state = try level.makeState()
            var seen: Set<Int> = []
            for policySeed in 0..<80 as Range<UInt64> {
                let end = Solver.casual(state, policySeed: policySeed, greed: 0.5).state
                if end.status == .won {
                    seen.insert(level.stars(forScore: end.score))
                }
                if seen.isSuperset(of: [2, 3]) { break }
            }
            #expect(seen.isSuperset(of: [2, 3]), "\(level.id): 봇이 받은 별 \(seen.sorted())")
        }
    }

    @Test("이동 횟수는 5 단위이고 15수에서 60수 사이다")
    func moveLimits() {
        for level in levels {
            #expect(level.moves % 5 == 0, "\(level.id): \(level.moves)")
            #expect((15...60).contains(level.moves), "\(level.id): \(level.moves)")
        }
    }

    @Test("새 규칙이 나오는 레벨에는 설명이 있다")
    func tutorials() {
        // 조작, 여러 물질, 특수 블록, 콘크리트, 아이템, 대기 물질, 2×1, 철망, 벽, 2×2, 슬러지.
        for number in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12] {
            let text = levels[number - 1].tutorial
            #expect(text != nil, "레벨 \(number)")
            #expect((text ?? "").count >= 20, "레벨 \(number)")
        }
        for number in [11] {
            #expect(levels[number - 1].tutorial == nil, "레벨 \(number)")
        }
        #expect(levels[3].tutorial?.contains("콘크리트") == true)
        #expect(levels[4].tutorial?.contains("아이템") == true)
        #expect(levels[7].tutorial?.contains("철망") == true)
        #expect(levels[8].tutorial?.contains("벽") == true)
        #expect(levels[11].tutorial?.contains("슬러지") == true)
    }

    @Test("몇몇 레벨은 처음 클리어하면 시작 부스터를 주고, 마지막 레벨은 네 가지를 모두 준다")
    func rewards() {
        let rewarded = levels.enumerated().filter { !$0.element.rewards.isEmpty }.map { $0.offset + 1 }
        #expect(rewarded == [3, 5, 7, 9, 10, 12])
        #expect(Set(levels[11].rewards) == Set(Booster.allCases))
        // 특수 블록을 배우는 레벨 3에서 처음 받는다.
        #expect(levels[2].rewards == [.beam, .bomb])
    }

    @Test("시드가 서로 다르다")
    func distinctSeeds() {
        #expect(Set(levels.map(\.seed)).count == levels.count)
    }

    /// 봇을 서로 다른 경로로 여러 번 돌려, 정해진 이동 횟수 안에 클리어하는 경로가 있는지 본다.
    @Test("모든 레벨을 정해진 이동 횟수 안에 클리어할 수 있다", arguments: 0..<12)
    func clearable(index: Int) throws {
        let level = levels[index]
        let state = try level.makeState()
        var best: Int?
        for policySeed in 0..<24 as Range<UInt64> {
            if let turns = Solver.playout(state, policySeed: policySeed) {
                best = min(best ?? turns, turns)
                break
            }
        }
        #expect(best != nil, "\(level.id): 24번 시도에 클리어하지 못했다")
        if let best {
            #expect(best <= level.moves)
        }
    }
}
