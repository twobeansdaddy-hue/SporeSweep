import Testing
@testable import GameCore

@Suite("대기 물질")
struct PendingMaterialTests {
    /// 2열에 세로 3개 매치가 있는 16행 보드. 안정시키면 2열에 블록 3개가 보충된다.
    let board = Board.deadlocked(rows: 16).setting(.soil, at: [(2, 4), (2, 5), (2, 6)])

    /// 첫 보충에서 2열에 들어온 블록. 아래쪽 칸이 먼저다.
    func firstRefill(pending: [PendingMaterial]) -> (spawns: [Spawn], state: GameState) {
        let result = GameState(board: board, pending: pending).settle()
        for case .refilled(let spawns) in result.events {
            return (spawns.filter { $0.position.column == 2 }, result.state)
        }
        Issue.record("보충 이벤트가 없다")
        return ([], result.state)
    }

    @Test("대기 물질은 보드에 없지만 수거해야 할 물질로 센다")
    func countsTowardTotal() {
        let state = GameState(board: board.placing(.material, at: (5, 0)), pending: [PendingMaterial(column: 2, depth: 6)])
        #expect(state.materialsTotal == 2)
        #expect(state.materialsRemaining == 2)
        #expect(state.materialPositions == [pos(5, 0)])
    }

    @Test("대기 깊이가 0이면 그 열의 다음 보충이 물질이다")
    func depthZeroEntersFirst() {
        let (spawns, state) = firstRefill(pending: [PendingMaterial(column: 2, depth: 0)])
        #expect(spawns.map(\.position) == [pos(2, 2), pos(2, 1), pos(2, 0)])
        #expect(spawns[0].block == .material)
        #expect(spawns[1].block != .material && spawns[2].block != .material)
        #expect(state.pendingMaterials.isEmpty)
        #expect(state.materialsRemaining == 1)
    }

    @Test("대기 깊이만큼 블록이 먼저 들어온 뒤 물질이 들어온다")
    func entersAfterDepthBlocks() {
        let (spawns, state) = firstRefill(pending: [PendingMaterial(column: 2, depth: 2)])
        #expect(spawns.map { $0.block == .material } == [false, false, true])
        #expect(spawns[2].position == pos(2, 0))
        #expect(state.pendingMaterials.isEmpty)
    }

    @Test("들어온 블록 수만큼 대기 깊이가 준다")
    func depthCountsDown() {
        let (spawns, state) = firstRefill(pending: [PendingMaterial(column: 2, depth: 5)])
        #expect(spawns.count == 3)
        #expect(spawns.allSatisfy { $0.block != .material })
        // 뒤따른 연쇄로 2열에 더 보충됐을 수 있으므로 3 이상 줄었는지만 본다.
        #expect(state.materialPositions.count + state.pendingMaterials.count == 1)
        if let pending = state.pendingMaterials.first {
            #expect(pending.depth <= 2)
        }
    }

    @Test("다른 열의 보충은 대기 깊이를 줄이지 않는다")
    func otherColumnsDoNotCount() {
        let result = GameState(board: board, pending: [PendingMaterial(column: 6, depth: 1)]).settle()
        let refilledColumns = Set(result.events.flatMap { event -> [Int] in
            if case .refilled(let spawns) = event { return spawns.map(\.position.column) }
            return []
        })
        if !refilledColumns.contains(6) {
            #expect(result.state.pendingMaterials == [PendingMaterial(column: 6, depth: 1)])
        }
        #expect(refilledColumns.contains(2))
    }

    @Test("같은 열에 대기 물질이 여럿이면 차례로 들어온다")
    func severalInOneColumn() {
        let (spawns, state) = firstRefill(pending: [
            PendingMaterial(column: 2, depth: 0), PendingMaterial(column: 2, depth: 1),
        ])
        // 첫 물질, 블록 하나, 둘째 물질 순서다.
        #expect(spawns.map { $0.block == .material } == [true, false, true])
        #expect(state.pendingMaterials.isEmpty)
    }

    @Test("대기 물질만 남아 있으면 아직 승리가 아니다")
    func notWonWhilePending() {
        let pendingOnly = GameState(board: board, moves: 10, pending: [PendingMaterial(column: 7, depth: 30)])
        let result = pendingOnly.settle()
        #expect(result.state.status == .playing)
        #expect(!result.events.contains(.won))
        #expect(result.state.materialsRemaining == 1)
    }

    @Test("대기 물질은 카메라를 붙잡지 않는다")
    func cameraIgnoresPending() {
        let board = Board.deadlocked(rows: 16).placing(.material, at: (5, 4))
        let state = GameState(board: board, pending: [PendingMaterial(column: 2, depth: 9)])
        let result = state.settle()
        #expect(result.state.activeTop == 3)
        #expect(result.state.pendingMaterials == [PendingMaterial(column: 2, depth: 9)])

        // 보드에 나온 물질이 없으면 카메라는 움직이지 않는다.
        let waiting = GameState(board: .deadlocked(rows: 16), pending: [PendingMaterial(column: 2, depth: 9)])
        #expect(waiting.settle().state.activeTop == 0)
    }

    @Test("카메라가 내려간 뒤에 들어오는 물질은 그때의 활성 구간 맨 위로 들어온다")
    func entersAtCurrentZoneTop() {
        // 카메라가 3행까지 내려간 상태. 2열의 매치는 활성 구간 안이다.
        var board = Board.deadlocked(rows: 16)
            .placing(.material, at: (5, 4))
            .setting(.soil, at: [(2, 6), (2, 7), (2, 8)])
        for position in board.positions(in: 0..<3) { board[position] = nil }
        let state = GameState(board: board, activeTop: 3, pending: [PendingMaterial(column: 2, depth: 2)])
        let result = state.settle()
        let entered = result.events.flatMap { event -> [Spawn] in
            if case .refilled(let spawns) = event { return spawns.filter { $0.block == .material } }
            return []
        }
        #expect(entered.map(\.position) == [pos(2, 3)])
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("대기 물질이 있는 레벨을 처음부터 클리어까지 플레이한다", arguments: [1004, 1, 2, 3] as [UInt64])
    func playToClear(seed: UInt64) {
        var state = GameState(
            seed: seed,
            rows: 16,
            moves: 400,
            materials: [pos(2, 0)],
            pendingMaterials: [PendingMaterial(column: 5, depth: 6)]
        )
        #expect(state.materialsTotal == 2)
        #expect(state.materialPositions == [pos(2, 0)])
        var enteredCount = 0
        var turns = 0
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            turns += 1
            for case .refilled(let spawns) in result.events {
                for spawn in spawns where spawn.block == .material {
                    enteredCount += 1
                    #expect(spawn.position.column == 5)
                }
            }
            #expect(replay(result.events, on: before.board) == state.board)
            #expect(state.materialsRemaining <= before.materialsRemaining)
            #expect(state.materialPositions.allSatisfy { state.activeRange.contains($0.row) })
            #expect(state.board.positions(in: state.activeRange).allSatisfy { state.board[$0] != nil })
            #expect(state.pendingMaterials.allSatisfy { $0.depth >= 0 })
        }
        #expect(state.status == .won)
        #expect(enteredCount == 1)
        #expect(state.pendingMaterials.isEmpty)
        print("대기 물질 seed \(seed): \(turns)턴에 클리어")
    }

    @Test("같은 시드와 같은 입력은 같은 결과를 낸다")
    func determinism() {
        func play() -> GameState {
            var state = GameState(
                seed: 77, rows: 16, moves: 40,
                materials: [pos(2, 0)], pendingMaterials: [PendingMaterial(column: 5, depth: 6)]
            )
            while state.status == .playing {
                state = state.performTurn(state.greedyMove()).state
            }
            return state
        }
        #expect(play() == play())
    }
}
