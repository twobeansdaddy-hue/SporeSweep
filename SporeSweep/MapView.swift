import GameScene
import LevelData
import SwiftUI

/// 권역 지도. 권역의 도시를 보여주고, 열린 도시를 누르면 그 도시로 간다(8장).
///
/// 도시의 레벨을 모두 클리어하면 이 화면이 뜨고, 비행기가 다음 도시로 날아간 뒤 그 도시가 열린다.
struct MapView: View {
    @Environment(AppModel.self) private var model
    var region: Region
    /// 보여줄 비행. 없으면 도시를 고르는 화면이다.
    var flight: AppModel.Flight?
    /// 화면을 닫을 때. 비행을 보여줬으면 끝난 뒤에 부른다.
    var onClose: () -> Void

    /// 비행에 걸리는 시간(초).
    static let flightDuration: Double = 3

    @State private var progress: Double = 0
    @State private var arrived = false
    /// 방금 정화한 도시의 초록이 번진 정도(0...1).
    @State private var spread: Double = 0

    /// 정화한 도시의 둘레. 레벨을 모두 클리어한 도시가 초록으로 돌아온다.
    private var patches: [PurifiedMap.Patch] {
        region.cityIDs.filter(model.hasClearedAllLevels).compactMap { id in
            guard let spot = region.cityPositions[id] else { return nil }
            // 방금 끝내고 떠나는 도시는 눈앞에서 번진다.
            return PurifiedMap.Patch(id: id, center: spot, radius: Region.cityRadius, amount: id == flight?.from ? spread : 1)
        }
    }

    /// 권역의 도시를 모두 정화했으면 지도 전체가 초록이다. 아직 만들지 않은 도시가 남아 있으면 아니다.
    private var isAllClean: Bool {
        region.isPlayable && region.planned.isEmpty && region.cityIDs.allSatisfy(model.hasClearedAllLevels)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            // 그림은 2:3이다. 세로로 긴 화면에서는 양옆이 잘린다. 도시가 모두 보이도록 권역마다 잘라낼 쪽을 정해 둔다.
            let width = max(size.height * 2 / 3, size.width)
            let shift = (size.width - width) * region.mapAnchor
            let place: (Region.Spot) -> CGPoint = { spot in
                CGPoint(x: spot.x * width + shift, y: spot.y * size.height)
            }
            let point: (String) -> CGPoint = { id in
                place(region.cityPositions[id] ?? .init(0.5, 0.5))
            }
            ZStack(alignment: .topLeading) {
                PurifiedMap(image: region.mapImage, patches: patches, isAllClean: isAllClean)
                    .frame(width: width, height: size.height)
                    .offset(x: shift)

                if let flight {
                    FlightTrail(from: point(flight.from), to: point(flight.to), progress: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 9]))
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                }

                ForEach(model.cities.filter { region.cityIDs.contains($0.id) }) { city in
                    pin(for: city)
                        .position(point(city.id))
                }
                // 아직 만들지 않은 도시.
                ForEach(region.planned, id: \.name) { planned in
                    VStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(ChunkyShape(tint: .slate, radius: 22))
                            .padding(.bottom, 4)
                        VStack(spacing: 1) {
                            Text(planned.name)
                                .font(.game(15))
                            Text("준비 중")
                                .font(.game(11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Palette.panel.opacity(0.92), in: Capsule())
                    }
                    .opacity(0.85)
                    .position(place(planned.spot))
                    .accessibilityElement()
                    .accessibilityLabel("\(planned.name), 준비 중")
                }

                if let flight {
                    Image(systemName: "airplane")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
                        .modifier(FlightPosition(from: point(flight.from), to: point(flight.to), progress: progress))
                        .opacity(arrived ? 0 : 1)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            GameHeader(title: region.name) {
                if flight == nil {
                    IconButton(systemName: "chevron.left", label: "도시로 돌아가기") {
                        GameFeedback.shared.play(.tap)
                        onClose()
                    }
                }
            } trailing: {
                if flight == nil {
                    IconButton(systemName: "globe.asia.australia.fill", label: "세계 지도") {
                        GameFeedback.shared.play(.tap)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            model.mapScreen = .world
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let flight, let city = model.cities.first(where: { $0.id == flight.to }) {
                Text(arrived ? "\(city.name) 도착!" : "다음 목적지는 \(city.name)!")
                    .font(.game(20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .gamePanel(radius: 20)
                    .padding(.bottom, 40)
            }
        }
        .task {
            guard let flight else { return }
            // 떠나는 도시의 둘레가 초록으로 돌아오는 것을 보여준 뒤 출발한다.
            try? await Task.sleep(for: .seconds(0.5))
            GameFeedback.shared.play(.restore)
            withAnimation(.easeOut(duration: 1.2)) {
                spread = 1
            }
            try? await Task.sleep(for: .seconds(1.4))
            GameFeedback.shared.play(.introArrival)
            withAnimation(.easeInOut(duration: Self.flightDuration)) {
                progress = 1
            }
            try? await Task.sleep(for: .seconds(Self.flightDuration))
            GameFeedback.shared.play(.restore)
            GameFeedback.shared.haptic(.success)
            withAnimation(.spring(duration: 0.4)) {
                arrived = true
            }
            try? await Task.sleep(for: .seconds(1.3))
            model.select(cityID: flight.to)
            onClose()
        }
    }

    /// 도시 하나의 표시. 열린 도시는 누를 수 있다.
    private func pin(for city: City) -> some View {
        // 비행이 도착하기 전에는 도착할 도시가 아직 잠겨 보인다.
        let isOpen = model.isUnlocked(cityID: city.id) && (flight?.to != city.id || arrived)
        let isDone = model.isFullyRestored(cityID: city.id)
        let isCurrent = model.city?.id == city.id && flight == nil
        let stars = model.stars(cityID: city.id)
        let tint: GameTint = !isOpen ? .slate : (isDone ? .green : .pink)
        return Button {
            GameFeedback.shared.play(.tap)
            model.select(cityID: city.id)
            onClose()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: !isOpen ? "lock.fill" : (isDone ? "checkmark" : "mappin"))
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(ChunkyShape(tint: tint, radius: 22))
                    .padding(.bottom, 4)
                    .scaleEffect(isCurrent ? 1.15 : 1)
                VStack(spacing: 1) {
                    Text(city.name)
                        .font(.game(15))
                    if isOpen {
                        Text("★ \(stars.earned)/\(stars.total)")
                            .font(.game(11))
                            .foregroundStyle(Palette.star)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Palette.panel.opacity(0.92), in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .disabled(!isOpen || flight != nil)
        .scaleEffect(flight?.to == city.id && arrived ? 1.2 : 1)
        .accessibilityLabel(isOpen ? "\(city.name), 별 \(stars.earned)개" : "\(city.name), 잠김")
    }
}

/// 두 도시를 잇는 휘어진 길 위의 한 점과, 그 점에서의 진행 방향.
func flightPoint(from: CGPoint, to: CGPoint, progress: Double) -> (point: CGPoint, angle: Angle) {
    // 길은 위로 볼록하게 휜다.
    let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - abs(to.x - from.x) * 0.45)
    let t = CGFloat(progress)
    let x = (1 - t) * (1 - t) * from.x + 2 * (1 - t) * t * control.x + t * t * to.x
    let y = (1 - t) * (1 - t) * from.y + 2 * (1 - t) * t * control.y + t * t * to.y
    let dx = 2 * (1 - t) * (control.x - from.x) + 2 * t * (to.x - control.x)
    let dy = 2 * (1 - t) * (control.y - from.y) + 2 * t * (to.y - control.y)
    return (CGPoint(x: x, y: y), Angle(radians: atan2(dy, dx)))
}

/// 비행기를 길 위의 제자리에 놓고 진행 방향으로 돌린다.
struct FlightPosition: ViewModifier, @preconcurrency Animatable {
    var from: CGPoint
    var to: CGPoint
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let place = flightPoint(from: from, to: to, progress: progress)
        // 가운데쯤에서 가장 크게 보여 높이 떠 있는 느낌을 준다.
        // 왼쪽으로 날 때는 뒤집어서 비행기가 거꾸로 보이지 않게 한다.
        content
            .scaleEffect(x: 1, y: cos(place.angle.radians) < 0 ? -1 : 1)
            .rotationEffect(place.angle)
            .scaleEffect(1 + 0.5 * sin(progress * .pi))
            .position(place.point)
    }
}

/// 비행기가 지나온 길.
struct FlightTrail: Shape {
    var from: CGPoint
    var to: CGPoint
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        let steps = 40
        for step in 1...steps {
            let t = progress * Double(step) / Double(steps)
            path.addLine(to: flightPoint(from: from, to: to, progress: t).point)
        }
        return path
    }
}
