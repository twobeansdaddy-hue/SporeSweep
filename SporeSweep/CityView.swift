import GameCore
import GameScene
import LevelData
import Progress
import SwiftUI

/// 도시 화면. 위에 랜드마크를 고정해 두고, 그 아래에 복원 화면으로 가는 버튼과 레벨 목록을 둔다(8장).
///
/// 레벨을 깨서 모은 별은 복원 화면에서 쓴다.
struct CityView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false
    @State private var showsRestoration = false
    @State private var showsLives = false
    @State private var showsDailyGift = false
    var onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(title: model.isLabMode ? "시험판" : (model.city?.name ?? "")) {
                IconButton(systemName: "map.fill", label: "지도") {
                    GameFeedback.shared.play(.tap)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        model.mapScreen = model.currentRegion.map { .region($0.id) } ?? .world
                    }
                }
            } trailing: {
                IconButton(systemName: "gearshape.fill", label: "설정") {
                    GameFeedback.shared.play(.tap)
                    showsSettings = true
                }
            }
            // 랜드마크와 복원 버튼은 늘 보이고, 레벨 목록만 움직인다.
            VStack(spacing: 12) {
                if let problem = model.problem {
                    Text(problem)
                        .font(.game(13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
                LandmarkPanel()
                if let landmark = model.city?.landmark {
                    LandmarkHeader(landmark: landmark)
                    if model.isFullyRestored {
                        // 다 복원했으면 더 갈 곳이 없으므로 버튼 대신 표시만 둔다.
                        Label("복원 완료!", systemImage: "checkmark.seal.fill")
                            .font(.game(17))
                            .foregroundStyle(GameTint.green.top)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(GameTint.green.lip.opacity(0.45), in: Capsule())
                            .overlay(Capsule().stroke(GameTint.green.top.opacity(0.5), lineWidth: 1.5))
                    } else {
                        restoreButton(landmark)
                    }
                }
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text(model.isLabMode ? "시험판 레벨" : "레벨")
                            .font(.game(18))
                            .foregroundStyle(.white)
                        Spacer()
                        if model.usesLives {
                            // 오늘의 선물. 받을 것이 있으면 통통 튄다.
                            Button {
                                GameFeedback.shared.play(.tap)
                                withAnimation { showsDailyGift = true }
                            } label: {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(model.canClaimDailyGift ? Palette.star : .white.opacity(0.55))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.3), in: Capsule())
                                    .symbolEffect(.bounce, options: .repeat(model.canClaimDailyGift ? 3 : 0), value: model.canClaimDailyGift)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("오늘의 선물")
                        }
                        if model.usesLives {
                            Button {
                                GameFeedback.shared.play(.tap)
                                withAnimation { showsLives = true }
                            } label: {
                                LivesBadge()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.levels.indices, id: \.self) { index in
                            LevelCell(
                                number: index + 1,
                                stars: model.progress.stars(for: model.levels[index].id),
                                isUnlocked: model.isUnlocked(index)
                            ) {
                                GameFeedback.shared.play(.tap)
                                // 생명이 없으면 판 대신 생명력 창을 띄운다.
                                if model.canStartLevel {
                                    onSelect(index)
                                } else {
                                    withAnimation { showsLives = true }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .gameBackground()
        .overlay {
            if showsDailyGift {
                DailyGiftView {
                    withAnimation { showsDailyGift = false }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // 오늘 처음 들어왔으면 선물 창을 띄운다. 비행이나 엔딩이 기다리고 있으면 미룬다.
            if model.canClaimDailyGift, model.pendingFlight == nil, !model.wantsEnding, model.mapScreen == nil {
                showsDailyGift = true
            }
        }
        .overlay {
            if showsLives {
                LivesPopup {
                    withAnimation { showsLives = false }
                }
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showsRestoration) {
            RestorationView()
        }
        // 다른 도시로 옮기면 복원 화면을 닫는다.
        .onChange(of: model.city?.id) {
            showsRestoration = false
        }
    }

    /// 복원 화면으로 가는 버튼. 지금 복원할 수 있는 부위가 있으면 눈에 띄게 한다.
    private func restoreButton(_ landmark: Landmark) -> some View {
        let canRestore = landmark.parts.contains { model.blocker(for: $0) == nil }
        return Button {
            GameFeedback.shared.play(.tap)
            showsRestoration = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                Text("복원하러 가기")
                if canRestore {
                    Text("지금 할 수 있어요!")
                        .font(.game(12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.28), in: Capsule())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
            }
        }
        .buttonStyle(ChunkyButtonStyle(tint: canRestore ? .pink : .blue, fills: true))
        .accessibilityLabel(canRestore ? "복원하러 가기, 지금 복원할 수 있는 부위가 있어요" : "복원하러 가기")
    }
}

/// 복원 화면. 위에 랜드마크를 고정해 두고, 그 아래의 부위 목록만 움직인다(8장).
struct RestorationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(title: String(localized: "\(model.city?.landmark.name ?? "") 복원")) {
                IconButton(systemName: "chevron.left", label: "도시로 돌아가기") {
                    GameFeedback.shared.play(.tap)
                    dismiss()
                }
            } trailing: {
                EmptyView()
            }
            VStack(spacing: 12) {
                LandmarkPanel()
                if let landmark = model.city?.landmark {
                    LandmarkHeader(landmark: landmark)
                }
            }
            .padding(.horizontal, 16)

            ScrollView {
                if let landmark = model.city?.landmark {
                    RestorationList(landmark: landmark)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .gameBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            // 마지막 부위를 복원하면 선물을 알린다.
            if model.justCompletedLandmark {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Text("복원 완료!")
                            .font(.game(26))
                            .foregroundStyle(Palette.star)
                        Text("\(model.city?.landmark.name ?? "")을 되살렸어요. 선물로 시작 부스터를 받았어요!")
                            .font(.game(15))
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            ForEach(AppModel.completionRewards, id: \.self) { booster in
                                BoosterIcon(booster: booster, size: 44)
                            }
                        }
                        Button("좋아요!") {
                            GameFeedback.shared.play(.tap)
                            model.justCompletedLandmark = false
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 18))
                        .padding(.top, 4)
                    }
                    .foregroundStyle(.white)
                    .padding(22)
                    .gamePanel(radius: 22)
                    .padding(28)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.justCompletedLandmark)
    }
}

/// 랜드마크 그림. 도시 화면과 복원 화면 위에 같은 크기로 놓는다.
private struct LandmarkPanel: View {
    @Environment(AppModel.self) private var model

    /// 랜드마크 그림에 쓰는 복원 부위. 디버그 빌드에서는 실행 인자 `-landmarkParts gate,sky`로
    /// 그림만 바꿔 볼 수 있다(`all`은 전부).
    private var shownParts: Set<String> {
        #if DEBUG
        if let list = UserDefaults.standard.string(forKey: "landmarkParts") {
            return list == "all" ? (art?.partIDs ?? []) : Set(list.split(separator: ",").map(String.init))
        }
        #endif
        return model.restoredParts
    }

    private var art: LandmarkArt? {
        model.city.flatMap { LandmarkArt.art(for: $0.id) }
    }

    var body: some View {
        Group {
            if let art {
                LandmarkView(restored: shownParts, art: art)
            } else {
                Palette.panel
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 2))
    }
}

/// 랜드마크의 이름과 복원한 부위 수, 쓸 수 있는 별.
private struct LandmarkHeader: View {
    @Environment(AppModel.self) private var model
    var landmark: Landmark

    var body: some View {
        let restored = landmark.parts.count { model.restoredParts.contains($0.id) }
        VStack(spacing: 5) {
            Text(model.isFullyRestored ? landmark.name : String(localized: "\(landmark.name) · \(restored)/\(landmark.parts.count) 복원"))
                .font(.game(20))
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Palette.star)
                Text("쓸 수 있는 별 \(model.availableStars)개")
                    .foregroundStyle(Palette.star)
                Text("· 모은 별 \(model.earnedStars)/\(model.levels.count * 3)")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(.game(14, weight: .bold))
        }
        .foregroundStyle(.white)
    }
}

/// 복원할 부위 목록. 별이 충분한 부위를 골라 복원한다.
private struct RestorationList: View {
    @Environment(AppModel.self) private var model
    var landmark: Landmark

    var body: some View {
        VStack(spacing: 10) {
            ForEach(landmark.parts) { part in
                row(part)
            }
        }
    }

    private func row(_ part: Landmark.Part) -> some View {
        let blocker = model.blocker(for: part)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(part.name)
                    .font(.game(17, weight: .bold))
                    .foregroundStyle(.white)
                if let note = note(for: blocker) {
                    Text(note)
                        .font(.game(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            if blocker == .alreadyRestored {
                Label("복원 완료", systemImage: "checkmark.circle.fill")
                    .font(.game(14))
                    .foregroundStyle(GameTint.green.top)
            } else {
                Button {
                    GameFeedback.shared.play(.restore)
                    GameFeedback.shared.haptic(.success)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        model.restore(part)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                        Text("\(part.cost)")
                        Text("복원")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(tint: .gold, size: 14))
                .disabled(blocker != nil)
                .accessibilityLabel("\(part.name) 복원, 별 \(part.cost)개")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .gamePanel(radius: 14)
    }

    /// 복원할 수 없는 이유를 한 줄로 알려준다.
    private func note(for blocker: RestoreBlocker?) -> String? {
        switch blocker {
        case .requires(let id):
            let name = landmark.parts.first { $0.id == id }?.name ?? id
            return String(localized: "\(name)부터 복원해야 해요")
        case .notEnoughStars(let short):
            return String(localized: "별이 \(short)개 더 필요해요")
        case .unknownPart, .alreadyRestored, nil:
            return nil
        }
    }
}

private struct LevelCell: View {
    var number: Int
    var stars: Int
    var isUnlocked: Bool
    var action: () -> Void

    /// 다음에 할 레벨은 분홍, 깬 레벨은 파랑, 잠긴 레벨은 회색이다.
    private var tint: GameTint {
        guard isUnlocked else { return .slate }
        return stars == 0 ? .pink : .blue
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isUnlocked {
                    Text("\(number)")
                        .font(.game(26))
                    StarsView(count: stars, size: 13)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .heavy))
                        .padding(.vertical, 3)
                    Text("\(number)")
                        .font(.game(13))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 66)
        }
        .buttonStyle(LevelCellStyle(tint: tint))
        .opacity(isUnlocked ? 1 : 0.55)
        .disabled(!isUnlocked)
        .accessibilityLabel(isUnlocked ? "레벨 \(number), 별 \(stars)개" : "레벨 \(number), 잠김")
    }
}

private struct LevelCellStyle: ButtonStyle {
    var tint: GameTint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(ChunkyShape(tint: tint, radius: 16, isPressed: configuration.isPressed))
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
