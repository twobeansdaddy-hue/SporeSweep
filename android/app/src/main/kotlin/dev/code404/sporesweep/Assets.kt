package dev.code404.sporesweep

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import dev.code404.sporesweep.core.Level
import java.util.Locale

/**
 * 앱에 든 그림, 레벨, 번역을 읽는다. 모두 iOS 판의 파일을 빌드할 때 복사한 것이다(app/build.gradle.kts).
 * 그림은 한 번 읽으면 기억해 둔다.
 */
object Assets {
    private lateinit var context: Context
    private val images = HashMap<String, ImageBitmap?>()

    fun install(context: Context) {
        this.context = context.applicationContext
        Strings.load(context)
        dev.code404.sporesweep.stage.LabelNode.typeface = typeface
    }

    /** 이미지 세트의 이름으로 그림을 읽는다(`title_art`, `tokyo_bg_restored` 등). 없으면 `null`이다. */
    fun image(name: String): ImageBitmap? = images.getOrPut(name) {
        val files = context.assets.list("images") ?: emptyArray()
        val file = files.firstOrNull { it.substringBeforeLast('.') == name } ?: return@getOrPut null
        context.assets.open("images/$file").use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
    }

    /** 보드에 쓰는 조각 그림(`block_brick` 등). */
    fun sprite(name: String): ImageBitmap? = images.getOrPut("sprite:$name") {
        runCatching { context.assets.open("sprites/$name.png").use { BitmapFactory.decodeStream(it)?.asImageBitmap() } }.getOrNull()
    }

    private val bitmaps = HashMap<String, android.graphics.Bitmap?>()

    /** 보드에 쓰는 조각 그림의 원본(`block_brick` 등). 그리기 엔진이 쓴다. */
    fun spriteBitmap(name: String): android.graphics.Bitmap? = bitmaps.getOrPut(name) {
        runCatching { context.assets.open("sprites/$name.png").use { BitmapFactory.decodeStream(it) } }.getOrNull()
    }

    /** 이미지 세트의 원본 그림. */
    fun imageBitmap(name: String): android.graphics.Bitmap? = bitmaps.getOrPut("image:$name") {
        val files = context.assets.list("images") ?: emptyArray()
        val file = files.firstOrNull { it.substringBeforeLast('.') == name } ?: return@getOrPut null
        context.assets.open("images/$file").use { BitmapFactory.decodeStream(it) }
    }

    val typeface: android.graphics.Typeface by lazy { android.graphics.Typeface.createFromAsset(context.assets, "fonts/Jua-Regular.ttf") }

    fun levels(city: String): List<Level> {
        val files = (context.assets.list("levels") ?: emptyArray()).filter { it.startsWith("$city-") && it.endsWith(".json") }.sorted()
        return files.map { file -> Level.parse(context.assets.open("levels/$file").bufferedReader().readText()) }
    }

    fun text(path: String): String = context.assets.open(path).bufferedReader().readText()

    val gameFont: FontFamily by lazy {
        FontFamily(Font(path = "fonts/Jua-Regular.ttf", assetManager = context.assets))
    }
}

/**
 * 번역. iOS 판처럼 한국어 문장을 열쇠로 쓴다. 영어 기기에서는 iOS 판의 `en.lproj/Localizable.strings`에서 찾는다.
 * `%lld`, `%@` 자리는 `tr`에 넘긴 값으로 차례로 채운다.
 */
object Strings {
    private val english = HashMap<String, String>()
    var isEnglish = false
        private set

    fun load(context: Context) {
        isEnglish = Locale.getDefault().language != "ko"
        if (!isEnglish) return
        val text = context.assets.open("strings/en.strings").bufferedReader().readText()
        val pattern = Regex("^\"((?:[^\"\\\\]|\\\\.)*)\"\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\";", RegexOption.MULTILINE)
        for (match in pattern.findAll(text)) {
            english[unescape(match.groupValues[1])] = unescape(match.groupValues[2])
        }
    }

    private fun unescape(s: String) = s.replace("\\\"", "\"").replace("\\n", "\n").replace("\\\\", "\\")

    /** 한국어 문장을 이 기기의 말로 바꾼다. 값이 들어가는 자리는 iOS 판처럼 `%lld`, `%@`로 적는다. */
    fun tr(korean: String, vararg values: Any): String {
        val template = if (isEnglish) english[korean] ?: korean else korean
        if (values.isEmpty()) return template
        var index = 0
        return Regex("%(\\d+\\$)?(lld|@|d)").replace(template) { match ->
            val position = match.groupValues[1].removeSuffix("$").toIntOrNull()?.minus(1) ?: index++
            values.getOrNull(position)?.toString() ?: ""
        }
    }
}

fun tr(korean: String, vararg values: Any) = Strings.tr(korean, *values)
