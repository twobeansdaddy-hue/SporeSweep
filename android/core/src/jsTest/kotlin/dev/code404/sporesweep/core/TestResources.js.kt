package dev.code404.sporesweep.core

// Node에서 돈다(mods판의 엔진과 같은 순수 자바스크립트 빌드). 파일 위치는 빌드가 만든 TestPaths.kt에 있다.
private fun readFile(path: String, gzipped: Boolean): String {
    val data: dynamic = js("process.getBuiltinModule('fs')").readFileSync(path)
    val text: dynamic = if (gzipped) js("process.getBuiltinModule('zlib')").gunzipSync(data) else data
    return text.toString("utf8") as String
}

actual fun testResource(name: String): String {
    val directory = if (name.startsWith("parity/")) PARITY_DIRECTORY else LEVELS_DIRECTORY
    return readFile(directory + "/" + name.removePrefix("parity/"), name.endsWith(".gz"))
}
