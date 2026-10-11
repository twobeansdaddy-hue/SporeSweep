import GameCore
import Testing
@testable import LevelData
import LevelTools

@Suite("시험판 레벨")
struct LabLevelsTests {
    let levels = (try? LevelCatalog.lab()) ?? []

    @Test("세 개가 있고 모두 벽과 흘러가는 물질을 쓰며, 수거함은 보드 폭 전체다")
    func catalog() throws {
        #expect(levels.map(\.id) == ["lab-001", "lab-002", "lab-003"])
        for level in levels {
            #expect(level.container == nil)
            #expect(level.materialsSlide)
            #expect(level.obstacles.contains { $0.type == "wall" })
            let state = try level.makeState()
            #expect(state.containerColumns == nil)
            #expect(state.materialsSlide)
            // 맨 아래 행에는 벽이 없어서 어느 열로 내려와도 수거된다.
            #expect((0..<level.columns).allSatisfy { state.board[$0, level.rows - 1] != .wall })
        }
    }

    @Test("벽 아래에 블록이 들어올 수 없는 그늘이 있으면 거부한다")
    func rejectsUnreachableCells() throws {
        // 0~5열을 가로지르는 평평한 벽 한 줄. 그 바로 아래는 오른쪽 끝에서만 채워진다.
        var level = try #require(levels.first)
        level.obstacles = (0...5).map { .init(type: "wall", column: $0, row: 6) }
        #expect(throws: LevelError.unreachableCell(column: 0, row: 7)) { try level.validate() }
        // 밑면을 비스듬히 채우면 통과한다.
        for depth in 1...5 {
            level.obstacles += (0...(5 - depth)).map { .init(type: "wall", column: $0, row: 6 + depth) }
        }
        try level.validate()
    }

    @Test("서울의 레벨에는 섞이지 않는다")
    func separateFromSeoul() throws {
        #expect(try LevelCatalog.seoul().count == 12)
        #expect(try LevelCatalog.seoul().allSatisfy { $0.container == nil })
    }

    @Test("좁은 수거함을 쓰려면 물질이 흘러가야 하고, 큰 물질과 뚫린 바닥은 허용하지 않는다")
    func narrowContainerValidation() throws {
        // 좁은 수거함은 지금 쓰지 않지만 레벨 형식은 받는다. 맨 아래 행의 수거함 밖을 벽으로 막은 레벨을 만든다.
        var level = try #require(levels.first)
        level.container = .init(from: 3, to: 4)
        #expect(throws: LevelError.openFloorOutsideContainer(column: 0)) { try level.validate() }
        level.obstacles += [0, 1, 2, 5, 6, 7].map { .init(type: "wall", column: $0, row: level.rows - 1) }
        try level.validate()
        #expect(try level.makeState().containerColumns == 3...4)
        level.materialsSlide = false
        #expect(throws: LevelError.narrowContainerNeedsFlowingMaterials) { try level.validate() }
        level.materialsSlide = true
        level.materials[0].width = 2
        #expect(throws: LevelError.narrowContainerNeedsFlowingMaterials) { try level.validate() }
        level.materials[0].width = 1
        level.container = .init(from: 5, to: 9)
        #expect(throws: LevelError.invalidContainer) { try level.validate() }
    }

    @Test("봇이 정해진 이동 횟수 안에 클리어할 수 있다", arguments: 0..<3)
    func clearable(index: Int) throws {
        let level = try #require(levels.indices.contains(index) ? levels[index] : nil)
        let state = try level.makeState()
        var cleared = false
        for policySeed in 0..<30 as Range<UInt64> where !cleared {
            cleared = Solver.playout(state, policySeed: policySeed) != nil
        }
        #expect(cleared, "\(level.id): 30번 시도에 클리어하지 못했다")
    }
}
