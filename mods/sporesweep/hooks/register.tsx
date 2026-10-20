import type { Register } from 'claude-code'

// 포자 대청소 mods판. /sporesweep으로 창을 열고, 그 안에서 game.tsx가 판을 그린다.
// 규칙은 iOS·안드로이드·웹과 같은 엔진(engine.mjs, Kotlin을 자바스크립트로 빌드한 것)이다.
// 여기(훅 모듈)는 창을 열고, 진행(레벨마다 받은 별)을 Claude Code의 저장소에 남기는 일만 한다.

const PANE = 'sporesweep'
const PROGRESS = 'progress'

/** 레벨 ID → 받은 별(1~3). 깬 레벨만 들어 있다. */
type Progress = Record<string, number>

function asProgress(value: unknown): Progress {
  if (typeof value !== 'object' || value === null) return {}
  const out: Progress = {}
  for (const [key, stars] of Object.entries(value)) {
    if (typeof stars === 'number' && stars >= 1 && stars <= 3) out[key] = stars
  }
  return out
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'sporesweep',
      description: '포자 대청소: 블록을 맞춰 외계 포자를 치우는 매치3 퍼즐 한 판',
    })
    return next(e)
  })

  on('command.run', { command: 'sporesweep' }, async $ => {
    await $.ui.open({ id: PANE, title: '포자 대청소', focus: true, columns: 96, rows: 40 })
    return { text: '포자 대청소를 열었어요. 블록을 잡고 옆으로 끌어서 바꿔요.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    if (e.surface !== 'terminal' && e.surface !== 'desktop') {
      const { Text } = $.ui.resolve(e)
      return <Text>이 화면에서는 포자 대청소를 열 수 없어요. 터미널이나 데스크톱 앱에서 열어 주세요.</Text>
    }
    const { Box, Client } = $.ui.resolve(e)
    const progress = asProgress(await $.store.get(PROGRESS))
    return (
      <Box flexDirection="column" flexGrow={1}>
        <Client key="game" module="./game.tsx" props={{ progress }} flexGrow={1} />
      </Box>
    )
  })

  // 판을 깨면 game.tsx가 새 진행을 보낸다. 저장하고 그 진행을 다시 넘겨준다.
  on('ui.message', async ($, e, next) => {
    if (e.requestId !== PANE) return next(e)
    const data = e.data as { type?: string; progress?: unknown } | null
    if (data?.type !== 'progress') return next(e)
    const progress = asProgress(data.progress)
    await $.store.set(PROGRESS, progress)
    return { props: { progress } }
  })
}
