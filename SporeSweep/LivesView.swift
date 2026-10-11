import GameScene
import Progress
import SwiftUI

/// 생명력 표시. 하트와 개수, 가득 차지 않았으면 다음 하나까지 남은 시간을 보여준다(6장).
struct LivesBadge: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // 시간이 지나면 저절로 차므로 1초마다 다시 그린다.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let count = model.lives(at: context.date)
            HStack(spacing: 5) {
                Image(systemName: count > 0 ? "heart.fill" : "heart.slash.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(GameTint.pink.top)
                Text("\(count)")
                    .font(.game(15).monospacedDigit())
                if let wait = model.timeUntilNextLife(at: context.date) {
                    Text(Self.clock(wait))
                        .font(.game(12).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.3), in: Capsule())
            .accessibilityElement()
            .accessibilityLabel("생명 \(count)개")
        }
    }

    /// 남은 시간을 `분:초`로 적는다.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded(.up)), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// 생명력 창. 지금 가진 수와 다음 하나까지 남은 시간을 보여주고, 모자라면 광고를 보고 하나를 받게 한다.
struct LivesPopup: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    @State private var showsAd = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let count = model.lives(at: context.date)
                let left = model.adLivesLeft(at: context.date)
                VStack(spacing: 12) {
                    Text(count > 0 ? "생명" : "생명이 다 떨어졌어요")
                        .font(.game(24))
                        .foregroundStyle(Palette.star)
                    HStack(spacing: 6) {
                        ForEach(0..<Lives.maximum, id: \.self) { index in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(index < count ? GameTint.pink.top : Color.white.opacity(0.18))
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("생명 \(count)개")
                    if let wait = model.timeUntilNextLife(at: context.date) {
                        Text("다음 생명까지 \(LivesBadge.clock(wait))")
                            .font(.game(15).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("가득 찼어요")
                            .font(.game(15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Text("판에서 지면 하나 줄고, \(Int(Lives.refillInterval / 60))분마다 하나씩 차요.")
                        .font(.game(13))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        if count < Lives.maximum {
                            Button {
                                GameFeedback.shared.play(.tap)
                                showsAd = true
                            } label: {
                                Label(left > 0 ? "광고 보고 생명 +1" : "오늘은 광고로 더 받을 수 없어요", systemImage: "play.rectangle.fill")
                            }
                            .buttonStyle(ChunkyButtonStyle(tint: .pink, fills: true))
                            .disabled(left == 0)
                        }
                        Button("닫기") {
                            GameFeedback.shared.play(.tap)
                            onClose()
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .slate, fills: true))
                    }
                    .padding(.top, 6)
                }
                .foregroundStyle(.white)
                .padding(24)
                .frame(maxWidth: 320)
                .gamePanel(radius: 24)
                .padding(28)
            }
            if showsAd {
                RewardedAdView(id: "life", reward: String(localized: "생명 +1")) { watched in
                    showsAd = false
                    if watched, model.grantLifeFromAd() {
                        GameFeedback.shared.play(.restore)
                        GameFeedback.shared.haptic(.success)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

/// 보상형 광고(6장). 끝까지 보면 보상을 준다.
///
/// 실제 광고는 `RewardedAds`가 이 화면 위에 띄운다. 이 화면은 그 뒤에 깔리는 검은 바탕이고,
/// 광고를 불러오는 동안과 불러오지 못했을 때의 안내를 보여준다.
/// 디버그 빌드에서는 광고를 불러오지 못하면 자리 표시 광고(3초)로 대신한다.
struct RewardedAdView: View {
    /// 기록에 남길 보상의 이름(life, moves, tool_이름).
    var id: String
    /// 다 보면 받는 것. 화면에 적는다.
    var reward: String
    var onFinish: (_ watched: Bool) -> Void

    private enum Phase {
        case loading, showing, placeholder, failed
    }

    /// 광고를 기다려 주는 시간(초).
    private static let patience: Double = 6
    /// 자리 표시 광고의 길이(초).
    private static let length = 3
    @State private var phase = Phase.loading
    @State private var hasStarted = false
    @State private var remaining = RewardedAdView.length

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                switch phase {
                case .loading:
                    ProgressView()
                        .tint(.white)
                    Text("광고를 불러오는 중이에요")
                        .font(.game(17))
                case .showing:
                    EmptyView()
                case .placeholder:
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("광고 자리예요")
                        .font(.game(24))
                    Text("아직 실제 광고는 나오지 않아요.\n\(remaining)초 뒤에 \(reward)을 받아요.")
                        .font(.game(15))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                case .failed:
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("광고를 불러오지 못했어요")
                        .font(.game(22))
                    Text("잠시 뒤에 다시 해 보세요.")
                        .font(.game(15))
                        .foregroundStyle(.white.opacity(0.7))
                    Button("닫기") {
                        GameFeedback.shared.play(.tap)
                        onFinish(false)
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .slate))
                    .padding(.top, 8)
                }
            }
            .foregroundStyle(.white)
        }
        .task {
            // 화면이 다시 나타나도 광고를 또 부르지 않는다.
            guard !hasStarted else { return }
            hasStarted = true
            guard RewardedAds.isEnabled, await RewardedAds.shared.waitUntilReady(seconds: Self.patience) else {
                #if DEBUG
                print("[광고] 준비되지 않아 자리 표시로 넘어감 (쓰는 중: \(RewardedAds.isEnabled))")
                #endif
                await fallBack()
                return
            }
            phase = .showing
            // 광고의 소리와 겹치지 않게 음악을 멈춘다.
            GameMusic.shared.pause()
            RewardedAds.shared.show { outcome in
                GameMusic.shared.resume()
                switch outcome {
                case .rewarded:
                    Tracker.log(.adReward(reward: id))
                    onFinish(true)
                case .skipped:
                    Tracker.log(.adSkip(reward: id))
                    onFinish(false)
                case .failed:
                    Tracker.log(.adFail(reward: id))
                    phase = .failed
                }
            }
        }
    }

    /// 실제 광고를 띄우지 못했을 때. 디버그 빌드에서는 자리 표시 광고를 보여주고 보상을 준다.
    private func fallBack() async {
        #if DEBUG
        phase = .placeholder
        while remaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            remaining -= 1
        }
        Tracker.log(.adReward(reward: id))
        onFinish(true)
        #else
        Tracker.log(.adFail(reward: id))
        phase = .failed
        #endif
    }
}
