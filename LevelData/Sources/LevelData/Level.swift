import Foundation
import GameCore

/// JSON 파일 하나로 정의한 레벨(9장).
public struct Level: Hashable, Sendable, Codable, Identifiable {
    public var id: String
    public var city: String
    public var columns: Int
    public var rows: Int
    public var blockTypes: Int
    public var moves: Int
    public var seed: UInt64
    /// 이 레벨에서 처음 나오는 규칙의 설명. 레벨을 처음 시작할 때 보여준다. 없으면 `nil`이다.
    public var tutorial: String?
    public var materials: [Material]
    public var pendingMaterials: [Pending]
    public var obstacles: [ObstacleEntry]
    /// 별 2개와 별 3개를 받는 점수. 별 1개는 클리어하면 받는다.
    public var starScores: [Int]
    /// 이 레벨을 처음 클리어하면 받는 시작 부스터(6장).
    public var rewards: [Booster]
    /// 수거함이 놓인 열. 없으면 보드 폭 전체다(5장).
    public var container: ContainerRange?
    /// 물질이 대각선 아래의 빈칸으로 흘러가는지(5장). 기본 규칙이라 생략하면 켜진다.
    public var materialsSlide: Bool

    /// 수거함이 차지하는 열. `from`부터 `to`까지다.
    public struct ContainerRange: Hashable, Sendable, Codable {
        public var from: Int
        public var to: Int

        public init(from: Int, to: Int) {
            self.from = from
            self.to = to
        }
    }

    /// 보드에 놓인 채 시작하는 물질. `column`, `row`는 왼쪽 위 칸이다.
    public struct Material: Hashable, Sendable, Codable {
        public var column: Int
        public var row: Int
        public var width: Int
        public var height: Int

        public init(column: Int, row: Int, width: Int = 1, height: Int = 1) {
            self.column = column
            self.row = row
            self.width = width
            self.height = height
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            column = try container.decode(Int.self, forKey: .column)
            row = try container.decode(Int.self, forKey: .row)
            // 생략하면 1×1이다.
            width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1
            height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1
        }
    }

    /// 화면 위에서 대기하는 물질. `depth`는 그 열에 물질보다 먼저 들어올 블록의 수다.
    public struct Pending: Hashable, Sendable, Codable {
        public var column: Int
        public var depth: Int

        public init(column: Int, depth: Int) {
            self.column = column
            self.depth = depth
        }
    }

    /// 시한 포자의 턴을 적지 않았을 때의 값과, 적을 수 있는 범위.
    public static let defaultTimerTurns = 8
    public static let timerTurnRange = 3...20

    /// 장애물. `type`은 `concrete`, `cage`, `sludge`, `wall`, `cocoon`, `rubble`, `nest`, `timer`, `fog`, `sticky`, `egg`, `chain`, `shield`, `boulder`, `vent`, `ice` 가운데 하나다.
    /// `hp`는 콘크리트와 포자 둥지에만 쓴다. 적지 않으면 콘크리트는 1, 둥지는 2다.
    /// `wall`은 없어지지 않는 벽으로, 보드의 모양을 만든다.
    public struct ObstacleEntry: Hashable, Sendable, Codable {
        public var type: String
        public var column: Int
        public var row: Int
        public var hp: Int?
        /// 오염 고치에 갇힌 블록의 종류(`brick`, `scrap` 등). `lock`에만 쓴다.
        public var kind: String?
        /// 시한 포자가 터지기까지의 턴. `timer`에만 쓴다. 적지 않으면 `defaultTimerTurns`다.
        public var turns: Int?

        public init(type: String, column: Int, row: Int, hp: Int? = nil, kind: String? = nil, turns: Int? = nil) {
            self.turns = turns
            self.type = type
            self.column = column
            self.row = row
            self.hp = hp
            self.kind = kind
        }
    }

    public init(
        id: String,
        city: String,
        columns: Int = GameConstants.columns,
        rows: Int,
        blockTypes: Int = GameConstants.blockTypes,
        moves: Int,
        seed: UInt64,
        tutorial: String? = nil,
        materials: [Material],
        pendingMaterials: [Pending] = [],
        obstacles: [ObstacleEntry] = [],
        starScores: [Int],
        container: ContainerRange? = nil,
        materialsSlide: Bool = true,
        rewards: [Booster] = []
    ) {
        self.id = id
        self.city = city
        self.columns = columns
        self.rows = rows
        self.blockTypes = blockTypes
        self.moves = moves
        self.seed = seed
        self.tutorial = tutorial
        self.materials = materials
        self.pendingMaterials = pendingMaterials
        self.obstacles = obstacles
        self.starScores = starScores
        self.container = container
        self.materialsSlide = materialsSlide
        self.rewards = rewards
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        city = try container.decode(String.self, forKey: .city)
        columns = try container.decode(Int.self, forKey: .columns)
        rows = try container.decode(Int.self, forKey: .rows)
        blockTypes = try container.decode(Int.self, forKey: .blockTypes)
        moves = try container.decode(Int.self, forKey: .moves)
        seed = try container.decode(UInt64.self, forKey: .seed)
        tutorial = try container.decodeIfPresent(String.self, forKey: .tutorial)
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        pendingMaterials = try container.decodeIfPresent([Pending].self, forKey: .pendingMaterials) ?? []
        obstacles = try container.decodeIfPresent([ObstacleEntry].self, forKey: .obstacles) ?? []
        starScores = try container.decode([Int].self, forKey: .starScores)
        self.container = try container.decodeIfPresent(ContainerRange.self, forKey: .container)
        // 물질이 흘러가는 것은 기본 규칙이다. 끄려면 레벨에 `false`를 적는다.
        materialsSlide = try container.decodeIfPresent(Bool.self, forKey: .materialsSlide) ?? true
        rewards = try container.decodeIfPresent([Booster].self, forKey: .rewards) ?? []
    }
}

/// 레벨 데이터가 잘못된 이유.
public enum LevelError: Error, Hashable, Sendable {
    /// 가로 칸 수가 8이 아니다.
    case invalidColumns(Int)
    /// 세로 행 수가 12~40을 벗어났다.
    case invalidRows(Int)
    /// 블록 종류 수가 4~6을 벗어났다.
    case invalidBlockTypes(Int)
    /// 이동 횟수가 0 이하다.
    case invalidMoves(Int)
    /// 물질 수(대기 포함)가 1~4를 벗어났다.
    case invalidMaterialCount(Int)
    /// 물질의 크기가 1보다 작다.
    case invalidMaterialSize(column: Int, row: Int)
    /// 좌표가 보드를 벗어났다.
    case outOfBounds(column: Int, row: Int)
    /// 물질이 첫 활성 구간 밖에서 시작한다.
    case materialBelowStartZone(column: Int, row: Int)
    /// 두 항목이 같은 칸을 차지한다.
    case overlap(column: Int, row: Int)
    /// 대기 물질의 열이나 깊이가 잘못됐다.
    case invalidPending(column: Int, depth: Int)
    /// 모르는 장애물 종류다.
    case unknownObstacle(String)
    /// 콘크리트의 hp가 1~2를 벗어났다.
    case invalidHP(Int)
    /// 시한 포자의 턴이 범위를 벗어났다.
    case invalidTimerTurns(Int)
    /// 별 점수 기준이 3개가 아니거나 오름차순이 아니다.
    case invalidStarScores
    /// 오염 고치의 종류가 없거나, 이 레벨에 나오지 않는 종류다. 그런 고치는 터뜨릴 수 없다.
    case invalidCocoonKind(column: Int, row: Int)
    /// 벽에 가려 블록이 들어올 수 없는 칸이 있다. 그 칸은 판이 끝날 때까지 비어 있게 된다.
    case unreachableCell(column: Int, row: Int)
    /// 수거함의 열이 보드를 벗어났거나 순서가 뒤집혔다.
    case invalidContainer
    /// 수거함이 좁은데 물질이 흘러가지 않거나 큰 물질이 있다. 그런 물질은 수거함까지 갈 수 없다.
    case narrowContainerNeedsFlowingMaterials
    /// 수거함이 좁은데 맨 아래 행의 수거함 밖 칸이 벽이 아니다. 물질이 그 칸에 갇힌다.
    case openFloorOutsideContainer(column: Int)
}

extension Level {
    public static let rowRange = 12...40
    public static let materialCountRange = 1...4

    /// 범위를 벗어난 좌표, 겹친 칸, 0 이하의 이동 횟수 같은 잘못된 데이터를 거부한다.
    public func validate() throws(LevelError) {
        guard columns == GameConstants.columns else { throw .invalidColumns(columns) }
        guard Self.rowRange.contains(rows) else { throw .invalidRows(rows) }
        guard GameConstants.blockTypeRange.contains(blockTypes) else { throw .invalidBlockTypes(blockTypes) }
        guard moves > 0 else { throw .invalidMoves(moves) }
        let materialCount = materials.count + pendingMaterials.count
        guard Self.materialCountRange.contains(materialCount) else { throw .invalidMaterialCount(materialCount) }

        var occupied: Set<Position> = []
        func claim(column: Int, row: Int) throws(LevelError) {
            guard (0..<columns).contains(column), (0..<rows).contains(row) else {
                throw .outOfBounds(column: column, row: row)
            }
            guard occupied.insert(Position(column: column, row: row)).inserted else {
                throw .overlap(column: column, row: row)
            }
        }

        for material in materials {
            guard material.width >= 1, material.height >= 1 else {
                throw .invalidMaterialSize(column: material.column, row: material.row)
            }
            for row in material.row..<(material.row + material.height) {
                for column in material.column..<(material.column + material.width) {
                    try claim(column: column, row: row)
                }
            }
            // 물질은 화면에 보이는 첫 구간 안에서 시작해야 카메라가 따라갈 수 있다.
            guard material.row + material.height <= GameConstants.activeRows else {
                throw .materialBelowStartZone(column: material.column, row: material.row)
            }
        }
        for pending in pendingMaterials {
            guard (0..<columns).contains(pending.column), pending.depth >= 0 else {
                throw .invalidPending(column: pending.column, depth: pending.depth)
            }
        }
        for obstacle in obstacles {
            switch obstacle.type {
            case "concrete":
                let hp = obstacle.hp ?? 1
                guard (1...2).contains(hp) else { throw .invalidHP(hp) }
            case "nest", "vent":
                let hp = obstacle.hp ?? 2
                guard (1...2).contains(hp) else { throw .invalidHP(hp) }
            case "timer":
                let turns = obstacle.turns ?? Self.defaultTimerTurns
                guard Self.timerTurnRange.contains(turns) else { throw .invalidTimerTurns(turns) }
            case "cage", "sludge", "wall", "rubble", "fog", "sticky", "egg", "chain", "shield", "boulder", "ice":
                break
            case "cocoon":
                // 보충되는 블록은 앞쪽 종류부터 쓰므로, 그 안에 든 종류여야 맞출 수 있다.
                let kinds = BlockKind.allCases.prefix(blockTypes)
                guard let kind = obstacle.kind.flatMap(BlockKind.init(name:)), kinds.contains(kind) else {
                    throw .invalidCocoonKind(column: obstacle.column, row: obstacle.row)
                }
            default:
                throw .unknownObstacle(obstacle.type)
            }
            try claim(column: obstacle.column, row: obstacle.row)
        }
        guard starScores.count == 2, starScores[0] < starScores[1], starScores.allSatisfy({ $0 > 0 }) else {
            throw .invalidStarScores
        }
        // 블록은 위에서 떨어지거나 대각선 위에서 미끄러져 들어온다. 벽 아래의 넓고 평평한 그늘에는
        // 어느 쪽으로도 닿지 않아 빈칸이 남는다. 그런 칸이 생기지 않게 벽의 밑면을 비스듬히 채워야 한다.
        let walls = Set(obstacles.filter { $0.type == "wall" }.map { Position(column: $0.column, row: $0.row) })
        if !walls.isEmpty {
            var reachable: Set<Position> = []
            for row in 0..<rows {
                for column in 0..<columns {
                    let cell = Position(column: column, row: row)
                    guard !walls.contains(cell) else { continue }
                    let fromAbove = [0, -1, 1].contains { reachable.contains(Position(column: column + $0, row: row - 1)) }
                    guard row == 0 || fromAbove else { throw .unreachableCell(column: column, row: row) }
                    reachable.insert(cell)
                }
            }
        }
        if let container {
            guard container.from >= 0, container.to < columns, container.from <= container.to else {
                throw .invalidContainer
            }
            // 폭 전체가 아니면 물질이 옆으로 움직일 수 있어야 하고, 큰 물질은 흘러가지 못하므로 쓸 수 없다.
            if container.from > 0 || container.to < columns - 1 {
                guard materialsSlide, materials.allSatisfy({ $0.width == 1 && $0.height == 1 }) else {
                    throw .narrowContainerNeedsFlowingMaterials
                }
                let walls = Set(obstacles.filter { $0.type == "wall" && $0.row == rows - 1 }.map(\.column))
                for column in 0..<columns where !(container.from...container.to).contains(column) {
                    guard walls.contains(column) else { throw .openFloorOutsideContainer(column: column) }
                }
            }
        }
    }

    /// 클리어한 판의 점수로 별 수를 정한다(6장).
    /// 클리어하면 1개이고, 별 2개와 별 3개의 기준 점수를 넘길 때마다 하나씩 는다.
    public func stars(forScore score: Int) -> Int {
        1 + starScores.count { score >= $0 }
    }

    /// 이 레벨의 시작 상태를 만든다. 같은 레벨은 항상 같은 보드로 시작한다.
    ///
    public func makeState() throws(LevelError) -> GameState {
        try validate()
        return GameState(
            seed: seed,
            columns: columns,
            rows: rows,
            blockTypes: blockTypes,
            moves: moves,
            pendingMaterials: pendingMaterials.map { PendingMaterial(column: $0.column, depth: $0.depth) },
            materialPieces: materials.map {
                MaterialPiece(
                    origin: Position(column: $0.column, row: $0.row),
                    width: $0.width,
                    height: $0.height
                )
            },
            obstacles: obstacles.map { entry in
                let kind: ObstacleKind = switch entry.type {
                case "cage": .cage
                case "sludge": .sludge
                case "wall": .wall
                case "rubble": .rubble
                case "nest": .nest(hp: entry.hp ?? 2)
                case "timer": .timer(turns: entry.turns ?? Self.defaultTimerTurns)
                case "fog": .fog
                case "sticky": .sticky
                case "egg": .egg
                case "chain": .chain
                case "shield": .shield
                case "boulder": .boulder
                case "vent": .vent(hp: entry.hp ?? 2)
                case "ice": .ice
                case "cocoon": .cocoon(entry.kind.flatMap(BlockKind.init(name:)) ?? .brick)
                default: .concrete(hp: entry.hp ?? 1)
                }
                return Obstacle(kind: kind, position: Position(column: entry.column, row: entry.row))
            },
            blocksSlide: true,
            containerColumns: container.map { $0.from...$0.to },
            materialsSlide: materialsSlide
        )
    }
}
