import Testing
@testable import GameCore

/// 왼쪽 위 칸과 크기로 물질 덩어리를 만든다.
private func piece(_ column: Int, _ row: Int, _ width: Int, _ height: Int) -> MaterialPiece {
    MaterialPiece(origin: pos(column, row), width: width, height: height)
}

@Suite("물질 덩어리")
struct MaterialPieceTests {
    @Test("덮는 칸과 범위")
    func cells() {
        let wide = piece(2, 3, 2, 1)
        #expect(wide.cells == [pos(2, 3), pos(3, 3)])
        #expect(wide.bottomRow == 3)
        #expect(wide.isLarge)

        let square = piece(5, 0, 2, 2)
        #expect(square.cells == [pos(5, 0), pos(6, 0), pos(5, 1), pos(6, 1)])
        #expect(square.bottomRow == 1)
        #expect(square.contains(pos(6, 1)))
        #expect(!square.contains(pos(7, 1)))

        #expect(!MaterialPiece(origin: pos(0, 0)).isLarge)
    }

    @Test("덩어리 목록을 주지 않으면 물질 칸마다 한 칸짜리로 본다")
    func inferredSingles() {
        let board = Board.deadlocked(rows: 16).placing(.material, at: (2, 0)).placing(.material, at: (3, 0))
        let state = GameState(board: board)
        #expect(state.materials == [MaterialPiece(origin: pos(2, 0)), MaterialPiece(origin: pos(3, 0))])
        #expect(state.materialsTotal == 2)
    }

    @Test("큰 물질은 칸 수와 상관없이 하나로 센다")
    func largePieceCountsOnce() {
        let square = piece(5, 0, 2, 2)
        let state = GameState(board: Board.deadlocked(rows: 16).placing(square), pieces: [square])
        #expect(state.materialsTotal == 1)
        #expect(state.materialsRemaining == 1)
        #expect(state.materialPositions.count == 4)
    }
}

@Suite("큰 물질의 낙하")
struct LargeMaterialGravityTests {
    let wide = piece(2, 3, 2, 1)
    var board: Board { Board.deadlocked(rows: 16).placing(wide) }

    @Test("한쪽 아래만 비면 내려가지 않고, 그 칸은 빈 채로 남는다")
    func staysWhenHalfSupported() {
        var board = board.setting(nil, at: [(2, 4)])
        var pieces = [wide]
        let moves = board.applyGravity(in: 0..<10, pieces: &pieces)
        #expect(moves.isEmpty)
        #expect(pieces == [wide])
        #expect(board[2, 4] == nil)
        // 물질 위의 블록도 물질에 얹혀 그대로다.
        #expect(board[2, 2] == Board.deadlocked(rows: 16)[2, 2])
    }

    @Test("폭 전체의 아래가 비면 한 몸으로 내려가고 위의 블록이 따라온다")
    func fallsWhenFullyUnsupported() {
        let original = board
        var board = original.setting(nil, at: [(2, 4), (3, 4)])
        var pieces = [wide]
        let moves = board.applyGravity(in: 0..<10, pieces: &pieces)
        #expect(pieces == [piece(2, 4, 2, 1)])
        #expect(board[2, 4] == .material && board[3, 4] == .material)
        #expect(board[2, 3] == original[2, 2])
        #expect(board[3, 3] == original[3, 2])
        #expect(board[2, 0] == nil && board[3, 0] == nil)
        // 두 열에서 물질 칸과 그 위의 블록 3개씩이 한 칸 내려온다.
        #expect(moves.count == 8)
        #expect(moves.allSatisfy { $0.to == pos($0.from.column, $0.from.row + 1) })
        // 같은 열에서는 아래쪽 칸이 먼저다.
        #expect(moves.prefix(4).map(\.from) == [pos(2, 3), pos(2, 2), pos(2, 1), pos(2, 0)])
    }

    @Test("빈 깊이가 다르면 얕은 쪽만큼만 내려간다")
    func fallsByShallowerSide() {
        var board = board.setting(nil, at: [(2, 4), (2, 5), (2, 6), (3, 4)])
        var pieces = [wide]
        board.applyGravity(in: 0..<10, pieces: &pieces)
        #expect(pieces == [piece(2, 4, 2, 1)])
        #expect(board[2, 5] == nil && board[2, 6] == nil)
    }

    @Test("2×2는 네 칸이 함께 내려간다")
    func squareFalls() {
        let square = piece(5, 2, 2, 2)
        var board = Board.deadlocked(rows: 16).placing(square).setting(nil, at: [(5, 4), (6, 4), (5, 5), (6, 5)])
        var pieces = [square]
        board.applyGravity(in: 0..<10, pieces: &pieces)
        #expect(pieces == [piece(5, 4, 2, 2)])
        for cell in pieces[0].cells {
            #expect(board[cell] == .material)
        }
        #expect(board.positions.count { board[$0] == .material } == 4)
    }

    @Test("활성 구간의 바닥에서 멈춘다")
    func stopsAtZoneBottom() {
        var board = Board(columns: 8, rows: 16).placing(wide)
        var pieces = [wide]
        board.applyGravity(in: 0..<10, pieces: &pieces)
        #expect(pieces == [piece(2, 9, 2, 1)])
    }

    @Test("한 칸짜리 물질과 일반 블록은 전처럼 열마다 따로 떨어진다")
    func singlesFallIndependently() {
        var board = Board.deadlocked(rows: 16).placing(.material, at: (2, 3)).setting(nil, at: [(2, 4)])
        var pieces = [MaterialPiece(origin: pos(2, 3))]
        board.applyGravity(in: 0..<10, pieces: &pieces)
        #expect(pieces == [MaterialPiece(origin: pos(2, 4))])
        #expect(board[2, 4] == .material)
    }
}

@Suite("큰 물질의 턴 처리")
struct LargeMaterialTurnTests {
    let wide = piece(2, 3, 2, 1)

    @Test("흘러내림을 끄면 한쪽 아래를 지웠을 때 빈칸이 남고 보충되지 않는다")
    func caveIsNotRefilled() {
        // 왼쪽 칸 아래의 세로 3개 매치.
        let board = Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(2, 4), (2, 5), (2, 6)])
        let result = GameState(board: board, pieces: [wide], slide: false).settle()
        #expect(result.state.materials == [wide])
        #expect(result.state.board[2, 4] == nil)
        #expect(result.state.board[2, 5] == nil)
        #expect(result.state.board[2, 6] == nil)
        for case .refilled(let spawns) in result.events {
            #expect(!spawns.contains { $0.position.column == 2 })
        }
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("바로 아래에서 가로 3개를 맞추면 한 번에 내려간다")
    func horizontalMatchBelowDropsPiece() {
        let board = Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(2, 4), (3, 4), (4, 4)])
        let result = GameState(board: board, pieces: [wide]).settle()
        #expect(result.state.materials[0].origin.row >= 4)
        #expect(result.state.materials[0].origin.column == 2)
        #expect(result.state.board[result.state.materials[0].origin] == .material)
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("흘러내림을 끄면 나눠서 지워도 진행이 쌓여 결국 내려간다")
    func progressAccumulates() {
        // 먼저 왼쪽 아래, 이어서 오른쪽 아래를 지운다.
        let first = Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(2, 4), (2, 5), (2, 6)])
        var state = GameState(board: first, pieces: [wide], slide: false).settle().state
        #expect(state.materials == [wide])

        state.board[3, 4] = .normal(.soil)
        state.board[3, 5] = .normal(.soil)
        state.board[3, 6] = .normal(.soil)
        state = state.settle().state
        #expect(state.materials[0].origin.row >= 6)
    }

    @Test("큰 물질은 스왑할 수 없다")
    func largePiecesCannotBeSwapped() {
        // soil이 (2,3)으로 오면 가로 3개가 되는 배치. 한 칸짜리라면 허용되는 스왑이다.
        let board = Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(0, 3), (1, 3), (2, 2)])
        let state = GameState(board: board, pieces: [wide])
        let move = swap((2, 2), (2, 3))
        #expect(board.isValid(move, in: 0..<10))
        #expect(state.rejection(for: move) == .immovable)
        #expect(state.performTurn(move).events == [.swapRejected(move, .immovable)])
        #expect(!state.possibleMoves().contains(move))

        // 같은 배치의 한 칸짜리 물질은 스왑된다.
        let single = Board.deadlocked(rows: 16).placing(.material, at: (2, 3)).setting(.soil, at: [(0, 3), (1, 3), (2, 2)])
        #expect(GameState(board: single).rejection(for: move) == nil)
    }

    @Test("큰 물질과의 스왑밖에 없으면 가능한 이동이 없는 것으로 보고 셔플한다")
    func lockedMovesDoNotCount() {
        let board = Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(0, 3), (1, 3), (2, 2)])
        #expect(board.possibleMoves(in: 0..<10) == [swap((2, 2), (2, 3))])
        let state = GameState(board: board, pieces: [wide])
        #expect(state.possibleMoves().isEmpty)
        let result = state.settle()
        #expect(result.events.contains { if case .shuffled = $0 { true } else { false } })
        #expect(result.state.materials == [wide])
        #expect(!result.state.possibleMoves().isEmpty)
    }

    @Test("한 칸짜리 물질은 스왑하면 위치가 따라 바뀐다")
    func singlePieceFollowsSwap() {
        let board = Board.deadlocked(rows: 16)
            .setting(.soil, at: [(0, 5), (1, 5), (3, 5)])
            .placing(.material, at: (2, 5))
        let result = GameState(board: board).performTurn(swap((2, 5), (3, 5)))
        let state = result.state
        #expect(state.materials.count == 1)
        #expect(state.board[state.materials[0].origin] == .material)
        #expect(state.materials[0].origin.column == 3)
    }

    @Test("특수 효과는 큰 물질을 지우지 못한다")
    func effectsDoNotRemoveLargePieces() {
        let square = piece(4, 3, 2, 2)
        let board = Board.deadlocked(rows: 16).placing(square)
            .placing(.core, at: (1, 5)).placing(.core, at: (2, 5))
        let result = GameState(board: board, pieces: [square]).performTurn(swap((1, 5), (2, 5)))
        #expect(result.events[1].activations?[0].cleared.count == 76)
        #expect(result.state.materials.count == 1)
        #expect(result.state.materialPositions.count == 4)
        // 구간이 다 비었으므로 구간 바닥까지 내려간다.
        #expect(result.state.materials[0].width == 2 && result.state.materials[0].height == 2)
    }

    @Test("카메라는 큰 물질의 맨 위 행을 따른다")
    func cameraFollowsPieceTop() {
        let square = piece(4, 5, 2, 2)
        let state = GameState(board: Board.deadlocked(rows: 16).placing(square), pieces: [square])
        #expect(state.settle().state.activeTop == 4)
    }

    @Test("맨 아래 행이 보드 끝에 닿으면 통째로 수거된다")
    func collectedWhole() {
        // 12행 보드의 끝. 2×2가 10~11행까지 내려오면 수거된다.
        let square = piece(2, 8, 2, 2)
        let board = Board.deadlocked(rows: 12).placing(square).setting(.soil, at: [(2, 10), (3, 10), (4, 10)])
        // 아래 두 행 가운데 10행만 지워서는 닿지 않는다.
        let partial = GameState(board: board, activeTop: 2, moves: 5, pieces: [square]).settle()
        #expect(partial.state.status == .playing)
        #expect(partial.state.materials[0].bottomRow == 10)

        var next = partial.state
        next.board[2, 11] = .normal(.soil)
        next.board[3, 11] = .normal(.soil)
        next.board[4, 11] = .normal(.soil)
        let result = next.settle()
        #expect(result.events.contains(.materialsCollected([pos(2, 10), pos(3, 10), pos(2, 11), pos(3, 11)])))
        #expect(result.state.materials.isEmpty)
        #expect(result.state.status == .won)
        #expect(replay(result.events, on: next.board) == result.state.board)
    }
}

@Suite("큰 물질이 있는 레벨")
struct LargeMaterialLevelTests {
    let pieces = [piece(1, 0, 2, 1), piece(5, 0, 2, 2)]

    func level(seed: UInt64, moves: Int = 40) -> GameState {
        GameState(seed: seed, rows: 16, moves: moves, materialPieces: pieces)
    }

    @Test("크기를 정한 물질이 지정한 칸에 놓인다")
    func generation() {
        for seed in 0..<50 as Range<UInt64> {
            let state = level(seed: seed)
            #expect(state.materials == pieces)
            #expect(state.materialsTotal == 2)
            #expect(state.materialPositions == pieces.flatMap(\.cells).sorted())
            #expect(state.board.isFull)
            #expect(state.board.findMatches().isEmpty)
            #expect(!state.possibleMoves().isEmpty)
        }
        #expect(level(seed: 9) == level(seed: 9))
    }

    @Test("한 칸짜리와 큰 물질을 한 판에 섞을 수 있다")
    func mixedSizes() {
        let state = GameState(
            seed: 1, rows: 16, moves: 40,
            materials: [pos(0, 0)],
            pendingMaterials: [PendingMaterial(column: 7, depth: 3)],
            materialPieces: [piece(3, 0, 2, 2)]
        )
        #expect(state.materialsTotal == 3)
        #expect(state.materials == [MaterialPiece(origin: pos(0, 0)), piece(3, 0, 2, 2)])
    }

    @Test("2×1과 2×2가 있는 16행 레벨을 처음부터 클리어까지 플레이한다", arguments: [1, 2, 3, 4, 5, 6] as [UInt64])
    func playToClear(seed: UInt64) {
        var state = level(seed: seed, moves: 2000)
        var turns = 0
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            turns += 1

            #expect(replay(result.events, on: before.board) == state.board)
            // 덩어리 목록과 보드의 물질 칸이 늘 일치하고, 모양이 변하지 않는다.
            #expect(state.materials.flatMap(\.cells).sorted() == state.materialPositions)
            #expect(state.materials.allSatisfy { ($0.width, $0.height) == (2, 1) || ($0.width, $0.height) == (2, 2) })
            #expect(state.materials.allSatisfy { state.activeRange.contains($0.origin.row) && state.activeRange.contains($0.bottomRow) })
            if let topmost = state.materials.map(\.origin.row).min() {
                #expect(state.activeTop == min(max(topmost - 1, 0), 6))
            }
            // 활성 구간의 빈칸은 모두 같은 열의 물질 아래에 있다.
            for position in state.board.positions(in: state.activeRange) where state.board[position] == nil {
                #expect(state.materials.contains {
                    $0.columns.contains(position.column) && $0.bottomRow < position.row
                })
            }
            #expect(state.board.findMatches(in: state.activeRange).isEmpty)
            if state.status == .playing {
                #expect(!state.possibleMoves().isEmpty)
            }
        }
        #expect(state.status == .won)
        #expect(state.materials.isEmpty)
        print("큰 물질 seed \(seed): \(turns)턴에 클리어")
    }

    @Test("같은 시드와 같은 입력은 같은 결과를 낸다")
    func determinism() {
        func play() -> GameState {
            var state = level(seed: 12, moves: 60)
            while state.status == .playing {
                state = state.performTurn(state.greedyMove()).state
            }
            return state
        }
        #expect(play() == play())
    }
}
