import Testing
@testable import GameCore

@Suite("턴 처리")
struct TurnTests {
    /// (3,9)의 soil을 왼쪽으로 옮기면 맨 아래 행에 가로 3개가 된다.
    let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
    let move = swap((3, 9), (2, 9))

    @Test("유효한 스왑은 교환, 제거, 낙하, 보충 순서로 이벤트를 낸다")
    func eventOrder() {
        let result = GameState(board: board).performTurn(move)
        let events = result.events
        #expect(events.count >= 4)
        #expect(events[0] == .swapped(move))
        #expect(events[1] == .matchesCleared(
            [Match(kind: .soil, shape: .line(.horizontal, length: 3), positions: [pos(0, 9), pos(1, 9), pos(2, 9)])],
            chain: 1
        ))
        guard case .fell(let falls) = events[2], case .refilled(let spawns) = events[3] else {
            Issue.record("낙하와 보충 이벤트가 없다: \(events)")
            return
        }
        // 세 열에서 9개씩 한 칸 내려온다.
        #expect(falls.count == 27)
        #expect(falls.allSatisfy { $0.to == pos($0.from.column, $0.from.row + 1) && $0.from.column <= 2 })
        // 지워진 3칸만큼 맨 위에서 들어온다.
        #expect(Set(spawns.map(\.position)) == [pos(0, 0), pos(1, 0), pos(2, 0)])
    }

    @Test("입력 상태는 바뀌지 않는다")
    func inputIsNotMutated() {
        let state = GameState(board: board)
        let copy = state
        _ = state.performTurn(move)
        #expect(state == copy)
    }

    @Test("보충되는 블록은 설정한 종류 수 안에서 나온다", arguments: [4, 5, 6])
    func refillUsesConfiguredKinds(blockTypes: Int) {
        var state = GameState(seed: 7, blockTypes: blockTypes)
        let allowed = Set(BlockKind.allCases.prefix(blockTypes))
        for _ in 0..<30 {
            let result = state.performTurn(state.board.possibleMoves()[0])
            for case .refilled(let spawns) in result.events {
                #expect(spawns.allSatisfy { $0.block.kind.map(allowed.contains) == true && !$0.block.isSpecial })
            }
            state = result.state
        }
    }

    @Test("보충은 빈칸 수만큼, 각 열의 맨 위부터 채운다")
    func refillFillsTopOfColumns() {
        var state = GameState(seed: 11)
        for _ in 0..<60 {
            let result = state.performTurn(state.board.possibleMoves()[0])
            // 제거된 칸에서 특수 블록이 새로 놓인 칸을 뺀 것이 빈칸이다.
            var emptied: Set<Position> = []
            for event in result.events {
                switch event {
                case .matchesCleared(let matches, _):
                    emptied.formUnion(matches.flatMap(\.positions))
                case .specialsActivated(let activations):
                    emptied.formUnion(activations.flatMap(\.cleared))
                case .specialsCreated(let spawns):
                    emptied.subtract(spawns.map(\.position))
                case .refilled(let spawns):
                    #expect(spawns.count == emptied.count)
                    let emptiedPerColumn = Dictionary(grouping: emptied, by: \.column).mapValues(\.count)
                    let spawnRows = Dictionary(grouping: spawns, by: \.position.column)
                        .mapValues { Set($0.map(\.position.row)) }
                    for (column, count) in emptiedPerColumn {
                        #expect(spawnRows[column] == Set(0..<count))
                    }
                    emptied = []
                default:
                    break
                }
            }
            state = result.state
        }
    }

    @Test("낙하로 생긴 매치는 연쇄로 처리한다")
    func cascade() {
        // 첫 매치가 지워지면 (1,8), (2,8)의 A가 한 칸 내려와 스왑으로 밀려난 (3,9)의 A와 가로 3개가 된다.
        let cascading = board.setting(.brick, at: [(1, 8), (2, 8)])
        #expect(cascading[2, 9] == .normal(.brick))
        #expect(cascading.findMatches().isEmpty)

        let result = GameState(board: cascading).performTurn(move)
        let clears = result.events.compactMap { event -> (matches: [Match], chain: Int)? in
            if case .matchesCleared(let matches, let chain) = event { return (matches, chain) }
            return nil
        }
        #expect(clears.count >= 2)
        #expect(clears.map(\.chain) == Array(1...clears.count))
        #expect(clears[0].matches.map(\.kind) == [.soil])
        #expect(clears[1].matches.contains(
            Match(kind: .brick, shape: .line(.horizontal, length: 3), positions: [pos(1, 9), pos(2, 9), pos(3, 9)])
        ))
    }

    @Test("한 번의 스왑으로 생긴 L과 T 모양을 구분한다")
    func shapesFromSwap() {
        // (3,9)의 soil이 (2,9)로 가면 가로줄의 오른쪽 끝이자 세로줄의 아래 끝이 된다.
        let lBoard = board.setting(.soil, at: [(2, 7), (2, 8)])
        let lResult = GameState(board: lBoard).performTurn(move)
        #expect(lResult.events[1].clearedMatches?.map(\.shape) == [.lShape])
        #expect(lResult.events[1].clearedMatches?[0].positions.count == 5)

        // (2,6)의 soil이 (2,7)로 내려가면 가로줄의 가운데이자 세로줄의 위 끝이 된다.
        let tBoard = Board.deadlocked.setting(.soil, at: [(1, 7), (3, 7), (2, 8), (2, 9), (2, 6)])
        let tResult = GameState(board: tBoard).performTurn(swap((2, 6), (2, 7)))
        #expect(tResult.events[1].clearedMatches?.map(\.shape) == [.tShape])
        #expect(tResult.events[1].clearedMatches?[0].positions.count == 5)
    }

    @Test("턴이 끝난 보드는 꽉 차 있고, 매치가 없고, 가능한 이동이 있다")
    func boardIsStableAfterEveryTurn() {
        for seed in 0..<10 as Range<UInt64> {
            var state = GameState(seed: seed)
            for turn in 0..<50 {
                let moves = state.board.possibleMoves()
                let result = state.performTurn(moves[(turn * 7) % moves.count])
                state = result.state
                #expect(state.board.isFull)
                #expect(state.board.findMatches().isEmpty)
                #expect(state.board.hasPossibleMove)
                #expect(state.board.columns == 8 && state.board.rows == 10)
            }
        }
    }

    @Test("이벤트를 순서대로 재생하면 결과 보드가 나온다", arguments: [3, 4, 5, 6, 7] as [UInt64])
    func eventsReplayToFinalBoard(seed: UInt64) {
        var state = GameState(seed: seed)
        for turn in 0..<80 {
            let moves = state.board.possibleMoves()
            let result = state.performTurn(moves[(turn * 5) % moves.count])
            #expect(replay(result.events, on: state.board) == result.state.board)
            state = result.state
        }
    }
}
