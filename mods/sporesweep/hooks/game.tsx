import type { ClientKeyEvent, ClientModule, ClientPointerEvent, ClientSurface } from 'claude-code'

import { SporeGame } from './engine.mjs'
import { cities, levels } from './levels.mjs'

// 포자 대청소 mods판의 화면. 창 안의 Client 영역에서 돈다(터미널과 데스크톱 앱).
//
// 보드는 활성 구간 8×10칸을 한 칸에 글자 세 개로 그린다. 블록은 종류마다 바탕색과 머리글자가 다르다.
// 조작: 방향키로 칸 고르기, Enter나 Space로 잡기, 잡은 채로 방향키로 밀기. 마우스로 칸을 누르고 옆 칸을 눌러도 된다.

type Progress = Record<string, number>
type Props = { progress?: Progress }
type Cell = { c: number; r: number }

type State = {
  screen: 'menu' | 'game'
  city: number
  level: number
  cursor: Cell
  picked: Cell | null
  game: SporeGame | null
  note: string
  progress: Progress
  /** 이 판의 결과를 이미 저장했는지. */
  saved: boolean
}

/** 보드 위에 쓰는 줄 수. 마우스 좌표를 칸으로 바꿀 때 쓴다. */
const HEADER_ROWS = 2
/** 한 칸의 폭(글자 수). */
const CELL = 3

// 일반 블록 여섯 종류: 바탕색, 머리글자. 벽돌, 너트(고철), 유리, 전선 릴(나무), 원뿔(플라스틱), 흙.
const KINDS: [string, string][] = [
  ['#d9554a', 'B'],
  ['#9aa6b8', 'N'],
  ['#4cc7e6', 'G'],
  ['#e9a93f', 'W'],
  ['#6ccb5f', 'P'],
  ['#a87bd8', 'S'],
]
const DARK = '#1c1f33'
const PINK = '#ff4fa3'

/** 칸 코드(engine.cells)를 세 글자와 색으로. */
function look(code: string): { text: string; fg: string; bg: string } {
  const kind = Number(code.slice(1))
  switch (code[0]) {
    case '.': return { text: '   ', fg: DARK, bg: DARK }
    case '?': return { text: '???', fg: '#d8c8ff', bg: '#4b3a73' }
    case 'H': return { text: '<=>', fg: '#7ff3ff', bg: '#24304f' }
    case 'V': return { text: '/|\\', fg: '#7ff3ff', bg: '#24304f' }
    case 'X': return { text: '(X)', fg: '#ffb347', bg: '#24304f' }
    case 'C': return { text: '(C)', fg: '#ffffff', bg: '#5b3fa8' }
    case 'D': return { text: '-D-', fg: '#7ff3ff', bg: '#1f6f8b' }
    case 'M': return { text: ' @ ', fg: '#3a0a22', bg: PINK }
    case 'W': return { text: '###', fg: '#55596e', bg: '#2a2d40' }
    case 'K': return { text: kind >= 2 ? '[K]' : '[k]', fg: '#ffffff', bg: '#7d8191' }
    case 'S': return { text: '~~~', fg: '#f3d36b', bg: '#5a4524' }
    case 'R': return { text: ':::', fg: '#e8e2d6', bg: '#6d6458' }
    case 'N': return { text: '(N)', fg: '#ffd1e8', bg: '#7a1f4a' }
    case 'E': return { text: '(e)', fg: '#ffc94d', bg: '#23305e' }
    case 'U': return { text: '(U)', fg: '#ff9a4d', bg: '#3b2a24' }
    case 'F': return { text: '^F^', fg: '#cfd8ff', bg: '#3a4566' }
    case 'G': return { text: `[${KINDS[kind]?.[1] ?? '?'}]`, fg: '#ffffff', bg: KINDS[kind]?.[0] ?? DARK }
    case 'L': return { text: `{${KINDS[kind]?.[1] ?? '?'}}`, fg: '#ffd84d', bg: KINDS[kind]?.[0] ?? DARK }
    case 'O': return { text: `(${KINDS[kind]?.[1] ?? '?'})`, fg: '#ffd1e8', bg: '#7a1f4a' }
    case 'T': return { text: ` ${KINDS[kind]?.[1] ?? '?'}!`, fg: PINK, bg: KINDS[kind]?.[0] ?? DARK }
    case 'I': return { text: `*${KINDS[kind]?.[1] ?? '?'}*`, fg: '#1c3a52', bg: '#bfe9ff' }
    default: {
      const [bg, letter] = KINDS[Number(code)] ?? [DARK, '?']
      return { text: ` ${letter} `, fg: '#16182a', bg }
    }
  }
}

/** 도시 하나. 번호가 범위 밖이면 마지막 도시다. */
function cityAt(index: number) {
  return cities[Math.min(Math.max(index, 0), cities.length - 1)]!
}

/** 레벨 ID. */
function levelAt(city: number, level: number): string {
  const ids = cityAt(city).levels
  return ids[Math.min(Math.max(level, 0), ids.length - 1)]!
}

function cityUnlocked(progress: Progress, index: number): boolean {
  if (index === 0) return true
  return cityAt(index - 1).levels.every(id => (progress[id] ?? 0) > 0)
}

function levelUnlocked(progress: Progress, city: number, level: number): boolean {
  if (!cityUnlocked(progress, city)) return false
  if (level === 0) return true
  return (progress[levelAt(city, level - 1)] ?? 0) > 0
}

/** 처음 열었을 때 둘 곳: 아직 깨지 않은 첫 레벨. */
function firstOpen(progress: Progress): { city: number; level: number } {
  for (let c = 0; c < cities.length; c++) {
    for (let l = 0; l < cityAt(c).levels.length; l++) {
      if (!levelUnlocked(progress, c, l)) return { city: c, level: Math.max(l - 1, 0) }
      if ((progress[levelAt(c, l)] ?? 0) === 0) return { city: c, level: l }
    }
  }
  return { city: cities.length - 1, level: cityAt(cities.length - 1).levels.length - 1 }
}

function startGame(state: State, city: number, level: number): State {
  const id = levelAt(city, level)
  const json = levels[id] ?? '{}'
  // 판마다 시작 보드가 다르다. 레벨 설명이 있는 판은 늘 같은 보드다(엔진이 0을 레벨의 시드로 본다).
  const hasTutorial = json.includes('"tutorial"')
  const seed = hasTutorial ? 0 : Math.floor(Math.random() * 2_000_000_000) + 1
  const game = new SporeGame(json, seed)
  return {
    ...state,
    screen: 'game',
    city,
    level,
    game,
    picked: null,
    cursor: { c: 3, r: 5 },
    saved: false,
    note: game.tutorial ?? '방향키로 칸을 고르고 Enter로 잡은 뒤, 방향키로 밀어요.',
  }
}

const DIRECTIONS: Record<string, [number, number]> = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }

const REASONS: Record<string, string> = {
  nomatch: '그렇게 밀면 맞춰지는 게 없어요.',
  immovable: '그 칸은 움직일 수 없어요.',
  emptycell: '빈칸이에요.',
  outofbounds: '보드 밖이에요.',
  notadjacent: '바로 옆 칸만 바꿀 수 있어요.',
  gameover: '판이 끝났어요.',
}

function trySwap(state: State, from: Cell, to: Cell): State {
  const game = state.game
  if (!game) return state
  const result = game.swap(from.c, from.r, to.c, to.r)
  if (result !== 'ok') return { ...state, picked: null, note: REASONS[result] ?? result }
  return { ...state, picked: null, cursor: to, note: game.last || '좋아요!' }
}

/** 판이 끝났으면 별을 진행에 더하고 훅 모듈에 보낸다. */
function settle(state: State, surface: ClientSurface<State>): State {
  const game = state.game
  if (!game || state.saved || game.status === 'playing') return state
  if (game.status !== 'won') return { ...state, saved: true }
  const id = levelAt(state.city, state.level)
  const stars = Math.max(game.stars(), state.progress[id] ?? 0)
  const progress = { ...state.progress, [id]: stars }
  surface.post({ type: 'progress', progress })
  return { ...state, progress, saved: true }
}

function onKey(event: ClientKeyEvent, state: State, surface: ClientSurface<State>) {
  const key = event.key.toLowerCase()
  if (state.screen === 'menu') {
    let { city, level } = state
    if (key === 'up' && city > 0) { city -= 1; level = 0 }
    if (key === 'down' && city + 1 < cities.length && cityUnlocked(state.progress, city + 1)) { city += 1; level = 0 }
    if (key === 'left' && level > 0) level -= 1
    if (key === 'right' && level + 1 < cityAt(city).levels.length && levelUnlocked(state.progress, city, level + 1)) level += 1
    if (key === 'return' || key === ' ') {
      surface.setState(startGame(state, city, level))
      return
    }
    surface.setState({ ...state, city, level })
    return
  }
  const game = state.game
  if (!game) return
  if (game.status !== 'playing') {
    if (key === 'return' || key === 'n') {
      const next = state.level + 1 < cityAt(state.city).levels.length
        ? { city: state.city, level: state.level + 1 }
        : { city: Math.min(state.city + 1, cities.length - 1), level: 0 }
      const target = game.status === 'won' ? next : { city: state.city, level: state.level }
      surface.setState(startGame(state, target.city, target.level))
    } else if (key === 'r') {
      surface.setState(startGame(state, state.city, state.level))
    } else if (key === 'm' || key === 'q') {
      surface.setState({ ...state, screen: 'menu' })
    }
    return
  }
  if (key === 'm' || key === 'q') return surface.setState({ ...state, screen: 'menu' })
  if (key === 'r') return surface.setState(startGame(state, state.city, state.level))
  if (key === 'h') {
    const hint = game.hint()
    if (hint.length === 4) {
      surface.setState({ ...state, cursor: { c: hint[0]!, r: hint[1]! }, picked: null, note: `여기를 ${arrow(hint)} 쪽으로 밀어 보세요.` })
    }
    return
  }
  if (key === 'return' || key === ' ') {
    surface.setState({ ...state, picked: state.picked ? null : state.cursor })
    return
  }
  const direction = DIRECTIONS[key]
  if (!direction) return
  const to = {
    c: Math.min(Math.max(state.cursor.c + direction[0], 0), game.columns - 1),
    r: Math.min(Math.max(state.cursor.r + direction[1], 0), game.activeRows - 1),
  }
  if (state.picked) {
    surface.setState(settle(trySwap(state, state.picked, to), surface))
  } else {
    surface.setState({ ...state, cursor: to })
  }
}

function arrow(hint: number[]): string {
  const [fromColumn = 0, fromRow = 0, toColumn = 0, toRow = 0] = hint
  if (toColumn > fromColumn) return '오른'
  if (toColumn < fromColumn) return '왼'
  return toRow > fromRow ? '아래' : '위'
}

function onPointer(event: ClientPointerEvent, state: State, surface: ClientSurface<State>) {
  if (event.type !== 'down' || state.screen !== 'game' || !state.game || state.game.status !== 'playing') return
  const cell = { c: Math.floor(event.x / CELL), r: event.y - HEADER_ROWS }
  if (cell.c < 0 || cell.c >= state.game.columns || cell.r < 0 || cell.r >= state.game.activeRows) return
  const picked = state.picked
  if (picked && Math.abs(picked.c - cell.c) + Math.abs(picked.r - cell.r) === 1) {
    surface.setState(settle(trySwap(state, picked, cell), surface))
  } else {
    surface.setState({ ...state, cursor: cell, picked: cell })
  }
}

function stars(count: number): string {
  return '★'.repeat(count) + '☆'.repeat(3 - count)
}

const Game: ClientModule<Props, State> = (props, surface) => {
  const { Box, Text } = surface.elements
  const incoming = props.progress ?? {}
  let state = surface.state
  if (!state) {
    const open = firstOpen(incoming)
    state = { screen: 'menu', city: open.city, level: open.level, cursor: { c: 3, r: 5 }, picked: null, game: null, note: '', progress: incoming, saved: false }
    surface.setState(state)
  }
  const current = state
  surface.onKey(event => onKey(event, surface.state ?? current, surface))
  surface.onPointer(event => onPointer(event, surface.state ?? current, surface))

  if (current.screen === 'menu') {
    const city = cityAt(current.city)
    const earned = city.levels.reduce((sum, id) => sum + (current.progress[id] ?? 0), 0)
    return (
      <Box flexDirection="column">
        <Text weight="bold" color={PINK}>포자 대청소</Text>
        <Text dimColor>위·아래로 도시, 왼쪽·오른쪽으로 레벨을 고르고 Enter로 시작해요.</Text>
        <Text> </Text>
        {cities.map((one, index) => {
          const open = cityUnlocked(current.progress, index)
          const mine = index === current.city
          const total = one.levels.reduce((sum, id) => sum + (current.progress[id] ?? 0), 0)
          return (
            <Text color={mine ? '#ffffff' : undefined} dimColor={!open} inverse={mine}>
              {` ${open ? ' ' : '🔒'} ${one.name} · ${one.landmark}  ★ ${total}/${one.levels.length * 3} `}
            </Text>
          )
        }).slice(Math.max(0, current.city - 6), Math.max(0, current.city - 6) + 13)}
        <Text> </Text>
        <Text weight="bold">{`${city.name} 레벨  ★ ${earned}/${city.levels.length * 3}`}</Text>
        <Text>
          {city.levels.map((id, index) => {
            const open = levelUnlocked(current.progress, current.city, index)
            const got = current.progress[id] ?? 0
            const mine = index === current.level
            const label = `${String(index + 1).padStart(2, ' ')}${got > 0 ? '★'.repeat(got) : open ? '   ' : ' 🔒'}`
            return (
              <Text inverse={mine} dimColor={!open} color={got > 0 ? '#ffd84d' : undefined}>
                {` ${label} `}
              </Text>
            )
          })}
        </Text>
      </Box>
    )
  }

  const game = current.game!
  const cells = game.cells()
  const rows = []
  for (let r = 0; r < game.activeRows; r++) {
    const parts = []
    for (let c = 0; c < game.columns; c++) {
      const { text, fg, bg } = look(cells[r * game.columns + c] ?? '.')
      const isCursor = current.cursor.c === c && current.cursor.r === r
      const isPicked = current.picked?.c === c && current.picked?.r === r
      parts.push(
        <Text color={isPicked ? '#16182a' : fg} backgroundColor={isPicked ? '#ffe14d' : bg} inverse={isCursor && !isPicked} weight="bold">
          {text}
        </Text>,
      )
    }
    rows.push(<Text>{parts}</Text>)
  }
  const city = cityAt(current.city)
  const collected = game.materialsTotal - game.materialsLeft
  const header = `${city.name} ${current.level + 1}단계   이동 ${game.moves}   ${game.score}점   물질 ${collected}/${game.materialsTotal}   ★${game.starScores[0] ?? 0} ★★${game.starScores[1] ?? 0}`
  let footer: string
  if (game.status === 'won') footer = `정화 완료! ${stars(game.stars())}  Enter 다음 레벨 · R 한 번 더 · M 메뉴`
  else if (game.status === 'lost') footer = `아쉬워요! 물질이 ${game.materialsLeft}개 남았어요.  Enter·R 다시 · M 메뉴`
  else footer = current.note
  return (
    <Box flexDirection="column">
      <Text weight="bold">{header}</Text>
      <Text dimColor>방향키 고르기 · Enter 잡기 · 잡고 방향키로 밀기 · H 힌트 · R 다시 · M 메뉴</Text>
      {rows}
      <Text color={game.status === 'won' ? '#ffd84d' : game.status === 'lost' ? PINK : undefined}>{footer}</Text>
    </Box>
  )
}

export default Game
