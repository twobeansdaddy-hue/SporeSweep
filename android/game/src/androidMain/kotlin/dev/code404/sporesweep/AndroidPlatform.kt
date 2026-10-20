package dev.code404.sporesweep

import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import dev.code404.sporesweep.core.GameProgress
import dev.code404.sporesweep.core.ProgressStore
import java.io.File
import java.util.Locale

actual fun decodeImage(bytes: ByteArray): ImageBitmap? = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()

/** 안드로이드의 글꼴은 파일에서 읽으므로 한 번 캐시 폴더에 써 둔다. */
actual fun fontFamily(name: String, bytes: ByteArray): FontFamily {
    val file = File(AndroidPlatform.context.cacheDir, "$name.ttf")
    if (!file.exists() || file.length() != bytes.size.toLong()) file.writeBytes(bytes)
    return FontFamily(Font(file))
}

/** 안드로이드 앱의 Platform. MainActivity가 시작할 때 부른다. */
object AndroidPlatform {
    internal lateinit var context: Context

    fun install(context: Context, isDebug: Boolean) {
        this.context = context.applicationContext
        val app = this.context
        Platform.isDebug = isDebug
        Platform.isKorean = Locale.getDefault().language == "ko"
        Platform.prefs = SharedPrefs(app.getSharedPreferences("spore", Context.MODE_PRIVATE))
        Platform.progress = FileProgress(ProgressStore(File(app.filesDir, "progress.json")))
        Platform.assets = AssetFiles(app)
        Platform.audio = AndroidAudio(app)
        Platform.log = { tag, message -> Log.i(tag, message) }
        Platform.backHandler = { enabled, onBack -> androidx.activity.compose.BackHandler(enabled, onBack) }
    }
}

private class SharedPrefs(private val prefs: SharedPreferences) : Prefs {
    override fun getBoolean(key: String, default: Boolean) = prefs.getBoolean(key, default)
    override fun getInt(key: String, default: Int) = prefs.getInt(key, default)
    override fun getString(key: String, default: String?) = prefs.getString(key, default)
    override fun getStringSet(key: String, default: Set<String>?): Set<String>? = prefs.getStringSet(key, default)
    override fun edit(): Prefs.Editor = Editor(prefs.edit())

    private class Editor(private val editor: SharedPreferences.Editor) : Prefs.Editor {
        override fun putBoolean(key: String, value: Boolean) = apply { editor.putBoolean(key, value) }
        override fun putInt(key: String, value: Int) = apply { editor.putInt(key, value) }
        override fun putString(key: String, value: String?) = apply { editor.putString(key, value) }
        override fun putStringSet(key: String, value: Set<String>?) = apply { editor.putStringSet(key, value) }
        override fun remove(key: String) = apply { editor.remove(key) }
        override fun apply() = editor.apply()
    }
}

private class FileProgress(private val store: ProgressStore) : ProgressPersistence {
    override fun load(): GameProgress = store.load()
    override fun save(progress: GameProgress) = store.save(progress)
    override fun reset() = store.reset()
}

/** 앱의 assets 폴더. 빌드할 때 iOS 판의 파일을 모아 넣는다(app/build.gradle.kts). */
private class AssetFiles(private val context: Context) : AssetSource {
    override fun list(folder: String) = (context.assets.list(folder) ?: emptyArray()).toList()
    override fun bytes(path: String): ByteArray? = runCatching { context.assets.open(path).use { it.readBytes() } }.getOrNull()
}

private class AndroidAudio(private val context: Context) : AudioBackend {
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }
    private val pool = SoundPool.Builder()
        .setMaxStreams(8)
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
        .build()
    private val ids = HashMap<String, Int>()
    private var player: MediaPlayer? = null
    private var playing: String? = null

    override fun loadSounds(names: List<String>) {
        for (name in names) {
            runCatching { context.assets.openFd("sounds/$name.wav").use { ids[name] = pool.load(it, 1) } }
        }
    }

    override fun playSound(name: String) {
        ids[name]?.let { pool.play(it, 1f, 1f, 1, 0, 1f) }
    }

    override val isSilenced get() = manager.ringerMode != AudioManager.RINGER_MODE_NORMAL

    override val isOtherAudioPlaying get() = manager.isMusicActive && player?.isPlaying != true

    override fun playMusic(name: String, volume: Float) {
        if (playing == name && player != null) {
            if (player?.isPlaying != true) player?.start()
            return
        }
        stopMusic()
        val fd = runCatching { context.assets.openFd("music/$name.m4a") }.getOrNull() ?: return
        val next = MediaPlayer()
        next.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
        next.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
        fd.close()
        next.isLooping = true
        next.setVolume(volume, volume)
        next.setOnPreparedListener { it.start() }
        next.prepareAsync()
        player = next
        playing = name
    }

    override fun stopMusic() {
        player?.release()
        player = null
        playing = null
    }

    override fun vibrate(timings: LongArray, amplitudes: IntArray) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
    }
}
