import Testing
@testable import GameCore

@Suite("오염 물질")
struct MaterialTests {
    @Test("물질은 매치되지 않는다")
    func materialsDoNotMatch() {
        let board = Board.deadlocked
            .placing(.material, at: (2, 4)).placing(.material, at: (3, 4)).placing(.material, at: (4, 4))
        #expect(Block.material.kind == nil)
        #expect(!Block.material.isSpecial)
        #expect(board.findMatches().isEmpty)
    }

    @Test("물질은 일반 블록처럼 떨어진다")
    func materialsFall() {
        var board = Board.deadlocked.placing(.material, at: (2, 3)).setting(nil, at: [(2, 4), (2, 5)])
        board.applyGravity()
        #expect(board[2, 5] == .material)
    }

    @Test("물질과의 스왑은 매치가 성립할 때만 허용한다")
    func materialSwapNeedsMatch() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 5), (1, 5), (3, 5)])
            .placing(.material, at: (2, 5))
        // soil이 (2,5)로 오면 가로 3개가 되고 물질은 옆 열로 옮겨진다.
        let move = swap((2, 5), (3, 5))
        #expect(board.isValid(move))
        #expect(replay(Array(GameState(board: board).performTurn(move).events.prefix(1)), on: board)[3, 5] == .material)
        // 매치가 안 되는 방향은 거부한다.
        #expect(board.rejection(for: swap((2, 5), (2, 4))) == .noMatch)
        #expect(board.rejection(for: swap((2, 5), (2, 6))) == .noMatch)
    }

    @Test("물질끼리, 물질과 정화 코어의 스왑은 거부한다")
    func materialWithCoreOrMaterial() {
        let board = Board.deadlocked
            .placing(.material, at: (2, 5)).placing(.core, at: (3, 5)).placing(.material, at: (2, 6))
        #expect(board.rejection(for: swap((2, 5), (3, 5))) == .noMatch)
        #expect(board.rejection(for: swap((3, 5), (2, 5))) == .noMatch)
        #expect(board.rejection(for: swap((2, 5), (2, 6))) == .noMatch)
        // 코어는 다른 블록과는 여전히 스왑된다.
        #expect(board.isValid(swap((3, 5), (4, 5))))
    }

    @Test("물질은 어떤 특수 효과로도 제거되지 않는다")
    func effectsDoNotRemoveMaterials() {
        let move = swap((3, 5), (4, 5))
        let combos: [(Block, Block)] = [
            (.beam(.horizontal), .beam(.vertical)),
            (.beam(.horizontal), .bomb),
            (.bomb, .bomb),
            (.core, .core),
            (.core, .bomb),
            (.core, .beam(.horizontal)),
        ]
        for (dragged, target) in combos {
            // 효과 범위 안에 물질 둘을 둔다. 16행 보드라 물질이 바닥에 닿아 수거되지는 않는다.
            let board = Board.deadlocked(rows: 16)
                .placing(dragged, at: (3, 5)).placing(target, at: (4, 5))
                .placing(.material, at: (4, 4)).placing(.material, at: (5, 5))
            let state = GameState(board: board)
            let result = state.performTurn(move)
            let cleared = result.events.compactMap(\.activations).flatMap { $0 }.flatMap(\.cleared)
            #expect(!cleared.contains(pos(4, 4)))
            #expect(!cleared.contains(pos(5, 5)))
            #expect(result.state.materialsRemaining == 2)
        }
    }

    @Test("정화 코어 + 정화 코어는 물질만 남기고 전부 지운다")
    func clearBoardLeavesMaterials() {
        let board = Board.deadlocked(rows: 16)
            .placing(.core, at: (3, 5)).placing(.core, at: (4, 5)).placing(.material, at: (0, 0))
        let result = GameState(board: board).performTurn(swap((3, 5), (4, 5)))
        #expect(result.events[1].activations?[0].cleared.count == 79)
        #expect(result.state.materialsRemaining == 1)
    }

    @Test("셔플은 물질을 제자리에 둔다")
    func shuffleKeepsMaterials() {
        let board = Board.deadlocked.placing(.material, at: (2, 0)).placing(.material, at: (5, 4))
        for seed in 0..<30 as Range<UInt64> {
            let result = GameState(board: board, seed: seed).settle()
            guard case .shuffled(let moves) = result.events.last else {
                Issue.record("seed \(seed): 셔플 이벤트가 없다")
                continue
            }
            #expect(result.state.materialPositions == [pos(2, 0), pos(5, 4)])
            #expect(!moves.contains { [$0.from, $0.to].contains(pos(2, 0)) || [$0.from, $0.to].contains(pos(5, 4)) })
        }
    }
}

@Suite("활성 구간")
struct ActiveZoneTests {
    let tall = Board.deadlocked(rows: 16)

    @Test("긴 보드도 매치와 가능한 이동이 없는 무늬다")
    func tallBoardIsDeadlocked() {
        #expect(tall.rows == 16)
        #expect(tall.findMatches().isEmpty)
        #expect(!tall.hasPossibleMove)
    }

    @Test("활성 구간은 맨 위 행부터 10행이다")
    func activeRange() {
        #expect(GameState(board: tall).activeRange == 0..<10)
        #expect(GameState(board: tall, activeTop: 6).activeRange == 6..<16)
        #expect(GameState(board: .deadlocked).activeRange == 0..<10)
    }

    @Test("활성 구간 밖의 매치는 처리하지 않는다")
    func matchesOutsideAreIgnored() {
        let below = tall.setting(.soil, at: [(2, 12), (3, 12), (4, 12)])
        #expect(below.findMatches(in: 0..<10).isEmpty)
        // 구간 경계에 걸친 줄도 매치가 아니다.
        let straddling = tall.setting(.soil, at: [(2, 8), (2, 9), (2, 10)])
        #expect(straddling.findMatches(in: 0..<10).isEmpty)
        #expect(straddling.findMatches(in: 1..<11).count == 1)

        // 가능한 이동이 없어 셔플만 하고, 구간 아래는 건드리지 않는다.
        let result = GameState(board: below).settle()
        #expect(result.events.allSatisfy { $0.clearedMatches == nil })
        for position in below.positions(in: 10..<16) {
            #expect(result.state.board[position] == below[position])
        }
    }

    @Test("활성 구간 밖의 칸은 스왑할 수 없다")
    func swapsOutsideAreRejected() {
        let board = tall.setting(.soil, at: [(0, 12), (1, 12), (3, 12)])
        #expect(board.isValid(swap((3, 12), (2, 12))))
        #expect(board.rejection(for: swap((3, 12), (2, 12)), in: 0..<10) == .outOfBounds)
        // 구간의 맨 아래 행과 그 아래 행의 스왑도 안 된다.
        #expect(board.rejection(for: swap((0, 9), (0, 10)), in: 0..<10) == .outOfBounds)
        let state = GameState(board: board)
        #expect(state.performTurn(swap((3, 12), (2, 12))).events == [
            .swapRejected(swap((3, 12), (2, 12)), .outOfBounds)
        ])
        #expect(state.possibleMoves().isEmpty)
    }

    @Test("구간 밖 블록과 이어져야 하는 매치는 가능한 이동이 아니다")
    func movesNeedMatchInsideZone() {
        // soil이 (2,9)로 오면 (2,10), (2,11)과 세로 3개지만 둘은 구간 밖이다.
        let board = tall.setting(.soil, at: [(3, 9), (2, 10), (2, 11)])
        #expect(board.isValid(swap((3, 9), (2, 9))))
        #expect(!board.isValid(swap((3, 9), (2, 9)), in: 0..<10))
    }

    @Test("특수 효과는 활성 구간 안에서만 적용된다")
    func effectsAreClippedToZone() {
        // 세로 빔을 옮겨 발동한다. 16행 보드지만 구간의 10행만 지운다.
        let board = tall.placing(.beam(.vertical), at: (1, 9))
        let events = GameState(board: board).performTurn(swap((1, 9), (0, 9))).events
        #expect(events[1].activations?[0].cleared == (0...9).map { pos(0, $0) })

        // 코어 조합도 구간 안의 블록만 지운다.
        let cores = tall.placing(.core, at: (3, 5)).placing(.core, at: (4, 5))
        let cleared = GameState(board: cores).performTurn(swap((3, 5), (4, 5))).events[1].activations![0].cleared
        #expect(cleared.count == 80)
        #expect(cleared.allSatisfy { $0.row < 10 })
    }

    @Test("낙하와 보충은 활성 구간 안에서만 일어나고 그 아래 행은 변하지 않는다")
    func belowZoneIsUntouched() {
        var state = GameState(seed: 3, rows: 16)
        #expect(state.board.rows == 16)
        for turn in 0..<40 {
            let before = state.board
            let moves = state.possibleMoves()
            #expect(moves.allSatisfy { $0.from.row < 10 && $0.to.row < 10 })
            let result = state.performTurn(moves[(turn * 7) % moves.count])
            state = result.state
            for position in before.positions(in: 10..<16) {
                #expect(state.board[position] == before[position])
            }
            for case .refilled(let spawns) in result.events {
                #expect(spawns.allSatisfy { $0.position.row < 10 })
            }
            #expect(state.activeTop == 0)
        }
    }
}

@Suite("카메라와 물질 수거")
struct CameraTests {
    /// (2,0)의 물질 아래에 세로 3개 매치가 있는 16행 보드.
    let board = Board.deadlocked(rows: 16)
        .placing(.material, at: (2, 0))
        .setting(.soil, at: [(2, 1), (2, 2), (2, 3)])

    @Test("물질이 내려가면 활성 구간의 맨 위가 물질의 한 행 위로 따라간다")
    func cameraFollowsMaterial() {
        let result = GameState(board: board).settle()
        let material = result.state.materialPositions[0]
        #expect(material.row >= 3)
        #expect(result.state.activeTop == material.row - 1)
        #expect(result.events.contains(.scrolled(from: 0, to: result.state.activeTop)))
        #expect(result.state.activeRange == (material.row - 1)..<(material.row + 9))
    }

    @Test("지나간 행은 버려진다")
    func passedRowsAreDiscarded() {
        let state = GameState(board: board).settle().state
        for position in state.board.positions(in: 0..<state.activeTop) {
            #expect(state.board[position] == nil)
        }
        for position in state.board.positions(in: state.activeTop..<16) {
            #expect(state.board[position] != nil)
        }
    }

    @Test("물질이 맨 위 행에 있으면 카메라는 움직이지 않는다")
    func cameraStaysAtStart() {
        let state = GameState(board: Board.deadlocked(rows: 16).placing(.material, at: (2, 0)))
        let result = state.settle()
        #expect(result.state.activeTop == 0)
        #expect(!result.events.contains { if case .scrolled = $0 { true } else { false } })
    }

    @Test("카메라는 가장 위에 있는 물질을 따른다")
    func cameraFollowsTopmostMaterial() {
        // 먼저 내려간 물질이 있어도 뒤처진 물질이 맨 위 행에 있으면 움직이지 않는다.
        let two = Board.deadlocked(rows: 16).placing(.material, at: (2, 0)).placing(.material, at: (5, 7))
        #expect(GameState(board: two).settle().state.activeTop == 0)
        let lower = Board.deadlocked(rows: 16).placing(.material, at: (2, 4)).placing(.material, at: (5, 7))
        #expect(GameState(board: lower).settle().state.activeTop == 3)
    }

    @Test("카메라는 보드 끝에서 멈춘다")
    func cameraStopsAtBoardEnd() {
        let state = GameState(board: Board.deadlocked(rows: 16).placing(.material, at: (2, 13)))
        let result = state.settle()
        #expect(result.state.activeTop == 6)
        #expect(result.state.activeRange == 6..<16)
    }

    @Test("스크롤로 들어온 행에서 생긴 매치는 연쇄로 처리하고 이동 횟수를 줄이지 않는다")
    func scrollTriggersCascade() {
        // (5,9)~(5,11)의 세로 3개는 (5,10), (5,11)이 구간 밖이라 처음에는 매치가 아니다.
        let seam = board.setting(.soil, at: [(5, 9), (5, 10), (5, 11)])
        #expect(seam.findMatches(in: 0..<10).map(\.positions) == [[pos(2, 1), pos(2, 2), pos(2, 3)]])

        let result = GameState(board: seam, moves: 10).settle()
        let scrollIndex = result.events.firstIndex { if case .scrolled = $0 { true } else { false } }!
        let seamIndex = result.events.firstIndex {
            $0.clearedMatches?.contains { $0.positions == [pos(5, 9), pos(5, 10), pos(5, 11)] } == true
        }
        #expect(seamIndex != nil && seamIndex! > scrollIndex)
        #expect(result.state.movesRemaining == 10)
        #expect(replay(result.events, on: seam) == result.state.board)
    }

    @Test("마지막 행에 닿은 물질은 수거되고, 모두 수거하면 승리다")
    func collectionAndWin() {
        // 12행 보드의 끝. (2,10)의 물질 아래에서 가로 3개를 맞추면 물질이 마지막 행으로 떨어진다.
        let board = Board.deadlocked(rows: 12)
            .placing(.material, at: (2, 10))
            .setting(.soil, at: [(0, 11), (1, 11), (2, 9)])
            .setting(.soil, at: [(3, 11)])
        let state = GameState(board: board, activeTop: 2, moves: 5)
        #expect(state.materialsTotal == 1)
        #expect(state.status == .playing)

        let result = state.performTurn(swap((3, 11), (2, 11)))
        #expect(result.events.contains(.materialsCollected([pos(2, 11)])))
        #expect(result.events.last == .won)
        #expect(result.state.status == .won)
        #expect(result.state.materialsRemaining == 0)
        #expect(result.state.movesRemaining == 4)
        // 수거된 자리는 다시 채워진다.
        #expect(result.state.board.positions(in: result.state.activeRange).allSatisfy { result.state.board[$0] != nil })
        #expect(replay(result.events, on: board) == result.state.board)
    }

    @Test("마지막 이동에서 모두 수거하면 실패가 아니라 승리다")
    func winOnLastMove() {
        let board = Board.deadlocked(rows: 12)
            .placing(.material, at: (2, 10))
            .setting(.soil, at: [(0, 11), (1, 11), (3, 11)])
        let result = GameState(board: board, activeTop: 2, moves: 1).performTurn(swap((3, 11), (2, 11)))
        #expect(result.state.movesRemaining == 0)
        #expect(result.state.status == .won)
        #expect(!result.events.contains(.lost))
    }

    @Test("물질은 활성 구간의 바닥에서 멈춘다")
    func materialStopsAtZoneBottom() {
        // 구간 바닥인 9행의 물질. 아래 행은 조작할 수 없으므로 더 내려가지 않고 수거되지도 않는다.
        let board = Board.deadlocked(rows: 16).placing(.material, at: (2, 0)).placing(.material, at: (5, 9))
        var state = GameState(board: board, seed: 4)
        for _ in 0..<20 where state.status == .playing && state.activeTop == 0 {
            state = state.performTurn(state.possibleMoves().first ?? swap((0, 0), (1, 0))).state
            state = state.settle().state
            #expect(state.board[5, 9] == .material || state.activeTop > 0)
        }
    }
}

@Suite("이동 횟수와 승패")
struct MovesTests {
    let board = Board.deadlocked(rows: 16)
        .placing(.material, at: (2, 0))
        .setting(.soil, at: [(5, 9), (6, 9)])
        .setting(.soil, at: [(7, 8)])

    @Test("유효한 스왑 한 번에 1씩 줄고, 거부된 스왑은 줄이지 않는다")
    func movesDecrement() {
        let state = GameState(board: board, moves: 3)
        let rejected = state.performTurn(swap((0, 0), (1, 0)))
        #expect(rejected.state.movesRemaining == 3)
        let result = state.performTurn(swap((7, 8), (7, 9)))
        #expect(result.state.movesRemaining == 2)
    }

    @Test("연쇄가 얼마나 이어져도 한 턴에 1만 준다")
    func cascadesDoNotCostMoves() {
        var state = GameState(seed: 9, rows: 16, moves: 500, materials: [pos(2, 0), pos(5, 0)])
        var turns = 0
        while state.status == .playing && turns < 60 {
            let result = state.performTurn(state.possibleMoves()[0])
            turns += 1
            #expect(result.state.movesRemaining == 500 - turns)
            state = result.state
        }
    }

    @Test("물질을 남긴 채 이동 횟수가 떨어지면 실패다")
    func loseWhenOutOfMoves() {
        let result = GameState(board: board, moves: 1).performTurn(swap((7, 8), (7, 9)))
        #expect(result.state.movesRemaining == 0)
        #expect(result.state.status == .lost)
        #expect(result.events.last == .lost)
        // 실패한 판에서는 셔플하지 않는다.
        #expect(!result.events.contains { if case .shuffled = $0 { true } else { false } })
    }

    @Test("끝난 판에서는 스왑을 받지 않는다")
    func noSwapsAfterGameOver() {
        let lost = GameState(board: board, moves: 1).performTurn(swap((7, 8), (7, 9))).state
        let move = swap((0, 0), (1, 0))
        let result = lost.performTurn(move)
        #expect(result.events == [.swapRejected(move, .gameOver)])
        #expect(result.state == lost)
    }

    @Test("물질도 이동 제한도 없는 판은 끝나지 않는다")
    func freePlayNeverEnds() {
        var state = GameState(seed: 2)
        #expect(state.materialsTotal == 0)
        #expect(state.movesRemaining == nil)
        for _ in 0..<50 {
            state = state.performTurn(state.possibleMoves()[0]).state
            #expect(state.status == .playing)
        }
    }
}

@Suite("레벨 생성과 플레이")
struct LevelPlayTests {
    let materials = [pos(2, 0), pos(5, 0)]

    func level(seed: UInt64, moves: Int = 25) -> GameState {
        GameState(seed: seed, rows: 16, moves: moves, materials: materials)
    }

    @Test("물질은 지정한 칸에 놓이고 나머지는 시드로 채운다")
    func generation() {
        for seed in 0..<100 as Range<UInt64> {
            let state = level(seed: seed)
            #expect(state.board.rows == 16)
            #expect(state.board.isFull)
            #expect(state.materialPositions == materials)
            #expect(state.materialsTotal == 2)
            #expect(state.movesRemaining == 25)
            #expect(state.activeTop == 0)
            #expect(state.status == .playing)
            // 보드 전체에 맞춰진 매치가 없고, 첫 활성 구간에 가능한 이동이 있다.
            #expect(state.board.findMatches().isEmpty, "seed \(seed)")
            #expect(!state.possibleMoves().isEmpty, "seed \(seed)")
        }
        #expect(level(seed: 1004) == level(seed: 1004))
        #expect(level(seed: 1004).board != level(seed: 1005).board)
    }

    @Test("16행 레벨을 처음부터 클리어까지 플레이한다", arguments: [1004, 1, 2, 3, 4, 5, 6, 7] as [UInt64])
    func playToClear(seed: UInt64) {
        var state = level(seed: seed, moves: 200)
        var turns = 0
        while state.status == .playing {
            let before = state
            let result = state.performTurn(state.greedyMove())
            state = result.state
            turns += 1

            #expect(replay(result.events, on: before.board) == state.board)
            // 카메라는 위로 돌아가지 않고 보드 끝을 넘지 않는다.
            #expect(state.activeTop >= before.activeTop)
            #expect(state.activeTop <= 6)
            if let topmost = state.materialPositions.map(\.row).min() {
                #expect(state.activeTop == min(max(topmost - 1, 0), 6))
            }
            // 물질은 늘 활성 구간 안에 있다.
            #expect(state.materialPositions.allSatisfy { state.activeRange.contains($0.row) })
            // 활성 구간은 꽉 차 있고 매치가 없다. 지나간 행은 비어 있다.
            #expect(state.board.positions(in: state.activeRange).allSatisfy { state.board[$0] != nil })
            #expect(state.board.positions(in: 0..<state.activeTop).allSatisfy { state.board[$0] == nil })
            #expect(state.board.findMatches(in: state.activeRange).isEmpty)
            // 구간 아래의 행은 화면에 들어오기 전까지 변하지 않는다.
            for position in state.board.positions(in: state.activeRange.upperBound..<16) {
                #expect(state.board[position] == before.board[position])
            }
            if state.status == .playing {
                #expect(!state.possibleMoves().isEmpty)
            }
        }
        #expect(state.status == .won)
        #expect(state.materialsRemaining == 0)
        #expect(state.movesRemaining == 200 - turns)
        print("seed \(seed): \(turns)턴에 클리어")
    }

    @Test("같은 시드와 같은 입력은 같은 결과를 낸다")
    func determinism() {
        func play() -> [TurnResult] {
            var state = level(seed: 1004, moves: 200)
            var results: [TurnResult] = []
            while state.status == .playing {
                let result = state.performTurn(state.greedyMove())
                results.append(result)
                state = result.state
            }
            return results
        }
        #expect(play() == play())
    }
}
