package dev.code404.sporesweep.core

import kotlinx.datetime.TimeZone
import kotlinx.datetime.UtcOffset
import kotlinx.datetime.asTimeZone
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

// Progress 패키지의 Swift 시험(DailyGiftTests, LivesTests, ProgressTests)을 옮긴 것이다.

internal val start: Instant = Instant.fromEpochSeconds(1_800_000_000)
// 서울은 일광 절약 시간이 없어 UTC+9로 고정해도 같다. 웹에서는 시간대 이름 표가 없어서 이름으로 찾지 않는다.
internal val seoul: TimeZone = UtcOffset(hours = 9).asTimeZone()
internal fun day(offset: Int): Instant = start + (offset * 86_400L).seconds
internal fun minutes(value: Int): Instant = start + (value * 60L).seconds
internal val levels = (1..12).map { "seoul-" + it.toString().padStart(3, '0') }

class DailyGiftTest {
    @Test fun oncePerDay() {
        val gift = DailyGift()
        assertTrue(gift.canClaim(start, seoul))
        assertEquals(DailyGift.REWARDS[0], gift.claim(start, seoul))
        assertFalse(gift.canClaim((start + 3600.seconds), seoul))
        assertNull(gift.claim((start + 3600.seconds), seoul))
    }

    @Test fun streak() {
        val gift = DailyGift()
        for (index in 0 until 8) {
            assertEquals(index % 7 + 1, gift.nextDay(day(index), seoul))
            assertEquals(DailyGift.REWARDS[index % 7], gift.claim(day(index), seoul))
        }
    }

    @Test fun missedDay() {
        val gift = DailyGift()
        gift.claim(day(0), seoul)
        gift.claim(day(1), seoul)
        assertEquals(1, gift.nextDay(day(3), seoul))
        assertEquals(DailyGift.REWARDS[0], gift.claim(day(3), seoul))
    }

    @Test fun clockRollback() {
        val gift = DailyGift()
        gift.claim(day(2), seoul)
        assertFalse(gift.canClaim(day(0), seoul))
    }

    @Test fun seventhDay() {
        assertEquals(DailyGift.CYCLE, DailyGift.REWARDS.size)
        assertTrue("lives" in DailyGift.REWARDS[6])
        assertEquals(3, DailyGift.REWARDS[6].count { it.startsWith("tool:") })
    }

    @Test fun merging() {
        val here = GameProgress()
        here.recordClear("a", 3, 100)
        here.recordClear("b", 1, 500)
        here.restore("gate", "seoul")
        here.addBooster("bomb", 2)
        val there = GameProgress()
        there.recordClear("a", 1, 900)
        there.recordClear("b", 2, 50)
        there.recordClear("c", 2, 70)
        there.restore("roof", "seoul")
        there.addBooster("beam", 1)
        val merged = here.merging(there)
        assertEquals(3, merged.stars("a"))
        assertEquals(2, merged.stars("b"))
        assertEquals(2, merged.stars("c"))
        assertEquals(900, merged.bestScore("a"))
        assertEquals(setOf("gate", "roof"), merged.restoredParts("seoul"))
        assertEquals(1, merged.boosterCount("beam"))
        assertEquals(0, merged.boosterCount("bomb"))
        val reversed = there.merging(here)
        assertEquals(3, reversed.stars("a"))
        assertEquals(setOf("gate", "roof"), reversed.restoredParts("seoul"))
    }

    @Test fun decodesOldFile() {
        val old = GameProgress.fromJson("""{"stars":{},"bestScores":{}}""")
        assertTrue(old.daily.canClaim(start, seoul))
    }
}

class LivesTest {
    @Test fun startsFull() {
        val lives = Lives()
        assertEquals(5, lives.count(start))
        assertNull(lives.timeUntilNext(start))
    }

    @Test fun refills() {
        val lives = Lives()
        assertTrue(lives.lose(start))
        assertEquals(4, lives.count(start))
        assertEquals(20 * 60.0, lives.timeUntilNext(minutes(10)))
        assertEquals(4, lives.count(minutes(29)))
        assertEquals(5, lives.count(minutes(30)))
        assertNull(lives.timeUntilNext(minutes(30)))
    }

    @Test fun keepsTimer() {
        val lives = Lives()
        lives.lose(start)
        lives.lose(minutes(20))
        assertEquals(3, lives.count(minutes(20)))
        assertEquals(10 * 60.0, lives.timeUntilNext(minutes(20)))
        assertEquals(4, lives.count(minutes(30)))
        assertEquals(5, lives.count(minutes(60)))
    }

    @Test fun settlesPartialTime() {
        val lives = Lives()
        lives.lose(start)
        lives.lose(start)
        lives.lose(minutes(45))
        assertEquals(3, lives.count(minutes(45)))
        assertEquals(15 * 60.0, lives.timeUntilNext(minutes(45)))
    }

    @Test fun cannotGoBelowZero() {
        val lives = Lives()
        repeat(5) { lives.lose(start) }
        assertEquals(0, lives.count(start))
        assertFalse(lives.lose(start))
        assertEquals(5, lives.count(minutes(60 * 24)))
    }

    @Test fun clockRollback() {
        val lives = Lives()
        lives.lose(start)
        assertEquals(4, lives.count(minutes(-120)))
        assertEquals(30 * 60.0, lives.timeUntilNext(minutes(-120)))
    }

    @Test fun adGrant() {
        val lives = Lives()
        assertFalse(lives.addFromAd(start, seoul))
        lives.lose(start)
        lives.lose(start)
        assertTrue(lives.addFromAd(minutes(1), seoul))
        assertEquals(4, lives.count(minutes(1)))
        assertEquals(29 * 60.0, lives.timeUntilNext(minutes(1)))
        assertTrue(lives.addFromAd(minutes(2), seoul))
        assertNull(lives.timeUntilNext(minutes(2)))
    }

    @Test fun dailyAdLimit() {
        val lives = Lives()
        for (index in 0 until 5) {
            lives.set(0, minutes(index))
            assertTrue(lives.addFromAd(minutes(index), seoul))
        }
        lives.set(0, minutes(6))
        assertEquals(0, lives.adGrantsLeft(minutes(6), seoul))
        assertFalse(lives.addFromAd(minutes(6), seoul))
        val tomorrow = minutes(60 * 24)
        assertEquals(5, lives.adGrantsLeft(tomorrow, seoul))
        lives.set(0, tomorrow)
        assertTrue(lives.addFromAd(tomorrow, seoul))
    }

    @Test fun codable() {
        val progress = GameProgress()
        progress.lives.lose(start)
        val loaded = GameProgress.fromJson(progress.toJson())
        assertEquals(4, loaded.lives.count(start))
        val old = GameProgress.fromJson("""{"stars":{},"bestScores":{}}""")
        assertEquals(5, old.lives.count(start))
    }
}

class GameProgressTest {
    @Test fun boosters() {
        val progress = GameProgress()
        assertEquals(0, progress.boosterCount("bomb"))
        assertFalse(progress.useBooster("bomb"))
        progress.addBooster("bomb")
        progress.addBooster("bomb", 2)
        progress.addBooster("beam", 0)
        assertEquals(3, progress.boosterCount("bomb"))
        assertEquals(0, progress.boosterCount("beam"))
        assertTrue(progress.useBooster("bomb"))
        assertEquals(2, progress.boosterCount("bomb"))
    }

    @Test fun boostersPersist() {
        val decoded = GameProgress.fromJson("""{"stars":{"seoul-001":2},"bestScores":{"seoul-001":900}}""")
        assertEquals(0, decoded.boosterCount("bomb"))
        assertEquals(2, decoded.stars("seoul-001"))
        val progress = GameProgress()
        progress.addBooster("core", 2)
        val again = GameProgress.fromJson(progress.toJson())
        assertEquals(progress, again)
        assertEquals(2, again.boosterCount("core"))
    }

    @Test fun empty() {
        val progress = GameProgress()
        assertEquals(0, progress.stars("seoul-001"))
        assertEquals(0, progress.bestScore("seoul-001"))
        assertFalse(progress.isCleared("seoul-001"))
        assertEquals(0, progress.clearedCount(levels))
        assertEquals(0, progress.totalStars(levels))
    }

    @Test fun recordClear() {
        val progress = GameProgress()
        assertTrue(progress.recordClear("seoul-001", 2, 9000))
        assertEquals(2, progress.stars("seoul-001"))
        assertEquals(9000, progress.bestScore("seoul-001"))
        assertTrue(progress.isCleared("seoul-001"))
        assertEquals(1, progress.clearedCount(levels))
    }

    @Test fun keepsBest() {
        val progress = GameProgress()
        progress.recordClear("seoul-001", 2, 9000)
        assertTrue(progress.recordClear("seoul-001", 1, 9500))
        assertEquals(2, progress.stars("seoul-001"))
        assertEquals(9500, progress.bestScore("seoul-001"))
        assertFalse(progress.recordClear("seoul-001", 1, 100))
        assertTrue(progress.recordClear("seoul-001", 3, 100))
        assertEquals(3, progress.stars("seoul-001"))
        assertEquals(9500, progress.bestScore("seoul-001"))
    }

    @Test fun clampsStars() {
        val progress = GameProgress()
        progress.recordClear("a", 0, 10)
        progress.recordClear("b", 7, 10)
        assertEquals(1, progress.stars("a"))
        assertEquals(3, progress.stars("b"))
    }

    @Test fun unlocking() {
        val progress = GameProgress()
        assertTrue(progress.isUnlocked(0, levels))
        assertFalse(progress.isUnlocked(1, levels))
        progress.recordClear(levels[0], 1, 1)
        assertTrue(progress.isUnlocked(1, levels))
        assertFalse(progress.isUnlocked(2, levels))
        assertFalse(progress.isUnlocked(12, levels))
        assertFalse(progress.isUnlocked(-1, levels))
    }

    @Test fun totalStars() {
        val progress = GameProgress()
        progress.recordClear(levels[0], 3, 1)
        progress.recordClear(levels[1], 2, 1)
        progress.recordClear("other-001", 3, 1)
        assertEquals(5, progress.totalStars(levels))
        assertEquals(2, progress.clearedCount(levels))
    }
}

class RestoredPartsTest {
    @Test fun empty() = assertTrue(GameProgress().restoredParts("seoul").isEmpty())

    @Test fun restore() {
        val progress = GameProgress()
        assertTrue(progress.restore("gate", "seoul") && progress.restore("wallLeft", "seoul") && progress.restore("gate", "busan"))
        assertEquals(setOf("gate", "wallLeft"), progress.restoredParts("seoul"))
        assertEquals(setOf("gate"), progress.restoredParts("busan"))
    }

    @Test fun restoreTwice() {
        val progress = GameProgress()
        progress.restore("gate", "seoul")
        assertFalse(progress.restore("gate", "seoul"))
        assertEquals(1, progress.restoredParts("seoul").size)
    }

    @Test fun decodesOldFile() {
        val progress = GameProgress.fromJson("""{ "stars": { "seoul-001": 2 }, "bestScores": { "seoul-001": 9000 } }""")
        assertEquals(2, progress.stars("seoul-001"))
        assertTrue(progress.restoredParts("seoul").isEmpty())
    }
}

class WorldTest {
    private fun resource(name: String) = testResource(name)

    /** iOS 판 CityTests의 검증을 옮긴 것이다. 모든 도시를 읽고, 복원 계획이 레벨 수로 감당되는지 본다. */
    @Test fun allCitiesLoad() {
        assertEquals(LevelCatalog.cityIDs, RegionCatalog.cityIDs)
        for (id in LevelCatalog.cityIDs) {
            val city = City.parse(resource("$id.json"))
            assertEquals(id, city.id)
            assertTrue(city.landmark.parts.isNotEmpty())
            val seen = HashSet<String>()
            for (part in city.landmark.parts) {
                assertTrue(part.cost >= 1)
                assertTrue(part.requires.all { it in seen }, "${city.id}/${part.id}")
                seen.add(part.id)
            }
        }
    }

    @Test fun blockers() {
        val landmark = Landmark("t", "t", listOf(Landmark.Part("a", "a", 3), Landmark.Part("b", "b", 2, listOf("a"))))
        assertEquals(RestoreBlocker.Requires("a"), landmark.blocker("b", 9, emptySet()))
        assertEquals(RestoreBlocker.NotEnoughStars(1), landmark.blocker("a", 2, emptySet()))
        assertNull(landmark.blocker("a", 3, emptySet()))
        assertEquals(RestoreBlocker.AlreadyRestored, landmark.blocker("a", 3, setOf("a")))
        assertEquals(4, landmark.availableStars(9, setOf("a", "b")))
        assertTrue(landmark.isFullyRestored(setOf("a", "b")))
    }
}
