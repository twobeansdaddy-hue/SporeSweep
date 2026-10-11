import CoreGraphics
import GameCore

/// 화면 크기로 계산한 보드 배치(3장 "화면 대응").
///
/// 기기 종류를 보지 않고 주어진 영역의 크기만 쓴다. 좌표는 SpriteKit 씬 기준(y가 위쪽)이다.
public struct BoardLayout: Equatable, Sendable {
    /// 칸 크기의 상한.
    public static let maximumCellSize: CGFloat = 72
    /// 보드와 영역 가장자리 사이의 여백.
    public static let margin: CGFloat = 8

    public let columns: Int
    public let rows: Int
    public let cellSize: CGFloat
    /// 보드가 차지하는 사각형. 영역의 가운데에 놓인다.
    public let frame: CGRect

    public init(
        containerSize: CGSize,
        columns: Int = GameConstants.columns,
        rows: Int = GameConstants.activeRows
    ) {
        self.init(container: CGRect(origin: .zero, size: containerSize), columns: columns, rows: rows)
    }

    /// 주어진 사각형 안에 보드를 놓는다. `rows`는 화면에 보이는 행 수다.
    public init(
        container: CGRect,
        columns: Int = GameConstants.columns,
        rows: Int = GameConstants.activeRows
    ) {
        self.columns = columns
        self.rows = rows
        let width = max(container.width - 2 * Self.margin, 0)
        let height = max(container.height - 2 * Self.margin, 0)
        cellSize = min(width / CGFloat(columns), height / CGFloat(rows), Self.maximumCellSize)
        let size = CGSize(width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
        frame = CGRect(
            x: container.midX - size.width / 2,
            y: container.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// 칸의 중심. 보드 밖의 행과 열도 같은 격자로 계산한다.
    /// 보충 블록의 출발점과, 화면 아래로 이어지는 긴 보드의 행에 쓴다.
    public func center(of position: Position) -> CGPoint {
        CGPoint(
            x: frame.minX + (CGFloat(position.column) + 0.5) * cellSize,
            y: frame.maxY - (CGFloat(position.row) + 0.5) * cellSize
        )
    }

    /// 점이 놓인 칸. 보드 밖이면 `nil`이다.
    public func position(at point: CGPoint) -> Position? {
        guard cellSize > 0, frame.contains(point) else { return nil }
        let column = min(Int((point.x - frame.minX) / cellSize), columns - 1)
        let row = min(Int((frame.maxY - point.y) / cellSize), rows - 1)
        return Position(column: column, row: row)
    }
}
