import Foundation
import GameCore
import LevelData

/// 레벨 생성기(9장). 난이도 값에 따라 판을 만들고, 봇으로 재서 이동 횟수와 별 기준을 정한다.
///
/// 만든 판이 설계 규칙에 어긋나거나(벽 밑의 닿지 않는 칸 등) 봇이 잘 깨지 못하면 버리고 다시 만든다.
/// 같은 설정은 늘 같은 레벨을 만든다.
public enum LevelGenerator {
    /// 레벨에 넣을 수 있는 요소. 도시가 넘어갈 때마다 하나씩 풀어 준다.
    public enum Feature: String, CaseIterable, Sendable {
        /// 콘크리트.
        case concrete
        /// 강화 콘크리트(두 번 부숴야 한다). `concrete`가 있어야 나온다.
        case reinforced
        /// 철망.
        case cage
        /// 오염 슬러지.
        case sludge
        /// 벽으로 만든 비탈과 기둥.
        case wall
        /// 화면 위에서 대기하는 물질.
        case pending
        /// 가로 2칸 물질.
        case wide
        /// 2×2 물질.
        case big
        /// 잔해 더미. 아래가 비면 떨어진다.
        case rubble
        /// 오염 고치. 옆에서 갇힌 것과 같은 종류를 맞춰야 터진다.
        case cocoon
        /// 포자 둥지. 몇 턴마다 옆 칸을 슬러지로 바꾼다.
        case nest
        /// 시한 포자. 숫자가 0이 되기 전에 그 블록을 없애야 한다.
        case timer
        /// 오염 안개. 그 칸의 블록이 보이지 않는다.
        case fog
        /// 끈끈이 바닥. 그 칸의 블록을 밀 수 없다.
        case sticky
        /// 포자 알. 특수 효과로만 깨진다.
        case egg
        /// 쇠사슬. 두 번 맞춰야 풀리는 철망이다.
        case chain
        /// 포자 보호막. 그 칸의 블록은 특수 효과에 지워지지 않는다.
        case shield
        /// 운석 조각. 떨어지고, 특수 효과로만 깨진다.
        case boulder
        /// 안개 굴뚝. 몇 턴마다 안개를 뿜는다.
        case vent
        /// 얼음 블록. 옆에서 맞추면 녹는다.
        case ice
    }

    public struct Options: Sendable {
        /// 도시 ID. 레벨 ID는 `도시-번호`다.
        public var city: String
        public var count: Int
        /// 첫 레벨의 번호.
        public var firstNumber: Int
        /// 첫 레벨과 마지막 레벨의 난이도(0...1). 그 사이는 고르게 올라간다.
        public var difficulty: ClosedRange<Double>
        public var features: Set<Feature>
        public var seed: UInt64
        /// 레벨 하나를 잴 때 봇이 두는 판 수.
        public var playouts: Int
        /// 이 도시에서 처음 나오는 장애물의 종류(`lock` 등). 첫 레벨에 반드시 넣고, 다른 레벨에도 자주 넣는다.
        public var spotlight: String?
        /// 장애물의 종류 → 그 장애물이 처음 나오는 레벨에 붙일 설명.
        public var tutorials: [String: String] = [:]

        public init(
            city: String, count: Int, firstNumber: Int = 1, difficulty: ClosedRange<Double> = 0.2...0.6,
            features: Set<Feature> = Set(Feature.allCases), seed: UInt64 = 1, playouts: Int = 120
        ) {
            self.city = city
            self.count = count
            self.firstNumber = firstNumber
            self.difficulty = difficulty
            self.features = features
            self.seed = seed
            self.playouts = playouts
        }
    }

    /// 만든 레벨 하나와 잰 결과.
    public struct Result: Sendable {
        public var level: Level
        public var calibration: Calibration
        /// 이 레벨에 쓴 구성의 이름.
        public var patterns: [String]
        /// 받아들일 때까지 만든 횟수.
        public var attempts: Int
    }

    /// 봇이 이만큼은 깨야 받아들인다.
    public static let minimumClearRate = 0.6
    /// 한 레벨에 다시 만들어 보는 횟수의 상한.
    static let maximumAttempts = 24

    public static func generate(_ options: Options) -> [Result] {
        var results: [Result] = (0..<options.count).map { index in
            let fraction = options.count > 1 ? Double(index) / Double(options.count - 1) : 0
            let difficulty = options.difficulty.lowerBound
                + (options.difficulty.upperBound - options.difficulty.lowerBound) * fraction
            return make(
                number: options.firstNumber + index, isLast: index == options.count - 1,
                difficulty: difficulty, options: options, isFirst: index == 0
            )
        }
        // 장애물이 처음 나오는 레벨에 설명을 붙인다.
        for (type, text) in options.tutorials.sorted(by: { $0.key < $1.key }) {
            func introduces(_ result: Result) -> Bool {
                result.level.tutorial == nil && result.level.obstacles.contains { $0.type == type }
            }
            if let index = results.firstIndex(where: introduces) {
                results[index].level.tutorial = text
            }
        }
        return results
    }

    private static func make(number: Int, isLast: Bool, difficulty: Double, options: Options, isFirst: Bool) -> Result {
        var best: Result?
        for attempt in 0..<maximumAttempts {
            // 계속 버려지면 난이도를 조금씩 낮춰 만든다.
            let eased = max(difficulty - Double(attempt / 6) * 0.12, 0)
            let seed = options.seed &* 100_003 &+ UInt64(number) &* 1009 &+ UInt64(attempt) &* 7919
            var random = SeededGenerator(seed: seed)
            var (level, patterns) = draft(
                id: String(format: "%@-%03d", options.city, number), city: options.city,
                difficulty: eased, features: options.features, seed: seed,
                spotlight: options.spotlight, forcesSpotlight: isFirst, random: &random
            )
            guard (try? level.validate()) != nil,
                  let calibration = Calibration.measure(level, playouts: options.playouts)
            else { continue }
            level.moves = calibration.moves
            level.starScores = calibration.starScores
            level.rewards = rewards(number: number, isLast: isLast)
            let result = Result(level: level, calibration: calibration, patterns: patterns, attempts: attempt + 1)
            // 정해진 이동 횟수 안에 충분히 깨지는 판만 받아들인다.
            if calibration.clearRate >= minimumClearRate, calibration.wantedMoves <= Calibration.moveRange.upperBound {
                return result
            }
            // 받아들일 판이 끝내 안 나오면 가장 잘 깨진 판을 쓴다.
            if best == nil || calibration.clearRate > best!.calibration.clearRate {
                best = result
            }
        }
        guard let best else {
            preconditionFailure("\(options.city)-\(number): 쓸 수 있는 판을 하나도 만들지 못했다")
        }
        return best
    }

    /// 다섯 레벨마다 부스터 하나를, 마지막 레벨에서는 네 가지를 모두 준다.
    private static func rewards(number: Int, isLast: Bool) -> [Booster] {
        if isLast { return Booster.allCases }
        guard number.isMultiple(of: 5) else { return [] }
        return [Booster.allCases[(number / 5) % Booster.allCases.count]]
    }

    // MARK: - 판 만들기

    /// 난이도에 맞는 판 하나를 만든다. 이동 횟수와 별 기준은 재기 전이라 임시 값이다.
    private static func draft(
        id: String, city: String, difficulty: Double, features: Set<Feature>, seed: UInt64,
        spotlight: String?, forcesSpotlight: Bool, random: inout SeededGenerator
    ) -> (Level, [String]) {
        func chance(_ probability: Double, _ random: inout SeededGenerator) -> Bool {
            Double(random.nextInt(below: 1000)) < probability * 1000
        }
        let columns = GameConstants.columns
        // 길이는 난이도를 따라 12행에서 30행까지 늘어난다.
        let rows = min(12 + Int((difficulty * 18).rounded()) + random.nextInt(below: 3), 30)
        var patterns: [String] = []
        var materials: [Level.Material] = []
        var pending: [Level.Pending] = []
        var obstacles: [Level.ObstacleEntry] = []
        var taken: Set<Position> = []

        // 물질. 네 판에 한 판쯤은 큰 물질 하나다.
        let largeKinds = [Feature.wide, .big].filter(features.contains)
        // 새 장애물을 보여주는 첫 레벨은 한 칸짜리 물질로 단순하게 만든다.
        let hasLarge = !largeKinds.isEmpty && !forcesSpotlight && chance(0.25, &random)
        if hasLarge {
            let kind = largeKinds[random.nextInt(below: largeKinds.count)]
            let column = 2 + random.nextInt(below: 3)
            materials.append(.init(column: column, row: 0, width: 2, height: kind == .big ? 2 : 1))
            patterns.append(kind == .big ? "2×2 물질" : "2×1 물질")
        } else {
            let count = min(1 + Int(difficulty * 2.4) + random.nextInt(below: 2), 4)
            var free = Array(0..<columns)
            for _ in 0..<count {
                materials.append(.init(column: free.remove(at: random.nextInt(below: free.count)), row: 0))
            }
            // 물질이 둘 이상이면 하나를 화면 위에서 기다리게 할 수 있다.
            if features.contains(.pending), materials.count >= 2, chance(0.3, &random) {
                let waiting = materials.removeLast()
                pending.append(.init(column: waiting.column, depth: 4 + random.nextInt(below: 7)))
                patterns.append("대기 물질")
            }
            patterns.insert("물질 \(count)개", at: 0)
        }
        for material in materials {
            for row in material.row..<(material.row + material.height) {
                for column in material.column..<(material.column + material.width) {
                    taken.insert(Position(column: column, row: row))
                }
            }
        }

        // 블록 종류는 난이도를 가장 크게 움직인다. 큰 물질은 가로 매치가 필요해서 늘 4종이다.
        let blockTypes = hasLarge || difficulty < 0.35 ? 4 : 5

        // 장애물. 위에서부터 띠를 나눠 한 띠에 구성 하나를 놓는다.
        var available: [String] = []
        if features.contains(.concrete) { available.append("concrete") }
        if features.contains(.cage) { available.append("cage") }
        if features.contains(.sludge) { available.append("sludge") }
        // 큰 물질은 흘러가지 못해 벽에 걸린다.
        if features.contains(.wall), !hasLarge { available += ["ramp", "pillar"] }
        if features.contains(.cocoon) { available.append("cocoon") }
        if features.contains(.rubble) { available.append("rubble") }
        if features.contains(.nest) { available.append("nest") }
        if features.contains(.timer) { available.append("timer") }
        if features.contains(.fog) { available.append("fog") }
        if features.contains(.sticky) { available.append("sticky") }
        if features.contains(.egg) { available.append("egg") }
        if features.contains(.chain) { available.append("chain") }
        if features.contains(.shield) { available.append("shield") }
        if features.contains(.boulder) { available.append("boulder") }
        if features.contains(.vent) { available.append("vent") }
        if features.contains(.ice) { available.append("ice") }
        // 이 도시의 새 장애물은 두 배로 자주 나온다.
        if let spotlight, available.contains(spotlight) { available.append(spotlight) }
        var wanted = available.isEmpty ? 0 : min(Int(difficulty * 3) + random.nextInt(below: 2), 3)
        var queue: [String] = []
        if forcesSpotlight, let spotlight, available.contains(spotlight) {
            queue = [spotlight]
            wanted = 1
        }
        var cursor = 4
        func place(_ type: String, _ column: Int, _ row: Int, hp: Int? = nil, kind: String? = nil, turns: Int? = nil) {
            let position = Position(column: column, row: row)
            guard taken.insert(position).inserted else { return }
            obstacles.append(.init(type: type, column: column, row: row, hp: hp, kind: kind, turns: turns))
        }
        for _ in 0..<wanted {
            let pattern = queue.isEmpty ? available[random.nextInt(below: available.count)] : queue.removeFirst()
            switch pattern {
            case "chain":
                guard cursor + 2 < rows - 2 else { continue }
                for _ in 0..<(2 + random.nextInt(below: 3)) {
                    place("chain", random.nextInt(below: columns), cursor + random.nextInt(below: 2))
                }
                patterns.append("쇠사슬")
                cursor += 4
            case "shield":
                guard cursor + 2 < rows - 2 else { continue }
                // 두 줄 높이의 띠. 특수 블록으로 한 번에 밀어 버릴 수 없는 구간이 된다.
                let width = 3 + Int(difficulty * 2) + random.nextInt(below: 2)
                let start = random.nextInt(below: max(columns - width, 0) + 1)
                for row in cursor..<(cursor + 2) {
                    for column in start..<min(start + width, columns) {
                        place("shield", column, row)
                    }
                }
                patterns.append("포자 보호막")
                cursor += 3
            case "boulder":
                guard cursor + 2 < rows - 2 else { continue }
                // 떨어지는 장애물이고 매치로는 못 깨므로 두세 개만 흩어 놓는다.
                for _ in 0..<(2 + random.nextInt(below: 2)) {
                    place("boulder", random.nextInt(below: columns), cursor + random.nextInt(below: 3))
                }
                patterns.append("운석 조각")
                cursor += 4
            case "vent":
                guard cursor + 1 < rows - 2 else { continue }
                let first = random.nextInt(below: columns)
                place("vent", first, cursor)
                if difficulty > 0.6, chance(0.5, &random) {
                    place("vent", (first + 3 + random.nextInt(below: 2)) % columns, cursor + 1)
                }
                patterns.append("안개 굴뚝")
                cursor += 4
            case "ice":
                guard cursor + 2 < rows - 2 else { continue }
                // 두 줄에 띄엄띄엄 놓는다. 옆에서 맞추면 녹으므로 길을 오래 막지는 않는다.
                for _ in 0..<(3 + random.nextInt(below: 4)) {
                    place("ice", random.nextInt(below: columns), cursor + random.nextInt(below: 2))
                }
                patterns.append("얼음 블록")
                cursor += 3
            case "egg":
                guard cursor + 1 < rows - 2 else { continue }
                // 서로 떨어뜨려 두세 개만 놓는다. 매치로는 깨지지 않으므로 길을 막으면 안 된다.
                let count = 2 + (difficulty > 0.7 && chance(0.5, &random) ? 1 : 0)
                var columnsLeft = Array(stride(from: random.nextInt(below: 2), to: columns, by: 2))
                for _ in 0..<min(count, columnsLeft.count) {
                    let column = columnsLeft.remove(at: random.nextInt(below: columnsLeft.count))
                    place("egg", column, cursor + random.nextInt(below: 2))
                }
                patterns.append("포자 알")
                cursor += 4
            case "sticky":
                guard cursor + 2 < rows - 2 else { continue }
                // 한 줄씩 띄운 두 줄. 사이의 줄에서 블록을 밀어 넣어 맞출 수 있게 한다. 어려울수록 넓다.
                let width = 3 + Int(difficulty * 3) + random.nextInt(below: 2)
                let start = random.nextInt(below: max(columns - width, 0) + 1)
                for row in [cursor, cursor + 2] {
                    for column in start..<min(start + width, columns) where chance(0.8, &random) {
                        place("sticky", column, row)
                    }
                }
                patterns.append("끈끈이 바닥")
                cursor += 4
            case "fog":
                guard cursor + 2 < rows - 2 else { continue }
                // 두세 줄 높이의 안개 띠. 어려울수록 넓다. 블록은 그대로 있어 길을 막지는 않는다.
                let width = 3 + Int(difficulty * 3) + random.nextInt(below: 2)
                let height = 2 + random.nextInt(below: 2)
                let start = random.nextInt(below: max(columns - width, 0) + 1)
                for row in cursor..<(cursor + height) {
                    for column in start..<min(start + width, columns) {
                        place("fog", column, row)
                    }
                }
                patterns.append("오염 안개")
                cursor += height + 1
            case "timer":
                guard cursor + 2 < rows - 2 else { continue }
                // 두세 개를 흩어 놓는다. 어려울수록 숫자가 작다. 화면에 들어온 뒤부터 줄기 때문에 깊은 곳에 있어도 같다.
                let count = 2 + random.nextInt(below: 2)
                for _ in 0..<count {
                    let turns = 9 - Int(difficulty * 3) + random.nextInt(below: 3)
                    place("timer", random.nextInt(below: columns), cursor + random.nextInt(below: 3), turns: turns)
                }
                patterns.append("시한 포자")
                cursor += 4
            case "nest":
                guard cursor + 1 < rows - 2 else { continue }
                // 한두 개만 서로 떨어뜨려 놓는다. 슬러지를 계속 뱉으므로 많으면 판이 막힌다.
                let first = random.nextInt(below: columns)
                place("nest", first, cursor)
                if difficulty > 0.5, chance(0.5, &random) {
                    place("nest", (first + 3 + random.nextInt(below: 2)) % columns, cursor + 1)
                }
                patterns.append("포자 둥지")
                cursor += 4
            case "rubble":
                guard cursor + 2 < rows - 2 else { continue }
                // 물질이 지나갈 길 위에 흩어 놓는다. 떨어지는 장애물이라 판이 진행되면 물질 아래에 쌓인다.
                let count = 3 + random.nextInt(below: 4)
                for _ in 0..<count {
                    place("rubble", random.nextInt(below: columns), cursor + random.nextInt(below: 3))
                }
                patterns.append("잔해 더미")
                cursor += 4
            case "cocoon":
                guard cursor + 1 < rows - 2 else { continue }
                // 길을 다 막지 않게 띄엄띄엄 놓는다. 갇힌 종류는 이 레벨에 나오는 블록 가운데서 고른다.
                let count = 2 + random.nextInt(below: 3)
                var columnsLeft = Array(0..<columns)
                for _ in 0..<count {
                    let column = columnsLeft.remove(at: random.nextInt(below: columnsLeft.count))
                    let kind = BlockKind.allCases[random.nextInt(below: blockTypes)]
                    place("cocoon", column, cursor + random.nextInt(below: 2), kind: kind.name)
                }
                patterns.append("오염 고치")
                cursor += 4
            case "concrete":
                guard cursor + 1 < rows - 2 else { continue }
                // 길을 다 막지 않게 양쪽에 틈을 남긴다.
                let length = 3 + random.nextInt(below: 3)
                let start = 1 + random.nextInt(below: columns - length - 1)
                let reinforced = features.contains(.reinforced) && chance(difficulty, &random)
                for column in start..<(start + length) {
                    place("concrete", column, cursor, hp: reinforced && column.isMultiple(of: 2) ? 2 : 1)
                }
                patterns.append(reinforced ? "강화 콘크리트" : "콘크리트")
                cursor += 3
            case "cage":
                guard cursor + 2 < rows - 2 else { continue }
                for _ in 0..<(2 + random.nextInt(below: 4)) {
                    place("cage", random.nextInt(below: columns), cursor + random.nextInt(below: 2))
                }
                patterns.append("철망")
                cursor += 4
            case "sludge":
                guard cursor + 1 < rows - 2 else { continue }
                let column = random.nextInt(below: columns - 1)
                place("sludge", column, cursor)
                if chance(0.5, &random) { place("sludge", column + 1, cursor) }
                patterns.append("슬러지")
                cursor += 3
            case "ramp":
                // 한 줄에 한 칸씩 넓어졌다가 좁아지는 마름모. 밑면이 비스듬해서 그 아래에 그늘이 생기지 않는다.
                let width = 3 + random.nextInt(below: 2)
                guard cursor + width * 2 - 1 < rows - 2 else { continue }
                let fromLeft = chance(0.5, &random)
                for step in 0..<(width * 2 - 1) {
                    let reach = step < width ? step + 1 : width * 2 - 1 - step
                    for offset in 0..<reach {
                        place("wall", fromLeft ? offset : columns - 1 - offset, cursor + step)
                    }
                }
                patterns.append(fromLeft ? "왼쪽 비탈" : "오른쪽 비탈")
                cursor += width * 2 + 1
            default:
                // 가운데 기둥. 두 칸 폭이라 그 아래 칸은 양옆에서 채워진다.
                let height = 3 + random.nextInt(below: 3)
                guard cursor + height < rows - 2 else { continue }
                let column = 2 + random.nextInt(below: 3)
                for row in cursor..<(cursor + height) {
                    place("wall", column, row)
                    place("wall", column + 1, row)
                }
                patterns.append("기둥")
                cursor += height + 2
            }
        }

        let level = Level(
            id: id, city: city, columns: columns, rows: rows, blockTypes: blockTypes,
            moves: Calibration.moveRange.upperBound, seed: seed % 1_000_000_007,
            materials: materials, pendingMaterials: pending, obstacles: obstacles,
            starScores: [100, 200]
        )
        return (level, patterns)
    }

    // MARK: - 파일로 쓰기

    /// 레벨을 `도시-번호.json`으로 쓴다.
    public static func write(_ results: [Result], to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        for result in results {
            try encoder.encode(result.level)
                .write(to: directory.appendingPathComponent(result.level.id + ".json"))
        }
    }
}
