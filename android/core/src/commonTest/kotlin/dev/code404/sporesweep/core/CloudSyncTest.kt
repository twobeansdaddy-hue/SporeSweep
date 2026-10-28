package dev.code404.sporesweep.core

import kotlin.time.Duration.Companion.seconds
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 손으로 끝내는 가짜 클라우드. 일은 `pending`에 쌓이고 `runAll`로 끝난다. */
private class FakeCloud : CloudBackend {
    var stored: GameProgress? = null
    /** `true`면 읽지 못한 것처럼 군다. */
    var unreadable = false
    val pending = ArrayDeque<() -> Unit>()
    override val isAvailable = true

    private fun current(): CloudRead = when {
        unreadable -> CloudRead.Unavailable
        stored == null -> CloudRead.Empty
        else -> CloudRead.Found(stored!!.copy())
    }

    override fun load(done: (CloudRead) -> Unit) {
        pending.add { done(current()) }
    }

    override fun update(transform: (CloudRead) -> GameProgress?, done: (Boolean) -> Unit) {
        pending.add {
            val next = transform(current())
            if (next != null) stored = next.copy()
            done(next != null)
        }
    }

    override fun clear(done: (Boolean) -> Unit) {
        pending.add {
            stored = null
            done(true)
        }
    }

    fun runAll() {
        while (pending.isNotEmpty()) pending.removeFirst()()
    }
}

class CloudSyncTest {
    private fun played() = GameProgress().apply {
        recordClear("seoul-001", 3, 1200)
        restore("gate", "seoul")
        addBooster("tool_hammer", 5)
    }

    @Test fun usedItemsDoNotComeBack() {
        val cloud = played()
        val here = cloud.copy()
        assertTrue(here.useBooster("tool_hammer"))
        // 같은 레벨 수에서 아이템을 쓴 쪽이 더 나중에 바꾼 쪽이다.
        assertEquals(4, here.merging(cloud).boosterCount("tool_hammer"))
        assertEquals(4, cloud.merging(here).boosterCount("tool_hammer"))
        val upload = assertNotNull(CloudGate(here, start).upload(here, cloud))
        assertEquals(4, upload.boosterCount("tool_hammer"))
    }

    @Test fun stampSurvivesJson() {
        val p = played()
        assertEquals(p.boosterStamp, GameProgress.fromJson(p.toJson()).boosterStamp)
        assertEquals(0, GameProgress.fromJson("""{"stars":{},"bestScores":{}}""").boosterStamp)
    }

    @Test fun reinstallRestoresWithoutOverwriting() {
        val backend = FakeCloud().apply { stored = played() }
        var enabled = true
        val sync = CloudSync(backend, { enabled }, now = { start })
        var local = GameProgress()
        sync.start(local) { local = local.merging(it); sync.push(local) }
        // 받기 전에 저장해도 올리지 않는다.
        local.addBooster("tool_hammer")
        sync.push(local)
        backend.runAll()
        assertEquals(3, local.stars("seoul-001"))
        assertEquals(3, assertNotNull(backend.stored).stars("seoul-001"))
        assertEquals(setOf("gate"), backend.stored!!.restoredParts("seoul"))
    }

    @Test fun unreadableCloudIsNotOverwritten() {
        val backend = FakeCloud().apply { stored = played(); unreadable = true }
        val sync = CloudSync(backend, { true }, now = { start + 120.seconds })
        val local = GameProgress().apply { recordClear("seoul-002", 1, 10) }
        sync.start(local) {}
        sync.push(local)
        backend.runAll()
        assertNull(backend.stored!!.let { if (it.stars("seoul-002") == 0) null else it })
    }

    @Test fun resetDropsInFlightWorkAndWaitsForClear() {
        val backend = FakeCloud().apply { stored = played() }
        val sync = CloudSync(backend, { true }, now = { start })
        var local = played()
        var remoteCalls = 0
        sync.start(local) { remoteCalls++ }
        // 받기가 끝나기 전에 처음부터 다시 한다.
        sync.clear()
        local = GameProgress().apply { recordClear("seoul-001", 1, 10) }
        sync.push(local)
        backend.runAll()
        assertEquals(0, remoteCalls)
        val stored = assertNotNull(backend.stored)
        assertEquals(1, stored.stars("seoul-001"))
        assertTrue(stored.restoredParts("seoul").isEmpty())
    }

    @Test fun turningOffStopsUploads() {
        val backend = FakeCloud()
        var enabled = true
        val sync = CloudSync(backend, { enabled }, now = { start })
        val local = played()
        sync.start(local) {}
        enabled = false
        sync.enabledChanged(local)
        backend.runAll()
        assertNull(backend.stored)
    }
}

class CloudSyncReviewTest {
    @Test fun starterToolsDoNotOverwriteLegacyCloud() {
        // 부스터 변경 횟수가 없던 예전 저장(0)에 망치 9개.
        val legacy = GameProgress.fromJson("""{"stars":{"seoul-001":3},"bestScores":{},"boosters":{"tool_hammer":9}}""")
        val fresh = GameProgress().apply { addBooster("tool_hammer", changesStamp = false) }
        assertEquals(9, fresh.merging(legacy).boosterCount("tool_hammer"))
        assertEquals(9, legacy.merging(fresh).boosterCount("tool_hammer"))
    }

    @Test fun failedClearIsRetriedBeforeAnyUpload() {
        val old = GameProgress().apply { recordClear("seoul-001", 3, 100); restore("gate", "seoul") }
        var pending = false
        val backend = object : CloudBackend {
            var stored: GameProgress? = old
            var online = false
            override val isAvailable = true
            override fun load(done: (CloudRead) -> Unit) = done(stored?.let { CloudRead.Found(it.copy()) } ?: CloudRead.Empty)
            override fun update(transform: (CloudRead) -> GameProgress?, done: (Boolean) -> Unit) {
                val next = transform(stored?.let { CloudRead.Found(it.copy()) } ?: CloudRead.Empty)
                if (next != null) stored = next.copy()
                done(next != null)
            }
            override fun clear(done: (Boolean) -> Unit) {
                if (online) stored = null
                done(online)
            }
        }
        val sync = CloudSync(backend, { true }, { pending }, { pending = it }, { start })
        sync.start(old) {}
        sync.clear()
        assertTrue(pending)
        val fresh = GameProgress().apply { recordClear("seoul-001", 1, 10) }
        sync.push(fresh)
        // 지우지 못한 동안은 올리지 않아 예전 기록과 합쳐지지 않는다.
        assertEquals(setOf("gate"), backend.stored!!.restoredParts("seoul"))
        backend.online = true
        sync.push(fresh)
        assertEquals(false, pending)
        val stored = assertNotNull(backend.stored)
        assertEquals(1, stored.stars("seoul-001"))
        assertTrue(stored.restoredParts("seoul").isEmpty())
    }

    @Test fun clearWaitsForInFlightCommit() {
        val backend = FakeCloudForOrder()
        val sync = CloudSync(backend, { true }, now = { start })
        val played = GameProgress().apply { recordClear("seoul-001", 3, 100) }
        sync.start(played) {}
        backend.runNext()  // 받기
        // 올리기가 시작돼 끝나지 않은 사이에 처음부터 다시 한다.
        sync.push(played)
        sync.clear()
        backend.runAll()
        assertNull(backend.stored)
    }
}

/** 일을 하나씩 끝내는 가짜 클라우드. 올리기는 클라우드 쓰기까지 한 번에 끝난다. */
private class FakeCloudForOrder : CloudBackend {
    var stored: GameProgress? = null
    private val pending = ArrayDeque<() -> Unit>()
    override val isAvailable = true
    override fun load(done: (CloudRead) -> Unit) { pending.add { done(stored?.let { CloudRead.Found(it.copy()) } ?: CloudRead.Empty) } }
    override fun update(transform: (CloudRead) -> GameProgress?, done: (Boolean) -> Unit) {
        // 쓸 내용은 연 순간 정해지고, 쓰기는 나중에 끝난다.
        val next = transform(stored?.let { CloudRead.Found(it.copy()) } ?: CloudRead.Empty)
        pending.add { if (next != null) stored = next.copy(); done(next != null) }
    }
    override fun clear(done: (Boolean) -> Unit) { pending.add { stored = null; done(true) } }
    fun runNext() { pending.removeFirstOrNull()?.invoke() }
    fun runAll() { while (pending.isNotEmpty()) runNext() }
}
