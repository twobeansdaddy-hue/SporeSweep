import Testing
@testable import Progress

struct ReviewPromptTests {
    @Test("처음, 세 번째, 여섯 번째로 다 복원했을 때 묻는다")
    func asksAtMilestones() {
        #expect(ReviewPrompt.shouldAsk(completed: 1, askedAt: 0))
        #expect(!ReviewPrompt.shouldAsk(completed: 2, askedAt: 1))
        #expect(ReviewPrompt.shouldAsk(completed: 3, askedAt: 1))
        #expect(!ReviewPrompt.shouldAsk(completed: 4, askedAt: 3))
        #expect(ReviewPrompt.shouldAsk(completed: 6, askedAt: 3))
        #expect(!ReviewPrompt.shouldAsk(completed: 7, askedAt: 6))
    }

    @Test("같은 수에서 두 번 묻지 않는다")
    func asksOnce() {
        #expect(!ReviewPrompt.shouldAsk(completed: 1, askedAt: 1))
        #expect(!ReviewPrompt.shouldAsk(completed: 3, askedAt: 3))
    }

    @Test("아무것도 다 복원하지 않았으면 묻지 않는다")
    func noneCompleted() {
        #expect(!ReviewPrompt.shouldAsk(completed: 0, askedAt: 0))
    }
}
