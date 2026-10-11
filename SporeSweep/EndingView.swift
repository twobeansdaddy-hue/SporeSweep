import GameScene
import SwiftUI

/// 엔딩 화면(2장). 마지막 도시의 레벨을 모두 깨면 한 번 뜨고, 설정에서 다시 볼 수 있다.
///
/// 깨끗해진 지구 앞에서 정화 대원이 손을 흔드는 그림 위에, 그동안의 기록을 보여준다.
struct EndingView: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void

    @State private var zoom = false
    @State private var step = 0

    var body: some View {
        GeometryReader { geometry in
            Image("ending")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                // 그림이 천천히 다가온다.
                .scaleEffect(zoom ? 1.08 : 1, anchor: .init(x: 0.5, y: 0.35))
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .overlay(alignment: .top) {
            if step >= 1 {
                Text("지구 정화 완료!")
                    .font(.game(34))
                    .foregroundStyle(Palette.star)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .gamePanel(radius: 24)
                    .padding(.top, 64)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                if step >= 2 {
                    Text("외계인들은 꼬리를 내리고 돌아갔어요.\n온 세상의 랜드마크가 다시 빛나요.\n고마워요, 정화 대원!")
                        .font(.game(17))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
                if step >= 3 {
                    HStack(spacing: 8) {
                        stat("도시", String(localized: "\(model.cities.count)곳"))
                        stat("모은 별", "\(model.totalStars.earned)/\(model.totalStars.total)")
                        stat("복원한 랜드마크", "\(model.restoredLandmarks)/\(model.cities.count)")
                    }
                    .transition(.opacity)
                    if model.restoredLandmarks < model.cities.count {
                        Text("아직 복원하지 못한 랜드마크가 있어요. 별을 더 모아 마저 되살려 보세요!")
                            .font(.game(13))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    Button("계속하기") {
                        GameFeedback.shared.play(.tap)
                        onClose()
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19))
                    .padding(.top, 2)
                    .transition(.opacity)
                }
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity)
            .gamePanel(radius: 22)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .opacity(step >= 2 ? 1 : 0)
        }
        .task {
            GameMusic.shared.play(.intro)
            withAnimation(.easeInOut(duration: 12)) { zoom = true }
            try? await Task.sleep(for: .seconds(0.8))
            GameFeedback.shared.play(.win)
            GameFeedback.shared.haptic(.success)
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { step = 1 }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.5)) { step = 2 }
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.5)) { step = 3 }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.game(17).monospacedDigit())
                .foregroundStyle(Palette.star)
            Text(LocalizedStringKey(title))
                .font(.game(11))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
    }
}
