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

export function loadEnvFile(file) {
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!m || line.trim().startsWith('#')) continue;
    let v = m[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    // 빈 값(KEY=)은 건너뛴다. .env.example을 그대로 복사한 프로젝트가 전역 키를 가리지 않게.
    if (v !== '' && process.env[m[1]] === undefined) process.env[m[1]] = v;
  }
}

// 키트가 읽는 키. 외부 에이전트(codex·agy) 자식 프로세스에는 넘기지 않는다.
const KIT_SECRET_RE = /^(CLOUDFLARE_|TYPESAFE_|OPENROUTER_|DECIDE_LOCAL_)/;
export function childEnv() {
  return Object.fromEntries(Object.entries(process.env).filter(([k]) => !KIT_SECRET_RE.test(k)));
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
export function agyModelArgs({ model, effort }) {
  checkModel(model); checkEffort(effort);
  if (model && effort) {
    const m = model.match(AGY_SUFFIX_RE);
    if (m && m[1] !== effort) throw new Error(`agy 모델 ${model}에는 이미 강도 ${m[1]}가 들어 있어 effort ${effort}와 충돌합니다. 기본 이름(${model.replace(AGY_SUFFIX_RE, '')})을 쓰거나 effort를 비우세요`);
    if (/[\s()]/.test(model)) throw new Error(`표시 이름 "${model}"에는 effort를 쓸 수 없습니다. \`agy models\`의 ID를 쓰거나 effort를 비우세요`);
  }
  return [...(model ? ['--model', model] : []), ...(effort ? ['--effort', effort] : [])];
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
