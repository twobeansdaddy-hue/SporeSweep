import GameScene
import SwiftUI

/// 인트로. 게임을 처음 시작할 때 이야기를 그림 다섯 장으로 보여준다(2장).
///
/// 그림은 천천히 움직이고 아래에 설명이 뜬다. 화면을 누르면 다음 장으로 넘어가고, 언제든 건너뛸 수 있다.
struct IntroView: View {
    /// 인트로가 끝났거나 건너뛰었을 때.
    var onFinish: () -> Void

    struct Scene {
        var image: String
        var caption: String
        /// 장면이 나올 때 한 번 나는 소리.
        var sound: GameSound
        /// 화면 위로 포자가 떨어지는 장면인지.
        var rainsSpores = false
        /// 그림이 화면보다 넓어서 좌우가 잘린다. 처음과 끝에 그림의 어디를 보여줄지를 -1(왼쪽 끝)에서
        /// 1(오른쪽 끝)로 적는다. 둘이 다르면 그 사이를 천천히 훑는다.
        var pan: (from: CGFloat, to: CGFloat) = (0, 0)
        /// 처음과 끝의 크기. 1이면 화면에 꼭 맞는다.
        var zoom: (from: CGFloat, to: CGFloat) = (1, 1.1)
    }

    static let scenes: [Scene] = [
        Scene(image: "intro_1", caption: "푸르고 평화롭던 지구.", sound: .introEarth, pan: (-0.25, 0.25), zoom: (1.08, 1)),
        Scene(image: "intro_2", caption: "어느 날, 장난꾸러기 외계인들이 나타나 끈적한 오염 물질을 마구 뿌렸어요!", sound: .introInvasion, rainsSpores: true),
        // 양옆의 에펠탑과 자유의 여신상까지 보이도록 왼쪽에서 오른쪽으로 훑는다.
        Scene(image: "intro_3", caption: "오염 물질은 온 세상으로 번졌고, 나라마다 아끼던 랜드마크가 망가져 버렸어요.", sound: .introRuin, rainsSpores: true, pan: (-1, 1), zoom: (1, 1)),
        Scene(image: "intro_4", caption: "하지만 걱정 마세요. 정화 대원이 출동했으니까요!", sound: .introHero, zoom: (1, 1.08)),
        // 정화 대원이 그림 왼쪽에 서 있다.
        Scene(image: "intro_5", caption: "첫 번째 목적지는 서울, 숭례문! 오염 물질을 격리 컨테이너로 내려보내고 도시를 되살려 주세요.", sound: .introArrival, pan: (-1, -0.45), zoom: (1, 1)),
    ]

    /// 한 장을 보여주는 시간(초). 누르지 않아도 이만큼 지나면 다음 장으로 넘어간다.
    static let sceneDuration: Double = 6

    @State private var index = 0

    private var isLast: Bool { index == Self.scenes.count - 1 }

    var body: some View {
        let scene = Self.scenes[index]
        ZStack {
            Color.black.ignoresSafeArea()
            IntroPicture(scene: scene)
                .id(index)
                .transition(.opacity)
            if scene.rainsSpores {
                SporeRain()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button("건너뛰기") {
                        GameFeedback.shared.play(.tap)
                        onFinish()
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .slate, size: 14))
                    .opacity(isLast ? 0 : 1)
                }
                Spacer()
                VStack(spacing: 12) {
                    Text(LocalizedStringKey(scene.caption))
                        .font(.game(20))
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .id(index)
                        .transition(.opacity)
                    if isLast {
                        Button("출동!") {
                            GameFeedback.shared.play(.tap)
                            onFinish()
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 20))
                    } else {
                        HStack(spacing: 6) {
                            ForEach(Self.scenes.indices, id: \.self) { dot in
                                Circle()
                                    .fill(dot == index ? Palette.material : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
                .padding(18)
                .gamePanel(radius: 22)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        // 누르지 않아도 조금 뒤에 다음 장으로 넘어간다. 마지막 장은 버튼을 눌러야 끝난다.
        .task(id: index) {
            guard !isLast else { return }
            try? await Task.sleep(for: .seconds(Self.sceneDuration))
            if !Task.isCancelled {
                advance(silently: true)
            }
        }
        .onAppear {
            GameMusic.shared.play(.intro)
            GameFeedback.shared.play(scene.sound)
        }
        // 장면이 바뀔 때마다 그 장면의 소리를 낸다.
        .onChange(of: index) {
            GameFeedback.shared.play(Self.scenes[index].sound)
        }
        .accessibilityAction(named: "다음") { advance() }
    }

    private func advance(silently: Bool = false) {
        guard !isLast else { return }
        if !silently {
            GameFeedback.shared.play(.tap)
        }
        withAnimation(.easeInOut(duration: 0.6)) {
            index += 1
        }
    }
}

/// 인트로의 그림 한 장. 화면 높이에 맞춰 그리고, 보는 동안 천천히 훑거나 커진다.
private struct IntroPicture: View {
    var scene: IntroView.Scene
    @State private var isMoving = false

    var body: some View {
        GeometryReader { geometry in
            // 그림은 2:3이라 세로로 긴 화면에서는 좌우가 넘친다. 넘친 만큼만 좌우로 움직일 수 있다.
            let width = max(geometry.size.height * 2 / 3, geometry.size.width)
            let overflow = (width - geometry.size.width) / 2
            let position = isMoving ? scene.pan.to : scene.pan.from
            Image(scene.image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: geometry.size.height)
                .offset(x: -position * overflow)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(isMoving ? scene.zoom.to : scene.zoom.from)
                .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: IntroView.sceneDuration + 1)) {
                isMoving = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// 화면 위에서 아래로 떨어지는 포자. 외계인이 오염 물질을 뿌리는 장면에 겹친다.
private struct SporeRain: View {
    /// 포자마다의 가로 자리(0...1), 크기, 속도, 처음 높이, 모양.
    private static let drops: [(x: CGFloat, size: CGFloat, speed: CGFloat, phase: CGFloat, shape: Int)] = [
        (0.08, 34, 0.11, 0.10, 0), (0.22, 22, 0.16, 0.55, 3), (0.35, 44, 0.09, 0.80, 1), (0.47, 18, 0.19, 0.30, 0),
        (0.58, 30, 0.13, 0.65, 2), (0.70, 24, 0.17, 0.05, 3), (0.82, 40, 0.10, 0.45, 0), (0.93, 20, 0.15, 0.90, 4),
        (0.15, 16, 0.21, 0.70, 0), (0.64, 14, 0.23, 0.20, 0), (0.40, 26, 0.14, 0.95, 3), (0.88, 16, 0.20, 0.60, 0),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for drop in Self.drops {
                    let image = context.resolve(Image("landmark_spore_\(drop.shape)"))
                    // 화면 위에서 아래로 한 바퀴 돌고 다시 위에서 나온다.
                    let travel = (CGFloat(time) * drop.speed + drop.phase).truncatingRemainder(dividingBy: 1)
                    let y = travel * (size.height * 0.8 + drop.size * 2) - drop.size
                    let x = drop.x * size.width + sin(CGFloat(time) * 1.3 + drop.phase * 9) * 8
                    var turned = context
                    turned.opacity = 0.95
                    turned.translateBy(x: x, y: y)
                    turned.rotate(by: .degrees(Double(sin(CGFloat(time) + drop.phase * 5)) * 12))
                    turned.draw(image, in: CGRect(x: -drop.size / 2, y: -drop.size / 2, width: drop.size, height: drop.size))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
