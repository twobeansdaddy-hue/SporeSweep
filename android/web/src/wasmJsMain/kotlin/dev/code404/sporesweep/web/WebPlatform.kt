package dev.code404.sporesweep.web

import dev.code404.sporesweep.AssetSource
import dev.code404.sporesweep.AudioBackend
import dev.code404.sporesweep.Platform
import dev.code404.sporesweep.Prefs
import dev.code404.sporesweep.ProgressPersistence
import dev.code404.sporesweep.core.GameProgress
import kotlinx.browser.localStorage
import kotlinx.browser.window
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.await
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.khronos.webgl.ArrayBuffer
import org.khronos.webgl.Int8Array
import org.khronos.webgl.get
import org.w3c.fetch.Response

// 웹판의 Platform. 파일은 assets/ 아래에서 내려받고, 설정과 진행은 브라우저 저장소(localStorage)에 둔다.
// 소리는 index.html의 작은 자바스크립트(window.sporeAudio)가 Web Audio로 낸다.

private val scope = MainScope()

/** 파일을 받는다. 없으면 `null`이다. 연결이 끊기면 세 번까지 다시 받는다. */
private suspend fun download(path: String): ByteArray? {
    repeat(3) { attempt ->
        try {
            val response = window.fetch("assets/$path").await<Response>()
            if (!response.ok) return null
            val buffer = response.arrayBuffer().await<ArrayBuffer>()
            val array = Int8Array(buffer)
            return ByteArray(array.length) { array[it] }
        } catch (e: Throwable) {
            delay(400L * (attempt + 1))
        }
    }
    return null
}

private suspend fun downloadText(path: String): String? = download(path)?.decodeToString()

object WebAssets : AssetSource {
    private val files = HashMap<String, ByteArray>()
    private val manifest = HashMap<String, List<String>>()
    private val waiting = HashMap<String, MutableList<() -> Unit>>()

    /** 파일 목록과 작은 글 파일 묶음을 받는다. 게임을 띄우기 전에 한 번 부른다. */
    suspend fun start() {
        val list = Json.parseToJsonElement(downloadText("manifest.json") ?: error("manifest.json이 없다")).jsonObject
        for ((folder, names) in list) manifest[folder] = names.jsonArray.map { it.jsonPrimitive.content }
        val bundle = Json.parseToJsonElement(downloadText("bundle.json") ?: error("bundle.json이 없다")).jsonObject
        for ((path, text) in bundle) files[path] = text.jsonPrimitive.content.encodeToByteArray()
    }

    /** 파일들을 받아 둔다. 다 받을 때까지 기다린다. */
    suspend fun load(paths: List<String>) {
        // 한꺼번에 너무 많이 받지 않게 여섯 개씩 받는다.
        for (chunk in paths.filter { it !in files }.chunked(6)) {
            coroutineScope { chunk.map { path -> async { download(path)?.let { files[path] = it } } }.awaitAll() }
        }
    }

    override fun list(folder: String) = manifest[folder] ?: emptyList()

    override fun bytes(path: String): ByteArray? = files[path]

    override fun fetch(paths: List<String>, done: () -> Unit) {
        val missing = paths.filter { it !in files }
        if (missing.isEmpty()) return done()
        scope.launch {
            load(missing)
            done()
        }
    }
}

private class LocalPrefs : Prefs {
    private fun key(name: String) = "spore.$name"
    override fun getBoolean(key: String, default: Boolean) = localStorage.getItem(key(key))?.toBooleanStrictOrNull() ?: default
    override fun getInt(key: String, default: Int) = localStorage.getItem(key(key))?.toIntOrNull() ?: default
    override fun getString(key: String, default: String?) = localStorage.getItem(key(key)) ?: default
    override fun getStringSet(key: String, default: Set<String>?): Set<String>? =
        localStorage.getItem(key(key))?.let { text -> Json.parseToJsonElement(text).jsonArray.map { it.jsonPrimitive.content }.toSet() } ?: default

    override fun edit(): Prefs.Editor = object : Prefs.Editor {
        private val changes = ArrayList<() -> Unit>()
        override fun putBoolean(key: String, value: Boolean) = apply { changes.add { localStorage.setItem(key(key), value.toString()) } }
        override fun putInt(key: String, value: Int) = apply { changes.add { localStorage.setItem(key(key), value.toString()) } }
        override fun putString(key: String, value: String?) = apply {
            changes.add { if (value == null) localStorage.removeItem(key(key)) else localStorage.setItem(key(key), value) }
        }
        override fun putStringSet(key: String, value: Set<String>?) = apply {
            changes.add {
                if (value == null) localStorage.removeItem(key(key))
                else localStorage.setItem(key(key), JsonArray(value.sorted().map { JsonPrimitive(it) }).toString())
            }
        }
        override fun remove(key: String) = apply { changes.add { localStorage.removeItem(key(key)) } }
        override fun apply() = changes.forEach { it() }
    }
}

private object LocalProgress : ProgressPersistence {
    private const val KEY = "spore.progress"
    override fun load(): GameProgress = localStorage.getItem(KEY)?.let { GameProgress.fromJson(it) } ?: GameProgress()
    override fun save(progress: GameProgress) = localStorage.setItem(KEY, progress.toJson())
    override fun reset() = localStorage.removeItem(KEY)
}

private fun jsLoadSound(name: String, url: String): Unit = js("window.sporeAudio.loadSound(name, url)")
private fun jsPlaySound(name: String): Unit = js("window.sporeAudio.playSound(name)")
private fun jsPlayMusic(url: String, volume: Double): Unit = js("window.sporeAudio.playMusic(url, volume)")
private fun jsStopMusic(): Unit = js("window.sporeAudio.stopMusic()")
private fun jsVibrate(pattern: String): Unit = js("window.sporeAudio.vibrate(pattern)")

private object WebAudio : AudioBackend {
    override fun loadSounds(names: List<String>) {
        for (name in names) jsLoadSound(name, "assets/sounds/$name.wav")
    }

    override fun playSound(name: String) = jsPlaySound(name)
    override val isSilenced = false
    override val isOtherAudioPlaying = false
    override fun playMusic(name: String, volume: Float) = jsPlayMusic("assets/music/$name.m4a", volume.toDouble())
    override fun stopMusic() = jsStopMusic()

    /** 휴대전화 브라우저 일부만 진동한다. 세기는 고를 수 없어 켜고 끄는 시간만 넘긴다. */
    override fun vibrate(timings: LongArray, amplitudes: IntArray) = jsVibrate(timings.drop(1).joinToString(","))
}

private fun jsLog(name: String, json: String): Unit = js("window.sporeLog && window.sporeLog(name, JSON.parse(json))")
private fun jsLanguage(): String = js("navigator.language || 'ko'")
private fun jsQuery(): String = js("window.location.search")

object WebPlatform {
    /** 주소의 `?city=tokyo&level=2` 같은 값. `debug=1`이 있을 때만 개발용 실행 인자로 쓴다. */
    val query: Map<String, String> by lazy {
        jsQuery().removePrefix("?").split("&").filter { "=" in it }.associate {
            val (key, value) = it.split("=", limit = 2)
            key to value
        }
    }

    fun install() {
        Platform.isDebug = query["debug"] == "1"
        Platform.isKorean = jsLanguage().lowercase().startsWith("ko")
        Platform.prefs = LocalPrefs()
        Platform.progress = LocalProgress
        Platform.assets = WebAssets
        Platform.audio = WebAudio
        Platform.adsArePlaceholders = true
        Platform.analytics = { name, parameters ->
            val json = parameters.entries.joinToString(",", "{", "}") { (key, value) ->
                "\"$key\":" + if (value is Int) value.toString() else JsonPrimitive(value.toString()).toString()
            }
            jsLog(name, json)
        }
    }
}
