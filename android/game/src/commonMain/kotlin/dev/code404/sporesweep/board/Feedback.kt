package dev.code404.sporesweep.board

/** 효과음의 종류. 파일 이름과 같다(iOS 판 GameSound). */
enum class GameSound(val file: String) {
    SWAP("swap"), REJECT("reject"),
    CLEAR1("clear1"), CLEAR2("clear2"), CLEAR3("clear3"), CLEAR4("clear4"), CLEAR5("clear5"),
    SPECIAL("special"), CREATE("create"), CRACK("crack"), COLLECT("collect"), WIN("win"), LOSE("lose"),
    RESTORE("restore"), TAP("tap"), DRONE("drone"),
    INTRO_EARTH("introEarth"), INTRO_INVASION("introInvasion"), INTRO_RUIN("introRuin"), INTRO_HERO("introHero"), INTRO_ARRIVAL("introArrival");

    companion object {
        /** 연쇄 번호에 맞는 제거음. 5번째부터는 같다. */
        fun clear(chain: Int) = listOf(CLEAR1, CLEAR2, CLEAR3, CLEAR4, CLEAR5)[chain.coerceIn(1, 5) - 1]
    }
}

enum class GameHaptic { LIGHT, MEDIUM, HEAVY, SUCCESS, WARNING, FAILURE }

/** 효과음과 진동을 낼 곳. */
interface Feedback {
    fun play(sound: GameSound)
    fun haptic(haptic: GameHaptic)
}
