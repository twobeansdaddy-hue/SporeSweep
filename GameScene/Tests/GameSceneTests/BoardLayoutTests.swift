import CoreGraphics
import GameCore
import Testing
@testable import GameScene

@Suite("화면 크기 기준 배치")
struct BoardLayoutTests {
    @Test("세로로 긴 화면에서는 가로가 칸 크기를 정한다")
    func portraitPhone() {
        let layout = BoardLayout(containerSize: CGSize(width: 402, height: 780))
        #expect(layout.cellSize == 48.25)  // (402 - 16) / 8
        #expect(layout.frame.width == layout.cellSize * 8)
        #expect(layout.frame.height == layout.cellSize * 10)
    }

    @Test("가로로 넓은 화면에서는 세로가 칸 크기를 정한다")
    func landscape() {
        let layout = BoardLayout(containerSize: CGSize(width: 800, height: 376))
        #expect(layout.cellSize == 36.0)  // (376 - 16) / 10
    }

    @Test("칸 크기는 72pt를 넘지 않는다")
    func cellSizeIsCapped() {
        let layout = BoardLayout(containerSize: CGSize(width: 1366, height: 1024))
        #expect(layout.cellSize == 72)
        #expect(layout.frame.size == CGSize(width: 576, height: 720))
    }

    @Test("보드는 어떤 크기에서도 8×10이고 영역 가운데에 놓인다", arguments: [
        CGSize(width: 320, height: 568),
        CGSize(width: 402, height: 780),
        CGSize(width: 800, height: 376),
        CGSize(width: 1366, height: 1024),
    ])
    func alwaysEightByTenAndCentered(size: CGSize) {
        let layout = BoardLayout(containerSize: size)
        #expect(layout.columns == 8)
        #expect(layout.rows == 10)
        #expect(abs(layout.frame.midX - size.width / 2) < 0.001)
        #expect(abs(layout.frame.midY - size.height / 2) < 0.001)
        #expect(layout.frame.minX >= BoardLayout.margin - 0.001)
        #expect(layout.frame.minY >= BoardLayout.margin - 0.001)
    }

    @Test("행 0은 화면 위쪽이다")
    func rowZeroIsAtTop() {
        let layout = BoardLayout(containerSize: CGSize(width: 402, height: 780))
        let topLeft = layout.center(of: Position(column: 0, row: 0))
        let bottomRight = layout.center(of: Position(column: 7, row: 9))
        #expect(topLeft.y > bottomRight.y)
        #expect(topLeft.x < bottomRight.x)
        #expect(topLeft.x == layout.frame.minX + layout.cellSize / 2)
        #expect(topLeft.y == layout.frame.maxY - layout.cellSize / 2)
    }

    @Test("칸의 중심은 그 칸으로 되돌아온다")
    func centerRoundTrips() {
        let layout = BoardLayout(containerSize: CGSize(width: 402, height: 780))
        for row in 0..<10 {
            for column in 0..<8 {
                let position = Position(column: column, row: row)
                #expect(layout.position(at: layout.center(of: position)) == position)
            }
        }
    }

    @Test("보드 밖의 점은 칸이 아니다")
    func outsideIsNil() {
        let layout = BoardLayout(containerSize: CGSize(width: 402, height: 780))
        #expect(layout.position(at: CGPoint(x: 2, y: 390)) == nil)
        #expect(layout.position(at: CGPoint(x: 201, y: layout.frame.maxY + 5)) == nil)
        #expect(layout.position(at: CGPoint(x: 201, y: layout.frame.minY - 5)) == nil)
    }

    @Test("영역이 너무 작으면 칸 크기가 0이다")
    func degenerateContainer() {
        let layout = BoardLayout(containerSize: .zero)
        #expect(layout.cellSize == 0)
        #expect(layout.position(at: .zero) == nil)
    }
}

@Suite("씬 전체 배치")
struct SceneLayoutTests {
    @Test("보드, 이동 횟수 표시, 미니맵, 격리 컨테이너가 화면 안에서 겹치지 않는다", arguments: [
        CGSize(width: 320, height: 568),
        CGSize(width: 402, height: 780),
        CGSize(width: 440, height: 860),
        CGSize(width: 800, height: 376),
        CGSize(width: 1366, height: 1024),
    ])
    func areasDoNotOverlap(size: CGSize) {
        let layout = SceneLayout(size: size)
        let bounds = CGRect(origin: .zero, size: size)
        let areas = [
            layout.board.frame, layout.hudFrame, layout.queueFrame, layout.minimapFrame, layout.containerFrame,
        ]
        for area in areas {
            #expect(bounds.contains(area))
        }
        for (index, first) in areas.enumerated() {
            for second in areas.dropFirst(index + 1) {
                #expect(!first.insetBy(dx: 0.01, dy: 0.01).intersects(second))
            }
        }
    }

    @Test("미니맵은 보드 오른쪽, 격리 컨테이너는 보드 아래, 이동 횟수는 보드 위다")
    func arrangement() {
        let layout = SceneLayout(size: CGSize(width: 402, height: 780))
        let board = layout.board.frame
        #expect(layout.minimapFrame.minX > board.maxX)
        #expect(layout.minimapFrame.height == board.height)
        #expect(layout.minimapFrame.width < layout.board.cellSize)
        #expect(layout.containerFrame.maxY < board.minY)
        #expect(layout.containerFrame.width == board.width)
        // 대기 물질 표시는 보드 바로 위, 이동 횟수는 그 위다.
        #expect(layout.queueFrame.minY > board.maxY)
        #expect(layout.hudFrame.minY > layout.queueFrame.maxY)
    }

    @Test("활성 구간은 어떤 화면에서도 8×10이고 칸 크기는 72pt를 넘지 않는다")
    func boardStaysEightByTen() {
        for size in [CGSize(width: 402, height: 780), CGSize(width: 1366, height: 1024)] {
            let layout = SceneLayout(size: size)
            #expect(layout.board.columns == 8)
            #expect(layout.board.rows == 10)
            #expect(layout.board.cellSize <= 72)
        }
    }
}
