package dev.code404.sporesweep

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.text.font.FontFamily
import dev.code404.sporesweep.core.GameProgress

// 안드로이드 앱과 웹판이 다른 것. 게임 코드는 이 인터페이스만 보고, 플랫폼마다 시작할 때 Platform.install로 넣는다.

/** 설정처럼 작은 값을 저장한다. 안드로이드의 SharedPreferences와 같은 모양이다. */
interface Prefs {
    fun getBoolean(key: String, default: Boolean): Boolean
    fun getInt(key: String, default: Int): Int
    fun getString(key: String, default: String?): String?
    fun getStringSet(key: String, default: Set<String>?): Set<String>?
    fun edit(): Editor

    interface Editor {
        fun putBoolean(key: String, value: Boolean): Editor
        fun putInt(key: String, value: Int): Editor
        fun putString(key: String, value: String?): Editor
        fun putStringSet(key: String, value: Set<String>?): Editor
        fun remove(key: String): Editor
        fun apply()
    }
}

/** 진행을 저장한다. 읽을 수 없게 깨졌으면 `load`가 예외를 던진다. */
interface ProgressPersistence {
    fun load(): GameProgress
    fun save(progress: GameProgress)
    fun reset()
}

/**
 * 앱에 든 파일(그림, 레벨, 번역, 소리). 경로는 `images/title_art.jpg`, `levels/tokyo-001.json`처럼 적는다.
 * 웹에서는 내려받아야 하므로 아직 없는 파일은 `null`이고, `fetch`로 받아 둔 뒤에 읽는다.
 */
interface AssetSource {
    /** 폴더 안 파일 이름. */
    fun list(folder: String): List<String>

    /** 파일의 내용. 아직 받지 않았거나 없으면 `null`이다. */
    fun bytes(path: String): ByteArray?

    /** 파일들을 받아 둔다. 다 받으면 `done`을 부른다. 이미 있으면 바로 부른다. */
    fun fetch(paths: List<String>, done: () -> Unit) = done()
}

/** 소리와 진동. */
interface AudioBackend {
    /** 효과음을 미리 읽어 둔다. 이름은 확장자 없는 파일 이름이다. */
    fun loadSounds(names: List<String>)
    fun playSound(name: String)
    /** 무음 모드처럼 소리를 내면 안 되는 상태인지. */
    val isSilenced: Boolean
    /** 다른 앱이 음악을 틀고 있는지. */
    val isOtherAudioPlaying: Boolean
    /** 배경 음악을 되풀이해 튼다. 같은 곡이면 이어서 튼다. */
    fun playMusic(name: String, volume: Float)
    fun stopMusic()
    /** 진동. 밀리초로 켜고 끄기를 번갈아 적고, 세기는 0..255다. */
    fun vibrate(timings: LongArray, amplitudes: IntArray)
}

/** 보상형 광고. */
interface AdService {
    enum class Outcome { REWARDED, SKIPPED, FAILED }

    /** 실제 광고를 쓰는지. 아니면 자리 표시 화면으로 대신한다. */
    val isEnabled: Boolean
    suspend fun waitUntilReady(seconds: Double): Boolean
    fun show(onFinish: (Outcome) -> Unit)
}

object NoAds : AdService {
    override val isEnabled = false
    override suspend fun waitUntilReady(seconds: Double) = false
    override fun show(onFinish: (AdService.Outcome) -> Unit) = onFinish(AdService.Outcome.FAILED)
}

/** 플랫폼마다 다른 것을 모은 곳. 앱이 시작할 때 한 번 정한다. */
object Platform {
    lateinit var prefs: Prefs
    lateinit var progress: ProgressPersistence
    lateinit var assets: AssetSource
    lateinit var audio: AudioBackend
    var ads: AdService = NoAds
    /** 플레이 기록을 보내는 곳. 없으면 개발 빌드에서 로그에만 적는다. */
    var analytics: ((String, Map<String, Any>) -> Unit)? = null
    /** 개발 빌드인지. 개발용 실행 인자와 화면을 켠다. */
    var isDebug = false
    /** 광고 대신 자리 표시 화면을 보여주고 보상을 주는지. 웹판처럼 광고가 없는 곳에서 쓴다. */
    var adsArePlaceholders = false
    /** 기기의 언어가 한국어인지. */
    var isKorean = true
    var log: (String, String) -> Unit = { tag, message -> println("[$tag] $message") }
    /** 뒤로 가기를 받는다. 안드로이드는 뒤로 가기 단추, 웹은 Esc 키다. */
    var backHandler: @Composable (enabled: Boolean, onBack: () -> Unit) -> Unit = { _, _ -> }
}

/** 그림 파일을 읽는다. */
expect fun decodeImage(bytes: ByteArray): ImageBitmap?

/** 글꼴 파일을 읽는다. */
expect fun fontFamily(name: String, bytes: ByteArray): FontFamily

/** 뒤로 가기(iOS 판에는 없다). */
@Composable
fun BackHandler(enabled: Boolean = true, onBack: () -> Unit) = Platform.backHandler(enabled, onBack)

/** 개발용 실행 인자. iOS 판과 이름이 같다. 개발 빌드에서만 읽는다. */
class DebugArgs(private val values: Map<String, String>) {
    private val on get() = Platform.isDebug

    fun has(key: String) = on && key in values
    fun bool(key: String) = on && (values[key]?.let { it == "true" || it == "1" } ?: false)
    fun int(key: String) = if (on) values[key]?.toIntOrNull() ?: 0 else 0
    fun double(key: String) = if (on) values[key]?.toDoubleOrNull() ?: 0.0 else 0.0
    fun string(key: String): String? = if (on) values[key] else null
}
