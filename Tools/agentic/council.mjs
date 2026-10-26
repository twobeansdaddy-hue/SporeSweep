#!/usr/bin/env node
// 설계 협의체: 구현 전에 Codex·Antigravity에게 독립 제안을 받고, 교차 비판을 한 번 돌린다.
// Claude(오케스트레이터)는 실행 전에 자기 안을 파일로 써 두고 --claude-file로 넘긴다 (먼저 보여주면 다른 위원이 끌려감).
// 사용: node tools/agentic/council.mjs "<주제>" [--claude-file 경로] [--context-file 경로]... [--no-cross]
// 종료 코드: 0 성공(위원 1명 이상 응답) / 75 외부 위원 전원 실패 → 협의 생략 / 2 사용법 오류
import { mkdirSync, readFileSync, writeFileSync, existsSync, statSync, realpathSync, accessSync, constants } from 'node:fs';
import { join, dirname, resolve, basename } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { findRoot, loadConfig, globalEnvPath, childEnv, agyWorkspace, stageSettings, codexModelArgs, agyModelArgs, hasCommand, run, agyFailure, exitFailure, EXIT_FALLBACK } from './lib.mjs';

// 키가 필요 없으므로 loadEnv를 하지 않는다. 자식 프로세스에도 키트 키를 지운 환경만 넘긴다.
const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
const CONFIG = loadConfig(ROOT);
const CFG = CONFIG.council ?? {};
const MAX_CONTEXT_CHARS = 60000;

function usage(msg) {
  console.error(`오류: ${msg}`);
  console.error('사용: council.mjs "<주제>" [--claude-file 경로] [--context-file 경로]... [--no-cross]');
  process.exit(2);
}

// 넘긴 파일은 외부 모델로 전송되므로, 키 파일은 심볼릭 링크를 따라간 실제 경로 기준으로 거부한다.
function inputFile(opt, value) {
  if (!value || value.startsWith('--')) usage(`${opt} 값 없음`);
  const p = resolve(value);
  if (!existsSync(p) || !statSync(p).isFile()) usage(`일반 파일이 아님: ${p}`);
  try { accessSync(p, constants.R_OK); } catch { usage(`읽을 수 없음: ${p}`); }
  const real = realpathSync(p);
  // 프로젝트 .env나 공용 키 파일이 다른 이름의 파일을 가리키는 링크여도 걸리도록 양쪽 다 실제 경로로 비교한다.
  const keyFiles = [join(ROOT, '.env'), globalEnvPath()].filter(existsSync).map((f) => realpathSync(f));
  if ((/^\.env(\..+)?$/.test(basename(real)) && basename(real) !== '.env.example') || keyFiles.includes(real))
    usage(`키 파일은 협의 자료로 넘길 수 없습니다: ${p}`);
  return p;
}

const args = process.argv.slice(2);
let topic = '', claudeFile = '', cross = CFG.crossCritique !== false;
const contextFiles = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--claude-file') claudeFile = inputFile(args[i], args[++i]);
  else if (args[i] === '--context-file') contextFiles.push(inputFile(args[i], args[++i]));
  else if (args[i] === '--no-cross') cross = false;
  else if (!topic && !args[i].startsWith('--')) topic = args[i];
  else usage(`알 수 없는 인자: ${args[i]}`);
}
if (!topic) usage('주제가 필요합니다');

if (CFG.enabled === false) {
  console.log('COUNCIL_DISABLED: config.json의 council.enabled가 false입니다. 협의 없이 진행하세요.');
  process.exit(0);
}

let codexModel, agyModel;
try { codexModel = codexModelArgs(stageSettings(CONFIG, 'council', 'codex')); agyModel = agyModelArgs(stageSettings(CONFIG, 'council', 'agy')); }
catch (e) { usage(e.message); }

const context = contextFiles.map((f) => `### ${f}\n${readFileSync(f, 'utf8')}`).join('\n\n').slice(0, MAX_CONTEXT_CHARS);
const claudeProposal = claudeFile ? readFileSync(claudeFile, 'utf8').trim() : '';

const outDir = join(ROOT, '.agentic', 'council');
const partsDir = join(outDir, 'parts');
mkdirSync(partsDir, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');

const MEMBERS = {
  codex: { label: 'Codex', role: '설계 비판자. 엣지 케이스, 실패 지점, 오류 처리, 테스트 가능성에 집중한다.', ask: askCodex },
  agy: { label: 'Antigravity', role: '선행 사례 조사자. 저장소 전체 맥락과, 비슷한 문제를 다른 곳에서 어떻게 풀었는지에 집중한다.', ask: askAgy },
};

const RULES = `파일을 수정하거나 삭제하지 말고, 명령은 읽기 전용으로만 실행하라. 먼저 AGENTS.md를 읽어라.
명령 출력이나 검색 결과를 지어내지 말고, 확인하지 못한 것은 "미확인"이라고 써라.`;

function proposalPrompt(m) {
  return `너는 이 저장소의 설계 협의체 위원이다. 역할: ${m.role}
${RULES}
다른 위원의 안은 보지 않은 상태다. 네 판단만으로 독립적으로 제안하라.

주제: ${topic}
${context ? `\n참고 자료:\n${context}\n` : ''}
출력은 아래 마크다운 형식만 쓴다.
## 제안
(접근 방식, 바꿀 파일, 단계)
## 위험
(실패 지점, 엣지 케이스, 범위 초과 우려)
## 테스트 전략
## 확신도
(0~1 숫자와 한 줄 이유)`;
}

function critiquePrompt(m, others) {
  return `너는 이 저장소의 설계 협의체 위원이다. 역할: ${m.role}
${RULES}

주제: ${topic}

아래는 네 1라운드 안과 다른 위원들의 안이다.
## 네 안
${m.proposal}

${others.map(([name, text]) => `## ${name} 안\n${text}`).join('\n\n')}

다른 위원 안마다 가장 큰 약점과 네 안보다 나은 점을 짚어라. 새 안을 처음부터 다시 쓰지 말라.
출력은 아래 형식만 쓴다.
${others.map(([name]) => `### ${name} 안\n- 약점:\n- 나은 점:`).join('\n')}
### 내 입장 변화
(유지 또는 수정 + 한 줄 이유)`;
}

async function askCodex(prompt, file) {
  if (!hasCommand('codex')) return { ok: false, reason: 'codex CLI 미설치' };
  // 설계 협의는 diff가 필요 없으므로 git 저장소가 아니어도 돌게 한다 (읽기 전용 샌드박스 유지).
  const res = await run('codex', ['exec', ...codexModel, '--sandbox', CONFIG.codex?.sandbox ?? 'read-only', '--skip-git-repo-check', '--cd', ROOT, '--output-last-message', file, prompt],
    { cwd: ROOT, timeoutMs: CFG.timeoutMs ?? 600000, env: childEnv() });
  return finish(res, existsSync(file) ? readFileSync(file, 'utf8').trim() : res.stdout.trim(), file);
}

async function askAgy(prompt, file) {
  if (!hasCommand('agy')) return { ok: false, reason: 'agy CLI 미설치' };
  // print 모드는 도구 호출을 자동 승인한다. 금지 목록이 없으면 참여시키지 않는다 (doctor.mjs와 같은 기준).
  if (!agyHasDenyList()) return { ok: false, reason: 'agy 금지 목록 없음 (bash setup-mac.sh 실행)' };
  // 파일 저장을 요청하지 않는다: headless 모드는 write_file을 자동 거부해 답 전체가 사라진다.
  // 출력 누락은 가짜 터미널(pty)로 막고, 화면 출력을 이쪽에서 파일로 남긴다.
  const argv = ['--add-dir', ROOT, '--print-timeout', CONFIG.agy?.printTimeout ?? '10m'];
  argv.push(...agyModel);
  argv.push('--print', prompt);
  // 키 파일 가드가 걸린 전용 폴더에서 실행한다 (프로젝트는 --add-dir로 붙임).
  const res = await run('agy', argv, { cwd: agyWorkspace(ROOT), timeoutMs: CFG.timeoutMs ?? 600000, pty: true, env: childEnv() });
  return finish(res, res.stdout.trim(), file, { agy: true });
}

function agyHasDenyList() {
  try {
    const deny = JSON.parse(readFileSync(join(homedir(), '.gemini', 'antigravity-cli', 'settings.json'), 'utf8'))?.permissions?.deny ?? [];
    return deny.includes('command(rm)');
  } catch { return false; }
}

// agy는 실패해도 종료 코드 0으로 안내문만 출력할 때가 있어 본문도 본다. codex는 종료 코드만 믿는다.
function finish(res, text, file, { agy = false } = {}) {
  if (res.timedOut) return { ok: false, reason: '시간 초과' };
  if (res.code !== 0) return { ok: false, reason: exitFailure(res) };
  if (!text) return { ok: false, reason: '빈 출력' };
  const notice = agy && agyFailure(text);
  if (notice) return { ok: false, reason: notice };
  if (!existsSync(file)) writeFileSync(file, text + '\n');
  return { ok: true, text };
}

// 1라운드: 독립 제안 (병렬). Claude 안은 여기 넣지 않는다.
const ids = Object.keys(MEMBERS);
const round1 = await Promise.all(ids.map((id) => MEMBERS[id].ask(proposalPrompt(MEMBERS[id]), join(partsDir, `${stamp}-${id}-proposal.md`))));
ids.forEach((id, i) => { MEMBERS[id].r1 = round1[i]; MEMBERS[id].proposal = round1[i].text; });
const active = ids.filter((id) => MEMBERS[id].r1.ok);

// 2라운드: 교차 비판 1회 (병렬). 비판할 다른 안이 있는 위원만.
if (cross && active.length) {
  await Promise.all(active.map(async (id) => {
    const others = [
      ...(claudeProposal ? [['Claude', claudeProposal]] : []),
      ...active.filter((o) => o !== id).map((o) => [MEMBERS[o].label, MEMBERS[o].proposal]),
    ];
    if (!others.length) return;
    MEMBERS[id].r2 = await MEMBERS[id].ask(critiquePrompt(MEMBERS[id], others), join(partsDir, `${stamp}-${id}-critique.md`));
  }));
}

const status = (r) => !r ? '생략' : r.ok ? '응답' : `실패(${r.reason})`;
const section = (title, r) => `### ${title}\n${r?.ok ? r.text : `_${status(r)}_`}`;
const record = `# 설계 협의 ${stamp}

## 주제
${topic}

## 참여
| 위원 | 1라운드 제안 | 2라운드 비판 |
|---|---|---|
| Claude | ${claudeProposal ? '응답' : '없음 (--claude-file 미지정)'} | 오케스트레이터가 아래 종합에서 작성 |
${ids.map((id) => `| ${MEMBERS[id].label} | ${status(MEMBERS[id].r1)} | ${status(MEMBERS[id].r2)} |`).join('\n')}
${active.length < ids.length ? `\n> 대체 경로: 응답하지 않은 위원이 있습니다. 서브에이전트로 채우지 않았으므로 의견 다양성이 줄었습니다.\n` : ''}
## 1라운드 — 독립 제안
### Claude
${claudeProposal || '_없음_'}

${ids.map((id) => section(MEMBERS[id].label, MEMBERS[id].r1)).join('\n\n')}

## 2라운드 — 교차 비판
${ids.map((id) => section(MEMBERS[id].label, MEMBERS[id].r2)).join('\n\n')}

## 종합 (오케스트레이터 작성)
- 합의한 점:
- 의견이 갈린 점 (사용자 결정 필요):
- 선택한 안과 이유:
- 협의로 계획이 바뀌었나: 예 / 아니오 — (무엇이)
`;

const recordPath = join(outDir, `council-${stamp}.md`);
writeFileSync(recordPath, record);
console.log(record);
console.log(`COUNCIL_FILE=${recordPath}`);
console.log(`PARTICIPANTS ${ids.map((id) => `${id}=${MEMBERS[id].r1.ok ? 'ok' : 'unavailable'}`).join(' ')}`);
if (!active.length) {
  console.log('COUNCIL_UNAVAILABLE: 외부 위원이 모두 응답하지 않았습니다. 협의 없이 Claude 계획으로 진행하고 보고에 적으세요.');
  process.exit(EXIT_FALLBACK);
}
