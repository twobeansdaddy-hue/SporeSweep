import Testing
@testable import GameCore

private func slides(_ events: [GameEvent]) -> [BlockMove] {
    events.flatMap { event -> [BlockMove] in
        if case .slid(let moves) = event { return moves }
        return []
    }
}

@Suite("벽")
struct WallTests {
    @Test("벽은 고정돼 있고 스왑할 수 없고 종류가 없다")
    func properties() {
        #expect(Block.wall.isFixed)
        #expect(!Block.wall.isSwappable)
        #expect(!Block.wall.canSlide)
        #expect(Block.wall.kind == nil)
        #expect(Block.wall.isIndestructible)
        #expect(Block.material.isIndestructible)
        #expect(!Block.concrete(hp: 1).isIndestructible)
    }

    @Test("특수 효과가 닿아도 없어지지 않고 피해도 입지 않는다")
    func survivesEffects() {
        // 가로 빔이 지나는 줄에 벽이 있다.
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.wall, at: (6, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.state.board[6, 5] == .wall)
        #expect(result.events[1].activations?[0].cleared.contains(pos(6, 5)) == false)
        #expect(!result.events.contains { if case .obstaclesDamaged = $0 { true } else { false } })
    }

    @Test("옆에서 매치해도 없어지지 않는다")
    func survivesAdjacentMatch() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.wall, at: (2, 8))
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(result.state.board[2, 8] == .wall)
        #expect(!result.events.contains { if case .obstaclesDamaged = $0 { true } else { false } })
    }

    @Test("벽은 떨어지지 않고, 벽 아래의 빈칸은 옆 열의 블록이 미끄러져 채운다")
    func blocksSlideUnderWalls() {
        let board = Board.deadlocked(rows: 16)
            .placing(.wall, at: (2, 3))
            .setting(.soil, at: [(2, 4), (2, 5), (2, 6)])
        let result = GameState(board: board).settle()
        #expect(result.state.board[2, 3] == .wall)
        #expect(result.state.board.positions(in: result.state.activeRange).allSatisfy { result.state.board[$0] != nil })
        #expect(!slides(result.events).isEmpty)
        #expect(replay(result.events, on: board) == result.state.board)
    }
}

@Suite("좁은 수거함")
struct NarrowContainerTests {
    /// 맨 아래 행이 벽이고 3·4열만 뚫린 12행 보드.
    func floorBoard() -> Board {
        var board = Board.deadlocked(rows: 12)
        for column in [0, 1, 2, 5, 6, 7] {
            board[column, 11] = .wall
        }
        return board
    }

    @Test("수거함이 놓인 열에 닿은 물질만 수거한다")
    func collectsOnlyInContainer() {
        // 3열의 물질은 맨 아래 행에 닿아 있고, 0열의 물질은 벽 위에 얹혀 있다.
        let board = floorBoard().placing(.material, at: (3, 11)).placing(.material, at: (0, 10))
        let state = GameState(board: board, generator: SeededGenerator(seed: 1), activeTop: 2, containerColumns: 3...4)
        let result = state.settle()
        #expect(result.state.materials.map(\.origin) == [pos(0, 10)])
        #expect(result.events.contains(.materialsCollected([pos(3, 11)])))
        #expect(result.state.status == .playing)
    }

    @Test("수거함을 정하지 않으면 어느 열이든 수거한다")
    func fullWidthByDefault() {
        let board = Board.deadlocked(rows: 12).placing(.material, at: (0, 11))
        let state = GameState(board: board, generator: SeededGenerator(seed: 1), activeTop: 2)
        #expect(state.containerColumns == nil)
        #expect(state.settle().state.status == .won)
    }

    @Test("수거함 밖의 맨 아래 칸에 닿은 물질은 수거하지 않는다")
    func notCollectedOutside() {
        let board = Board.deadlocked(rows: 12).placing(.material, at: (0, 11))
        let state = GameState(board: board, generator: SeededGenerator(seed: 1), activeTop: 2, containerColumns: 3...4)
        let result = state.settle()
        #expect(result.state.materials.count == 1)
        #expect(result.state.status == .playing)
    }
}

@Suite("흘러가는 물질")
struct MaterialFlowTests {
    /// (2,5)에 물질이 있고 그 아래 (2,6)은 벽이다. `columns`의 열마다 벽 옆(6행)부터 세로 3칸이
    /// 맞춰져 있어서, 정리하면 그 칸들이 지워진다.
    func board(clearing columns: [Int]) -> Board {
        Board.deadlocked(rows: 16)
            .placing(.material, at: (2, 5))
            .placing(.wall, at: (2, 6))
            .setting(.soil, at: columns.flatMap { column in [(column, 6), (column, 7), (column, 8)] })
    }

    func state(_ board: Board, flows: Bool = true, container: ClosedRange<Int>? = nil) -> GameState {
        GameState(
            board: board, generator: SeededGenerator(seed: 3),
            containerColumns: container, materialsSlide: flows
        )
    }

    @Test("기본으로는 꺼져 있다")
    func offByDefault() {
        #expect(!GameState(seed: 1).materialsSlide)
    }

    @Test("아래가 막힌 물질은 대각선 아래의 빈칸으로 흘러든다")
    func flowsIntoDiagonalGap() {
        let start = board(clearing: [3])
        let result = state(start).settle()
        #expect(slides(result.events).first == BlockMove(from: pos(2, 5), to: pos(3, 6)))
        // 흘러든 뒤에는 제 열에서 계속 떨어진다.
        #expect(result.state.materials[0].origin.column == 3)
        #expect(result.state.materials[0].origin.row >= 6)
        #expect(result.state.board[result.state.materials[0].origin] == .material)
        #expect(result.state.materialPositions == result.state.materials.map(\.origin))
        #expect(replay(result.events, on: start) == result.state.board)
    }

    @Test("꺼져 있으면 물질은 흘러가지 않는다")
    func staysWhenOff() {
        let result = state(board(clearing: [3]), flows: false).settle()
        #expect(result.state.materials[0].origin == pos(2, 5))
    }

    @Test("아래가 비어 있으면 옆으로 가지 않고 곧장 떨어진다")
    func fallsStraightFirst() {
        // 벽 없이, 물질 바로 아래의 가로 3칸이 한 번에 지워진다.
        let start = Board.deadlocked(rows: 16).placing(.material, at: (2, 5)).setting(.soil, at: [(2, 6), (3, 6), (4, 6)])
        let result = state(start).settle()
        #expect(result.state.materials[0].origin.column == 2)
    }

    @Test("양쪽이 다 비어 있으면 수거함에 가까워지는 쪽으로 간다")
    func prefersContainerSide() {
        let both = board(clearing: [1, 3])
        #expect(state(both, container: 5...6).settle().state.materials[0].origin.column == 3)
        #expect(state(both, container: 0...0).settle().state.materials[0].origin.column == 1)
    }

    @Test("큰 물질은 흘러가지 않는다")
    func largePiecesDoNotFlow() {
        let wide = MaterialPiece(origin: pos(2, 5), width: 2, height: 1)
        let start = Board.deadlocked(rows: 16)
            .placing(wide)
            .placing(.wall, at: (2, 6))
            .placing(.wall, at: (3, 6))
            .setting(.soil, at: [(4, 6), (4, 7), (4, 8)])
        var flowing = GameState(board: start, generator: SeededGenerator(seed: 3), materials: [wide], materialsSlide: true)
        flowing = flowing.settle().state
        #expect(flowing.materials == [wide])
    }

    @Test("벽으로 만든 깔때기를 따라 좁은 수거함까지 내려가 클리어한다", arguments: [1, 2, 3] as [UInt64])
    func funnelPlaysToClear(seed: UInt64) {
        // 아래 세 행이 계단 모양으로 좁아져 3·4열의 수거함으로 모인다.
        var walls: [Obstacle] = []
        for (row, open) in [(13, 1...6), (14, 2...5), (15, 3...4)] {
            for column in 0..<8 where !open.contains(column) {
                walls.append(Obstacle(kind: .wall, position: pos(column, row)))
            }
        }
        var state = GameState(
            seed: seed, rows: 16, moves: 400, materials: [pos(0, 0), pos(7, 0)],
            obstacles: walls, containerColumns: 3...4, materialsSlide: true
        )
        var turns = 0
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            turns += 1
            #expect(replay(result.events, on: before.board) == state.board)
            #expect(state.materials.map(\.origin).sorted() == state.materialPositions)
            // 벽은 그대로다.
            #expect(walls.allSatisfy { state.board[$0.position] == .wall || $0.position.row < state.activeTop })
        }
        #expect(state.status == .won)
        print("깔때기 seed \(seed): \(turns)턴에 클리어")
    }
}

@Suite("클리어한 뒤의 특수 블록")
struct FinalDetonationTests {
    /// 물질이 한 수에 수거되는 12행 보드. `specials`를 활성 구간에 놓는다.
    func start(specials: [(Block, (Int, Int))]) -> Board {
        var board = Board.deadlocked(rows: 12)
            .placing(.material, at: (2, 10))
            .setting(.soil, at: [(0, 11), (1, 11), (3, 11)])
        for (block, cell) in specials {
            board = board.placing(block, at: cell)
        }
        return board
    }

    func result(specials: [(Block, (Int, Int))]) -> TurnResult {
        GameState(board: start(specials: specials), activeTop: 2, moves: 5).performTurn(swap((3, 11), (2, 11)))
    }

    @Test("터진 특수 블록은 발동 기록의 지워진 칸에 들어 있어서, 이벤트만으로 보드를 그대로 다시 만들 수 있다")
    func eventsReplayExactly() {
        let specials: [(Block, (Int, Int))] = [(.beam(.horizontal), (5, 4)), (.bomb, (6, 7)), (.core, (1, 5))]
        let outcome = result(specials: specials)
        #expect(replay(outcome.events, on: start(specials: specials)) == outcome.state.board)
        // 혼자 터진 특수 블록도 제 칸이 지워진 칸에 들어 있다. 발동한 자리는 모두 지워진 칸이다.
        let activations = outcome.events.flatMap { $0.activations ?? [] }
        #expect(activations.count >= 3)
        #expect(Set(activations.flatMap(\.cleared)).isSuperset(of: activations.map(\.origin)))
    }

    @Test("클리어하면 화면에 남은 특수 블록이 모두 발동하고, 그 점수가 더해진다")
    func detonatesAll() {
        let plain = result(specials: [])
        let with = result(specials: [(.beam(.horizontal), (5, 4)), (.bomb, (6, 7))])
        #expect(plain.state.status == .won)
        #expect(with.state.status == .won)
        // 끝난 판에는 특수 블록이 남지 않는다.
        let range = with.state.activeRange
        #expect(with.state.board.positions(in: range).allSatisfy { with.state.board[$0]?.isSpecial != true })
        // 두 특수 블록이 발동한 기록이 있고, 그만큼 점수가 높다.
        let origins = with.events.flatMap { $0.activations ?? [] }.map(\.origin)
        #expect(origins.contains(pos(5, 4)))
        #expect(origins.contains(pos(6, 7)))
        #expect(with.state.score > plain.state.score)
        // 마지막 이벤트는 승리다.
        #expect(with.events.last == .won)
    }

    @Test("특수 블록이 없으면 평소처럼 끝난다")
    func nothingToDetonate() {
        let plain = result(specials: [])
        #expect(!plain.events.contains { $0.activations != nil })
        #expect(plain.events.last == .won)
    }

    @Test("실패한 판에서는 특수 블록이 터지지 않는다")
    func notOnLoss() {
        let board = Board.deadlocked(rows: 16)
            .placing(.material, at: (2, 0))
            .placing(.bomb, at: (6, 3))
            .setting(.soil, at: [(5, 9), (6, 9), (7, 8)])
        let result = GameState(board: board, moves: 1).performTurn(swap((7, 8), (7, 9)))
        #expect(result.state.status == .lost)
        // 폭탄은 아래 블록이 지워져 한 칸 떨어졌을 뿐 그대로 있다.
        #expect(result.state.board.positions.contains { result.state.board[$0] == .bomb })
        #expect(!result.events.contains { $0.activations != nil })
    }
}
