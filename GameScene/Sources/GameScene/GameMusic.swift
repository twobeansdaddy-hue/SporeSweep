import AVFoundation
import Foundation

/// 배경 음악의 종류. 파일 이름과 같다.
public enum GameTrack: String, CaseIterable, Sendable {
    /// 타이틀 화면과 인트로.
    case intro = "music_intro"
    /// 도시 화면.
    case city = "music_city"
    /// 플레이 화면.
    case game = "music_game"
}

/// 배경 음악을 튼다. 설정에서 끌 수 있고, 끈 상태는 앱을 다시 켜도 유지된다.
///
/// 사용자가 다른 앱으로 자기 음악을 듣고 있으면 틀지 않는다. 무음 스위치도 따른다.
@MainActor
public final class GameMusic {
    public static let shared = GameMusic()

    private static let musicKey = "musicEnabled"
    /// 효과음이 묻히지 않게 작게 튼다.
    static let volume: Float = 0.35
    static let fade: TimeInterval = 0.6

    public var isMusicEnabled: Bool {
        didSet {
            defaults.set(isMusicEnabled, forKey: Self.musicKey)
            refresh()
        }
    }

    /// 지금 화면에 맞는 곡. 실제로 소리가 나는지는 `isPlaying`으로 본다.
    public private(set) var track: GameTrack?

    public var isPlaying: Bool { player?.isPlaying ?? false }

    private let defaults: UserDefaults
    private let isOtherAudioPlaying: () -> Bool
    private var player: AVAudioPlayer?
    private var playingTrack: GameTrack?
    private var isPaused = false

    /// `isOtherAudioPlaying`은 다른 앱의 소리가 나고 있는지 알려준다. 주지 않으면 기기에 묻는다.
    public init(defaults: UserDefaults = .standard, isOtherAudioPlaying: (() -> Bool)? = nil) {
        self.defaults = defaults
        // 처음에는 켜져 있다.
        isMusicEnabled = defaults.object(forKey: Self.musicKey) as? Bool ?? true
        #if os(iOS)
        // 무음 스위치를 따르고, 듣고 있던 음악을 끊지 않는다.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        self.isOtherAudioPlaying = isOtherAudioPlaying ?? { AVAudioSession.sharedInstance().isOtherAudioPlaying }
        #else
        self.isOtherAudioPlaying = isOtherAudioPlaying ?? { false }
        #endif
    }

    /// 배경 음악 파일의 위치. 패키지에 들어 있지 않으면 `nil`이다.
    public static func url(for track: GameTrack) -> URL? {
        Bundle.module.url(forResource: track.rawValue, withExtension: "m4a")
    }

    /// 화면에 맞는 곡으로 바꾼다. 같은 곡이면 이어서 튼다.
    public func play(_ track: GameTrack) {
        self.track = track
        refresh()
    }

    /// 음악을 멈춘다.
    public func stop() {
        track = nil
        refresh()
    }

    /// 광고처럼 다른 소리가 나는 동안 잠깐 멈춘다. 곡은 기억해 둔다.
    public func pause() {
        isPaused = true
        refresh()
    }

    /// 멈췄던 음악을 다시 튼다.
    public func resume() {
        isPaused = false
        refresh()
    }

    /// 설정과 다른 앱의 소리를 다시 보고 틀지 멈출지 정한다. 앱이 앞으로 돌아올 때도 부른다.
    public func refresh() {
        guard isMusicEnabled, !isPaused, let track, !isOtherAudioPlaying() else {
            fadeOut()
            return
        }
        if playingTrack == track, let player {
            if !player.isPlaying {
                player.play()
            }
            return
        }
        fadeOut()
        guard let url = Self.url(for: track), let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.numberOfLoops = -1
        next.volume = 0
        next.play()
        next.setVolume(Self.volume, fadeDuration: Self.fade)
        player = next
        playingTrack = track
    }

    private func fadeOut() {
        guard let old = player else { return }
        player = nil
        playingTrack = nil
        old.setVolume(0, fadeDuration: Self.fade)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.fade))
            old.stop()
        }
    }
}
