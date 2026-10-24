import SwiftUI

/// 랜드마크 그림 한 벌. 도시마다 하나씩 있다(10장).
///
/// 그림은 복원된 모습과 폐허가 된 모습 두 장이고, 각각 배경(`접두어_bg_*`), 건물만 남긴 투명 그림
/// (`접두어_building_*`), 나무만 남긴 투명 그림(`접두어_trees_*`)으로 나뉘어 있다(`Tools/split_landmark.py`).
/// 건물의 부위마다 정해 둔 영역을 복원 여부에 따라 둘 중 한 장에서 잘라 그린다.
@MainActor
struct LandmarkArt {
    /// 그림 이름의 접두어.
    var prefix: String
    /// 접근성 이름.
    var name: String
    /// 이 줄 아래가 땅이다. 그림의 세로를 0...1로 본 비율이다.
    var horizon: CGFloat
    /// 건물의 부위와 그 영역. 영역은 그림 크기를 받아 만든다. `hole`은 그 영역에서 빼는 자리다.
    var parts: [Part]
    var spores: [Spore]

    struct Part {
        var id: String
        var region: (CGSize) -> Path
        var hole: ((CGSize) -> Path)?
    }

    /// 그림 위에 붙어 있는 포자 하나. 자리는 비율이고, 크기는 가로 대비 반지름이다.
    struct Spore {
        var x: CGFloat
        var y: CGFloat
        var radius: CGFloat
        var degrees: Double
        /// 이 부위를 복원하면 터져 사라진다.
        var part: String
        /// 모양. 0은 둥근 포자이고, 1~4는 쏠린 것, 뭉친 것, 흘러내리는 것, 납작하게 퍼진 것이다(`landmark_spore_N`).
        /// 흘러내리는 모양은 아래를 향해야 하므로 거의 기울이지 않는다.
        var shape: Int
    }

    /// 어느 도시에나 있는 환경 부위. 하늘과 땅을 바꾼다.
    static let environment = ["pollution", "sky", "ground", "greenery"]

    /// 이 그림이 그릴 줄 아는 부위.
    var partIDs: Set<String> {
        Set(parts.map(\.id) + Self.environment)
    }

    static func art(for cityID: String) -> LandmarkArt? {
        switch cityID {
        case "seoul": .sungnyemun
        case "tokyo": .tokyoTower
        case "beijing": .greatWall
        case "newdelhi": .indiaGate
        case "bangkok": .watArun
        case "singapore": .marinaBaySands
        case "cairo": .giza
        case "dubai": .burjAlArab
        case "capetown": .cableway
        default: shapedCities[cityID]
        }
    }

    /// 비율로 적은 사각형.
    static func band(_ x: CGFloat, _ y: CGFloat, _ right: CGFloat, _ bottom: CGFloat) -> (CGSize) -> Path {
        { size in
            Path(CGRect(x: x * size.width, y: y * size.height, width: (right - x) * size.width, height: (bottom - y) * size.height))
        }
    }
}

/// 다 복원한 랜드마크 위에서 차례로 반짝이는 별빛.
private struct Sparkles: View {
    /// 별빛의 자리(비율), 크기(가로 대비), 박자의 어긋남.
    private static let spots: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: Double)] = [
        (0.36, 0.20, 0.050, 0.0), (0.63, 0.14, 0.060, 0.9), (0.50, 0.06, 0.045, 1.7), (0.30, 0.48, 0.040, 2.4),
        (0.70, 0.42, 0.050, 0.5), (0.44, 0.34, 0.035, 3.1), (0.58, 0.58, 0.040, 1.3), (0.22, 0.30, 0.030, 2.0),
        (0.79, 0.26, 0.035, 2.8),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                ForEach(Array(Self.spots.enumerated()), id: \.offset) { _, spot in
                    // 3초에 한 번 잠깐 커졌다가 사라진다.
                    let beat = (time / 3 + spot.phase / 3.6).truncatingRemainder(dividingBy: 1)
                    let glow = max(0, 1 - abs(beat - 0.15) / 0.15)
                    Image(systemName: "sparkle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: spot.size * geometry.size.width, height: spot.size * geometry.size.width)
                        .foregroundStyle(.white)
                        .shadow(color: Color(red: 1, green: 0.95, blue: 0.6), radius: 4)
                        .scaleEffect(0.3 + glow * 0.9)
                        .rotationEffect(.degrees(glow * 45))
                        .opacity(glow)
                        .position(x: spot.x * geometry.size.width, y: spot.y * geometry.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 도시의 랜드마크. 플레이어가 복원한 부위만 온전한 모습으로 그린다(8장).
struct LandmarkView: View {
    /// 복원한 부위의 ID.
    var restored: Set<String>
    var art: LandmarkArt = .sungnyemun

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .overlay {
            GeometryReader { geometry in
                let size = geometry.size
                // 포자는 늘 그려 두고, 딸린 부위가 복원되면 터지는 모습으로 바꾼다.
                ForEach(Array(art.spores.enumerated()), id: \.offset) { index, spore in
                    let side = spore.radius * 2.4 * size.width
                    let popped = has(spore.part)
                    Image("landmark_spore_\(spore.shape)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: side, height: side)
                        .rotationEffect(.degrees(spore.degrees))
                        .modifier(SporePop(progress: popped ? 1 : 0))
                        .position(x: spore.x * size.width, y: spore.y * size.height)
                        // 같은 부위의 포자가 한꺼번에 터지지 않게 하나씩 늦춘다.
                        .animation(.easeOut(duration: Self.popDuration).delay(Double(index % 4) * Self.popDuration * 0.36), value: popped)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay {
            // 다 복원한 랜드마크는 반짝인다.
            if art.partIDs.allSatisfy(has) {
                Sparkles()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .accessibilityElement()
        .accessibilityIdentifier("landmark_\(art.prefix)")
        .accessibilityLabel("\(art.name), \(art.partIDs.count { has($0) })개 부위 복원")
    }

    private func has(_ part: String) -> Bool {
        restored.contains(part)
    }

    /// 포자 하나가 터지는 데 걸리는 시간. 디버그 빌드에서는 실행 인자 `-sporePopDuration 초`로 늘려 볼 수 있다.
    private static let popDuration: Double = {
        #if DEBUG
        let custom = UserDefaults.standard.double(forKey: "sporePopDuration")
        if custom > 0 { return custom }
        #endif
        return 0.5
    }()

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        func rect(_ x: CGFloat, _ y: CGFloat, _ right: CGFloat, _ bottom: CGFloat) -> CGRect {
            CGRect(x: x * size.width, y: y * size.height, width: (right - x) * size.width, height: (bottom - y) * size.height)
        }
        func paint(_ name: String, clip: Path, excluding hole: Path? = nil, filters: [GraphicsContext.Filter] = []) {
            let image = context.resolve(Image("\(art.prefix)_\(name)"))
            context.drawLayer { layer in
                layer.clip(to: clip)
                if let hole {
                    layer.clip(to: hole, options: .inverse)
                }
                for filter in filters {
                    layer.addFilter(filter)
                }
                layer.draw(image, in: full)
            }
        }

        // 하늘. 오염을 걷어내면 잿빛이 되고, 맑은 하늘을 복원하면 파래진다.
        let sky = Path(rect(0, 0, 1, art.horizon))
        if has("sky") {
            paint("bg_restored", clip: sky)
        } else if has("pollution") {
            paint("bg_ruined", clip: sky, filters: [.grayscale(0.85), .brightness(0.12)])
        } else {
            paint("bg_ruined", clip: sky)
        }

        // 땅. 잔해를 치우면 맨흙이 되고, 녹지를 복원하면 잔디가 덮인다.
        let ground = Path(rect(0, art.horizon, 1, 1))
        if has("greenery") {
            paint("bg_restored", clip: ground)
        } else if has("ground") {
            // 잔디 그림의 색을 빼고 흙빛을 입힌다. 필터는 나중에 넣은 것이 먼저 적용된다.
            let soil = Color(red: 0.95, green: 0.76, blue: 0.56)
            paint("bg_restored", clip: ground, filters: [.colorMultiply(soil), .grayscale(1)])
        } else {
            paint("bg_ruined", clip: ground)
        }

        // 나무와 풀숲. 잔해를 치우기 전에는 죽은 그루터기가 서 있다.
        if has("greenery") {
            paint("trees_restored", clip: Path(full))
        } else if !has("ground") {
            paint("trees_ruined", clip: Path(full))
        }

        // 건물. 부위마다 복원된 그림이나 폐허 그림에서 제 영역만 가져온다.
        for part in art.parts {
            paint(has(part.id) ? "building_restored" : "building_ruined", clip: part.region(size), excluding: part.hole?(size))
        }
    }
}

extension LandmarkArt {
    /// 영역을 모양으로 적은 부위 하나. 넷째 권역부터의 도시가 쓴다(`LandmarkTiers.swift`).
    struct ShapedPart {
        var id: String
        var shapes: [Shape]
        /// 이 부위의 영역에서 빼는 다른 부위. 앞에 겹쳐 있는 부위(풍차의 날개 등)를 적는다.
        var minus: [String]
        /// 이 부위에 붙는 큰 포자의 자리.
        var spore: (CGFloat, CGFloat)

        enum Shape {
            case rect(CGFloat, CGFloat, CGFloat, CGFloat)
            case ellipse(CGFloat, CGFloat, CGFloat, CGFloat)
            case poly([(CGFloat, CGFloat)])

            func path(in size: CGSize) -> Path {
                switch self {
                case .rect(let x0, let y0, let x1, let y1):
                    return Path(CGRect(x: x0 * size.width, y: y0 * size.height, width: (x1 - x0) * size.width, height: (y1 - y0) * size.height))
                case .ellipse(let x0, let y0, let x1, let y1):
                    return Path(ellipseIn: CGRect(x: x0 * size.width, y: y0 * size.height, width: (x1 - x0) * size.width, height: (y1 - y0) * size.height))
                case .poly(let points):
                    var path = Path()
                    path.addLines(points.map { CGPoint(x: $0.0 * size.width, y: $0.1 * size.height) })
                    path.closeSubpath()
                    return path
                }
            }
        }
    }

    /// 모양으로 적은 부위들로 랜드마크를 만든다. 부위마다 큰 포자 하나와 그 옆의 작은 포자 하나를 붙이고,
    /// 환경 부위의 포자는 어느 도시나 같은 자리에 둔다.
    static func shaped(prefix: String, name: String, parts shaped: [ShapedPart]) -> LandmarkArt {
        func region(_ shapes: [ShapedPart.Shape]) -> (CGSize) -> Path {
            { size in
                var path = Path()
                for shape in shapes {
                    path.addPath(shape.path(in: size))
                }
                return path
            }
        }
        var parts: [Part] = []
        var spores: [Spore] = []
        for (index, item) in shaped.enumerated() {
            let removed = shaped.filter { item.minus.contains($0.id) }.flatMap(\.shapes)
            parts.append(Part(id: item.id, region: region(item.shapes), hole: removed.isEmpty ? nil : region(removed)))
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            spores.append(Spore(x: item.spore.0, y: item.spore.1, radius: 0.034, degrees: 0, part: item.id, shape: 1 + index % 3))
            spores.append(Spore(
                x: item.spore.0 + side * 0.035, y: item.spore.1 + 0.07, radius: 0.016,
                degrees: Double(index) * 25, part: item.id, shape: index % 2 == 0 ? 0 : 4
            ))
        }
        spores += [
            Spore(x: 0.050, y: 0.700, radius: 0.034, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.950, y: 0.700, radius: 0.036, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.850, y: 0.965, radius: 0.030, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.060, y: 0.930, radius: 0.024, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.700, y: 0.975, radius: 0.022, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.250, y: 0.975, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.110, y: 0.300, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.900, y: 0.420, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.200, y: 0.100, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.800, y: 0.200, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
        return LandmarkArt(prefix: prefix, name: name, horizon: 0.655, parts: parts, spores: spores)
    }

    /// 서울의 숭례문. 석축을 좌우로 나누고 가운데 홍예문을 따로 두며, 그 위에 문루 두 층을 올린다.
    /// 배경은 멀리 남산과 서울의 빌딩 숲, 돌을 깐 광장과 소나무, 석등이다.
    static let sungnyemun: LandmarkArt = {
        // 건물은 뒤의 남산과 빌딩이 보이도록 처음 그림의 85% 크기로 줄여 넣었다.
        // 위층 지붕과 아래층 지붕의 경계. 아래층 지붕은 양 끝이 위로 들려 있어서 가장자리에서는 경계가 더 높다.
        let floor2Bottom: CGFloat = 0.457
        let floor2SideBottom: CGFloat = 0.402
        let floor2Left: CGFloat = 0.2025
        let floor2Right: CGFloat = 0.7975
        let floor1Bottom: CGFloat = 0.61
        let wallBottom: CGFloat = 0.95
        // 석축 맨 윗줄의 아래 끝과, 그 줄에서 가운데에 가장 가까운 세로 이음매.
        let topRowBottom: CGFloat = 0.663
        let topRowJoint: CGFloat = 0.421
        // 홍예문. 돌 테두리의 바깥 폭이고, 위쪽은 `archCenterY`를 중심으로 한 반원이다.
        let gateRect = CGRect(x: 0.3946, y: 0.661, width: 0.2074, height: 0.289)
        let archCenterY: CGFloat = 0.819
        func union(_ regions: [(CGSize) -> Path]) -> (CGSize) -> Path {
            { size in
                var path = Path()
                for region in regions {
                    path.addPath(region(size))
                }
                return path
            }
        }
        let gate: (CGSize) -> Path = { size in
            var path = Path()
            let center = CGPoint(x: gateRect.midX * size.width, y: archCenterY * size.height)
            path.move(to: CGPoint(x: gateRect.minX * size.width, y: wallBottom * size.height))
            path.addLine(to: CGPoint(x: gateRect.minX * size.width, y: center.y))
            path.addArc(center: center, radius: gateRect.width / 2 * size.width, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: gateRect.maxX * size.width, y: wallBottom * size.height))
            path.closeSubpath()
            return path
        }
        return LandmarkArt(
            prefix: "landmark",
            name: "숭례문",
            horizon: 0.67,
            parts: [
                // 석축에서는 홍예문 자리를 뺀다. 빼지 않으면 복원한 문 안으로 무너진 돌이 비친다.
                // 좌우의 경계는 가운데 세로선이 아니라 맨 윗줄의 돌 이음매를 따라 꺾인다.
                Part(id: "wallLeft", region: union([band(0, floor1Bottom, topRowJoint, topRowBottom), band(0, topRowBottom, 0.5, wallBottom)]), hole: gate),
                Part(id: "wallRight", region: union([band(topRowJoint, floor1Bottom, 1, topRowBottom), band(0.5, topRowBottom, 1, wallBottom)]), hole: gate),
                Part(id: "gate", region: gate),
                Part(id: "floor1", region: union([
                    band(0, floor2Bottom, 1, floor1Bottom),
                    band(0, floor2SideBottom, floor2Left, floor2Bottom),
                    band(floor2Right, floor2SideBottom, 1, floor2Bottom),
                ])),
                Part(id: "floor2", region: union([band(0, 0, 1, floor2SideBottom), band(floor2Left, floor2SideBottom, floor2Right, floor2Bottom)])),
            ],
            spores: [
                Spore(x: 0.228, y: 0.788, radius: 0.037, degrees: 0, part: "wallLeft", shape: 3),
                Spore(x: 0.321, y: 0.890, radius: 0.017, degrees: -15, part: "wallLeft", shape: 4),
                Spore(x: 0.772, y: 0.771, radius: 0.039, degrees: 0, part: "wallRight", shape: 1),
                Spore(x: 0.678, y: 0.882, radius: 0.015, degrees: 20, part: "wallRight", shape: 3),
                Spore(x: 0.500, y: 0.704, radius: 0.029, degrees: 0, part: "gate", shape: 3),
                Spore(x: 0.449, y: 0.788, radius: 0.014, degrees: 30, part: "gate", shape: 0),
                Spore(x: 0.330, y: 0.525, radius: 0.034, degrees: 0, part: "floor1", shape: 2),
                Spore(x: 0.653, y: 0.568, radius: 0.017, degrees: -20, part: "floor1", shape: 3),
                Spore(x: 0.789, y: 0.499, radius: 0.014, degrees: 40, part: "floor1", shape: 0),
                Spore(x: 0.568, y: 0.295, radius: 0.036, degrees: 0, part: "floor2", shape: 1),
                Spore(x: 0.381, y: 0.346, radius: 0.017, degrees: 60, part: "floor2", shape: 3),
                Spore(x: 0.466, y: 0.236, radius: 0.012, degrees: 20, part: "floor2", shape: 0),
                Spore(x: 0.050, y: 0.720, radius: 0.034, degrees: -8, part: "greenery", shape: 2),
                Spore(x: 0.955, y: 0.710, radius: 0.036, degrees: 6, part: "greenery", shape: 1),
                Spore(x: 0.900, y: 0.960, radius: 0.028, degrees: 5, part: "greenery", shape: 4),
                Spore(x: 0.030, y: 0.900, radius: 0.022, degrees: -12, part: "ground", shape: 4),
                Spore(x: 0.760, y: 0.975, radius: 0.020, degrees: 170, part: "ground", shape: 4),
                Spore(x: 0.270, y: 0.975, radius: 0.018, degrees: 30, part: "ground", shape: 2),
                Spore(x: 0.090, y: 0.300, radius: 0.032, degrees: 20, part: "sky", shape: 0),
                Spore(x: 0.920, y: 0.250, radius: 0.024, degrees: -30, part: "sky", shape: 0),
                Spore(x: 0.130, y: 0.090, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
                Spore(x: 0.860, y: 0.060, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
            ]
        )
    }()

    /// 베이징의 만리장성. 가운데 망루를 아래층, 위층, 지붕의 세 토막으로 나누고, 양옆의 성벽을 따로 둔다.
    /// 배경은 멀리 능선을 따라가는 장성과 겹겹의 산, 풀밭의 돌길이다.
    static let greatWall = LandmarkArt(
        prefix: "beijing",
        name: "만리장성",
        horizon: 0.65,
        parts: [
            Part(id: "wallLeft", region: band(0, 0.50, 0.33, 0.88)),
            Part(id: "wallRight", region: band(0.67, 0.50, 1, 0.88)),
            Part(id: "gate", region: band(0.33, 0.556, 0.67, 0.88)),
            Part(id: "tower", region: band(0.33, 0.332, 0.67, 0.556)),
            Part(id: "roof", region: band(0, 0, 1, 0.332)),
        ],
        spores: [
            Spore(x: 0.180, y: 0.660, radius: 0.044, degrees: 0, part: "wallLeft", shape: 3),
            Spore(x: 0.080, y: 0.760, radius: 0.020, degrees: -15, part: "wallLeft", shape: 4),
            Spore(x: 0.820, y: 0.680, radius: 0.046, degrees: 0, part: "wallRight", shape: 1),
            Spore(x: 0.920, y: 0.610, radius: 0.018, degrees: 20, part: "wallRight", shape: 3),
            Spore(x: 0.400, y: 0.700, radius: 0.036, degrees: 0, part: "gate", shape: 3),
            Spore(x: 0.610, y: 0.770, radius: 0.018, degrees: 30, part: "gate", shape: 0),
            Spore(x: 0.560, y: 0.440, radius: 0.036, degrees: 0, part: "tower", shape: 2),
            Spore(x: 0.400, y: 0.390, radius: 0.016, degrees: -20, part: "tower", shape: 3),
            Spore(x: 0.470, y: 0.200, radius: 0.038, degrees: 0, part: "roof", shape: 1),
            Spore(x: 0.590, y: 0.260, radius: 0.016, degrees: 60, part: "roof", shape: 0),
            Spore(x: 0.060, y: 0.720, radius: 0.036, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.945, y: 0.710, radius: 0.040, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.600, y: 0.955, radius: 0.034, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.170, y: 0.900, radius: 0.026, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.840, y: 0.910, radius: 0.028, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.400, y: 0.968, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.130, y: 0.330, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.880, y: 0.440, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.220, y: 0.110, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.800, y: 0.130, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 뉴델리의 인디아 게이트. 양쪽 기둥을 세우고 그 위에 아치와 꼭대기를 올린다. 양옆의 낮은 난간은 따로 복원한다.
    ///
    /// 풍경이 들어간 시험판이다. 배경(먼 대통령궁과 가로수, 의장대로와 연못)과 건물을 따로 그렸고,
    /// 건물이 그림 높이의 대부분을 차지한다. 나무는 배경에 들어 있어서 나무 그림은 비어 있다.
    static let indiaGate = LandmarkArt(
        prefix: "newdelhi",
        name: "인디아 게이트",
        horizon: 0.68,
        parts: [
            Part(id: "wallLeft", region: band(0, 0.72, 0.255, 0.92)),
            Part(id: "wallRight", region: band(0.745, 0.72, 1, 0.92)),
            Part(id: "pierLeft", region: band(0.255, 0.49, 0.5, 0.92)),
            Part(id: "pierRight", region: band(0.5, 0.49, 0.745, 0.92)),
            Part(id: "arch", region: band(0.25, 0.227, 0.75, 0.49)),
            Part(id: "crown", region: band(0, 0, 1, 0.227)),
        ],
        spores: [
            Spore(x: 0.130, y: 0.810, radius: 0.030, degrees: 0, part: "wallLeft", shape: 3),
            Spore(x: 0.060, y: 0.790, radius: 0.016, degrees: -15, part: "wallLeft", shape: 0),
            Spore(x: 0.870, y: 0.805, radius: 0.032, degrees: 0, part: "wallRight", shape: 1),
            Spore(x: 0.940, y: 0.790, radius: 0.015, degrees: 20, part: "wallRight", shape: 3),
            Spore(x: 0.345, y: 0.600, radius: 0.040, degrees: 0, part: "pierLeft", shape: 3),
            Spore(x: 0.330, y: 0.790, radius: 0.020, degrees: 25, part: "pierLeft", shape: 0),
            Spore(x: 0.655, y: 0.620, radius: 0.042, degrees: 0, part: "pierRight", shape: 1),
            Spore(x: 0.670, y: 0.800, radius: 0.018, degrees: -20, part: "pierRight", shape: 4),
            Spore(x: 0.430, y: 0.330, radius: 0.038, degrees: 0, part: "arch", shape: 2),
            Spore(x: 0.630, y: 0.420, radius: 0.022, degrees: 0, part: "arch", shape: 3),
            Spore(x: 0.530, y: 0.140, radius: 0.040, degrees: 0, part: "crown", shape: 1),
            Spore(x: 0.410, y: 0.190, radius: 0.016, degrees: 50, part: "crown", shape: 0),
            Spore(x: 0.060, y: 0.720, radius: 0.036, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.945, y: 0.710, radius: 0.040, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.600, y: 0.950, radius: 0.036, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.200, y: 0.920, radius: 0.026, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.820, y: 0.930, radius: 0.028, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.400, y: 0.965, radius: 0.022, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.150, y: 0.330, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.860, y: 0.440, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.240, y: 0.110, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.780, y: 0.130, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 방콕의 왓 아룬. 기단 위에 양옆의 작은 탑과 가운데 큰 탑을 올린다. 큰 탑은 아래층과 첨탑의 두 토막이다.
    /// 배경은 멀리 방콕의 빌딩과 사원 지붕, 연꽃이 핀 연못과 돌길이다.
    static let watArun = LandmarkArt(
        prefix: "bangkok",
        name: "왓 아룬",
        horizon: 0.65,
        parts: [
            Part(id: "base", region: band(0, 0.80, 1, 0.97)),
            Part(id: "prangLeft", region: band(0, 0.30, 0.37, 0.80)),
            Part(id: "prangRight", region: band(0.63, 0.30, 1, 0.80)),
            Part(id: "tiers", region: band(0.37, 0.45, 0.63, 0.80)),
            Part(id: "spire", region: band(0.37, 0, 0.63, 0.45)),
        ],
        spores: [
            Spore(x: 0.200, y: 0.870, radius: 0.030, degrees: 0, part: "base", shape: 3),
            Spore(x: 0.790, y: 0.860, radius: 0.032, degrees: 0, part: "base", shape: 1),
            Spore(x: 0.500, y: 0.880, radius: 0.018, degrees: 15, part: "base", shape: 4),
            Spore(x: 0.260, y: 0.580, radius: 0.036, degrees: 0, part: "prangLeft", shape: 3),
            Spore(x: 0.300, y: 0.730, radius: 0.016, degrees: 25, part: "prangLeft", shape: 0),
            Spore(x: 0.740, y: 0.560, radius: 0.038, degrees: 0, part: "prangRight", shape: 1),
            Spore(x: 0.700, y: 0.720, radius: 0.016, degrees: -20, part: "prangRight", shape: 4),
            Spore(x: 0.460, y: 0.560, radius: 0.036, degrees: 0, part: "tiers", shape: 2),
            Spore(x: 0.560, y: 0.700, radius: 0.020, degrees: 0, part: "tiers", shape: 3),
            Spore(x: 0.520, y: 0.300, radius: 0.036, degrees: 0, part: "spire", shape: 1),
            Spore(x: 0.470, y: 0.400, radius: 0.015, degrees: 50, part: "spire", shape: 0),
            Spore(x: 0.060, y: 0.720, radius: 0.036, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.945, y: 0.710, radius: 0.040, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.800, y: 0.965, radius: 0.030, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.050, y: 0.930, radius: 0.024, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.940, y: 0.900, radius: 0.026, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.230, y: 0.975, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.110, y: 0.300, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.900, y: 0.420, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.200, y: 0.100, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.800, y: 0.200, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 싱가포르의 하늘 정원 호텔. 저층부 위에 타워 세 동을 세우고, 그 위에 스카이파크를 얹는다.
    /// 배경은 멀리 싱가포르의 빌딩 숲과 대관람차, 바다와 물가의 산책로다.
    static let marinaBaySands = LandmarkArt(
        prefix: "singapore",
        name: "하늘 정원 호텔",
        horizon: 0.65,
        parts: [
            // 스카이파크를 먼저 그리고 타워를 그 위에 그린다. 폐허에서는 부서진 스카이파크 조각이 타워 높이까지
            // 비스듬히 내려와 걸쳐 있다. 그 자리까지 스카이파크의 영역에 넣어야, 타워만 복원했을 때
            // 조각이 경계에서 잘리지 않고 복원된 타워 뒤에 걸쳐 보인다.
            Part(id: "skypark", region: { size in
                var path = band(0, 0, 1, 0.20)(size)
                path.addPath(band(0.39, 0.20, 1, 0.42)(size))
                return path
            }),
            Part(id: "podium", region: band(0, 0.77, 1, 0.96)),
            Part(id: "towerLeft", region: band(0, 0.20, 0.39, 0.77)),
            Part(id: "towerCenter", region: band(0.39, 0.20, 0.615, 0.77)),
            Part(id: "towerRight", region: band(0.615, 0.20, 1, 0.77)),
        ],
        spores: [
            Spore(x: 0.250, y: 0.850, radius: 0.030, degrees: 0, part: "podium", shape: 3),
            Spore(x: 0.740, y: 0.840, radius: 0.032, degrees: 0, part: "podium", shape: 1),
            Spore(x: 0.500, y: 0.860, radius: 0.018, degrees: 15, part: "podium", shape: 4),
            Spore(x: 0.270, y: 0.420, radius: 0.036, degrees: 0, part: "towerLeft", shape: 3),
            Spore(x: 0.290, y: 0.650, radius: 0.016, degrees: 25, part: "towerLeft", shape: 0),
            Spore(x: 0.510, y: 0.540, radius: 0.036, degrees: 0, part: "towerCenter", shape: 2),
            Spore(x: 0.490, y: 0.320, radius: 0.018, degrees: 0, part: "towerCenter", shape: 3),
            Spore(x: 0.730, y: 0.480, radius: 0.038, degrees: 0, part: "towerRight", shape: 1),
            Spore(x: 0.710, y: 0.680, radius: 0.016, degrees: -20, part: "towerRight", shape: 4),
            Spore(x: 0.330, y: 0.130, radius: 0.034, degrees: 0, part: "skypark", shape: 3),
            Spore(x: 0.700, y: 0.120, radius: 0.022, degrees: 0, part: "skypark", shape: 1),
            Spore(x: 0.060, y: 0.720, radius: 0.036, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.945, y: 0.710, radius: 0.040, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.800, y: 0.965, radius: 0.030, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.050, y: 0.930, radius: 0.024, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.940, y: 0.900, radius: 0.026, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.230, y: 0.975, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.110, y: 0.300, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.900, y: 0.420, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.200, y: 0.100, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.800, y: 0.200, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 카이로의 피라미드와 스핑크스. 대피라미드를 아래에서 위로 세 토막으로 올리고, 양옆의 작은 피라미드와
    /// 앞의 스핑크스를 따로 복원한다. 배경은 멀리 카이로와 나일강, 모래 언덕, 돌길과 야자수, 오아시스다.
    static let giza = LandmarkArt(
        prefix: "cairo",
        name: "피라미드와 스핑크스",
        horizon: 0.66,
        parts: [
            Part(id: "pyramidLeft", region: band(0, 0.30, 0.27, 0.95)),
            Part(id: "pyramidRight", region: band(0.73, 0.30, 1, 0.95)),
            Part(id: "base", region: band(0.27, 0.56, 0.73, 0.95)),
            Part(id: "middle", region: band(0.27, 0.30, 0.73, 0.56)),
            Part(id: "peak", region: band(0, 0, 1, 0.30)),
            // 스핑크스는 대피라미드 앞에 있어서 맨 나중에 그린다. 네모로 자르면 뒤의 피라미드까지 함께 바뀌어
            // 네모난 자국이 남으므로, 머리는 타원으로 몸은 좁은 네모로 스핑크스의 윤곽에 가깝게 자른다.
            Part(id: "sphinx", region: { size in
                var path = Path(ellipseIn: CGRect(x: 0.37 * size.width, y: 0.42 * size.height, width: 0.26 * size.width, height: 0.34 * size.height))
                path.addPath(band(0.335, 0.70, 0.665, 0.95)(size))
                return path
            }),
        ],
        spores: [
            Spore(x: 0.130, y: 0.640, radius: 0.034, degrees: 0, part: "pyramidLeft", shape: 3),
            Spore(x: 0.200, y: 0.780, radius: 0.016, degrees: -15, part: "pyramidLeft", shape: 0),
            Spore(x: 0.870, y: 0.650, radius: 0.036, degrees: 0, part: "pyramidRight", shape: 1),
            Spore(x: 0.800, y: 0.780, radius: 0.016, degrees: 20, part: "pyramidRight", shape: 3),
            Spore(x: 0.300, y: 0.700, radius: 0.034, degrees: 0, part: "base", shape: 3),
            Spore(x: 0.700, y: 0.660, radius: 0.020, degrees: 25, part: "base", shape: 0),
            Spore(x: 0.400, y: 0.400, radius: 0.036, degrees: 0, part: "middle", shape: 2),
            Spore(x: 0.610, y: 0.470, radius: 0.018, degrees: 0, part: "middle", shape: 3),
            Spore(x: 0.520, y: 0.200, radius: 0.034, degrees: 0, part: "peak", shape: 1),
            Spore(x: 0.470, y: 0.270, radius: 0.014, degrees: 50, part: "peak", shape: 0),
            Spore(x: 0.560, y: 0.560, radius: 0.026, degrees: 0, part: "sphinx", shape: 3),
            Spore(x: 0.420, y: 0.800, radius: 0.016, degrees: 30, part: "sphinx", shape: 4),
            Spore(x: 0.050, y: 0.700, radius: 0.034, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.950, y: 0.700, radius: 0.036, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.850, y: 0.965, radius: 0.030, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.060, y: 0.930, radius: 0.024, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.660, y: 0.975, radius: 0.022, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.250, y: 0.975, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.110, y: 0.300, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.900, y: 0.420, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.220, y: 0.100, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.780, y: 0.200, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 두바이의 돛 모양 호텔. 인공섬 위에 돛 모양의 탑을 아래에서 위로 네 토막으로 올린다.
    /// 배경은 멀리 두바이의 빌딩 숲, 바다, 모래 해변과 나무 산책로다.
    static let burjAlArab = LandmarkArt(
        prefix: "dubai",
        name: "돛 모양 호텔",
        horizon: 0.655,
        parts: [
            Part(id: "island", region: band(0, 0.76, 1, 0.95)),
            Part(id: "lower", region: band(0, 0.565, 1, 0.76)),
            Part(id: "middle", region: band(0, 0.385, 1, 0.565)),
            Part(id: "upper", region: band(0, 0.19, 1, 0.385)),
            Part(id: "mast", region: band(0, 0, 1, 0.19)),
        ],
        spores: [
            Spore(x: 0.300, y: 0.830, radius: 0.030, degrees: 0, part: "island", shape: 3),
            Spore(x: 0.700, y: 0.840, radius: 0.028, degrees: 0, part: "island", shape: 1),
            Spore(x: 0.540, y: 0.680, radius: 0.034, degrees: 0, part: "lower", shape: 3),
            Spore(x: 0.450, y: 0.620, radius: 0.016, degrees: 20, part: "lower", shape: 0),
            Spore(x: 0.560, y: 0.480, radius: 0.034, degrees: 0, part: "middle", shape: 2),
            Spore(x: 0.455, y: 0.430, radius: 0.015, degrees: -20, part: "middle", shape: 4),
            Spore(x: 0.520, y: 0.300, radius: 0.032, degrees: 0, part: "upper", shape: 1),
            Spore(x: 0.400, y: 0.250, radius: 0.016, degrees: 30, part: "upper", shape: 0),
            Spore(x: 0.440, y: 0.110, radius: 0.024, degrees: 0, part: "mast", shape: 3),
            Spore(x: 0.470, y: 0.040, radius: 0.012, degrees: 40, part: "mast", shape: 0),
            Spore(x: 0.050, y: 0.700, radius: 0.034, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.950, y: 0.700, radius: 0.036, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.850, y: 0.965, radius: 0.030, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.090, y: 0.930, radius: 0.024, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.720, y: 0.975, radius: 0.022, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.250, y: 0.975, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.150, y: 0.300, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.860, y: 0.420, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.250, y: 0.100, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.750, y: 0.180, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 케이프타운의 테이블마운틴 케이블카. 산은 배경이고, 복원하는 것은 아래 승강장, 철탑과 줄, 산 위 승강장, 케이블카다.
    /// 폐허에서는 케이블카가 줄에서 떨어져 땅에 누워 있어서, 케이블카의 영역은 매달린 자리부터 땅까지다.
    static let cableway = LandmarkArt(
        prefix: "capetown",
        name: "테이블마운틴 케이블카",
        horizon: 0.634,
        parts: [
            Part(id: "lower", region: band(0, 0.30, 0.33, 0.95)),
            Part(id: "pylon", region: band(0.475, 0, 0.68, 0.95)),
            Part(id: "upper", region: band(0.68, 0, 1, 0.42)),
            Part(id: "cabin", region: band(0.33, 0.30, 0.475, 0.95)),
        ],
        spores: [
            Spore(x: 0.150, y: 0.700, radius: 0.036, degrees: 0, part: "lower", shape: 3),
            Spore(x: 0.260, y: 0.800, radius: 0.018, degrees: 20, part: "lower", shape: 0),
            Spore(x: 0.070, y: 0.620, radius: 0.016, degrees: -20, part: "lower", shape: 4),
            Spore(x: 0.570, y: 0.560, radius: 0.034, degrees: 0, part: "pylon", shape: 1),
            Spore(x: 0.590, y: 0.780, radius: 0.018, degrees: 30, part: "pylon", shape: 3),
            Spore(x: 0.555, y: 0.330, radius: 0.016, degrees: 0, part: "pylon", shape: 0),
            Spore(x: 0.840, y: 0.180, radius: 0.036, degrees: 0, part: "upper", shape: 2),
            Spore(x: 0.930, y: 0.260, radius: 0.016, degrees: -30, part: "upper", shape: 0),
            Spore(x: 0.740, y: 0.250, radius: 0.018, degrees: 15, part: "upper", shape: 3),
            Spore(x: 0.405, y: 0.760, radius: 0.028, degrees: 0, part: "cabin", shape: 1),
            Spore(x: 0.380, y: 0.860, radius: 0.014, degrees: 40, part: "cabin", shape: 0),
            Spore(x: 0.800, y: 0.700, radius: 0.034, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.950, y: 0.900, radius: 0.036, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.700, y: 0.950, radius: 0.030, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.060, y: 0.950, radius: 0.024, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.880, y: 0.780, radius: 0.022, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.270, y: 0.965, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.130, y: 0.200, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.400, y: 0.130, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.270, y: 0.300, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.620, y: 0.120, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )

    /// 도쿄의 붉은 전파탑. 탑이라 아래에서 위로 다섯 토막으로 나눈다.
    /// 배경은 멀리 후지산과 도쿄의 빌딩 숲, 벚꽃이 핀 공원의 길이다.
    static let tokyoTower = LandmarkArt(
        prefix: "tokyo",
        name: "붉은 전파탑",
        horizon: 0.66,
        parts: [
            Part(id: "base", region: band(0, 0.65, 1, 0.97)),
            Part(id: "deck1", region: band(0, 0.527, 1, 0.65)),
            Part(id: "body", region: band(0, 0.322, 1, 0.527)),
            Part(id: "deck2", region: band(0, 0.21, 1, 0.322)),
            Part(id: "antenna", region: band(0, 0, 1, 0.21)),
        ],
        spores: [
            Spore(x: 0.400, y: 0.840, radius: 0.040, degrees: 0, part: "base", shape: 3),
            Spore(x: 0.620, y: 0.900, radius: 0.022, degrees: 20, part: "base", shape: 0),
            Spore(x: 0.560, y: 0.590, radius: 0.036, degrees: 0, part: "deck1", shape: 1),
            Spore(x: 0.420, y: 0.610, radius: 0.016, degrees: -20, part: "deck1", shape: 4),
            Spore(x: 0.480, y: 0.430, radius: 0.034, degrees: 0, part: "body", shape: 2),
            Spore(x: 0.545, y: 0.480, radius: 0.015, degrees: 30, part: "body", shape: 0),
            Spore(x: 0.530, y: 0.270, radius: 0.030, degrees: 0, part: "deck2", shape: 3),
            Spore(x: 0.465, y: 0.250, radius: 0.014, degrees: -30, part: "deck2", shape: 0),
            Spore(x: 0.505, y: 0.120, radius: 0.028, degrees: 0, part: "antenna", shape: 1),
            Spore(x: 0.490, y: 0.050, radius: 0.012, degrees: 40, part: "antenna", shape: 0),
            Spore(x: 0.060, y: 0.720, radius: 0.036, degrees: -8, part: "greenery", shape: 2),
            Spore(x: 0.945, y: 0.710, radius: 0.040, degrees: 6, part: "greenery", shape: 1),
            Spore(x: 0.800, y: 0.955, radius: 0.034, degrees: 5, part: "greenery", shape: 4),
            Spore(x: 0.170, y: 0.900, radius: 0.026, degrees: -12, part: "ground", shape: 4),
            Spore(x: 0.840, y: 0.860, radius: 0.028, degrees: 170, part: "ground", shape: 4),
            Spore(x: 0.230, y: 0.968, radius: 0.020, degrees: 30, part: "ground", shape: 2),
            Spore(x: 0.130, y: 0.330, radius: 0.032, degrees: 20, part: "sky", shape: 0),
            Spore(x: 0.880, y: 0.440, radius: 0.024, degrees: -30, part: "sky", shape: 0),
            Spore(x: 0.220, y: 0.110, radius: 0.016, degrees: 55, part: "pollution", shape: 0),
            Spore(x: 0.800, y: 0.130, radius: 0.020, degrees: 10, part: "pollution", shape: 0),
        ]
    )
}

/// 포자가 터지는 모습. 부풀며 흐려지고, 분홍 방울이 사방으로 튄다.
private struct SporePop: ViewModifier, @preconcurrency Animatable {
    /// 0이면 그대로, 1이면 다 터진 뒤다.
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.45 * progress)
            .opacity(1 - progress)
            .overlay {
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    ForEach(0..<7, id: \.self) { index in
                        let angle = Double(index) / 7 * 2 * .pi + 0.4
                        let distance = side * (0.25 + 0.75 * progress)
                        Circle()
                            .fill(Palette.material)
                            .frame(width: side * 0.16, height: side * 0.16)
                            .scaleEffect(1 - 0.6 * progress)
                            .position(
                                x: geometry.size.width / 2 + cos(angle) * distance,
                                y: geometry.size.height / 2 + sin(angle) * distance
                            )
                    }
                }
                // 터지는 동안에만 보인다.
                .opacity(sin(progress * .pi))
            }
    }
}

#Preview {
    VStack {
        LandmarkView(restored: [])
            .aspectRatio(1.5, contentMode: .fit)
        LandmarkView(restored: ["base", "deck1", "sky", "pollution"], art: .tokyoTower)
            .aspectRatio(1.5, contentMode: .fit)
    }
}
