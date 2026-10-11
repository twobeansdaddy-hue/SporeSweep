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

    public init(
        kind: BlockKind,
        shape: MatchShape,
        positions: [Position],
        longestLine: Int? = nil,
        crossing: Position? = nil
    ) {
        self.kind = kind
        self.shape = shape
        self.positions = positions.sorted()
        if let longestLine {
            self.longestLine = longestLine
        } else if case .line(_, let length) = shape {
            self.longestLine = length
        } else {
            self.longestLine = GameConstants.minimumMatchLength
        }
        self.crossing = crossing
    }

    /// 이 매치가 만드는 특수 블록(4장). 5개 일렬, L·T 모양, 4개 일렬 순으로 본다.
    public var createdSpecial: Special? {
        if longestLine >= 5 {
            return .core
        }
        switch shape {
        case .lShape, .tShape:
            return .bomb
        case .line(let orientation, let length):
            return length == 4 ? .beam(orientation) : nil
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
        let runs = findRuns(in: rowRange(rows))
        guard !runs.isEmpty else { return [] }

        // 칸을 공유하는 줄끼리 묶는다.
        var group = Array(runs.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while group[index] != index { index = group[index] }
            return index
        }
        var firstRunAt: [Position: Int] = [:]
        for (index, run) in runs.enumerated() {
            for position in run.positions {
                if let other = firstRunAt[position] {
                    let a = root(index), b = root(other)
                    group[max(a, b)] = min(a, b)
                } else {
                    firstRunAt[position] = index
                }
            }
        }

        var runsByGroup: [Int: [Run]] = [:]
        for (index, run) in runs.enumerated() {
            runsByGroup[root(index), default: []].append(run)
        }

        return runsByGroup.values
            .map { groupRuns in
                let positions = Set(groupRuns.flatMap(\.positions))
                let (shape, crossing) = Self.shape(of: groupRuns)
                return Match(
                    kind: kind(at: groupRuns[0].positions[0])!,
                    shape: shape,
                    positions: Array(positions),
                    longestLine: groupRuns.map(\.positions.count).max(),
                    crossing: crossing
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
        return (shape, firstCrossing)
    }
}
