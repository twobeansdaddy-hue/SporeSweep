#!/usr/bin/env node
// Antigravity PreToolUse 훅: 키 파일(.env, .env.*, 공용 키 파일)을 가리키는 도구 호출을 막는다.
// agy print 모드는 도구 호출을 자동 승인하므로, 금지 목록(명령)만으로는 파일 읽기를 막을 수 없다.
// 키트 스크립트(agy-research, council)만 이 훅을 쓴다: agy를 .agentic/tmp/agy/에서 실행하고 그 안의 .agents/hooks.json이 이 파일을 부른다.
// 사용자가 프로젝트 루트에서 직접 여는 agy에는 적용되지 않는다 (agy는 현재 폴더에서 위로만 .agents/를 찾음).
// 입력(stdin): { toolCall: { name, args } ... }  출력(stdout): {"decision":"deny"|"allow"|"ask"}
// - 키 파일을 가리키면 deny.
// - 읽기 전용 도구는 allow. allow는 agy 금지 목록(command(rm) 등)을 덮어쓰지 않는다 (실측).
// - run_command는 모든 구간이 읽기 전용 명령 목록에 맞을 때만 allow, 아니면 deny (셸 확장으로 키 파일을 우회해 읽는 것을 막음).
// - 그 밖의 도구(쓰기 등)는 ask = agy 기본 판단. headless에서는 물어볼 수 없어 거부되므로 가드가 없을 때와 같다.
// agy는 decision이 없으면({}) 거부로 처리한다 (실측).
import { readFileSync, realpathSync, existsSync } from 'node:fs';
import { basename, dirname, resolve, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { globalEnvPath } from './lib.mjs';

// 문자열 안에서 .env 파일을 가리키는 토큰 (.env, .env.local, 경로/.env). .env.example·.env.sample은 허용.
const ENV_TOKEN_RE = /(?:^|[\s'"`=:(\/])\.env(?:\.[\w-]+)*(?=$|[\s'"`;|&)<>\/])/g;
const ALLOWED_ENV = new Set(['.env.example', '.env.sample', '.env.template']);
const READ_ONLY_TOOLS = new Set(['read_file', 'view_file', 'view_file_outline', 'list_dir', 'grep_search', 'find_by_name', 'codebase_search', 'search_web', 'read_url_content']);
// run_command의 각 구간(| 로 나눈 조각)이 이 중 하나에 맞아야 한다. 파일을 쓰거나 다른 프로그램을 부를 수 있는 옵션은 뺐다.
const READ_ONLY_COMMANDS = [
  /^git (log|show|diff|status|blame|ls-files|rev-parse)\b(?!.*\s--(output|ext-diff|textconv|exec))/,
  /^(ls|pwd|wc|head|tail|cat|file|stat)\b/,
  /^sed -n \d+(,\d+)?p(\s|$)/,                                  // sed의 w·e 명령은 파일을 쓰거나 명령을 실행하므로 줄 범위 출력만
  /^grep\b(?!.*\s-[a-zA-Z]*[rR])(?!.*--recursive)/,
  /^find\b(?!.*\s-(exec|execdir|delete|ok|okdir|fprint|fprint0|fprintf|fls))/,
  /^(node|npm|codex|agy|claude) (-v|--version)$/,
];
// 셸 구문(확장·치환·리다이렉트·따옴표·이스케이프·백그라운드·순차 실행): 문자열 검사를 우회할 수 있으므로 있으면 막는다.
// 구간 구분자는 파이프(|)만 허용한다 (||는 막음).
const SHELL_SYNTAX_RE = /[*?[\]{}$`~<>\\'"&;!#\n\r]|\|\|/;

export function commandReason(line) {
  if (SHELL_SYNTAX_RE.test(line)) return '셸 확장·따옴표·리다이렉트·순차 실행 문자가 있는 명령';
  for (const seg of line.split('|').map((x) => x.trim()).filter(Boolean)) {
    if (!READ_ONLY_COMMANDS.some((re) => re.test(seg))) return `읽기 전용 목록에 없는 명령 "${seg.split(/\s+/)[0]}"`;
  }
  return null;
}

function realish(p) {
  try { return realpathSync(p); } catch { return p; }
}

// 이 값이 키 파일을 가리키면 그 이유, 아니면 null.
export function keyFileReason(value, { cwd = process.cwd(), globalEnv = globalEnvPath() } = {}) {
  if (typeof value !== 'string' || !value) return null;
  const globalReal = realish(globalEnv);
  const globalDir = dirname(globalReal);
  // 경로처럼 생긴 값(공백 없음): 실제 경로(링크 해석)로 공용 키 폴더·.env 이름을 본다.
  // "alias.txt"처럼 슬래시가 없어도 그 이름의 파일이 있으면 링크를 따라간다.
  const candidate = isAbsolute(value) ? value : resolve(cwd, value);
  if (!/\s/.test(value) && (isAbsolute(value) || value.includes('/') || value.startsWith('.') || existsSync(candidate))) {
    const real = realish(candidate);
    const name = basename(real);
    if (real === globalReal || real.startsWith(globalDir + '/')) return `공용 키 파일 ${globalEnv}`;
    if (/^\.env(\..+)?$/.test(name) && !ALLOWED_ENV.has(name)) return `키 파일 ${name}`;
  }
  // 명령줄·검색어 같은 자유 문자열: .env 토큰이나 공용 키 경로가 들어 있으면 막는다.
  if (value.includes(globalEnv) || value.includes(globalDir)) return '명령·검색어에 공용 키 파일 경로';
  for (const m of value.matchAll(ENV_TOKEN_RE)) {
    const token = m[0].replace(/^[\s'"`=:(\/]/, '');
    if (!ALLOWED_ENV.has(token)) return `명령·검색어에 키 파일 이름 ${token}`;
  }
  return null;
}

export function guardDecision(input, opts = {}) {
  const call = input?.toolCall ?? {};
  // 상대 경로는 agy 작업 폴더와 --add-dir로 붙인 폴더 모두를 기준으로 해석해 본다.
  const bases = [...(input?.workspacePaths ?? []), opts.cwd ?? process.cwd()];
  const strings = [];
  (function collect(v) {
    if (typeof v === 'string') strings.push(v);
    else if (Array.isArray(v)) v.forEach(collect);
    else if (v && typeof v === 'object') Object.values(v).forEach(collect);
  })(call.args);
  for (const s of strings) for (const cwd of bases) {
    const reason = keyFileReason(s, { ...opts, cwd });
    if (reason) return { decision: 'deny', reason: `agentic-kit: 키 파일 접근 차단 (${reason}). 키 값이 필요하면 사용자에게 물어보세요.` };
  }
  if (call.name === 'run_command') {
    const line = call.args?.CommandLine ?? strings.join(' ');
    const reason = commandReason(String(line).trim());
    return reason ? { decision: 'deny', reason: `agentic-kit: 키트의 agy 실행에서는 읽기 전용 명령만 씁니다 (${reason}). 파일 읽기 도구를 쓰세요.` } : { decision: 'allow' };
  }
  if (READ_ONLY_TOOLS.has(call.name)) return { decision: 'allow' };
  return { decision: 'ask' };
}

if (process.argv[1] && realish(process.argv[1]) === realish(fileURLToPath(import.meta.url))) {
  let input = {};
  try { input = JSON.parse(readFileSync(0, 'utf8') || '{}'); } catch { input = { toolCall: { args: { unparsed: '.env' } } }; } // 읽을 수 없으면 막음
  // 판단 중 오류가 나면 막는 쪽으로 (키 유출보다 agy 실패가 낫다. 실패하면 키트가 대체 경로로 넘어감).
  let out;
  try { out = guardDecision(input); } catch (e) { out = { decision: 'deny', reason: `agentic-kit 가드 오류: ${e.message}` }; }
  process.stdout.write(JSON.stringify(out) + '\n');
}
