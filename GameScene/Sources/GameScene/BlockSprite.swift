import GameCore
import SpriteKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 블록의 모습(10장 "아트").
///
/// 스프라이트 이름과 같은 이름의 그림이 `Sprites` 폴더에 있으면 그 그림을 쓰고, 없으면 색 도형으로 그린다.
/// 종류마다 색과 모양을 함께 다르게 해서 색만으로 구분하지 않게 한다(3장).
@MainActor
enum BlockSprite {
    /// 스프라이트 이름. 나중에 이미지로 바꿀 때도 이 이름을 쓴다.
    static func name(for kind: BlockKind) -> String {
        switch kind {
        case .brick: "block_brick"
        case .scrap: "block_scrap"
        case .glass: "block_glass"
        case .wood: "block_wood"
        case .plastic: "block_plastic"
        case .soil: "block_soil"
        }
    }

    private static var textures: [String: SKTexture?] = [:]

    /// 스프라이트 이름에 해당하는 그림. 패키지에 없으면 `nil`이다.
    static func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] {
            return cached
        }
        var texture: SKTexture?
        if let url = Bundle.module.url(forResource: name, withExtension: "png") {
            #if canImport(UIKit)
            texture = UIImage(contentsOfFile: url.path).map(SKTexture.init(image:))
            #elseif canImport(AppKit)
            texture = NSImage(contentsOf: url).map(SKTexture.init(image:))
            #endif
        }
        textures[name] = texture
        return texture
    }

    /// 그림으로 그린 블록.
    private static func spriteNode(named name: String, cellSize: CGFloat) -> SKSpriteNode? {
        guard let texture = texture(named: name) else { return nil }
        // 그림 파일에 여백이 조금 있어서 칸 크기 그대로 그린다.
        let node = SKSpriteNode(texture: texture, size: CGSize(width: cellSize, height: cellSize))
        node.name = name
        return node
    }

    static func color(for kind: BlockKind) -> SKColor {
        switch kind {
        case .brick: SKColor(red: 0.86, green: 0.33, blue: 0.27, alpha: 1)
        case .scrap: SKColor(red: 0.62, green: 0.67, blue: 0.74, alpha: 1)
        case .glass: SKColor(red: 0.30, green: 0.78, blue: 0.90, alpha: 1)
        case .wood: SKColor(red: 0.93, green: 0.69, blue: 0.29, alpha: 1)
        case .plastic: SKColor(red: 0.45, green: 0.80, blue: 0.42, alpha: 1)
        case .soil: SKColor(red: 0.67, green: 0.48, blue: 0.86, alpha: 1)
        }
    }

    /// 특수 블록까지 구분하는 스프라이트 이름.
    static func name(for block: Block) -> String {
        switch block {
        case .normal(let kind): name(for: kind)
        case .beam(.horizontal): "block_beam_h"
        case .beam(.vertical): "block_beam_v"
        case .bomb: "block_bomb"
        case .core: "block_core"
        case .drone: "block_drone"
        case .material: materialName
        case .concrete(let hp): "obstacle_concrete_\(hp)"
        case .caged(let kind): name(for: kind) + "_caged"
        case .sludge: "obstacle_sludge"
        case .wall: "obstacle_wall"
        case .rubble: "obstacle_rubble"
        case .nest(let hp): "obstacle_nest_\(min(hp, 2))"
        case .timed(let kind, _): name(for: kind) + "_timed"
        case .egg: "obstacle_egg"
        case .chained(let kind): name(for: kind) + "_chained"
        case .boulder: "obstacle_boulder"
        case .vent(let hp): "obstacle_vent_\(min(hp, 2))"
        case .frozen(let kind): name(for: kind) + "_frozen"
        case .cocoon(let kind): "obstacle_cocoon_" + name(for: kind)
        }
    }

    /// 오염 물질의 스프라이트 이름.
    static let materialName = "material"

    /// 철망 그림의 이름. 갇힌 블록의 그림 위에 얹는다.
    static let cageName = "obstacle_cage"

    /// 블록 노드를 만든다. 스프라이트 이름과 같은 그림이 있으면 그 그림을 쓴다.
    static func makeNode(block: Block, cellSize: CGFloat) -> SKNode {
        let radius = cellSize * 0.4
        // 이 블록 그대로의 그림이 있으면 그것을 쓴다.
        if let sprite = spriteNode(named: name(for: block), cellSize: cellSize) {
            return sprite
        }
        // 오염 고치는 고치 그림의 창에 갇힌 블록의 그림을 작게 넣는다.
        if case .cocoon(let kind) = block {
            return makeCocoon(kind: kind, cellSize: cellSize)
        }
        // 얼음 블록은 종류의 그림 위에 얼음을 씌운다.
        if case .frozen(let kind) = block {
            let base: SKNode = spriteNode(named: name(for: kind), cellSize: cellSize) ?? {
                let shape = SKShapeNode(path: path(for: kind, radius: radius))
                shape.fillColor = color(for: kind)
                shape.strokeColor = .clear
                return shape
            }()
            base.name = name(for: block)
            base.addChild(iceOverlay(cellSize: cellSize))
            return base
        }
        // 철망에 갇힌 블록은 종류의 그림 위에 철망을 얹는다.
        if let kind = block.kind, let base = spriteNode(named: name(for: kind), cellSize: cellSize) {
            base.name = name(for: block)
            decorate(base, for: block, radius: radius, cellSize: cellSize)
            return base
        }
        let node: SKShapeNode
        if case .concrete(let hp) = block {
            return makeConcrete(hp: hp, cellSize: cellSize)
        } else if block == .sludge {
            return makeSludge(cellSize: cellSize)
        } else if block == .wall {
            return makeWall(cellSize: cellSize)
        } else if block == .boulder {
            // 그림이 없을 때의 운석 조각.
            let rock = SKShapeNode(path: star(points: 7, outer: cellSize * 0.44, inner: cellSize * 0.37))
            rock.name = name(for: .boulder)
            rock.fillColor = SKColor(red: 0.25, green: 0.2, blue: 0.2, alpha: 1)
            rock.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
            rock.lineWidth = max(cellSize * 0.05, 1)
            return rock
        } else if case .vent = block {
            // 그림이 없을 때의 안개 굴뚝.
            let side = cellSize * 0.7
            let pipe = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerRadius: cellSize * 0.12)
            pipe.name = name(for: block)
            pipe.fillColor = SKColor(red: 0.25, green: 0.33, blue: 0.5, alpha: 1)
            pipe.strokeColor = SKColor(red: 0.12, green: 0.16, blue: 0.3, alpha: 1)
            pipe.lineWidth = max(cellSize * 0.06, 1)
            return pipe
        } else if block == .egg {
            // 그림이 없을 때의 포자 알. 짙은 남색 타원이다.
            let egg = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.7, height: cellSize * 0.88))
            egg.name = name(for: .egg)
            egg.fillColor = SKColor(red: 0.16, green: 0.2, blue: 0.42, alpha: 1)
            egg.strokeColor = SKColor(red: 0.08, green: 0.1, blue: 0.24, alpha: 1)
            egg.lineWidth = max(cellSize * 0.06, 1)
            return egg
        } else if case .nest = block {
            // 그림이 없을 때의 포자 둥지. 분홍 덩어리에 어두운 구멍이 있다.
            let mound = SKShapeNode(circleOfRadius: cellSize * 0.42)
            mound.name = name(for: block)
            mound.fillColor = SKColor(red: 0.85, green: 0.1, blue: 0.6, alpha: 1)
            mound.strokeColor = SKColor(red: 0.5, green: 0.05, blue: 0.35, alpha: 1)
            mound.lineWidth = max(cellSize * 0.05, 1)
            let mouth = SKShapeNode(circleOfRadius: cellSize * 0.2)
            mouth.fillColor = SKColor(red: 0.2, green: 0.1, blue: 0.08, alpha: 1)
            mouth.strokeColor = .clear
            mound.addChild(mouth)
            return mound
        } else if block == .rubble {
            // 그림이 없을 때의 잔해 더미. 울퉁불퉁한 회색 덩어리다.
            let pile = SKShapeNode(path: star(points: 6, outer: cellSize * 0.45, inner: cellSize * 0.36))
            pile.name = name(for: .rubble)
            pile.fillColor = SKColor(white: 0.6, alpha: 1)
            pile.strokeColor = SKColor(white: 0.3, alpha: 1)
            pile.lineWidth = max(cellSize * 0.05, 1)
            return pile
        } else if block == .material {
            // 오염 물질은 블록과 헷갈리지 않게 뾰족한 포자 모양에 어두운 핵을 둔다.
            node = SKShapeNode(path: star(points: 10, outer: radius * 1.12, inner: radius * 0.82))
            node.fillColor = SKColor(red: 1.0, green: 0.22, blue: 0.58, alpha: 1)
            let core = radius * 0.4
            let nucleus = SKShapeNode(
                path: CGPath(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2), transform: nil)
            )
            nucleus.fillColor = SKColor(red: 0.25, green: 0.02, blue: 0.16, alpha: 1)
            nucleus.strokeColor = .clear
            nucleus.zPosition = 0.1
            node.addChild(nucleus)
        } else if let kind = block.kind {
            node = SKShapeNode(path: path(for: kind, radius: radius))
            node.fillColor = color(for: kind)
        } else if block == .core {
            // 정화 코어는 흰 별로 그린다.
            node = SKShapeNode(path: star(points: 8, outer: radius * 1.1, inner: radius * 0.6))
            node.fillColor = .white
        } else if block == .drone {
            // 그림이 없을 때의 청소 드론. 청록색 원판 위에 흰 날개 넷을 둔다.
            node = SKShapeNode(circleOfRadius: radius)
            node.fillColor = SKColor(red: 0.12, green: 0.62, blue: 0.66, alpha: 1)
        } else {
            // 제염 빔과 중화 폭탄은 어두운 강철색 원판 위에 흰 표식을 둔다.
            node = SKShapeNode(circleOfRadius: radius)
            node.fillColor = SKColor(white: 0.32, alpha: 1)
        }
        node.name = name(for: block)
        node.strokeColor = SKColor(white: 0, alpha: 0.35)
        node.lineWidth = max(cellSize * 0.04, 1)
        node.lineJoin = .round
        decorate(node, for: block, radius: radius, cellSize: cellSize)
        return node
    }

    /// 그림이 없을 때 쓰는 특수 블록의 흰 표식과, 철망을 노드 위에 얹는다.
    private static func decorate(_ node: SKNode, for block: Block, radius: CGFloat, cellSize: CGFloat) {
        switch block.special {
        case .beam(let orientation):
            // 지우는 줄의 방향으로 놓인 막대.
            let length = cellSize * 0.82
            let thickness = cellSize * 0.16
            let size = orientation == .horizontal
                ? CGSize(width: length, height: thickness)
                : CGSize(width: thickness, height: length)
            node.addChild(marker(CGPath(
                roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                cornerWidth: thickness / 2,
                cornerHeight: thickness / 2,
                transform: nil
            ), cellSize: cellSize))
        case .bomb:
            // 가운데의 둥근 점.
            let dot = radius * 0.45
            node.addChild(marker(
                CGPath(ellipseIn: CGRect(x: -dot, y: -dot, width: dot * 2, height: dot * 2), transform: nil),
                cellSize: cellSize
            ))
        case .drone:
            // 네 갈래 날개. 대각선으로 놓아 빔의 막대와 헷갈리지 않게 한다.
            let blade = CGMutablePath()
            let long = radius * 0.78
            let wide = radius * 0.2
            for index in 0..<4 {
                let angle = CGFloat(index) * .pi / 2 + .pi / 4
                var transform = CGAffineTransform(rotationAngle: angle)
                blade.addPath(CGPath(
                    roundedRect: CGRect(x: wide * 0.6, y: -wide / 2, width: long, height: wide),
                    cornerWidth: wide / 2, cornerHeight: wide / 2, transform: &transform
                ))
            }
            let hub = radius * 0.22
            blade.addEllipse(in: CGRect(x: -hub, y: -hub, width: hub * 2, height: hub * 2))
            node.addChild(marker(blade, cellSize: cellSize))
        case .core, nil:
            break
        }
        if case .caged = block {
            node.addChild(cageOverlay(cellSize: cellSize))
        }
        if case .chained = block {
            // 철망 위에 자물쇠 달린 쇠사슬을 한 겹 더 얹는다. 그림이 없으면 금빛 철망을 비스듬히 얹는다.
            node.addChild(cageOverlay(cellSize: cellSize))
            if let chain = spriteNode(named: "obstacle_chain", cellSize: cellSize) {
                chain.name = "chain"
                chain.zPosition = 0.25
                node.addChild(chain)
            } else {
                let chain = cageOverlay(cellSize: cellSize * 1.08)
                chain.name = "chain"
                chain.zRotation = .pi / 4
                chain.setScale(0.78)
                chain.zPosition = 0.25
                (chain as? SKShapeNode)?.strokeColor = SKColor(red: 1, green: 0.78, blue: 0.2, alpha: 1)
                node.addChild(chain)
            }
        }
        if case .timed(_, let turns) = block {
            node.addChild(timerOverlay(turns: turns, cellSize: cellSize))
        }
    }

    /// 블록을 덮은 얼음. 반투명한 하늘색 덩어리에 흰 빛줄기가 있다.
    private static func iceOverlay(cellSize: CGFloat) -> SKNode {
        if let ice = spriteNode(named: "obstacle_ice", cellSize: cellSize * 1.04) {
            ice.name = "ice"
            ice.zPosition = 0.3
            return ice
        }
        let side = cellSize * 0.94
        let ice = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerRadius: cellSize * 0.2)
        ice.name = "ice"
        ice.fillColor = SKColor(red: 0.72, green: 0.9, blue: 1, alpha: 0.6)
        ice.strokeColor = SKColor(red: 0.9, green: 0.98, blue: 1, alpha: 0.95)
        ice.lineWidth = max(cellSize * 0.06, 1.5)
        ice.zPosition = 0.3
        for (x, length) in [(-0.2, 0.34), (-0.05, 0.2)] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: cellSize * CGFloat(x), y: cellSize * 0.3))
            path.addLine(to: CGPoint(x: cellSize * (CGFloat(x) - CGFloat(length) * 0.5), y: cellSize * (0.3 - CGFloat(length))))
            let glint = SKShapeNode(path: path)
            glint.strokeColor = SKColor(white: 1, alpha: 0.85)
            glint.lineWidth = max(cellSize * 0.07, 1.5)
            glint.lineCap = .round
            ice.addChild(glint)
        }
        return ice
    }

    /// 포자 보호막. 칸을 감싼 둥근 막이다. 블록 위에 얹는다.
    static func makeShield(cellSize: CGFloat) -> SKNode {
        if let ring = spriteNode(named: "obstacle_shield", cellSize: cellSize * 1.08) {
            // 고리 안쪽에 옅은 막을 깔아 안이 덮여 있음을 보인다.
            let film = SKShapeNode(circleOfRadius: cellSize * 0.4)
            film.fillColor = SKColor(red: 0.4, green: 0.95, blue: 1, alpha: 0.22)
            film.strokeColor = .clear
            film.zPosition = -0.1
            ring.addChild(film)
            return ring
        }
        let bubble = SKShapeNode(circleOfRadius: cellSize * 0.5)
        bubble.name = "obstacle_shield"
        bubble.fillColor = SKColor(red: 0.3, green: 0.95, blue: 0.9, alpha: 0.2)
        bubble.strokeColor = SKColor(red: 0.6, green: 1, blue: 0.95, alpha: 0.95)
        bubble.lineWidth = max(cellSize * 0.07, 1.5)
        let glint = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.26, height: cellSize * 0.12))
        glint.position = CGPoint(x: -cellSize * 0.2, y: cellSize * 0.28)
        glint.zRotation = 0.6
        glint.fillColor = SKColor(white: 1, alpha: 0.8)
        glint.strokeColor = .clear
        bubble.addChild(glint)
        return bubble
    }

    /// 끈끈이 바닥. 칸을 다 채우고 블록 아래에 깔린다.
    static func makeSticky(cellSize: CGFloat) -> SKNode {
        if let texture = texture(named: "obstacle_sticky") {
            let node = SKSpriteNode(texture: texture, size: CGSize(width: cellSize * 1.06, height: cellSize * 1.06))
            node.name = "obstacle_sticky"
            return node
        }
        let side = cellSize * 0.98
        let node = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerRadius: cellSize * 0.22)
        node.name = "obstacle_sticky"
        node.fillColor = SKColor(red: 0.1, green: 0.75, blue: 0.75, alpha: 1)
        node.strokeColor = SKColor(red: 0.05, green: 0.45, blue: 0.5, alpha: 1)
        node.lineWidth = max(cellSize * 0.05, 1)
        return node
    }

    /// 오염 안개. 칸을 다 덮어 그 아래의 블록을 가린다.
    static func makeFog(cellSize: CGFloat) -> SKNode {
        if let texture = texture(named: "obstacle_fog") {
            let node = SKSpriteNode(texture: texture, size: CGSize(width: cellSize * 1.08, height: cellSize * 1.08))
            node.name = "obstacle_fog"
            return node
        }
        let side = cellSize * 0.98
        let node = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerRadius: cellSize * 0.3)
        node.name = "obstacle_fog"
        node.fillColor = SKColor(red: 0.45, green: 0.25, blue: 0.6, alpha: 1)
        node.strokeColor = SKColor(red: 0.3, green: 0.12, blue: 0.42, alpha: 1)
        node.lineWidth = max(cellSize * 0.04, 1)
        return node
    }

    /// 시한 포자의 노드 이름과, 그 안의 숫자 노드 이름.
    static let timerName = "timer"
    private static let timerLabelName = "timerLabel"

    /// 블록의 오른쪽 아래에 붙는 시한 포자. 가운데의 어두운 원에 남은 턴을 적는다.
    /// 블록의 종류가 보여야 하므로 칸의 절반 남짓만 가린다.
    private static func timerOverlay(turns: Int, cellSize: CGFloat) -> SKNode {
        let side = cellSize * 0.62
        let badge: SKNode
        if let texture = texture(named: "obstacle_timer") {
            let size = texture.size()
            badge = SKSpriteNode(texture: texture, size: CGSize(width: side * size.width / max(size.height, 1), height: side))
        } else {
            let spore = SKShapeNode(path: star(points: 9, outer: side * 0.5, inner: side * 0.38))
            spore.fillColor = SKColor(red: 1.0, green: 0.22, blue: 0.58, alpha: 1)
            spore.strokeColor = SKColor(red: 0.5, green: 0.05, blue: 0.3, alpha: 1)
            spore.lineWidth = max(cellSize * 0.03, 1)
            let disc = SKShapeNode(circleOfRadius: side * 0.26)
            disc.fillColor = SKColor(red: 0.25, green: 0.02, blue: 0.16, alpha: 1)
            disc.strokeColor = .clear
            spore.addChild(disc)
            badge = spore
        }
        badge.name = timerName
        badge.position = CGPoint(x: cellSize * 0.19, y: -cellSize * 0.17)
        badge.zPosition = 0.3
        let label = SKLabelNode(fontNamed: BoardScene.fontName)
        label.name = timerLabelName
        label.fontSize = side * 0.44
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        // 그림의 어두운 원은 심지 때문에 한가운데보다 조금 아래에 있다.
        label.position = CGPoint(x: 0, y: -side * 0.05)
        label.zPosition = 0.1
        badge.addChild(label)
        setTimer(turns, on: badge)
        return badge
    }

    /// 시한 포자의 숫자를 바꾼다. 얼마 남지 않으면 빨갛게 적는다. `node`는 블록 노드이거나 포자 노드다.
    static func setTimer(_ turns: Int, on node: SKNode) {
        let badge = node.name == timerName ? node : node.childNode(withName: timerName)
        guard let label = badge?.childNode(withName: timerLabelName) as? SKLabelNode else { return }
        label.text = "\(turns)"
        label.fontColor = turns <= 2 ? SKColor(red: 1.0, green: 0.35, blue: 0.3, alpha: 1) : .white
    }

    /// 콘크리트. 칸을 거의 다 채우는 회색 판이고, 강화형(hp 2)은 안쪽에 테두리가 하나 더 있다.
    private static func makeConcrete(hp: Int, cellSize: CGFloat) -> SKShapeNode {
        let side = cellSize * 0.9
        let node = SKShapeNode(
            rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
            cornerRadius: cellSize * 0.08
        )
        node.name = name(for: .concrete(hp: hp))
        node.fillColor = SKColor(white: 0.42, alpha: 1)
        node.strokeColor = SKColor(white: 0.2, alpha: 1)
        node.lineWidth = max(cellSize * 0.05, 1)
        if hp > 1 {
            let inner = side * 0.62
            let plate = SKShapeNode(
                rect: CGRect(x: -inner / 2, y: -inner / 2, width: inner, height: inner),
                cornerRadius: cellSize * 0.05
            )
            plate.fillColor = SKColor(white: 0.55, alpha: 1)
            plate.strokeColor = SKColor(white: 0.2, alpha: 1)
            plate.lineWidth = max(cellSize * 0.05, 1)
            plate.zPosition = 0.1
            node.addChild(plate)
        }
        return node
    }

    /// 벽. 칸을 꽉 채우는 어두운 남색 판이다. 부술 수 없다는 것이 보이도록 콘크리트보다 어둡고 매끈하게 그린다.
    private static func makeWall(cellSize: CGFloat) -> SKShapeNode {
        let side = cellSize * 0.98
        let node = SKShapeNode(
            rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
            cornerRadius: cellSize * 0.14
        )
        node.name = name(for: .wall)
        node.fillColor = SKColor(red: 0.20, green: 0.23, blue: 0.38, alpha: 1)
        node.strokeColor = SKColor(red: 0.36, green: 0.40, blue: 0.60, alpha: 1)
        node.lineWidth = max(cellSize * 0.05, 1)
        return node
    }

    /// 오염 고치의 그림 이름.
    static let cocoonName = "obstacle_cocoon"

    /// 오염 고치. 가운데 창에 비치는 종류의 블록을 옆에서 맞춰야 터진다.
    private static func makeCocoon(kind: BlockKind, cellSize: CGFloat) -> SKNode {
        let node: SKNode
        if let texture = texture(named: cocoonName) {
            node = SKSpriteNode(texture: texture, size: CGSize(width: cellSize, height: cellSize))
        } else {
            let side = cellSize * 0.94
            let box = SKShapeNode(
                rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                cornerRadius: cellSize * 0.14
            )
            box.fillColor = SKColor(red: 1.0, green: 0.36, blue: 0.66, alpha: 1)
            box.strokeColor = SKColor(red: 0.72, green: 0.1, blue: 0.4, alpha: 1)
            box.lineWidth = max(cellSize * 0.07, 1.5)
            node = box
        }
        node.name = name(for: .cocoon(kind))
        let icon = makeNode(block: .normal(kind), cellSize: cellSize * 0.46)
        icon.name = "cocoonKind"
        // 창은 고치의 가운데에 있다.
        icon.position = CGPoint(x: 0, y: cellSize * 0.02)
        icon.zPosition = 0.1
        node.addChild(icon)
        return node
    }

    /// 오염 슬러지. 어두운 녹색 덩어리다.
    private static func makeSludge(cellSize: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(path: star(points: 7, outer: cellSize * 0.47, inner: cellSize * 0.38))
        node.name = name(for: .sludge)
        node.fillColor = SKColor(red: 0.20, green: 0.30, blue: 0.12, alpha: 1)
        node.strokeColor = SKColor(red: 0.55, green: 0.75, blue: 0.20, alpha: 1)
        node.lineWidth = max(cellSize * 0.05, 1)
        node.lineJoin = .round
        return node
    }

    /// 철망. 갇힌 블록 위에 격자를 덮는다.
    private static func cageOverlay(cellSize: CGFloat) -> SKNode {
        if let cage = spriteNode(named: cageName, cellSize: cellSize) {
            cage.name = "cage"
            // 은청색 고철 위에서 묻히지 않도록 창살을 조금 어둡게 누른다.
            cage.color = SKColor(red: 0.16, green: 0.18, blue: 0.28, alpha: 1)
            cage.colorBlendFactor = 0.5
            cage.zPosition = 0.2
            return cage
        }
        let side = cellSize * 0.9
        let path = CGMutablePath()
        path.addRect(CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
        for step in 1...2 {
            let offset = -side / 2 + side * CGFloat(step) / 3
            path.move(to: CGPoint(x: offset, y: -side / 2))
            path.addLine(to: CGPoint(x: offset, y: side / 2))
            path.move(to: CGPoint(x: -side / 2, y: offset))
            path.addLine(to: CGPoint(x: side / 2, y: offset))
        }
        let cage = SKShapeNode(path: path)
        cage.name = "cage"
        cage.fillColor = .clear
        cage.strokeColor = SKColor(white: 0.92, alpha: 0.9)
        cage.lineWidth = max(cellSize * 0.05, 1.5)
        cage.zPosition = 0.2
        return cage
    }

    /// 물질 덩어리 하나를 그린다. 한 칸짜리는 포자 모양이고, 큰 것은 덮은 칸 전체를 채우는
    /// 한 덩어리에 칸마다 어두운 핵을 둔다.
    static func makeMaterialNode(width: Int, height: Int, cellSize: CGFloat) -> SKNode {
        guard width * height > 1 else {
            return makeNode(block: .material, cellSize: cellSize)
        }
        // 크기에 맞는 그림이 있으면 덮은 칸 전체에 그린다.
        if let texture = texture(named: "\(materialName)_\(width)x\(height)") {
            let sprite = SKSpriteNode(
                texture: texture,
                size: CGSize(width: CGFloat(width) * cellSize, height: CGFloat(height) * cellSize)
            )
            sprite.name = materialName
            return sprite
        }
        let size = CGSize(
            width: (CGFloat(width) - 0.16) * cellSize,
            height: (CGFloat(height) - 0.16) * cellSize
        )
        let node = SKShapeNode(
            rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerRadius: cellSize * 0.3
        )
        node.name = materialName
        node.fillColor = SKColor(red: 1.0, green: 0.22, blue: 0.58, alpha: 1)
        node.strokeColor = SKColor(white: 0, alpha: 0.35)
        node.lineWidth = max(cellSize * 0.04, 1)
        let core = cellSize * 0.16
        for row in 0..<height {
            for column in 0..<width {
                let nucleus = SKShapeNode(
                    path: CGPath(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2), transform: nil)
                )
                nucleus.fillColor = SKColor(red: 0.25, green: 0.02, blue: 0.16, alpha: 1)
                nucleus.strokeColor = .clear
                nucleus.zPosition = 0.1
                nucleus.position = CGPoint(
                    x: (CGFloat(column) - CGFloat(width - 1) / 2) * cellSize,
                    y: (CGFloat(height - 1) / 2 - CGFloat(row)) * cellSize
                )
                node.addChild(nucleus)
            }
        }
        return node
    }

    private static func marker(_ path: CGPath, cellSize: CGFloat) -> SKShapeNode {
        let marker = SKShapeNode(path: path)
        marker.fillColor = .white
        marker.strokeColor = SKColor(white: 0, alpha: 0.55)
        marker.lineWidth = max(cellSize * 0.03, 1)
        marker.zPosition = 0.1
        return marker
    }

    private static func star(points: Int, outer: CGFloat, inner: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = .pi / 2 + CGFloat(index) * .pi / CGFloat(points)
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func path(for kind: BlockKind, radius: CGFloat) -> CGPath {
        switch kind {
        case .brick:
            // 둥근 사각형
            let side = radius * 1.7
            return CGPath(
                roundedRect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                cornerWidth: side * 0.18,
                cornerHeight: side * 0.18,
                transform: nil
            )
        case .scrap:
            return polygon(sides: 6, radius: radius, rotation: 0)
        case .glass:
            return polygon(sides: 4, radius: radius * 1.1, rotation: 0)
        case .wood:
            return CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        case .plastic:
            return polygon(sides: 3, radius: radius * 1.15, rotation: .pi / 2, offsetY: -radius * 0.15)
        case .soil:
            return polygon(sides: 5, radius: radius * 1.05, rotation: .pi / 2)
        }
    }

    /// 정다각형. `rotation`은 첫 꼭짓점의 방향이다.
    private static func polygon(sides: Int, radius: CGFloat, rotation: CGFloat, offsetY: CGFloat = 0) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<sides {
            let angle = rotation + CGFloat(index) * 2 * .pi / CGFloat(sides)
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius + offsetY)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#if canImport(UIKit)
/// 스프라이트 그림. 게임 화면 밖(부스터 고르기 등)에서 같은 그림을 쓸 때 부른다.
public enum SpriteImage {
    public static func image(named name: String) -> UIImage? {
        Bundle.module.url(forResource: name, withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
    }
}
#endif
