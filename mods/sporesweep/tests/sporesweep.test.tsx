import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'

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

for (const surface of SURFACES) {
  test(`메뉴에서 Enter로 서울 1단계를 시작하고 힌트대로 한 수를 둔다 (${surface})`, async ($, on) => {
    memoryStore(on)
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await textOf(ui)).toContain('포자 대청소')
    await ui.key({ key: 'return', in: 'game' })
    let text = await textOf(ui)
    expect(text).toContain('서울 1단계')
    expect(text).toContain('이동 15')
    // 서울 1단계는 레벨 설명이 있어 늘 같은 보드로 시작한다. 힌트가 가리키는 칸을 잡아 그 방향으로 민다.
    await ui.key({ key: 'h', in: 'game' })
    text = await textOf(ui)
    const direction = /여기를 (오른|왼|아래|위) 쪽으로/.exec(text)?.[1]
    expect(direction).toBeDefined()
    await ui.key({ key: 'return', in: 'game' })
    const keys: Record<string, string> = { 오른: 'right', 왼: 'left', 아래: 'down', 위: 'up' }
    await ui.key({ key: keys[direction ?? '오른'] ?? 'right', in: 'game' })
    expect(await textOf(ui)).toContain('이동 14')
  })

  test(`보낸 진행을 저장하고 메뉴에 별로 보여준다 (${surface})`, async ($, on) => {
    const store = memoryStore(on)
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.post({ type: 'progress', progress: { 'seoul-001': 3, 'seoul-002': 1 } }, { in: 'game' })
    expect(store.get('progress')).toEqual({ 'seoul-001': 3, 'seoul-002': 1 })
    await ui.unmount()
    const again = await $.ui.mount({ ...PANE, surface })
    expect(await textOf(again)).toContain('★ 4/36')
  })
}
