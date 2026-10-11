/// 화면의 버튼과 글자에 쓰는 게임풍 스타일. 시스템 기본 모양 대신 통통한 버튼과 둥근 글꼴을 쓴다.
import SwiftUI
import UIKit

extension Font {
    /// 게임 글꼴의 이름. 둥근 한글 글꼴 "주아"다(SIL OFL, `Fonts/Jua-OFL.txt`).
    static let gameFontName = "Jua-Regular"

    /// 게임 글꼴. 주아는 굵기가 하나뿐이라 `weight`는 글꼴을 읽지 못해 시스템 글꼴로 돌아갈 때만 쓰인다.
    static func game(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        if UIFont(name: gameFontName, size: size) != nil {
            // 주아는 같은 크기의 시스템 글꼴보다 작아 보여서 조금 키운다.
            return .custom(gameFontName, fixedSize: size * 1.08)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

/// 버튼의 색. 윗면의 위아래 색과, 아래로 비어져 나온 두께의 색이다.
enum GameTint {
    case pink, blue, slate, gold, green

    var top: Color {
        switch self {
        case .pink: Color(red: 1.00, green: 0.42, blue: 0.70)
        case .blue: Color(red: 0.36, green: 0.66, blue: 1.00)
        case .slate: Color(red: 0.42, green: 0.47, blue: 0.62)
        case .gold: Color(red: 1.00, green: 0.84, blue: 0.30)
        case .green: Color(red: 0.42, green: 0.86, blue: 0.48)
        }
    }

    var bottom: Color {
        switch self {
        case .pink: Color(red: 0.96, green: 0.20, blue: 0.55)
        case .blue: Color(red: 0.20, green: 0.48, blue: 0.94)
        case .slate: Color(red: 0.30, green: 0.34, blue: 0.48)
        case .gold: Color(red: 0.98, green: 0.66, blue: 0.14)
        case .green: Color(red: 0.20, green: 0.70, blue: 0.36)
        }
    }

    var lip: Color {
        switch self {
        case .pink: Color(red: 0.66, green: 0.08, blue: 0.36)
        case .blue: Color(red: 0.10, green: 0.28, blue: 0.66)
        case .slate: Color(red: 0.17, green: 0.20, blue: 0.31)
        case .gold: Color(red: 0.72, green: 0.42, blue: 0.05)
        case .green: Color(red: 0.10, green: 0.44, blue: 0.22)
        }
    }

    /// 버튼 위의 글자색. 밝은 금색 위에서는 어두운 글자를 쓴다.
    var text: Color {
        self == .gold ? Color(red: 0.36, green: 0.20, blue: 0.02) : .white
    }
}

/// 두께가 있는 통통한 판. 버튼과 칸의 바탕으로 쓴다.
struct ChunkyShape: View {
    var tint: GameTint
    var radius: CGFloat = 14
    var depth: CGFloat = 4
    /// 눌렸을 때는 윗면이 두께만큼 내려앉는다.
    var isPressed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(tint.lip)
                .offset(y: depth)
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [tint.top, tint.bottom], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    // 윗면 가장자리의 밝은 띠.
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(.white.opacity(0.35), lineWidth: 1.5)
                        .padding(1)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                }
                .offset(y: isPressed ? depth - 1 : 0)
        }
    }
}

/// 통통한 버튼. 누르면 내려앉는다.
struct ChunkyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: GameTint = .pink
    var size: CGFloat = 17
    /// 가로를 꽉 채울지.
    var fills = false

    func makeBody(configuration: Configuration) -> some View {
        let shown: GameTint = isEnabled ? tint : .slate
        configuration.label
            .font(.game(size))
            .foregroundStyle(shown.text.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, size)
            .padding(.vertical, size * 0.62)
            .frame(maxWidth: fills ? .infinity : nil)
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(ChunkyShape(tint: shown, radius: size * 0.8, isPressed: configuration.isPressed))
            .padding(.bottom, 4)
            .opacity(isEnabled ? 1 : 0.7)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 둥근 아이콘 버튼. 뒤로 가기, 설정, 설명 보기에 쓴다.
struct IconButton: View {
    var systemName: String
    var label: String
    var tint: GameTint = .slate
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .heavy))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(IconButtonStyle(tint: tint))
        .accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

private struct IconButtonStyle: ButtonStyle {
    var tint: GameTint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint.text)
            .padding(11)
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(ChunkyShape(tint: tint, radius: 21, isPressed: configuration.isPressed))
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 화면 위쪽의 제목 줄. 시스템 내비게이션 바 대신 쓴다.
struct GameHeader<Leading: View, Trailing: View>: View {
    var title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(LocalizedStringKey(title))
                .font(.game(19))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(Palette.panel, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1.5))
                .accessibilityAddTraits(.isHeader)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

/// 내용을 담는 둥근 판.
struct GamePanel: ViewModifier {
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.10), lineWidth: 1.5))
    }
}

extension View {
    func gamePanel(radius: CGFloat = 18) -> some View {
        modifier(GamePanel(radius: radius))
    }

    /// 화면 전체의 바탕. 짙은 남색에서 보라로 내려간다.
    func gameBackground() -> some View {
        background(Palette.backdrop.ignoresSafeArea())
    }
}

/// 통통한 스위치.
struct ChunkyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                    .font(.game(17, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? GameTint.green.bottom : Color.black.opacity(0.35))
                        .frame(width: 58, height: 32)
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 2)
                        .padding(3)
                }
                .animation(.spring(duration: 0.2), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "켜짐" : "꺼짐")
    }
}
