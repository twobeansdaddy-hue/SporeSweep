import Foundation

/// 일반 블록의 종류. 오염된 잔해 조각이다(3장).
public enum BlockKind: Int, CaseIterable, Hashable, Sendable, Codable {
    case brick
    case scrap
    case glass
    case wood
    case plastic
    case soil
}

/// 특수 블록의 종류(4장). 이름은 가칭이다.
public enum Special: Hashable, Sendable, Codable {
    /// 제염 빔. 방향과 같은 줄 전체를 제거한다.
    case beam(Orientation)
    /// 중화 폭탄. 주변 3×3을 제거한다.
    case bomb
    /// 정화 코어. 스왑한 블록과 같은 종류를 모두 제거한다.
    case core
}

extension BlockKind {
    /// 레벨 파일에 적는 이름.
    public var name: String {
        switch self {
        case .brick: "brick"
        case .scrap: "scrap"
        case .glass: "glass"
        case .wood: "wood"
        case .plastic: "plastic"
        case .soil: "soil"
        }
    }

    public init?(name: String) {
        guard let kind = BlockKind.allCases.first(where: { $0.name == name }) else { return nil }
        self = kind
    }
}

/// 보드 한 칸에 놓이는 블록.
///
/// 특수 블록(제염 빔, 중화 폭탄, 정화 코어)과 오염 물질은 종류가 없어 매치에 들지 않는다.
/// 특수 블록은 옆 칸의 블록과 스왑하면 옮겨 간 자리에서 발동한다(4장).
public enum Block: Hashable, Sendable, Codable {
    case normal(BlockKind)
    case beam(Orientation)
    case bomb
    case core
    /// 외계 오염 물질(5장). 매치되지 않고 어떤 효과로도 사라지지 않으며 중력만 받는다.
    case material
    /// 콘크리트(7장). 움직이지 않고 떨어지지 않는다. 옆에서 매치하거나 특수 효과가 닿으면 `hp`가 1 준다.
    case concrete(hp: Int)
    /// 철망에 갇힌 블록(7장). 종류가 있어 매치에 쓰이지만 스왑할 수 없다.
    /// 매치에 들거나 특수 효과에 맞으면 철망만 사라지고 블록은 남는다. 그 블록을 다시 매치해야 없어진다.
    case caged(BlockKind)
    /// 오염 슬러지(7장). 움직이지 않는다. 하나도 제거하지 못한 턴마다 옆 칸으로 번진다.
    case sludge
    /// 벽(5장). 보드의 모양을 만드는 칸이다. 움직이지 않고 어떤 방법으로도 없어지지 않는다.
    case wall
    /// 오염 고치(7장). 외계 점액이 블록 하나를 감싸 굳은 덩어리다. 움직이지 않는다.
    /// 바로 옆에서 고치에 갇힌 것과 같은 종류의 블록을 맞춰야 터진다. 다른 종류의 매치로는 터지지 않는다.
    /// 특수 효과가 닿아도 터진다.
    case cocoon(BlockKind)
    /// 잔해 더미(7장). 무너진 돌과 벽돌이 쌓인 것이다. 고정돼 있지 않아서 아래가 비면 떨어진다.
    /// 스왑할 수 없고 매치에 들지 않는다. 바로 옆에서 매치하거나 특수 효과가 닿으면 치워진다.
    case rubble
    /// 포자 둥지(7장). 움직이지 않는다. 몇 턴마다 옆 칸의 블록 하나를 슬러지로 바꾼다.
    /// 옆에서 매치하거나 특수 효과가 닿으면 `hp`가 1 준다.
    case nest(hp: Int)
    /// 시한 포자가 달라붙은 블록(7장). 종류가 있어 보통 블록처럼 밀고 맞출 수 있고 떨어진다.
    /// 화면에 있는 동안 턴마다 `turns`가 1씩 줄고, 0이 되면 터져서 제자리와 옆 칸을 슬러지로 덮는다.
    /// 그 전에 매치하거나 특수 효과로 없애면 아무 일도 없다.
    case timed(BlockKind, turns: Int)
    /// 포자 알(7장). 단단한 껍데기의 알이다. 움직이지 않는다.
    /// 옆에서 매치해도 깨지지 않고, 특수 효과가 닿아야 깨진다.
    case egg
    /// 쇠사슬에 감긴 블록(7장). 철망이 두 겹인 셈이다. 매치에 들거나 특수 효과에 맞으면 쇠사슬만 풀려 철망에 갇힌 블록이 된다.
    case chained(BlockKind)
    /// 운석 조각(7장). 고정돼 있지 않아 떨어진다. 스왑할 수 없고, 옆 매치로는 깨지지 않으며 특수 효과로만 깨진다.
    case boulder
    /// 안개 굴뚝(7장). 움직이지 않는다. 몇 턴마다 옆 칸에 오염 안개를 뿜는다. 옆 매치나 특수 효과에 `hp`가 1 준다.
    case vent(hp: Int)
    /// 얼음 블록(7장). 블록 하나가 얼어붙은 것이다. 움직이지 않고 매치에 들지 않는다.
    /// 옆에서 매치하거나 특수 효과가 닿으면 녹아서 보통 블록이 된다.
    case frozen(BlockKind)

    public var kind: BlockKind? {
        switch self {
        case .normal(let kind), .caged(let kind), .timed(let kind, _), .chained(let kind): kind
        case .beam, .bomb, .core, .material, .concrete, .sludge, .wall, .cocoon, .rubble, .nest, .egg, .boulder, .vent, .frozen: nil
        }
    }

    public var special: Special? {
        switch self {
        case .normal, .material, .concrete, .caged, .sludge, .wall, .cocoon, .rubble, .nest, .timed, .egg, .chained, .boulder, .vent, .frozen: nil
        case .beam(let orientation): .beam(orientation)
        case .bomb: .bomb
        case .core: .core
        }
    }

    public var isSpecial: Bool {
        special != nil
    }

    /// 제자리에 고정된 칸인지. 떨어지지 않는다. 장애물은 옆 매치나 특수 효과로만 없어지고, 벽은 없어지지 않는다.
    public var isFixed: Bool {
        switch self {
        case .concrete, .sludge, .wall, .cocoon, .nest, .egg, .vent, .frozen: true
        default: false
        }
    }

    /// 스왑할 수 있는 블록인지. 장애물과 철망에 갇힌 블록은 안 된다.
    public var isSwappable: Bool {
        switch self {
        case .concrete, .caged, .sludge, .wall, .cocoon, .rubble, .nest, .egg, .chained, .boulder, .vent, .frozen: false
        default: true
        }
    }

    /// 흘러내림으로 옆 열에 미끄러져 들어갈 수 있는 블록인지.
    public var canSlide: Bool {
        switch self {
        case .normal, .beam, .bomb, .core, .timed: true
        case .material, .concrete, .caged, .sludge, .wall, .cocoon, .rubble, .nest, .egg, .chained, .boulder, .vent, .frozen: false
        }
    }

    /// 옆에서 매치하면 피해를 입는 장애물인지. 고정된 장애물과 잔해 더미다.
    public var takesAdjacentHits: Bool {
        // 포자 알은 고정돼 있지만 옆 매치로는 깨지지 않는다.
        (isFixed && self != .egg) || self == .rubble
    }

    /// 시한 포자를 뗀 블록. 시한 포자가 없으면 그대로다.
    public var withoutTimer: Block {
        if case .timed(let kind, _) = self { return .normal(kind) }
        return self
    }

    /// 어떤 효과로도 없어지지 않는 칸인지. 오염 물질과 벽이다.
    public var isIndestructible: Bool {
        self == .material || self == .wall
    }

    /// 특수 블록. 종류가 없다.
    public init(special: Special) {
        switch special {
        case .beam(let orientation): self = .beam(orientation)
        case .bomb: self = .bomb
        case .core: self = .core
        }
    }
}

/// 보드의 한 칸. 행 0이 보드 맨 위다(9장).
public struct Position: Hashable, Sendable, Codable, Comparable {
    public var column: Int
    public var row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    /// 위에서 아래로, 같은 행에서는 왼쪽에서 오른쪽으로 정렬한다.
    public static func < (lhs: Position, rhs: Position) -> Bool {
        (lhs.row, lhs.column) < (rhs.row, rhs.column)
    }
}

/// 두 칸의 블록을 교환하는 입력.
public struct Swap: Hashable, Sendable, Codable {
    public var from: Position
    public var to: Position

    public init(from: Position, to: Position) {
        self.from = from
        self.to = to
    }

    /// 두 칸이 상하좌우로 붙어 있는지.
    public var isAdjacent: Bool {
        abs(from.column - to.column) + abs(from.row - to.row) == 1
    }
}
