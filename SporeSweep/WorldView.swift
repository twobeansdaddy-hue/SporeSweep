import GameScene
import LevelData
import SwiftUI

/// 세계 지도. 권역을 고른다(8장).
///
/// 위에 세계 지도를 두고 권역마다 번호를 찍는다. 그 아래의 목록에서 권역을 누르면 그 권역의 지도로 간다.
struct WorldView: View {
    @Environment(AppModel.self) private var model
    /// 보여줄 비행. 다른 권역의 도시로 넘어갈 때만 있다. 없으면 권역을 고르는 화면이다.
    var flight: AppModel.Flight?
    var onClose: () -> Void

    @State private var progress: Double = 0
    @State private var arrived = false
    /// 방금 끝낸 권역의 초록이 번진 정도(0...1).
    @State private var spread: Double = 0

    /// 비행의 출발 권역과 도착 권역.
    private var route: (from: Region, to: Region)? {
        guard let flight,
              let from = model.regions.first(where: { $0.cityIDs.contains(flight.from) }),
              let to = model.regions.first(where: { $0.cityIDs.contains(flight.to) }) else { return nil }
        return (from, to)
    }

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(title: "세계 지도") {
                if flight == nil {
                    IconButton(systemName: "chevron.left", label: "도시로 돌아가기") {
                        GameFeedback.shared.play(.tap)
                        onClose()
                    }
                }
            } trailing: {
                EmptyView()
            }
            map
                .padding(.horizontal, 16)
            if let flight, let route, let city = model.cities.first(where: { $0.id == flight.to }) {
                Text(arrived ? "\(city.name) 도착!" : "다음 목적지는 \(route.to.name)의 \(city.name)!")
                    .font(.game(18))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .gamePanel(radius: 18)
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(model.regions.enumerated()), id: \.element.id) { index, region in
                        row(region, number: index + 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .gameBackground()
        .task {
            guard let flight, route != nil else { return }
            // 끝낸 권역이 초록으로 돌아오는 것을 보여준 뒤 다음 권역으로 날아간다.
            try? await Task.sleep(for: .seconds(0.5))
            GameFeedback.shared.play(.restore)
            withAnimation(.easeOut(duration: 1.2)) {
                spread = 1
            }
            try? await Task.sleep(for: .seconds(1.4))
            GameFeedback.shared.play(.introArrival)
            withAnimation(.easeInOut(duration: MapView.flightDuration)) {
                progress = 1
            }
            try? await Task.sleep(for: .seconds(MapView.flightDuration))
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

    /// 권역의 상태.
    private enum Status {
        case locked, comingSoon, open, done

        var tint: GameTint {
            switch self {
            case .locked, .comingSoon: .slate
            case .open: .pink
            case .done: .green
            }
        }
    }

    private func status(of region: Region) -> Status {
        // 비행이 도착하기 전에는 도착할 권역이 아직 잠겨 보인다.
        if let route, route.to.id == region.id, !arrived { return .locked }
        guard model.isUnlocked(regionID: region.id) else { return .locked }
        guard region.isPlayable else { return .comingSoon }
        // 아직 만들지 않은 도시가 남은 권역은 끝난 것이 아니다.
        return region.planned.isEmpty && region.cityIDs.allSatisfy(model.hasClearedAllLevels) ? .done : .open
    }

    /// 정화한 권역의 둘레. 도시를 끝낼 때마다 초록이 넓어지고, 권역을 끝내면 다 돌아온다.
    private var patches: [PurifiedMap.Patch] {
        model.regions.compactMap { region in
            let cleared = region.cityIDs.filter(model.hasClearedAllLevels).count
            guard cleared > 0 else { return nil }
            // 아직 만들지 않은 도시도 몫에 넣는다.
            let count = Double(region.cityIDs.count + region.planned.count)
            var share = Double(cleared) / count
            // 방금 끝낸 권역은 마지막 도시의 몫만큼 눈앞에서 넓어진다.
            if region.id == route?.from.id {
                share -= (1 - spread) / count
            }
            return PurifiedMap.Patch(id: region.id, center: region.worldSpot, radius: region.worldRadius, amount: 0.4 + 0.6 * share)
        }
    }

    /// 모든 권역을 끝냈으면 세계가 다 초록이다.
    private var isAllClean: Bool {
        model.regions.allSatisfy { $0.isPlayable && $0.planned.isEmpty && $0.cityIDs.allSatisfy(model.hasClearedAllLevels) }
    }

    /// 세계 지도 그림과 권역의 번호.
    private var map: some View {
        PurifiedMap(image: "map_world", patches: patches, isAllClean: isAllClean)
            .aspectRatio(1.5, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    ForEach(Array(model.regions.enumerated()), id: \.element.id) { index, region in
                        let status = status(of: region)
                        Text("\(index + 1)")
                            .font(.game(13))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                LinearGradient(colors: [status.tint.top, status.tint.bottom], startPoint: .top, endPoint: .bottom),
                                in: Circle()
                            )
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
                            .scaleEffect(region.id == model.currentRegion?.id ? 1.25 : 1)
                            .position(
                                x: region.worldSpot.x * geometry.size.width,
                                y: region.worldSpot.y * geometry.size.height
                            )
                    }
                    if let route {
                        let place: (Region) -> CGPoint = {
                            CGPoint(x: $0.worldSpot.x * geometry.size.width, y: $0.worldSpot.y * geometry.size.height)
                        }
                        FlightTrail(from: place(route.from), to: place(route.to), progress: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 7]))
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        Image(systemName: "airplane")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
                            .modifier(FlightPosition(from: place(route.from), to: place(route.to), progress: progress))
                            .opacity(arrived ? 0 : 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 2))
            .accessibilityHidden(true)
    }

    private func row(_ region: Region, number: Int) -> some View {
        let status = status(of: region)
        let stars = model.stars(regionID: region.id)
        // 지도가 있는 열린 권역만 들어가 볼 수 있다.
        let canOpen = status != .locked && !region.mapImage.isEmpty
        return Button {
            GameFeedback.shared.play(.tap)
            withAnimation(.easeInOut(duration: 0.3)) {
                model.mapScreen = .region(region.id)
            }
        } label: {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.game(17))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(ChunkyShape(tint: status.tint, radius: 17, depth: 3))
                    .padding(.bottom, 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(region.name)
                        .font(.game(18))
                        .foregroundStyle(.white)
                    Text(caption(for: region, status: status, stars: stars))
                        .font(.game(12))
                        .foregroundStyle(status == .open || status == .done ? Palette.star : .white.opacity(0.6))
                }
                Spacer()
                Image(systemName: icon(for: status, canOpen: canOpen))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white.opacity(canOpen ? 0.9 : 0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .gamePanel(radius: 14)
            .opacity(status == .locked ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canOpen || flight != nil)
        .accessibilityLabel("\(region.name), \(caption(for: region, status: status, stars: stars))")
    }

    private func caption(for region: Region, status: Status, stars: (earned: Int, total: Int)) -> String {
        switch status {
        case .locked: String(localized: "앞 권역을 끝내면 열려요")
        case .comingSoon: String(localized: "준비 중이에요")
        case .open, .done: String(localized: "도시 \(region.cityIDs.count)곳 · ★ \(stars.earned)/\(stars.total)")
        }
    }

    private func icon(for status: Status, canOpen: Bool) -> String {
        switch status {
        case .locked: "lock.fill"
        case .comingSoon: canOpen ? "chevron.right" : "hourglass"
        case .open: "chevron.right"
        case .done: "checkmark"
        }
    }
}
