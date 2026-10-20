import Foundation

public enum Orientation: Hashable, Sendable, Codable {
    case horizontal
    case vertical
}

/// 매치의 모양. 4장의 특수 블록 생성 기준이 된다.
public enum MatchShape: Hashable, Sendable, Codable {
    /// 가로나 세로 한 줄. `length`는 3 이상이다.
    case line(Orientation, length: Int)
    /// 가로줄과 세로줄이 서로의 끝 칸에서 만난다.
    case lShape
    /// 가로줄과 세로줄이 적어도 한쪽의 끝이 아닌 칸에서 만난다. 십자 모양도 여기에 넣는다.
    case tShape
    /// 줄 없이 2×2 정사각형만으로 된 매치.
    case square
}

/// 한 번에 제거되는 같은 종류 블록의 묶음.
public struct Match: Hashable, Sendable, Codable {
    public var kind: BlockKind
    public var shape: MatchShape
    /// 매치에 포함된 칸. 정렬되어 있고 겹치지 않는다.
    public var positions: [Position]
    /// 매치를 이루는 줄 가운데 가장 긴 줄의 길이.
    public var longestLine: Int
    /// 가로줄과 세로줄이 만나는 칸. 한 줄짜리 매치는 `nil`이다.
    public var crossing: Position?
    /// 2×2 정사각형을 품었는지. 줄이 만드는 특수 블록이 없으면 청소 드론을 남긴다(4장).
    public var hasSquare: Bool

    public init(
        kind: BlockKind,
        shape: MatchShape,
        positions: [Position],
        longestLine: Int? = nil,
        crossing: Position? = nil,
        hasSquare: Bool? = nil
    ) {
        self.kind = kind
        self.shape = shape
        self.positions = positions.sorted()
        if let longestLine {
            self.longestLine = longestLine
        } else if case .line(_, let length) = shape {
            self.longestLine = length
        } else if shape == .square {
            self.longestLine = 2
        } else {
            self.longestLine = GameConstants.minimumMatchLength
        }
        self.crossing = crossing
        self.hasSquare = hasSquare ?? (shape == .square)
    }

    /// 이 매치가 만드는 특수 블록(4장). 5개 일렬, L·T 모양, 4개 일렬, 2×2 순으로 본다.
    public var createdSpecial: Special? {
        if longestLine >= 5 {
            return .core
        }
        switch shape {
        case .lShape, .tShape:
            return .bomb
        case .line(let orientation, let length) where length == 4:
            return .beam(orientation)
        case .line, .square:
            return hasSquare ? .drone : nil
        }
    }

    /// 연쇄 중에 특수 블록이 놓이는 가운데 칸. 모양이 꺾였으면 두 줄이 만나는 칸이다.
    public var center: Position {
        crossing ?? positions[(positions.count - 1) / 2]
    }
}

extension Board {
    private struct Run {
        var orientation: Orientation
        var positions: [Position]
    }

    /// 보드에 성립한 매치를 모두 찾는다.
    ///
    /// 한 칸을 공유하는 가로줄과 세로줄은 하나의 매치로 합친다.
    /// 결과는 각 매치의 첫 칸 순서로 정렬된다.
    /// `rows`를 주면 그 행 범위(활성 구간) 안의 블록만 본다.
    public func findMatches(in rows: Range<Int>? = nil) -> [Match] {
        let range = rowRange(rows)
        let runs = findRuns(in: range)
        let squares = findSquares(in: range)
        guard !runs.isEmpty || !squares.isEmpty else { return [] }

        // 칸을 공유하는 줄과 정사각형끼리 묶는다. 정사각형은 줄 뒤에 번호를 붙인다.
        let pieces: [[Position]] = runs.map(\.positions) + squares
        var group = Array(pieces.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while group[index] != index { index = group[index] }
            return index
        }
        var firstRunAt: [Position: Int] = [:]
        for (index, piece) in pieces.enumerated() {
            for position in piece {
                if let other = firstRunAt[position] {
                    let a = root(index), b = root(other)
                    group[max(a, b)] = min(a, b)
                } else {
                    firstRunAt[position] = index
                }
            }
        }

        var piecesByGroup: [Int: [Int]] = [:]
        for index in pieces.indices {
            piecesByGroup[root(index), default: []].append(index)
        }

        return piecesByGroup.values
            .map { members in
                let groupRuns = members.filter { $0 < runs.count }.map { runs[$0] }
                let hasSquare = members.contains { $0 >= runs.count }
                let positions = Set(members.flatMap { pieces[$0] })
                let (shape, crossing) = groupRuns.isEmpty ? (MatchShape.square, nil) : Self.shape(of: groupRuns)
                return Match(
                    kind: kind(at: pieces[members[0]][0])!,
                    shape: shape,
                    positions: Array(positions),
                    longestLine: groupRuns.map(\.positions.count).max() ?? 2,
                    crossing: crossing,
                    hasSquare: hasSquare
                )
            }
            .sorted { $0.positions[0] < $1.positions[0] }
    }

    /// 주어진 칸의 블록이 3개 이상의 줄에 들어 있는지.
    public func hasMatch(at position: Position, in rows: Range<Int>? = nil) -> Bool {
        let range = rowRange(rows)
        guard range.contains(position.row), let kind = kind(at: position) else { return false }
        func count(_ dc: Int, _ dr: Int) -> Int {
            var n = 0
            var p = Position(column: position.column + dc, row: position.row + dr)
            while contains(p), range.contains(p.row), self.kind(at: p) == kind {
                n += 1
                p = Position(column: p.column + dc, row: p.row + dr)
            }
            return n
        }
        let minimum = GameConstants.minimumMatchLength
        return count(-1, 0) + 1 + count(1, 0) >= minimum
            || count(0, -1) + 1 + count(0, 1) >= minimum
            || isInSquare(position, kind: kind, range: range)
    }

    /// 이 칸이 같은 종류 2×2 정사각형의 한 칸인지.
    func isInSquare(_ position: Position, kind: BlockKind, range: Range<Int>) -> Bool {
        for (dc, dr) in [(-1, -1), (0, -1), (-1, 0), (0, 0)] {
            let corner = Position(column: position.column + dc, row: position.row + dr)
            if squareCells(at: corner, range: range).map({ $0.allSatisfy { self.kind(at: $0) == kind } }) == true {
                return true
            }
        }
        return false
    }

    /// 왼쪽 위가 `corner`인 2×2의 네 칸. 보드나 행 범위를 벗어나면 `nil`이다.
    private func squareCells(at corner: Position, range: Range<Int>) -> [Position]? {
        let cells = [(0, 0), (1, 0), (0, 1), (1, 1)].map { Position(column: corner.column + $0.0, row: corner.row + $0.1) }
        return cells.allSatisfy { contains($0) && range.contains($0.row) } ? cells : nil
    }

    /// 같은 종류 블록 네 개로 된 2×2 정사각형을 모두 찾는다. 겹치는 정사각형도 따로 나온다.
    private func findSquares(in range: Range<Int>) -> [[Position]] {
        var squares: [[Position]] = []
        for row in range {
            for column in 0..<columns {
                guard let cells = squareCells(at: Position(column: column, row: row), range: range),
                      let kind = kind(at: cells[0]),
                      cells.allSatisfy({ self.kind(at: $0) == kind })
                else { continue }
                squares.append(cells)
            }
        }
        return squares
    }

    private func findRuns(in range: Range<Int>) -> [Run] {
        var runs: [Run] = []
        func scan(_ orientation: Orientation, line: [Position]) {
            var start = 0
            while start < line.count {
                var end = start + 1
                if let kind = kind(at: line[start]) {
                    while end < line.count, self.kind(at: line[end]) == kind { end += 1 }
                    if end - start >= GameConstants.minimumMatchLength {
                        runs.append(Run(orientation: orientation, positions: Array(line[start..<end])))
                    }
                }
                start = end
            }
        }
        for row in range {
            scan(.horizontal, line: (0..<columns).map { Position(column: $0, row: row) })
        }
        for column in 0..<columns {
            scan(.vertical, line: range.map { Position(column: column, row: $0) })
        }
        return runs
    }

    private static func shape(of runs: [Run]) -> (MatchShape, crossing: Position?) {
        if runs.count == 1 {
            return (.line(runs[0].orientation, length: runs[0].positions.count), nil)
        }
        // 줄 안에서 블록은 한 줄로 늘어서 있으므로 첫 칸과 끝 칸이 줄의 양 끝이다.
        func isEnd(_ position: Position, of run: Run) -> Bool {
            position == run.positions.first || position == run.positions.last
        }
        let horizontals = runs.filter { $0.orientation == .horizontal }
        let verticals = runs.filter { $0.orientation == .vertical }
        var firstCrossing: Position?
        var shape = MatchShape.lShape
        for horizontal in horizontals {
            for vertical in verticals {
                guard let crossing = horizontal.positions.first(where: vertical.positions.contains) else {
                    continue
                }
                firstCrossing = firstCrossing ?? crossing
                if !isEnd(crossing, of: horizontal) || !isEnd(crossing, of: vertical) {
                    shape = .tShape
                }
            }
        }
        guard let firstCrossing else {
            let longest = runs.max { $0.positions.count < $1.positions.count }!
            return (.line(longest.orientation, length: longest.positions.count), nil)
        }
        return (shape, firstCrossing)
    }
}
