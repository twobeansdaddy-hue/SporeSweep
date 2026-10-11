import Testing
@testable import GameCore

private func hits(_ events: [GameEvent]) -> [ObstacleHit] {
    events.flatMap { event -> [ObstacleHit] in
        if case .obstaclesDamaged(let hits) = event { return hits }
        return []
    }
}

private func spreads(_ events: [GameEvent]) -> [Position] {
    events.flatMap { event -> [Position] in
        if case .sludgeSpread(let positions) = event { return positions }
        return []
    }
}

private func count(_ block: Block, in board: Board) -> Int {
    board.positions.count { board[$0] == block }
}

@Suite("콘크리트")
struct ConcreteTests {
    /// 맨 아래 행에서 soil 3개를 맞추는 스왑. 매치 칸은 (0,9), (1,9), (2,9)다.
    let move = swap((3, 8), (2, 8))
    func board(concrete: Block = .concrete(hp: 1), at cell: (Int, Int)) -> Board {
        Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (3, 8)]).placing(concrete, at: cell)
    }

    @Test("종류가 없어 매치되지 않고 스왑할 수 없다")
    func cannotMatchOrSwap() {
        let board = Board.deadlocked
            .placing(.concrete(hp: 1), at: (2, 4)).placing(.concrete(hp: 1), at: (3, 4)).placing(.concrete(hp: 1), at: (4, 4))
        #expect(Block.concrete(hp: 1).kind == nil)
        #expect(board.findMatches().isEmpty)
        #expect(board.rejection(for: swap((2, 4), (2, 5))) == .immovable)
        #expect(board.rejection(for: swap((1, 4), (2, 4))) == .immovable)
        #expect(board.possibleMoves().isEmpty)
    }

    @Test("떨어지지 않고, 위의 블록과 물질을 받친다")
    func doesNotFall() {
        var board = Board.deadlocked(rows: 16)
            .placing(.concrete(hp: 1), at: (2, 4))
            .placing(.material, at: (2, 3))
            .setting(nil, at: [(2, 5), (2, 6)])
        let moves = board.applyGravity(in: 0..<10)
        #expect(moves.isEmpty)
        #expect(board[2, 4] == .concrete(hp: 1))
        #expect(board[2, 3] == .material)
        #expect(board[2, 5] == nil)
    }

    @Test("옆에서 매치하면 없어진다")
    func adjacentMatchRemoves() {
        // (3,8)은 매치 칸 (2,8)의 오른쪽이다.
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (2, 7)]).placing(.concrete(hp: 1), at: (3, 8))
        let result = GameState(board: board).performTurn(swap((2, 7), (2, 8)))
        #expect(hits(result.events) == [ObstacleHit(position: pos(3, 8), remaining: nil)])
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("위아래로 붙은 매치도 피해를 준다")
    func verticalAdjacency() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (2, 7)]).placing(.concrete(hp: 1), at: (1, 9))
        let result = GameState(board: board).performTurn(swap((2, 7), (2, 8)))
        #expect(hits(result.events).first == ObstacleHit(position: pos(1, 9), remaining: nil))
    }

    @Test("대각선으로만 닿은 매치는 피해를 주지 않는다")
    func diagonalDoesNotDamage() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (2, 7)]).placing(.concrete(hp: 1), at: (3, 9))
        let events = GameState(board: board).performTurn(swap((2, 7), (2, 8))).events
        // 첫 매치 단계에서는 피해가 없다.
        let firstStep = events.prefix { if case .fell = $0 { false } else { true } }
        #expect(hits(Array(firstStep)).isEmpty)
    }

    @Test("강화형은 두 번 맞아야 없어진다")
    func reinforcedTakesTwoHits() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 8), (1, 8), (2, 7)]).placing(.concrete(hp: 2), at: (3, 8))
        let first = GameState(board: board).performTurn(swap((2, 7), (2, 8)))
        #expect(hits(first.events).first == ObstacleHit(position: pos(3, 8), remaining: .concrete(hp: 1)))
    }

    @Test("여러 매치 칸에 붙어 있어도 한 단계에 한 번만 맞는다")
    func hitOncePerStep() {
        // (1,9)는 매치 칸 (1,8)의 아래이고, 가로 3개가 한 번에 지워진다.
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 8), (1, 8), (2, 7)])
            .placing(.concrete(hp: 2), at: (1, 9)).placing(.concrete(hp: 2), at: (0, 9))
        let first = hits(GameState(board: board).performTurn(swap((2, 7), (2, 8))).events).prefix(2)
        #expect(Array(first) == [
            ObstacleHit(position: pos(0, 9), remaining: .concrete(hp: 1)),
            ObstacleHit(position: pos(1, 9), remaining: .concrete(hp: 1)),
        ])
    }

    @Test("특수 효과가 닿으면 한 번 맞는다")
    func effectsDamage() {
        // 가로 빔을 맨 아래 줄로 옮겨 발동한다. 같은 줄의 콘크리트 둘이 맞는다.
        let board = Board.deadlocked
            .placing(.beam(.horizontal), at: (0, 8))
            .placing(.concrete(hp: 1), at: (5, 9)).placing(.concrete(hp: 2), at: (7, 9))
        let events = GameState(board: board).performTurn(swap((0, 8), (0, 9))).events
        // 콘크리트는 효과의 제거 칸에 들지 않고 피해 이벤트로 따로 나온다.
        #expect(events[1].activations?[0].cleared == [0, 1, 2, 3, 4, 6].map { pos($0, 9) })
        #expect(events[2] == .obstaclesDamaged([
            ObstacleHit(position: pos(5, 9), remaining: nil),
            ObstacleHit(position: pos(7, 9), remaining: .concrete(hp: 1)),
        ]))
    }

    @Test("정화 코어 둘의 조합도 콘크리트를 한 번만 깎는다")
    func clearBoardDamagesOnce() {
        let board = Board.deadlocked(rows: 16)
            .placing(.core, at: (3, 5)).placing(.core, at: (4, 5))
            .placing(.concrete(hp: 2), at: (0, 0)).placing(.concrete(hp: 1), at: (7, 9))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events[1].activations?[0].cleared.count == 78)
        #expect(hits(result.events).prefix(2) == [
            ObstacleHit(position: pos(0, 0), remaining: .concrete(hp: 1)),
            ObstacleHit(position: pos(7, 9), remaining: nil),
        ])
    }

    @Test("흘러내림을 끄면 콘크리트 아래의 빈칸은 채워지지 않는다")
    func gapBelowIsNotRefilled() {
        let board = Board.deadlocked(rows: 16)
            .placing(.concrete(hp: 1), at: (5, 3))
            .setting(.soil, at: [(5, 5), (5, 6), (5, 7)])
        let result = GameState(board: board, slide: false).settle()
        // 콘크리트 바로 아래 블록 하나가 떨어지고, 그 위는 빈 채로 남는다.
        #expect(result.state.board[5, 3] == .concrete(hp: 1))
        #expect(result.state.board[5, 4] == nil)
        #expect(result.state.board[5, 7] == board[5, 4])
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("콘크리트 아래의 빈칸은 옆에서 흘러내린 블록으로 채워진다")
    func gapBelowFillsWithSlide() {
        let board = Board.deadlocked(rows: 16)
            .placing(.concrete(hp: 1), at: (5, 3))
            .setting(.soil, at: [(5, 5), (5, 6), (5, 7)])
        let result = GameState(board: board).settle()
        #expect(result.state.board.positions(in: 0..<10).allSatisfy { result.state.board[$0] != nil })
        #expect(result.state.board[5, 3] == .concrete(hp: 1))
    }

    @Test("물질의 길을 막고, 없애면 물질이 내려간다")
    func blocksMaterialUntilRemoved() {
        // 물질 아래에 콘크리트, 그 아래에 빈칸이 생기는 매치.
        var board = Board.deadlocked(rows: 16)
            .placing(.material, at: (2, 3)).placing(.concrete(hp: 1), at: (2, 4))
            .setting(.soil, at: [(2, 5), (2, 6), (2, 7)])
        // 세로 매치의 맨 위 칸이 콘크리트 바로 아래라 콘크리트가 맞아 없어지고 물질이 떨어진다.
        let opened = GameState(board: board).settle()
        #expect(hits(opened.events).first == ObstacleHit(position: pos(2, 4), remaining: nil))
        #expect(opened.state.materialPositions[0].row > 3)

        // 강화형은 한 번 맞아도 남아서 물질을 계속 받친다.

        board = Board.deadlocked(rows: 16)
            .placing(.material, at: (2, 3)).placing(.concrete(hp: 2), at: (2, 4))
            .setting(.soil, at: [(2, 5), (2, 6), (2, 7)])
        let stillBlocked = GameState(board: board).settle()
        #expect(stillBlocked.state.board[2, 4] == .concrete(hp: 1))
        #expect(stillBlocked.state.materialPositions == [pos(2, 3)])
    }
}

@Suite("철망")
struct CageTests {
    @Test("갇힌 블록은 종류가 있어 매치에 쓰이고, 매치되면 철망만 사라지고 블록은 남는다")
    func matchRemovesCageOnly() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (3, 9)]).placing(.caged(.soil), at: (1, 9))
        #expect(Block.caged(.soil).kind == .soil)
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(result.events[1].clearedMatches?[0].positions == [pos(0, 9), pos(1, 9), pos(2, 9)])
        // 철망이 벗겨진 자리에 같은 종류의 일반 블록이 남는다. 맨 아래 행이라 떨어지지 않는다.
        #expect(result.events[2] == .obstaclesDamaged([ObstacleHit(position: pos(1, 9), remaining: .normal(.soil))]))
        #expect(replay(Array(result.events.prefix(3)), on: board)[1, 9] == .normal(.soil))
        #expect(count(.caged(.soil), in: result.state.board) == 0)
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("남은 블록은 다시 매치해야 사라진다")
    func secondMatchRemovesBlock() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (3, 9)]).placing(.caged(.soil), at: (1, 9))
        let events = GameState(board: board).performTurn(swap((3, 9), (2, 9))).events
        // 철망이 벗겨진 직후의 보드에서, 풀려난 블록 양옆에 같은 종류를 놓아 다시 맞춘다.
        var released = replay(Array(events.prefix(3)), on: board)
        #expect(released[1, 9] == .normal(.soil))
        released[0, 9] = .normal(.soil)
        released[2, 9] = .normal(.soil)
        let result = GameState(board: released).settle()
        #expect(result.events[0].clearedMatches?[0].positions == [pos(0, 9), pos(1, 9), pos(2, 9)])
        #expect(hits(Array(result.events.prefix(2))).isEmpty)
    }

    @Test("철망이 벗겨진 블록은 스왑할 수 있다")
    func releasedBlockCanSwap() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (3, 9)]).placing(.caged(.soil), at: (1, 9))
        let events = GameState(board: board).performTurn(swap((3, 9), (2, 9))).events
        #expect(replay(Array(events.prefix(3)), on: board)[1, 9]?.isSwappable == true)
        #expect(!Block.caged(.soil).isSwappable)
    }

    @Test("갇힌 블록이 여럿 든 매치는 철망만 모두 벗긴다")
    func matchOfCagedBlocks() {
        let board = Board.deadlocked
            .placing(.caged(.soil), at: (0, 9)).placing(.caged(.soil), at: (1, 9)).setting(.soil, at: [(3, 9)])
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(result.events[2] == .obstaclesDamaged([
            ObstacleHit(position: pos(0, 9), remaining: .normal(.soil)),
            ObstacleHit(position: pos(1, 9), remaining: .normal(.soil)),
        ]))
        // 뒤따르는 셔플 전의 보드에서 확인한다.
        let afterMatch = replay(Array(result.events.prefix(3)), on: board)
        #expect(afterMatch[0, 9] == .normal(.soil))
        #expect(afterMatch[1, 9] == .normal(.soil))
        #expect(afterMatch[2, 9] == nil)
    }

    @Test("갇힌 블록은 스왑할 수 없다")
    func cannotSwap() {
        // 갇힌 soil이 (2,9)로 가면 매치지만 움직일 수 없다.
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9)]).placing(.caged(.soil), at: (3, 9))
        #expect(board.rejection(for: swap((3, 9), (2, 9))) == .immovable)
        #expect(board.rejection(for: swap((2, 9), (3, 9))) == .immovable)
        #expect(board.possibleMoves().isEmpty)
        let state = GameState(board: board)
        #expect(state.performTurn(swap((3, 9), (2, 9))).events == [.swapRejected(swap((3, 9), (2, 9)), .immovable)])
    }

    @Test("일반 블록처럼 떨어진다")
    func falls() {
        var board = Board.deadlocked.placing(.caged(.soil), at: (2, 3)).setting(nil, at: [(2, 4), (2, 5)])
        board.applyGravity()
        #expect(board[2, 5] == .caged(.soil))
    }

    @Test("특수 효과에 맞아도 철망만 사라진다")
    func effectRemovesCageOnly() {
        let board = Board.deadlocked
            .placing(.beam(.horizontal), at: (0, 8))
            .placing(.caged(.brick), at: (6, 9))
        let events = GameState(board: board).performTurn(swap((0, 8), (0, 9))).events
        #expect(events[1].activations?[0].cleared.contains(pos(6, 9)) == false)
        #expect(events[2] == .obstaclesDamaged([ObstacleHit(position: pos(6, 9), remaining: .normal(.brick))]))
    }

    @Test("정화 코어 둘의 조합도 철망만 벗긴다")
    func clearBoardReleasesCages() {
        let board = Board.deadlocked(rows: 16)
            .placing(.core, at: (3, 5)).placing(.core, at: (4, 5)).placing(.caged(.brick), at: (0, 9))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events[1].activations?[0].cleared.count == 79)
        #expect(hits(result.events).first == ObstacleHit(position: pos(0, 9), remaining: .normal(.brick)))
    }

    @Test("셔플해도 제자리에 있고 흘러내리지 않는다")
    func staysInPlace() {
        let board = Board.deadlocked.placing(.caged(.soil), at: (4, 4))
        for seed in 0..<20 as Range<UInt64> {
            let result = GameState(board: board, seed: seed).settle()
            #expect(result.state.board[4, 4] == .caged(.soil))
        }
        #expect(!Block.caged(.soil).canSlide)
        #expect(!Block.concrete(hp: 1).canSlide)
        #expect(Block.normal(.soil).canSlide)
    }
}

@Suite("오염 슬러지")
struct SludgeTests {
    /// 슬러지에서 멀리 떨어진 맨 아래 행의 매치.
    let farMove = swap((3, 9), (2, 9))
    var board: Board {
        Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)]).placing(.sludge, at: (6, 2))
    }

    @Test("움직이지 않고 스왑할 수 없다")
    func fixed() {
        var board = Board.deadlocked.placing(.sludge, at: (2, 3)).setting(nil, at: [(2, 4)])
        #expect(board.applyGravity().isEmpty)
        #expect(board.rejection(for: swap((2, 3), (3, 3))) == .immovable)
        #expect(Block.sludge.kind == nil)
    }

    @Test("슬러지를 제거하지 못한 턴에는 옆 칸으로 한 칸 번진다")
    func spreadsWhenNotCleared() {
        let result = GameState(board: board).performTurn(farMove)
        let spread = spreads(result.events)
        #expect(spread.count == 1)
        // 원래 슬러지의 상하좌우 가운데 하나다.
        #expect([pos(6, 1), pos(6, 3), pos(5, 2), pos(7, 2)].contains(spread[0]))
        #expect(count(.sludge, in: result.state.board) == 2)
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("옆에서 매치하면 없어지고, 그 턴에는 번지지 않는다")
    func clearedByAdjacentMatch() {
        // 매치 칸 (2,9) 옆의 슬러지와, 멀리 떨어진 슬러지.
        let board = board.placing(.sludge, at: (3, 9)).setting(.soil, at: [(2, 8)])
        let result = GameState(board: board).performTurn(swap((2, 8), (2, 9)))
        #expect(hits(result.events).first == ObstacleHit(position: pos(3, 9), remaining: nil))
        #expect(spreads(result.events).isEmpty)
        #expect(count(.sludge, in: result.state.board) == 1)
    }

    @Test("특수 효과로도 없어진다")
    func clearedByEffect() {
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (0, 8))
            .placing(.sludge, at: (6, 9))
        let result = GameState(board: board).performTurn(swap((0, 8), (0, 9)))
        #expect(hits(result.events).contains(ObstacleHit(position: pos(6, 9), remaining: nil)))
        #expect(spreads(result.events).isEmpty)
    }

    @Test("일반 블록만 덮는다")
    func spreadsOnlyOntoNormalBlocks() {
        // 슬러지의 네 이웃이 물질, 콘크리트, 특수 블록, 철망이다.
        let board = board
            .placing(.material, at: (6, 1)).placing(.concrete(hp: 1), at: (6, 3))
            .placing(.bomb, at: (5, 2)).placing(.caged(.brick), at: (7, 2))
        let result = GameState(board: board).performTurn(farMove)
        #expect(spreads(result.events).isEmpty)
        #expect(count(.sludge, in: result.state.board) == 1)
    }

    @Test("스왑이 없는 안정화에서는 번지지 않는다")
    func noSpreadWithoutPlayerTurn() {
        let result = GameState(board: board.setting(.soil, at: [(2, 9)])).settle()
        #expect(spreads(result.events).isEmpty)
    }

    @Test("거부된 스왑에서는 번지지 않는다")
    func noSpreadOnRejectedSwap() {
        let result = GameState(board: board).performTurn(swap((5, 5), (6, 5)))
        #expect(result.events.count == 1)
        #expect(count(.sludge, in: result.state.board) == 1)
    }

    @Test("활성 구간 밖의 슬러지는 번지지 않는다")
    func noSpreadOutsideZone() {
        let board = Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)]).placing(.sludge, at: (6, 13))
        let result = GameState(board: board).performTurn(farMove)
        #expect(spreads(result.events).isEmpty)
    }

    @Test("클리어한 턴에는 번지지 않는다")
    func noSpreadOnWin() {
        let board = Board.deadlocked(rows: 12)
            .placing(.material, at: (2, 10))
            .setting(.soil, at: [(0, 11), (1, 11), (3, 11)])
            .placing(.sludge, at: (6, 5))
        let result = GameState(board: board, activeTop: 2, moves: 3).performTurn(swap((3, 11), (2, 11)))
        #expect(result.state.status == .won)
        #expect(spreads(result.events).isEmpty)
    }

    @Test("번지는 칸은 시드로 정해진다")
    func spreadIsDeterministic() {
        let a = GameState(board: board, seed: 5).performTurn(farMove)
        let b = GameState(board: board, seed: 5).performTurn(farMove)
        #expect(a == b)
        let targets = Set((0..<40 as Range<UInt64>).flatMap { spreads(GameState(board: board, seed: $0).performTurn(farMove).events) })
        #expect(targets.count > 1)
    }
}

@Suite("장애물이 있는 판")
struct ObstacleLevelTests {
    let obstacles = [
        Obstacle(kind: .concrete(hp: 1), position: pos(2, 6)),
        Obstacle(kind: .concrete(hp: 2), position: pos(3, 6)),
        Obstacle(kind: .cage, position: pos(5, 4)),
        Obstacle(kind: .cage, position: pos(6, 4)),
        Obstacle(kind: .sludge, position: pos(7, 8)),
    ]

    func level(seed: UInt64, slide: Bool = false) -> GameState {
        GameState(
            seed: seed, rows: 16, moves: 500,
            materials: [pos(2, 0), pos(5, 0)], obstacles: obstacles, blocksSlide: slide
        )
    }

    @Test("장애물이 지정한 칸에 놓이고 철망은 무작위 종류의 블록을 가둔다")
    func generation() {
        for seed in 0..<50 as Range<UInt64> {
            let board = level(seed: seed).board
            #expect(board[2, 6] == .concrete(hp: 1))
            #expect(board[3, 6] == .concrete(hp: 2))
            #expect(board[7, 8] == .sludge)
            for cell in [pos(5, 4), pos(6, 4)] {
                guard case .caged(let kind) = board[cell] else {
                    Issue.record("seed \(seed): \(cell)에 철망이 없다")
                    continue
                }
                #expect(kind.rawValue < 5)
            }
            #expect(board.isFull)
            #expect(board.findMatches().isEmpty)
            #expect(!level(seed: seed).possibleMoves().isEmpty)
        }
        #expect(level(seed: 3) == level(seed: 3))
    }

    @Test("장애물이 있는 레벨을 클리어까지 플레이한다", arguments: [(1, false), (2, false), (1, true), (2, true)] as [(UInt64, Bool)])
    func playToClear(seed: UInt64, slide: Bool) {
        var state = level(seed: seed, slide: slide)
        var turns = 0
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            turns += 1
            #expect(replay(result.events, on: before.board) == state.board)
            #expect(state.materials.flatMap(\.cells).sorted() == state.materialPositions)
            #expect(state.board.findMatches(in: state.activeRange).isEmpty)
            // 콘크리트와 슬러지는 제자리에서만 줄어들거나(콘크리트) 옆으로 번진다(슬러지).
            for position in state.board.positions(in: state.activeRange) {
                if case .concrete = state.board[position] {
                    #expect({ if case .concrete = before.board[position] { true } else { false } }())
                }
            }
            if state.status == .playing {
                #expect(!state.possibleMoves().isEmpty)
            }
        }
        #expect(state.status == .won)
        print("장애물 seed \(seed) slide \(slide): \(turns)턴에 클리어")
    }

    @Test("섞어도 둘 곳이 없고 폭탄을 놓을 자리도 없으면 실패다")
    func stuckBoardIsLost() {
        // 일반 블록이 하나뿐이라 폭탄으로 바꿔도 바꿀 상대가 없다.
        var board = Board(columns: 3, rows: 1)
        board[0, 0] = .concrete(hp: 1)
        board[1, 0] = .normal(.brick)
        board[2, 0] = .concrete(hp: 1)
        let result = GameState(board: board).settle()
        #expect(result.events == [.lost])
        #expect(result.state.status == .lost)
        #expect(result.state.board == board)
    }
}
