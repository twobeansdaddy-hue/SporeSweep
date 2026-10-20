package dev.code404.sporesweep.core

/**
 * 시험에 쓰는 파일을 글로 읽는다. 레벨 JSON(`tokyo_01.json`)이나 기준 기록(`parity/tokyo.txt.gz`)의 이름을 받는다.
 * `.gz`로 끝나면 풀어서 돌려준다.
 */
expect fun testResource(name: String): String
