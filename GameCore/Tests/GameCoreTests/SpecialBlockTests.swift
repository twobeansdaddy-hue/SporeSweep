import Testing
@testable import GameCore

/// 스왑 직후의 이벤트만 본다. 뒤따르는 보충은 무작위라 검사하지 않는다.
private func turn(_ board: Board, _ swap: Swap) -> [GameEvent] {
    GameState(board: board).performTurn(swap).events
}

@Suite("특수 블록 생성")
struct SpecialCreationTests {
    @Test("3개 매치는 특수 블록을 만들지 않는다")
    func threeCreatesNothing() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
        let events = turn(board, swap((3, 9), (2, 9)))
        #expect(events[1].clearedMatches?.count == 1)
        #expect(events.allSatisfy { $0.createdSpecials == nil })
    }

    @Test("가로 4개는 움직인 자리에 가로 제염 빔을 만든다")
    func horizontalFour() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9), (2, 8)])
        let events = turn(board, swap((2, 8), (2, 9)))
        #expect(events[1].clearedMatches?.map(\.shape) == [.line(.horizontal, length: 4)])
        #expect(events[2] == .specialsCreated([
            SpecialSpawn(position: pos(2, 9), block: .beam(.horizontal))
        ]))
    }

    @Test("세로 4개는 움직인 자리에 세로 제염 빔을 만든다")
    func verticalFour() {
        let board = Board.deadlocked.setting(.soil, at: [(5, 6), (5, 8), (5, 9), (4, 7)])
        let events = turn(board, swap((4, 7), (5, 7)))
        #expect(events[2] == .specialsCreated([
            SpecialSpawn(position: pos(5, 7), block: .beam(.vertical))
        ]))
    }

    @Test("끌어다 놓은 칸이 아니라 밀려난 칸에서 매치가 생겨도 그 자리에 만든다")
    func spawnsAtDisplacedCell() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9), (2, 8)])
        let events = turn(board, swap((2, 9), (2, 8)))
        #expect(events[2].createdSpecials?.map(\.position) == [pos(2, 9)])
    }

    @Test("L 모양은 움직인 자리에 중화 폭탄을 만든다")
    func lShape() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9), (2, 7), (2, 8)])
        let events = turn(board, swap((3, 9), (2, 9)))
        #expect(events[1].clearedMatches?.map(\.shape) == [.lShape])
        #expect(events[2] == .specialsCreated([SpecialSpawn(position: pos(2, 9), block: .bomb)]))
    }

    @Test("T 모양은 움직인 자리에 중화 폭탄을 만든다")
    func tShape() {
        let board = Board.deadlocked.setting(.soil, at: [(1, 7), (3, 7), (2, 8), (2, 9), (2, 6)])
        let events = turn(board, swap((2, 6), (2, 7)))
        #expect(events[1].clearedMatches?.map(\.shape) == [.tShape])
        #expect(events[2] == .specialsCreated([SpecialSpawn(position: pos(2, 7), block: .bomb)]))
    }

    @Test("5개 일렬은 움직인 자리에 정화 코어를 만든다")
    func fiveInARow() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9), (4, 9), (2, 8)])
        let events = turn(board, swap((2, 8), (2, 9)))
        #expect(events[1].clearedMatches?.map(\.shape) == [.line(.horizontal, length: 5)])
        #expect(events[2] == .specialsCreated([SpecialSpawn(position: pos(2, 9), block: .core)]))
    }

    @Test("5개 일렬이 다른 줄과 만나도 정화 코어가 우선한다")
    func fiveBeatsCrossing() {
        let cells = [(0, 9), (1, 9), (2, 9), (3, 9), (4, 9), (2, 7), (2, 8)]
        let match = Board.deadlocked.setting(.soil, at: cells).findMatches()[0]
        #expect(match.shape == .tShape)
        #expect(match.longestLine == 5)
        #expect(match.createdSpecial == .core)
    }

    @Test("매치 모양별로 만드는 특수 블록", arguments: [
        ([(0, 0), (1, 0), (2, 0)], nil),
        ([(0, 0), (1, 0), (2, 0), (3, 0)], Special.beam(.horizontal)),
        ([(0, 0), (0, 1), (0, 2), (0, 3)], Special.beam(.vertical)),
        ([(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)], Special.core),
        ([(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0)], Special.core),
        ([(0, 0), (1, 0), (2, 0), (0, 1), (0, 2)], Special.bomb),
        ([(0, 0), (1, 0), (2, 0), (1, 1), (1, 2)], Special.bomb),
        ([(0, 0), (1, 0), (2, 0), (3, 0), (1, 1), (1, 2)], Special.bomb),
    ] as [([(Int, Int)], Special?)])
    func createdSpecial(cells: [(Int, Int)], expected: Special?) {
        let matches = Board.deadlocked.setting(.soil, at: cells).findMatches()
        #expect(matches.count == 1)
        #expect(matches[0].createdSpecial == expected)
    }

    @Test("연쇄 중에는 매치의 가운데 칸에 만든다")
    func cascadeSpawnsAtCenter() {
        // 스왑 없이 안정시키면 모든 매치가 연쇄로 취급된다.
        let line = Board.deadlocked.setting(.soil, at: [(2, 9), (3, 9), (4, 9), (5, 9)])
        #expect(GameState(board: line).settle().events[1] == .specialsCreated([
            SpecialSpawn(position: pos(3, 9), block: .beam(.horizontal))
        ]))

        let five = Board.deadlocked.setting(.soil, at: [(1, 9), (2, 9), (3, 9), (4, 9), (5, 9)])
        #expect(GameState(board: five).settle().events[1] == .specialsCreated([
            SpecialSpawn(position: pos(3, 9), block: .core)
        ]))

        // 꺾인 모양은 두 줄이 만나는 칸이다.
        let corner = Board.deadlocked.setting(.soil, at: [(2, 9), (3, 9), (4, 9), (4, 8), (4, 7)])
        #expect(GameState(board: corner).settle().events[1] == .specialsCreated([
            SpecialSpawn(position: pos(4, 9), block: .bomb)
        ]))
    }

    @Test("만들어진 특수 블록은 보드에 남는다")
    func createdBlockStaysOnBoard() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9), (2, 8)])
        let result = GameState(board: board).performTurn(swap((2, 8), (2, 9)))
        // 맨 아래 행이라 떨어지지 않는다.
        #expect(replay(Array(result.events.prefix(3)), on: board)[2, 9] == .beam(.horizontal))
        #expect(replay(result.events, on: board) == result.state.board)
    }
}

@Suite("특수 블록 발동")
struct SpecialActivationTests {
    /// (3,5)의 특수 블록을 오른쪽 칸으로 옮긴다. 옮겨 간 (4,5)에서 발동한다.
    let move = swap((3, 5), (4, 5))

    @Test("특수 블록은 종류가 없어 매치에 들지 않는다")
    func specialsHaveNoKind() {
        for block in [Block.beam(.horizontal), .beam(.vertical), .bomb, .core] {
            #expect(block.kind == nil)
            #expect(block.isSpecial)
            let board = Board.deadlocked.setting(.soil, at: [(1, 9), (2, 9)]).placing(block, at: (0, 9))
            #expect(board.findMatches().isEmpty)
        }
    }

    @Test("특수 블록은 매치가 없어도 옆 칸의 아무 블록과 스왑할 수 있다")
    func anySwapIsValid() {
        for block in [Block.beam(.horizontal), .beam(.vertical), .bomb, .core] {
            let board = Board.deadlocked.placing(block, at: (3, 5))
            for neighbor in [(2, 5), (4, 5), (3, 4), (3, 6)] {
                #expect(board.rejection(for: swap((3, 5), neighbor)) == nil)
                #expect(board.rejection(for: swap(neighbor, (3, 5))) == nil)
            }
        }
    }

    @Test("가로 제염 빔은 옮겨 간 자리의 가로줄 전체를 제거한다")
    func horizontalBeam() {
        let board = Board.deadlocked.placing(.beam(.horizontal), at: (3, 5))
        let events = turn(board, move)
        #expect(events[0] == .swapped(move))
        // 빔 자신과, 스왑으로 (3,5)에 간 블록도 그 줄에 있다.
        #expect(events[1] == .specialsActivated([
            SpecialActivation(origin: pos(4, 5), effect: .beam(.horizontal), cleared: (0...7).map { pos($0, 5) })
        ]))
    }

    @Test("세로 제염 빔은 옮겨 간 자리의 세로줄 전체를 제거한다")
    func verticalBeam() {
        let board = Board.deadlocked.placing(.beam(.vertical), at: (3, 5))
        let events = turn(board, move)
        #expect(events[1] == .specialsActivated([
            SpecialActivation(origin: pos(4, 5), effect: .beam(.vertical), cleared: (0...9).map { pos(4, $0) })
        ]))
    }

    @Test("빔의 방향은 어느 쪽으로 옮겨도 그대로다")
    func beamKeepsOrientation() {
        let board = Board.deadlocked.placing(.beam(.horizontal), at: (3, 5))
        let events = turn(board, swap((3, 5), (3, 6)))
        #expect(events[1] == .specialsActivated([
            SpecialActivation(origin: pos(3, 6), effect: .beam(.horizontal), cleared: (0...7).map { pos($0, 6) })
        ]))
    }

    @Test("일반 블록을 특수 블록 쪽으로 끌어도 특수 블록이 옮겨 간 자리에서 발동한다")
    func draggingTheOtherBlock() {
        let board = Board.deadlocked.placing(.bomb, at: (3, 5))
        let events = turn(board, swap((4, 5), (3, 5)))
        #expect(events[1].activations?[0].origin == pos(4, 5))
    }

    @Test("중화 폭탄은 옮겨 간 자리의 주변 3×3을 제거한다")
    func bomb() {
        let board = Board.deadlocked.placing(.bomb, at: (3, 5))
        let events = turn(board, move)
        #expect(events[1] == .specialsActivated([
            SpecialActivation(
                origin: pos(4, 5),
                effect: .bomb,
                cleared: [4, 5, 6].flatMap { row in [3, 4, 5].map { pos($0, row) } }
            )
        ]))
    }

    @Test("효과는 보드 밖으로 나가지 않는다")
    func effectsAreClippedToBoard() {
        let board = Board.deadlocked.placing(.bomb, at: (1, 9))
        let events = turn(board, swap((1, 9), (0, 9)))
        #expect(events[1].activations?[0].cleared == [pos(0, 8), pos(1, 8), pos(0, 9), pos(1, 9)])
    }

    @Test("효과에 맞은 특수 블록은 이어서 발동한다")
    func chainReaction() {
        let board = Board.deadlocked
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.bomb, at: (7, 5))
            .placing(.beam(.vertical), at: (6, 4))
        let activations = turn(board, move)[1].activations!
        #expect(activations.map(\.origin) == [pos(4, 5), pos(7, 5), pos(6, 4)])
        #expect(activations.map(\.effect) == [.beam(.horizontal), .bomb, .beam(.vertical)])
        // 앞선 효과가 이미 지운 칸은 다시 들어가지 않는다.
        #expect(activations[1].cleared == [pos(6, 4), pos(7, 4), pos(6, 6), pos(7, 6)])
        #expect(activations[2].cleared == [0, 1, 2, 3, 7, 8, 9].map { pos(6, $0) })
    }

    @Test("옆에서 매치가 일어나도 특수 블록은 발동하지 않는다")
    func adjacentMatchDoesNotTrigger() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
            .placing(.bomb, at: (1, 8))
        let events = turn(board, swap((3, 9), (2, 9)))
        #expect(events[1].clearedMatches?.count == 1)
        // 첫 낙하 전까지 발동이 없다.
        let firstStep = events.prefix { if case .fell = $0 { false } else { true } }
        #expect(firstStep.allSatisfy { $0.activations == nil })
    }

    @Test("특수 블록을 옮겨 발동해도 이동 횟수가 1 준다")
    func activationCostsAMove() {
        let board = Board.deadlocked(rows: 16).placing(.material, at: (0, 0)).placing(.bomb, at: (3, 5))
        let result = GameState(board: board, moves: 5).performTurn(move)
        #expect(result.state.movesRemaining == 4)
    }

    @Test("물질, 장애물, 철망과는 스왑할 수 없다")
    func cannotSwapWithMaterialOrObstacles() {
        let base = Board.deadlocked.placing(.bomb, at: (3, 5))
        #expect(base.placing(.material, at: (4, 5)).rejection(for: move) == .noMatch)
        #expect(base.placing(.concrete(hp: 1), at: (4, 5)).rejection(for: move) == .immovable)
        #expect(base.placing(.sludge, at: (4, 5)).rejection(for: move) == .immovable)
        #expect(base.placing(.caged(.brick), at: (4, 5)).rejection(for: move) == .immovable)
    }

    @Test("정화 코어를 일반 블록과 스왑하면 그 종류를 모두 제거한다")
    func coreWithNormal() {
        let board = Board.deadlocked.placing(.core, at: (3, 5))
        let kind = board.kind(at: pos(4, 5))!
        #expect(board.isValid(move))

        let events = turn(board, move)
        #expect(events[0] == .swapped(move))
        let activations = events[1].activations!
        #expect(activations.count == 1)
        #expect(activations[0].origin == pos(4, 5))
        #expect(activations[0].effect == .core(kind))
        // 스왑으로 (3,5)에 간 블록을 포함해 그 종류 전부와 코어 자신이다.
        var expected = Set(board.positions(of: kind))
        expected.remove(pos(4, 5))
        expected.formUnion([pos(3, 5), pos(4, 5)])
        #expect(Set(activations[0].cleared) == expected)
        #expect(activations[0].cleared.count == 17)
    }

    @Test("정화 코어를 끌어도, 코어 쪽으로 끌어도 같다")
    func coreSwapDirection() {
        let board = Board.deadlocked.placing(.core, at: (3, 5))
        let kind = board.kind(at: pos(4, 5))!
        let events = turn(board, swap((4, 5), (3, 5)))
        #expect(events[1].activations?[0].effect == .core(kind))
        // 어느 쪽을 끌든 코어가 가서 놓인 칸이 중심이다.
        #expect(events[1].activations?[0].origin == pos(4, 5))
        #expect(events[1].activations?[0].cleared.count == 17)
    }

    @Test("다른 효과에 맞은 정화 코어는 가장 많이 남은 종류를 제거한다")
    func coreHitByEffect() {
        // (0,8)의 가로 빔을 아래로 옮겨 맨 아래 줄을 지운다. 그 줄 끝의 코어가 맞아 발동한다.
        // 줄이 지워지면 glass와 wood가 15개씩 남아 가장 많다. 수가 같으면 종류 순서가 앞선 glass다.
        let board = Board.deadlocked
            .placing(.beam(.horizontal), at: (0, 8))
            .placing(.core, at: (7, 9))
        let activations = turn(board, swap((0, 8), (0, 9)))[1].activations!
        #expect(activations.map(\.effect) == [.beam(.horizontal), .core(.glass)])
        #expect(activations[1].origin == pos(7, 9))
        #expect(activations[1].cleared == board.positions(of: .glass).filter { $0.row != 9 })
        #expect(activations[1].cleared.count == 15)
    }
}

@Suite("특수 블록 조합")
struct SpecialComboTests {
    let move = swap((3, 5), (4, 5))

    func comboBoard(_ dragged: Block, _ target: Block) -> Board {
        Board.deadlocked.placing(dragged, at: (3, 5)).placing(target, at: (4, 5))
    }

    /// 조합 발동 하나만 나오는 경우의 제거 칸.
    func cleared(_ board: Board) -> Set<Position> {
        let events = turn(board, move)
        #expect(events[0] == .swapped(move))
        let activations = events[1].activations!
        #expect(activations.count == 1)
        #expect(activations[0].origin == pos(4, 5))
        return Set(activations[0].cleared)
    }

    @Test("특수 블록끼리의 스왑은 매치가 없어도 유효하다")
    func combosAreValidSwaps() {
        let specials: [Block] = [.beam(.horizontal), .bomb, .core]
        for dragged in specials {
            for target in specials {
                #expect(comboBoard(dragged, target).isValid(move))
            }
        }
    }

    @Test("제염 빔 + 제염 빔: 가로줄과 세로줄")
    func beamBeam() {
        // 두 빔의 방향이 같아도 가로줄과 세로줄을 함께 지운다.
        let board = comboBoard(.beam(.horizontal), .beam(.horizontal))
        #expect(turn(board, move)[1].activations?[0].effect == .crossBeam)
        let expected = Set(board.positions.filter { $0.column == 4 || $0.row == 5 })
        #expect(cleared(board) == expected)
        #expect(expected.count == 17)
    }

    @Test("제염 빔 + 중화 폭탄: 3줄 두께의 가로줄과 세로줄", arguments: [true, false])
    func beamBomb(beamFirst: Bool) {
        let board = beamFirst
            ? comboBoard(.beam(.vertical), .bomb)
            : comboBoard(.bomb, .beam(.vertical))
        #expect(turn(board, move)[1].activations?[0].effect == .wideCrossBeam)
        let expected = Set(board.positions.filter { (3...5).contains($0.column) || (4...6).contains($0.row) })
        #expect(cleared(board) == expected)
        #expect(expected.count == 45)
    }

    @Test("중화 폭탄 + 중화 폭탄: 주변 5×5")
    func bombBomb() {
        let board = comboBoard(.bomb, .bomb)
        #expect(turn(board, move)[1].activations?[0].effect == .bigBomb)
        let expected = Set(board.positions.filter { (2...6).contains($0.column) && (3...7).contains($0.row) })
        #expect(cleared(board) == expected)
        #expect(expected.count == 25)
    }

    @Test("정화 코어 + 제염 빔: 해당 종류를 모두 제염 빔으로 바꿔 발동", arguments: [true, false])
    func coreBeam(coreFirst: Bool) {
        let board = coreFirst
            ? comboBoard(.core, .beam(.horizontal))
            : comboBoard(.beam(.horizontal), .core)
        // 빔에는 종류가 없으므로 가장 많은 종류가 대상이다. 수가 같으면 순서가 앞선 brick이다.
        let normals = board.positions.filter { board[$0] == .normal(.brick) }
        let events = turn(board, move)
        let corePosition = coreFirst ? pos(4, 5) : pos(3, 5)
        let beamPosition = coreFirst ? pos(3, 5) : pos(4, 5)

        #expect(events[1] == .specialsActivated([
            SpecialActivation(origin: corePosition, effect: .coreBeam(.brick), cleared: [corePosition])
        ]))
        let created = events[2].createdSpecials!
        #expect(created.map(\.position) == normals)
        #expect(created.allSatisfy {
            if case .beam(_) = $0.block { true } else { false }
        })
        // 바뀐 빔과 스왑한 빔이 모두 발동한다.
        let activations = events[3].activations!
        #expect(Set(activations.map(\.origin)) == Set(normals + [beamPosition]))
        #expect(activations.allSatisfy {
            if case .beam = $0.effect { true } else { false }
        })
        #expect(Set(activations.flatMap(\.cleared)).isSuperset(of: normals + [beamPosition]))
    }

    @Test("정화 코어 + 중화 폭탄: 해당 종류를 모두 중화 폭탄으로 바꿔 발동", arguments: [true, false])
    func coreBomb(coreFirst: Bool) {
        let board = coreFirst
            ? comboBoard(.core, .bomb)
            : comboBoard(.bomb, .core)
        // 폭탄에는 종류가 없으므로 가장 많은 종류가 대상이다. 수가 같으면 순서가 앞선 brick이다.
        let normals = board.positions.filter { board[$0] == .normal(.brick) }
        let events = turn(board, move)
        let corePosition = coreFirst ? pos(4, 5) : pos(3, 5)
        let bombPosition = coreFirst ? pos(3, 5) : pos(4, 5)

        #expect(events[1] == .specialsActivated([
            SpecialActivation(origin: corePosition, effect: .coreBomb(.brick), cleared: [corePosition])
        ]))
        #expect(events[2] == .specialsCreated(normals.map { SpecialSpawn(position: $0, block: .bomb) }))
        let activations = events[3].activations!
        #expect(Set(activations.map(\.origin)) == Set(normals + [bombPosition]))
        #expect(activations.allSatisfy { $0.effect == .bomb })
        // 각 폭탄의 3×3이 모두 지워진다.
        let expected = Set(board.positions.filter { position in
            (normals + [bombPosition]).contains {
                abs($0.column - position.column) <= 1 && abs($0.row - position.row) <= 1
            }
        }).subtracting([corePosition])
        #expect(Set(activations.flatMap(\.cleared)) == expected)
    }

    @Test("정화 코어 + 정화 코어: 블록 전체 제거")
    func coreCore() {
        let board = comboBoard(.core, .core)
        let events = turn(board, move)
        #expect(events[1] == .specialsActivated([
            SpecialActivation(origin: pos(4, 5), effect: .clearBoard, cleared: board.positions)
        ]))
        // 떨어질 블록이 없으므로 바로 80칸을 보충한다.
        guard case .refilled(let spawns) = events[2] else {
            Issue.record("보충 이벤트가 없다: \(events[2])")
            return
        }
        #expect(spawns.count == 80)
    }

    @Test("조합 뒤에 이어지는 매치는 연쇄 2부터 센다")
    func chainCountsFromTwoAfterCombo() {
        for seed in 0..<30 as Range<UInt64> {
            let state = GameState(board: comboBoard(.bomb, .bomb), seed: seed)
            let chains = state.performTurn(move).events.compactMap { event -> Int? in
                if case .matchesCleared(_, let chain) = event { return chain }
                return nil
            }
            #expect(chains == Array(2..<(2 + chains.count)))
        }
    }

    @Test("모든 조합에서 이벤트 재생 결과가 최종 보드와 같고 보드가 안정된다")
    func combosReplayAndSettle() {
        let specials: [Block] = [.beam(.horizontal), .beam(.vertical), .bomb, .core]
        for dragged in specials {
            for target in specials {
                let board = comboBoard(dragged, target)
                let result = GameState(board: board).performTurn(move)
                #expect(replay(result.events, on: board) == result.state.board)
                #expect(result.state.board.isFull)
                #expect(result.state.board.findMatches().isEmpty)
                #expect(result.state.board.hasPossibleMove)
            }
        }
    }
}

@Suite("특수 블록과 이동 탐색·셔플")
struct SpecialMoveTests {
    @Test("정화 코어는 네 방향 모두 가능한 이동이다")
    func coreMoves() {
        let board = Board.deadlocked.placing(.core, at: (3, 5))
        #expect(Set(board.possibleMoves()) == [
            swap((2, 5), (3, 5)), swap((3, 5), (4, 5)), swap((3, 4), (3, 5)), swap((3, 5), (3, 6)),
        ])
    }

    @Test("제염 빔과 중화 폭탄도 네 방향 모두 가능한 이동이다")
    func beamAndBombMoves() {
        let board = Board.deadlocked
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.bomb, at: (3, 6))
        let moves = Set(board.possibleMoves())
        // 두 블록의 이웃 여덟 쌍에서 서로 맞닿은 한 쌍이 겹친다.
        #expect(moves.count == 7)
        #expect(moves.contains(swap((3, 5), (3, 6))))
        #expect(moves.contains(swap((2, 5), (3, 5))))
        #expect(moves.contains(swap((3, 6), (3, 7))))
    }

    @Test("움직일 수 있는 특수 블록이 있으면 섞지 않는다")
    func noShuffleWhileSpecialCanMove() {
        let board = Board.deadlocked.placing(.bomb, at: (3, 5))
        let state = GameState(board: board)
        #expect(!state.possibleMoves().isEmpty)
        #expect(state.settle().events.isEmpty)
    }

    @Test("셔플은 일반 블록만 섞고 특수 블록은 제자리에 둔다")
    func shuffleKeepsSpecialsInPlace() {
        // 구석의 폭탄을 콘크리트로 막아 움직일 수 없게 한다.
        let board = Board.deadlocked
            .placing(.bomb, at: (0, 0))
            .placing(.concrete(hp: 1), at: (1, 0)).placing(.concrete(hp: 1), at: (0, 1))
        #expect(!board.hasPossibleMove)
        for seed in 0..<50 as Range<UInt64> {
            let result = GameState(board: board, seed: seed).settle()
            guard case .shuffled(let moves) = result.events.last else {
                Issue.record("seed \(seed): 셔플 이벤트가 없다")
                continue
            }
            #expect(result.state.board[0, 0] == .bomb)
            #expect(!moves.contains { [$0.from, $0.to].contains(pos(0, 0)) })
            #expect(result.state.board.findMatches().isEmpty)
            #expect(result.state.board.hasPossibleMove)
        }
    }

    @Test("특수 블록이 생기는 긴 플레이에서도 매 턴 보드가 안정된다")
    func longPlayWithSpecials() {
        var created: Set<Special> = []
        var activated = 0
        for seed in 0..<20 as Range<UInt64> {
            var state = GameState(seed: seed)
            for turn in 0..<150 {
                let moves = state.board.possibleMoves()
                let result = state.performTurn(moves[(turn * 11) % moves.count])
                for event in result.events {
                    created.formUnion(event.createdSpecials?.compactMap(\.block.special) ?? [])
                    activated += event.activations?.count ?? 0
                }
                #expect(replay(result.events, on: state.board) == result.state.board)
                state = result.state
                #expect(state.board.isFull)
                #expect(state.board.findMatches().isEmpty)
                #expect(state.board.hasPossibleMove)
            }
        }
        // 무작위 플레이에서도 세 종류가 모두 만들어지고 발동한다.
        #expect(created.contains(.bomb))
        #expect(created.contains(.core))
        #expect(created.contains { if case .beam = $0 { true } else { false } })
        #expect(activated > 0)
    }
}
