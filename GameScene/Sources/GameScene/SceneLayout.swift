import CoreGraphics
import GameCore

/// 씬 전체의 배치. 화면 크기만으로 계산한다.
///
/// 아이폰 배치다. 보드 위에 이동 횟수와 물질 수, 그 아래에 열마다 대기 물질 표시,
/// 보드 오른쪽에 가는 세로 막대 미니맵, 보드 아래에 격리 컨테이너를 둔다(3장, 5장).
public struct SceneLayout: Equatable, Sendable {
    public static let hudHeight: CGFloat = 60
    /// 대기 물질 표시가 놓이는 띠의 높이.
    public static let queueHeight: CGFloat = 22
    public static let containerHeight: CGFloat = 40
    /// 화면에 높이가 남을 때 수거함이 더 커질 수 있는 한도.
    public static let containerGrowth: CGFloat = 60
    public static let minimapWidth: CGFloat = 10
    public static let minimapGap: CGFloat = 6

    public let board: BoardLayout
    public let hudFrame: CGRect
    /// 보드 바로 위의 띠. 열마다 화면 위에서 대기하는 물질을 표시한다.
    public let queueFrame: CGRect
    public let minimapFrame: CGRect
    public let containerFrame: CGRect

    public init(size: CGSize, columns: Int = GameConstants.columns, rows: Int = GameConstants.activeRows) {
        let area = CGRect(
            x: 0,
            y: Self.containerHeight,
            width: max(size.width - Self.minimapWidth - Self.minimapGap, 0),
            height: max(size.height - Self.hudHeight - Self.queueHeight - Self.containerHeight, 0)
        )
        // 보드의 크기는 폭으로 정해져서 세로로 긴 화면에서는 높이가 남는다. 보드를 가운데에 두면 위쪽 머리글과
        // 점수 사이가 휑하게 뜨므로, 묶음을 위로 붙이고 남는 높이는 수거함을 키우는 데 쓴다.
        let fitted = BoardLayout(container: area, columns: columns, rows: rows).frame
        let slack = max(area.height - fitted.height, 0)
        let containerHeight = Self.containerHeight + min(slack, Self.containerGrowth)
        board = BoardLayout(
            container: CGRect(x: area.minX, y: area.maxY - fitted.height, width: area.width, height: fitted.height),
            columns: columns, rows: rows
        )
        let frame = board.frame
        queueFrame = CGRect(x: frame.minX, y: frame.maxY + 2, width: frame.width, height: Self.queueHeight - 2)
        hudFrame = CGRect(x: frame.minX, y: queueFrame.maxY + 4, width: frame.width, height: Self.hudHeight - 8)
        minimapFrame = CGRect(
            x: frame.maxX + Self.minimapGap,
            y: frame.minY,
            width: Self.minimapWidth,
            height: frame.height
        )
        containerFrame = CGRect(
            x: frame.minX,
            y: frame.minY - containerHeight + 4,
            width: frame.width,
            height: containerHeight - 8
        )
    }
}
