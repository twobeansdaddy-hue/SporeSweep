import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'

import { SporeGame } from '../hooks/engine.mjs'
import { levels } from '../hooks/levels.mjs'

// 포자 대청소 mods판의 시험. 터미널과 데스크톱에서 같은 동작을 본다.

const SURFACES = ['terminal', 'desktop'] as const
const PANE = { plugin: 'sporesweep', component: 'Pane', props: {}, requestId: 'sporesweep' } as const

/** Claude Code의 저장소 대신 쓰는 메모리 저장소. */
function memoryStore(on: On, start: Record<string, unknown> = {}) {
  const data = new Map(Object.entries(start))
  // $의 호출에 답할 때는 { value }로 감싸서 돌려준다.
  on('store.get', async (_$, e) => ({ value: data.get(e.key) }))
  on('store.set', async (_$, e) => {
    data.set(e.key, e.value)
    return { value: undefined }
  })
  return data
}

/** 그려진 글자를 한 줄로 모은다. */
async function textOf(ui: { findAll: (query: { type: 'Text'; in: string }) => Promise<{ text?: string }[]> }): Promise<string> {
  return (await ui.findAll({ type: 'Text', in: 'game' })).map(one => one.text ?? '').join('\n')
}

/** 서울 1단계에서 둘 수 있는 수(레벨 설명이 있어 늘 같은 보드다). [열, 행, 열, 행] */
function seoulHint(): number[] {
  return new SporeGame(levels['seoul-001'] ?? '{}', 0).hint()
}

const MOVES = JSON.parse(levels['seoul-001'] ?? '{}').moves as number

for (const surface of SURFACES) {
  test(`이어하기를 눌러 서울 1단계를 시작하고 키보드로 한 수를 둔다 (${surface})`, async ($, on) => {
    memoryStore(on)
    const ui = await $.ui.mount({ ...PANE, surface })
    let text = await textOf(ui)
    expect(text).toContain('이어하기: 서울 1단계')
    // 잠긴 도시는 다음 도시 하나만 보인다.
    expect(text).toContain('다음 도시 도쿄')
    expect(text).not.toContain('베이징')
    // 이어하기 단추는 넷째 줄에 있다.
    await ui.pointer({ type: 'down', x: 2, y: 3, button: 'left' })
    text = await textOf(ui)
    expect(text).toContain('서울 1단계')
    expect(text).toContain(`남은 이동 ${MOVES}`)
    // 커서는 (3, 5)에서 시작한다. 힌트의 칸까지 옮겨 잡고 그 방향으로 민다.
    const [fc = 0, fr = 0, tc = 0, tr = 0] = seoulHint()
    const steps = [
      ...Array(Math.abs(fc - 3)).fill(fc > 3 ? 'right' : 'left'),
      ...Array(Math.abs(fr - 5)).fill(fr > 5 ? 'down' : 'up'),
    ]
    for (const key of steps) await ui.key({ key, in: 'game' })
    await ui.key({ key: 'return', in: 'game' })
    await ui.key({ key: tc > fc ? 'right' : tc < fc ? 'left' : tr > fr ? 'down' : 'up', in: 'game' })
    expect(await textOf(ui)).toContain(`남은 이동 ${MOVES - 1}`)
  })

  test(`블록을 잡고 옆 칸으로 끌면 바뀐다 (${surface})`, async ($, on) => {
    memoryStore(on)
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.key({ key: 'c', in: 'game' })
    // 시험의 창(80×30)에서는 칸이 폭 5, 높이 2로 그려지고 보드는 셋째 줄부터다.
    const [fc = 0, fr = 0, tc = 0, tr = 0] = seoulHint()
    const at = (c: number, r: number) => ({ x: c * 5 + 1, y: 2 + r * 2 })
    await ui.pointer({ type: 'down', ...at(fc, fr), button: 'left' })
    await ui.pointer({ type: 'move', ...at(tc, tr), button: 'left' })
    await ui.pointer({ type: 'up', ...at(tc, tr), button: 'left' })
    expect(await textOf(ui)).toContain(`남은 이동 ${MOVES - 1}`)
  })

  test(`힌트 단추와 메뉴 단추가 눌린다 (${surface})`, async ($, on) => {
    memoryStore(on)
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.key({ key: 'c', in: 'game' })
    await ui.key({ key: 'h', in: 'game' })
    expect(await textOf(ui)).toContain('반짝이는 두 칸')
    await ui.key({ key: 'm', in: 'game' })
    expect(await textOf(ui)).toContain('이어하기')
  })

  test(`보낸 진행을 저장하고 메뉴에 별로 보여준다 (${surface})`, async ($, on) => {
    const store = memoryStore(on)
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.post({ type: 'progress', progress: { 'seoul-001': 3, 'seoul-002': 1 } }, { in: 'game' })
    expect(store.get('progress')).toEqual({ 'seoul-001': 3, 'seoul-002': 1 })
    await ui.unmount()
    const again = await $.ui.mount({ ...PANE, surface })
    const text = await textOf(again)
    expect(text).toContain('⭐ 4/36')
    expect(text).toContain('이어하기: 서울 3단계')
  })
}
