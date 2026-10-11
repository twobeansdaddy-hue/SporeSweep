import Testing
@testable import GameCore

private func piece(_ column: Int, _ row: Int, _ width: Int, _ height: Int) -> MaterialPiece {
    MaterialPiece(origin: pos(column, row), width: width, height: height)
}

private func emptyCells(_ state: GameState) -> [Position] {
    state.board.positions(in: state.activeRange).filter { state.board[$0] == nil }
}

@Suite("흘러내림")
struct SlideTests {
    /// 보드 가운데의 가로 2칸 물질과, 그 왼쪽 칸 아래의 세로 3개 매치.
    let wide = piece(2, 3, 2, 1)
    var board: Board {
        Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(2, 4), (2, 5), (2, 6)])
    }

    @Test("기본으로 켜져 있다")
    func onByDefault() {
        #expect(GameState(seed: 1).blocksSlide)
        #expect(GameState(board: board, generator: SeededGenerator(seed: 1), materials: [wide]).blocksSlide)
    }

    @Test("끄면 물질 아래의 빈칸이 남는다")
    func gapsStayWhenOff() {
        let state = GameState(board: board, pieces: [wide], slide: false)
        #expect(!state.blocksSlide)
        let result = state.settle()
        #expect(emptyCells(result.state) == [pos(2, 4), pos(2, 5), pos(2, 6)])
        #expect(!result.events.contains { if case .slid = $0 { true } else { false } })
    }

    @Test("켜면 옆 열의 블록이 대각선으로 내려와 빈칸을 채운다")
    func fillsGapFromSide() {
        let result = GameState(board: board, pieces: [wide], slide: true).settle()
        #expect(emptyCells(result.state).isEmpty)
        // 한쪽만 지웠으므로 물질은 제자리다.
        #expect(result.state.materials == [wide])
        let slides = result.events.flatMap { event -> [BlockMove] in
            if case .slid(let moves) = event { return moves }
            return []
        }
        #expect(!slides.isEmpty)
        // 한 칸 옆, 한 칸 아래로만 움직인다.
        #expect(slides.allSatisfy { abs($0.to.column - $0.from.column) == 1 && $0.to.row == $0.from.row + 1 })
        // 처음에는 빈칸 셋이 모두 물질 바깥쪽인 1열에서 채워진다. 3열은 물질에 깔려 있어 움직이지 않는다.
        #expect(Set(slides.prefix(3)) == [
            BlockMove(from: pos(1, 5), to: pos(2, 6)),
            BlockMove(from: pos(1, 4), to: pos(2, 5)),
            BlockMove(from: pos(1, 3), to: pos(2, 4)),
        ])
        #expect(slides.allSatisfy { $0.from.column != 3 })
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("켜져 있어도 폭 전체를 한 번에 지우면 물질이 내려간다")
    func pieceStillFallsWhenFullWidthCleared() {
        let below = Board.deadlocked(rows: 16).placing(wide).setting(.soil, at: [(2, 4), (3, 4), (4, 4)])
        let result = GameState(board: below, pieces: [wide], slide: true).settle()
        #expect(result.state.materials[0].origin.row >= 4)
        #expect(emptyCells(result.state).isEmpty)
    }

    @Test("물질에 깔린 블록은 미끄러지지 않아서, 구멍 하나로 물질이 내려가지 않는다")
    func supportDoesNotSlideOut() {
        // 왼쪽 벽에 붙은 물질. 0열 빈칸을 채울 수 있는 것은 물질에 깔린 1열뿐이라 빈 채로 남는다.
        let atWall = piece(0, 3, 2, 1)
        let board = Board.deadlocked(rows: 16).placing(atWall).setting(.soil, at: [(0, 4), (0, 5), (0, 6)])
        let state = GameState(board: board, pieces: [atWall], slide: true)
        #expect(state.isUnderLargeMaterial(pos(1, 4)))
        #expect(!state.isUnderLargeMaterial(pos(2, 4)))
        #expect(!state.isUnderLargeMaterial(pos(1, 2)))

        let result = state.settle()
        #expect(emptyCells(result.state) == [pos(0, 4), pos(0, 5), pos(0, 6)])
        #expect(result.state.materials == [atWall])
        #expect(result.state.board[1, 4] == board[1, 4])
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("물질은 미끄러지지 않는다")
    func materialsDoNotSlide() {
        // (2,4)의 대각선 위에 한 칸짜리 물질을 둔다.
        let board = board.placing(.material, at: (1, 3))
        let state = GameState(
            board: board,
            pieces: [MaterialPiece(origin: pos(1, 3)), wide],
            slide: true
        )
        let result = state.settle()
        // 한 칸짜리 물질은 아래 블록이 빠져나가 제 열에서 떨어질 뿐, 옆 열로 넘어가지 않는다.
        #expect(result.state.materials[0].origin.column == 1)
        #expect(result.state.materials[1] == wide)
        #expect(result.state.materialPositions.count == 3)
    }

    @Test("특수 블록도 일반 블록처럼 미끄러진다")
    func specialsSlide() {
        var board = board
        board[1, 3] = .bomb
        let result = GameState(board: board, pieces: [wide], slide: true).settle()
        let slides = result.events.flatMap { event -> [BlockMove] in
            if case .slid(let moves) = event { return moves }
            return []
        }
        #expect(slides.contains(BlockMove(from: pos(1, 3), to: pos(2, 4))))
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("한 칸짜리 물질만 있는 판은 켜도 결과가 같다")
    func noEffectWithoutLargePieces() {
        func play(slide: Bool) -> [[GameEvent]] {
            var state = GameState(
                seed: 6, rows: 16, moves: 200,
                materials: [pos(2, 0), pos(5, 0)], blocksSlide: slide
            )
            var events: [[GameEvent]] = []
            while state.status == .playing {
                let result = state.performTurn(state.greedyMove())
                events.append(result.events)
                state = result.state
            }
            return events
        }
        #expect(play(slide: true) == play(slide: false))
    }

    @Test("흘러내림을 켠 16행 레벨을 처음부터 클리어까지 플레이한다", arguments: [1, 2, 3, 4] as [UInt64])
    func playToClear(seed: UInt64) {
        var state = GameState(
            seed: seed, rows: 16, moves: 5000,
            materialPieces: [piece(1, 0, 2, 1), piece(5, 0, 2, 2)],
            blocksSlide: true
        )
        var turns = 0
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            turns += 1
            #expect(replay(result.events, on: before.board) == state.board)
            #expect(state.materials.flatMap(\.cells).sorted() == state.materialPositions)
            #expect(state.board.findMatches(in: state.activeRange).isEmpty)
            // 남은 빈칸은 더 채울 수 없는 칸뿐이다. 대각선 위가 구간 밖이거나, 비었거나, 물질이거나, 물질에 깔려 있다.
            for gap in emptyCells(state) {
                for side in [-1, 1] {
                    let source = pos(gap.column + side, gap.row - 1)
                    let usable = state.board.contains(source)
                        && state.activeRange.contains(source.row)
                        && state.board[source] != nil
                        && state.board[source] != .material
                        && !state.isUnderLargeMaterial(source)
                    #expect(!usable, "\(gap)는 \(source)에서 채울 수 있다")
                }
            }
            if state.status == .playing {
                #expect(!state.possibleMoves().isEmpty)
            }
        }
        #expect(state.status == .won)
        print("흘러내림 seed \(seed): \(turns)턴에 클리어")
    }

    @Test("같은 시드와 같은 입력은 같은 결과를 낸다")
    func determinism() {
        func play() -> GameState {
            var state = GameState(
                seed: 12, rows: 16, moves: 80,
                materialPieces: [piece(1, 0, 2, 1), piece(5, 0, 2, 2)],
                blocksSlide: true
            )
            while state.status == .playing {
                state = state.performTurn(state.greedyMove()).state
            }
            return state
        }
        #expect(play() == play())
    }
}
