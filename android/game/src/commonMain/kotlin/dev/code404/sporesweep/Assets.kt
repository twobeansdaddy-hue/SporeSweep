package dev.code404.sporesweep

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.text.font.FontFamily
import dev.code404.sporesweep.core.Level

/**
 * 앱에 든 그림, 레벨, 번역을 읽는다. 모두 iOS 판의 파일을 빌드할 때 복사한 것이다.
 * 그림은 한 번 읽으면 기억해 둔다.
 *
 * 웹에서는 파일을 내려받아야 한다. 아직 없는 그림은 `null`을 돌려주고 받기 시작하며, 다 받으면 `version`이 올라
 * 그 그림을 읽던 화면이 다시 그려진다.
 */
object Assets {
    private val images = HashMap<String, ImageBitmap?>()
    private val requested = HashSet<String>()

    /** 받아 둔 파일이 늘 때마다 오른다. 그림을 읽는 화면은 이 값을 따라 다시 그려진다. */
    var version by mutableIntStateOf(0)
        private set

    private val source get() = Platform.assets

    fun install() {
        Strings.load()
    }

    /** 폴더의 파일 목록. 한 번만 읽는다. */
    private val listings = HashMap<String, List<String>>()

    private fun list(folder: String) = listings.getOrPut(folder) { source.list(folder) }

    private fun imageFile(name: String) = list("images").firstOrNull { it.substringBeforeLast('.') == name }

    /** 파일을 그림으로 읽는다. 아직 받지 않았으면 받기 시작하고 `null`이다. */
    private fun load(key: String, path: String?): ImageBitmap? {
        version // 읽어 두면 받기를 마쳤을 때 다시 그려진다.
        images[key]?.let { return it }
        if (path == null) return null
        val bytes = source.bytes(path)
        if (bytes == null) {
            if (requested.add(path)) source.fetch(listOf(path)) { version += 1 }
            return null
        }
        return decodeImage(bytes).also { images[key] = it }
    }

    /** 이미지 세트의 이름으로 그림을 읽는다(`title_art`, `tokyo_bg_restored` 등). 없으면 `null`이다. */
    fun image(name: String): ImageBitmap? = load(name, imageFile(name)?.let { "images/$it" })

    /** 보드에 쓰는 조각 그림(`block_brick` 등). */
    fun sprite(name: String): ImageBitmap? =
        load("sprite:$name", list("sprites").firstOrNull { it.substringBeforeLast('.') == name }?.let { "sprites/$it" })

    /** 이름의 그림들을 미리 받아 둔다. 다 받으면 `done`. */
    fun prefetchImages(names: List<String>, done: () -> Unit = {}) {
        val paths = names.mapNotNull { imageFile(it)?.let { file -> "images/$file" } }.filter { source.bytes(it) == null }
        if (paths.isEmpty()) return done()
        requested.addAll(paths)
        source.fetch(paths) {
            version += 1
            done()
        }
    }

    /** 도시의 레벨 ID. 파일 이름이 곧 ID라서 파일을 읽지 않고 안다. */
    fun levelIDs(city: String): List<String> =
        list("levels").filter { it.startsWith("$city-") && it.endsWith(".json") }.sorted().map { it.removeSuffix(".json") }

    fun levels(city: String): List<Level> = levelIDs(city).map { Level.parse(text("levels/$it.json")) }

    fun text(path: String): String = source.bytes(path)?.decodeToString() ?: error("$path 이 없다")

    val gameFont: FontFamily by lazy { fontFamily("Jua", source.bytes("fonts/Jua-Regular.ttf") ?: error("글꼴이 없다")) }
}

/**
 * 번역. iOS 판처럼 한국어 문장을 열쇠로 쓴다. 영어 기기에서는 iOS 판의 `en.lproj/Localizable.strings`에서 찾는다.
 * `%lld`, `%@` 자리는 `tr`에 넘긴 값으로 차례로 채운다.
 */
object Strings {
    private val english = HashMap<String, String>()
    var isEnglish = false
        private set

    fun load() {
        isEnglish = !Platform.isKorean
        if (!isEnglish) return
        val text = Assets.text("strings/en.strings")
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
