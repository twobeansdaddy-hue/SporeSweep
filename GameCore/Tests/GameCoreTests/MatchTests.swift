import Testing
@testable import GameCore

@Suite("매치 판정")
struct MatchTests {
    @Test("매치가 없는 보드")
    func noMatches() {
        #expect(Board.deadlocked.findMatches().isEmpty)
    }

    @Test("2개는 매치가 아니다")
    func twoIsNotAMatch() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 9), (1, 9), (5, 3), (5, 4)])
        #expect(board.findMatches().isEmpty)
    }

    @Test("가로 3개")
    func horizontalThree() {
        let board = Board.deadlocked.setting(.soil, at: [(2, 4), (3, 4), (4, 4)])
        #expect(board.findMatches() == [
            Match(kind: .soil, shape: .line(.horizontal, length: 3), positions: [pos(2, 4), pos(3, 4), pos(4, 4)])
        ])
    }

    @Test("세로 3개")
    func verticalThree() {
        let board = Board.deadlocked.setting(.soil, at: [(7, 7), (7, 8), (7, 9)])
        #expect(board.findMatches() == [
            Match(kind: .soil, shape: .line(.vertical, length: 3), positions: [pos(7, 7), pos(7, 8), pos(7, 9)])
        ])
    }

    @Test("4개와 5개 일렬은 길이로 구분된다", arguments: [4, 5, 8])
    func longLines(length: Int) {
        let cells = (0..<length).map { ($0, 0) }
        let matches = Board.deadlocked.setting(.soil, at: cells).findMatches()
        #expect(matches.count == 1)
        #expect(matches[0].shape == .line(.horizontal, length: length))
        #expect(matches[0].positions.count == length)
    }

    @Test("세로 4개")
    func verticalFour() {
        let matches = Board.deadlocked.setting(.soil, at: [(3, 2), (3, 3), (3, 4), (3, 5)]).findMatches()
        #expect(matches.map(\.shape) == [.line(.vertical, length: 4)])
    }

    @Test("L 모양: 두 줄이 서로의 끝에서 만난다", arguments: [
        [(2, 5), (3, 5), (4, 5), (2, 6), (2, 7)],  // ┌
        [(2, 5), (3, 5), (4, 5), (4, 6), (4, 7)],  // ┐
        [(2, 7), (3, 7), (4, 7), (2, 5), (2, 6)],  // └
        [(2, 7), (3, 7), (4, 7), (4, 5), (4, 6)],  // ┘
    ])
    func lShape(cells: [(Int, Int)]) {
        let matches = Board.deadlocked.setting(.soil, at: cells).findMatches()
        #expect(matches.count == 1)
        #expect(matches[0].shape == .lShape)
        #expect(matches[0].kind == .soil)
        #expect(Set(matches[0].positions) == Set(cells.map { pos($0.0, $0.1) }))
        #expect(matches[0].positions.count == 5)
    }

    @Test("T 모양: 한 줄의 끝이 다른 줄의 가운데에 닿는다", arguments: [
        [(2, 5), (3, 5), (4, 5), (3, 6), (3, 7)],  // ┬
        [(2, 7), (3, 7), (4, 7), (3, 5), (3, 6)],  // ┴
        [(2, 5), (2, 6), (2, 7), (3, 6), (4, 6)],  // ├
        [(4, 5), (4, 6), (4, 7), (2, 6), (3, 6)],  // ┤
    ])
    func tShape(cells: [(Int, Int)]) {
        let matches = Board.deadlocked.setting(.soil, at: cells).findMatches()
        #expect(matches.count == 1)
        #expect(matches[0].shape == .tShape)
        #expect(Set(matches[0].positions) == Set(cells.map { pos($0.0, $0.1) }))
        #expect(matches[0].positions.count == 5)
    }

    @Test("십자 모양은 T로 분류한다")
    func plusShape() {
        let cells = [(2, 6), (3, 6), (4, 6), (3, 5), (3, 7)]
        let matches = Board.deadlocked.setting(.soil, at: cells).findMatches()
        #expect(matches.map(\.shape) == [.tShape])
        #expect(matches[0].positions.count == 5)
    }

    @Test("떨어져 있는 매치는 따로 센다")
    func separateMatches() {
        let board = Board.deadlocked
            .setting(.soil, at: [(0, 0), (1, 0), (2, 0)])
            .setting(.soil, at: [(5, 7), (5, 8), (5, 9)])
        #expect(board.findMatches().map(\.shape) == [
            .line(.horizontal, length: 3),
            .line(.vertical, length: 3),
        ])
    }

    @Test("나란히 붙은 두 줄은 칸을 공유하지 않으므로 따로 센다")
    func parallelLines() {
        let board = Board.deadlocked.setting(.soil, at: [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)])
        #expect(board.findMatches().map(\.shape) == [
            .line(.horizontal, length: 3),
            .line(.horizontal, length: 3),
        ])
    }

    @Test("종류가 다른 줄은 교차해도 합쳐지지 않는다")
    func differentKindsStaySeparate() {
        let board = Board(text: [
            "AAAC",
            "BCDC",
            "DBAC"
        ])
        let matches = board.findMatches()
        #expect(matches.map(\.kind) == [.brick, .glass])
        #expect(matches.map(\.shape) == [.line(.horizontal, length: 3), .line(.vertical, length: 3)])
    }

    @Test("빈칸은 매치가 되지 않는다")
    func emptyCellsDoNotMatch() {
        #expect(Board(columns: 8, rows: 10).findMatches().isEmpty)
    }

    @Test("칸 하나가 줄에 들어 있는지 검사")
    func hasMatchAt() {
        let board = Board.deadlocked.setting(.soil, at: [(2, 4), (3, 4), (4, 4)])
        #expect(board.hasMatch(at: pos(2, 4)))
        #expect(board.hasMatch(at: pos(3, 4)))
        #expect(board.hasMatch(at: pos(4, 4)))
        #expect(!board.hasMatch(at: pos(5, 4)))
        #expect(!board.hasMatch(at: pos(3, 3)))
    }
}
