import GameScene
import SwiftUI

/// 타이틀 화면. 앱을 켜면 처음 보이고, "시작"을 누르면 게임으로 들어간다.
struct TitleView: View {
    var onStart: () -> Void
    @State private var isFloating = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image("title_art")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                logo
                    .padding(.top, 28)
                    .offset(y: isFloating ? -5 : 5)
                Spacer()
                Button("시작") {
                    GameFeedback.shared.play(.tap)
                    onStart()
                }
                .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 26))
                .scaleEffect(isFloating ? 1.04 : 0.98)
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            GameMusic.shared.play(.intro)
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }

    /// 게임 이름. 게임의 포자와 같은 분홍 젤리 글자로 그린 그림이다.
    private var logo: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 330)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
            .accessibilityLabel("Spore Sweep")
    }
}
