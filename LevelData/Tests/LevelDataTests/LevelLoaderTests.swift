import Foundation
import GameCore
import LevelData
import Testing

/// 기획서 9장의 예시.
private let example = """
{
  "id": "seoul-004",
  "city": "seoul",
  "columns": 8,
  "rows": 16,
  "blockTypes": 5,
  "moves": 25,
  "seed": 1004,
  "materials": [
    { "column": 2, "row": 0 },
    { "column": 5, "row": 0, "width": 2, "height": 2 }
  ],
  "pendingMaterials": [
    { "column": 0, "depth": 6 }
  ],
  "obstacles": [
    { "type": "concrete", "column": 2, "row": 9, "hp": 1 },
    { "type": "concrete", "column": 3, "row": 9, "hp": 1 }
  ],
  "starScores": [3000, 6000]
}
"""

private func level(_ change: (inout Level) -> Void = { _ in }) -> Level {
    var level = Level(
        id: "test", city: "seoul", rows: 16, moves: 25, seed: 7,
        materials: [.init(column: 2, row: 0)], starScores: [3000, 6000]
    )
    change(&level)
    return level
}

private func error(_ level: Level) -> LevelError? {
    do {
        try level.validate()
        return nil
    } catch {
        return error
    }
}

@Suite("레벨 JSON 읽기")
struct LevelDecodingTests {
    @Test("기획서의 예시를 읽는다")
    func decodesExample() throws {
        let level = try LevelLoader.load(Data(example.utf8))
        #expect(level.id == "seoul-004")
        #expect(level.city == "seoul")
        #expect(level.columns == 8)
        #expect(level.rows == 16)
        #expect(level.blockTypes == 5)
        #expect(level.moves == 25)
        #expect(level.seed == 1004)
        #expect(level.materials == [
            .init(column: 2, row: 0),
            .init(column: 5, row: 0, width: 2, height: 2),
        ])
        #expect(level.pendingMaterials == [.init(column: 0, depth: 6)])
        #expect(level.obstacles == [
            .init(type: "concrete", column: 2, row: 9, hp: 1),
            .init(type: "concrete", column: 3, row: 9, hp: 1),
        ])
        #expect(level.starScores == [3000, 6000])
    }

    @Test("크기를 생략한 물질은 1×1이고, 대기 물질과 장애물은 생략할 수 있다")
    func optionalFields() throws {
        let json = """
        { "id": "a", "city": "seoul", "columns": 8, "rows": 12, "blockTypes": 4, "moves": 10, "seed": 1,
          "materials": [{ "column": 3, "row": 0 }], "starScores": [1, 2] }
        """
        let level = try LevelLoader.load(Data(json.utf8))
        #expect(level.materials[0].width == 1 && level.materials[0].height == 1)
        #expect(level.pendingMaterials.isEmpty)
        #expect(level.obstacles.isEmpty)
    }

    @Test("필수 항목이 빠지거나 형식이 틀리면 읽지 못한다")
    func malformedJSON() {
        #expect(throws: DecodingError.self) {
            try LevelLoader.load(Data(#"{ "id": "a", "city": "seoul" }"#.utf8))
        }
        #expect(throws: (any Error).self) {
            try LevelLoader.load(Data("not json".utf8))
        }
    }

    @Test("값이 잘못된 JSON은 읽을 때 거부한다")
    func loaderValidates() {
        let invalid = example.replacingOccurrences(of: "\"moves\": 25", with: "\"moves\": 0")
        #expect(throws: LevelError.invalidMoves(0)) {
            try LevelLoader.load(Data(invalid.utf8))
        }
    }

    @Test("저장했다가 다시 읽어도 같다")
    func roundTrips() throws {
        let original = try LevelLoader.load(Data(example.utf8))
        let data = try JSONEncoder().encode(original)
        #expect(try LevelLoader.load(data) == original)
    }
}

@Suite("레벨 검증")
struct LevelValidationTests {
    @Test("올바른 레벨은 통과한다")
    func valid() {
        #expect(error(level()) == nil)
    }

    @Test("가로는 8칸, 세로는 12~40행, 블록 종류는 4~6이어야 한다")
    func sizeLimits() {
        #expect(error(level { $0.columns = 7 }) == .invalidColumns(7))
        #expect(error(level { $0.rows = 11 }) == .invalidRows(11))
        #expect(error(level { $0.rows = 41 }) == .invalidRows(41))
        #expect(error(level { $0.rows = 12 }) == nil)
        #expect(error(level { $0.rows = 40 }) == nil)
        #expect(error(level { $0.blockTypes = 3 }) == .invalidBlockTypes(3))
        #expect(error(level { $0.blockTypes = 7 }) == .invalidBlockTypes(7))
    }

    @Test("이동 횟수는 1 이상이어야 한다")
    func moves() {
        #expect(error(level { $0.moves = 0 }) == .invalidMoves(0))
        #expect(error(level { $0.moves = -3 }) == .invalidMoves(-3))
    }

    @Test("물질은 대기 물질을 합쳐 1~4개여야 한다")
    func materialCount() {
        #expect(error(level { $0.materials = [] }) == .invalidMaterialCount(0))
        #expect(error(level {
            $0.materials = []
            $0.pendingMaterials = [.init(column: 2, depth: 3)]
        }) == nil)
        #expect(error(level {
            $0.materials = (0..<4).map { .init(column: $0, row: 0) }
            $0.pendingMaterials = [.init(column: 7, depth: 3)]
        }) == .invalidMaterialCount(5))
    }

    @Test("보드를 벗어난 좌표를 거부한다")
    func outOfBounds() {
        #expect(error(level { $0.materials = [.init(column: 8, row: 0)] }) == .outOfBounds(column: 8, row: 0))
        #expect(error(level { $0.materials = [.init(column: -1, row: 0)] }) == .outOfBounds(column: -1, row: 0))
        // 큰 물질은 덮는 칸이 모두 보드 안이어야 한다.
        #expect(error(level { $0.materials = [.init(column: 7, row: 0, width: 2, height: 1)] })
            == .outOfBounds(column: 8, row: 0))
        #expect(error(level { $0.obstacles = [.init(type: "sludge", column: 3, row: 16)] })
            == .outOfBounds(column: 3, row: 16))
    }

    @Test("물질은 첫 활성 구간 안에서 시작해야 한다")
    func materialStartZone() {
        #expect(error(level { $0.materials = [.init(column: 2, row: 9)] }) == nil)
        #expect(error(level { $0.materials = [.init(column: 2, row: 10)] })
            == .materialBelowStartZone(column: 2, row: 10))
        #expect(error(level { $0.materials = [.init(column: 2, row: 9, width: 2, height: 2)] })
            == .materialBelowStartZone(column: 2, row: 9))
    }

    @Test("물질의 크기는 1 이상이어야 한다")
    func materialSize() {
        #expect(error(level { $0.materials = [.init(column: 2, row: 0, width: 0, height: 1)] })
            == .invalidMaterialSize(column: 2, row: 0))
    }

    @Test("겹친 칸을 거부한다")
    func overlap() {
        #expect(error(level { $0.materials += [.init(column: 2, row: 0)] }) == .overlap(column: 2, row: 0))
        // 큰 물질이 덮는 칸에 다른 물질이 있다.
        #expect(error(level {
            $0.materials = [.init(column: 2, row: 0, width: 2, height: 2), .init(column: 3, row: 1)]
        }) == .overlap(column: 3, row: 1))
        #expect(error(level { $0.obstacles = [.init(type: "concrete", column: 2, row: 0, hp: 1)] })
            == .overlap(column: 2, row: 0))
        #expect(error(level {
            $0.obstacles = [.init(type: "cage", column: 4, row: 5), .init(type: "sludge", column: 4, row: 5)]
        }) == .overlap(column: 4, row: 5))
    }

    @Test("대기 물질의 열과 깊이를 검사한다")
    func pending() {
        #expect(error(level { $0.pendingMaterials = [.init(column: 8, depth: 2)] })
            == .invalidPending(column: 8, depth: 2))
        #expect(error(level { $0.pendingMaterials = [.init(column: 3, depth: -1)] })
            == .invalidPending(column: 3, depth: -1))
        #expect(error(level { $0.pendingMaterials = [.init(column: 3, depth: 0)] }) == nil)
    }

    @Test("장애물의 종류와 hp를 검사한다")
    func obstacles() {
        #expect(error(level { $0.obstacles = [.init(type: "lava", column: 3, row: 5)] }) == .unknownObstacle("lava"))
        #expect(error(level { $0.obstacles = [.init(type: "concrete", column: 3, row: 5, hp: 3)] }) == .invalidHP(3))
        #expect(error(level { $0.obstacles = [.init(type: "concrete", column: 3, row: 5, hp: 0)] }) == .invalidHP(0))
        // hp를 생략한 콘크리트는 1이다.
        #expect(error(level { $0.obstacles = [.init(type: "concrete", column: 3, row: 5)] }) == nil)
        #expect(error(level { $0.obstacles = [.init(type: "concrete", column: 3, row: 5, hp: 2)] }) == nil)
    }

    @Test("별 점수 기준은 오름차순 3개여야 한다")
    func starScores() {
        #expect(error(level { $0.starScores = [1, 2, 3] }) == .invalidStarScores)
        #expect(error(level { $0.starScores = [2, 1] }) == .invalidStarScores)
        #expect(error(level { $0.starScores = [2, 2] }) == .invalidStarScores)
        #expect(error(level { $0.starScores = [0, 1] }) == .invalidStarScores)
    }
}

@Suite("레벨에서 판 만들기")
struct LevelStateTests {
    @Test("레벨의 값이 시작 상태에 그대로 들어간다")
    func makeState() throws {
        let level = try LevelLoader.load(Data(example.utf8))
        let state = try level.makeState()
        #expect(state.board.columns == 8)
        #expect(state.board.rows == 16)
        #expect(state.blockTypes == 5)
        #expect(state.movesRemaining == 25)
        #expect(state.materialsTotal == 3)
        #expect(state.materials == [
            MaterialPiece(origin: Position(column: 2, row: 0)),
            MaterialPiece(origin: Position(column: 5, row: 0), width: 2, height: 2),
        ])
        #expect(state.pendingMaterials == [PendingMaterial(column: 0, depth: 6)])
        #expect(state.board[2, 9] == .concrete(hp: 1))
        #expect(state.board[3, 9] == .concrete(hp: 1))
        #expect(state.status == .playing)
        // 흘러내림은 모든 레벨에 켜져 있다.
        #expect(state.blocksSlide)
    }

    @Test("장애물 종류가 맞게 놓인다")
    func obstacleKinds() throws {
        let state = try level {
            $0.obstacles = [
                .init(type: "concrete", column: 0, row: 5, hp: 2),
                .init(type: "concrete", column: 1, row: 5),
                .init(type: "cage", column: 2, row: 5),
                .init(type: "sludge", column: 3, row: 5),
            ]
        }.makeState()
        #expect(state.board[0, 5] == .concrete(hp: 2))
        #expect(state.board[1, 5] == .concrete(hp: 1))
        #expect(state.board[3, 5] == .sludge)
        if case .caged = state.board[2, 5] {} else {
            Issue.record("철망이 없다: \(String(describing: state.board[2, 5]))")
        }
    }

    @Test("같은 레벨은 항상 같은 보드로 시작한다")
    func sameLevelSameBoard() throws {
        let level = try LevelLoader.load(Data(example.utf8))
        #expect(try level.makeState() == level.makeState())
        var other = level
        other.seed = 1005
        #expect(try other.makeState().board != level.makeState().board)
    }

    @Test("시작 보드에는 매치가 없고 첫 활성 구간에 가능한 이동이 있다")
    func startsStable() throws {
        let state = try LevelLoader.load(Data(example.utf8)).makeState()
        #expect(state.board.findMatches().isEmpty)
        #expect(!state.possibleMoves().isEmpty)
    }

    @Test("클리어하면 별 1개이고, 기준 점수를 넘길 때마다 하나씩 는다")
    func stars() {
        let level = level { $0.starScores = [3000, 6000] }
        #expect(level.stars(forScore: 0) == 1)
        #expect(level.stars(forScore: 2999) == 1)
        #expect(level.stars(forScore: 3000) == 2)
        #expect(level.stars(forScore: 5999) == 2)
        #expect(level.stars(forScore: 6000) == 3)
        #expect(level.stars(forScore: 50000) == 3)
    }

    @Test("잘못된 레벨로는 판을 만들지 않는다")
    func invalidLevelThrows() {
        #expect(throws: LevelError.invalidMoves(0)) {
            try level { $0.moves = 0 }.makeState()
        }
    }
}
