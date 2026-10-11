import AVFoundation
import Foundation
import Testing
@testable import GameScene

@MainActor
@Suite("배경 음악")
struct GameMusicTests {
    func freshDefaults() -> UserDefaults {
        let name = "GameMusicTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("모든 곡이 패키지에 들어 있고 반복해 틀 만한 길이다")
    func musicFilesExist() throws {
        for track in GameTrack.allCases {
            let url = try #require(GameMusic.url(for: track), "\(track.rawValue).m4a가 없다")
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 20, "\(track.rawValue)")
            #expect(player.duration < 180, "\(track.rawValue)")
        }
    }

    @Test("처음에는 켜져 있고, 끈 상태는 다시 켜도 유지된다")
    func settingPersists() {
        let defaults = freshDefaults()
        let music = GameMusic(defaults: defaults, isOtherAudioPlaying: { false })
        #expect(music.isMusicEnabled)
        music.isMusicEnabled = false
        #expect(!GameMusic(defaults: defaults, isOtherAudioPlaying: { false }).isMusicEnabled)
    }

    @Test("화면에 맞는 곡을 틀고, 화면이 바뀌면 곡을 바꾼다")
    func playsAndSwitches() {
        let music = GameMusic(defaults: freshDefaults(), isOtherAudioPlaying: { false })
        #expect(!music.isPlaying)
        music.play(.city)
        #expect(music.track == .city)
        #expect(music.isPlaying)
        music.play(.game)
        #expect(music.track == .game)
        #expect(music.isPlaying)
        music.stop()
        #expect(music.track == nil)
        #expect(!music.isPlaying)
    }

    @Test("끄면 멈추고, 다시 켜면 화면에 맞는 곡을 다시 튼다")
    func togglingStopsAndResumes() {
        let music = GameMusic(defaults: freshDefaults(), isOtherAudioPlaying: { false })
        music.play(.game)
        music.isMusicEnabled = false
        #expect(!music.isPlaying)
        #expect(music.track == .game)
        music.isMusicEnabled = true
        #expect(music.isPlaying)
    }

    @Test("다른 앱의 소리가 나고 있으면 틀지 않고, 그 소리가 멈춘 뒤 다시 보면 튼다")
    func yieldsToOtherAudio() {
        var other = true
        let music = GameMusic(defaults: freshDefaults(), isOtherAudioPlaying: { other })
        music.play(.city)
        #expect(!music.isPlaying)
        other = false
        music.refresh()
        #expect(music.isPlaying)
        other = true
        music.refresh()
        #expect(!music.isPlaying)
    }
}
