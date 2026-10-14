import GameScene
import SwiftUI

/// 설정 화면(10장 AppUI). 배경 음악, 효과음, 햅틱을 켜고 끄고, 설명과 진행을 초기화한다.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isMusicEnabled = GameMusic.shared.isMusicEnabled
    @State private var isSoundEnabled = GameFeedback.shared.isSoundEnabled
    @State private var isHapticsEnabled = GameFeedback.shared.isHapticsEnabled
    @State private var confirmsReset = false
    @State private var didResetTutorials = false

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(title: "설정") {
                EmptyView()
            } trailing: {
                IconButton(systemName: "xmark", label: "닫기") {
                    GameFeedback.shared.play(.tap)
                    dismiss()
                }
            }
            .padding(.top, 10)

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        VStack(spacing: 14) {
                            Toggle("배경 음악", isOn: $isMusicEnabled)
                            Toggle("효과음", isOn: $isSoundEnabled)
                            Toggle("진동", isOn: $isHapticsEnabled)
                        }
                        .toggleStyle(ChunkyToggleStyle())
                        .padding(16)
                        .gamePanel()
                        note("다른 앱으로 음악을 듣고 있으면 배경 음악은 나오지 않아요.")
                    }

                    // iCloud 저장은 권한을 넣기 전까지 동작하지 않으므로 스위치를 보이지 않는다.
                    if CloudSync.isAvailable {
                        VStack(spacing: 6) {
                            Toggle("iCloud에 저장", isOn: Binding(get: { model.isCloudEnabled }, set: { model.isCloudEnabled = $0 }))
                                .toggleStyle(ChunkyToggleStyle())
                                .padding(16)
                                .gamePanel()
                            note("기기를 바꿔도 진행이 이어져요. 같은 Apple 계정으로 로그인한 기기끼리 맞춰져요.")
                        }
                    }

                    VStack(spacing: 6) {
                        Button(didResetTutorials ? "다음 판부터 다시 보여 드려요" : "레벨 설명 다시 보기") {
                            GameFeedback.shared.play(.tap)
                            model.resetTutorials()
                            didResetTutorials = true
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .blue, fills: true))
                        .disabled(didResetTutorials)
                        note("새 규칙이 나오는 레벨을 시작할 때 설명이 다시 떠요.")
                    }

                    Button("인트로 다시 보기") {
                        GameFeedback.shared.play(.tap)
                        dismiss()
                        model.wantsIntro = true
                    }
                    .buttonStyle(ChunkyButtonStyle(tint: .blue, fills: true))

                    if model.hasClearedEverything {
                        Button("엔딩 다시 보기") {
                            GameFeedback.shared.play(.tap)
                            dismiss()
                            model.wantsEnding = true
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .blue, fills: true))
                    }

                    #if DEBUG
                    VStack(spacing: 6) {
                        Button(model.isLabMode ? "서울로 돌아가기" : "시험판 레벨 해 보기") {
                            GameFeedback.shared.play(.tap)
                            model.setLabMode(!model.isLabMode)
                            dismiss()
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .gold, fills: true))
                        note("새 규칙을 시험하는 레벨 3개와 레벨 생성기로 만든 견본 16개예요. 기록은 남지 않아요.")
                    }
                    VStack(spacing: 6) {
                        Button("엔딩 보기") {
                            GameFeedback.shared.play(.tap)
                            dismiss()
                            model.wantsEnding = true
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .gold, fills: true))
                        note("다 깨지 않아도 엔딩을 볼 수 있어요. 기록은 지금 모은 만큼만 나와요. 개발용 빌드에만 있어요.")
                    }
                    VStack(spacing: 8) {
                        Text("도시 바로 가기")
                            .font(.game(15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(model.cities) { city in
                                Button(city.name) {
                                    GameFeedback.shared.play(.tap)
                                    model.visit(cityID: city.id)
                                    dismiss()
                                }
                                .buttonStyle(ChunkyButtonStyle(tint: model.city?.id == city.id ? .pink : .gold, size: 14, fills: true))
                            }
                        }
                        note("잠금과 상관없이 그 도시로 가고, 그 도시의 레벨이 모두 열려요. 앱을 다시 켜면 원래대로 돌아가요. 거기서 깬 판의 기록은 남아요. 개발용 빌드에만 있어요.")
                    }
                    .padding(14)
                    .gamePanel()
                    #endif

                    VStack(spacing: 6) {
                        Button("처음부터 다시 하기") {
                            GameFeedback.shared.play(.tap)
                            confirmsReset = true
                        }
                        .buttonStyle(ChunkyButtonStyle(tint: .slate, fills: true))
                        note("레벨 기록과 복원한 랜드마크가 모두 지워져요.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .gameBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: isMusicEnabled) {
            GameMusic.shared.isMusicEnabled = isMusicEnabled
        }
        .onChange(of: isSoundEnabled) {
            GameFeedback.shared.isSoundEnabled = isSoundEnabled
            GameFeedback.shared.play(.tap)
        }
        .onChange(of: isHapticsEnabled) {
            GameFeedback.shared.isHapticsEnabled = isHapticsEnabled
            GameFeedback.shared.haptic(.light)
        }
        .overlay {
            // 시스템 알림창 대신 게임 안의 판으로 묻는다.
            if confirmsReset {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Text("정말 처음부터 다시 할까요?")
                            .font(.game(19))
                        Text("레벨 기록과 복원한 랜드마크가 사라지고 되돌릴 수 없어요.")
                            .font(.game(14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        HStack(spacing: 10) {
                            Button("그만두기") {
                                GameFeedback.shared.play(.tap)
                                confirmsReset = false
                            }
                            .buttonStyle(ChunkyButtonStyle(tint: .blue, size: 15, fills: true))
                            Button("모두 지우기") {
                                GameFeedback.shared.play(.tap)
                                model.resetProgress()
                                dismiss()
                            }
                            .buttonStyle(ChunkyButtonStyle(tint: .pink, size: 15, fills: true))
                        }
                        .padding(.top, 4)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .gamePanel(radius: 20)
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: confirmsReset)
    }

    private func note(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(.game(12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}
