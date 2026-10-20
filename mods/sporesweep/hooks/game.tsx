import type { ClientKeyEvent, ClientModule, ClientPointerEvent, ClientSurface, RenderElement } from 'claude-code'

import { SporeGame } from './engine.mjs'
import { cities, levels } from './levels.mjs'

// 포자 대청소 mods판의 화면. 창 안의 Client 영역에서 돈다(터미널과 데스크톱 앱).
//
// 보드는 활성 구간 8×10칸을 그린다. 칸은 블록마다 이모지와 바탕색이 다르고, 창이 넓으면 크게 그린다.
// 조작: 블록을 잡고 옆 칸으로 끌거나, 두 칸을 차례로 누른다. 키보드로는 방향키로 고르고 Enter로 잡은 뒤 방향키로 민다.
// 한동안 두지 않으면 둘 수 있는 곳이 깜박인다. 창이 넓으면 보드 옆에 블록 설명(범례)이 나온다.

type Progress = Record<string, number>
type Props = { progress?: Progress }
type Cell = { c: number; r: number }

type State = {
  screen: 'menu' | 'game'
  city: number
  level: number
  cursor: Cell
  picked: Cell | null
  /** 마우스 단추를 누른 채 시작한 칸. 옆 칸으로 끌면 바꾼다. */
  drag: Cell | null
  /** 키보드로 두는 중인지. 그럴 때만 커서를 그린다. */
  keyboard: boolean
  game: SporeGame | null
  note: string
  progress: Progress
  /** 이 판의 결과를 이미 저장했는지. */
  saved: boolean
  /** 마지막으로 손댄 때(ms). 한동안 가만히 있으면 힌트를 깜박인다. */
  touched: number
  blink: boolean
}

/** 보드 위에 쓰는 줄 수. 마우스 좌표를 칸으로 바꿀 때 쓴다. */
const HEADER_ROWS = 2
/** 보드 아래에 쓰는 줄 수. */
const FOOTER_ROWS = 2
/** 보드 쪽 줄(위 두 줄, 단추)이 줄바꿈되지 않을 폭. */
const BOARD_MIN = 52
/** 범례의 폭(글자 칸). */
const LEGEND = 34
/** 가만히 있으면 힌트를 깜박이기까지(ms). */
const IDLE = 6000

/** 칸 크기: 칸 사이 간격(w)과 줄 수(h). 칸의 색칠한 폭은 w가 4보다 크면 w-1(한 칸 띄움)이다. */
const SIZES = [
  { w: 7, h: 3 },
  { w: 5, h: 2 },
  { w: 4, h: 1 },
  { w: 3, h: 1 },
]
type Size = (typeof SIZES)[number]

// 일반 블록 여섯 종류: 바탕색, 이모지, 이름.
const KINDS: [string, string, string][] = [
  ['#d9554a', '🧱', '벽돌'],
  ['#9aa6b8', '🔩', '고철'],
  ['#4cc7e6', '💎', '유리'],
  ['#e9a93f', '🪵', '목재'],
  ['#6ccb5f', '🥤', '플라스틱'],
  ['#a87bd8', '🟤', '흙'],
]
const DARK = '#1c1f33'
const PINK = '#ff4fa3'
const PICKED = '#ffe14d'
const HINT = '#7fffd4'
const CURSOR = '#f4f4f8'

type Look = { text: string; fg: string; bg: string }

function kindAt(index: number): [string, string, string] {
  return KINDS[index] ?? [DARK, '?', '?']
}

/** 칸 코드(engine.cells)를 보이는 글자(폭 3 이하)와 색으로. */
function look(code: string): Look {
  const kind = Number(code.slice(1, 2))
  const [kindBg, emoji] = kindAt(kind)
  switch (code[0]) {
    case '.': return { text: '', fg: DARK, bg: DARK }
    case '?': return { text: '??', fg: '#d8c8ff', bg: '#4b3a73' }
    case 'H': return { text: '<=>', fg: '#7ff3ff', bg: '#24304f' }
    case 'V': return { text: '/|\\', fg: '#7ff3ff', bg: '#24304f' }
    case 'X': return { text: '💣', fg: '#ffb347', bg: '#24304f' }
    case 'C': return { text: '🌀', fg: '#ffffff', bg: '#5b3fa8' }
    case 'D': return { text: '🚁', fg: '#7ff3ff', bg: '#1f6f8b' }
    case 'M': return { text: '🦠', fg: '#3a0a22', bg: PINK }
    case 'W': return { text: '##', fg: '#6b7088', bg: '#2a2d40' }
    case 'K': return { text: kind >= 2 ? '🔲2' : '🔲', fg: '#ffffff', bg: '#7d8191' }
    case 'G': return { text: `#${emoji}`, fg: '#1c1f33', bg: kindBg }
    case 'S': return { text: '🫧', fg: '#f3d36b', bg: '#5a4524' }
    case 'O': return { text: `@${emoji}`, fg: '#ffd1e8', bg: '#7a1f4a' }
    case 'R': return { text: '🪨', fg: '#e8e2d6', bg: '#6d6458' }
    case 'N': return { text: '🍄', fg: '#ffd1e8', bg: '#7a1f4a' }
    case 'T': return { text: `⏰${code.split(':')[1] ?? ''}`, fg: '#16182a', bg: kindBg }
    case 'E': return { text: '🥚', fg: '#ffc94d', bg: '#23305e' }
    case 'L': return { text: '🔒', fg: '#ffd84d', bg: kindBg }
    case 'U': return { text: '🌑', fg: '#ff9a4d', bg: '#3b2a24' }
    case 'F': return { text: '🏭', fg: '#cfd8ff', bg: '#3a4566' }
    case 'I': return { text: '🧊', fg: '#1c3a52', bg: '#bfe9ff' }
    default: {
      const [bg, mark] = kindAt(Number(code))
      return { text: mark, fg: '#16182a', bg }
    }
  }
}

/** 장애물의 설명. 이 판에 있는 것만 범례에 나온다. */
const EXPLAIN: Record<string, string> = {
  W: '벽: 부서지지 않아요',
  K: '콘크리트: 옆에서 맞추면 깨져요',
  G: '철망: 함께 맞추면 풀려요',
  S: '슬러지: 못 지우면 번져요',
  O: '고치: 옆에서 같은 블록을 맞춰요',
  R: '잔해: 떨어져요. 옆에서 깨요',
  N: '둥지: 슬러지를 뿜어요',
  T: '시한 포자: 0이 되기 전에 지워요',
  E: '알: 특수 효과로만 깨져요',
  L: '쇠사슬: 두 번 맞춰야 풀려요',
  U: '운석: 특수 효과로만 깨져요',
  F: '굴뚝: 안개를 뿜어요',
  I: '얼음: 옆에서 맞추면 녹아요',
  '?': '안개: 옆에서 맞추면 걷혀요',
}

/** 글자의 화면 폭. 이모지와 한글은 두 칸이다. */
function width(text: string): number {
  let w = 0
  for (const ch of text) w += (ch.codePointAt(0) ?? 0) > 0x7f ? 2 : 1
  return w
}

function center(text: string, room: number): string {
  const free = Math.max(room - width(text), 0)
  const left = Math.floor(free / 2)
  return ' '.repeat(left) + text + ' '.repeat(free - left)
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

/** 이어서 할 곳: 아직 깨지 않은 첫 레벨. 다 깼으면 마지막 레벨이다. */
function firstOpen(progress: Progress): { city: number; level: number } {
  for (let c = 0; c < cities.length; c++) {
    for (let l = 0; l < cityAt(c).levels.length; l++) {
      if ((progress[levelAt(c, l)] ?? 0) === 0) return { city: c, level: l }
    }
  }
  return { city: cities.length - 1, level: cityAt(cities.length - 1).levels.length - 1 }
}

/** 열린 도시 수. */
function openCities(progress: Progress): number {
  let count = 1
  while (count < cities.length && cityUnlocked(progress, count)) count += 1
  return count
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
    drag: null,
    cursor: { c: 3, r: 5 },
    saved: false,
    touched: Date.now(),
    blink: false,
    note: game.tutorial ?? '블록을 잡고 옆으로 끌어 같은 블록 셋을 한 줄로 맞춰요.',
  }
}

function nextLevel(state: State): { city: number; level: number } {
  if (state.level + 1 < cityAt(state.city).levels.length) return { city: state.city, level: state.level + 1 }
  return { city: Math.min(state.city + 1, cities.length - 1), level: 0 }
}

const DIRECTIONS: Record<string, [number, number]> = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }

const REASONS: Record<string, string> = {
  nomatch: '그렇게 바꾸면 맞춰지는 게 없어요. 같은 블록 셋이 한 줄이 되게 해 봐요.',
  immovable: '그 칸은 움직일 수 없어요.',
  emptycell: '빈칸이에요.',
  outofbounds: '보드 밖이에요.',
  notadjacent: '바로 옆 칸끼리만 바꿀 수 있어요.',
  gameover: '판이 끝났어요.',
}

function adjacent(a: Cell, b: Cell): boolean {
  return Math.abs(a.c - b.c) + Math.abs(a.r - b.r) === 1
}

function trySwap(state: State, from: Cell, to: Cell): State {
  const game = state.game
  if (!game) return state
  const result = game.swap(from.c, from.r, to.c, to.r)
  const touched = Date.now()
  if (result !== 'ok') return { ...state, picked: null, drag: null, touched, blink: false, note: REASONS[result] ?? result }
  return { ...state, picked: null, drag: null, cursor: to, touched, blink: false, note: game.last || '좋아요!' }
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

function showHint(state: State): State {
  const hint = state.game?.hint() ?? []
  if (hint.length !== 4) return state
  return { ...state, picked: null, touched: 0, blink: true, note: '반짝이는 두 칸을 서로 바꿔 보세요.' }
}

// 마지막으로 그린 화면의 배치. 누른 곳을 칸이나 단추로 바꿀 때 쓴다.
type Hit = { y: number; x0: number; x1: number; act: (state: State) => State }
let hits: Hit[] = []
let size: Size = SIZES[1]!

function onKey(event: ClientKeyEvent, state: State, surface: ClientSurface<State>) {
  const key = event.key.toLowerCase()
  if (state.screen === 'menu') {
    let { city, level } = state
    const open = openCities(state.progress)
    if (key === 'up' && city > 0) { city -= 1; level = 0 }
    if (key === 'down' && city + 1 < open) { city += 1; level = 0 }
    if (key === 'left' && level > 0) level -= 1
    if (key === 'right' && level + 1 < cityAt(city).levels.length && levelUnlocked(state.progress, city, level + 1)) level += 1
    if (key === 'return' || key === ' ') return surface.setState(startGame(state, city, level))
    if (key === 'c') {
      const resume = firstOpen(state.progress)
      return surface.setState(startGame(state, resume.city, resume.level))
    }
    return surface.setState({ ...state, city, level })
  }
  const game = state.game
  if (!game) return
  if (game.status !== 'playing') {
    if (key === 'return' || key === 'n') {
      const target = game.status === 'won' ? nextLevel(state) : { city: state.city, level: state.level }
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
  if (key === 'h') return surface.setState(showHint(state))
  if (key === 'return' || key === ' ') {
    surface.setState({ ...state, keyboard: true, touched: Date.now(), blink: false, picked: state.picked ? null : state.cursor })
    return
  }
  const direction = DIRECTIONS[key]
  if (!direction) return
  const to = {
    c: Math.min(Math.max(state.cursor.c + direction[0], 0), game.columns - 1),
    r: Math.min(Math.max(state.cursor.r + direction[1], 0), game.activeRows - 1),
  }
  if (state.picked) {
    surface.setState(settle(trySwap({ ...state, keyboard: true }, state.picked, to), surface))
  } else {
    surface.setState({ ...state, keyboard: true, cursor: to, touched: Date.now(), blink: false })
  }
}

function onPointer(event: ClientPointerEvent, state: State, surface: ClientSurface<State>) {
  if (event.type === 'down') {
    const hit = hits.find(one => one.y === event.y && event.x >= one.x0 && event.x < one.x1)
    if (hit) return surface.setState(settle(hit.act(state), surface))
  }
  const game = state.game
  if (state.screen !== 'game' || !game || game.status !== 'playing') return
  if (event.type === 'up') {
    if (state.drag) surface.setState({ ...state, drag: null })
    return
  }
  const cell = { c: Math.floor(event.x / size.w), r: Math.floor((event.y - HEADER_ROWS) / size.h) }
  const inside = event.y >= HEADER_ROWS && cell.c >= 0 && cell.c < game.columns && cell.r >= 0 && cell.r < game.activeRows
  if (event.type === 'down') {
    if (!inside) return surface.setState({ ...state, picked: null, drag: null })
    const picked = state.picked
    if (picked && adjacent(picked, cell)) return surface.setState(settle(trySwap(state, picked, cell), surface))
    if (picked && picked.c === cell.c && picked.r === cell.r) return surface.setState({ ...state, picked: null, drag: null })
    return surface.setState({ ...state, keyboard: false, cursor: cell, picked: cell, drag: cell, touched: Date.now(), blink: false })
  }
  // 누른 채 옆 칸으로 끌면 바꾼다.
  if (event.type === 'move' && event.button === 'left' && state.drag && inside && adjacent(state.drag, cell)) {
    surface.setState(settle(trySwap(state, state.drag, cell), surface))
  }
}

function stars(count: number): string {
  return '⭐'.repeat(count) + '·'.repeat(3 - count)
}

/** 창 크기에 맞는 칸 크기와, 옆에 범례를 둘 수 있는지. */
function fit(surface: ClientSurface<State>, game: SporeGame): { size: Size; legend: boolean } {
  const columns = surface.columns || 80
  const rows = surface.rows || 30
  const fits = (one: Size, extra: number) =>
    Math.max(game.columns * one.w, BOARD_MIN) + extra <= columns && game.activeRows * one.h + HEADER_ROWS + FOOTER_ROWS <= rows
  for (const one of SIZES) if (fits(one, 2 + LEGEND)) return { size: one, legend: true }
  for (const one of SIZES) if (fits(one, 0)) return { size: one, legend: false }
  return { size: SIZES[SIZES.length - 1]!, legend: false }
}

const Game: ClientModule<Props, State> = (props, surface) => {
  const { Box, Text } = surface.elements
  const incoming = props.progress ?? {}
  let state = surface.state
  if (!state) {
    const open = firstOpen(incoming)
    state = {
      screen: 'menu', city: open.city, level: open.level, cursor: { c: 3, r: 5 }, picked: null, drag: null,
      keyboard: false, game: null, note: '', progress: incoming, saved: false, touched: Date.now(), blink: false,
    }
    surface.setState(state)
    // 한동안 두지 않으면 둘 수 있는 곳을 깜박인다.
    surface.every(500, () => {
      const now = surface.state
      if (!now || now.screen !== 'game' || now.game?.status !== 'playing') return
      const idle = Date.now() - now.touched > IDLE
      if (idle || now.blink) surface.setState({ ...now, blink: idle ? !now.blink : false })
    })
  }
  const current = state
  surface.onKey(event => onKey(event, surface.state ?? current, surface))
  surface.onPointer(event => onPointer(event, surface.state ?? current, surface))
  hits = []

  /** 한 줄짜리 단추들. 누르면 act가 돈다. */
  function buttons(y: number, items: { label: string; act: (s: State) => State; color?: string }[]): RenderElement {
    let x = 0
    const parts: RenderElement[] = []
    for (const item of items) {
      const text = ` ${item.label} `
      hits.push({ y, x0: x, x1: x + width(text), act: item.act })
      x += width(text) + 2
      parts.push(<Text inverse weight="bold" color={item.color}>{text}</Text>, <Text>{'  '}</Text>)
    }
    return <Text wrap="truncate-end">{parts}</Text>
  }

  if (current.screen === 'menu') {
    const lines: RenderElement[] = []
    const progress = current.progress
    const resume = firstOpen(progress)
    lines.push(<Text weight="bold" color={PINK}>🦠 포자 대청소</Text>)
    lines.push(<Text wrap="truncate-end" dimColor>외계 포자를 보드 맨 아래 격리 컨테이너까지 내려 도시를 정화해요.</Text>)
    lines.push(<Text> </Text>)
    lines.push(buttons(lines.length, [{
      label: `🎮 이어하기: ${cityAt(resume.city).name} ${resume.level + 1}단계`,
      color: '#ffd84d',
      act: s => startGame(s, resume.city, resume.level),
    }]))
    lines.push(<Text wrap="truncate-end" dimColor>  누르거나 C를 눌러요. 다른 판은 아래에서 골라요.</Text>)
    lines.push(<Text> </Text>)
    lines.push(<Text weight="bold">도시</Text>)
    const open = openCities(progress)
    for (let index = 0; index < open; index++) {
      const one = cityAt(index)
      const total = one.levels.reduce((sum, id) => sum + (progress[id] ?? 0), 0)
      const mine = index === current.city
      const text = `${mine ? '👉' : '  '} ${one.name} · ${one.landmark}   ⭐ ${total}/${one.levels.length * 3}`
      hits.push({ y: lines.length, x0: 0, x1: width(text) + 2, act: s => ({ ...s, city: index, level: 0 }) })
      lines.push(<Text wrap="truncate-end" weight={mine ? 'bold' : undefined} color={mine ? '#ffffff' : undefined}>{text}</Text>)
    }
    if (open < cities.length) {
      lines.push(<Text wrap="truncate-end" dimColor>{`🔒 다음 도시 ${cityAt(open).name}: ${cityAt(open - 1).name}의 레벨을 모두 깨면 열려요`}</Text>)
    }
    lines.push(<Text> </Text>)
    const city = cityAt(current.city)
    lines.push(<Text wrap="truncate-end" weight="bold">{`${city.name} 레벨  (누르면 시작해요)`}</Text>)
    const perLine = 4
    for (let start = 0; start < city.levels.length; start += perLine) {
      const parts: RenderElement[] = []
      let x = 0
      for (let index = start; index < Math.min(start + perLine, city.levels.length); index++) {
        const id = city.levels[index]!
        const unlocked = levelUnlocked(progress, current.city, index)
        const got = progress[id] ?? 0
        const mine = index === current.level
        const mark = got > 0 ? '⭐'.repeat(got) : unlocked ? '' : '🔒'
        const text = ` ${String(index + 1).padStart(2, ' ')} ${mark}${' '.repeat(6 - width(mark))} `
        if (unlocked) {
          const level = index
          const cityIndex = current.city
          hits.push({ y: lines.length, x0: x, x1: x + width(text), act: s => startGame(s, cityIndex, level) })
        }
        x += width(text) + 1
        parts.push(
          <Text inverse={mine} dimColor={!unlocked} color={got > 0 ? '#ffd84d' : undefined}>{text}</Text>,
          <Text> </Text>,
        )
      }
      lines.push(<Text wrap="truncate-end">{parts}</Text>)
    }
    lines.push(<Text> </Text>)
    lines.push(<Text dimColor>키보드: ↑↓ 도시 · ←→ 레벨 · Enter 시작</Text>)
    return <Box flexDirection="column">{lines}</Box>
  }

  const game = current.game!
  const layout = fit(surface, game)
  size = layout.size
  const tile = size.w > 4 ? size.w - 1 : size.w
  const middle = Math.floor((size.h - 1) / 2)
  const cells = game.cells()
  const marks = game.marks()
  const hint = current.blink ? game.hint() : []
  const isHint = (c: number, r: number) =>
    hint.length === 4 && ((hint[0] === c && hint[1] === r) || (hint[2] === c && hint[3] === r))

  const boardLines: RenderElement[] = []
  for (let r = 0; r < game.activeRows; r++) {
    for (let line = 0; line < size.h; line++) {
      const parts: RenderElement[] = []
      for (let c = 0; c < game.columns; c++) {
        const index = r * game.columns + c
        const { text, fg, bg } = look(cells[index] ?? '.')
        const mark = marks[index] ?? ''
        const isPicked = current.picked?.c === c && current.picked?.r === r
        const isCursor = current.keyboard && current.cursor.c === c && current.cursor.r === r
        const back = isPicked ? PICKED : isHint(c, r) ? HINT : isCursor ? CURSOR : bg
        // 끈끈이는 ~, 보호막은 +로 칸의 위아래 줄(한 줄짜리 칸이면 왼쪽 끝)을 채운다.
        const fill = mark === 'sticky' ? '~' : mark === 'shield' ? '+' : ' '
        let body: string
        let color = fg
        if (line === middle) {
          body = size.h === 1 && fill !== ' ' ? fill + center(text, tile - 1) : center(text, tile)
        } else {
          body = fill.repeat(tile)
          color = mark === 'shield' ? '#7ff3ff' : '#f3d36b'
        }
        parts.push(<Text color={color} backgroundColor={back} weight="bold">{body}</Text>)
        if (tile < size.w) parts.push(<Text backgroundColor={DARK}>{' '.repeat(size.w - tile)}</Text>)
      }
      boardLines.push(<Text>{parts}</Text>)
    }
  }

  const city = cityAt(current.city)
  const collected = game.materialsTotal - game.materialsLeft
  const earned = game.starScores.filter(score => game.score >= score).length
  const header = (
    <Text wrap="truncate-end">
      <Text weight="bold">{`${city.name} ${current.level + 1}단계  `}</Text>
      <Text color={PINK} weight="bold">{`🦠 ${collected}/${game.materialsTotal} 수거  `}</Text>
      <Text weight="bold">{`남은 이동 ${game.moves}  `}</Text>
      <Text color="#ffd84d">{`${game.score}점 ${stars(earned)}`}</Text>
    </Text>
  )
  const goal = <Text dimColor wrap="truncate-end">목표: 분홍 🦠 물질을 맨 아래까지 내려 모두 수거해요.</Text>

  const boardBottom = HEADER_ROWS + game.activeRows * size.h
  let footer: RenderElement
  let controls: RenderElement
  if (game.status === 'won') {
    footer = <Text color="#ffd84d" weight="bold">{`🎉 정화 완료! ${stars(game.stars())}  ${game.score}점`}</Text>
    controls = buttons(boardBottom, [
      { label: '다음 (Enter)', color: '#ffd84d', act: s => { const n = nextLevel(s); return startGame(s, n.city, n.level) } },
      { label: '한 번 더 (R)', act: s => startGame(s, s.city, s.level) },
      { label: '메뉴 (M)', act: s => ({ ...s, screen: 'menu' }) },
    ])
  } else if (game.status === 'lost') {
    footer = <Text color={PINK} weight="bold">{`아쉬워요! 물질이 ${game.materialsLeft}개 남았어요.`}</Text>
    controls = buttons(boardBottom, [
      { label: '다시 도전 (Enter)', color: '#ffd84d', act: s => startGame(s, s.city, s.level) },
      { label: '메뉴 (M)', act: s => ({ ...s, screen: 'menu' }) },
    ])
  } else {
    footer = <Text>{current.note}</Text>
    controls = buttons(boardBottom, [
      { label: '💡 힌트 (H)', act: showHint },
      { label: '다시 (R)', act: s => startGame(s, s.city, s.level) },
      { label: '메뉴 (M)', act: s => ({ ...s, screen: 'menu' }) },
    ])
  }

  const board = (
    <Box flexDirection="column" width={layout.legend ? Math.max(game.columns * size.w, BOARD_MIN) : undefined}>
      {header}
      {goal}
      {boardLines}
      {controls}
      {footer}
    </Box>
  )
  if (!layout.legend) return board
  return (
    <Box flexDirection="row">
      {board}
      <Box flexDirection="column" marginLeft={2} width={LEGEND}>
        {legend(cells, marks, game.starScores, Text)}
      </Box>
    </Box>
  )
}

/** 보드 옆의 설명. 조작, 블록 여섯 가지, 특수 블록 만드는 법, 이 판에 있는 장애물, 별 기준. */
function legend(cells: string[], marks: string[], starScores: number[], Text: ClientSurface<State>['elements']['Text']): RenderElement[] {
  const out: RenderElement[] = []
  out.push(<Text weight="bold">조작</Text>)
  out.push(<Text dimColor>블록을 잡고 옆으로 끌어요.</Text>)
  out.push(<Text dimColor>두 칸을 차례로 눌러도 돼요.</Text>)
  out.push(<Text> </Text>)
  out.push(<Text weight="bold">블록: 같은 것 셋을 한 줄로</Text>)
  for (let i = 0; i < KINDS.length; i += 2) {
    const [, a, an] = kindAt(i)
    const [, b, bn] = kindAt(i + 1)
    out.push(<Text>{`${a} ${an}${' '.repeat(Math.max(10 - width(an), 1))}${b} ${bn}`}</Text>)
  }
  out.push(<Text> </Text>)
  out.push(<Text weight="bold">특수 블록 만들기</Text>)
  out.push(<Text>🚁 드론    2×2 네모로</Text>)
  out.push(<Text>{'<=> 빔    4개를 한 줄로'}</Text>)
  out.push(<Text>💣 폭탄    L·T자로</Text>)
  out.push(<Text>🌀 코어    5개를 한 줄로</Text>)
  out.push(<Text dimColor>특수 블록끼리 바꾸면 더 세져요.</Text>)
  const seen = new Set(cells.map(code => code[0] ?? '.'))
  const here = Object.keys(EXPLAIN).filter(code => seen.has(code))
  const sticky = marks.includes('sticky')
  const shield = marks.includes('shield')
  if (here.length > 0 || sticky || shield) {
    out.push(<Text> </Text>)
    out.push(<Text weight="bold">이 판의 장애물</Text>)
    for (const code of here) {
      const { text } = look(cells.find(one => one[0] === code) ?? code)
      out.push(<Text>{`${text}${' '.repeat(Math.max(4 - width(text), 1))}${EXPLAIN[code]}`}</Text>)
    }
    if (sticky) out.push(<Text>{'~   끈끈이: 그 위 블록은 못 밀어요'}</Text>)
    if (shield) out.push(<Text>{'+   보호막: 특수 효과가 안 닿아요'}</Text>)
  }
  out.push(<Text> </Text>)
  out.push(<Text weight="bold">별 기준</Text>)
  out.push(<Text color="#ffd84d">{starScores.map((score, i) => `${'⭐'.repeat(i + 1)} ${score}`).join('  ')}</Text>)
  return out
}

export default Game
