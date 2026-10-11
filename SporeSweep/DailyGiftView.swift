import GameCore
import GameScene
import Progress
import SwiftUI

/// 일일 보상 창(6장). 이레치 선물을 늘어놓고 오늘 것을 받게 한다.
struct DailyGiftView: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    /// 방금 받은 날. 받고 나면 인사를 보여준다.
    @State private var claimedDay: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        let today = claimedDay ?? model.dailyGiftDay
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                Text("오늘의 선물")
                    .font(.game(24))
                    .foregroundStyle(Palette.star)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(1...DailyGift.cycle, id: \.self) { day in
                        tile(day: day, today: today)
                    }
                }
                Text("매일 들르면 선물이 커져요. 하루를 거르면 처음부터예요.")
                    .font(.game(12))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                if claimedDay == nil {
                    Button("선물 받기") {
                        if model.claimDailyGift() != nil {
                            GameFeedback.shared.play(.restore)
                            GameFeedback.shared.haptic(.success)
                            withAnimation(.spring(duration: 0.3)) { claimedDay = today }
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 19, fills: true))
                } else {
                    Button("내일 또 만나요!") {
                        GameFeedback.shared.play(.tap)
                        onClose()
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .blue, fills: true))
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: 340)
            .gamePanel(radius: 24)
            .padding(24)
        }
    }

    /// 하루치 선물 한 칸. 지난 날은 체크, 오늘은 밝게, 남은 날은 흐리게 보여준다.
    private func tile(day: Int, today: Int) -> some View {
        let isToday = day == today
        let isPast = day < today || (isToday && claimedDay != nil)
        return VStack(spacing: 4) {
            Text(isToday ? "오늘" : "\(day)일째")
                .font(.game(11))
                .foregroundStyle(isToday ? Palette.star : .white.opacity(0.7))
            HStack(spacing: 1) {
                ForEach(Array(DailyGift.rewards[day - 1].enumerated()), id: \.offset) { _, item in
                    icon(item, size: DailyGift.rewards[day - 1].count > 2 ? 17 : 28)
                }
            }
            .frame(height: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isToday ? GameTint.pink.lip.opacity(0.55) : Color.black.opacity(0.28),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isToday ? GameTint.pink.top : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(GameTint.green.top, .white)
                    .offset(x: 4, y: -4)
            }
        }
        .opacity(isPast ? 0.55 : 1)
        .accessibilityElement()
        .accessibilityLabel("\(day)일째")
    }

    @ViewBuilder
    private func icon(_ item: String, size: CGFloat) -> some View {
        let parts = item.split(separator: ":").map(String.init)
        if parts.first == "booster", let booster = Booster(rawValue: parts[1]) {
            BoosterIcon(booster: booster, size: size)
        } else if parts.first == "tool", let tool = Tool(rawValue: parts[1]) {
            ToolIcon(tool: tool, size: size)
        } else {
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.8, weight: .black))
                .foregroundStyle(GameTint.pink.top)
                .accessibilityLabel("생명 가득")
        }
    }
}
