package dev.code404.sporesweep.core

import java.io.File
import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant
import kotlinx.datetime.TimeZone

class ProgressStoreTest {
    private fun temporaryStore() = ProgressStore(File(Files.createTempDirectory("ProgressTests").toFile(), "nested/progress.json"))

    @Test fun missingFile() = assertEquals(GameProgress(), temporaryStore().load())

    @Test fun roundTrip() {
        val store = temporaryStore()
        val progress = GameProgress()
        progress.recordClear("seoul-001", 3, 12000)
        progress.recordClear("seoul-002", 1, 4000)
        progress.restore("gate", "seoul")
        store.save(progress)
        val loaded = ProgressStore(store.file).load()
        assertEquals(progress, loaded)
        assertEquals(4, loaded.totalStars(levels))
        assertEquals(setOf("gate"), loaded.restoredParts("seoul"))
        assertTrue(loaded.isUnlocked(2, levels))
    }

    @Test fun overwrite() {
        val store = temporaryStore()
        val progress = GameProgress()
        progress.recordClear("seoul-001", 1, 100)
        store.save(progress)
        progress.recordClear("seoul-001", 3, 900)
        store.save(progress)
        assertEquals(3, store.load().stars("seoul-001"))
    }

    @Test fun corruptFile() {
        val store = temporaryStore()
        store.file.parentFile.mkdirs()
        store.file.writeText("{ broken")
        assertFailsWith<Exception> { store.load() }
        assertTrue(store.file.exists())
    }

    @Test fun reset() {
        val store = temporaryStore()
        val progress = GameProgress()
        progress.recordClear("seoul-001", 2, 100)
        store.save(progress)
        store.reset()
        assertEquals(GameProgress(), store.load())
        store.reset()
    }
}
