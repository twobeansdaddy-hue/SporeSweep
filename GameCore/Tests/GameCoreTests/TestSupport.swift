import GameCore

func pos(_ column: Int, _ row: Int) -> Position {
    Position(column: column, row: row)
}

func swap(_ from: (Int, Int), _ to: (Int, Int)) -> Swap {
    Swap(from: pos(from.0, from.1), to: pos(to.0, to.1))
}

extension Board {
    /// 글자로 보드를 만든다. A~F는 블록 종류 순서, `.`은 빈칸이고 공백은 무시한다.
    init(text rows: [String]) {
        self.init(rows.map { row in
            row.filter { $0 != " " }.map { character -> Block? in
                guard character != "." else { return nil }
                return .normal(BlockKind(rawValue: Int(character.asciiValue! - Character("A").asciiValue!))!)
            }
        })
    }

    /// 매치도 가능한 이동도 없는 8×10 보드. 5종류(A~E)만 쓴다.
    ///
    /// 종류가 (열 + 2×행) mod 5라서 같은 종류가 한 줄에서 5칸 간격으로만 나온다.
    /// 테스트는 여기에 여섯 번째 종류(soil)를 놓아 원하는 모양만 만든다.
    static var deadlocked: Board {
        deadlocked(rows: GameConstants.activeRows)
    }

    /// 같은 무늬로 만든 더 긴 보드. 행 수와 상관없이 매치도 가능한 이동도 없다.
    static func deadlocked(rows: Int) -> Board {
        var board = Board(columns: GameConstants.columns, rows: rows)
        for position in board.positions {
            board[position] = .normal(BlockKind(rawValue: (position.column + 2 * position.row) % 5)!)
        }
        return board
    }

    func setting(_ kind: BlockKind?, at cells: [(Int, Int)]) -> Board {
        var board = self
        for (column, row) in cells {
            board[column, row] = kind.map(Block.normal)
        }
        return board
    }

    /// 물질 덩어리가 덮는 칸을 모두 `.material`로 만든다.
    func placing(_ piece: MaterialPiece) -> Board {
        var board = self
        for cell in piece.cells {
            board[cell] = .material
        }
        return board
    }

    func placing(_ block: Block, at cell: (Int, Int)) -> Board {
        var board = self
        board[cell.0, cell.1] = block
        return board
    }

    /// `kind` 종류의 블록이 놓인 칸.
    func positions(of kind: BlockKind) -> [Position] {
        positions.filter { self.kind(at: $0) == kind }
    }

    /// 종류별 블록 수.
    var kindCounts: [BlockKind: Int] {
        positions.compactMap { kind(at: $0) }.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }
}

extension GameState {
    init(
        board: Board,
        seed: UInt64 = 1,
        activeTop: Int = 0,
        moves: Int? = nil,
        pending: [PendingMaterial] = [],
        pieces: [MaterialPiece]? = nil,
        slide: Bool = true
    ) {
        // 테스트 보드에는 철망, 콘크리트, 슬러지를 직접 놓는다.
        self.init(
            board: board,
            generator: SeededGenerator(seed: seed),
            activeTop: activeTop,
            movesRemaining: moves,
            pendingMaterials: pending,
            materials: pieces,
            blocksSlide: slide
        )
    }

    /// 물질을 가장 많이 내리는 이동. 수거한 물질을 가장 크게 치고, 같으면 먼저 찾은 이동이다.
    /// 대기 중인 물질은 대기 깊이가 줄어드는 만큼 내려온 것으로 친다.
    func greedyMove() -> Swap {
        func progress(_ state: GameState) -> Int {
            let collected = state.materialsTotal - state.materialsRemaining
            // 큰 물질 아래에 파 놓은 빈칸도 조금씩 진전으로 친다.
            let caves = state.board.positions(in: state.activeRange).count { state.board[$0] == nil }
            return collected * 10_000
                + state.materialPositions.map(\.row).reduce(0, +) * 10
                - state.pendingMaterials.map { $0.depth + 1 }.reduce(0, +) * 10
                + caves
        }
        var best: (swap: Swap, progress: Int)?
        for move in possibleMoves() {
            let value = progress(performTurn(move).state)
            if best == nil || value > best!.progress {
                best = (move, value)
            }
        }
        return best!.swap
    }
}

extension GameEvent {
    var activations: [SpecialActivation]? {
        if case .specialsActivated(let activations) = self { return activations }
        return nil
    }

    var createdSpecials: [SpecialSpawn]? {
        if case .specialsCreated(let spawns) = self { return spawns }
        return nil
    }

    var clearedMatches: [Match]? {
        if case .matchesCleared(let matches, _) = self { return matches }
        return nil
    }
}

/// 이벤트를 보드에 순서대로 적용한다. 화면이 재생하는 방식과 같다.
func replay(_ events: [GameEvent], on start: Board) -> Board {
    var board = start
    for event in events {
        switch event {
        case .swapped(let swap):
            board.swapAt(swap.from, swap.to)
        case .swapRejected:
            break
        case .matchesCleared(let matches, _):
            for position in matches.flatMap(\.positions) { board[position] = nil }
        case .specialsActivated(let activations):
            for position in activations.flatMap(\.cleared) { board[position] = nil }
        case .specialsCreated(let spawns):
            for spawn in spawns { board[spawn.position] = spawn.block }
        case .fell(let moves), .slid(let moves):
            for move in moves {
                board[move.to] = board[move.from]
                board[move.from] = nil
            }
        case .refilled(let spawns), .regenerated(let spawns):
            for spawn in spawns { board[spawn.position] = spawn.block }
        case .shuffled(let moves):
            let before = board
            for move in moves { board[move.to] = before[move.from] }
        case .materialsCollected(let positions):
            for position in positions { board[position] = nil }
        case .scrolled(_, let to):
            for position in board.positions(in: 0..<to) { board[position] = nil }
        case .obstaclesDamaged(let hits):
            for hit in hits { board[hit.position] = hit.remaining }
        case .sludgeSpread(let positions):
            for position in positions { board[position] = .sludge }
        case .nestsSpat(let spits):
            for spit in spits { board[spit.target] = .sludge }
        case .timersTicked(let ticks):
            for tick in ticks {
                if let kind = board[tick.position]?.kind { board[tick.position] = .timed(kind, turns: tick.turns) }
            }
        case .timersBurst(let bursts):
            for position in bursts.flatMap(\.sludge) { board[position] = .sludge }
        case .hammered(let position):
            board[position] = nil
        case .won, .lost, .fogLifted, .stickyCleared, .shieldsBroken, .ventsPuffed:
            break
        }
    }
    return board
}
