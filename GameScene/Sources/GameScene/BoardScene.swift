import GameCore
import SpriteKit

/// 보드를 그리고 스와이프를 받는 씬.
///
/// 규칙은 모두 GameCore가 처리한다. 씬은 스왑을 넘기고, 돌아온 이벤트 목록을 순서대로 재생한다(10장).
/// 보드는 화면보다 길 수 있다. 활성 구간의 10행만 보이고, 카메라가 내려가면 블록 전체가 위로 밀린다.
public final class BoardScene: SKScene {
    public private(set) var state: GameState
    public private(set) var sceneLayout: SceneLayout
    /// 이벤트를 재생하는 동안에는 입력을 받지 않는다.
    public private(set) var isAnimating = false
    /// 미니맵을 눌러 아래 구간을 보는 중인지. 보는 동안에는 블록을 움직일 수 없다.
    public private(set) var isPreviewing = false
    /// 판이 끝나 결과를 보여주는 중인지. 이 동안에는 스왑을 받지 않는다.
    public private(set) var isShowingResult = false
    /// 판이 끝났을 때 불린다. 정해 두면 씬은 자체 결과 화면을 띄우지 않고 앱에 맡긴다.
    /// 정하지 않으면 씬이 간단한 결과 화면을 띄우고, 탭하면 같은 판을 다시 시작한다.
    public var onFinish: ((GameState) -> Void)?
    /// 판이 끝났는데 아직 `onFinish`로 알리지 않았는지. 끝나는 연출이 버려져도 결과를 잃지 않으려고 따로 둔다.
    public private(set) var hasPendingResult = false
    /// 쓰려고 든 아이템(6장). 정화 망치는 다음에 누른 칸에, 자리 바꾸기는 다음에 민 두 칸에 쓴다.
    /// 쓰고 나면 `nil`로 돌아간다.
    public var armedTool: Tool?
    /// 아이템을 실제로 썼을 때. 앱이 가진 수를 줄인다.
    public var onToolUsed: ((Tool) -> Void)?
    /// 별 2개와 별 3개를 받는 점수(6장). 주면 점수 아래에 별 막대를 그린다.
    public var starScores: [Int] = [] {
        didSet {
            buildStarBar()
            updateHUD()
        }
    }
    /// 효과음과 햅틱을 낼 곳. 정하지 않으면 소리도 진동도 없다.
    public var feedback: GameFeedback?
    /// 입력이 없을 때 가능한 이동 하나를 흔들어 보여주기까지의 시간(3장 "힌트").
    public var hintDelay: TimeInterval = 5

    /// 보이는 활성 구간의 배치.
    public var layout: BoardLayout { sceneLayout.board }

    private let initialState: GameState
    private let boardNode = SKNode()
    /// 안개 노드. 칸에 붙어 있어서 블록과 따로 둔다.
    private var fogNodes: [Position: SKNode] = [:]
    /// 끈끈이 바닥 노드. 블록 아래에 깔린다.
    private var stickyNodes: [Position: SKNode] = [:]
    /// 포자 보호막 노드. 블록 위에 얹힌다.
    private var shieldNodes: [Position: SKNode] = [:]
    private let cropNode = SKCropNode()
    /// 보드 전체가 놓이는 노드. 카메라가 내려가면 이 노드가 위로 올라간다.
    private let worldNode = SKNode()
    private var blocks: [Position: SKNode] = [:]
    private var dragStart: (point: CGPoint, position: Position)?

    private var movesLabel = SKLabelNode()
    private var scoreLabel = SKLabelNode()
    private var starBarNode = SKNode()
    private var hudNode = SKNode()
    private var starFill = SKShapeNode()
    private var starMarks: [SKLabelNode] = []
    private var starsLit: [Bool] = []
    static let starBarWidth: CGFloat = 132
    static let starBarHeight: CGFloat = 12
    private var materialsLabel = SKLabelNode()
    private var containerNode = SKNode()
    private var containerLamps: [SKShapeNode] = []
    private var minimapNode = SKNode()
    private var minimapViewport = SKShapeNode()
    /// 화면에 반영된 수거 수. 수거 애니메이션이 재생될 때 오른다.
    private var collectedShown = 0
    /// 화면에 보이는 점수. 턴의 연출이 진행되는 동안 블록이 터질 때마다 조금씩 오른다.
    private var displayedScore = 0
    /// 이번 턴의 이벤트마다 화면의 점수에 더할 값. 이벤트의 순서와 같다.
    private var scoreSteps: [Int] = []
    /// 클리어했을 때 남은 이동 횟수로 받는 점수. 마지막에 따로 세어 올린다.
    private var finalBonus = 0
    /// 남은 이동 횟수를 점수로 바꾸는 동안 화면에 보이는 이동 횟수.
    private var movesShown: Int?
    private var queueNode = SKNode()
    /// 화면에 반영된 대기 물질. 보충 애니메이션이 재생될 때 줄어든다.
    private(set) var pendingShown: [PendingMaterial] = []

    private enum Timing {
        static let swap: TimeInterval = 0.15
        static let clear: TimeInterval = 0.18
        /// 한 칸 떨어지는 시간. 거리가 늘면 제곱근으로 늘어 멀리 떨어질수록 빨라진다.
        static let fallUnit: TimeInterval = 0.12
        /// 같은 열에서 위 블록이 아래 블록보다 늦게 출발하는 간격.
        static let stagger: TimeInterval = 0.025
        /// 이어지는 낙하·흘러내림 묶음 사이의 간격. 앞 묶음이 한 칸쯤 움직였을 때 다음이 출발한다.
        static let flowStep: TimeInterval = 0.1
        /// 이미 움직이던 블록이 이어서 움직일 때는 속도가 붙어 있으므로 시간을 줄인다.
        static let carryFactor: Double = 0.75
        static let shuffle: TimeInterval = 0.35
        static let effect: TimeInterval = 0.3
        /// 터지는 칸 하나가 부풀며 사라지는 시간.
        static let pop: TimeInterval = 0.26
        /// 빔이 한 칸 뻗어 나가는 시간, 다 뻗은 뒤 머무는 시간, 사라지는 시간.
        static let beamStep: TimeInterval = 0.045
        static let beamHold: TimeInterval = 0.12
        static let beamFade: TimeInterval = 0.28
        /// 폭탄의 충격이 한 칸 퍼지는 시간.
        static let bombStep: TimeInterval = 0.07
        /// 코어가 블록을 하나씩 터뜨리는 간격.
        static let coreStep: TimeInterval = 0.035
        /// 청소 드론이 목표까지 날아가는 시간.
        static let droneFlight: TimeInterval = 0.42
        static let create: TimeInterval = 0.15
        static let slide: TimeInterval = 0.14
        static let scrollPerRow: TimeInterval = 0.16
        static let collect: TimeInterval = 0.35
    }

    private enum Palette {
        static let background = SKColor(red: 0.09, green: 0.11, blue: 0.14, alpha: 1)
        static let text = SKColor(white: 0.95, alpha: 1)
        static let panel = SKColor(red: 0.17, green: 0.19, blue: 0.31, alpha: 1)
        static let material = SKColor(red: 1.0, green: 0.22, blue: 0.58, alpha: 1)
        static let container = SKColor(red: 0.98, green: 0.80, blue: 0.25, alpha: 1)
    }

    public init(state: GameState, size: CGSize) {
        self.state = state
        initialState = state
        sceneLayout = SceneLayout(size: size, columns: state.board.columns, rows: state.activeRange.count)
        super.init(size: size)
        scaleMode = .resizeFill
        // 바탕은 비워 둔다. 앱이 씬 뒤에 깔아 둔 화면 바탕이 비친다.
        backgroundColor = .clear
        addChild(boardNode)
        rebuild()
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:)는 지원하지 않는다")
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        // super.init 도중에도 불린다. 그때는 init이 직접 그린다.
        guard boardNode.parent != nil, size != oldSize else { return }
        rebuild()
    }

    public override func didMove(to view: SKView) {
        scheduleHint()
        #if DEBUG
        autoPlayIfNeeded()
        #endif
    }

    // MARK: - 힌트

    /// 힌트로 보여줄 이동. 가능한 이동 가운데 첫 번째다. 판이 끝났으면 없다.
    var hintSwap: Swap? {
        state.status == .playing ? state.possibleMoves().first : nil
    }

    /// 입력이 `hintDelay`초 동안 없으면 가능한 이동 하나를 흔든다. 입력이 올 때까지 같은 간격으로 되풀이한다.
    private func scheduleHint() {
        removeAction(forKey: "hint")
        guard hintDelay > 0 else { return }
        run(.sequence([
            .wait(forDuration: hintDelay),
            .run { [weak self] in
                MainActor.assumeIsolated {
                    self?.showHint()
                }
            },
        ]), withKey: "hint")
    }

    private func cancelHint() {
        removeAction(forKey: "hint")
        for node in blocks.values {
            node.removeAction(forKey: "hintShake")
            node.zRotation = 0
        }
    }

    private func showHint() {
        guard !isAnimating, !isPreviewing, !isShowingResult, let swap = hintSwap else { return }
        let angle: CGFloat = 0.14
        let shake = SKAction.sequence([
            .rotate(toAngle: angle, duration: 0.07),
            .rotate(toAngle: -angle, duration: 0.14),
            .rotate(toAngle: angle, duration: 0.14),
            .rotate(toAngle: -angle, duration: 0.14),
            .rotate(toAngle: 0, duration: 0.07),
        ])
        for position in [swap.from, swap.to] {
            blocks[position]?.run(shake, withKey: "hintShake")
        }
        scheduleHint()
    }

    // MARK: - 그리기

    /// 현재 상태와 씬 크기로 모든 노드를 다시 만든다. 재생 중이던 애니메이션은 버린다.
    private func rebuild() {
        boardNode.removeAllActions()
        boardNode.removeAllChildren()
        cropNode.removeAllChildren()
        worldNode.removeAllActions()
        worldNode.removeAllChildren()
        blocks.removeAll()
        fogNodes.removeAll()
        stickyNodes.removeAll()
        shieldNodes.removeAll()
        isAnimating = false
        isPreviewing = false
        isShowingResult = false
        dragStart = nil
        collectedShown = state.materialsTotal - state.materialsRemaining
        displayedScore = state.score
        scoreSteps = []
        finalBonus = 0
        movesShown = nil
        pendingShown = state.pendingMaterials

        let board = state.board
        sceneLayout = SceneLayout(size: size, columns: board.columns, rows: state.activeRange.count)
        guard layout.cellSize > 0 else { return }

        // 활성 구간 밖은 가린다. 보충 블록이 위에서 들어올 때도 보드 밖 부분은 보이지 않는다.
        let mask = SKSpriteNode(color: .white, size: layout.frame.size)
        mask.position = CGPoint(x: layout.frame.midX, y: layout.frame.midY)
        cropNode.maskNode = mask
        cropNode.addChild(worldNode)
        // 보드의 바탕. 뒤의 풍경 위에서 블록이 묻히지 않게 어두운 판을 깔고 둥근 테두리를 두른다.
        let bed = layout.frame.insetBy(dx: -5, dy: -5)
        let panel = SKShapeNode(rect: bed, cornerRadius: layout.cellSize * 0.22)
        panel.fillColor = SKColor(red: 0.07, green: 0.08, blue: 0.19, alpha: 0.82)
        panel.strokeColor = SKColor(red: 0.62, green: 0.68, blue: 1, alpha: 0.55)
        panel.lineWidth = 3
        panel.zPosition = -2
        boardNode.addChild(panel)
        let rim = SKShapeNode(rect: bed.insetBy(dx: -4, dy: -4), cornerRadius: layout.cellSize * 0.28)
        rim.fillColor = .clear
        rim.strokeColor = SKColor(red: 0.05, green: 0.05, blue: 0.14, alpha: 0.7)
        rim.lineWidth = 4
        rim.zPosition = -3
        boardNode.addChild(rim)
        boardNode.addChild(cropNode)
        worldNode.position = worldOffset(top: CGFloat(state.activeTop))

        for position in board.positions {
            let tile = SKSpriteNode(
                color: SKColor(white: 1, alpha: (position.column + position.row).isMultiple(of: 2) ? 0.07 : 0.04),
                size: CGSize(width: layout.cellSize, height: layout.cellSize)
            )
            tile.position = layout.center(of: position)
            worldNode.addChild(tile)
        }
        for position in board.positions {
            // 물질은 덩어리 단위로 따로 그린다.
            if let block = board[position], block != .material {
                addBlock(block, at: position, from: position)
            }
        }
        for piece in state.materials {
            let node = BlockSprite.makeMaterialNode(width: piece.width, height: piece.height, cellSize: layout.cellSize)
            node.zPosition = 1
            worldNode.addChild(node)
            for cell in piece.cells {
                blocks[cell] = node
            }
            node.position = centroid(of: node)
        }

        // 끈끈이 바닥은 블록 아래에 깔린다. 가장자리가 블록 밖으로 비어져 나와 보인다.
        for position in state.sticky {
            let node = BlockSprite.makeSticky(cellSize: layout.cellSize)
            node.position = layout.center(of: position)
            node.zPosition = 0.5
            worldNode.addChild(node)
            stickyNodes[position] = node
        }
        // 보호막은 블록 위에 얹힌다.
        for position in state.shields {
            let node = BlockSprite.makeShield(cellSize: layout.cellSize)
            node.position = layout.center(of: position)
            node.zPosition = 5
            worldNode.addChild(node)
            shieldNodes[position] = node
            node.run(.repeatForever(.sequence([.fadeAlpha(to: 0.7, duration: 0.9), .fadeAlpha(to: 1, duration: 0.9)])))
        }
        // 안개는 칸에 붙어 블록을 가린다. 블록 위, 효과 아래에 그린다.
        for position in state.fog {
            addFog(at: position)
        }

        buildHUD()
        queueNode = SKNode()
        boardNode.addChild(queueNode)
        updateQueue()
        buildContainer()
        buildMinimap()
        if state.status != .playing {
            // 이미 알린 결과는 또 알리지 않는다. 끝나는 연출이 버려졌으면 여기서 알린다.
            showResult(notify: hasPendingResult)
        }
    }

    /// 활성 구간의 맨 위가 `top`행일 때 보드 전체를 얼마나 올려야 하는지.
    private func worldOffset(top: CGFloat) -> CGPoint {
        CGPoint(x: 0, y: top * layout.cellSize)
    }

    @discardableResult
    private func addBlock(_ block: Block, at position: Position, from start: Position) -> SKNode {
        let node = BlockSprite.makeNode(block: block, cellSize: layout.cellSize)
        node.position = layout.center(of: start)
        node.zPosition = 1
        worldNode.addChild(node)
        blocks[position] = node
        if block.isSpecial {
            addShimmer(to: node, block: block)
        }
        return node
    }

    /// 칸에 안개를 놓는다. 칸마다 박자를 달리해 천천히 부푼다.
    @discardableResult
    private func addFog(at position: Position) -> SKNode {
        let node = BlockSprite.makeFog(cellSize: layout.cellSize)
        node.position = layout.center(of: position)
        node.zPosition = 6
        worldNode.addChild(node)
        fogNodes[position] = node
        let beat = 1.4 + Double((position.column * 3 + position.row * 5) % 7) * 0.12
        node.run(.repeatForever(.sequence([
            .scale(to: 1.06, duration: beat),
            .scale(to: 0.98, duration: beat),
        ])))
        return node
    }

    /// 특수 블록 뒤에서 숨 쉬듯 밝아졌다 어두워지는 빛. 보드에서 특수 블록이 한눈에 들어오게 한다.
    private func addShimmer(to node: SKNode, block: Block) {
        let color: SKColor = switch block {
        case .bomb: SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 1)
        case .core: .white
        default: SKColor(red: 0.5, green: 0.9, blue: 1, alpha: 1)
        }
        let side = layout.cellSize * 1.5
        let glow = SKSpriteNode(texture: EffectTexture.glow, size: CGSize(width: side, height: side))
        glow.color = color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.zPosition = -0.1
        glow.alpha = 0.25
        node.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.7, duration: 0.8),
            .fadeAlpha(to: 0.25, duration: 0.8),
        ])))
    }

    /// 노드가 덮은 칸들의 한가운데. 큰 물질은 여러 칸이 한 노드를 가리킨다.
    private func centroid(of node: SKNode) -> CGPoint {
        let centers = blocks.filter { $0.value === node }.map { layout.center(of: $0.key) }
        guard !centers.isEmpty else { return node.position }
        return CGPoint(
            x: centers.map(\.x).reduce(0, +) / CGFloat(centers.count),
            y: centers.map(\.y).reduce(0, +) / CGFloat(centers.count)
        )
    }

    /// 화면에 적는 글을 기기의 언어로 바꾼다. 번역은 앱의 문자열 표에 있고, 없으면 한국어 그대로다.
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: Bundle.main.localizedString(forKey: key, value: key, table: nil), arguments: arguments)
    }

    /// 글자에 쓰는 글꼴. 앱에 든 게임 글꼴이 없으면 숫자가 둥글게 나오는 시스템 글꼴을 쓴다.
    static let fontName: String = {
        #if canImport(UIKit)
        // 앱이 둥근 한글 글꼴 "주아"를 넣어 두었으면 그것을 쓴다.
        if UIFont(name: "Jua-Regular", size: 20) != nil {
            return "Jua-Regular"
        }
        let base = UIFont.systemFont(ofSize: 20, weight: .heavy)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: 20).fontName
        }
        #endif
        return "AppleSDGothicNeo-Bold"
    }()

    private func makeLabel(size: CGFloat, alignment: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: Self.fontName)
        label.fontSize = size
        label.fontColor = Palette.text
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        return label
    }

    /// 위쪽 정보 줄. 왼쪽에 남은 이동, 가운데에 점수와 별 막대, 오른쪽에 수거한 물질을 둔다.
    /// 앱의 버튼과 같은 둥근 판 위에 올린다.
    private func buildHUD() {
        hudNode.removeFromParent()
        hudNode = SKNode()
        let frame = sceneLayout.hudFrame
        let pillHeight = min(frame.height, 34)
        let moves = makePill(width: 86, height: pillHeight)
        moves.position = CGPoint(x: frame.minX + 43, y: frame.midY)
        hudNode.addChild(moves)
        let materials = makePill(width: 98, height: pillHeight)
        materials.position = CGPoint(x: frame.maxX - 49, y: frame.midY)
        hudNode.addChild(materials)

        movesLabel = makeLabel(size: 17, alignment: .center)
        movesLabel.position = moves.position
        materialsLabel = makeLabel(size: 17, alignment: .center)
        materialsLabel.position = materials.position
        scoreLabel = makeLabel(size: 18, alignment: .center)
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        for label in [movesLabel, scoreLabel, materialsLabel] {
            label.zPosition = 0.2
            hudNode.addChild(label)
        }
        boardNode.addChild(hudNode)
        buildStarBar()
        updateHUD()
    }

    /// 정보 줄의 둥근 판.
    private func makePill(width: CGFloat, height: CGFloat) -> SKShapeNode {
        let pill = SKShapeNode(
            rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerRadius: height / 2
        )
        pill.fillColor = Palette.panel
        pill.strokeColor = SKColor(white: 1, alpha: 0.14)
        pill.lineWidth = 1.5
        return pill
    }

    /// 별 하나. 어두운 그림자 위에 별을 얹어 두께가 있어 보이게 한다.
    private func makeStar(size: CGFloat) -> (node: SKNode, face: SKLabelNode) {
        let node = SKNode()
        let shadow = makeLabel(size: size, alignment: .center)
        shadow.text = "★"
        shadow.fontColor = SKColor(red: 0.08, green: 0.09, blue: 0.18, alpha: 1)
        shadow.position = CGPoint(x: 0, y: -2)
        let face = makeLabel(size: size, alignment: .center)
        face.text = "★"
        face.zPosition = 0.1
        node.addChild(shadow)
        node.addChild(face)
        return (node, face)
    }

    /// 점수 아래의 별 막대. 점수가 별 3개 기준에 가까워질수록 차오르고, 기준을 넘긴 별이 켜진다.
    /// 첫 별은 클리어해야 받으므로 판이 끝나기 전에는 꺼져 있다.
    private func buildStarBar() {
        starBarNode.removeFromParent()
        starBarNode = SKNode()
        starFill = SKShapeNode()
        starMarks = []
        starsLit = []
        let frame = sceneLayout.hudFrame
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        guard starScores.count == 2, state.materialsTotal > 0 else { return }
        let width = Self.starBarWidth
        let height = Self.starBarHeight
        // 점수 글자를 올리고 그 아래에 막대를 둔다.
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.midY + 11)
        starBarNode.position = CGPoint(x: frame.midX - width / 2, y: frame.midY - 10)
        let track = SKShapeNode(rect: CGRect(x: 0, y: -height / 2, width: width, height: height), cornerRadius: height / 2)
        track.fillColor = SKColor(red: 0.08, green: 0.09, blue: 0.18, alpha: 1)
        track.strokeColor = SKColor(white: 1, alpha: 0.16)
        track.lineWidth = 1.5
        starBarNode.addChild(track)
        starFill.fillColor = Palette.container
        starFill.strokeColor = .clear
        starFill.zPosition = 0.1
        starBarNode.addChild(starFill)
        for fraction in [0, CGFloat(starScores[0]) / CGFloat(starScores[1]), 1] {
            let star = makeStar(size: 21)
            star.node.position = CGPoint(x: width * fraction, y: 1)
            star.node.zPosition = 0.2
            starBarNode.addChild(star.node)
            starMarks.append(star.face)
            starsLit.append(false)
        }
        hudNode.addChild(starBarNode)
    }

    /// 지금 점수로 받은 별 수. 판이 끝나기 전에는 첫 별(클리어)을 세지 않는다.
    var starsShown: Int {
        guard starScores.count == 2 else { return 0 }
        let cleared = state.status == .won ? 1 : 0
        return cleared + starScores.count { displayedScore >= $0 }
    }

    /// 별 막대가 찬 비율(0...1).
    var starBarFraction: CGFloat {
        guard starScores.count == 2 else { return 0 }
        return min(CGFloat(displayedScore) / CGFloat(starScores[1]), 1)
    }

    private func updateHUD() {
        movesLabel.text = (movesShown ?? state.movesRemaining).map { Self.text("이동 %lld", $0) } ?? ""
        scoreLabel.text = state.materialsTotal > 0 ? Self.text("%lld점", displayedScore) : ""
        materialsLabel.text = state.materialsTotal > 0 ? Self.text("물질 %lld/%lld", collectedShown, state.materialsTotal) : ""
        guard !starMarks.isEmpty else { return }
        // 막대의 끝이 둥글어서, 너무 짧으면 찌그러진다. 조금이라도 찼으면 높이만큼은 그린다.
        let height = Self.starBarHeight - 4
        let filled = starBarFraction > 0 ? max((Self.starBarWidth - 4) * starBarFraction, height) : 0
        starFill.path = CGPath(
            roundedRect: CGRect(x: 2, y: -height / 2, width: filled, height: height),
            cornerWidth: min(height, filled) / 2, cornerHeight: height / 2, transform: nil
        )
        let won = state.status == .won
        for (index, star) in starMarks.enumerated() {
            let lit = index == 0 ? won : displayedScore >= starScores[index - 1]
            star.fontColor = lit ? Palette.container : SKColor(red: 0.36, green: 0.39, blue: 0.54, alpha: 1)
            // 새로 켜진 별은 한 번 튀어 오른다.
            if lit, !starsLit[index], let node = star.parent {
                node.run(.sequence([.scale(to: 1.6, duration: 0.12), .scale(to: 1, duration: 0.18)]))
            }
            starsLit[index] = lit
        }
    }

    /// 화면 위에서 대기하는 물질을 열 위에 표시한다.
    /// 숫자는 그 열에서 블록을 몇 개 더 지워야 물질이 들어오는지다.
    private func updateQueue() {
        queueNode.removeAllChildren()
        let frame = sceneLayout.queueFrame
        var countByColumn: [Int: Int] = [:]
        for pending in pendingShown {
            // 같은 열에 여럿이면 옆으로 조금씩 밀어 겹치지 않게 한다.
            let index = countByColumn[pending.column, default: 0]
            countByColumn[pending.column] = index + 1
            let x = layout.center(of: Position(column: pending.column, row: 0)).x
            let marker = SKNode()
            marker.position = CGPoint(x: x + CGFloat(index) * layout.cellSize * 0.3, y: frame.midY)

            let icon = BlockSprite.makeNode(block: .material, cellSize: frame.height)
            icon.position = CGPoint(x: -layout.cellSize * 0.2, y: 0)
            marker.addChild(icon)
            let label = makeLabel(size: frame.height * 0.75, alignment: .left)
            label.text = "\(pending.depth + 1)"
            label.fontColor = Palette.material
            label.position = CGPoint(x: -layout.cellSize * 0.2 + frame.height * 0.55, y: 0)
            marker.addChild(label)
            queueNode.addChild(marker)
        }
    }

    /// 격리 컨테이너 그림의 이름.
    static let containerSpriteName = "container"

    /// 격리 컨테이너를 그리는 자리. 그림이 있으면 그 비율대로, 보드 아래 남은 공간 안에서 키운다.
    var containerDrawFrame: CGRect {
        var frame = sceneLayout.containerFrame
        // 수거함이 좁으면 수거함이 놓인 열 아래에만 그린다.
        if let columns = state.containerColumns {
            let cell = layout.cellSize
            frame = CGRect(
                x: frame.minX + CGFloat(columns.lowerBound) * cell, y: frame.minY,
                width: CGFloat(columns.count) * cell, height: frame.height
            )
        }
        guard let texture = BlockSprite.texture(named: Self.containerSpriteName) else { return frame }
        let natural = frame.width * texture.size().height / texture.size().width
        // 화면에 높이가 남으면 그림의 비율보다 조금 더(1.3배까지) 키운다.
        let height = max(min(natural * 1.3, frame.maxY - 2), frame.height)
        return CGRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
    }

    /// 격리 컨테이너. 카메라가 보드 끝에 닿아야 또렷하게 보인다(5장).
    private func buildContainer() {
        containerNode = SKNode()
        containerLamps = []
        guard state.materialsTotal > 0 else { return }
        let frame = containerDrawFrame
        // 크기를 바꾸는 연출이 가운데를 중심으로 일어나도록 노드를 수거함의 가운데에 둔다.
        containerNode.position = CGPoint(x: frame.midX, y: frame.midY)
        let size = frame.size
        if let texture = BlockSprite.texture(named: Self.containerSpriteName) {
            let sprite = SKSpriteNode(texture: texture, size: size)
            sprite.name = Self.containerSpriteName
            containerNode.addChild(sprite)
            // 입구의 빛이 숨 쉬듯 밝아졌다 어두워진다.
            let glow = SKSpriteNode(
                color: SKColor(red: 0.6, green: 0.95, blue: 1, alpha: 1),
                size: CGSize(width: size.width * 0.8, height: size.height * 0.22)
            )
            glow.position = CGPoint(x: 0, y: size.height * 0.27)
            glow.blendMode = .add
            glow.alpha = 0.05
            glow.zPosition = 0.1
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.9),
                .fadeAlpha(to: 0.05, duration: 0.9),
            ])))
            containerNode.addChild(glow)
        } else {
            let box = SKShapeNode(
                rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                cornerRadius: 6
            )
            box.fillColor = Palette.container.withAlphaComponent(0.15)
            box.strokeColor = Palette.container
            box.lineWidth = 2
            containerNode.addChild(box)
        }
        // 앞판의 등. 수거해야 하는 물질 수만큼 있고, 하나 수거할 때마다 분홍색으로 켜진다.
        let count = state.materialsTotal
        let radius = min(size.height * 0.2, size.width / CGFloat(count * 4))
        let spacing = radius * 2.9
        for index in 0..<count {
            let lamp = SKShapeNode(circleOfRadius: radius)
            lamp.position = CGPoint(
                x: (CGFloat(index) - CGFloat(count - 1) / 2) * spacing,
                y: -size.height * 0.17
            )
            lamp.lineWidth = max(radius * 0.3, 1)
            lamp.zPosition = 0.2
            containerNode.addChild(lamp)
            containerLamps.append(lamp)
        }
        updateContainerLamps()
        containerNode.alpha = isAtBoardEnd(top: state.activeTop) ? 1 : 0.35
        boardNode.addChild(containerNode)
    }

    /// 수거한 물질 수만큼 등을 켠다.
    private func updateContainerLamps() {
        for (index, lamp) in containerLamps.enumerated() {
            let lit = index < collectedShown
            lamp.fillColor = lit ? Palette.material : SKColor(red: 0.08, green: 0.09, blue: 0.18, alpha: 1)
            lamp.strokeColor = lit ? SKColor(red: 1, green: 0.75, blue: 0.88, alpha: 1) : SKColor(white: 1, alpha: 0.25)
            // 수거한 물질은 칸 안에 담겨 꿈틀거린다.
            guard lit, lamp.childNode(withName: "blob") == nil,
                  let texture = BlockSprite.texture(named: BlockSprite.materialName) else { continue }
            let side = lamp.frame.width * 1.25
            let blob = SKSpriteNode(texture: texture, size: CGSize(width: side, height: side))
            blob.name = "blob"
            blob.zPosition = 0.1
            lamp.addChild(blob)
            let beat = 0.7 + Double(index % 3) * 0.15
            blob.run(.repeatForever(.sequence([
                .group([.scaleX(to: 1.08, duration: beat), .scaleY(to: 0.92, duration: beat), .rotate(byAngle: 0.25, duration: beat)]),
                .group([.scaleX(to: 0.94, duration: beat), .scaleY(to: 1.06, duration: beat), .rotate(byAngle: -0.25, duration: beat)]),
            ])))
        }
    }

    /// 켜진 등의 수.
    var litContainerLamps: Int {
        min(collectedShown, containerLamps.count)
    }

    /// 물질을 삼키는 연출. 수거함이 꿀꺽하듯 눌렸다 튀어 오르고, 입구가 번쩍이고, 새로 켜진 등이 튄다.
    private func gulp(newlyLit: Range<Int>) {
        let size = containerDrawFrame.size
        containerNode.run(.sequence([
            .wait(forDuration: Timing.collect * 0.7),
            .group([.scaleX(to: 1.05, duration: 0.07), .scaleY(to: 0.86, duration: 0.07)]),
            .group([.scaleX(to: 0.98, duration: 0.09), .scaleY(to: 1.1, duration: 0.09)]),
            .scale(to: 1, duration: 0.1),
        ]))
        let flash = SKSpriteNode(
            color: SKColor(red: 0.75, green: 1, blue: 1, alpha: 1),
            size: CGSize(width: size.width * 0.86, height: size.height * 0.5)
        )
        flash.position = CGPoint(x: 0, y: size.height * 0.2)
        flash.blendMode = .add
        flash.alpha = 0
        flash.zPosition = 0.3
        containerNode.addChild(flash)
        flash.run(.sequence([
            .wait(forDuration: Timing.collect * 0.7),
            .fadeAlpha(to: 0.8, duration: 0.05),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
        for index in newlyLit where containerLamps.indices.contains(index) {
            containerLamps[index].run(.sequence([
                .wait(forDuration: Timing.collect * 0.7),
                .scale(to: 1.8, duration: 0.1),
                .scale(to: 1, duration: 0.18),
            ]))
        }
    }

    private func isAtBoardEnd(top: Int) -> Bool {
        top + state.activeRange.count >= state.board.rows
    }

    // MARK: - 미니맵

    /// 보드 전체 길이, 활성 구간, 물질 위치를 보여주는 세로 막대. 화면보다 긴 보드에서만 그린다.
    private func buildMinimap() {
        minimapNode = SKNode()
        guard state.board.rows > state.activeRange.count else { return }
        let frame = sceneLayout.minimapFrame
        let track = SKShapeNode(rect: frame, cornerRadius: 3)
        track.fillColor = SKColor(white: 1, alpha: 0.08)
        track.strokeColor = .clear
        minimapNode.addChild(track)

        minimapViewport = SKShapeNode()
        minimapViewport.fillColor = SKColor(white: 1, alpha: 0.22)
        minimapViewport.strokeColor = SKColor(white: 1, alpha: 0.7)
        minimapViewport.lineWidth = 1
        minimapNode.addChild(minimapViewport)
        boardNode.addChild(minimapNode)
        updateMinimap(top: CGFloat(state.activeTop))
    }

    private func minimapY(row: CGFloat) -> CGFloat {
        let frame = sceneLayout.minimapFrame
        return frame.maxY - row / CGFloat(state.board.rows) * frame.height
    }

    /// 미니맵의 활성 구간 표시와 물질 점을 다시 그린다. 물질 위치는 화면의 노드에서 읽는다.
    private func updateMinimap(top: CGFloat) {
        guard minimapNode.parent != nil else { return }
        let frame = sceneLayout.minimapFrame
        let visible = CGFloat(state.activeRange.count)
        minimapViewport.path = CGPath(
            rect: CGRect(
                x: frame.minX,
                y: minimapY(row: top + visible),
                width: frame.width,
                height: minimapY(row: top) - minimapY(row: top + visible)
            ),
            transform: nil
        )
        minimapNode.children.filter { $0.name == "dot" }.forEach { $0.removeFromParent() }
        // 큰 물질은 여러 칸이 한 노드이므로 노드마다 점 하나를 가운데 행에 찍는다.
        var rowsByNode: [ObjectIdentifier: [Int]] = [:]
        for (position, node) in blocks where node.name == BlockSprite.materialName {
            rowsByNode[ObjectIdentifier(node), default: []].append(position.row)
        }
        for rows in rowsByNode.values {
            let row = CGFloat(rows.reduce(0, +)) / CGFloat(rows.count)
            let dot = SKShapeNode(circleOfRadius: frame.width * 0.45)
            dot.name = "dot"
            dot.fillColor = Palette.material
            dot.strokeColor = .clear
            dot.position = CGPoint(x: frame.midX, y: minimapY(row: row + 0.5))
            dot.zPosition = 1
            minimapNode.addChild(dot)
        }
        // 장애물이 있는 행은 가는 회색 선으로 표시한다.
        let obstacleRows = Set(blocks.filter { $0.value.name?.hasPrefix("obstacle_") == true }.map(\.key.row))
        for row in obstacleRows {
            let mark = SKSpriteNode(
                color: SKColor(white: 0.75, alpha: 0.9),
                size: CGSize(width: frame.width, height: max(frame.height / CGFloat(state.board.rows) * 0.5, 2))
            )
            mark.name = "dot"
            mark.position = CGPoint(x: frame.midX, y: minimapY(row: CGFloat(row) + 0.5))
            mark.zPosition = 0.5
            minimapNode.addChild(mark)
        }
        // 대기 중인 물질은 미니맵 위쪽에 빈 고리로 쌓아 보여준다.
        for index in pendingShown.indices {
            let ring = SKShapeNode(circleOfRadius: frame.width * 0.38)
            ring.name = "dot"
            ring.fillColor = .clear
            ring.strokeColor = Palette.material
            ring.lineWidth = 1.5
            ring.position = CGPoint(x: frame.midX, y: frame.maxY + 8 + CGFloat(index) * (frame.width + 2))
            minimapNode.addChild(ring)
        }
    }

    /// 미니맵을 누른 높이에 해당하는 구간을 보여준다. 지나간 위쪽 행으로는 돌아가지 않는다.
    private func preview(at point: CGPoint) {
        let frame = sceneLayout.minimapFrame
        let visible = CGFloat(state.activeRange.count)
        let row = (frame.maxY - point.y) / frame.height * CGFloat(state.board.rows) - visible / 2
        let top = min(max(row, CGFloat(state.activeTop)), CGFloat(state.board.rows) - visible)
        worldNode.removeAllActions()
        worldNode.position = worldOffset(top: top)
        updateMinimap(top: top)
    }

    // MARK: - 입력

    func beginDrag(at point: CGPoint) {
        guard !isAnimating else { return }
        cancelHint()
        scheduleHint()
        if isShowingResult {
            // 앱이 결과 화면을 맡았으면 씬은 탭에 반응하지 않는다.
            if onFinish == nil {
                restart()
            }
            return
        }
        if minimapNode.parent != nil, sceneLayout.minimapFrame.insetBy(dx: -14, dy: 0).contains(point) {
            isPreviewing = true
            preview(at: point)
            return
        }
        guard let visible = layout.position(at: point) else { return }
        if armedTool == .hammer {
            // 정화 망치를 들었으면 누른 칸을 친다. 칠 수 없는 칸이면 아무 일도 없고 망치는 든 채로 있다.
            let target = Position(column: visible.column, row: visible.row + state.activeTop)
            if let result = state.hammering(target) {
                armedTool = nil
                addHammerStrike(at: target)
                onToolUsed?(.hammer)
                run(result)
            } else {
                feedback?.play(.reject)
            }
            return
        }
        dragStart = (point, Position(column: visible.column, row: visible.row + state.activeTop))
    }

    /// 손가락이 칸의 1/3 이상 움직이면 그 방향의 이웃 칸과 스왑한다.
    func continueDrag(to point: CGPoint) {
        if isPreviewing {
            preview(at: point)
            return
        }
        guard !isAnimating, let start = dragStart else { return }
        let dx = point.x - start.point.x
        let dy = point.y - start.point.y
        guard max(abs(dx), abs(dy)) >= layout.cellSize / 3 else { return }
        dragStart = nil

        var target = start.position
        if abs(dx) > abs(dy) {
            target.column += dx > 0 ? 1 : -1
        } else {
            // 씬은 y가 위쪽이고 보드는 행 0이 맨 위다.
            target.row += dy > 0 ? -1 : 1
        }
        guard state.board.contains(target), state.activeRange.contains(target.row) else { return }
        perform(Swap(from: start.position, to: target))
    }

    func endDrag() {
        dragStart = nil
        if isPreviewing {
            // 손을 떼면 활성 구간으로 돌아온다.
            isPreviewing = false
            let action = SKAction.move(to: worldOffset(top: CGFloat(state.activeTop)), duration: 0.2)
            action.timingMode = .easeOut
            worldNode.run(action)
            updateMinimap(top: CGFloat(state.activeTop))
        }
    }

    func perform(_ swap: Swap) {
        guard !isAnimating, !isPreviewing, !isShowingResult else { return }
        if armedTool == .swap {
            // 자리 바꾸기를 들었으면 매치가 되지 않아도 바꾼다. 평소에도 되는 스왑이면 아이템을 쓰지 않는다.
            if state.rejection(for: swap) == .noMatch, let result = state.freeSwapping(swap) {
                armedTool = nil
                onToolUsed?(.swap)
                run(result)
                return
            }
            if state.rejection(for: swap) != nil {
                feedback?.play(.reject)
                return
            }
            armedTool = nil
        }
        run(state.performTurn(swap))
    }

    /// 턴의 결과를 받아 상태를 바꾸고 이벤트를 재생한다.
    private func run(_ result: TurnResult) {
        cancelHint()
        let before = state.score
        state = result.state
        if state.status != .playing {
            hasPendingResult = true
        }
        isAnimating = true
        planScore(for: result.events, from: before)
        updateHUD()
        play(result.events[...], index: 0)
    }

    /// 섞기 아이템을 쓴다.
    /// - Returns: 썼는지. 연출 중이거나 섞을 수 없으면 `false`다.
    @discardableResult
    public func useShuffle() -> Bool {
        guard !isAnimating, !isPreviewing, !isShowingResult, let result = state.shuffling() else { return false }
        armedTool = nil
        onToolUsed?(.shuffle)
        run(result)
        return true
    }

    /// 아이템을 쓸 수 있는 때인지. 연출 중이거나 판이 끝났으면 쓸 수 없다.
    public var canUseTools: Bool {
        !isAnimating && !isPreviewing && !isShowingResult && state.status == .playing
    }

    /// 망치가 내리치는 모습. 위에서 떨어져 칸을 치고 튕겨 사라진다.
    private func addHammerStrike(at position: Position) {
        let cell = layout.cellSize
        let center = layout.center(of: position)
        let hammer: SKNode
        if let texture = BlockSprite.texture(named: "tool_hammer") {
            hammer = SKSpriteNode(texture: texture, size: CGSize(width: cell * 1.2, height: cell * 1.2))
        } else {
            let label = SKLabelNode(text: "🔨")
            label.fontSize = cell * 0.9
            label.verticalAlignmentMode = .center
            hammer = label
        }
        hammer.position = CGPoint(x: center.x + cell * 0.5, y: center.y + cell * 1.1)
        hammer.zRotation = -0.9
        hammer.zPosition = 9
        worldNode.addChild(hammer)
        let swing = SKAction.group([
            .move(to: CGPoint(x: center.x + cell * 0.2, y: center.y + cell * 0.2), duration: 0.1),
            .rotate(toAngle: 0.5, duration: 0.1),
        ])
        swing.timingMode = .easeIn
        hammer.run(.sequence([swing, .wait(forDuration: 0.06), .group([.fadeOut(withDuration: 0.15), .moveBy(x: 0, y: cell * 0.3, duration: 0.15)]), .removeFromParent()]))
        let ring = SKShapeNode(circleOfRadius: cell * 0.3)
        ring.position = center
        ring.strokeColor = .white
        ring.lineWidth = cell * 0.1
        ring.fillColor = .clear
        ring.blendMode = .add
        ring.alpha = 0
        ring.zPosition = 8
        worldNode.addChild(ring)
        ring.run(.sequence([
            .wait(forDuration: 0.1),
            .fadeAlpha(to: 1, duration: 0.01),
            .group([.scale(to: 2.6, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent(),
        ]))
        shakeBoard(strength: 6)
    }

    /// 진 판을 이동 횟수를 더 받아 이어 한다(6장). 보드는 그대로 두고 다시 입력을 받는다.
    /// - Returns: 이어 했는지.
    @discardableResult
    public func continuePlaying(extraMoves: Int) -> Bool {
        guard isShowingResult, !isAnimating, state.continuePlaying(extraMoves: extraMoves) else { return false }
        isShowingResult = false
        // 둘 곳이 없는 보드였으면 여기서 섞인다.
        let result = state.settle()
        state = result.state
        if state.status != .playing {
            hasPendingResult = true
        }
        updateHUD()
        if result.events.isEmpty {
            scheduleHint()
        } else {
            isAnimating = true
            play(result.events[...], index: 0)
        }
        return true
    }

    /// 같은 판을 처음부터 다시 시작한다(6장 "실패 시").
    public func restart() {
        state = initialState
        hasPendingResult = false
        rebuild()
        scheduleHint()
        #if DEBUG
        autoPlayIfNeeded()
        #endif
    }

    // MARK: - 이벤트 재생

    /// 이번 턴에 오른 점수를 이벤트마다 나눠 둔다.
    ///
    /// 점수는 블록이 터지는 순간에 올라야 한다. 매치와 특수 효과가 지운 칸 수에 비례해 나누고,
    /// 남은 이동 횟수로 받는 점수는 마지막에 따로 센다. 나눈 값의 합은 실제로 오른 점수와 같다.
    private func planScore(for events: [GameEvent], from before: Int) {
        finalBonus = state.status == .won ? (state.movesRemaining ?? 0) * GameConstants.scorePerRemainingMove : 0
        let gained = state.score - before - finalBonus
        let weights = events.map { event -> Int in
            switch event {
            case .matchesCleared(let matches, let chain):
                Set(matches.flatMap(\.positions)).count * min(chain, GameConstants.maximumChainMultiplier)
            case .specialsActivated(let activations):
                Set(activations.flatMap(\.cleared)).count
            case .hammered:
                1
            default:
                0
            }
        }
        let total = weights.reduce(0, +)
        scoreSteps = weights.map { total > 0 ? gained * $0 / total : 0 }
        // 나눗셈에서 남은 점수는 마지막으로 점수가 오르는 이벤트에 얹는다.
        if let last = weights.lastIndex(where: { $0 > 0 }) {
            scoreSteps[last] += gained - scoreSteps.reduce(0, +)
        }
        // 화면이 없으면 연출이 돌지 않으므로 바로 최종 점수를 보여준다.
        if view == nil {
            displayedScore = state.score
            scoreSteps = []
            finalBonus = 0
        }
    }

    /// 화면의 점수를 올리고 숫자를 한 번 튕긴다.
    private func addScore(_ amount: Int) {
        guard amount != 0 else { return }
        displayedScore += amount
        updateHUD()
        scoreLabel.removeAction(forKey: "pop")
        scoreLabel.setScale(1)
        scoreLabel.run(.sequence([.scale(to: 1.25, duration: 0.07), .scale(to: 1, duration: 0.13)]), withKey: "pop")
    }

    private func play(_ events: ArraySlice<GameEvent>, index: Int) {
        guard let event = events.first else {
            isAnimating = false
            scheduleHint()
            #if DEBUG
            autoPlayIfNeeded()
            #endif
            return
        }
        // 이어지는 낙하, 흘러내림, 보충은 한 흐름으로 묶어 재생한다.
        let flow = events.prefix { Self.isMotion($0) }
        if flow.isEmpty, scoreSteps.indices.contains(index) {
            addScore(scoreSteps[index])
        }
        let duration = flow.isEmpty ? animate(event) : animateFlow(flow)
        let consumed = max(flow.count, 1)
        let remaining = events.dropFirst(consumed)
        boardNode.run(.wait(forDuration: duration)) { [weak self] in
            MainActor.assumeIsolated {
                self?.play(remaining, index: index + consumed)
            }
        }
    }

    /// 이벤트에 맞는 효과음과 햅틱을 낸다.
    private func giveFeedback(for event: GameEvent) {
        guard let feedback else { return }
        switch event {
        case .swapped:
            feedback.play(.swap)
            feedback.haptic(.light)
        case .swapRejected:
            feedback.play(.reject)
            feedback.haptic(.warning)
        case .matchesCleared(_, let chain):
            feedback.play(.clear(chain: chain))
            feedback.haptic(chain >= 3 ? .medium : .light)
        case .specialsActivated(let activations):
            feedback.play(.special)
            if activations.contains(where: { Self.isDrone($0.effect) }) {
                feedback.play(.drone)
            }
            feedback.haptic(.heavy)
        case .specialsCreated:
            feedback.play(.create)
        case .obstaclesDamaged:
            feedback.play(.crack)
            feedback.haptic(.medium)
        case .materialsCollected:
            feedback.play(.collect)
            feedback.haptic(.success)
        case .won:
            feedback.play(.win)
            feedback.haptic(.success)
        case .lost:
            feedback.play(.lose)
            feedback.haptic(.failure)
        case .hammered:
            feedback.play(.crack)
            feedback.haptic(.heavy)
        case .nestsSpat:
            feedback.play(.crack)
            feedback.haptic(.light)
        case .timersBurst:
            feedback.play(.special)
            feedback.haptic(.heavy)
        case .fell, .slid, .refilled, .shuffled, .regenerated, .sludgeSpread, .scrolled, .timersTicked, .fogLifted, .stickyCleared, .shieldsBroken, .ventsPuffed:
            break
        }
    }

    /// 이벤트 하나의 애니메이션을 시작하고 걸리는 시간을 반환한다.
    private func animate(_ event: GameEvent) -> TimeInterval {
        giveFeedback(for: event)
        switch event {
        case .swapped(let swap):
            let first = blocks[swap.from]
            let second = blocks[swap.to]
            first?.run(move(to: swap.to, duration: Timing.swap))
            second?.run(move(to: swap.from, duration: Timing.swap))
            blocks[swap.from] = second
            blocks[swap.to] = first
            return Timing.swap

        case .swapRejected(let swap, let reason):
            // 입력 단계에서 걸러지지 않는 거부는 "매치 없음"뿐이다. 갔다가 제자리로 돌아온다.
            guard reason == .noMatch else { return 0 }
            for (from, to) in [(swap.from, swap.to), (swap.to, swap.from)] {
                blocks[from]?.run(.sequence([
                    move(to: to, duration: Timing.swap),
                    move(to: from, duration: Timing.swap),
                ]))
            }
            return Timing.swap * 2

        case .matchesCleared(let matches, let chain):
            // 철망에 갇힌 블록은 매치돼도 철망만 벗겨지고 남는다. 뒤따르는 장애물 이벤트에서 바꿔 그린다.
            var popped: [Position: TimeInterval] = [:]
            var tints: [Position: SKColor] = [:]
            for position in matches.flatMap(\.positions) where blocks[position]?.name?.hasSuffix("_caged") != true
                && blocks[position]?.name?.hasSuffix("_chained") != true {
                popped[position] = 0
                tints[position] = tint(at: position)
                removeBlock(at: position, scale: 0.2, duration: Timing.clear)
            }
            // 매치된 블록도 제 색의 빛과 알갱이를 남기고 사라진다.
            for (position, color) in tints {
                addPop(at: position, delay: 0, tint: color, bright: false)
            }
            addSparks(at: popped, tints: tints)
            if chain >= 3 {
                showPraise(chain: chain)
            }
            return Timing.clear

        case .specialsActivated(let activations):
            return animateActivations(activations)

        case .specialsCreated(let spawns):
            for spawn in spawns {
                // 조합 효과는 놓여 있던 블록을 특수 블록으로 바꾼다.
                blocks.removeValue(forKey: spawn.position)?.removeFromParent()
                let node = addBlock(spawn.block, at: spawn.position, from: spawn.position)
                node.setScale(0.3)
                node.run(.scale(to: 1, duration: Timing.create))
            }
            return Timing.create

        case .fell, .slid, .refilled:
            return animateFlow([event][...])

        case .obstaclesDamaged(let hits):
            // 맞은 장애물은 터지고, 남은 것은 한 겹 벗겨진 모습으로 바뀐다.
            // 강화 콘크리트는 보통 콘크리트로, 철망에 갇힌 블록은 일반 블록으로 남는다.
            for hit in hits {
                removeBlock(at: hit.position, scale: 1.2, duration: Timing.clear)
                if let remaining = hit.remaining {
                    addBlock(remaining, at: hit.position, from: hit.position)
                }
            }
            updateMinimap(top: displayedTop)
            return Timing.clear

        case .sludgeSpread(let positions):
            // 슬러지가 옆 칸의 블록을 덮는다.
            for position in positions {
                blocks.removeValue(forKey: position)?.removeFromParent()
                let node = addBlock(.sludge, at: position, from: position)
                node.setScale(0.3)
                node.run(.scale(to: 1, duration: Timing.create))
            }
            updateMinimap(top: displayedTop)
            return Timing.create

        case .nestsSpat(let spits):
            // 둥지가 움찔하며 슬러지 덩어리를 옆 칸으로 뱉는다. 덩어리가 닿으면 그 칸이 슬러지가 된다.
            let flight = Timing.create
            for spit in spits {
                blocks[spit.nest]?.run(.sequence([
                    .scale(to: 1.25, duration: flight * 0.4),
                    .scale(to: 1, duration: flight * 0.6),
                ]))
                let blob = BlockSprite.makeNode(block: .sludge, cellSize: layout.cellSize)
                blob.position = layout.center(of: spit.nest)
                blob.setScale(0.3)
                blob.zPosition = 20
                worldNode.addChild(blob)
                let target = spit.target
                blob.run(.sequence([
                    .group([
                        .move(to: layout.center(of: target), duration: flight),
                        .scale(to: 0.8, duration: flight),
                    ]),
                    .removeFromParent(),
                    .run { [weak self] in
                        guard let self else { return }
                        self.blocks.removeValue(forKey: target)?.removeFromParent()
                        let node = self.addBlock(.sludge, at: target, from: target)
                        node.setScale(0.8)
                        node.run(.scale(to: 1, duration: Timing.create * 0.5))
                    },
                ]))
            }
            run(.sequence([.wait(forDuration: flight * 1.5), .run { [weak self] in
                guard let self else { return }
                self.updateMinimap(top: self.displayedTop)
            }]))
            return flight * 1.6

        case .hammered(let position):
            // 망치가 닿는 순간에 블록이 제 색의 빛과 알갱이를 남기고 부서진다.
            let color = tint(at: position)
            removeBlock(at: position, scale: 1.6, duration: Timing.pop, delay: 0.1)
            addPop(at: position, delay: 0.1, tint: color, bright: true)
            addSparks(at: [position: 0.1], tints: [position: color])
            return 0.1 + Timing.pop

        case .shieldsBroken(let positions):
            // 보호막이 부풀다 터진다.
            for position in positions {
                guard let node = shieldNodes.removeValue(forKey: position) else { continue }
                node.removeAllActions()
                node.run(.sequence([
                    .group([.scale(to: 1.5, duration: Timing.clear), .fadeOut(withDuration: Timing.clear)]),
                    .removeFromParent(),
                ]))
            }
            return 0

        case .ventsPuffed(let positions):
            // 굴뚝에서 나온 안개가 옆 칸에 피어오른다.
            for position in positions where fogNodes[position] == nil {
                let node = addFog(at: position)
                node.alpha = 0
                node.run(.fadeIn(withDuration: Timing.create * 2))
            }
            return Timing.create

        case .stickyCleared(let positions):
            // 끈끈이가 오그라들며 사라진다.
            for position in positions {
                guard let node = stickyNodes.removeValue(forKey: position) else { continue }
                node.run(.sequence([
                    .group([.scale(to: 0.2, duration: Timing.clear * 1.4), .fadeOut(withDuration: Timing.clear * 1.4)]),
                    .removeFromParent(),
                ]))
            }
            return 0

        case .fogLifted(let positions):
            // 안개가 부풀며 흩어진다. 다음 연출을 기다리게 하지 않는다.
            for position in positions {
                guard let node = fogNodes.removeValue(forKey: position) else { continue }
                node.removeAllActions()
                node.run(.sequence([
                    .group([.scale(to: 1.5, duration: Timing.clear * 1.4), .fadeOut(withDuration: Timing.clear * 1.4)]),
                    .removeFromParent(),
                ]))
            }
            return 0

        case .timersTicked(let ticks):
            // 숫자가 줄면서 포자가 움찔한다. 얼마 남지 않은 것은 더 크게 뛴다.
            for tick in ticks {
                guard let node = blocks[tick.position] else { continue }
                BlockSprite.setTimer(tick.turns, on: node)
                let badge = node.childNode(withName: BlockSprite.timerName)
                let scale: CGFloat = tick.turns <= 2 ? 1.45 : 1.2
                badge?.run(.sequence([
                    .scale(to: scale, duration: Timing.create * 0.4),
                    .scale(to: 1, duration: Timing.create * 0.6),
                ]))
            }
            return Timing.create * 0.6

        case .timersBurst(let bursts):
            // 포자가 터지며 제자리와 옆 칸을 슬러지로 덮는다.
            for burst in bursts {
                let ring = SKShapeNode(circleOfRadius: layout.cellSize * 0.4)
                ring.position = layout.center(of: burst.position)
                ring.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 1)
                ring.lineWidth = layout.cellSize * 0.12
                ring.fillColor = .clear
                ring.zPosition = 20
                worldNode.addChild(ring)
                ring.run(.sequence([
                    .group([.scale(to: 3.4, duration: Timing.create), .fadeOut(withDuration: Timing.create)]),
                    .removeFromParent(),
                ]))
                for position in burst.sludge {
                    blocks.removeValue(forKey: position)?.removeFromParent()
                    let node = addBlock(.sludge, at: position, from: burst.position)
                    node.setScale(0.3)
                    node.run(.group([
                        .move(to: layout.center(of: position), duration: Timing.create),
                        .scale(to: 1, duration: Timing.create),
                    ]))
                }
            }
            shakeBoard(strength: 10)
            updateMinimap(top: displayedTop)
            return Timing.create * 1.2

        case .shuffled(let moves):
            let before = blocks
            for blockMove in moves {
                guard let node = before[blockMove.from] else { continue }
                blocks[blockMove.to] = node
                node.run(move(to: blockMove.to, duration: Timing.shuffle, timing: .easeInEaseOut))
            }
            return Timing.shuffle

        case .regenerated(let spawns):
            for spawn in spawns {
                blocks.removeValue(forKey: spawn.position)?.removeFromParent()
                let node = addBlock(spawn.block, at: spawn.position, from: spawn.position)
                node.alpha = 0
                node.run(.fadeIn(withDuration: Timing.shuffle))
            }
            return Timing.shuffle

        case .materialsCollected(let positions):
            // 물질이 보드 아래의 격리 컨테이너로 빨려 들어간다. 보드 밖으로 나가야 하므로 가림막 밖으로 옮긴다.
            let container = containerDrawFrame
            // 큰 물질은 여러 칸이 한 노드다. 노드마다 한 번만 처리하고 하나로 센다.
            var collected: [ObjectIdentifier: SKNode] = [:]
            for position in positions {
                if let node = blocks.removeValue(forKey: position) {
                    collected[ObjectIdentifier(node)] = node
                }
            }
            for node in collected.values {
                let start = CGPoint(
                    x: node.position.x + worldNode.position.x,
                    y: node.position.y + worldNode.position.y
                )
                node.removeFromParent()
                node.position = start
                node.zPosition = 5
                boardNode.addChild(node)
                node.run(.sequence([
                    .group([
                        .move(to: CGPoint(x: start.x, y: container.midY), duration: Timing.collect),
                        .scale(to: 0.4, duration: Timing.collect),
                    ]),
                    .removeFromParent(),
                ]))
            }
            let before = collectedShown
            collectedShown += collected.count
            gulp(newlyLit: before..<collectedShown)
            updateContainerLamps()
            updateHUD()
            updateMinimap(top: displayedTop)
            return Timing.collect

        case .scrolled(let from, let to):
            // 카메라가 내려간다. 지나간 행의 블록은 화면 밖으로 밀려난 뒤 버린다.
            let duration = min(Timing.scrollPerRow * TimeInterval(to - from), 0.8)
            let action = SKAction.move(to: worldOffset(top: CGFloat(to)), duration: duration)
            action.timingMode = .easeInEaseOut
            worldNode.run(action)
            for (position, node) in blocks where position.row < to {
                blocks.removeValue(forKey: position)
                node.run(.sequence([.wait(forDuration: duration), .removeFromParent()]))
            }
            updateMinimap(top: CGFloat(to))
            if isAtBoardEnd(top: to) {
                containerNode.run(.fadeAlpha(to: 1, duration: duration))
            }
            return duration

        case .won, .lost:
            // 남은 이동 횟수를 하나씩 점수로 바꿔 보여준 뒤 결과를 띄운다.
            let duration = tallyRemainingMoves()
            boardNode.run(.wait(forDuration: duration)) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.displayedScore = self.state.score
                    self.movesShown = nil
                    self.updateHUD()
                    self.showResult(notify: true)
                }
            }
            return duration
        }
    }

    /// 클리어한 판에서 남은 이동 횟수를 하나씩 줄이며 점수로 바꾼다. 걸리는 시간을 반환한다.
    private func tallyRemainingMoves() -> TimeInterval {
        let moves = state.movesRemaining ?? 0
        guard finalBonus > 0, moves > 0 else {
            displayedScore = state.score
            updateHUD()
            return 0.25
        }
        // 많이 남았어도 1.2초 안에 끝낸다.
        let step = min(0.08, 1.2 / Double(moves))
        let perMove = finalBonus / moves
        movesShown = moves
        for index in 0..<moves {
            boardNode.run(.wait(forDuration: Double(index + 1) * step)) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.movesShown = moves - index - 1
                    self.addScore(perMove)
                    if index.isMultiple(of: 2) {
                        self.feedback?.play(.tap)
                    }
                }
            }
        }
        return Double(moves) * step + 0.45
    }

    /// 화면에 보이는 활성 구간의 맨 위 행. 스크롤 애니메이션 중에는 도착할 행이 아니라 지금 위치다.
    private var displayedTop: CGFloat {
        layout.cellSize > 0 ? worldNode.position.y / layout.cellSize : 0
    }

    /// 끝나는 연출을 기다리는 결과를 연출을 건너뛰고 바로 알린다. 연출 도중에 화면을 나갈 때 쓴다.
    /// - Returns: 알렸는지. 알릴 결과가 없으면 `false`다.
    @discardableResult
    public func deliverPendingResult() -> Bool {
        guard hasPendingResult else { return false }
        // 끝난 상태로 다시 그리면 남은 연출이 버려지고, 그 끝에서 결과를 알린다.
        rebuild()
        return true
    }

    private func showResult(notify: Bool) {
        isShowingResult = true
        if notify {
            hasPendingResult = false
        }
        if let onFinish {
            if notify {
                onFinish(state)
            }
            return
        }
        let overlay = SKNode()
        overlay.zPosition = 10
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.65), size: size)
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(dim)

        let title = makeLabel(size: 34, alignment: .center)
        title.text = state.status == .won ? "정화 완료" : "이동 횟수 소진"
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        overlay.addChild(title)

        let detail = makeLabel(size: 17, alignment: .center)
        if state.status == .won {
            detail.text = "남은 이동 \(state.movesRemaining ?? 0)"
        } else {
            detail.text = "남은 물질 \(state.materialsRemaining)"
        }
        detail.position = CGPoint(x: size.width / 2, y: size.height / 2 - 14)
        overlay.addChild(detail)

        let hint = makeLabel(size: 15, alignment: .center)
        hint.text = "탭하여 다시 시작"
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position = CGPoint(x: size.width / 2, y: size.height / 2 - 48)
        overlay.addChild(hint)

        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.25))
        boardNode.addChild(overlay)
    }

    private static func isMotion(_ event: GameEvent) -> Bool {
        switch event {
        case .fell, .slid, .refilled: true
        default: false
        }
    }

    /// 낙하, 흘러내림, 보충을 블록마다 하나의 이어진 움직임으로 재생한다.
    ///
    /// 블록은 묶음 단위로 한꺼번에 움직이지 않고 아래쪽부터 차례로 출발한다. 한 블록이 여러 묶음에
    /// 걸쳐 움직이면(떨어진 뒤 미끄러지고 다시 떨어지는 식) 멈추지 않고 이어서 간다.
    private func animateFlow(_ events: ArraySlice<GameEvent>) -> TimeInterval {
        struct Segment {
            var start: TimeInterval
            var duration: TimeInterval
            var point: CGPoint
        }
        var tracks: [ObjectIdentifier: (node: SKNode, segments: [Segment])] = [:]
        var eventStart: TimeInterval = 0

        // 이 묶음에서 움직인 노드에 구간 하나를 더한다. 앞 구간이 끝나기 전에는 출발하지 않는다.
        func add(_ node: SKNode, duration: TimeInterval, order: Int) {
            let id = ObjectIdentifier(node)
            let previous = tracks[id]?.segments.last
            let start = max(eventStart + Timing.stagger * TimeInterval(order), previous.map { $0.start + $0.duration } ?? 0)
            tracks[id, default: (node, [])].segments.append(Segment(
                start: start,
                duration: previous == nil ? duration : duration * Timing.carryFactor,
                point: centroid(of: node)
            ))
        }

        for event in events {
            switch event {
            case .fell(let moves):
                // 같은 열에서는 아래쪽 블록이 먼저 오므로 도착 칸은 항상 비어 있다.
                // 큰 물질은 덮은 칸마다 이동이 하나씩 오고, 모두 같은 노드를 가리킨다.
                var moved: [(node: SKNode, cells: Int, order: Int)] = []
                var seen: Set<ObjectIdentifier> = []
                var orderInColumn: [Int: Int] = [:]
                for blockMove in moves {
                    guard let node = blocks.removeValue(forKey: blockMove.from) else { continue }
                    blocks[blockMove.to] = node
                    guard seen.insert(ObjectIdentifier(node)).inserted else { continue }
                    let order = orderInColumn[blockMove.from.column, default: 0]
                    orderInColumn[blockMove.from.column] = order + 1
                    moved.append((node, blockMove.to.row - blockMove.from.row, order))
                }
                for item in moved {
                    add(item.node, duration: fallDuration(cells: item.cells), order: item.order)
                }

            case .slid(let moves):
                // 옆 열의 블록이 대각선으로 미끄러져 내려온다. 아래쪽 빈칸부터 차례로 채워진다.
                for (order, blockMove) in moves.enumerated() {
                    guard let node = blocks.removeValue(forKey: blockMove.from) else { continue }
                    blocks[blockMove.to] = node
                    add(node, duration: Timing.slide, order: order)
                }

            case .refilled(let spawns):
                // 한 열에 n개가 들어오면 모두 n칸 위에서 출발해 줄지어 내려온다.
                let countByColumn = Dictionary(grouping: spawns, by: \.position.column).mapValues(\.count)
                var orderInColumn: [Int: Int] = [:]
                for spawn in spawns {
                    // 대기 표시도 GameCore의 보충 규칙대로 줄인다.
                    let column = spawn.position.column
                    if spawn.block == .material {
                        if let index = pendingShown.firstIndex(where: { $0.column == column && $0.depth == 0 }) {
                            pendingShown.remove(at: index)
                        }
                    } else {
                        for index in pendingShown.indices where pendingShown[index].column == column {
                            pendingShown[index].depth = max(pendingShown[index].depth - 1, 0)
                        }
                    }
                    let count = countByColumn[column] ?? 1
                    let start = Position(column: column, row: spawn.position.row - count)
                    let node = addBlock(spawn.block, at: spawn.position, from: start)
                    let order = orderInColumn[column, default: 0]
                    orderInColumn[column] = order + 1
                    add(node, duration: fallDuration(cells: count), order: order)
                }

            default:
                break
            }
            eventStart += Timing.flowStep
        }

        var total: TimeInterval = 0
        for (node, segments) in tracks.values {
            var actions: [SKAction] = []
            var clock: TimeInterval = 0
            for (index, segment) in segments.enumerated() {
                if segment.start > clock {
                    actions.append(.wait(forDuration: segment.start - clock))
                }
                let action = SKAction.move(to: segment.point, duration: segment.duration)
                // 처음에는 가속하며 출발하고, 이어지는 구간은 붙은 속도 그대로 간다.
                action.timingMode = index == 0 ? .easeIn : .linear
                actions.append(action)
                clock = segment.start + segment.duration
            }
            // 바닥에 닿으면 살짝 눌렸다가 튀어 오른다. 여러 칸에 걸친 큰 물질은 무거워 보이게 그대로 둔다.
            if blocks.values.filter({ $0 === node }).count <= 1 {
                actions.append(.sequence([
                    .group([.scaleX(to: 1.12, duration: 0.05), .scaleY(to: 0.86, duration: 0.05)]),
                    .group([.scaleX(to: 0.96, duration: 0.07), .scaleY(to: 1.05, duration: 0.07)]),
                    .group([.scaleX(to: 1, duration: 0.06), .scaleY(to: 1, duration: 0.06)]),
                ]))
            }
            node.run(.sequence(actions))
            total = max(total, clock)
        }
        updateQueue()
        updateMinimap(top: displayedTop)
        return total
    }

    // MARK: - 특수 효과의 연출

    /// 특수 효과를 재생한다. 효과는 중심에서 바깥으로 퍼져 나가며 칸을 차례로 터뜨린다.
    ///
    /// 빔은 줄을 따라 뻗어 나가고, 폭탄은 충격파가 퍼지고, 코어는 중심에서 대상 블록마다 빛줄기를 쏜다.
    /// 다른 효과에 맞아 이어서 발동하는 특수 블록은 자기가 맞은 순간에 시작한다.
    private func animateActivations(_ activations: [SpecialActivation]) -> TimeInterval {
        // 칸마다 터지는 시각.
        var delays: [Position: TimeInterval] = [:]
        // 폭탄에 터진 칸. 네모난 번쩍임 대신 불덩이가 덮으므로 따로 번쩍이지 않는다.
        var burned: Set<Position> = []
        var blasts: [(activation: SpecialActivation, start: TimeInterval, reach: TimeInterval)] = []
        for activation in activations {
            let origin = activation.origin
            let start = delays[origin] ?? 0
            let ordered = activation.cleared.sorted { Self.distance($0, origin) < Self.distance($1, origin) }
            var reach: TimeInterval = 0
            for (order, cell) in ordered.enumerated() {
                let offset: TimeInterval
                switch activation.effect {
                case .beam, .crossBeam, .wideCrossBeam:
                    // 빔은 한 칸씩 뻗어 나간다.
                    offset = Double(Self.distance(cell, origin)) * Timing.beamStep
                case .bomb, .bigBomb:
                    offset = Double(Self.distance(cell, origin)) * Timing.bombStep
                    burned.insert(cell)
                case .core, .coreBeam, .coreBomb, .coreDrone, .clearBoard:
                    // 코어는 가까운 블록부터 하나씩 터뜨린다. 대상이 많으면 간격을 줄인다.
                    offset = Double(order) * min(Timing.coreStep, 0.5 / Double(max(ordered.count, 1)))
                case .drone, .droneSwarm, .droneBeam, .droneBomb:
                    // 드론은 제자리와 상하좌우를 먼저 터뜨리고, 날아가 닿은 뒤에 목표 쪽을 터뜨린다.
                    if Self.distance(cell, origin) <= 1 {
                        offset = Double(Self.distance(cell, origin)) * Timing.bombStep
                    } else {
                        let landing = Self.droneTargets(of: activation.effect)
                            .min { Self.distance(cell, $0) < Self.distance(cell, $1) }
                        offset = Timing.droneFlight + Double(landing.map { Self.distance(cell, $0) } ?? 0) * Timing.bombStep
                    }
                }
                reach = max(reach, offset)
                delays[cell] = min(delays[cell] ?? .infinity, start + offset)
            }
            blasts.append((activation, start, reach))
        }

        // 터지는 칸의 색. 블록이 사라지기 전에 알아 둔다.
        var tints: [Position: SKColor] = [:]
        for position in delays.keys {
            tints[position] = tint(at: position)
        }
        for blast in blasts {
            addBlast(for: blast.activation, start: blast.start, reach: blast.reach, tints: tints)
        }
        for (position, delay) in delays {
            // 터지기 직전에 움찔 부풀었다가 터진다.
            blocks[position]?.run(.sequence([
                .wait(forDuration: max(delay - 0.07, 0)),
                .scale(to: 1.22, duration: 0.07),
            ]))
            removeBlock(at: position, scale: 1.7, duration: Timing.pop, delay: delay)
            addPop(at: position, delay: delay, tint: tints[position] ?? .white, bright: !burned.contains(position))
        }
        addSparks(at: delays, tints: tints)
        let cleared = Set(delays.keys)
        knockBack(from: activations.map(\.origin), near: cleared)
        shakeBoard(strength: min(CGFloat(cleared.count), 24))
        // 큰 효과는 보드 전체가 번쩍인다.
        for blast in blasts {
            switch blast.activation.effect {
            case .bigBomb, .wideCrossBeam, .coreBeam, .coreBomb, .coreDrone:
                flashBoard(alpha: 0.16, delay: blast.start)
            case .clearBoard:
                flashBoard(alpha: 0.3, delay: blast.start)
            case .crossBeam, .core:
                flashBoard(alpha: 0.07, delay: blast.start)
            case .beam, .bomb, .drone, .droneSwarm, .droneBeam, .droneBomb:
                break
            }
        }
        return (delays.values.max() ?? 0) + Timing.pop
    }

    /// 청소 드론이 날아가는 효과인지.
    private static func isDrone(_ effect: SpecialEffect) -> Bool {
        switch effect {
        case .drone, .droneSwarm, .droneBeam, .droneBomb: true
        default: false
        }
    }

    /// 청소 드론이 날아가 맞히는 칸.
    private static func droneTargets(of effect: SpecialEffect) -> [Position] {
        switch effect {
        case .drone(let target), .droneBeam(_, let target), .droneBomb(let target): target.map { [$0] } ?? []
        case .droneSwarm(let targets): targets
        default: []
        }
    }

    /// 연쇄가 길게 이어지면 보드 가운데에 칭찬을 띄운다. 연쇄가 길수록 말이 커진다.
    private func showPraise(chain: Int) {
        let words = ["좋아요!", "멋져요!", "굉장해요!", "환상적이에요!"].map { Self.text($0) }
        let node = SKNode()
        node.position = CGPoint(x: layout.frame.midX, y: layout.frame.midY + layout.cellSize * 1.5)
        node.zPosition = 9
        let size = layout.cellSize * (0.85 + CGFloat(min(chain - 3, 3)) * 0.1)
        for (offset, color) in [(CGPoint(x: 0, y: -size * 0.07), SKColor(red: 0.45, green: 0.1, blue: 0.3, alpha: 1)), (.zero, SKColor(red: 1, green: 0.88, blue: 0.35, alpha: 1))] {
            let label = makeLabel(size: size, alignment: .center)
            label.text = words[min(chain - 3, words.count - 1)]
            label.fontColor = color
            label.verticalAlignmentMode = .center
            label.position = offset
            node.addChild(label)
        }
        // 블록 위에서도 읽히게 어두운 바탕을 깐다.
        // 글자의 실제 폭에 맞춘다. 언어마다 글자 폭이 다르다.
        let width = (node.children.map(\.frame.width).max() ?? size * 4) + size * 1.2
        let backing = SKShapeNode(
            rect: CGRect(x: -width / 2, y: -size * 0.75, width: width, height: size * 1.5), cornerRadius: size * 0.75
        )
        backing.fillColor = SKColor(red: 0.1, green: 0.08, blue: 0.22, alpha: 0.78)
        backing.strokeColor = SKColor(red: 1, green: 0.88, blue: 0.35, alpha: 0.9)
        backing.lineWidth = max(size * 0.06, 1.5)
        backing.zPosition = -1
        node.addChild(backing)
        node.setScale(0.3)
        node.alpha = 0
        boardNode.addChild(node)
        let pop = SKAction.scale(to: 1.15, duration: 0.14)
        pop.timingMode = .easeOut
        node.run(.sequence([
            .group([.fadeIn(withDuration: 0.08), pop]),
            .scale(to: 1, duration: 0.08),
            .wait(forDuration: 0.35),
            .group([.moveBy(x: 0, y: layout.cellSize * 0.8, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// 칸에 놓인 블록의 색. 효과의 빛과 파편에 입힌다.
    private func tint(at position: Position) -> SKColor {
        guard let name = blocks[position]?.name else { return .white }
        for kind in BlockKind.allCases where name.hasPrefix(BlockSprite.name(for: kind)) {
            return BlockSprite.color(for: kind)
        }
        return SKColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)
    }

    /// 빛 그림 하나를 색을 입혀 만든다. 겹칠수록 밝아지게 더하기로 그린다.
    private func light(_ texture: SKTexture, color: SKColor, size: CGSize, at point: CGPoint, z: CGFloat = 3) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture, size: size)
        node.color = color
        node.colorBlendFactor = 1
        node.blendMode = .add
        node.position = point
        node.zPosition = z
        node.alpha = 0
        worldNode.addChild(node)
        return node
    }

    /// 칸 하나가 터지는 순간의 빛. 블록 색의 둥근 빛이 번지고 반짝임이 돌며 사라진다.
    private func addPop(at position: Position, delay: TimeInterval, tint: SKColor, bright: Bool) {
        let cell = layout.cellSize
        let center = layout.center(of: position)
        let glow = light(EffectTexture.glow, color: tint, size: CGSize(width: cell * 1.5, height: cell * 1.5), at: center, z: 2.5)
        glow.setScale(0.5)
        glow.run(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: bright ? 0.7 : 0.5, duration: 0.03),
            .group([.scale(to: 1.7, duration: Timing.pop * 1.3), .fadeOut(withDuration: Timing.pop * 1.3)]),
            .removeFromParent(),
        ]))
        guard bright else { return }
        let star = light(EffectTexture.sparkle, color: .white, size: CGSize(width: cell * 1.3, height: cell * 1.3), at: center, z: 3.4)
        star.setScale(0.2)
        star.zRotation = CGFloat((position.column * 7 + position.row * 13) % 8) * .pi / 8
        let grow = SKAction.scale(to: 1.15, duration: Timing.pop * 0.45)
        grow.timingMode = .easeOut
        star.run(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .sequence([grow, .scale(to: 0, duration: Timing.pop * 0.75)]),
                .rotate(byAngle: .pi / 2, duration: Timing.pop * 1.2),
            ]),
            .removeFromParent(),
        ]))
    }

    /// 보드 전체를 잠깐 하얗게 번쩍인다.
    private func flashBoard(alpha: CGFloat, delay: TimeInterval) {
        let flash = SKSpriteNode(color: .white, size: layout.frame.size)
        flash.position = CGPoint(x: layout.frame.midX, y: layout.frame.midY)
        flash.zPosition = 8
        flash.blendMode = .add
        flash.alpha = 0
        boardNode.addChild(flash)
        flash.run(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: alpha, duration: 0.04),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    /// 두 칸 사이의 거리. 대각선도 한 칸으로 센다.
    private static func distance(_ first: Position, _ second: Position) -> Int {
        max(abs(first.column - second.column), abs(first.row - second.row))
    }

    /// 효과의 모양을 그린다. `start`는 시작하는 시각, `reach`는 가장 먼 칸에 닿을 때까지 걸리는 시간이다.
    private func addBlast(for activation: SpecialActivation, start: TimeInterval, reach: TimeInterval, tints: [Position: SKColor]) {
        let center = layout.center(of: activation.origin)
        let cell = layout.cellSize
        let boardWidth = layout.frame.width
        let warm = SKColor(red: 1, green: 0.78, blue: 0.3, alpha: 1)
        let cool = SKColor(red: 0.55, green: 0.95, blue: 1, alpha: 1)

        /// 중심에서 양쪽으로 뻗어 나가는 빛줄기. 번지는 빛, 색 띠, 흰 심을 겹치고,
        /// 빛 덩어리 두 개가 줄 끝까지 달려가며 가는 빛살이 그 뒤를 따른다.
        func beam(_ orientation: Orientation, thickness: CGFloat) {
            let length = orientation == .horizontal ? boardWidth * 2 : CGFloat(GameConstants.activeRows) * cell * 2
            let angle: CGFloat = orientation == .horizontal ? 0 : .pi / 2
            let axis = CGVector(dx: cos(angle), dy: sin(angle))
            let travel = max(reach, 0.12)
            let layers: [(CGFloat, SKColor, CGFloat)] = [
                (thickness * 2.6, SKColor(red: 0.2, green: 0.75, blue: 1, alpha: 1), 0.55),
                (thickness * 1.3, cool, 0.95),
                (thickness * 0.5, .white, 1),
            ]
            for (width, color, alpha) in layers {
                let bar = light(EffectTexture.beam, color: color, size: CGSize(width: length, height: cell * width), at: center)
                bar.zRotation = angle
                // 중심의 한 점에서 시작해 줄 끝까지 자란다.
                bar.xScale = 0.02
                let grow = SKAction.scaleX(to: 1, duration: travel)
                grow.timingMode = .easeOut
                // 머무는 동안 굵기가 떨려 살아 있는 빛처럼 보인다.
                let flicker = SKAction.sequence([
                    .scaleY(to: 1.25, duration: Timing.beamHold / 2),
                    .scaleY(to: 0.9, duration: Timing.beamHold / 2),
                ])
                bar.run(.sequence([
                    .wait(forDuration: start),
                    .fadeAlpha(to: alpha, duration: 0.02),
                    grow,
                    flicker,
                    .group([.scaleY(to: 0.05, duration: Timing.beamFade), .fadeOut(withDuration: Timing.beamFade)]),
                    .removeFromParent(),
                ]))
            }
            for side in [CGFloat(-1), 1] {
                // 줄 끝으로 달려가는 빛 덩어리.
                let head = light(
                    EffectTexture.glow, color: .white,
                    size: CGSize(width: cell * 2.2 * thickness.squareRoot(), height: cell * 1.5 * thickness.squareRoot()),
                    at: center, z: 3.2
                )
                head.zRotation = angle
                let run = SKAction.moveBy(x: axis.dx * side * length / 2, y: axis.dy * side * length / 2, duration: travel)
                run.timingMode = .easeOut
                head.run(.sequence([
                    .wait(forDuration: start),
                    .fadeAlpha(to: 1, duration: 0.02),
                    run,
                    .fadeOut(withDuration: 0.12),
                    .removeFromParent(),
                ]))
                // 줄을 따라 뒤따르는 가는 빛살.
                for index in 0..<7 {
                    let lane = (CGFloat((index * 5) % 7) / 6 - 0.5) * cell * thickness * 1.5
                    let streak = light(
                        EffectTexture.glow, color: index.isMultiple(of: 2) ? .white : cool,
                        size: CGSize(width: cell * (0.9 + CGFloat(index % 3) * 0.4), height: cell * 0.1),
                        at: CGPoint(x: center.x - axis.dy * lane, y: center.y + axis.dx * lane), z: 3.3
                    )
                    streak.zRotation = angle
                    let fly = SKAction.moveBy(
                        x: axis.dx * side * length * 0.45, y: axis.dy * side * length * 0.45,
                        duration: travel + Timing.beamHold + 0.15
                    )
                    fly.timingMode = .easeOut
                    streak.run(.sequence([
                        .wait(forDuration: start + Double(index) * 0.025),
                        .fadeAlpha(to: 0.9, duration: 0.02),
                        .group([fly, .sequence([.wait(forDuration: travel), .fadeOut(withDuration: Timing.beamHold + 0.15)])]),
                        .removeFromParent(),
                    ]))
                }
            }
            // 포구에서 번쩍이는 빛과 반짝임.
            let muzzle = light(EffectTexture.glow, color: .white, size: CGSize(width: cell * 2, height: cell * 2), at: center, z: 3.4)
            muzzle.setScale(0.4)
            muzzle.run(.sequence([
                .wait(forDuration: start),
                .fadeAlpha(to: 1, duration: 0.03),
                .group([.scale(to: 1.6 * thickness.squareRoot(), duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
            let star = light(EffectTexture.sparkle, color: .white, size: CGSize(width: cell * 2.6, height: cell * 2.6), at: center, z: 3.5)
            star.setScale(0.2)
            star.run(.sequence([
                .wait(forDuration: start),
                .fadeAlpha(to: 1, duration: 0.02),
                .group([
                    .sequence([.scale(to: thickness.squareRoot() * 1.2, duration: 0.14), .scale(to: 0, duration: 0.26)]),
                    .rotate(byAngle: .pi / 2, duration: 0.4),
                ]),
                .removeFromParent(),
            ]))
        }

        /// 중심에서 퍼져 나가는 충격파. 고리 두 개가 조금 어긋나 퍼지고 가운데가 번쩍인다.
        func shockwave(reachCells: CGFloat, color: SKColor) {
            let duration = max(reach + Timing.pop, 0.35)
            for (lag, width) in [(0.0, 0.26), (0.08, 0.12)] {
                let ring = SKShapeNode(circleOfRadius: cell * 0.5)
                ring.position = center
                ring.zPosition = 3
                ring.strokeColor = color
                ring.lineWidth = cell * width
                ring.fillColor = .clear
                ring.blendMode = .add
                ring.alpha = 0
                ring.setScale(0.3)
                worldNode.addChild(ring)
                let grow = SKAction.scale(to: reachCells * 2, duration: duration)
                grow.timingMode = .easeOut
                ring.run(.sequence([
                    .wait(forDuration: start + lag),
                    .fadeAlpha(to: 1, duration: 0.02),
                    .group([grow, .sequence([.wait(forDuration: duration * 0.4), .fadeOut(withDuration: duration * 0.6)])]),
                    .removeFromParent(),
                ]))
            }
            let core = SKShapeNode(circleOfRadius: cell * 0.6)
            core.position = center
            core.zPosition = 3.1
            core.fillColor = .white
            core.strokeColor = .clear
            core.blendMode = .add
            core.alpha = 0
            worldNode.addChild(core)
            core.run(.sequence([
                .wait(forDuration: start),
                .fadeAlpha(to: 1, duration: 0.03),
                .group([.scale(to: reachCells, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                .removeFromParent(),
            ]))
        }

        /// 코어가 힘을 모으는 모습. 여섯 색의 빛이 코어 둘레를 돌며 안으로 빨려 들어간다.
        func charge(duration: TimeInterval) {
            let orbit = SKNode()
            orbit.position = center
            orbit.zPosition = 3.3
            worldNode.addChild(orbit)
            for (index, kind) in BlockKind.allCases.enumerated() {
                let angle = CGFloat(index) * 2 * .pi / CGFloat(BlockKind.allCases.count)
                let orb = SKSpriteNode(texture: EffectTexture.glow, size: CGSize(width: cell * 0.9, height: cell * 0.9))
                orb.color = BlockSprite.color(for: kind)
                orb.colorBlendFactor = 1
                orb.blendMode = .add
                orb.position = CGPoint(x: cos(angle) * cell * 1.1, y: sin(angle) * cell * 1.1)
                orbit.addChild(orb)
                let pull = SKAction.move(to: .zero, duration: duration)
                pull.timingMode = .easeIn
                orb.run(pull)
            }
            orbit.alpha = 0
            orbit.run(.sequence([
                .wait(forDuration: start),
                .fadeIn(withDuration: 0.03),
                .rotate(byAngle: .pi * 2.5, duration: duration),
                .fadeOut(withDuration: 0.08),
                .removeFromParent(),
            ]))
            let halo = light(EffectTexture.glow, color: .white, size: CGSize(width: cell * 2.4, height: cell * 2.4), at: center, z: 3.2)
            halo.setScale(0.4)
            halo.run(.sequence([
                .wait(forDuration: start),
                .fadeAlpha(to: 0.9, duration: 0.03),
                .scale(to: 1.3, duration: duration),
                .group([.scale(to: 2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                .removeFromParent(),
            ]))
        }

        /// 코어가 대상 블록마다 쏘는 번개. 꺾인 줄을 대상의 색으로 굵게, 흰색으로 가늘게 겹쳐 그리고,
        /// 닿는 자리에 빛이 번쩍인다. 너무 많으면 가까운 것만 그린다.
        func rays() {
            let targets = activation.cleared
                .filter { $0 != activation.origin }
                .sorted { Self.distance($0, activation.origin) < Self.distance($1, activation.origin) }
            let step = min(Timing.coreStep, 0.5 / Double(max(activation.cleared.count, 1)))
            charge(duration: max(Double(min(targets.count, 40)) * step, 0.25))
            for (order, target) in targets.prefix(40).enumerated() {
                let end = layout.center(of: target)
                let color = tints[target] ?? cool
                // 가는 길에 서너 번 꺾인다. 꺾이는 폭은 칸의 위치로 정해 같은 판은 늘 같은 모습이다.
                let path = CGMutablePath()
                path.move(to: center)
                let length = hypot(end.x - center.x, end.y - center.y)
                let normal = length > 0 ? CGPoint(x: -(end.y - center.y) / length, y: (end.x - center.x) / length) : .zero
                let bends = max(Int(length / (cell * 1.2)), 2)
                for bend in 1..<bends {
                    let t = CGFloat(bend) / CGFloat(bends)
                    let sway = sin(CGFloat(target.column * 31 + target.row * 17 + bend * 7)) * cell * 0.32
                    path.addLine(to: CGPoint(
                        x: center.x + (end.x - center.x) * t + normal.x * sway,
                        y: center.y + (end.y - center.y) * t + normal.y * sway
                    ))
                }
                path.addLine(to: end)
                let strike = start + Double(order + 1) * step
                for (width, stroke, alpha) in [(0.24, color, CGFloat(0.75)), (0.08, SKColor.white, CGFloat(1))] {
                    let bolt = SKShapeNode(path: path)
                    bolt.strokeColor = stroke
                    bolt.lineWidth = max(cell * width, 1.5)
                    bolt.lineCap = .round
                    bolt.lineJoin = .round
                    bolt.zPosition = 3
                    bolt.blendMode = .add
                    bolt.alpha = 0
                    worldNode.addChild(bolt)
                    bolt.run(.sequence([
                        .wait(forDuration: strike),
                        .fadeAlpha(to: alpha, duration: 0.02),
                        .fadeAlpha(to: alpha * 0.4, duration: 0.05),
                        .fadeAlpha(to: alpha, duration: 0.03),
                        .fadeOut(withDuration: 0.18),
                        .removeFromParent(),
                    ]))
                }
                let impact = light(EffectTexture.glow, color: color, size: CGSize(width: cell * 1.8, height: cell * 1.8), at: end, z: 3.1)
                impact.setScale(0.3)
                impact.run(.sequence([
                    .wait(forDuration: strike),
                    .fadeAlpha(to: 1, duration: 0.02),
                    .group([.scale(to: 1.2, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                    .removeFromParent(),
                ]))
            }
        }

        /// 폭발. 둥근 불덩이 여러 개가 어긋나게 부풀고, 불티가 멀리 튀고, 연기가 피어오른다.
        /// 칸의 네모에 맞지 않도록 모든 것을 원과 불규칙한 자리로 그린다.
        func explosion(reachCells: CGFloat) {
            let radius = cell * reachCells
            // 자리와 크기는 칸의 위치로 정해, 같은 판은 늘 같은 모습으로 터진다.
            let seed = CGFloat(activation.origin.column * 53 + activation.origin.row * 97)
            func wobble(_ index: Int, _ scale: CGFloat) -> CGFloat {
                sin(seed + CGFloat(index) * 2.4) * scale
            }
            func blob(color: SKColor, size: CGFloat, at offset: CGPoint, delay: TimeInterval, life: TimeInterval, additive: Bool, z: CGFloat) {
                let node = SKShapeNode(circleOfRadius: cell * 0.5)
                node.position = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
                node.zPosition = z
                node.fillColor = color
                node.strokeColor = .clear
                node.blendMode = additive ? .add : .alpha
                node.alpha = 0
                node.setScale(0.2)
                worldNode.addChild(node)
                let grow = SKAction.scale(to: size / (cell * 0.5), duration: life)
                grow.timingMode = .easeOut
                node.run(.sequence([
                    .wait(forDuration: start + delay),
                    .fadeAlpha(to: 1, duration: 0.02),
                    .group([grow, .sequence([.wait(forDuration: life * 0.35), .fadeOut(withDuration: life * 0.65)])]),
                    .removeFromParent(),
                ]))
            }
            // 연기. 불덩이 뒤에서 늦게 피어올라 위로 흩어진다.
            for index in 0..<7 {
                let angle = CGFloat(index) * 0.9 + seed
                let offset = CGPoint(x: cos(angle) * radius * 0.45, y: sin(angle) * radius * 0.4 + radius * 0.15)
                blob(
                    color: SKColor(red: 0.22, green: 0.2, blue: 0.26, alpha: 0.75),
                    size: radius * (0.42 + abs(wobble(index, 0.12))), at: offset,
                    delay: 0.12 + Double(index) * 0.02, life: 0.6, additive: false, z: 2.9
                )
            }
            // 불덩이. 붉은 것부터 흰 것까지 겹치고, 가장자리에 작은 불덩이가 어긋나게 터진다.
            blob(color: SKColor(red: 1, green: 0.35, blue: 0.1, alpha: 1), size: radius * 1.0, at: .zero, delay: 0, life: 0.38, additive: true, z: 3)
            blob(color: SKColor(red: 1, green: 0.7, blue: 0.2, alpha: 1), size: radius * 0.78, at: .zero, delay: 0.02, life: 0.32, additive: true, z: 3.1)
            blob(color: .white, size: radius * 0.5, at: .zero, delay: 0, life: 0.22, additive: true, z: 3.2)
            for index in 0..<6 {
                let angle = CGFloat(index) * 1.05 + seed * 0.7
                let distance = radius * (0.5 + abs(wobble(index, 0.25)))
                blob(
                    color: index.isMultiple(of: 2) ? SKColor(red: 1, green: 0.5, blue: 0.12, alpha: 1) : warm,
                    size: radius * (0.3 + abs(wobble(index + 3, 0.14))),
                    at: CGPoint(x: cos(angle) * distance, y: sin(angle) * distance),
                    delay: 0.04 + Double(index) * 0.025, life: 0.3, additive: true, z: 3.05
                )
            }
            // 불티. 길쭉한 조각이 멀리 날아가다 아래로 떨어진다.
            for index in 0..<14 {
                let angle = CGFloat(index) * (2 * .pi / 14) + wobble(index, 0.3)
                let ember = SKSpriteNode(
                    color: index.isMultiple(of: 3) ? .white : warm,
                    size: CGSize(width: cell * 0.28, height: cell * 0.08)
                )
                ember.position = center
                ember.zPosition = 3.3
                ember.zRotation = angle
                ember.blendMode = .add
                ember.alpha = 0
                worldNode.addChild(ember)
                let distance = radius * (1.1 + abs(wobble(index + 5, 0.5)))
                let life = 0.45 + Double(abs(wobble(index, 0.15)))
                let fly = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: life)
                fly.timingMode = .easeOut
                let drop = SKAction.moveBy(x: 0, y: -cell * 0.5, duration: life)
                drop.timingMode = .easeIn
                ember.run(.sequence([
                    .wait(forDuration: start),
                    .fadeAlpha(to: 1, duration: 0.01),
                    .group([fly, drop, .sequence([.wait(forDuration: life * 0.5), .fadeOut(withDuration: life * 0.5)])]),
                    .removeFromParent(),
                ]))
            }
            // 터지는 순간의 눈부신 빛과, 사방으로 돌며 날아가는 반짝임.
            let burst = light(EffectTexture.glow, color: SKColor(red: 1, green: 0.95, blue: 0.75, alpha: 1), size: CGSize(width: radius * 3.4, height: radius * 3.4), at: center, z: 3.25)
            burst.setScale(0.3)
            burst.run(.sequence([
                .wait(forDuration: start),
                .fadeAlpha(to: 1, duration: 0.02),
                .group([.scale(to: 1, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
            for index in 0..<8 {
                let angle = CGFloat(index) * (.pi / 4) + seed * 0.3
                let star = light(
                    EffectTexture.sparkle, color: index.isMultiple(of: 2) ? .white : warm,
                    size: CGSize(width: cell * 0.9, height: cell * 0.9), at: center, z: 3.4
                )
                star.setScale(0.3)
                let distance = radius * (0.9 + abs(wobble(index + 9, 0.5)))
                let fly = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.5)
                fly.timingMode = .easeOut
                star.run(.sequence([
                    .wait(forDuration: start + 0.03),
                    .fadeAlpha(to: 1, duration: 0.02),
                    .group([
                        fly,
                        .rotate(byAngle: .pi, duration: 0.5),
                        .sequence([.scale(to: 1, duration: 0.18), .scale(to: 0, duration: 0.32)]),
                    ]),
                    .removeFromParent(),
                ]))
            }
            // 한 박자 늦게 퍼지는 두 번째 충격파.
            let echo = SKShapeNode(circleOfRadius: cell * 0.5)
            echo.position = center
            echo.zPosition = 3
            echo.strokeColor = warm
            echo.lineWidth = cell * 0.16
            echo.fillColor = .clear
            echo.blendMode = .add
            echo.alpha = 0
            echo.setScale(0.3)
            worldNode.addChild(echo)
            let widen = SKAction.scale(to: reachCells * 2.1, duration: 0.45)
            widen.timingMode = .easeOut
            echo.run(.sequence([
                .wait(forDuration: start + 0.12),
                .fadeAlpha(to: 0.8, duration: 0.02),
                .group([widen, .fadeOut(withDuration: 0.45)]),
                .removeFromParent(),
            ]))
            // 가느다란 충격파 하나.
            let ring = SKShapeNode(circleOfRadius: cell * 0.5)
            ring.position = center
            ring.zPosition = 3
            ring.strokeColor = SKColor(red: 1, green: 0.92, blue: 0.7, alpha: 1)
            ring.lineWidth = cell * 0.08
            ring.fillColor = .clear
            ring.blendMode = .add
            ring.alpha = 0
            ring.setScale(0.3)
            worldNode.addChild(ring)
            let spread = SKAction.scale(to: reachCells * 2.6, duration: 0.4)
            spread.timingMode = .easeOut
            ring.run(.sequence([
                .wait(forDuration: start),
                .fadeAlpha(to: 0.9, duration: 0.02),
                .group([spread, .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        }

        switch activation.effect {
        case .beam(let orientation):
            beam(orientation, thickness: 0.7)
        case .crossBeam:
            beam(.horizontal, thickness: 0.7)
            beam(.vertical, thickness: 0.7)
        case .wideCrossBeam:
            beam(.horizontal, thickness: 2.6)
            beam(.vertical, thickness: 2.6)
        case .bomb:
            explosion(reachCells: 1.9)
        case .bigBomb:
            explosion(reachCells: 3.1)
        case .core, .coreBeam, .coreBomb, .coreDrone:
            shockwave(reachCells: 1.4, color: cool)
            rays()
        case .drone, .droneSwarm, .droneBeam, .droneBomb:
            // 제자리에서 작게 터지고, 드론이 목표로 날아가 닿은 자리에서 다시 터진다.
            shockwave(reachCells: 1.1, color: cool)
            for target in Self.droneTargets(of: activation.effect) {
                flyDrone(from: activation.origin, to: target, start: start)
                let landing = start + Timing.droneFlight
                let payload: SpecialEffect = switch activation.effect {
                case .droneBeam(let orientation, _): .beam(orientation)
                case .droneBomb: .bomb
                default: .bomb
                }
                if case .drone = activation.effect {
                    // 혼자 날아간 드론은 목표 한 칸만 맞히므로 작은 충격만 남긴다.
                    let hit = SpecialActivation(origin: target, effect: .drone(nil), cleared: [])
                    addLanding(hit, start: landing)
                } else if case .droneSwarm = activation.effect {
                    addLanding(SpecialActivation(origin: target, effect: .drone(nil), cleared: []), start: landing)
                } else {
                    addBlast(for: SpecialActivation(origin: target, effect: payload, cleared: []), start: landing, reach: 0.25, tints: tints)
                }
            }
        case .clearBoard:
            shockwave(reachCells: 9, color: cool)
            shockwave(reachCells: 5, color: warm)
        }
    }

    /// 청소 드론이 `from`에서 `to`로 날아간다. 살짝 위로 휘며 날고, 날개처럼 돈다.
    private func flyDrone(from: Position, to: Position, start: TimeInterval) {
        let cell = layout.cellSize
        let node = BlockSprite.makeNode(block: .drone, cellSize: cell)
        node.position = layout.center(of: from)
        node.zPosition = 8
        node.alpha = 0
        worldNode.addChild(node)
        let a = layout.center(of: from)
        let b = layout.center(of: to)
        let lift = cell * 1.6
        let path = CGMutablePath()
        path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + lift))
        let flight = SKAction.follow(path, asOffset: false, orientToPath: false, duration: Timing.droneFlight)
        flight.timingMode = .easeInEaseOut
        node.run(.sequence([
            .wait(forDuration: start),
            .fadeIn(withDuration: 0.04),
            .group([flight, .rotate(byAngle: .pi * 4, duration: Timing.droneFlight), .sequence([
                .scale(to: 1.25, duration: Timing.droneFlight / 2), .scale(to: 0.9, duration: Timing.droneFlight / 2),
            ])]),
            .fadeOut(withDuration: 0.06),
            .removeFromParent(),
        ]))
        // 지나간 자리에 옅은 빛을 남긴다.
        let trail = light(EffectTexture.glow, color: SKColor(red: 0.55, green: 0.95, blue: 1, alpha: 1), size: CGSize(width: cell * 0.6, height: cell * 0.6), at: a)
        trail.alpha = 0
        trail.run(.sequence([
            .wait(forDuration: start),
            .group([.follow(path, asOffset: false, orientToPath: false, duration: Timing.droneFlight), .sequence([.fadeAlpha(to: 0.6, duration: 0.05), .wait(forDuration: Timing.droneFlight - 0.1), .fadeOut(withDuration: 0.05)])]),
            .removeFromParent(),
        ]))
    }

    /// 드론이 목표에 닿은 자리의 번쩍임.
    private func addLanding(_ hit: SpecialActivation, start: TimeInterval) {
        let cell = layout.cellSize
        let flash = light(EffectTexture.sparkle, color: .white, size: CGSize(width: cell * 1.8, height: cell * 1.8), at: layout.center(of: hit.origin))
        flash.alpha = 0
        flash.run(.sequence([
            .wait(forDuration: start),
            .fadeAlpha(to: 1, duration: 0.03),
            .group([.scale(to: 1.6, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent(),
        ]))
    }

    /// 터지는 칸마다 그 순간에 블록 색의 빛 알갱이를 사방으로 날린다. 날아가다 아래로 떨어진다.
    /// 칸 수가 많으면 알갱이를 줄인다.
    private func addSparks(at cells: [Position: TimeInterval], tints: [Position: SKColor] = [:]) {
        let perCell = cells.count > 24 ? 3 : (cells.count > 10 ? 5 : 7)
        let cell = layout.cellSize
        for (position, delay) in cells {
            let center = layout.center(of: position)
            let tint = tints[position] ?? SKColor(red: 1, green: 0.9, blue: 0.45, alpha: 1)
            // 칸의 위치로 방향을 정해 같은 판은 늘 같은 모습으로 터진다.
            let base = CGFloat((position.column * 37 + position.row * 91) % 360) * .pi / 180
            for index in 0..<perCell {
                let angle = base + CGFloat(index) * 2 * .pi / CGFloat(perCell)
                let side = cell * (0.26 + CGFloat(index % 3) * 0.08)
                let spark = light(
                    EffectTexture.glow, color: index.isMultiple(of: 3) ? .white : tint,
                    size: CGSize(width: side, height: side), at: center
                )
                let distance = cell * (0.9 + CGFloat(index % 3) * 0.35)
                let life = Timing.pop * 2
                let fly = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: life)
                fly.timingMode = .easeOut
                let drop = SKAction.moveBy(x: 0, y: -cell * 0.45, duration: life)
                drop.timingMode = .easeIn
                spark.run(.sequence([
                    .wait(forDuration: delay),
                    .fadeAlpha(to: 1, duration: 0.01),
                    .group([
                        fly, drop,
                        .sequence([.wait(forDuration: life * 0.4), .fadeOut(withDuration: life * 0.6)]),
                        .scale(to: 0.35, duration: life),
                    ]),
                    .removeFromParent(),
                ]))
            }
        }
    }

    /// 터진 칸 가까이에 남은 블록을 효과의 중심에서 바깥쪽으로 살짝 밀었다가 제자리로 돌린다.
    /// 다음 낙하가 시작되기 전에 끝나야 하므로 효과 시간 안에 마친다.
    private func knockBack(from origins: [Position], near cleared: Set<Position>) {
        guard !cleared.isEmpty else { return }
        let cell = layout.cellSize
        var seen: Set<ObjectIdentifier> = []
        for (position, node) in blocks where !cleared.contains(position) {
            guard seen.insert(ObjectIdentifier(node)).inserted else { continue }
            // 벽은 꿈쩍하지 않는다.
            guard node.name != BlockSprite.name(for: .wall) else { continue }
            // 가장 가까운 터진 칸까지의 거리. 두 칸 안쪽만 민다.
            let gap = cleared.map { max(abs($0.column - position.column), abs($0.row - position.row)) }.min() ?? 9
            guard gap <= 2 else { continue }
            let home = node.position
            // 미는 방향은 가장 가까운 효과의 중심에서 이 블록을 향하는 쪽이다.
            let origin = origins.min {
                abs($0.column - position.column) + abs($0.row - position.row)
                    < abs($1.column - position.column) + abs($1.row - position.row)
            } ?? position
            let from = layout.center(of: origin)
            var dx = home.x - from.x
            var dy = home.y - from.y
            let length = max(hypot(dx, dy), 1)
            dx /= length
            dy /= length
            let push = cell * (gap == 1 ? 0.2 : 0.1)
            let out = SKAction.move(to: CGPoint(x: home.x + dx * push, y: home.y + dy * push), duration: Timing.pop * 0.3)
            out.timingMode = .easeOut
            let back = SKAction.move(to: home, duration: Timing.pop * 0.55)
            back.timingMode = .easeInEaseOut
            node.run(.group([
                .sequence([out, back]),
                .sequence([
                    .scale(to: 0.9, duration: Timing.pop * 0.3),
                    .scale(to: 1, duration: Timing.pop * 0.55),
                ]),
            ]))
        }
    }

    /// 보드를 짧게 흔든다. 많이 터질수록 세게 흔들린다.
    private func shakeBoard(strength: CGFloat) {
        let amplitude = 2 + strength * 0.3
        let step = Timing.effect / 5
        var moves: [SKAction] = []
        var offset = CGPoint.zero
        // 좌우와 위아래로 번갈아 움직이고 마지막에 제자리로 돌아온다.
        for (index, direction) in [(1.0, 0.6), (-1.0, -0.8), (0.7, 0.9), (-0.5, -0.4)].enumerated() {
            let fade = 1 - CGFloat(index) * 0.2
            let target = CGPoint(x: direction.0 * amplitude * fade, y: direction.1 * amplitude * fade)
            moves.append(.moveBy(x: target.x - offset.x, y: target.y - offset.y, duration: step))
            offset = target
        }
        moves.append(.moveBy(x: -offset.x, y: -offset.y, duration: step))
        // 앞의 흔들림이 끝나기 전에 또 터지면 제자리에서 다시 시작한다.
        cropNode.removeAction(forKey: "shake")
        cropNode.position = .zero
        cropNode.run(.sequence(moves), withKey: "shake")
    }

    private func removeBlock(at position: Position, scale: CGFloat, duration: TimeInterval, delay: TimeInterval = 0) {
        blocks.removeValue(forKey: position)?.run(.sequence([
            .wait(forDuration: delay),
            .group([
                .scale(to: scale, duration: duration),
                .fadeOut(withDuration: duration),
            ]),
            .removeFromParent(),
        ]))
    }

    private func move(
        to position: Position,
        duration: TimeInterval,
        timing: SKActionTimingMode = .easeOut
    ) -> SKAction {
        let action = SKAction.move(to: layout.center(of: position), duration: duration)
        action.timingMode = timing
        return action
    }

    /// `cells`칸을 떨어지는 데 걸리는 시간. 등가속 낙하처럼 거리의 제곱근에 비례한다.
    private func fallDuration(cells: Int) -> TimeInterval {
        Timing.fallUnit * Double(max(cells, 1)).squareRoot()
    }

    /// 두 칸이 같은 노드로 그려지는지. 테스트에 쓴다.
    func sharesNode(_ first: Position, _ second: Position) -> Bool {
        guard let node = blocks[first] else { return false }
        return node === blocks[second]
    }

    /// 칸에 놓인 블록의 스프라이트 이름. 테스트와 디버깅에 쓴다.
    func spriteName(at position: Position) -> String? {
        blocks[position]?.name
    }

    /// HUD에 표시된 글자. 테스트에 쓴다.
    var hudText: (moves: String?, materials: String?, score: String?) {
        (movesLabel.text, materialsLabel.text, scoreLabel.text)
    }

    // MARK: - 자동 플레이 (디버그)

    #if DEBUG
    /// 켜 두면 사람 대신 스스로 판을 진행한다. 시뮬레이터에서 한 판을 끝까지 확인할 때 쓴다.
    public var autoPlays = false

    private func autoPlayIfNeeded() {
        guard autoPlays, view != nil, !isAnimating, state.status == .playing else { return }
        boardNode.run(.wait(forDuration: 0.25)) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let swap = self.autoMove() else { return }
                self.perform(swap)
            }
        }
    }

    /// 물질을 가장 많이 내리는 이동을 고른다.
    private func autoMove() -> Swap? {
        func progress(_ state: GameState) -> Int {
            let collected = state.materialsTotal - state.materialsRemaining
            // 큰 물질 아래에 파 놓은 빈칸도 조금씩 진전으로 친다.
            let caves = state.board.positions(in: state.activeRange).count { state.board[$0] == nil }
            return collected * 10_000
                + state.materialPositions.map(\.row).reduce(0, +) * 10
                - state.pendingMaterials.map { $0.depth + 1 }.reduce(0, +) * 10
                + caves
        }
        var best: (swap: Swap, progress: Int)?
        for swap in state.possibleMoves() {
            let value = progress(state.performTurn(swap).state)
            if best == nil || value > best!.progress {
                best = (swap, value)
            }
        }
        return best?.swap
    }
    #endif
}

// MARK: - 터치

#if canImport(UIKit)
import UIKit

extension BoardScene {
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        beginDrag(at: touch.location(in: self))
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        continueDrag(to: touch.location(in: self))
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag()
    }
}
#endif
