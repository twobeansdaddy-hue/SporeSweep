import Testing
@testable import GameCore

/// 스왑 직후의 이벤트만 본다. 뒤따르는 보충은 무작위라 검사하지 않는다.
private func turn(_ board: Board, _ swap: Swap) -> [GameEvent] {
    GameState(board: board).performTurn(swap).events
}

/// 이벤트 가운데 첫 특수 효과 발동들.
private func activations(_ events: [GameEvent]) -> [SpecialActivation] {
    events.compactMap(\.activations).first ?? []
}

@Suite("2×2 매치")
struct SquareMatchTests {
    @Test("같은 종류 2×2는 매치다")
    func squareIsAMatch() {
        let board = Board.deadlocked.setting(.soil, at: [(3, 4), (4, 4), (3, 5), (4, 5)])
        let matches = board.findMatches()
        #expect(matches.map(\.shape) == [.square])
        #expect(matches[0].positions == [pos(3, 4), pos(4, 4), pos(3, 5), pos(4, 5)])
        #expect(matches[0].createdSpecial == .drone)
    }

    @Test("2×2를 만드는 스왑은 받아들인다")
    func swapMakingSquareIsValid() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (0, 9), (2, 9)])
        #expect(board.rejection(for: swap((2, 9), (1, 9))) == nil)
    }

    @Test("2×2를 맞추면 움직인 자리에 청소 드론이 생긴다")
    func squareCreatesDrone() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (0, 9), (2, 9)])
        let events = turn(board, swap((2, 9), (1, 9)))
        #expect(events[1].clearedMatches?.map(\.shape) == [.square])
        #expect(events[2] == .specialsCreated([SpecialSpawn(position: pos(1, 9), block: .drone)]))
    }

    @Test("2×3 덩어리는 3개짜리 두 줄이 아니라 드론 하나를 남긴다")
    func twoByThreeCreatesOneDrone() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (2, 8), (0, 9), (1, 9), (3, 9)])
        let events = turn(board, swap((3, 9), (2, 9)))
        #expect(events[1].clearedMatches?.count == 1)
        #expect(events[1].clearedMatches?[0].positions.count == 6)
        #expect(events[2] == .specialsCreated([SpecialSpawn(position: pos(2, 9), block: .drone)]))
    }

    @Test("4개 일렬이 2×2를 품으면 제염 빔이 앞선다")
    func fourLineBeatsSquare() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (2, 8), (3, 8), (0, 9), (1, 9)])
        #expect(board.findMatches().map(\.createdSpecial) == [.beam(.horizontal)])
    }

    @Test("L 모양이 2×2를 품으면 중화 폭탄이 앞선다")
    func lShapeBeatsSquare() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 7), (0, 8), (0, 9), (1, 9), (2, 9), (1, 8)])
        #expect(board.findMatches().map(\.createdSpecial) == [.bomb])
    }

    @Test("5개 일렬이 2×2를 품으면 정화 코어가 앞선다")
    func fiveLineBeatsSquare() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (2, 9), (3, 9), (4, 9), (0, 8), (1, 8)])
        #expect(board.findMatches().map(\.createdSpecial) == [.core])
    }

    @Test("새로 만든 보드에는 2×2가 미리 놓여 있지 않다")
    func newBoardsHaveNoSquares() {
        for seed in UInt64(1)...300 {
            let state = GameState(seed: seed, rows: 16, blockTypes: 4)
            #expect(state.board.findMatches(in: 0..<16).isEmpty, "시드 \(seed)")
        }
    }
}

@Suite("청소 드론")
struct DroneTests {
    @Test("일반 블록과 스왑하면 옮겨 간 자리와 상하좌우를 지우고 물질 바로 아래 칸을 맞힌다")
    func hitsBelowMaterial() {
        let board = Board.deadlocked.placing(.drone, at: (1, 9)).placing(.material, at: (5, 3))
        let events = turn(board, swap((1, 9), (2, 9)))
        let fired = activations(events)
        #expect(fired.first?.origin == pos(2, 9))
        #expect(fired.first?.effect == .drone(pos(5, 4)))
        let cleared = Set(fired.flatMap(\.cleared))
        #expect(cleared.isSuperset(of: [pos(2, 9), pos(1, 9), pos(3, 9), pos(2, 8), pos(5, 4)]))
        #expect(!cleared.contains(pos(5, 3)))
    }

    @Test("물질이 여럿이면 가장 아래쪽 물질 밑을 맞힌다")
    func lowestMaterialFirst() {
        let board = Board.deadlocked.placing(.drone, at: (1, 9))
            .placing(.material, at: (6, 2)).placing(.material, at: (3, 6))
        let fired = activations(turn(board, swap((1, 9), (2, 9))))
        #expect(fired.first?.effect == .drone(pos(3, 7)))
    }

    @Test("물질 밑을 맞힐 수 없으면 가장 아래쪽 장애물을 맞힌다")
    func fallsBackToObstacle() {
        let board = Board.deadlocked.placing(.drone, at: (1, 9))
            .placing(.concrete(hp: 2), at: (6, 2)).placing(.concrete(hp: 2), at: (4, 5))
        let events = turn(board, swap((1, 9), (2, 9)))
        #expect(activations(events).first?.effect == .drone(pos(4, 5)))
        #expect(events.contains(.obstaclesDamaged([ObstacleHit(position: pos(4, 5), remaining: .concrete(hp: 1))])))
    }

    @Test("물질도 장애물도 없으면 가장 많이 남은 종류의 블록을 맞힌다")
    func fallsBackToMostCommonKind() {
        // 맨 위 줄의 하나를 흙으로 바꾸고 흙을 가장 많게 한다.
        let board = Board.deadlocked.placing(.drone, at: (1, 9))
            .setting(.soil, at: [(0, 0), (2, 0), (4, 0), (6, 0), (0, 2), (2, 2), (4, 2), (6, 2), (0, 4), (2, 4), (4, 4), (6, 4),
                                 (0, 6), (2, 6), (4, 6), (6, 6), (7, 0)])
        let fired = activations(turn(board, swap((1, 9), (2, 9))))
        // 흙 가운데 가장 아래 행, 같은 행이면 왼쪽.
        #expect(fired.first?.effect == .drone(pos(0, 6)))
    }

    @Test("다른 효과에 맞으면 이어서 발동해 날아간다")
    func chainedByBeam() {
        let board = Board.deadlocked.placing(.beam(.horizontal), at: (2, 9)).placing(.drone, at: (6, 8))
            .placing(.material, at: (4, 2))
        let fired = activations(turn(board, swap((2, 9), (2, 8))))
        #expect(fired.contains { $0.origin == pos(6, 8) && $0.effect == .drone(pos(4, 3)) })
    }

    @Test("드론 두 대를 바꾸면 서로 다른 목표 셋을 맞힌다")
    func swarm() {
        let board = Board.deadlocked.placing(.drone, at: (3, 9)).placing(.drone, at: (4, 9)).placing(.material, at: (0, 2))
        let fired = activations(turn(board, swap((3, 9), (4, 9))))
        guard case .droneSwarm(let targets) = fired.first?.effect else {
            Issue.record("드론 셋이 날지 않았다: \(String(describing: fired.first?.effect))")
            return
        }
        #expect(targets.count == 3)
        #expect(Set(targets).count == 3)
        #expect(targets.first == pos(0, 3))
    }

    @Test("드론과 빔을 바꾸면 목표 칸에서 빔이 발동한다")
    func droneCarriesBeam() {
        let board = Board.deadlocked.placing(.drone, at: (3, 9)).placing(.beam(.vertical), at: (4, 9)).placing(.material, at: (6, 2))
        let fired = activations(turn(board, swap((3, 9), (4, 9))))
        #expect(fired.first?.effect == .droneBeam(.vertical, pos(6, 3)))
        let cleared = Set(fired.flatMap(\.cleared))
        #expect(cleared.isSuperset(of: [pos(6, 0), pos(6, 1), pos(6, 3), pos(6, 9)]))
    }

    @Test("드론과 폭탄을 바꾸면 목표 칸 둘레 3×3이 터진다")
    func droneCarriesBomb() {
        let board = Board.deadlocked.placing(.drone, at: (3, 9)).placing(.bomb, at: (4, 9)).placing(.material, at: (6, 2))
        let fired = activations(turn(board, swap((3, 9), (4, 9))))
        #expect(fired.first?.effect == .droneBomb(pos(6, 3)))
        let cleared = Set(fired.flatMap(\.cleared))
        #expect(cleared.isSuperset(of: [pos(5, 2), pos(7, 2), pos(5, 4), pos(6, 4), pos(7, 4)]))
    }

    @Test("정화 코어와 바꾸면 가장 많은 종류가 모두 드론이 되어 날아간다")
    func coreTurnsKindIntoDrones() {
        let board = Board.deadlocked.placing(.core, at: (3, 9)).placing(.drone, at: (4, 9))
        let events = turn(board, swap((3, 9), (4, 9)))
        let created = events.compactMap(\.createdSpecials).first ?? []
        #expect(!created.isEmpty)
        #expect(created.allSatisfy { $0.block == .drone })
        let drones = events.compactMap(\.activations).flatMap { $0 }.filter {
            if case .drone = $0.effect { true } else { false }
        }
        #expect(drones.count >= created.count)
    }

    @Test("같은 상태에서 같은 수를 두면 드론의 목표도 같다")
    func deterministic() {
        let board = Board.deadlocked.placing(.drone, at: (1, 9)).placing(.material, at: (5, 3))
        let a = GameState(board: board, seed: 9).performTurn(swap((1, 9), (2, 9)))
        let b = GameState(board: board, seed: 9).performTurn(swap((1, 9), (2, 9)))
        #expect(a == b)
    }
}
