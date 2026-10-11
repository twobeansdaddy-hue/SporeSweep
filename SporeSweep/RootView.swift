import GameScene
import LevelData
import SwiftUI

/// 앱의 뼈대. 타이틀 화면에서 시작해, 처음이면 인트로를 거쳐 도시 화면으로 간다.
/// 도시 화면에서 레벨을 고르면 게임 화면으로 들어간다.
struct RootView: View {
    /// 지금 보여주는 단계.
    enum Phase {
        case title, intro, main
    }

    @Environment(AppModel.self) private var model
    @State private var phase: Phase = RootView.initialPhase()
    @State private var path: [Int] = RootView.initialPath()
    @Environment(\.scenePhase) private var scenePhase

    private static let seenIntroKey = "seenIntro"

    /// 디버그 빌드에서 실행 인자 `-level 숫자`를 주면 잠금과 상관없이 그 레벨로 바로 들어간다.
    private static func initialPath() -> [Int] {
        #if DEBUG
        let level = UserDefaults.standard.integer(forKey: "level")
        if level > 0 {
            return [level - 1]
        }
        #endif
        return []
    }

    /// 디버그 빌드에서는 실행 인자로 타이틀을 건너뛸 수 있다. `-skipTitle 1`이나 화면을 바로 여는
    /// 인자(`-level`, `-allStars`, `-landmarkParts`)를 주면 도시 화면에서, `-intro 1`을 주면 인트로에서 시작한다.
    private static func initialPhase() -> Phase {
        #if DEBUG
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "intro") {
            return .intro
        }
        if defaults.bool(forKey: "skipTitle") || defaults.integer(forKey: "level") > 0
            || defaults.bool(forKey: "allStars") || defaults.string(forKey: "landmarkParts") != nil
            || defaults.string(forKey: "city") != nil || defaults.bool(forKey: "map") || defaults.bool(forKey: "flight")
            || defaults.bool(forKey: "world") || defaults.string(forKey: "region") != nil || defaults.bool(forKey: "ending") {
            return .main
        }
        #endif
        return .title
    }

    var body: some View {
        ZStack {
            switch phase {
            case .title:
                TitleView {
                    // 인트로는 처음 한 번만 보여준다. 설정에서 다시 볼 수 있다.
                    let seen = UserDefaults.standard.bool(forKey: Self.seenIntroKey)
                    withAnimation(.easeInOut(duration: 0.5)) {
                        phase = seen ? .main : .intro
                    }
                }
                .transition(.opacity)
            case .intro:
                IntroView {
                    if !UserDefaults.standard.bool(forKey: Self.seenIntroKey) {
                        Tracker.log(.introDone)
                    }
                    UserDefaults.standard.set(true, forKey: Self.seenIntroKey)
                    withAnimation(.easeInOut(duration: 0.5)) {
                        phase = .main
                    }
                }
                .transition(.opacity)
            case .main:
                main
                    .transition(.opacity)
            }
            // 엔딩. 결과 화면을 닫고 도시 화면으로 돌아온 뒤에 뜬다.
            if phase == .main, model.wantsEnding, path.isEmpty {
                EndingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        model.wantsEnding = false
                        model.isFirstEnding = false
                    }
                    GameMusic.shared.play(.city)
                }
                .onAppear {
                    Tracker.log(.ending(first: model.isFirstEnding))
                }
                .transition(.opacity)
                .zIndex(2)
            }
            // 지도. 도시를 고를 때와, 도시의 레벨을 모두 깨서 다음 도시로 날아갈 때 뜬다.
            // 비행은 결과 화면을 닫고 도시 화면으로 돌아온 뒤에 시작한다.
            if phase == .main, let screen = shownMap {
                let close = {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        model.pendingFlight = nil
                        model.mapScreen = nil
                        path = []
                    }
                }
                Group {
                    switch screen {
                    case .world:
                        WorldView(flight: model.pendingFlight.flatMap { model.crossesRegions($0) ? $0 : nil }, onClose: close)
                    case .region(let id):
                        if let region = model.regions.first(where: { $0.id == id }) {
                            MapView(region: region, flight: model.pendingFlight, onClose: close)
                        }
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onChange(of: scenePhase) {
            // 앱 밖에서 음악을 틀거나 껐을 수 있으므로 돌아올 때 다시 본다.
            if scenePhase == .active {
                GameMusic.shared.refresh()
            }
        }
        .onChange(of: model.wantsIntro) {
            // 설정에서 인트로를 다시 보겠다고 했을 때.
            if model.wantsIntro {
                model.wantsIntro = false
                path = []
                withAnimation(.easeInOut(duration: 0.5)) {
                    phase = .intro
                }
            }
        }
    }

    /// 지금 보여줄 지도 화면. 비행이 기다리고 있으면 출발 도시의 권역 지도이고, 다른 권역으로 가는 비행이면 세계 지도다.
    private var shownMap: AppModel.MapScreen? {
        if let flight = model.pendingFlight, path.isEmpty, let region = RegionCatalog.region(ofCity: flight.from) {
            return model.crossesRegions(flight) ? .world : .region(region.id)
        }
        return model.mapScreen
    }

    private var main: some View {
        NavigationStack(path: $path) {
            CityView { index in
                path = [index]
            }
            .navigationDestination(for: Int.self) { index in
                GameView(levelIndex: index) {
                    path = []
                }
            }
        }
        .tint(.white)
        // 도시 화면과 플레이 화면의 배경 음악이 다르다.
        .onAppear { playMusic() }
        .onChange(of: path) { playMusic() }
    }

    private func playMusic() {
        GameMusic.shared.play(path.isEmpty ? .city : .game)
    }
}

/// 앱 전체에서 쓰는 색.
enum Palette {
    static let background = Color(red: 0.09, green: 0.11, blue: 0.14)
    static let panel = Color(red: 0.17, green: 0.19, blue: 0.31)
    /// 화면 전체의 바탕. 짙은 남색에서 보라로 내려간다.
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.08, green: 0.10, blue: 0.20), Color(red: 0.17, green: 0.10, blue: 0.27)],
        startPoint: .top, endPoint: .bottom
    )
    static let star = Color(red: 0.98, green: 0.80, blue: 0.25)
    static let material = Color(red: 1.0, green: 0.22, blue: 0.58)
}

/// 별 세 개. 받은 만큼 채운다.
struct StarsView: View {
    var count: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: size * 0.12) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(index < count ? Palette.star : Color.black.opacity(0.35))
                    .shadow(color: index < count ? Color(red: 0.72, green: 0.42, blue: 0.05) : .clear, radius: 0, y: size * 0.08)
                    // 가운데 별을 조금 올려 부채꼴로 놓는다.
                    .offset(y: index == 1 ? -size * 0.12 : 0)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("별 \(count)개")
    }
}
