package dev.code404.sporesweep.core

import kotlin.test.Test
import kotlin.test.fail

/**
 * iOS 판(Swift)이 둔 판을 그대로 다시 두고, 수마다 이벤트와 상태가 글자 하나까지 같은지 본다.
 * 기준 기록은 `swift run -c release paritygen <폴더> 40`으로 만든다(LevelData 패키지).
 */
class ParityTest {
    private fun level(id: String) = Level.parse(testResource("$id.json"))

    private fun parsePosition(column: String, row: String) = Position(column.toInt(), row.toInt())

    private class Mismatch(val level: String, val step: String, val kind: String, val expected: String, val actual: String)

    private var levelsReplayed = 0
    private var stepsReplayed = 0

    private fun replay(city: String): List<Mismatch> {
        val lines = testResource("parity/$city.txt.gz").lines().filter { it.isNotEmpty() }
        val mismatches = mutableListOf<Mismatch>()
        var i = 0
        while (i < lines.size) {
            val header = lines[i++]
            check(header.startsWith("level ")) { "기록 형식이 틀렸다: $header" }
            val id = header.removePrefix("level ").substringBefore(" ")
            val boosters = header.substringAfter("boosters=").split(",").filter { it.isNotEmpty() }.map { Booster.byName(it)!! }
            levelsReplayed += 1
            var state = level(id).makeState()
            state.apply(boosters)
            var step = "시작"
            var failed = false
            fun compare(kind: String, expected: String, actual: String) {
                if (!failed && expected != actual) {
                    mismatches.add(Mismatch(id, step, kind, expected, actual))
                    failed = true
                }
            }
            compare("state", lines[i++].removePrefix("state "), ParityFormat.state(state))
            while (i < lines.size && lines[i].startsWith("do ")) {
                val action = lines[i++].removePrefix("do ")
                step = action
                stepsReplayed += 1
                val words = action.split(" ")
                var result: TurnResult? = null
                when (words[0]) {
                    "continue" -> {
                        state = state.copy()
                        state.continuePlaying(words[1].toInt())
                    }
                    "swap" -> result = state.performTurn(Swap(parsePosition(words[1], words[2]), parsePosition(words[3], words[4])))
                    "free" -> result = state.freeSwapping(Swap(parsePosition(words[1], words[2]), parsePosition(words[3], words[4])))
                    "hammer" -> result = state.hammering(parsePosition(words[1], words[2]))
                    "shuffle" -> result = state.shuffling()
                    else -> error("모르는 수: $action")
                }
                if (words[0] != "continue") {
                    val expected = lines[i++].removePrefix("events ")
                    if (result == null) {
                        compare("events", expected, "(이 수를 둘 수 없다고 했다)")
                    } else {
                        compare("events", expected, result.events.joinToString(" ") { ParityFormat.event(it) })
                        state = result.state
                    }
                }
                compare("state", lines[i++].removePrefix("state "), ParityFormat.state(state))
            }
        }
        return mismatches
    }

    /** 두 글이 처음 달라지는 곳의 앞뒤를 보여준다. */
    private fun firstDifference(expected: String, actual: String): String {
        val index = expected.zip(actual).indexOfFirst { it.first != it.second }.let { if (it < 0) minOf(expected.length, actual.length) else it }
        val from = maxOf(0, index - 120)
        return "  기대: …${expected.substring(from, minOf(expected.length, index + 160))}\n  실제: …${actual.substring(from, minOf(actual.length, index + 160))}"
    }

    @Test
    fun allLevelsMatchSwift() {
        val cities = LevelCatalog.cityIDs + listOf("lab", "sample")
        val all = cities.flatMap { replay(it) }
        println("Swift 기록과 비교: 레벨 ${levelsReplayed}개, 수 ${stepsReplayed}개")
        // 기록이 비어서 아무것도 비교하지 않고 통과하는 일이 없게 한다.
        check(levelsReplayed >= 390 && stepsReplayed >= 10_000) { "비교한 것이 너무 적다" }
        if (all.isNotEmpty()) {
            val report = all.take(5).joinToString("\n\n") {
                "${it.level} / ${it.step} / ${it.kind}\n" + firstDifference(it.expected, it.actual)
            }
            fail("Swift와 다른 레벨 ${all.size}개\n\n$report")
        }
    }
}
