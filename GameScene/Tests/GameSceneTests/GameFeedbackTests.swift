import AVFoundation
import Foundation
import Testing
@testable import GameScene

@MainActor
@Suite("효과음과 햅틱")
struct GameFeedbackTests {
    func freshDefaults() -> UserDefaults {
        let name = "GameFeedbackTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("모든 효과음 파일이 패키지에 들어 있고 재생할 수 있는 형식이다")
    func soundFilesExist() throws {
        for sound in GameSound.allCases {
            let url = try #require(GameFeedback.url(for: sound), "\(sound.rawValue).wav가 없다")
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 0.02, "\(sound.rawValue)")
            #expect(player.duration < 2, "\(sound.rawValue)")
        }
    }

    @Test("연쇄가 이어질수록 다른 제거음을 쓰고 5번째부터는 같다")
    func clearSoundByChain() {
        #expect(GameSound.clear(chain: 1) == .clear1)
        #expect(GameSound.clear(chain: 2) == .clear2)
        #expect(GameSound.clear(chain: 5) == .clear5)
        #expect(GameSound.clear(chain: 9) == .clear5)
        #expect(GameSound.clear(chain: 0) == .clear1)
    }

    @Test("처음에는 효과음과 햅틱이 켜져 있다")
    func enabledByDefault() {
        let feedback = GameFeedback(defaults: freshDefaults())
        #expect(feedback.isSoundEnabled)
        #expect(feedback.isHapticsEnabled)
    }

    @Test("끈 설정은 다시 만들어도 유지된다")
    func settingsPersist() {
        let defaults = freshDefaults()
        let feedback = GameFeedback(defaults: defaults)
        feedback.isSoundEnabled = false
        feedback.isHapticsEnabled = false

        let reopened = GameFeedback(defaults: defaults)
        #expect(!reopened.isSoundEnabled)
        #expect(!reopened.isHapticsEnabled)

        reopened.isSoundEnabled = true
        #expect(GameFeedback(defaults: defaults).isSoundEnabled)
        #expect(!GameFeedback(defaults: defaults).isHapticsEnabled)
    }

    @Test("꺼져 있으면 재생을 요청해도 문제없이 넘어간다")
    func disabledIsSilent() {
        let feedback = GameFeedback(defaults: freshDefaults())
        feedback.isSoundEnabled = false
        feedback.isHapticsEnabled = false
        feedback.play(.win)
        feedback.haptic(.success)
    }
}
