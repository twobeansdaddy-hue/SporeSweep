import Foundation

/// 보드에 나와 있는 오염 물질 한 덩어리. 가로 `width`칸, 세로 `height`칸을 차지한다.
///
/// 덩어리가 덮은 칸은 보드에서 모두 `.material`이다. 덩어리는 한 몸으로 움직여서,
/// 폭 전체의 바로 아래 칸이 비어야 내려간다.
public struct MaterialPiece: Hashable, Sendable, Codable {
    /// 왼쪽 위 칸.
    public var origin: Position
    public var width: Int
    public var height: Int

    public init(origin: Position, width: Int = 1, height: Int = 1) {
        precondition(width >= 1 && height >= 1, "물질의 크기는 1 이상이어야 한다")
        self.origin = origin
        self.width = width
        self.height = height
    }

    public var columns: Range<Int> {
        origin.column..<(origin.column + width)
    }

    public var rows: Range<Int> {
        origin.row..<(origin.row + height)
    }

    /// 맨 아래 행.
    public var bottomRow: Int {
        origin.row + height - 1
    }

    /// 한 칸보다 큰지. 큰 물질은 스왑할 수 없다.
    public var isLarge: Bool {
        width * height > 1
    }

    /// 덮고 있는 칸. 위에서 아래로, 왼쪽에서 오른쪽 순서다.
    public var cells: [Position] {
        rows.flatMap { row in columns.map { Position(column: $0, row: row) } }
    }

    public func contains(_ position: Position) -> Bool {
        columns.contains(position.column) && rows.contains(position.row)
    }
}
