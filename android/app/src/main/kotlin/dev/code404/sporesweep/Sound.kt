package dev.code404.sporesweep

import android.content.Context
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import dev.code404.sporesweep.board.Feedback
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound

/**
 * 효과음과 진동(iOS 판 GameFeedback). 설정에서 각각 끌 수 있고, 끈 상태는 앱을 다시 켜도 유지된다.
 * 무음 모드에서는 소리를 내지 않는다.
 */
object Sound : Feedback {
    private lateinit var prefs: SharedPreferences
    private lateinit var audio: AudioManager
    private var vibrator: Vibrator? = null
    private val pool = SoundPool.Builder()
        .setMaxStreams(8)
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
        .build()
    private val ids = HashMap<GameSound, Int>()

    var isSoundEnabled: Boolean
        get() = prefs.getBoolean("soundEnabled", true)
        set(value) = prefs.edit().putBoolean("soundEnabled", value).apply()

    var isHapticsEnabled: Boolean
        get() = prefs.getBoolean("hapticsEnabled", true)
        set(value) = prefs.edit().putBoolean("hapticsEnabled", value).apply()

    fun install(context: Context) {
        prefs = context.getSharedPreferences("spore", Context.MODE_PRIVATE)
        audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        for (sound in GameSound.entries) {
            runCatching { context.assets.openFd("sounds/${sound.file}.wav").use { ids[sound] = pool.load(it, 1) } }
        }
    }

    private val isSilent get() = audio.ringerMode != AudioManager.RINGER_MODE_NORMAL

    override fun play(sound: GameSound) {
        if (!isSoundEnabled || isSilent) return
        ids[sound]?.let { pool.play(it, 1f, 1f, 1, 0, 1f) }
    }

    override fun haptic(haptic: GameHaptic) {
        if (!isHapticsEnabled) return
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        val effect = when (haptic) {
            GameHaptic.LIGHT -> VibrationEffect.createOneShot(12, 60)
            GameHaptic.MEDIUM -> VibrationEffect.createOneShot(18, 120)
            GameHaptic.HEAVY -> VibrationEffect.createOneShot(28, 220)
            GameHaptic.SUCCESS -> VibrationEffect.createWaveform(longArrayOf(0, 20, 60, 30), intArrayOf(0, 120, 0, 200), -1)
            GameHaptic.WARNING -> VibrationEffect.createWaveform(longArrayOf(0, 25, 70, 25), intArrayOf(0, 160, 0, 160), -1)
            GameHaptic.FAILURE -> VibrationEffect.createWaveform(longArrayOf(0, 30, 50, 30, 50, 40), intArrayOf(0, 200, 0, 200, 0, 220), -1)
        }
        v.vibrate(effect)
    }
}

/** 배경 음악의 종류. 파일 이름과 같다. */
enum class GameTrack(val file: String) { INTRO("music_intro"), CITY("music_city"), GAME("music_game") }

/**
 * 배경 음악(iOS 판 GameMusic). 화면에 맞는 곡을 되풀이해 틀고, 곡이 바뀌면 천천히 넘긴다.
 * 다른 앱이 음악을 틀고 있거나 무음 모드면 틀지 않는다.
 */
object Music {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private lateinit var audio: AudioManager
    private var player: MediaPlayer? = null
    private var playing: GameTrack? = null
    private var track: GameTrack? = null
    private var isPaused = false
    private const val VOLUME = 0.35f

    var isMusicEnabled: Boolean
        get() = prefs.getBoolean("musicEnabled", true)
        set(value) {
            prefs.edit().putBoolean("musicEnabled", value).apply()
            refresh()
        }

    fun install(context: Context) {
        this.context = context.applicationContext
        prefs = context.getSharedPreferences("spore", Context.MODE_PRIVATE)
        audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
        val wanted = track
        if (!isMusicEnabled || isPaused || wanted == null || audio.isMusicActive && player?.isPlaying != true || audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
            release()
            return
        }
        if (playing == wanted && player != null) {
            if (player?.isPlaying != true) player?.start()
            return
        }
        release()
        val fd = runCatching { context.assets.openFd("music/${wanted.file}.m4a") }.getOrNull() ?: return
        val next = MediaPlayer()
        next.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
        next.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
        fd.close()
        next.isLooping = true
        next.setVolume(VOLUME, VOLUME)
        next.setOnPreparedListener { it.start() }
        next.prepareAsync()
        player = next
        playing = wanted
    }

    /** 앱이 뒤로 갔을 때. */
    fun suspend() = release()

    private fun release() {
        player?.release()
        player = null
        playing = null
    }
}
