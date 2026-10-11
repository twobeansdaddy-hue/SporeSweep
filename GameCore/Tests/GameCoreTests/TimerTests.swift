import Testing
@testable import GameCore

@Suite("시한 포자")
struct TimerTests {
    /// 포자에서 멀리 떨어진 맨 아래 행의 매치.
    let farMove = swap((3, 9), (2, 9))

    private func board(turns: Int) -> Board {
        let base = Board.deadlocked(rows: 16).setting(.soil, at: [(0, 9), (1, 9), (3, 9)])
        return base.placing(.timed(base.kind(at: pos(6, 2))!, turns: turns), at: (6, 2))
    }

    @Test("보통 블록처럼 종류가 있고 밀 수 있으며 떨어진다")
    func properties() {
        let block = Block.timed(.brick, turns: 5)
        #expect(block.kind == .brick)
        #expect(block.isSwappable)
        #expect(!block.isFixed)
        #expect(block.canSlide)
        #expect(!block.takesAdjacentHits)
        #expect(block.withoutTimer == .normal(.brick))
    }

    @Test("턴마다 숫자가 1씩 준다")
    func ticks() {
        let board = board(turns: 5)
        let result = GameState(board: board).performTurn(farMove)
        #expect(result.events.contains(.timersTicked([TimerTick(position: pos(6, 2), turns: 4)])))
        #expect(result.state.board[pos(6, 2)] == .timed(board.kind(at: pos(6, 2))!, turns: 4))
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("0이 되면 터져서 제자리와 옆 칸이 슬러지가 된다")
    func bursts() {
        let board = board(turns: 1)
        let result = GameState(board: board).performTurn(farMove)
        let bursts = result.events.flatMap { event -> [TimerBurst] in
            if case .timersBurst(let bursts) = event { return bursts }
            return []
        }
        #expect(bursts.count == 1)
        #expect(Set(bursts[0].sludge) == [pos(6, 2), pos(6, 1), pos(6, 3), pos(5, 2), pos(7, 2)])
        for position in bursts[0].sludge {
            #expect(result.state.board[position] == .sludge)
        }
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("그 전에 매치해서 없애면 터지지 않는다")
    func defusedByMatch() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 9), (1, 9)])
            .placing(.timed(.soil, turns: 1), at: (3, 9))
        let result = GameState(board: board).performTurn(swap((3, 9), (2, 9)))
        #expect(!result.events.contains { if case .timersBurst = $0 { true } else { false } })
        #expect(!result.state.board.positions.contains { result.state.board[$0] == .sludge })
    }

    @Test("특수 블록과 스왑하면 보통 블록과 스왑한 것처럼 발동한다")
    func swapsWithSpecial() {
        let board = Board.deadlocked(rows: 16)
            .placing(.beam(.horizontal), at: (3, 5))
            .placing(.timed(.brick, turns: 4), at: (4, 5))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events.contains { if case .specialsActivated = $0 { true } else { false } })
    }

    @Test("레벨에 놓으면 그 칸의 블록에 달라붙는다")
    func placedOnGeneratedBlock() {
        let state = GameState(
            seed: 3, rows: 16, moves: 30, materials: [pos(2, 0)],
            obstacles: [Obstacle(kind: .timer(turns: 7), position: pos(4, 5))]
        )
        guard case .timed(_, let turns) = state.board[pos(4, 5)] else {
            Issue.record("시한 포자가 없다")
            return
        }
        #expect(turns == 7)
    }

    @Test("시한 포자가 놓인 판을 끝까지 플레이할 수 있다")
    func playsToEnd() {
        var state = GameState(
            seed: 8, rows: 16, moves: 400, materials: [pos(2, 0), pos(5, 0)],
            obstacles: [(1, 4), (5, 6), (3, 8)].map { Obstacle(kind: .timer(turns: 4), position: pos($0.0, $0.1)) }
        )
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            #expect(replay(result.events, on: before.board) == state.board)
        }
        #expect(state.status == .won)
    }
}
