package dev.code404.sporesweep.core

// Node에서 돈다. 파일 위치는 빌드가 만든 TestPaths.kt에 있다.
private fun readFile(path: String, gzipped: Boolean): String = js("""{
    const fs = process.getBuiltinModule('fs');
    const data = fs.readFileSync(path);
    return (gzipped ? process.getBuiltinModule('zlib').gunzipSync(data) : data).toString('utf8');
}""")

actual fun testResource(name: String): String {
    val directory = if (name.startsWith("parity/")) PARITY_DIRECTORY else LEVELS_DIRECTORY
    return readFile(directory + "/" + name.removePrefix("parity/"), name.endsWith(".gz"))
}
