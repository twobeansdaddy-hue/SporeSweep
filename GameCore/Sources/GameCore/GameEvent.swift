import Foundation

/// 보충으로 새로 들어온 블록. 대기하던 오염 물질이 들어올 때는 `block`이 `.material`이다.
public struct Spawn: Hashable, Sendable, Codable {
    /// 블록이 최종적으로 놓인 칸. 화면에서는 같은 열의 맨 위 바깥에서 들어온다.
    public var position: Position
    public var block: Block

    public init(position: Position, block: Block) {
        self.position = position
        self.block = block
    }

    public init(position: Position, kind: BlockKind) {
        self.init(position: position, block: .normal(kind))
    }
}

/// 화면 위에서 대기하는 오염 물질.
///
/// 열의 보충 대기열에 끼어 있다. 그 열에 일반 블록이 `depth`개 들어온 뒤, 다음 차례에 물질이 들어온다.
public struct PendingMaterial: Hashable, Sendable, Codable {
    public var column: Int
    /// 물질보다 먼저 들어올 블록의 수. 0이면 그 열의 다음 보충이 물질이다.
    public var depth: Int

    public init(column: Int, depth: Int) {
        self.column = column
        self.depth = depth
    }
}

/// 특수 블록이 내는 효과. 앞의 셋은 블록 하나가 발동한 것이고 나머지는 스왑 조합이다(4장).
public enum SpecialEffect: Hashable, Sendable, Codable {
    /// 제염 빔: 발동한 칸의 가로줄 또는 세로줄 전체.
    case beam(Orientation)
    /// 중화 폭탄: 주변 3×3.
    case bomb
    /// 정화 코어: 해당 종류 전부. 보드에 종류가 있는 블록이 없으면 `nil`이다.
    case core(BlockKind?)
    /// 제염 빔 + 제염 빔: 가로줄과 세로줄.
    case crossBeam
    /// 제염 빔 + 중화 폭탄: 3줄 두께의 가로줄과 세로줄.
    case wideCrossBeam
    /// 중화 폭탄 + 중화 폭탄: 주변 5×5.
    case bigBomb
    /// 정화 코어 + 제염 빔: 해당 종류를 모두 제염 빔으로 바꿔 발동.
    case coreBeam(BlockKind)
    /// 정화 코어 + 중화 폭탄: 해당 종류를 모두 중화 폭탄으로 바꿔 발동.
    case coreBomb(BlockKind)
    /// 정화 코어 + 정화 코어: 블록 전체.
    case clearBoard
    /// 청소 드론: 제자리와 상하좌우, 그리고 날아가 맞히는 목표 칸. 발동하기 전에는 목표가 `nil`이고,
    /// 발동할 때 정한다(4장). 고를 칸이 없으면 끝까지 `nil`이다.
    case drone(Position?)
    /// 청소 드론 + 청소 드론: 제자리와 상하좌우, 그리고 서로 다른 목표 셋.
    case droneSwarm([Position])
    /// 청소 드론 + 제염 빔: 제자리와 상하좌우, 그리고 목표 칸을 지나는 그 방향의 줄.
    case droneBeam(Orientation, Position?)
    /// 청소 드론 + 중화 폭탄: 제자리와 상하좌우, 그리고 목표 칸 둘레 3×3.
    case droneBomb(Position?)
    /// 정화 코어 + 청소 드론: 해당 종류를 모두 청소 드론으로 바꿔 발동.
    case coreDrone(BlockKind)
}

/// 특수 효과 한 번의 발동 기록.
public struct SpecialActivation: Hashable, Sendable, Codable {
    /// 효과가 시작된 칸.
    public var origin: Position
    public var effect: SpecialEffect
    /// 이 효과로 제거된 칸. 같은 단계에서 먼저 제거된 칸은 들어 있지 않다.
    public var cleared: [Position]

    public init(origin: Position, effect: SpecialEffect, cleared: [Position]) {
        self.origin = origin
        self.effect = effect
        self.cleared = cleared
    }
}

/// 특수 블록이 놓인 기록.
public struct SpecialSpawn: Hashable, Sendable, Codable {
    public var position: Position
    public var block: Block

    public init(position: Position, block: Block) {
        self.position = position
        self.block = block
    }
}

/// 장애물이 피해를 입은 기록.
public struct ObstacleHit: Hashable, Sendable, Codable {
    public var position: Position
    /// 피해를 입은 뒤 그 칸에 남은 것. 없어졌으면 `nil`이다.
    public var remaining: Block?

    public init(position: Position, remaining: Block?) {
        self.position = position
        self.remaining = remaining
    }
}

/// 레벨에 놓는 장애물의 종류(7장).
public enum ObstacleKind: Hashable, Sendable, Codable {
    /// 콘크리트. `hp`는 없애는 데 필요한 횟수다. 강화형은 2다.
    case concrete(hp: Int)
    /// 철망. 그 칸의 블록을 가둔다.
    case cage
    /// 오염 슬러지.
    case sludge
    /// 벽. 없어지지 않는다.
    case wall
    /// 오염 고치. 옆에서 이 종류의 블록을 맞춰야 터진다.
    case cocoon(BlockKind)
    /// 잔해 더미. 아래가 비면 떨어진다.
    case rubble
    /// 포자 둥지. 몇 턴마다 옆 칸을 슬러지로 바꾼다. `hp`는 없애는 데 필요한 횟수다.
    case nest(hp: Int)
    /// 시한 포자. 그 칸의 블록에 달라붙는다. `turns`는 터지기까지 남은 턴이다.
    case timer(turns: Int)
    /// 오염 안개. 그 칸의 블록을 가린다. 칸에 붙어 있고 블록은 그대로 생긴다.
    case fog
    /// 끈끈이 바닥. 그 칸의 블록을 밀 수 없게 한다. 칸에 붙어 있고 블록은 그대로 생긴다.
    case sticky
    /// 포자 알. 특수 효과로만 깨진다.
    case egg
    /// 쇠사슬. 그 칸의 블록을 두 겹으로 가둔다.
    case chain
    /// 포자 보호막. 그 칸의 블록을 특수 효과에서 지킨다. 칸에 붙어 있다.
    case shield
    /// 운석 조각. 떨어지고, 특수 효과로만 깨진다.
    case boulder
    /// 안개 굴뚝. 몇 턴마다 옆 칸에 안개를 뿜는다.
    case vent(hp: Int)
    /// 얼음. 그 칸의 블록을 얼린다.
    case ice
}

/// 포자 둥지 하나가 슬러지를 뱉은 일.
public struct NestSpit: Hashable, Sendable, Codable {
    /// 둥지의 자리.
    public var nest: Position
    /// 슬러지가 된 칸.
    public var target: Position

    public init(nest: Position, target: Position) {
        self.nest = nest
        self.target = target
    }
}

/// 시한 포자 하나의 숫자가 준 일.
public struct TimerTick: Hashable, Sendable, Codable {
    public var position: Position
    /// 줄어든 뒤의 숫자.
    public var turns: Int

    public init(position: Position, turns: Int) {
        self.position = position
        self.turns = turns
    }
}

/// 시한 포자 하나가 터진 일.
public struct TimerBurst: Hashable, Sendable, Codable {
    /// 포자가 있던 칸.
    public var position: Position
    /// 슬러지가 된 칸. 포자가 있던 칸도 든다.
    public var sludge: [Position]

    public init(position: Position, sludge: [Position]) {
        self.position = position
        self.sludge = sludge
    }
}

/// 레벨에 놓는 장애물 하나.
public struct Obstacle: Hashable, Sendable, Codable {
    public var kind: ObstacleKind
    public var position: Position

    public init(kind: ObstacleKind, position: Position) {
        self.kind = kind
        self.position = position
    }
}

/// 한 턴 동안 일어난 일. 화면은 이 목록을 순서대로 재생한다(10장).
public enum GameEvent: Hashable, Sendable, Codable {
    /// 두 블록이 자리를 바꿨다.
    case swapped(Swap)
    /// 스왑이 거부됐다. 블록은 제자리로 돌아가고 보드는 변하지 않는다.
    case swapRejected(Swap, SwapRejection)
    /// 매치가 제거됐다. `chain`은 스왑 직후의 매치가 1이고 연쇄마다 1씩 오른다.
    case matchesCleared([Match], chain: Int)
    /// 특수 효과가 발동해 칸이 제거됐다. 배열 순서가 발동 순서다.
    case specialsActivated([SpecialActivation])
    /// 특수 블록이 생겼다. 그 칸에 있던 블록은 이 블록으로 바뀐다.
    case specialsCreated([SpecialSpawn])
    /// 빈칸 위의 블록이 떨어졌다.
    case fell([BlockMove])
    /// 위가 막혀 채워지지 않는 빈칸으로 옆 열의 블록이 대각선으로 미끄러져 내려왔다.
    /// 흘러내림을 켠 판에서만 나온다.
    case slid([BlockMove])
    /// 새 블록이 활성 구간의 맨 위에서 들어왔다. 대기하던 물질도 여기에 섞여 들어온다.
    case refilled([Spawn])
    /// 가능한 이동이 없어 블록을 다시 섞었다.
    case shuffled([BlockMove])
    /// 섞어도 유효한 배치가 나오지 않아 활성 구간의 일반 블록을 새로 만들었다.
    case regenerated([Spawn])
    /// 콘크리트나 슬러지가 옆 매치 또는 특수 효과에 맞았거나, 철망이 벗겨졌다.
    /// 철망이 벗겨진 칸에는 안에 있던 블록이 일반 블록으로 남는다.
    case obstaclesDamaged([ObstacleHit])
    /// 슬러지를 하나도 제거하지 못한 턴이라 슬러지가 옆 칸의 블록을 덮었다.
    case sludgeSpread([Position])
    /// 포자 둥지가 옆 칸의 블록을 슬러지로 바꿨다. 둥지마다 한 칸씩이다.
    case nestsSpat([NestSpit])
    /// 시한 포자의 숫자가 줄었다. 0이 된 것은 여기에 없고 `timersBurst`로 나온다.
    case timersTicked([TimerTick])
    /// 시한 포자가 터져서 제자리와 옆 칸이 슬러지가 됐다.
    case timersBurst([TimerBurst])
    /// 옆에서 매치했거나 특수 효과가 닿아 안개가 걷혔다.
    case fogLifted([Position])
    /// 끈끈이 바닥 위의 블록이 매치됐거나 특수 효과에 맞아 끈끈이가 없어졌다.
    case stickyCleared([Position])
    /// 보호막 안의 블록이 매치돼 보호막이 깨졌다.
    case shieldsBroken([Position])
    /// 안개 굴뚝이 옆 칸에 안개를 뿜었다. 값은 새로 안개가 낀 칸이다.
    case ventsPuffed([Position])
    /// 정화 망치가 블록 하나를 부쉈다. 장애물을 때렸으면 이 이벤트 대신 `obstaclesDamaged`가 나온다.
    case hammered(Position)
    /// 오염 물질이 보드의 마지막 행에 닿아 격리 컨테이너로 들어갔다.
    case materialsCollected([Position])
    /// 카메라가 내려갔다. 값은 활성 구간 맨 위 행이다. `to`보다 위의 행은 버려진다.
    case scrolled(from: Int, to: Int)
    /// 모든 물질을 수거했다.
    case won
    /// 물질을 남긴 채 이동 횟수가 다 떨어졌다. 섞어도 가능한 이동을 만들 수 없을 때도 실패다.
    case lost
}

/// 턴 처리 결과.
public struct TurnResult: Hashable, Sendable, Codable {
    public var state: GameState
    public var events: [GameEvent]

    public init(state: GameState, events: [GameEvent]) {
        self.state = state
        self.events = events
    }
}
