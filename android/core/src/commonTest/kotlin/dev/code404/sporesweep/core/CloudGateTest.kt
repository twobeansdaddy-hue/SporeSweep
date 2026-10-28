package dev.code404.sporesweep.core

import kotlin.time.Duration.Companion.seconds
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

// iOS 판 Progress 패키지의 CloudGateTests를 옮긴 것이다.

class CloudGateTest {
    private fun played() = GameProgress().apply {
        recordClear("seoul-001", 3, 1200)
        recordClear("seoul-002", 2, 900)
        restore("gate", "seoul")
        addBooster("bomb", 4)
    }

    @Test fun freshInstallWaits() {
        val fresh = GameProgress().apply { addBooster("bomb") }
        val gate = CloudGate(fresh, start)
        assertFalse(gate.isOpen)
        assertNull(gate.upload(fresh, null))
    }

    @Test fun reinstallKeepsCloud() {
        val cloud = played()
        val fresh = GameProgress().apply { addBooster("bomb") }
        val gate = CloudGate(fresh, start)
        gate.cloudSeen()
        assertNull(gate.upload(fresh, cloud))
        val merged = fresh.merging(cloud)
        assertEquals(3, merged.stars("seoul-001"))
        assertEquals(setOf("gate"), merged.restoredParts("seoul"))
        assertEquals(4, merged.boosterCount("bomb"))
    }

    @Test fun opensAfterWait() {
        val gate = CloudGate(GameProgress(), start)
        gate.tick(start + CloudGate.MAX_WAIT - 1.seconds)
        assertFalse(gate.isOpen)
        gate.tick(start + CloudGate.MAX_WAIT)
        assertTrue(gate.isOpen)
    }

    @Test fun existingDeviceOpens() {
        val here = GameProgress().apply { recordClear("seoul-003", 1, 300) }
        val gate = CloudGate(here, start)
        assertTrue(gate.isOpen)
        val upload = assertNotNull(gate.upload(here, played()))
        assertEquals(3, upload.stars("seoul-001"))
        assertEquals(1, upload.stars("seoul-003"))
    }

    @Test fun reuploadsWhenCloudIsBehind() {
        val here = played()
        val behind = GameProgress().apply { recordClear("seoul-001", 1, 100) }
        val gate = CloudGate(here, start)
        val upload = assertNotNull(gate.upload(here, behind))
        assertEquals(3, upload.stars("seoul-001"))
        assertEquals(2, upload.stars("seoul-002"))
        assertNull(gate.upload(here, upload))
    }

    @Test fun deviceStateDoesNotPingPong() {
        val shared = played()
        val here = shared.copy().apply { lives.set(1, start) }
        assertNull(CloudGate(here, start).upload(here, shared))
    }

    @Test fun boosterTieConverges() {
        val a = GameProgress().apply { recordClear("seoul-001", 2, 100); addBooster("bomb", 1) }
        val b = GameProgress().apply { recordClear("seoul-002", 2, 100); addBooster("beam", 3) }
        assertEquals(3, a.merging(b).boosterCount("beam"))
        assertEquals(3, b.merging(a).boosterCount("beam"))
        assertEquals(0, a.merging(b).boosterCount("bomb"))
        val cloud = a.merging(b)
        val gate = CloudGate(a, start)
        assertNull(gate.upload(a.merging(cloud), cloud))
        assertNull(gate.upload(b.merging(cloud), cloud))
    }

    @Test fun zeroClearReinstallKeepsItems() {
        val cloud = GameProgress().apply { addBooster("bomb", 2) }
        val fresh = GameProgress()
        val gate = CloudGate(fresh, start)
        gate.cloudSeen()
        assertNull(gate.upload(fresh, cloud))
        assertEquals(2, fresh.merging(cloud).boosterCount("bomb"))
    }
}
