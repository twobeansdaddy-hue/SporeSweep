package dev.code404.sporesweep

import dev.code404.sporesweep.board.Feedback
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound

/**
 * 효과음과 진동(iOS 판 GameFeedback). 설정에서 각각 끌 수 있고, 끈 상태는 앱을 다시 켜도 유지된다.
 * 무음 모드에서는 소리를 내지 않는다. 소리를 내는 일은 플랫폼(Platform.audio)이 한다.
 */
object Sound : Feedback {
    private val prefs get() = Platform.prefs
    private val audio get() = Platform.audio

    var isSoundEnabled: Boolean
        get() = prefs.getBoolean("soundEnabled", true)
        set(value) = prefs.edit().putBoolean("soundEnabled", value).apply()

    var isHapticsEnabled: Boolean
        get() = prefs.getBoolean("hapticsEnabled", true)
        set(value) = prefs.edit().putBoolean("hapticsEnabled", value).apply()

    fun install() {
        audio.loadSounds(GameSound.entries.map { it.file })
    }

    override fun play(sound: GameSound) {
        if (!isSoundEnabled || audio.isSilenced) return
        audio.playSound(sound.file)
    }

    override fun haptic(haptic: GameHaptic) {
        if (!isHapticsEnabled) return
        val (timings, amplitudes) = when (haptic) {
            GameHaptic.LIGHT -> longArrayOf(0, 12) to intArrayOf(0, 60)
            GameHaptic.MEDIUM -> longArrayOf(0, 18) to intArrayOf(0, 120)
            GameHaptic.HEAVY -> longArrayOf(0, 28) to intArrayOf(0, 220)
            GameHaptic.SUCCESS -> longArrayOf(0, 20, 60, 30) to intArrayOf(0, 120, 0, 200)
            GameHaptic.WARNING -> longArrayOf(0, 25, 70, 25) to intArrayOf(0, 160, 0, 160)
            GameHaptic.FAILURE -> longArrayOf(0, 30, 50, 30, 50, 40) to intArrayOf(0, 200, 0, 200, 0, 220)
        }
        audio.vibrate(timings, amplitudes)
    }
}

/** 배경 음악의 종류. 파일 이름과 같다. */
enum class GameTrack(val file: String) { INTRO("music_intro"), CITY("music_city"), GAME("music_game") }

/**
 * 배경 음악(iOS 판 GameMusic). 화면에 맞는 곡을 되풀이해 튼다.
 * 다른 앱이 음악을 틀고 있거나 무음 모드면 틀지 않는다.
 */
object Music {
    private val prefs get() = Platform.prefs
    private val audio get() = Platform.audio
    private var playing: GameTrack? = null
    private var track: GameTrack? = null
    private var isPaused = false
    private var isSuspended = false
    private const val VOLUME = 0.35f

    var isMusicEnabled: Boolean
        get() = prefs.getBoolean("musicEnabled", true)
        set(value) {
            prefs.edit().putBoolean("musicEnabled", value).apply()
            refresh()
        }

    fun play(next: GameTrack) {
        track = next
        refresh()
    }

    fun stop() {
        track = null
        refresh()
    }

    fun pause() {
        isPaused = true
        refresh()
    }

    fun resume() {
        isPaused = false
        refresh()
    }

    /** 설정과 다른 앱의 소리를 다시 보고 틀지 멈출지 정한다. 앱이 앞으로 돌아올 때도 부른다. */
    fun refresh() {
        isSuspended = false
        val wanted = track
        if (!isMusicEnabled || isPaused || wanted == null || audio.isOtherAudioPlaying && playing == null || audio.isSilenced) {
            release()
            return
        }
        if (playing == wanted) return
        audio.playMusic(wanted.file, VOLUME)
        playing = wanted
    }

    /** 앱이 뒤로 갔을 때. */
    fun suspend() {
        isSuspended = true
        release()
    }

    private fun release() {
        audio.stopMusic()
        playing = null
    }
}
