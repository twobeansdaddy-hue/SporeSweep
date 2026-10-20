import Foundation

/// 판의 진행 상태.
public enum GameStatus: Hashable, Sendable, Codable {
    case playing
    case won
    case lost
}

/// 한 판의 상태. 값 타입이므로 턴 처리는 새 상태를 반환한다.
public struct GameState: Hashable, Sendable, Codable {
    /// 보드 전체. 화면에 보이는 것은 그중 활성 구간뿐이다.
    public var board: Board
    /// 보충에 쓰는 블록 종류 수. `BlockKind.allCases`의 앞쪽부터 쓴다.
    public var blockTypes: Int
    /// 이 판의 유일한 난수 생성기.
    public var generator: SeededGenerator
    /// 활성 구간(카메라)의 맨 위 행. 내려가기만 한다.
    public var activeTop: Int
    /// 남은 이동 횟수. `nil`이면 제한이 없다.
    public var movesRemaining: Int?
    /// 보드에 나와 있는 물질 덩어리. 한 칸짜리도 여기에 든다.
    public var materials: [MaterialPiece]
    /// 화면 위에서 대기하는 물질. 해당 열에 블록이 충분히 보충되면 활성 구간 맨 위로 들어온다.
    public var pendingMaterials: [PendingMaterial]
    /// 흘러내림. 큰 물질이나 콘크리트 아래처럼 위가 막힌 빈칸을 옆 열의 블록이 미끄러져 내려와 채운다.
    /// 게임의 기본 규칙이라 늘 켜 둔다. 끄면 그런 빈칸은 빈 채로 남는다.
    public var blocksSlide: Bool
    /// 수거함이 놓인 열(5장). `nil`이면 보드 폭 전체다. 물질은 이 열의 맨 아래 행에 닿아야 수거된다.
    public var containerColumns: ClosedRange<Int>?
    /// 물질이 옆으로 흘러가는지(5장). 켜면 한 칸짜리 물질이 바로 아래가 막혀 있을 때
    /// 대각선 아래의 빈칸으로 미끄러져 들어간다. 좁은 수거함으로 물질을 몰고 가는 판에 쓴다.
    public var materialsSlide: Bool
    /// 점수(6장). 블록 1개 제거에 10점이고 연쇄가 이어질 때마다 배수가 1씩 오른다.
    /// 클리어하면 남은 이동 횟수 1회당 100점을 더한다.
    public var score = 0
    /// 이번 턴에 슬러지를 하나라도 제거했는지. 제거하지 못한 턴에는 슬러지가 번진다.
    var sludgeClearedThisTurn = false
    /// 포자 둥지가 다음에 슬러지를 뱉기까지 남은 턴. 둥지가 활성 구간에 있는 턴에만 준다.
    public var turnsUntilNestSpit = GameConstants.nestSpitInterval
    /// 오염 안개가 낀 칸(7장). 안개는 칸에 붙어 있어서 블록이 움직여도 따라가지 않는다.
    /// 규칙에는 영향이 없고, 화면이 그 칸의 블록을 가린다. 옆에서 매치하거나 특수 효과가 닿으면 걷힌다.
    public var fog: Set<Position> = []
    /// 끈끈이 바닥이 깔린 칸(7장). 칸에 붙어 있고, 그 위에 놓인 블록은 스왑할 수 없다. 떨어지는 것은 막지 않는다.
    /// 그 칸의 블록이 매치되거나 특수 효과에 맞으면 없어진다.
    public var sticky: Set<Position> = []
    /// 포자 보호막이 덮인 칸(7장). 칸에 붙어 있다. 특수 효과는 이 칸에 닿지 않는다.
    /// 그 칸의 블록이 매치되면 깨진다.
    public var shields: Set<Position> = []
    /// 안개 굴뚝이 다음에 안개를 뿜기까지 남은 턴.
    public var turnsUntilVentPuff = GameConstants.nestSpitInterval
    /// 이 판에서 수거해야 하는 물질의 수. 0이면 승패를 판정하지 않는다.
    public var materialsTotal: Int
    public var status: GameStatus

    /// 셔플을 다시 시도하는 최대 횟수. 넘으면 보드를 새로 만든다.
    static let maximumShuffleAttempts = 100
    /// 클리어한 뒤 남은 특수 블록을 터뜨리는 횟수의 상한.
    static let maximumFinalDetonations = 8

    /// 조작과 매치가 일어나는 행 범위(3장, 5장).
    public var activeRange: Range<Int> {
        activeTop..<min(activeTop + GameConstants.activeRows, board.rows)
    }

    /// 아직 수거하지 못한 물질의 수. 대기 중인 물질도 센다.
    public var materialsRemaining: Int {
        materials.count + pendingMaterials.count
    }

    /// 보드에 나와 있는 물질이 덮은 칸. 큰 물질은 덮은 칸이 모두 들어간다.
    public var materialPositions: [Position] {
        board.positions.filter { board[$0] == .material }
    }

    /// 활성 구간에서 가능한 이동.
    public func possibleMoves() -> [Swap] {
        board.possibleMoves(in: activeRange).filter { !isLocked($0) }
    }

    /// 스왑을 검증한다. 유효하면 `nil`을 반환한다.
    public func rejection(for swap: Swap) -> SwapRejection? {
        if status != .playing {
            return .gameOver
        }
        if board.contains(swap.from), board.contains(swap.to), isLocked(swap) {
            return .immovable
        }
        return board.rejection(for: swap, in: activeRange)
    }

    /// 큰 물질이 끼었거나 끈끈이 바닥 위의 블록을 움직이는 스왑인지.
    private func isLocked(_ swap: Swap) -> Bool {
        if sticky.contains(swap.from) || sticky.contains(swap.to) {
            return true
        }
        return materials.contains { $0.isLarge && ($0.contains(swap.from) || $0.contains(swap.to)) }
    }

    /// `board`의 활성 구간에 가능한 이동이 있는지. 물질 덩어리는 지금 위치 그대로라고 본다.
    private func hasPossibleMove(on board: Board) -> Bool {
        board.possibleMoves(in: activeRange).contains { !isLocked($0) }
    }

    /// 이미 만들어진 보드로 상태를 만든다.
    ///
    /// `materials`를 생략하면 보드의 `.material` 칸을 각각 한 칸짜리 물질로 본다.
    /// 큰 물질이 있으면 덩어리 목록을 넘겨야 하고, 덮은 칸은 보드에서 모두 `.material`이어야 한다.
    public init(
        board: Board,
        blockTypes: Int = GameConstants.blockTypes,
        generator: SeededGenerator,
        activeTop: Int = 0,
        movesRemaining: Int? = nil,
        pendingMaterials: [PendingMaterial] = [],
        materials: [MaterialPiece]? = nil,
        blocksSlide: Bool = true,
        containerColumns: ClosedRange<Int>? = nil,
        materialsSlide: Bool = false
    ) {
        precondition(GameConstants.blockTypeRange.contains(blockTypes), "블록 종류 수가 범위를 벗어났다")
        precondition(
            pendingMaterials.allSatisfy { (0..<board.columns).contains($0.column) && $0.depth >= 0 },
            "대기 물질의 열이나 깊이가 범위를 벗어났다"
        )
        precondition(
            containerColumns.map { $0.lowerBound >= 0 && $0.upperBound < board.columns } ?? true,
            "수거함의 열이 보드 밖이다"
        )
        self.pendingMaterials = pendingMaterials
        self.blocksSlide = blocksSlide
        self.containerColumns = containerColumns
        self.materialsSlide = materialsSlide
        self.board = board
        self.blockTypes = blockTypes
        self.generator = generator
        self.activeTop = activeTop
        self.movesRemaining = movesRemaining
        let cells = board.positions.filter { board[$0] == .material }
        let pieces = materials ?? cells.map { MaterialPiece(origin: $0) }
        precondition(
            pieces.flatMap(\.cells).sorted() == cells,
            "물질 덩어리가 보드의 물질 칸과 맞지 않는다"
        )
        self.materials = pieces
        materialsTotal = pieces.count + pendingMaterials.count
        status = .playing
    }

    /// 시드로 새 판을 만든다. 같은 시드는 항상 같은 보드를 만든다.
    ///
    /// 물질이 없는 칸은 무작위 블록으로 채운다. 만들어진 보드에는 맞춰진 매치가 없고
    /// 첫 활성 구간에 가능한 이동이 1개 이상 있다(9장).
    public init(
        seed: UInt64,
        columns: Int = GameConstants.columns,
        rows: Int = GameConstants.activeRows,
        blockTypes: Int = GameConstants.blockTypes,
        moves: Int? = nil,
        materials: [Position] = [],
        pendingMaterials: [PendingMaterial] = [],
        materialPieces: [MaterialPiece] = [],
        obstacles: [Obstacle] = [],
        blocksSlide: Bool = true,
        containerColumns: ClosedRange<Int>? = nil,
        materialsSlide: Bool = false
    ) {
        var board = Board(columns: columns, rows: rows)
        // `materials`는 한 칸짜리, `materialPieces`는 크기를 정한 물질이다.
        let pieces = materials.map { MaterialPiece(origin: $0) } + materialPieces
        for position in pieces.flatMap(\.cells) {
            precondition(board.contains(position), "물질의 좌표가 보드 밖이다")
            precondition(board[position] == nil, "물질이 겹친다")
            board[position] = .material
        }
        // 콘크리트와 슬러지는 칸을 차지한다. 철망과 시한 포자는 블록을 채운 뒤에 씌운다.
        var cages: [Position] = []
        var timers: [Position: Int] = [:]
        var fog: Set<Position> = []
        var sticky: Set<Position> = []
        var shields: Set<Position> = []
        var chains: [Position] = []
        var ice: [Position] = []
        for obstacle in obstacles {
            precondition(board.contains(obstacle.position), "장애물의 좌표가 보드 밖이다")
            precondition(board[obstacle.position] == nil && !cages.contains(obstacle.position) && timers[obstacle.position] == nil && !fog.contains(obstacle.position) && !sticky.contains(obstacle.position)
                    && !shields.contains(obstacle.position) && !chains.contains(obstacle.position) && !ice.contains(obstacle.position),
                "장애물이 겹친다"
            )
            switch obstacle.kind {
            case .concrete(let hp):
                precondition(hp >= 1, "콘크리트의 hp는 1 이상이어야 한다")
                board[obstacle.position] = .concrete(hp: hp)
            case .sludge:
                board[obstacle.position] = .sludge
            case .wall:
                board[obstacle.position] = .wall
            case .cocoon(let kind):
                board[obstacle.position] = .cocoon(kind)
            case .rubble:
                board[obstacle.position] = .rubble
            case .nest(let hp):
                precondition(hp >= 1, "포자 둥지의 hp는 1 이상이어야 한다")
                board[obstacle.position] = .nest(hp: hp)
            case .cage:
                cages.append(obstacle.position)
            case .timer(let turns):
                precondition(turns >= 1, "시한 포자의 턴은 1 이상이어야 한다")
                timers[obstacle.position] = turns
            case .fog:
                fog.insert(obstacle.position)
            case .sticky:
                sticky.insert(obstacle.position)
            case .egg:
                board[obstacle.position] = .egg
            case .boulder:
                board[obstacle.position] = .boulder
            case .vent(let hp):
                precondition(hp >= 1, "안개 굴뚝의 hp는 1 이상이어야 한다")
                board[obstacle.position] = .vent(hp: hp)
            case .shield:
                shields.insert(obstacle.position)
            case .chain:
                chains.append(obstacle.position)
            case .ice:
                ice.append(obstacle.position)
            }
        }
        self.init(
            board: board,
            blockTypes: blockTypes,
            generator: SeededGenerator(seed: seed),
            movesRemaining: moves,
            pendingMaterials: pendingMaterials,
            materials: pieces,
            blocksSlide: blocksSlide,
            containerColumns: containerColumns,
            materialsSlide: materialsSlide
        )
        // 끈끈이 위의 블록은 밀 수 없으므로, 보드를 만들 때 둘 곳이 있는지 볼 때부터 알고 있어야 한다.
        self.sticky = sticky
        generateBoard(cages: cages, timers: timers, chains: chains, ice: ice)
        self.fog = fog
        self.shields = shields
    }

    // MARK: - 턴 처리

    /// 스왑 한 번을 처리한다.
    ///
    /// 유효한 스왑이면 교환, 매치 제거와 특수 블록 발동, 낙하, 보충을 새 매치가 없을 때까지 반복하고,
    /// 가능한 이동이 없으면 셔플한다. 유효하지 않으면 상태는 그대로이고
    /// `swapRejected` 이벤트 하나만 나온다.
    public func performTurn(_ swap: Swap) -> TurnResult {
        if let rejection = rejection(for: swap) {
            return TurnResult(state: self, events: [.swapRejected(swap, rejection)])
        }
        var next = self
        next.sludgeClearedThisTurn = false
        // 유효한 스왑 한 번에 1씩 준다. 연쇄, 셔플, 스크롤 후 자동 매치는 줄이지 않는다(6장).
        if let moves = next.movesRemaining {
            next.movesRemaining = moves - 1
        }
        next.board.swapAt(swap.from, swap.to)
        // 한 칸짜리 물질이 스왑으로 옮겨졌으면 위치를 따라 바꾼다.
        for index in next.materials.indices {
            if next.materials[index].origin == swap.from {
                next.materials[index].origin = swap.to
            } else if next.materials[index].origin == swap.to {
                next.materials[index].origin = swap.from
            }
        }
        var events: [GameEvent] = [.swapped(swap)]
        if let effect = next.swapEffect(of: swap) {
            // 특수 블록은 스왑하면 매치 없이 바로 발동한다. 뒤따르는 매치는 연쇄 2부터다.
            events += next.liftingFog(next.activateSwapEffect(effect, swap: swap))
            events += next.dropAndRefill()
            events += next.settleInPlace(swap: nil, firstChain: 2, isPlayerTurn: true)
        } else {
            events += next.settleInPlace(swap: swap, firstChain: 1, isPlayerTurn: true)
        }
        return TurnResult(state: next, events: events)
    }

    /// 이동 횟수를 다 써서 진 판인지. 그런 판은 이동 횟수를 더 받아 이어 할 수 있다(6장).
    /// 섞어도 둘 곳이 없어서 진 판은 이어 할 수 없다.
    public var canContinue: Bool {
        status == .lost && movesRemaining == 0
    }

    /// 진 판을 이동 횟수를 더 받아 이어 한다. 보드와 점수는 그대로다.
    /// - Returns: 이어 했는지. 이어 할 수 없는 판이면 `false`이고 아무것도 바뀌지 않는다.
    @discardableResult
    public mutating func continuePlaying(extraMoves: Int) -> Bool {
        guard canContinue, extraMoves > 0 else { return false }
        movesRemaining = extraMoves
        status = .playing
        return true
    }

    /// 스왑 없이 보드를 안정시킨다. 매치가 있으면 연쇄로 처리하고, 가능한 이동이 없으면 셔플한다.
    public func settle() -> TurnResult {
        var next = self
        let events = next.settleInPlace(swap: nil, firstChain: 1, isPlayerTurn: false)
        return TurnResult(state: next, events: events)
    }

    /// 연쇄, 물질 수거, 카메라 이동을 더 일어날 일이 없을 때까지 돌리고 승패를 판정한다.
    private mutating func settleInPlace(swap: Swap?, firstChain: Int, isPlayerTurn: Bool) -> [GameEvent] {
        var events: [GameEvent] = []
        var chain = firstChain
        var swap = swap
        while true {
            events += collectMaterials()
            let matches = board.findMatches(in: activeRange)
            if !matches.isEmpty {
                events += liftingFog(clear(matches, chain: chain, swap: swap))
                events += dropAndRefill()
                chain += 1
                swap = nil
                continue
            }
            // 연쇄가 끝나면 카메라를 옮긴다. 새로 들어온 행에서 매치가 생기면 다시 연쇄다.
            if let scroll = scrollCamera() {
                events.append(scroll)
                continue
            }
            break
        }
        // 승패는 연쇄가 다 끝난 뒤에만 판정한다. 마지막 이동에서 모두 수거하면 클리어다(2장).
        if materialsTotal > 0, materialsRemaining == 0 {
            // 화면에 남은 특수 블록을 모두 터뜨리고 나서 점수를 마감한다.
            events += detonateRemainingSpecials()
            status = .won
            score += (movesRemaining ?? 0) * GameConstants.scorePerRemainingMove
            events.append(.won)
            return events
        }
        // 슬러지를 하나도 제거하지 못한 턴에는 슬러지가 한 칸 번진다(7장).
        if isPlayerTurn, !sludgeClearedThisTurn, let spread = spreadSludge() {
            events.append(spread)
        }
        // 포자 둥지는 몇 턴마다 옆 칸에 슬러지를 뱉는다(7장).
        if isPlayerTurn, let spat = spitFromNests() {
            events.append(spat)
        }
        // 안개 굴뚝은 몇 턴마다 옆 칸에 안개를 뿜는다(7장).
        if isPlayerTurn, let puffed = puffFromVents() {
            events.append(puffed)
        }
        // 시한 포자는 턴마다 숫자가 줄고, 0이 되면 터진다(7장).
        if isPlayerTurn {
            events += tickTimers()
        }
        if movesRemaining == 0 {
            status = .lost
            events.append(.lost)
        } else if !hasPossibleMove(on: board) {
            if let shuffled = shuffle() {
                events.append(shuffled)
            } else if let rescue = rescueWithBomb() {
                // 장애물에 막혀 섞어도 둘 곳이 없으면 중화 폭탄 하나를 놓아 준다. 플레이어의 잘못 없이 지지 않게 한다.
                events.append(rescue)
            } else {
                // 그래도 둘 곳이 없으면 더 진행할 수 없다.
                status = .lost
                events.append(.lost)
            }
        }
        return events
    }

    /// 클리어한 뒤 활성 구간에 남은 특수 블록을 모두 발동한다(6장).
    ///
    /// 한 번에 다 터뜨리고, 그 뒤의 낙하와 연쇄로 새 특수 블록이 생기면 다시 터뜨린다.
    /// 제거한 블록은 평소처럼 점수가 된다. 끝없이 이어지지 않게 횟수에 상한을 둔다.
    private mutating func detonateRemainingSpecials() -> [GameEvent] {
        var events: [GameEvent] = []
        for _ in 0..<Self.maximumFinalDetonations {
            let specials = board.positions(in: activeRange).filter { board[$0]?.isSpecial == true }
            guard !specials.isEmpty else { break }
            // 특수 블록 자신이 놓인 칸도 효과의 범위에 들어 있어서, 발동 기록의 지워진 칸에 함께 적힌다.
            // 미리 지워진 것으로 쳐 두면 기록에서 빠져 화면에 그 블록이 남는다.
            var removed: Set<Position> = []
            var triggered = Set(specials)
            var hits: Set<Position> = []
            let activations = resolve(
                specials.compactMap { position in board[position]?.effect.map { (position, $0) } },
                removed: &removed, triggered: &triggered, hits: &hits, protected: []
            )
            for position in removed {
                board[position] = nil
            }
            score += removed.count * GameConstants.scorePerBlock
            events.append(.specialsActivated(activations))
            events += damageObstacles(at: hits)
            events += dropAndRefill()
            // 떨어진 블록이 맞춰지면 평소의 연쇄처럼 지운다.
            var chain = 1
            while true {
                let matches = board.findMatches(in: activeRange)
                if matches.isEmpty { break }
                events += clear(matches, chain: chain, swap: nil)
                events += dropAndRefill()
                chain += 1
            }
        }
        return events
    }

    /// 낙하와 보충을 처리한다. 흘러내림을 켰으면 막힌 빈칸이 더 채워지지 않을 때까지 이어서 돌린다.
    private mutating func dropAndRefill() -> [GameEvent] {
        var events: [GameEvent] = []
        while true {
            // 물질이 먼저 움직인다. 방금 생긴 빈칸을 위의 블록이 메우기 전에 대각선 위의 물질이 흘러든다.
            let flows = slideMaterials()
            if !flows.isEmpty {
                events.append(.slid(flows))
            }
            let falls = board.applyGravity(in: activeRange, pieces: &materials)
            if !falls.isEmpty {
                events.append(.fell(falls))
            }
            let spawns = refill()
            if !spawns.isEmpty {
                events.append(.refilled(spawns))
            }
            guard blocksSlide else { break }
            // 낙하와 보충 뒤에도 남은 빈칸은 모두 위가 막힌 칸이다.
            let slides = slideIntoGaps()
            if slides.isEmpty { break }
            events.append(.slid(slides))
        }
        return events
    }

    /// 빈칸마다 대각선 위의 블록 하나를 끌어온다.
    ///
    /// 물질은 미끄러지지 않는다. 큰 물질 아래에 깔린 블록도 미끄러지지 않는다. 깔린 블록이 빠져나가면
    /// 한쪽 아래에 구멍 하나만 파도 반대쪽 받침이 흘러나와 물질이 내려가 버리기 때문이다.
    /// 그래서 빈칸은 물질 바깥쪽 열의 블록으로만 채워지고, 양쪽이 모두 막힌 칸은 빈 채로 남는다.
    ///
    /// 왼쪽 위와 오른쪽 위 가운데 어느 쪽을 먼저 볼지는 칸의 위치로 정해 한쪽으로 쏠리지 않게 한다.
    private mutating func slideIntoGaps() -> [BlockMove] {
        let range = activeRange
        let gaps = board.positions(in: range).reversed().filter { board[$0] == nil }
        var moves: [BlockMove] = []
        for gap in gaps where gap.row - 1 >= range.lowerBound && board[gap] == nil {
            let sides = (gap.column + gap.row).isMultiple(of: 2) ? [-1, 1] : [1, -1]
            for side in sides {
                let source = Position(column: gap.column + side, row: gap.row - 1)
                guard board.contains(source), let block = board[source], block.canSlide,
                      !isUnderLargeMaterial(source)
                else { continue }
                board[gap] = block
                board[source] = nil
                moves.append(BlockMove(from: source, to: gap))
                break
            }
        }
        return moves
    }

    /// 한 칸짜리 물질을 대각선 아래의 빈칸으로 한 칸씩 흘려보낸다(5장).
    ///
    /// 바로 아래가 비어 있으면 그냥 떨어지므로 여기서는 다루지 않는다. 아래가 막혀 있고 대각선 아래가
    /// 비어 있을 때만 움직인다. 양쪽이 다 비어 있으면 수거함에 가까워지는 쪽으로 간다.
    /// 큰 물질은 흘러가지 않는다.
    private mutating func slideMaterials() -> [BlockMove] {
        guard materialsSlide else { return [] }
        let range = activeRange
        var moves: [BlockMove] = []
        // 아래쪽 물질부터 본다. 아래 물질이 비켜난 자리로 위 물질이 이어서 내려올 수 있다.
        let order = materials.indices
            .filter { !materials[$0].isLarge }
            .sorted { materials[$0].origin.row > materials[$1].origin.row }
        for index in order {
            let origin = materials[index].origin
            let below = Position(column: origin.column, row: origin.row + 1)
            guard range.contains(origin.row), range.contains(below.row), board[below] != nil else { continue }
            let targets = slideSides(from: origin.column)
                .map { Position(column: origin.column + $0, row: below.row) }
                .filter { board.contains($0) && board[$0] == nil }
            guard let target = targets.first else { continue }
            board[target] = .material
            board[origin] = nil
            materials[index].origin = target
            moves.append(BlockMove(from: origin, to: target))
        }
        return moves
    }

    /// 물질이 `column`에서 옆으로 흘러갈 때 먼저 볼 방향. 수거함 쪽이 먼저다.
    private func slideSides(from column: Int) -> [Int] {
        if let container = containerColumns {
            if column < container.lowerBound { return [1, -1] }
            if column > container.upperBound { return [-1, 1] }
        }
        return column.isMultiple(of: 2) ? [-1, 1] : [1, -1]
    }

    /// 같은 열의 큰 물질 아래에 있는 칸인지.
    func isUnderLargeMaterial(_ position: Position) -> Bool {
        materials.contains { $0.isLarge && $0.columns.contains(position.column) && $0.bottomRow < position.row }
    }

    // MARK: - 물질과 카메라

    /// 보드의 마지막 행에 닿은 물질을 수거한다. 큰 물질은 맨 아래 행이 닿으면 통째로 수거된다.
    /// 수거함이 좁으면 수거함이 놓인 열에 닿은 물질만 수거한다.
    private mutating func collectMaterials() -> [GameEvent] {
        var events: [GameEvent] = []
        let lastRow = board.rows - 1
        func reachesContainer(_ piece: MaterialPiece) -> Bool {
            guard piece.bottomRow == lastRow else { return false }
            guard let container = containerColumns else { return true }
            return piece.columns.allSatisfy { container.contains($0) }
        }
        while activeRange.contains(lastRow) {
            let collected = materials.filter(reachesContainer)
            if collected.isEmpty { break }
            materials.removeAll(where: reachesContainer)
            let cells = collected.flatMap(\.cells).sorted()
            for position in cells {
                board[position] = nil
            }
            events.append(.materialsCollected(cells))
            events += dropAndRefill()
        }
        return events
    }

    /// 활성 구간의 맨 위를 가장 위에 있는 물질의 한 행 위로 내린다. 위로는 돌아가지 않는다.
    ///
    /// 보드에 나와 있는 물질만 본다. 대기 중인 물질은 카메라를 붙잡지 않고,
    /// 나중에 그때의 활성 구간 맨 위로 들어온다.
    private mutating func scrollCamera() -> GameEvent? {
        guard let topmost = materials.map(\.origin.row).min() else { return nil }
        let lowest = max(board.rows - GameConstants.activeRows, 0)
        let target = min(max(topmost - 1, 0), lowest)
        guard target > activeTop else { return nil }
        // 지나간 행은 버린다.
        for row in activeTop..<target {
            for column in 0..<board.columns {
                board[column, row] = nil
            }
        }
        defer { activeTop = target }
        return .scrolled(from: activeTop, to: target)
    }

    // MARK: - 매치 제거와 특수 블록 생성

    /// 매치를 제거한다. 매치에 든 특수 블록은 발동하고, 4개 이상이나 L·T 모양은 특수 블록을 남긴다.
    private mutating func clear(_ matches: [Match], chain: Int, swap: Swap?) -> [GameEvent] {
        var spawns: [SpecialSpawn] = []
        for match in matches {
            guard let special = match.createdSpecial else { continue }
            // 플레이어가 움직인 블록 자리에 둔다. 연쇄 중이면 매치의 가운데 칸이다.
            let position = [swap?.to, swap?.from].compactMap { $0 }.first(where: match.positions.contains)
                ?? match.center
            spawns.append(SpecialSpawn(position: position, block: Block(special: special)))
        }

        var removed = Set(matches.flatMap(\.positions))
        var triggered: Set<Position> = []
        var queue: [(Position, SpecialEffect)] = []
        for position in removed.sorted() {
            if let effect = board[position]?.effect {
                triggered.insert(position)
                queue.append((position, effect))
            }
        }
        // 매치 옆에 붙은 콘크리트와 슬러지는 피해를 입는다.
        var hits: Set<Position> = []
        // 매치에 든 철망은 철망만 벗겨지고 블록은 남는다.
        releaseCaged(from: &removed, into: &hits)
        for match in matches {
            for cell in match.positions {
                for neighbor in neighbors(of: cell) where board[neighbor]?.takesAdjacentHits == true {
                    // 오염 고치는 갇힌 것과 같은 종류의 매치에만 터진다.
                    if case .cocoon(let kind) = board[neighbor], kind != match.kind { continue }
                    hits.insert(neighbor)
                }
            }
        }
        // 이번에 생기는 특수 블록은 같은 단계의 효과에 지워지지 않는다.
        let activations = resolve(
            queue, removed: &removed, triggered: &triggered, hits: &hits,
            protected: Set(spawns.map(\.position))
        )

        for position in removed {
            board[position] = nil
        }
        for spawn in spawns {
            board[spawn.position] = spawn.block
        }
        // 매치와 효과로 제거한 블록 수에 연쇄 번호를 곱한다. 장애물과 벗겨진 철망은 세지 않는다.
        // 연쇄 배수는 상한까지만 오른다. 길게 이어진 연쇄 한 번이 점수를 좌우하지 않게 한다.
        score += removed.count * GameConstants.scorePerBlock * min(chain, GameConstants.maximumChainMultiplier)

        var events: [GameEvent] = [.matchesCleared(matches, chain: chain)]
        if !activations.isEmpty {
            events.append(.specialsActivated(activations))
        }
        events += damageObstacles(at: hits)
        if !spawns.isEmpty {
            events.append(.specialsCreated(spawns))
        }
        return events
    }

    // MARK: - 특수 블록 발동

    /// 스왑한 두 블록이 매치 없이 내는 효과. 스왑을 적용한 뒤의 보드에서 본다.
    private func swapEffect(of swap: Swap) -> SpecialEffect? {
        // 시한 포자가 붙은 블록은 보통 블록처럼 다룬다.
        guard let first = board[swap.from]?.withoutTimer, let second = board[swap.to]?.withoutTimer else { return nil }
        switch (first, second) {
        case (.core, .core):
            return .clearBoard
        case (.core, .beam), (.beam, .core):
            // 빔과 폭탄에는 종류가 없으므로 가장 많이 남은 종류를 대상으로 한다.
            return mostCommonKind(excluding: []).map(SpecialEffect.coreBeam) ?? .core(nil)
        case (.core, .bomb), (.bomb, .core):
            return mostCommonKind(excluding: []).map(SpecialEffect.coreBomb) ?? .core(nil)
        case (.core, .normal(let kind)), (.normal(let kind), .core):
            return .core(kind)
        case (.core, .drone), (.drone, .core):
            return mostCommonKind(excluding: []).map(SpecialEffect.coreDrone) ?? .core(nil)
        case (.drone, .drone):
            return .droneSwarm([])
        case (.drone, .beam(let orientation)), (.beam(let orientation), .drone):
            return .droneBeam(orientation, nil)
        case (.drone, .bomb), (.bomb, .drone):
            return .droneBomb(nil)
        case (.drone, .normal), (.normal, .drone):
            return .drone(nil)
        case (.beam, .beam):
            return .crossBeam
        case (.beam, .bomb), (.bomb, .beam):
            return .wideCrossBeam
        case (.bomb, .bomb):
            return .bigBomb
        // 빔이나 폭탄을 일반 블록과 스왑하면 옮겨 간 자리에서 혼자 발동한다.
        case (.beam(let orientation), .normal), (.normal, .beam(let orientation)):
            return .beam(orientation)
        case (.bomb, .normal), (.normal, .bomb):
            return .bomb
        default:
            return nil
        }
    }

    private mutating func activateSwapEffect(_ effect: SpecialEffect, swap: Swap) -> [GameEvent] {
        let zone = board.positions(in: activeRange)
        var events: [GameEvent] = []
        var removed: Set<Position> = []
        var hits: Set<Position> = []
        // 스왑한 두 블록은 이 효과로 쓰였으므로 각자의 효과를 따로 내지 않는다.
        var triggered: Set<Position> = [swap.from, swap.to]
        // 조합 효과의 중심은 블록을 옮겨 놓은 칸이다. 정화 코어가 끼면 코어가 놓인 칸이다.
        let corePosition = board[swap.to] == .core ? swap.to : swap.from
        // 특수 블록 하나가 혼자 발동할 때의 중심은 그 블록이 옮겨 간 칸이다.
        let specialPosition = board[swap.to]?.isSpecial == true ? swap.to : swap.from

        switch effect {
        case .clearBoard:
            let all = zone.filter {
                guard let block = board[$0], !shields.contains($0) else { return false }
                return !block.isIndestructible && !block.takesHits
            }
            removed = Set(all)
            hits = Set(zone.filter { board[$0]?.takesHits == true && !shields.contains($0) })
            events.append(.specialsActivated([SpecialActivation(origin: swap.to, effect: effect, cleared: all)]))

        case .coreBeam(let kind), .coreBomb(let kind), .coreDrone(let kind):
            removed = [corePosition]
            events.append(.specialsActivated([
                SpecialActivation(origin: corePosition, effect: effect, cleared: [corePosition])
            ]))
            // 해당 종류의 일반 블록을 모두 특수 블록으로 바꾼다. 이미 특수 블록이면 그대로 둔다.
            var spawns: [SpecialSpawn] = []
            for position in zone where board[position] == .normal(kind) {
                let block: Block
                switch effect {
                case .coreBeam:
                    // 방향은 칸의 위치로 정한다. 난수를 쓰지 않아 결과를 예측할 수 있다.
                    block = .beam((position.column + position.row).isMultiple(of: 2) ? .horizontal : .vertical)
                case .coreDrone:
                    block = .drone
                default:
                    block = .bomb
                }
                board[position] = block
                spawns.append(SpecialSpawn(position: position, block: block))
            }
            if !spawns.isEmpty {
                events.append(.specialsCreated(spawns))
            }
            // 바뀐 블록과, 코어와 스왑한 빔이나 폭탄이 모두 발동한다.
            let partner = corePosition == swap.to ? swap.from : swap.to
            var queue: [(Position, SpecialEffect)] = []
            for position in (spawns.map(\.position) + [partner]).sorted() {
                if let blockEffect = board[position]?.effect {
                    triggered.insert(position)
                    queue.append((position, blockEffect))
                }
            }
            let activations = resolve(queue, removed: &removed, triggered: &triggered, hits: &hits, protected: [])
            if !activations.isEmpty {
                events.append(.specialsActivated(activations))
            }

        default:
            let origin: Position
            switch effect {
            case .core:
                origin = corePosition
            case .beam, .bomb, .drone:
                origin = specialPosition
            default:
                origin = swap.to
            }
            let activations = resolve(
                [(origin, effect)], removed: &removed, triggered: &triggered, hits: &hits, protected: []
            )
            events.append(.specialsActivated(activations))
        }

        for position in removed {
            board[position] = nil
        }
        // 스왑 조합은 연쇄 1로 친다.
        score += removed.count * GameConstants.scorePerBlock
        events += damageObstacles(at: hits)
        return events
    }

    /// 효과를 차례로 적용한다. 효과에 맞은 특수 블록은 뒤이어 발동한다.
    ///
    /// 보드는 바꾸지 않고 `removed`에 제거될 칸을, `hits`에 효과가 닿은 장애물을 모은다.
    private func resolve(
        _ initial: [(Position, SpecialEffect)],
        removed: inout Set<Position>,
        triggered: inout Set<Position>,
        hits: inout Set<Position>,
        protected: Set<Position>
    ) -> [SpecialActivation] {
        var queue = initial
        var activations: [SpecialActivation] = []
        var index = 0
        while index < queue.count {
            var (origin, effect) = queue[index]
            index += 1
            if case .core(nil) = effect {
                // 다른 효과에 맞아 발동한 정화 코어는 보드에 가장 많이 남은 종류를 제거한다.
                effect = .core(mostCommonKind(excluding: removed))
            }
            // 청소 드론의 목표는 발동하는 순간에 정한다. 앞서 지워지기로 한 칸과 이미 고른 목표는 피한다.
            let taken = removed.union(hits).union(protected).union(cross(of: origin))
            switch effect {
            case .drone(nil):
                effect = .drone(droneTargets(1, excluding: taken).first)
            case .droneSwarm(let picked) where picked.isEmpty:
                effect = .droneSwarm(droneTargets(3, excluding: taken))
            case .droneBeam(let orientation, nil):
                effect = .droneBeam(orientation, droneTargets(1, excluding: taken).first)
            case .droneBomb(nil):
                effect = .droneBomb(droneTargets(1, excluding: taken).first)
            default:
                break
            }
            var cleared: [Position] = []
            for target in targets(of: effect, at: origin) where !protected.contains(target) {
                // 오염 물질과 벽은 어떤 효과로도 제거되지 않는다.
                guard let block = board[target], !block.isIndestructible else { continue }
                // 콘크리트, 슬러지, 철망은 바로 지워지지 않고 피해를 한 번 입는다.
                if block.takesHits {
                    hits.insert(target)
                    continue
                }
                if removed.insert(target).inserted {
                    cleared.append(target)
                }
                if let chained = block.effect, triggered.insert(target).inserted {
                    queue.append((target, chained))
                }
            }
            activations.append(SpecialActivation(origin: origin, effect: effect, cleared: cleared))
        }
        return activations
    }

    /// 활성 구간 안의 상하좌우 이웃 칸.
    private func neighbors(of position: Position) -> [Position] {
        [(0, -1), (0, 1), (-1, 0), (1, 0)]
            .map { Position(column: position.column + $0.0, row: position.row + $0.1) }
            .filter { board.contains($0) && activeRange.contains($0.row) }
    }

    /// 제거될 칸 가운데 철망에 갇힌 블록을 빼서 피해 목록으로 옮긴다.
    private func releaseCaged(from removed: inout Set<Position>, into hits: inout Set<Position>) {
        for position in removed {
            switch board[position] {
            case .caged, .chained: hits.insert(position)
            default: break
            }
        }
        removed.subtract(hits)
    }

    /// 장애물에 피해를 한 번씩 준다. 콘크리트는 hp가 1 줄고, 슬러지는 없어지고,
    /// 철망은 벗겨져 안의 블록이 일반 블록으로 남는다.
    /// 한 단계에서 매치와 효과가 함께 닿아도 한 번만 센다.
    private mutating func damageObstacles(at hits: Set<Position>) -> [GameEvent] {
        var damaged: [ObstacleHit] = []
        for position in hits.sorted() {
            switch board[position] {
            case .concrete(let hp):
                board[position] = hp > 1 ? .concrete(hp: hp - 1) : nil
            case .sludge:
                board[position] = nil
                sludgeClearedThisTurn = true
            case .nest(let hp):
                board[position] = hp > 1 ? .nest(hp: hp - 1) : nil
            case .cocoon, .rubble, .egg:
                board[position] = nil
            case .caged(let kind), .frozen(let kind):
                board[position] = .normal(kind)
            case .chained(let kind):
                board[position] = .caged(kind)
            case .vent(let hp):
                board[position] = hp > 1 ? .vent(hp: hp - 1) : nil
            case .boulder:
                board[position] = nil
            default:
                continue
            }
            damaged.append(ObstacleHit(position: position, remaining: board[position]))
        }
        return damaged.isEmpty ? [] : [.obstaclesDamaged(damaged)]
    }

    /// 슬러지가 옆 칸의 일반 블록 하나를 덮는다. 덮을 칸은 시드 난수로 고른다.
    private mutating func spreadSludge() -> GameEvent? {
        let zone = board.positions(in: activeRange)
        // 화면의 슬러지가 상한에 이르면 더 번지지 않는다. 슬러지가 화면을 덮어 블록이 들어올 길까지 막으면
        // 둘 곳이 없어져 판이 그대로 끝나 버리기 때문이다.
        guard zone.count(where: { board[$0] == .sludge }) < GameConstants.sludgeSpreadLimit else { return nil }
        var targets: Set<Position> = []
        for position in zone where board[position] == .sludge {
            for neighbor in neighbors(of: position) {
                if case .normal = board[neighbor] {
                    targets.insert(neighbor)
                }
            }
        }
        guard !targets.isEmpty else { return nil }
        let target = targets.sorted()[generator.nextInt(below: targets.count)]
        board[target] = .sludge
        return .sludgeSpread([target])
    }

    /// 활성 구간의 포자 둥지가 옆 칸의 일반 블록 하나씩을 슬러지로 바꾼다. 뱉을 차례가 아니면 턴만 센다.
    /// 둥지가 없으면 세지 않고, 처음 화면에 들어온 뒤로 정해진 턴이 지나야 뱉는다.
    private mutating func spitFromNests() -> GameEvent? {
        let nests = board.positions(in: activeRange).filter {
            if case .nest = board[$0] { return true }
            return false
        }
        guard !nests.isEmpty else {
            turnsUntilNestSpit = GameConstants.nestSpitInterval
            return nil
        }
        turnsUntilNestSpit -= 1
        guard turnsUntilNestSpit <= 0 else { return nil }
        turnsUntilNestSpit = GameConstants.nestSpitInterval
        var spits: [NestSpit] = []
        for nest in nests.sorted() {
            let targets = neighbors(of: nest).filter {
                if case .normal = board[$0] { return true }
                return false
            }.sorted()
            guard !targets.isEmpty else { continue }
            let target = targets[generator.nextInt(below: targets.count)]
            board[target] = .sludge
            spits.append(NestSpit(nest: nest, target: target))
        }
        return spits.isEmpty ? nil : .nestsSpat(spits)
    }

    /// 매치나 효과가 닿은 칸의 안개를 걷고, 걷힌 칸이 있으면 이벤트를 덧붙인다.
    /// 매치는 매치된 칸과 그 상하좌우에, 특수 효과는 효과가 지운 칸에 닿는다.
    private mutating func liftingFog(_ events: [GameEvent]) -> [GameEvent] {
        guard !fog.isEmpty || !sticky.isEmpty || !shields.isEmpty else { return events }
        var touched: Set<Position> = []
        // 보호막은 그 칸의 블록이 매치돼야 깨진다.
        var matched: Set<Position> = []
        // 끈끈이 바닥은 그 칸이 직접 맞아야 없어진다. 옆 칸의 매치로는 없어지지 않는다.
        var struck: Set<Position> = []
        for event in events {
            switch event {
            case .matchesCleared(let matches, _):
                for cell in matches.flatMap(\.positions) {
                    struck.insert(cell)
                    matched.insert(cell)
                    touched.insert(cell)
                    touched.formUnion(neighbors(of: cell))
                }
            case .specialsActivated(let activations):
                for activation in activations {
                    touched.insert(activation.origin)
                    touched.formUnion(activation.cleared)
                    struck.insert(activation.origin)
                    struck.formUnion(activation.cleared)
                }
            case .obstaclesDamaged(let hits):
                touched.formUnion(hits.map(\.position))
                struck.formUnion(hits.map(\.position))
            default:
                break
            }
        }
        var events = events
        let lifted = fog.intersection(touched).sorted()
        if !lifted.isEmpty {
            fog.subtract(lifted)
            events.append(.fogLifted(lifted))
        }
        let cleaned = sticky.intersection(struck).sorted()
        if !cleaned.isEmpty {
            sticky.subtract(cleaned)
            events.append(.stickyCleared(cleaned))
        }
        let broken = shields.intersection(matched).sorted()
        if !broken.isEmpty {
            shields.subtract(broken)
            events.append(.shieldsBroken(broken))
        }
        return events
    }

    /// 활성 구간의 안개 굴뚝이 안개가 없는 옆 칸 하나씩에 안개를 뿜는다. 뿜을 차례가 아니면 턴만 센다.
    private mutating func puffFromVents() -> GameEvent? {
        let vents = board.positions(in: activeRange).filter {
            if case .vent = board[$0] { return true }
            return false
        }
        guard !vents.isEmpty else {
            turnsUntilVentPuff = GameConstants.nestSpitInterval
            return nil
        }
        turnsUntilVentPuff -= 1
        guard turnsUntilVentPuff <= 0 else { return nil }
        turnsUntilVentPuff = GameConstants.nestSpitInterval
        var puffed: [Position] = []
        for vent in vents.sorted() {
            let targets = neighbors(of: vent).filter { !fog.contains($0) && board[$0] != .wall }.sorted()
            guard !targets.isEmpty else { continue }
            let target = targets[generator.nextInt(below: targets.count)]
            fog.insert(target)
            puffed.append(target)
        }
        return puffed.isEmpty ? nil : .ventsPuffed(puffed)
    }

    /// 활성 구간에 있는 시한 포자의 숫자를 1씩 줄인다. 0이 된 것은 터져서 제자리와 옆 칸의 일반 블록을 슬러지로 덮는다.
    private mutating func tickTimers() -> [GameEvent] {
        var ticks: [TimerTick] = []
        var expired: [Position] = []
        for position in board.positions(in: activeRange).sorted() {
            guard case .timed(let kind, let turns) = board[position] else { continue }
            if turns > 1 {
                board[position] = .timed(kind, turns: turns - 1)
                ticks.append(TimerTick(position: position, turns: turns - 1))
            } else {
                expired.append(position)
            }
        }
        var bursts: [TimerBurst] = []
        for position in expired {
            var sludge = [position]
            board[position] = .sludge
            for neighbor in neighbors(of: position).sorted() {
                if case .normal = board[neighbor] {
                    board[neighbor] = .sludge
                    sludge.append(neighbor)
                }
            }
            bursts.append(TimerBurst(position: position, sludge: sludge))
        }
        var events: [GameEvent] = []
        if !ticks.isEmpty { events.append(.timersTicked(ticks)) }
        if !bursts.isEmpty { events.append(.timersBurst(bursts)) }
        return events
    }

    /// 효과가 닿는 칸. 활성 구간 안으로 한정한다(4장).
    private func targets(of effect: SpecialEffect, at origin: Position) -> [Position] {
        // 보호막이 덮인 칸에는 효과가 닿지 않는다. 효과를 내는 블록이 선 칸은 뺀다.
        rawTargets(of: effect, at: origin).filter { !shields.contains($0) || $0 == origin }
    }

    private func rawTargets(of effect: SpecialEffect, at origin: Position) -> [Position] {
        let zone = board.positions(in: activeRange)
        func area(columns: ClosedRange<Int>, rows: ClosedRange<Int>) -> [Position] {
            zone.filter { columns.contains($0.column) && rows.contains($0.row) }
        }
        func cross(thickness: Int) -> [Position] {
            let reach = thickness / 2
            return zone.filter {
                abs($0.column - origin.column) <= reach || abs($0.row - origin.row) <= reach
            }
        }
        /// 제자리와 상하좌우 `reach`칸(청소 드론).
        func cross(reach: Int) -> [Position] {
            zone.filter {
                abs($0.column - origin.column) + abs($0.row - origin.row) <= reach
            }
        }
        func around(_ reach: Int) -> [Position] {
            area(
                columns: (origin.column - reach)...(origin.column + reach),
                rows: (origin.row - reach)...(origin.row + reach)
            )
        }
        switch effect {
        case .beam(.horizontal):
            return zone.filter { $0.row == origin.row }
        case .beam(.vertical):
            return zone.filter { $0.column == origin.column }
        case .bomb:
            return around(1)
        case .core(let kind):
            return zone.filter { $0 == origin || (kind != nil && board.kind(at: $0) == kind) }
        case .crossBeam:
            return cross(thickness: 1)
        case .wideCrossBeam:
            return cross(thickness: 3)
        case .bigBomb:
            return around(2)
        case .coreBeam, .coreBomb, .coreDrone:
            return [origin]
        case .clearBoard:
            return zone
        case .drone(let target):
            return cross(reach: 1) + (target.map { [$0] } ?? [])
        case .droneSwarm(let targets):
            return cross(reach: 1) + targets
        case .droneBeam(let orientation, let target):
            guard let target else { return cross(reach: 1) }
            let line = zone.filter { orientation == .horizontal ? $0.row == target.row : $0.column == target.column }
            return cross(reach: 1) + line
        case .droneBomb(let target):
            guard let target else { return cross(reach: 1) }
            let blast = zone.filter { abs($0.column - target.column) <= 1 && abs($0.row - target.row) <= 1 }
            return cross(reach: 1) + blast
        }
    }

    /// 제자리와 상하좌우 칸(청소 드론이 지우는 곳). 활성 구간 안으로 한정한다.
    private func cross(of origin: Position) -> Set<Position> {
        Set([(0, 0), (0, -1), (0, 1), (-1, 0), (1, 0)]
            .map { Position(column: origin.column + $0.0, row: origin.row + $0.1) }
            .filter { board.contains($0) && activeRange.contains($0.row) })
    }

    /// 청소 드론이 날아가 맞힐 칸을 `count`개까지 고른다(4장). 난수를 쓰지 않는다.
    ///
    /// 물질 바로 아래 칸, 피해를 입는 장애물, 가장 많이 남은 종류의 블록 순으로 보고,
    /// 같은 순위 안에서는 아래 행부터, 같은 행이면 왼쪽부터 고른다.
    private func droneTargets(_ count: Int, excluding taken: Set<Position>) -> [Position] {
        var excluded = taken
        var picked: [Position] = []
        let zone = board.positions(in: activeRange)
        func isTarget(_ position: Position) -> Bool {
            guard activeRange.contains(position.row), board.contains(position), !excluded.contains(position),
                  !shields.contains(position), let block = board[position], !block.isIndestructible
            else { return false }
            return true
        }
        let lowestFirst: (Position, Position) -> Bool = { ($0.row, -$0.column) > ($1.row, -$1.column) }
        while picked.count < count {
            let belowMaterials = zone
                .filter { board[$0] == .material }
                .map { Position(column: $0.column, row: $0.row + 1) }
                .filter { board[$0] != .material && isTarget($0) }
                .sorted(by: lowestFirst)
            let obstacles = zone.filter { board[$0]?.takesHits == true && isTarget($0) }.sorted(by: lowestFirst)
            var next = belowMaterials.first ?? obstacles.first
            if next == nil, let kind = mostCommonKind(excluding: excluded) {
                next = zone.filter { board.kind(at: $0) == kind && isTarget($0) }.sorted(by: lowestFirst).first
            }
            guard let target = next else { break }
            picked.append(target)
            excluded.insert(target)
        }
        return picked
    }

    /// 가장 많이 남은 종류. 수가 같으면 `BlockKind` 순서가 앞선 쪽이다.
    private func mostCommonKind(excluding removed: Set<Position>) -> BlockKind? {
        var counts: [BlockKind: Int] = [:]
        for position in board.positions(in: activeRange) where !removed.contains(position) {
            if let kind = board.kind(at: position) {
                counts[kind, default: 0] += 1
            }
        }
        return counts.max { ($0.value, -$0.key.rawValue) < ($1.value, -$1.key.rawValue) }?.key
    }

    // MARK: - 보충

    /// 활성 구간의 빈칸을 채운다. 열 순서, 같은 열에서는 아래쪽 빈칸부터 채운다.
    ///
    /// 블록은 활성 구간의 맨 위에서 들어오므로, 맨 위부터 이어진 빈칸만 채운다.
    /// 큰 물질 아래에 남은 빈칸은 위가 막혀 있어 채워지지 않는다.
    ///
    /// 보통은 무작위 블록이 들어온다. 그 열에 대기 깊이가 0인 물질이 있으면 블록 대신 물질이 들어오고,
    /// 아니면 블록이 들어올 때마다 그 열의 대기 깊이가 1씩 준다.
    private mutating func refill() -> [Spawn] {
        var spawns: [Spawn] = []
        for column in 0..<board.columns {
            let open = activeRange.prefix { board[column, $0] == nil }
            for row in open.reversed() {
                let position = Position(column: column, row: row)
                if let index = pendingMaterials.firstIndex(where: { $0.column == column && $0.depth == 0 }) {
                    pendingMaterials.remove(at: index)
                    board[position] = .material
                    materials.append(MaterialPiece(origin: position))
                } else {
                    board[position] = .normal(BlockKind.allCases[generator.nextInt(below: blockTypes)])
                    for index in pendingMaterials.indices where pendingMaterials[index].column == column {
                        pendingMaterials[index].depth -= 1
                    }
                }
                spawns.append(Spawn(position: position, block: board[position]!))
            }
        }
        return spawns
    }

    // MARK: - 아이템

    /// 정화 망치로 칠 수 있는 칸인지. 활성 구간 안의 블록이어야 하고, 오염 물질과 벽은 안 된다.
    public func canHammer(_ position: Position) -> Bool {
        guard status == .playing, board.contains(position), activeRange.contains(position.row),
              let block = board[position] else { return false }
        return !block.isIndestructible
    }

    /// 정화 망치를 쓴다. 블록이면 부수고, 장애물이면 한 번 때린다. 이동 횟수는 줄지 않고 슬러지도 번지지 않는다.
    /// 부서진 특수 블록은 발동하지 않는다.
    /// - Returns: 쓸 수 없는 칸이면 `nil`이다.
    public func hammering(_ position: Position) -> TurnResult? {
        guard canHammer(position), let block = board[position] else { return nil }
        var next = self
        var events: [GameEvent] = []
        if block.takesHits {
            events += next.damageObstacles(at: [position])
        } else {
            next.board[position] = nil
            next.score += GameConstants.scorePerBlock
            events.append(.hammered(position))
        }
        if next.fog.remove(position) != nil {
            events.append(.fogLifted([position]))
        }
        if next.sticky.remove(position) != nil {
            events.append(.stickyCleared([position]))
        }
        if next.shields.remove(position) != nil {
            events.append(.shieldsBroken([position]))
        }
        events += next.dropAndRefill()
        events += next.settleInPlace(swap: nil, firstChain: 1, isPlayerTurn: false)
        return TurnResult(state: next, events: events)
    }

    /// 자리 바꾸기로 바꿀 수 있는 두 칸인지. 붙어 있고, 둘 다 밀 수 있는 블록이어야 한다.
    public func canFreeSwap(_ swap: Swap) -> Bool {
        guard status == .playing, let rejection = rejection(for: swap) else { return status == .playing }
        // 매치가 되지 않는다는 이유로만 거부된 스왑은 아이템으로 할 수 있다.
        return rejection == .noMatch
    }

    /// 자리 바꾸기를 쓴다. 매치가 되지 않아도 두 블록을 바꾸고, 매치가 생기면 처리한다. 이동 횟수는 줄지 않는다.
    /// - Returns: 바꿀 수 없는 두 칸이면 `nil`이다.
    public func freeSwapping(_ swap: Swap) -> TurnResult? {
        guard canFreeSwap(swap) else { return nil }
        var next = self
        next.board.swapAt(swap.from, swap.to)
        for index in next.materials.indices {
            if next.materials[index].origin == swap.from {
                next.materials[index].origin = swap.to
            } else if next.materials[index].origin == swap.to {
                next.materials[index].origin = swap.from
            }
        }
        var events: [GameEvent] = [.swapped(swap)]
        if let effect = next.swapEffect(of: swap) {
            events += next.liftingFog(next.activateSwapEffect(effect, swap: swap))
            events += next.dropAndRefill()
            events += next.settleInPlace(swap: nil, firstChain: 2, isPlayerTurn: false)
        } else {
            events += next.settleInPlace(swap: swap, firstChain: 1, isPlayerTurn: false)
        }
        return TurnResult(state: next, events: events)
    }

    /// 섞기를 쓴다. 활성 구간의 일반 블록을 다시 섞는다. 이동 횟수는 줄지 않는다.
    /// - Returns: 섞을 수 없으면 `nil`이다.
    public func shuffling() -> TurnResult? {
        guard status == .playing else { return nil }
        var next = self
        guard let shuffled = next.shuffle() else { return nil }
        return TurnResult(state: next, events: [shuffled])
    }

    /// 섞어도 둘 곳이 없을 때, 옆 칸과 바꿀 수 있는 일반 블록 하나를 중화 폭탄으로 바꾼다.
    /// 특수 블록은 옆의 블록과 스왑하면 발동하므로 둘 곳이 생긴다. 그런 블록이 없으면 `nil`이다.
    private mutating func rescueWithBomb() -> GameEvent? {
        let candidates = board.positions(in: activeRange).filter { position in
            guard case .normal = board[position] else { return false }
            var trial = board
            trial[position] = .bomb
            return trial.possibleMoves(in: activeRange).contains { !isLocked($0) && ($0.from == position || $0.to == position) }
        }.sorted()
        guard !candidates.isEmpty else { return nil }
        let position = candidates[generator.nextInt(below: candidates.count)]
        board[position] = .bomb
        return .specialsCreated([SpecialSpawn(position: position, block: .bomb)])
    }

    // MARK: - 셔플

    /// 활성 구간의 일반 블록을 다시 섞는다. 특수 블록과 물질은 제자리에 둔다.
    /// 결과 보드에는 매치가 없고 가능한 이동이 1개 이상 있다. 그런 배치를 만들 수 없으면 `nil`이다.
    private mutating func shuffle() -> GameEvent? {
        let range = activeRange
        let normals = board.positions(in: range).filter {
            if case .normal = board[$0] { true } else { false }
        }
        for _ in 0..<Self.maximumShuffleAttempts {
            // 피셔-예이츠로 블록의 순서를 섞는다.
            var pool = normals
            for i in stride(from: pool.count - 1, to: 0, by: -1) {
                pool.swapAt(i, generator.nextInt(below: i + 1))
            }
            // 칸을 차례로 채우되, 3개 줄을 만들지 않는 첫 블록을 고른다.
            var candidate = board
            for target in normals {
                candidate[target] = nil
            }
            var moves: [BlockMove] = []
            for target in normals {
                guard let index = pool.firstIndex(where: {
                    !candidate.completesRun(board.kind(at: $0)!, at: target, in: range)
                }) else {
                    break
                }
                let source = pool.remove(at: index)
                candidate[target] = board[source]
                if source != target {
                    moves.append(BlockMove(from: source, to: target))
                }
            }
            if pool.isEmpty, candidate.findMatches(in: range).isEmpty, hasPossibleMove(on: candidate) {
                board = candidate
                return .shuffled(moves)
            }
        }
        // 블록 구성상 섞어서는 유효한 배치가 없는 경우. 일반 블록을 새로 만든다.
        // 장애물에 막혀 그래도 안 되면 포기한다.
        let saved = (board, generator)
        for _ in 0..<Self.maximumShuffleAttempts {
            fill(normals, in: range)
            if board.findMatches(in: range).isEmpty, hasPossibleMove(on: board) {
                return .regenerated(normals.map { Spawn(position: $0, kind: board.kind(at: $0)!) })
            }
        }
        (board, generator) = saved
        return nil
    }

    // MARK: - 보드 생성

    /// 물질과 장애물이 놓이지 않은 칸을 모두 채우고 `cages`의 칸에 철망을 씌운다.
    /// 첫 활성 구간에 가능한 이동이 있을 때까지 다시 만든다.
    private mutating func generateBoard(
        cages: [Position] = [], timers: [Position: Int] = [:], chains: [Position] = [], ice: [Position] = []
    ) {
        let (short, long) = (min(board.columns, board.rows), max(board.columns, board.rows))
        precondition(long >= 4 || (long >= 3 && short >= 2), "가능한 이동이 있을 수 없는 보드 크기다")
        let cells = board.positions.filter { board[$0] == nil }
        repeat {
            fill(cells, in: 0..<board.rows)
            for position in cages {
                board[position] = .caged(board.kind(at: position)!)
            }
            for (position, turns) in timers {
                board[position] = .timed(board.kind(at: position)!, turns: turns)
            }
            for position in chains {
                board[position] = .chained(board.kind(at: position)!)
            }
            for position in ice {
                board[position] = .frozen(board.kind(at: position)!)
            }
        } while !hasPossibleMove(on: board)
    }

    /// 주어진 칸을 무작위 일반 블록으로 채운다. 위와 왼쪽으로 3개 줄이 되는 종류는 피한다.
    private mutating func fill(_ cells: [Position], in range: Range<Int>) {
        for position in cells {
            board[position] = nil
        }
        let kinds = BlockKind.allCases.prefix(blockTypes)
        for position in cells {
            let candidates = kinds.filter { !board.completesRun($0, at: position, in: range) }
            board[position] = .normal(candidates[generator.nextInt(below: candidates.count)])
        }
    }
}

extension Block {
    /// 이 블록이 매치에 들거나 다른 효과에 맞았을 때 내는 효과.
    fileprivate var effect: SpecialEffect? {
        switch self {
        case .normal, .material, .concrete, .caged, .sludge, .wall, .cocoon, .rubble, .nest, .timed, .egg, .chained, .boulder, .vent, .frozen: nil
        case .beam(let orientation): .beam(orientation)
        case .bomb: .bomb
        case .core: .core(nil)
        case .drone: .drone(nil)
        }
    }

    /// 매치나 효과에 바로 지워지지 않고 피해를 한 번 입는 블록인지.
    fileprivate var takesHits: Bool {
        switch self {
        case .caged, .chained: return true
        default: break
        }
        // 벽은 고정돼 있지만 피해를 입지 않는다. 잔해 더미와 운석 조각은 고정돼 있지 않지만 피해를 입는다.
        return (isFixed && self != .wall) || self == .rubble || self == .boulder
    }
}

extension Board {
    /// 위에서 아래로, 왼쪽에서 오른쪽으로 채울 때 이 칸에 `kind`를 놓으면 3개 줄이나 2×2가 되는지.
    fileprivate func completesRun(_ kind: BlockKind, at position: Position, in range: Range<Int>) -> Bool {
        let (column, row) = (position.column, position.row)
        if column >= 2, kind == self.kind(at: Position(column: column - 1, row: row)),
           kind == self.kind(at: Position(column: column - 2, row: row)) {
            return true
        }
        if row - 2 >= range.lowerBound, kind == self.kind(at: Position(column: column, row: row - 1)),
           kind == self.kind(at: Position(column: column, row: row - 2)) {
            return true
        }
        // 왼쪽, 위, 왼쪽 위가 모두 같은 종류면 2×2 정사각형이 된다.
        if column >= 1, row - 1 >= range.lowerBound,
           kind == self.kind(at: Position(column: column - 1, row: row)),
           kind == self.kind(at: Position(column: column, row: row - 1)),
           kind == self.kind(at: Position(column: column - 1, row: row - 1)) {
            return true
        }
        return false
    }
}
