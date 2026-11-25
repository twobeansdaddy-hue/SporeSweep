// 공통 유틸: 저장소 루트 찾기, .env 로드, 설정 로드, 외부 CLI 실행
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';

export const EXIT_FALLBACK = 75; // 오케스트레이터에게 "대체 경로로 가라"는 신호

export function findRoot(start) {
  for (const base of [process.cwd(), start]) {
    let dir = base;
    while (true) {
      if (existsSync(join(dir, '.agentic', 'config.json'))) return dir;
      const up = dirname(dir);
      if (up === dir) break;
      dir = up;
    }
  }
  return process.cwd();
}

// 모든 프로젝트가 같이 쓰는 키 파일. 키트 폴더가 아니라 홈에 두므로 프로젝트에 복사·커밋되지 않는다.
export function globalEnvPath() {
  if (process.env.AGENTIC_ENV_FILE) return process.env.AGENTIC_ENV_FILE;
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), '.config');
  return join(base, 'agentic-kit', '.env');
}

// 키트를 설치한 프로젝트 목록. 공용 키 파일과 같은 폴더에 둔다 (예: ~/.config/agentic-kit/projects.json).
// { kitPath: 키트 폴더, projects: [{ path, version, updatedAt }] }
export function registryPath() {
  return join(dirname(globalEnvPath()), 'projects.json');
}

export function readRegistry() {
  try {
    const r = JSON.parse(readFileSync(registryPath(), 'utf8'));
    return { kitPath: r.kitPath ?? null, projects: Array.isArray(r.projects) ? r.projects : [] };
  } catch { return { kitPath: null, projects: [] }; }
}

export function registerProject(path, version, kitPath) {
  const reg = readRegistry();
  const entry = { path, version, updatedAt: new Date().toISOString() };
  const i = reg.projects.findIndex((p) => p.path === path);
  if (i >= 0) reg.projects[i] = entry; else reg.projects.push(entry);
  reg.kitPath = kitPath;
  mkdirSync(dirname(registryPath()), { recursive: true });
  writeFileSync(registryPath(), JSON.stringify(reg, null, 2) + '\n');
}

// "1.2.3" 비교: a가 크면 양수
export function compareVersions(a, b) {
  const pa = String(a ?? '0').split('.').map(Number), pb = String(b ?? '0').split('.').map(Number);
  for (let i = 0; i < 3; i++) if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) - (pb[i] || 0);
  return 0;
}

// 우선순위: 셸 환경변수 > 프로젝트 .env > 전역 키 파일
export function loadEnv(root) {
  loadEnvFile(join(root, '.env'));
  loadEnvFile(globalEnvPath());
}

// 키 파일(.env·공용 키 파일)에 값이 적힌 변수 이름. 셸에 같은 이름이 이미 있어서 대입하지 않았어도 기록한다
// (env-run으로 실행된 키트 스크립트처럼 키가 셸에 들어와 있는 경우에도 외부 에이전트에 넘기지 않으려고).
const loadedKeys = new Set();

export function loadEnvFile(file) {
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!m || line.trim().startsWith('#')) continue;
    let v = m[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    // 빈 값(KEY=)은 건너뛴다. .env.example을 그대로 복사한 프로젝트가 전역 키를 가리지 않게.
    if (v === '') continue;
    loadedKeys.add(m[1]);
    if (process.env[m[1]] === undefined) process.env[m[1]] = v;
  }
}

// 외부 에이전트(codex·agy) 자식 프로세스에 넘기지 않는 키: 키 파일에서 읽은 모든 변수와,
// 셸에 있더라도 키트·서비스 키로 알려진 이름(ElevenLabs 등). 프로젝트 스크립트에는 env-run.mjs로 넘긴다.
const KIT_SECRET_RE = /^(CLOUDFLARE_|TYPESAFE_|OPENROUTER_|DECIDE_LOCAL_|ELEVENLABS_)/;
// strict: 파일을 고칠 수 있는 외부 에이전트(codex-implement)용. 이름이 비밀값처럼 보이는 셸 변수도 뺀다
// (GITHUB_TOKEN, AWS_SECRET_ACCESS_KEY, NPM_TOKEN 등). Codex 자신의 인증에 쓰이는 OPENAI_·CODEX_ 변수는 남긴다.
const GENERIC_SECRET_RE = /(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|PRIVATE_?KEY|CREDENTIAL|SESSION_?KEY|ACCESS_?KEY)/i;
const AGENT_OWN_RE = /^(OPENAI_|CODEX_)/;
export function childEnv({ strict = false } = {}) {
  return Object.fromEntries(Object.entries(process.env).filter(([k]) =>
    !KIT_SECRET_RE.test(k) && !loadedKeys.has(k) && !(strict && GENERIC_SECRET_RE.test(k) && !AGENT_OWN_RE.test(k))));
}

export function loadConfig(root) {
  try { return JSON.parse(readFileSync(join(root, '.agentic', 'config.json'), 'utf8')); } catch { return {}; }
}

// 단계별 모델·추론 강도 (config.json의 stages.<단계>.<에이전트>). 빈 값은 각 도구의 전역 기본값을 쓴다.
// agy는 예전 설정 키 agy.model도 계속 받는다.
export function stageSettings(config, stage, agent) {
  const s = config?.stages?.[stage]?.[agent] ?? {};
  const text = (v, key) => {
    if (v === undefined || v === null || v === '') return '';
    if (typeof v !== 'string') throw new Error(`stages.${stage}.${agent}.${key}는 문자열이어야 합니다`);
    return v.trim();
  };
  const model = text(s.model, 'model') || (agent === 'agy' ? text(config?.agy?.model, 'model') : '');
  return { model, effort: text(s.effort, 'effort') };
}

// 강도는 codex 설정 문자열(-c) 안에 들어가므로 소문자 단어만 받는다. 이상하면 예외.
function checkEffort(effort) {
  if (effort && !/^[a-z]+$/.test(effort)) throw new Error(`추론 강도 값이 이상합니다: ${effort} (예: low, medium, high)`);
}

// 모델은 그대로 CLI 인자가 되므로, 옵션으로 읽힐 수 있는 값(-로 시작)과 제어 문자를 거부한다.
// agy 표시 이름처럼 공백·괄호가 있는 값은 허용한다.
function checkModel(model) {
  if (model && (model.startsWith('-') || /[\x00-\x1f\x7f]/.test(model))) throw new Error(`모델 값이 이상합니다: ${JSON.stringify(model)}`);
}

// codex exec 인자: -m <모델>, -c model_reasoning_effort="<강도>" (~/.codex/config.toml 값을 이번 실행만 덮어씀)
export function codexModelArgs({ model, effort }) {
  checkModel(model); checkEffort(effort);
  return [...(model ? ['-m', model] : []), ...(effort ? ['-c', `model_reasoning_effort="${effort}"`] : [])];
}

// agy 인자: --model <모델>, --effort <low|medium|high|xhigh|max>
// agy는 모델 ID에 강도가 붙어 있으면(…-low) 다른 --effort와 함께 쓰면 실행을 거부하고,
// 표시 이름("Gemini 3.8 Flash (Low)")에는 --effort를 받지 않는다. 호출 전에 같은 규칙으로 막는다.
const AGY_SUFFIX_RE = /-(low|medium|high|xhigh|max)$/;
// 모델 값에 강도가 이미 들어 있는가 (…-low 같은 ID, 또는 표시 이름)
export function agyPinned(model) {
  return !!model && (AGY_SUFFIX_RE.test(model) || /[\s()]/.test(model));
}
export function agyModelArgs({ model, effort }) {
  checkModel(model); checkEffort(effort);
  if (model && effort) {
    const m = model.match(AGY_SUFFIX_RE);
    if (m && m[1] !== effort) throw new Error(`agy 모델 ${model}에는 이미 강도 ${m[1]}가 들어 있어 effort ${effort}와 충돌합니다. 기본 이름(${model.replace(AGY_SUFFIX_RE, '')})을 쓰거나 effort를 비우세요`);
    if (/[\s()]/.test(model)) throw new Error(`표시 이름 "${model}"에는 effort를 쓸 수 없습니다. \`agy models\`의 ID를 쓰거나 effort를 비우세요`);
  }
  return [...(model ? ['--model', model] : []), ...(effort ? ['--effort', effort] : [])];
}

// 서브에이전트(Agent 도구)가 받는 모델 별칭. 빈 값·inherit은 메인 세션 모델. 실제 가용 목록은 세션의 Agent 도구 선택지가 기준이다.
export const SUBAGENT_MODELS = ['', 'inherit', 'sonnet', 'opus', 'haiku', 'fable'];

// ── 실행 시점 가용 모델 (models.mjs) ──
// 출력 형식이 바뀌거나 깨져도 예외를 내지 않고 빈 목록을 낸다. 목록이 비면 오케스트레이터는 설정 값(또는 전역 기본값)을 쓴다.
const EFFORT_ORDER = ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'];
const byEffort = (a, b) => (EFFORT_ORDER.indexOf(a) + 1 || 99) - (EFFORT_ORDER.indexOf(b) + 1 || 99);
// max보다 위이거나 키트가 모르는 강도 (예: 자동 위임이 붙은 ultra). 오케스트레이터는 사용자가 요청할 때만 쓴다.
const beyondMax = (efforts) => efforts.filter((e) => !EFFORT_ORDER.includes(e));
// CLI가 내준 설명은 그대로 오케스트레이터에게 가므로 제어 문자를 지우고 길이를 자른다.
const cleanText = (v, max = 200) => (typeof v === 'string' ? v.replace(/[\x00-\x1f\x7f]+/g, ' ').trim().slice(0, max) : '');
const SAFE_ID_RE = /^[\w.:][\w.:-]*$/; // -로 시작하면 CLI 옵션으로 읽히므로 뺀다 (checkModel과 같은 기준)

// `codex debug models` JSON: { models: [{ slug, display_name, description, default_reasoning_level,
//   supported_reasoning_levels: [{ effort, description }], visibility }] }.
// 숨김(visibility: hide) 모델도 hidden: true로 남긴다. 고를 목록에서는 빼지만, 사용자가 설정에 적은 모델인지 대조할 때는 쓴다.
export function parseCodexModels(text) {
  let j;
  try { j = JSON.parse(text); } catch { return []; }
  return (Array.isArray(j?.models) ? j.models : [])
    .filter((m) => m && typeof m.slug === 'string' && SAFE_ID_RE.test(m.slug))
    .map((m) => {
      const levels = (Array.isArray(m.supported_reasoning_levels) ? m.supported_reasoning_levels : [])
        .map((l) => (typeof l === 'string' ? { effort: l } : l)).filter((l) => typeof l?.effort === 'string' && /^[a-z]+$/.test(l.effort));
      const efforts = levels.map((l) => l.effort);
      const notes = Object.fromEntries(levels.filter((l) => cleanText(l.description)).map((l) => [l.effort, cleanText(l.description)]));
      return {
        id: m.slug,
        name: cleanText(m.display_name, 80) || m.slug,
        description: cleanText(m.description),
        defaultEffort: /^[a-z]+$/.test(m.default_reasoning_level ?? '') ? m.default_reasoning_level : '',
        efforts,
        beyondMax: beyondMax(efforts),
        ...(Object.keys(notes).length ? { effortNotes: notes } : {}),
        hidden: m.visibility === 'hide',
      };
    });
}

// `agy models` 출력: "<ID>\t<표시 이름>" 줄. 강도가 붙은 ID(gemini-3.8-flash-low)는 기본 이름으로 묶고 강도를 모은다.
// 기본 이름 + --effort로 부르면 된다 (agyModelArgs). 강도가 없는 ID는 efforts가 빈 배열이고 --effort 없이 부른다.
// 이름이 우연히 -max 등으로 끝나는 모델을 잘못 쪼개지 않도록, 표시 이름이 있으면 같은 "(강도)"로 끝날 때만 묶는다.
export function parseAgyModels(text) {
  const byBase = new Map();
  for (const raw of String(text ?? '').split(/\r?\n/)) {
    const line = raw.trim();
    const [id, ...rest] = (line.includes('\t') ? line.split('\t') : line.split(/\s+/)).map((s) => s.trim());
    // drift-check의 extractModels와 같은 기준에 영문자 하나 이상 ("12 models available" 같은 줄 제외)
    if (!id || !/^[a-z0-9][\w.-]*$/.test(id) || !/\d/.test(id) || !/[a-z]/.test(id)) continue;
    const display = cleanText(rest.join(' '), 80);
    let effort = id.match(AGY_SUFFIX_RE)?.[1];
    if (effort && display && !new RegExp(`\\(${effort}\\)$`, 'i').test(display)) effort = undefined;
    const base = effort ? id.replace(AGY_SUFFIX_RE, '') : id;
    const name = (effort ? display.replace(/\s*\([a-z]+\)$/i, '') : display).trim() || base;
    const cur = byBase.get(base) ?? { id: base, name, efforts: [] };
    if (effort && !cur.efforts.includes(effort)) cur.efforts.push(effort);
    byBase.set(base, cur);
  }
  return [...byBase.values()].map((m) => ({ ...m, efforts: m.efforts.sort(byEffort) }));
}

// ~/.codex/config.toml 최상위의 model·model_reasoning_effort·profile·model_provider (첫 [표] 앞까지만 본다).
// profile이나 model_provider가 있으면 실제 기본 모델이 다른 곳에서 정해지므로, 목록 대조 결과를 믿지 않는다 (models.mjs).
export function parseCodexDefaults(text) {
  const out = { model: '', effort: '', profile: '', provider: '' };
  const KEYS = { model: 'model', model_reasoning_effort: 'effort', profile: 'profile', model_provider: 'provider' };
  for (const line of String(text ?? '').split(/\r?\n/)) {
    if (/^\s*\[/.test(line)) break;
    const m = line.match(/^\s*(model|model_reasoning_effort|profile|model_provider)\s*=\s*["']([^"']*)["']/);
    if (m) out[KEYS[m[1]]] = m[2];
  }
  return out;
}

// 스크립트의 --effort 값 고르기. default는 "강도를 넘기지 않음"(모델 기본값, none은 실제 강도 값일 수 있어 쓰지 않는다), 비면 설정·등급에서 물려받은 값.
// --model로 모델을 바꿀 때는 물려받은 강도가 그 모델에 없을 수 있으므로 --effort도 같이 준다 (PIPELINE).
export function pickEffort(cli, inherited) {
  const v = String(cli ?? '').trim();
  if (v === 'default') return '';
  return v || inherited;
}

// ── 외부 CLI 업데이트 (cli-update.mjs) ──
// 버전 문자열에서 첫 x.y.z (예: "codex-cli 0.151.0" → "0.151.0"). 없으면 빈 값.
// 사전 공개 접미사(-alpha.3 등)는 버린다. 0.152.0-alpha.3은 0.152.0과 같은 버전으로 본다.
export function parseVersion(text) {
  return String(text ?? '').match(/\b(\d+\.\d+\.\d+)\b/)?.[1] ?? '';
}

// Node의 spawn(cmd)가 실제로 실행할 파일. Windows의 spawn은 PATH에서 .exe·.com만 찾고 .cmd(npm 전역 설치 실행 파일)는 실행하지 못한다.
// whereOut: `where cmd`(Windows) 또는 `which -a cmd` 출력. { path: 실행될 파일 또는 '', all: 찾은 경로 전부 }
export function resolveCommand(whereOut, platform = process.platform) {
  const all = String(whereOut ?? '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const path = platform === 'win32' ? (all.find((p) => /\.(exe|com)$/i.test(p)) ?? '') : (all[0] ?? '');
  return { path, all };
}

// CLI 업데이트 설정은 이 컴퓨터 전역 상태를 바꾸므로 저장소가 아니라 사용자 설정에 둔다 (공용 키 파일과 같은 폴더).
// 저장소 config에 두면 커밋 하나로 다른 사람의 오케스트레이터가 승인 없이 명령을 실행하게 만들 수 있다.
// { "auto": false, "commands": { "codex": [], "agy": [] } }
export function cliUpdateSettingsPath() {
  return join(dirname(globalEnvPath()), 'cli-update.json');
}
export function loadCliUpdateSettings() {
  try {
    const j = JSON.parse(readFileSync(cliUpdateSettingsPath(), 'utf8'));
    return { auto: j?.auto === true, commands: j?.commands && typeof j.commands === 'object' && !Array.isArray(j.commands) ? j.commands : {} };
  } catch { return { auto: false, commands: {} }; }
}

// 실행 파일이 npm 전역 설치본인가. npm의 bin 링크는 `npm root -g` 안(…/node_modules/@openai/codex/…)으로 이어지므로
// 실제 경로(realpath)가 그 안에 있을 때만 npm으로 본다. 접두 폴더(/usr/local 등)만 같은 Homebrew·apt·수동 설치본은 npm이 아니다.
// 대소문자는 Windows·macOS에서만 무시한다.
export function isNpmInstall(realPath, npmRoot, platform = process.platform) {
  if (!realPath || !npmRoot) return false;
  const norm = (p) => { const s = p.replace(/\\/g, '/').replace(/\/+$/, ''); return platform === 'win32' || platform === 'darwin' ? s.toLowerCase() : s; };
  return norm(realPath).startsWith(`${norm(npmRoot)}/`);
}

// 앱에 들어 있는 CLI (Codex 데스크톱 앱이 함께 설치한 codex). 앱이 스스로 업데이트하므로 키트가 건드리지 않는다.
export function isAppBundled(path) {
  return /[\\/]Programs[\\/]OpenAI[\\/]Codex[\\/]/i.test(path) || /\.app\/Contents\//.test(path);
}

// 업데이트 계획. info: { installed, latest, path, method('npm'|'self'|'app'|''), override(사용자 설정 명령 배열) }
// needsUpdate: true(설치본이 최신보다 낮음) / false / null(최신 버전을 알 수 없음)
// command: 실행할 argv. 사용자 설정 명령이 있으면 그것, 없으면 설치 방식별 기본값. 방법이 없으면 null과 reason.
// 'self'는 그 실행 파일의 도움말에 update 하위 명령이 있을 때만 정한다 (cli-update.mjs).
const NPM_PKG = { codex: '@openai/codex' };
const SAFE_ARG_RE = /^[\w@./:=+~-]+$/;
export function updatePlan(tool, { installed = '', latest = '', path = '', method = '', override = [] } = {}) {
  const needsUpdate = installed && latest ? compareVersions(installed, latest) < 0 : null;
  let command = null, reason = '';
  if (Array.isArray(override) && override.length) {
    if (override.every((a) => typeof a === 'string' && SAFE_ARG_RE.test(a))) command = override;
    else reason = `commands.${tool}의 인자에 허용하지 않는 문자가 있음 (영문·숫자·@./:=+~- 만, 공백·역슬래시 불가)`;
  } else if (method === 'app') reason = 'Codex 앱에 들어 있는 CLI라 앱에서 업데이트해야 함 (키트가 업데이트하지 않음)';
  else if (method === 'npm' && NPM_PKG[tool] && /^\d+\.\d+\.\d+$/.test(latest)) command = ['npm', 'install', '-g', `${NPM_PKG[tool]}@${latest}`];
  else if (method === 'self' && tool === 'codex' && path) command = [path, 'update'];
  else reason = tool === 'agy' ? 'agy에는 업데이트 명령이 없음 (수동 업데이트, 또는 사용자 설정 cli-update.json의 commands.agy에 명령 지정)' : '업데이트 방법을 정하지 못함';
  return { tool, installed, latest, path, method, needsUpdate, command, ...(reason ? { reason } : {}) };
}

// ── 요청 난이도 등급별 모델·추론 강도 (config.json의 autoSelect) ──
// autoSelect.tiers.<등급>.<단계>.<에이전트> = { model, effort }. 빈 값은 stages 값을 그대로 쓴다.
// 등급은 route 판정의 난이도 점수로 정하고(decide.mjs), 각 스크립트는 --tier <등급>으로 받는다.
export function autoSelectOn(config) {
  const a = config?.autoSelect;
  return !!a && a.enabled !== false && !!a.tiers && typeof a.tiers === 'object' && !Array.isArray(a.tiers);
}

export function tierNames(config) {
  return autoSelectOn(config) ? Object.keys(config.autoSelect.tiers) : [];
}

// 등급 값을 stages 위에 덮은 설정을 돌려준다 (원본은 바꾸지 않는다).
// 자동 선택이 꺼져 있거나 등급을 주지 않으면 원래 설정 그대로. 없는 등급 이름은 예외.
// fixed: { '<단계>.<에이전트>': 모델 } — 명령줄에서 직접 준 모델. 등급·stages의 모델 대신 이 모델을 기준으로 강도를 정한다.
export function withTier(config, tier, fixed = {}) {
  if (!tier || !autoSelectOn(config)) return config;
  const tiers = config.autoSelect.tiers;
  if (!Object.hasOwn(tiers, tier)) throw new Error(`알 수 없는 등급: ${tier} (가능: ${Object.keys(tiers).join(', ')})`);
  const isObj = (v) => !!v && typeof v === 'object' && !Array.isArray(v);
  const stages = structuredClone(isObj(config.stages) ? config.stages : {});
  for (const [stage, agents] of Object.entries(isObj(tiers[tier]) ? tiers[tier] : {})) {
    for (const [agent, over] of Object.entries(isObj(agents) ? agents : {})) {
      let o;
      try { o = stageSettings({ stages: { [stage]: { [agent]: over } } }, stage, agent); }
      catch (e) { throw new Error(`autoSelect.tiers.${tier}: ${e.message}`); }
      const base = stageSettings(config, stage, agent);
      if (fixed[`${stage}.${agent}`]) o.model = fixed[`${stage}.${agent}`];
      // agy 모델에 강도가 이미 들어 있으면(…-low, 표시 이름) 강도를 따로 얹을 수 없다. 그 모델의 강도를 그대로 둔다.
      // 등급이 그런 모델을 지정했으면 stages의 강도도 함께 비운다.
      const pinned = agent === 'agy' && agyPinned(o.model || base.model);
      if (!isObj(stages[stage])) stages[stage] = {};
      const cur = isObj(stages[stage][agent]) ? stages[stage][agent] : (stages[stage][agent] = {});
      if (o.model) cur.model = o.model;
      if (pinned && o.model) cur.effort = '';
      else if (o.effort && !pinned) cur.effort = o.effort;
    }
  }
  return { ...config, stages };
}

// 한 등급에서 실제로 쓰일 값 (council 제외: 파이프라인이 부르지 않는다).
export const TIER_TARGETS = [['review', 'codex'], ['implement', 'codex'], ['research', 'agy'], ['subagents', 'reviewer'], ['subagents', 'researcher']];
export function tierSelection(config, tier) {
  const cfg = withTier(config, tier);
  const out = {};
  for (const [stage, agent] of TIER_TARGETS) (out[stage] ??= {})[agent] = stageSettings(cfg, stage, agent);
  return out;
}

// 판정 정의의 tier 규칙 { from, levels: [{ below, tier }, …, { tier }] }과 요약된 답으로 등급을 고른다.
// 점수가 below보다 작은 첫 단계, 없으면 below가 없는 마지막 단계.
// 답이 없거나 점수가 숫자가 아니거나 0~max 범위를 벗어나면 null (오케스트레이터가 직접 고른다).
export function pickTier(rule, answers, max = Infinity) {
  const q = answers?.[rule?.from];
  const v = q?.value;
  if (!q || q.type !== 'score' || typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > max || !Array.isArray(rule.levels)) return null;
  const level = rule.levels.find((l) => typeof l.below !== 'number' || v < l.below);
  return level?.tier ? { tier: level.tier, uncertain: !!q.uncertain } : null;
}

export function hasCommand(cmd) {
  const r = spawnSync(process.platform === 'win32' ? 'where' : 'which', [cmd], { stdio: 'ignore' });
  return r.status === 0;
}

// 외부 CLI 실행. pty=true면 macOS/Linux의 `script`로 가짜 터미널을 붙인다 (agy 출력 누락 회피).
export function run(cmd, args, { cwd, timeoutMs, pty = false, input, env } = {}) {
  return new Promise((resolvePromise) => {
    let file = cmd, argv = args;
    if (pty && process.platform !== 'win32' && hasCommand('script')) {
      if (process.platform === 'darwin') { file = 'script'; argv = ['-q', '/dev/null', cmd, ...args]; }
      else { file = 'script'; argv = ['-qec', [cmd, ...args].map(shQuote).join(' '), '/dev/null']; }
    }
    const child = spawn(file, argv, { cwd, env, stdio: [input === undefined ? 'ignore' : 'pipe', 'pipe', 'pipe'] });
    let stdout = '', stderr = '', timedOut = false;
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    if (input !== undefined) { child.stdin.write(input); child.stdin.end(); }
    const timer = timeoutMs ? setTimeout(() => { timedOut = true; child.kill('SIGTERM'); setTimeout(() => child.kill('SIGKILL'), 5000); }, timeoutMs) : null;
    child.on('error', (e) => { if (timer) clearTimeout(timer); resolvePromise({ code: 127, stdout, stderr: stderr + String(e), timedOut }); });
    child.on('close', (code) => {
      if (timer) clearTimeout(timer);
      if (pty) stdout = stripTty(stdout);
      resolvePromise({ code: code ?? 1, stdout, stderr, timedOut });
    });
  });
}

function shQuote(s) { return `'${String(s).replace(/'/g, `'\\''`)}'`; }

// 가짜 터미널이 넣는 CR과 ANSI 제어 문자 제거
export function stripTty(s) {
  return s.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, '').replace(/\x1b\][^\x07]*\x07/g, '').replace(/\r/g, '').replace(/^\^D\x08\x08/, '');
}

export const QUOTA_RE = /usage limit|rate[ -]?limit|quota|429|too many requests|resource[_ ]exhausted|try again (at|in|later)/i;

// agy를 실행할 작업 폴더를 준비한다: <root>/.agentic/tmp/agy/.agents/hooks.json이 키 파일 가드(agy-guard.mjs)를 부른다.
// agy는 현재 폴더에서 프로젝트 루트까지 .agents/를 찾으므로, 이 폴더에서 연 agy에만 가드가 걸린다.
export function agyWorkspace(root) {
  const dir = join(root, '.agentic', 'tmp', 'agy');
  mkdirSync(join(dir, '.agents'), { recursive: true });
  const guard = join(dirname(fileURLToPath(import.meta.url)), 'agy-guard.mjs');
  const hooks = { 'agentic-kit-guard': { PreToolUse: [{ matcher: '*', hooks: [{ command: `${shQuote(process.execPath)} ${shQuote(guard)}`, timeout: 10 }] }] } };
  writeFileSync(join(dir, '.agents', 'hooks.json'), JSON.stringify(hooks, null, 2) + '\n');
  return dir;
}

// 0이 아닌 종료 코드의 이유. 출력에는 CLI가 되풀이한 프롬프트가 섞일 수 있으므로,
// CLI가 찍은 error 줄이 있으면 그 줄만 보고 분류한다. 없을 때만 끝 20줄 전체를 본다.
// 용량 부족 > 한도 초과 > error 줄 > 종료 코드 순.
const CAPACITY_RE = /at capacity|overloaded|temporarily unavailable|server is busy/i;
export function exitFailure(res) {
  const tail = `${res.stdout}\n${res.stderr}`.split(/\r?\n/).map((l) => l.trim()).filter(Boolean).slice(-20);
  const errors = tail.filter((l) => /^error\b/i.test(l));
  const text = (errors.length ? errors : tail).join('\n');
  if (CAPACITY_RE.test(text)) return '모델 용량 부족';
  if (QUOTA_RE.test(text)) return '사용 한도 초과';
  const line = errors[0];
  return line ? `종료 코드 ${res.code}: ${line.slice(0, 200)}` : `종료 코드 ${res.code}`;
}

// agy가 종료 코드 0으로 답 대신 내놓는 안내문을 찾는다. 안내문이면 이유, 아니면 null.
// - headless 권한 거부: CLI가 줄 맨 앞에 "jetski: no output produced"를 찍는다. 길이와 상관없이 실패로 본다.
// - 한도 초과: 형식이 정해져 있지 않아, 요청한 형식(## 제목)이 없는 짧은 출력에서 한도 문구가 있을 때만 본다.
//   정상 답변에 흔한 "429"·"rate limit"만으로는 판정하지 않는다.
const AGY_HEADLESS_RE = /^\s*jetski:\s*no output produced/im;
const AGY_QUOTA_RE = /usage limit|exhausted your quota|quota (exceeded|exhausted)|resource[_ ]exhausted|too many requests|try again (at|in|later)/i;
export function agyFailure(text) {
  if (!text) return null;
  if (AGY_HEADLESS_RE.test(text)) return 'headless 모드 권한 거부';
  if (text.length < 400 && !/^#{2,3} /m.test(text) && AGY_QUOTA_RE.test(text)) return '사용 한도 초과';
  return null;
}
