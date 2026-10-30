package dev.code404.sporesweep.core

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

// iOS 판 Progress 패키지의 ReviewPromptTests를 옮긴 것이다.

class ReviewPromptTest {
    @Test fun asksAtMilestones() {
        assertTrue(ReviewPrompt.shouldAsk(1, 0))
        assertFalse(ReviewPrompt.shouldAsk(2, 1))
        assertTrue(ReviewPrompt.shouldAsk(3, 1))
        assertFalse(ReviewPrompt.shouldAsk(4, 3))
        assertTrue(ReviewPrompt.shouldAsk(6, 3))
        assertFalse(ReviewPrompt.shouldAsk(7, 6))
    }

    @Test fun asksOnce() {
        assertFalse(ReviewPrompt.shouldAsk(1, 1))
        assertFalse(ReviewPrompt.shouldAsk(3, 3))
    }

    @Test fun noneCompleted() {
        assertFalse(ReviewPrompt.shouldAsk(0, 0))
    }
}
