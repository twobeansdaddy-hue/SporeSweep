import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 효과음의 종류. 파일 이름과 같다.
public enum GameSound: String, CaseIterable, Sendable {
    case swap, reject
    case clear1, clear2, clear3, clear4, clear5
    case special, create, crack, collect, win, lose
    /// 도시 화면에서 랜드마크 부위를 복원할 때.
    case restore
    case tap
    /// 인트로의 장면마다 하나씩. 지구, 외계인의 침공, 망가진 랜드마크, 정화 대원의 등장, 서울 도착.
    case introEarth, introInvasion, introRuin, introHero, introArrival

    /// 연쇄 번호에 맞는 제거음. 연쇄가 이어질수록 음이 올라가고 5번째부터는 같다.
    public static func clear(chain: Int) -> GameSound {
        [.clear1, .clear2, .clear3, .clear4, .clear5][min(max(chain, 1), 5) - 1]
    }
}

/// 진동의 세기.
public enum GameHaptic: Sendable {
    case light, medium, heavy
    case success, warning, failure
}

/// 효과음과 햅틱을 낸다. 설정에서 각각 끌 수 있고, 끈 상태는 앱을 다시 켜도 유지된다.
@MainActor
public final class GameFeedback {
    public static let shared = GameFeedback()

    private static let soundKey = "soundEnabled"
    private static let hapticsKey = "hapticsEnabled"

    public var isSoundEnabled: Bool {
        didSet { defaults.set(isSoundEnabled, forKey: Self.soundKey) }
    }

    public var isHapticsEnabled: Bool {
        didSet { defaults.set(isHapticsEnabled, forKey: Self.hapticsKey) }
    }

    private let defaults: UserDefaults
    private var data: [GameSound: Data] = [:]
    /// 재생 중인 플레이어. 끝날 때까지 붙잡고 있어야 소리가 끊기지 않는다.
    private var players: [AVAudioPlayer] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 처음에는 둘 다 켜져 있다.
        isSoundEnabled = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        isHapticsEnabled = defaults.object(forKey: Self.hapticsKey) as? Bool ?? true
        for sound in GameSound.allCases {
            if let url = Self.url(for: sound) {
                data[sound] = try? Data(contentsOf: url)
            }
        }
        #if os(iOS)
        // 무음 스위치를 따르고, 듣고 있던 음악을 끊지 않는다.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        #endif
    }

    /// 효과음 파일의 위치. 패키지에 들어 있지 않으면 `nil`이다.
    public static func url(for sound: GameSound) -> URL? {
        Bundle.module.url(forResource: sound.rawValue, withExtension: "wav")
    }

    public func play(_ sound: GameSound) {
        guard isSoundEnabled, let data = data[sound], let player = try? AVAudioPlayer(data: data) else { return }
        players.removeAll { !$0.isPlaying }
        players.append(player)
        player.play()
    }

    public func haptic(_ haptic: GameHaptic) {
        guard isHapticsEnabled else { return }
        #if os(iOS)
        switch haptic {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .failure: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }
}
