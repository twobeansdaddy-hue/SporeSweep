package dev.code404.sporesweep.core

import java.util.zip.GZIPInputStream

private object Anchor

actual fun testResource(name: String): String {
    val stream = Anchor::class.java.classLoader.getResourceAsStream(name) ?: error("$name 이 없다")
    return (if (name.endsWith(".gz")) GZIPInputStream(stream) else stream).bufferedReader().readText()
}
