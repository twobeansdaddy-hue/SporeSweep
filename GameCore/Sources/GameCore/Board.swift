import Foundation

/// 블록 한 개가 한 칸에서 다른 칸으로 옮겨간 기록.
public struct BlockMove: Hashable, Sendable, Codable {
    public var from: Position
    public var to: Position

    public init(from: Position, to: Position) {
        self.from = from
        self.to = to
    }
}

/// 블록이 놓인 격자. 빈칸은 `nil`이다.
public struct Board: Hashable, Sendable, Codable {
    public let columns: Int
    public let rows: Int
    private var cells: [Block?]

    /// 빈 보드를 만든다.
    public init(columns: Int = GameConstants.columns, rows: Int = GameConstants.activeRows) {
        precondition(columns > 0 && rows > 0, "보드 크기는 1 이상이어야 한다")
        self.columns = columns
        self.rows = rows
        cells = Array(repeating: nil, count: columns * rows)
    }

    /// 행 단위 배열로 보드를 만든다. `grid[0]`이 맨 위 행이다.
    public init(_ grid: [[Block?]]) {
        precondition(!grid.isEmpty && !grid[0].isEmpty, "보드 크기는 1 이상이어야 한다")
        precondition(grid.allSatisfy { $0.count == grid[0].count }, "모든 행의 길이가 같아야 한다")
        columns = grid[0].count
        rows = grid.count
        cells = grid.flatMap { $0 }
    }

    public subscript(column: Int, row: Int) -> Block? {
        get { cells[row * columns + column] }
        set { cells[row * columns + column] = newValue }
    }

    public subscript(position: Position) -> Block? {
        get { self[position.column, position.row] }
        set { self[position.column, position.row] = newValue }
    }

    /// 칸에 놓인 블록의 종류. 빈칸과 정화 코어는 `nil`이다.
    public func kind(at position: Position) -> BlockKind? {
        self[position]?.kind
    }

    public func contains(_ position: Position) -> Bool {
        (0..<columns).contains(position.column) && (0..<rows).contains(position.row)
    }

    /// 모든 칸. 위에서 아래로, 왼쪽에서 오른쪽 순서다.
    public var positions: [Position] {
        (0..<rows).flatMap { row in
            (0..<columns).map { Position(column: $0, row: row) }
        }
    }

    /// 주어진 행 범위의 칸. 범위를 생략하면 보드 전체다.
    public func positions(in rows: Range<Int>?) -> [Position] {
        rowRange(rows).flatMap { row in
            (0..<columns).map { Position(column: $0, row: row) }
        }
    }

    /// 보드 안으로 잘라낸 행 범위.
    func rowRange(_ rows: Range<Int>?) -> Range<Int> {
        (rows ?? 0..<self.rows).clamped(to: 0..<self.rows)
    }

    public var isFull: Bool {
        !cells.contains(nil)
    }

    public mutating func swapAt(_ a: Position, _ b: Position) {
        let block = self[a]
        self[a] = self[b]
        self[b] = block
    }

    /// 빈칸 위의 블록을 아래로 떨어뜨린다. 블록의 위아래 순서는 유지된다.
    ///
    /// `rows`를 주면 그 행 범위 안에서만 떨어진다. 범위 밖의 블록은 움직이지 않는다.
    /// - Returns: 자리가 바뀐 칸의 이동 목록. 열 순서, 같은 열에서는 아래쪽 블록이 먼저다.
    @discardableResult
    public mutating func applyGravity(in rows: Range<Int>? = nil) -> [BlockMove] {
        var pieces: [MaterialPiece] = []
        return applyGravity(in: rows, pieces: &pieces)
    }

    /// 물질 덩어리를 한 몸으로 다루는 낙하.
    ///
    /// 큰 물질은 폭 전체의 바로 아래 칸이 비어야 한 칸 내려간다. 한쪽만 비면 그 칸은
    /// 빈 채로 남고, 물질 위의 블록도 물질에 얹혀 그대로 있다.
    /// `pieces`의 위치는 낙하에 맞춰 갱신된다. 이동 목록에는 물질이 덮은 칸이 하나씩 들어간다.
    @discardableResult
    public mutating func applyGravity(in rows: Range<Int>? = nil, pieces: inout [MaterialPiece]) -> [BlockMove] {
        let range = rowRange(rows)
        // 지금 칸 → 처음 있던 칸. 움직인 블록만 들어 있다.
        var origins: [Position: Position] = [:]
        func shift(_ board: inout Board, from: Position, to: Position, origins: inout [Position: Position]) {
            board[to] = board[from]
            board[from] = nil
            origins[to] = origins.removeValue(forKey: from) ?? from
        }

        // 한 번에 한 칸씩, 더 움직일 블록이 없을 때까지 내린다.
        var moved = true
        while moved {
            moved = false
            for row in range.reversed() where row + 1 < range.upperBound {
                for column in 0..<columns {
                    let position = Position(column: column, row: row)
                    // 콘크리트와 슬러지는 떨어지지 않는다. 그 위의 블록은 얹혀서 멈춘다.
                    guard let block = self[position], !block.isFixed else { continue }
                    let index = self[position] == .material ? pieces.firstIndex { $0.contains(position) } : nil

                    if let index, pieces[index].isLarge {
                        let piece = pieces[index]
                        // 덩어리는 맨 아래 행의 왼쪽 칸에서 한 번만 처리한다.
                        guard position == Position(column: piece.origin.column, row: piece.bottomRow) else { continue }
                        let below = piece.columns.map { Position(column: $0, row: piece.bottomRow + 1) }
                        guard below.allSatisfy({ self[$0] == nil }) else { continue }
                        for cell in piece.cells.reversed() {
                            shift(&self, from: cell, to: Position(column: cell.column, row: cell.row + 1), origins: &origins)
                        }
                        pieces[index].origin.row += 1
                        moved = true
                    } else {
                        let below = Position(column: column, row: row + 1)
                        guard self[below] == nil else { continue }
                        shift(&self, from: position, to: below, origins: &origins)
                        if let index {
                            pieces[index].origin = below
                        }
                        moved = true
                    }
                }
            }
        }

        return origins
            .map { BlockMove(from: $0.value, to: $0.key) }
            .sorted { ($0.from.column, -$0.from.row) < ($1.from.column, -$1.from.row) }
    }
}
