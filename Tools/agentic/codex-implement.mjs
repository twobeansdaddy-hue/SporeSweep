#!/usr/bin/env node
// 범위가 정해진 작업 하나를 Codex에게 구현시킨다 (별도 워크트리·브랜치, workspace-write 샌드박스).
// 사용: node tools/agentic/codex-implement.mjs --name <짧은-이름> (--task "<작업 지시>" | --task-file <파일>) [--tier 등급] [--model 이름] [--effort 강도]
//       --model·--effort: 이번 조각에만 쓸 값 (models.mjs 목록에서 고른 값). 등급·stages 값보다 우선한다. --effort default는 강도를 넘기지 않는다.
//       --name: 소문자·숫자·하이픈. 브랜치 agentic/codex-<이름>, 워크트리 .agentic/tmp/worktrees/<이름>이 된다.
//       --tier: 요청 난이도 등급(config.json의 autoSelect.tiers). 그 등급의 모델·추론 강도를 stages.implement 위에 덮는다.
// Codex는 커밋하지 않는다. 결과는 워크트리에 커밋되지 않은 변경으로 남고, 오케스트레이터가 확인한 뒤 커밋·병합한다.
// 종료 코드: 0 성공(변경 있음) / 75 대체 경로 필요(미설치·한도 초과·시간 초과·변경 없음) / 2 사용법 오류
//   75일 때 첫 줄: CODEX_UNAVAILABLE(못 돌림) · CODEX_NO_CHANGE(돌았지만 바꾼 것 없음, 보고를 읽을 것) · CODEX_INCOMPLETE(끊겼고 변경이 남음)
import { mkdirSync, readFileSync, writeFileSync, existsSync, realpathSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { findRoot, loadEnv, loadConfig, childEnv, stageSettings, withTier, codexModelArgs, pickEffort, hasCommand, run, exitFailure, EXIT_FALLBACK } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const CONFIG = loadConfig(ROOT);
const CFG = CONFIG.codex ?? {};

const args = process.argv.slice(2);
let name = '', task = '', taskFile = '', tier = '', model = '', effort = '';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--name') name = args[++i] ?? '';
  else if (args[i] === '--task') task = args[++i] ?? '';
  else if (args[i] === '--task-file') taskFile = args[++i] ?? '';
  else if (args[i] === '--tier') tier = args[++i] ?? '';
  else if (args[i] === '--model' || args[i] === '--effort') {
    const v = args[++i];
    if (v === undefined || v.trim() === '') { console.error(`${args[i - 1]}에 값이 없습니다`); process.exit(2); }
    if (args[i - 1] === '--model') model = v; else effort = v;
  }
  else { console.error(`알 수 없는 인자: ${args[i]}`); process.exit(2); }
}
function usage(msg) {
  console.error(`${msg}\n사용: codex-implement.mjs --name <짧은-이름> (--task "<작업 지시>" | --task-file <파일>) [--tier 등급] [--model 이름] [--effort 강도]`);
  process.exit(2);
}
if (!/^[a-z0-9][a-z0-9-]{0,39}$/.test(name)) usage('--name은 소문자·숫자·하이픈 1~40자여야 합니다');
if (task && taskFile) usage('--task와 --task-file 중 하나만 쓰세요');
if (taskFile) {
  try { task = readFileSync(taskFile, 'utf8'); } catch (e) { usage(`작업 파일을 읽을 수 없습니다: ${e.message}`); }
}
if (!task.trim()) usage('작업 지시가 비어 있습니다');

function fallback(reason, detail = '') {
  console.log(`CODEX_UNAVAILABLE: ${reason}`);
  if (detail) console.log(detail.trim().slice(-800));
  console.log('→ 이 작업은 직접 구현하세요.');
  process.exit(EXIT_FALLBACK);
}

let modelArgs;
try {
  const stage = stageSettings(withTier(CONFIG, tier), 'implement', 'codex');
  modelArgs = codexModelArgs({ model: model.trim() || stage.model, effort: pickEffort(effort, stage.effort) });
} catch (e) { console.error(e.message); process.exit(2); }

if (!hasCommand('codex')) fallback('codex CLI가 설치되어 있지 않습니다 (npm i -g @openai/codex).');

const git = (argv, cwd = ROOT) => spawnSync('git', argv, { cwd, encoding: 'utf8' });
const head = git(['rev-parse', '--verify', 'HEAD']);
if (head.status !== 0) usage('git 저장소가 아니거나 커밋이 없습니다 (워크트리를 만들 수 없음)');
const startCommit = head.stdout.trim();
// 키트가 저장소 하위 폴더(모노레포)에 설치돼 있으면 워크트리는 저장소 전체를 담는다. Codex는 그 안의 같은 하위 폴더에서만 일하게 한다.
const top = git(['rev-parse', '--show-toplevel']);
if (top.status !== 0) usage('git 저장소 최상위를 찾지 못했습니다');
const subdir = relative(realpathSync(top.stdout.trim()), realpathSync(ROOT));
if (subdir.startsWith('..')) usage('프로젝트 폴더가 git 저장소 밖에 있습니다');

const branch = `agentic/codex-${name}`;
const worktree = join(ROOT, '.agentic', 'tmp', 'worktrees', name);
if (existsSync(worktree)) usage(`워크트리가 이미 있습니다: ${worktree} (다른 이름을 쓰거나 git worktree remove로 지우세요)`);
if (git(['rev-parse', '--verify', '--quiet', `refs/heads/${branch}`]).status === 0) usage(`브랜치가 이미 있습니다: ${branch} (다른 이름을 쓰세요)`);
mkdirSync(dirname(worktree), { recursive: true });
const add = git(['worktree', 'add', '-b', branch, worktree, startCommit]);
if (add.status !== 0) { console.error(`워크트리를 만들지 못했습니다: ${add.stderr.trim()}`); process.exit(2); }
const workdir = subdir ? join(worktree, subdir) : worktree;

// 변경이 없을 때만 워크트리와 브랜치를 치운다 (변경이 있으면 오케스트레이터가 확인해야 하므로 남긴다).
function cleanup() {
  git(['worktree', 'remove', '--force', worktree]);
  git(['branch', '-D', branch]);
}

const prompt = `너는 이 저장소에서 아래 작업 하나를 구현한다. 지금 폴더는 이 작업만을 위한 git 워크트리다.
먼저 AGENTS.md를 읽고 프로젝트 규칙을 따른다.
- 작업 범위 안에서만 고친다. 관련 없는 리팩터링, 의존성 추가, 설정 변경은 하지 않는다.
- 새 기능과 버그 수정에는 테스트를 함께 쓰고, AGENTS.md "프로젝트" 절의 테스트 명령을 실제로 실행한다.
- 커밋, 푸시, 브랜치 변경은 하지 않는다. 변경은 작업 트리에 그대로 둔다.
- 작업 지시가 모호해서 구현 방향을 정할 수 없으면 추측으로 진행하지 말고, 무엇이 필요한지만 답한다.
마지막 답에는 아래만 쓴다.
## 바꾼 것
(파일별 한 줄)
## 테스트
(실행한 명령과 실제 결과. 실행하지 못했으면 이유)
## 남은 것
(끝내지 못한 부분, 확인이 필요한 가정. 없으면 "없음")

작업:
${task.trim()}`;

const outDir = join(ROOT, '.agentic', 'reviews');
mkdirSync(outDir, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const lastMsg = join(outDir, `codex-implement-${name}-${stamp}.md`);

const res = await run('codex', [
  'exec',
  ...modelArgs,
  '--sandbox', 'workspace-write',
  '--cd', workdir,
  '--output-last-message', lastMsg,
  prompt,
  // 파일을 고칠 수 있는 프로세스이므로 키 파일의 키뿐 아니라 이름이 비밀값처럼 보이는 셸 변수도 넘기지 않는다
], { cwd: workdir, timeoutMs: CFG.implementTimeoutMs ?? 1800000, env: childEnv({ strict: true }) });

const combined = `${res.stdout}\n${res.stderr}`;
// 남은 것을 센다: 커밋되지 않은 변경과, 지시를 어기고 만든 커밋. git이 실패하면 아무것도 지우지 않는다.
const status = git(['status', '--porcelain'], worktree);
const nowHead = git(['rev-parse', '--verify', 'HEAD'], worktree);
if (status.status !== 0 || nowHead.status !== 0) {
  console.log('CODEX_INCOMPLETE: 워크트리 상태를 읽지 못했습니다. 아무것도 지우지 않았습니다.');
  console.log(`WORKTREE=${worktree}`);
  console.log(`BRANCH=${branch}`);
  console.log('→ 워크트리를 직접 확인하세요.');
  process.exit(EXIT_FALLBACK);
}
const uncommitted = status.stdout.split('\n').filter(Boolean);
const commits = nowHead.stdout.trim() === startCommit ? []
  : git(['rev-list', `${startCommit}..HEAD`], worktree).stdout.split('\n').filter(Boolean);
const committed = nowHead.stdout.trim() !== startCommit;
const changed = [...uncommitted, ...commits];
const tail = () => {
  console.log(`WORKTREE=${worktree}`);
  console.log(`BRANCH=${branch}`);
  if (committed) console.log(`COMMITTED=${commits.length || 1} (Codex가 지시와 달리 커밋했습니다. git -C <WORKTREE> log ${startCommit.slice(0, 12)}..HEAD 로 확인)`);
};

if (res.timedOut || res.code !== 0) {
  const reason = res.timedOut ? '시간 초과' : exitFailure(res);
  if (!changed.length && !committed) { cleanup(); fallback(reason === '모델 용량 부족' ? 'Codex 모델 용량 부족 (잠시 뒤 다시 하거나 stages.implement.codex.model로 다른 모델 지정)' : `Codex ${reason}`, combined); }
  // 중간에 끊겼지만 변경이 남았다: 지우지 않고 알린다.
  console.log(`CODEX_INCOMPLETE: Codex ${reason} — 끝나지 않은 변경 ${changed.length}개가 워크트리에 남아 있습니다.`);
  tail();
  console.log('→ 변경을 확인해 이어서 구현하거나, git worktree remove --force 로 버리고 직접 구현하세요.');
  process.exit(EXIT_FALLBACK);
}

const report = existsSync(lastMsg) ? readFileSync(lastMsg, 'utf8').trim() : res.stdout.trim();
if (!existsSync(lastMsg) && report) writeFileSync(lastMsg, report + '\n');
if (!changed.length && !committed) {
  // Codex는 돌았지만 바꾼 것이 없다. 지시가 모호해 되물은 것일 수 있으므로 "못 돌림"과 구분해 보고를 그대로 보여 준다.
  cleanup();
  console.log('CODEX_NO_CHANGE: Codex가 파일을 바꾸지 않았습니다. 아래는 Codex의 답입니다.');
  console.log(report || '(Codex가 답을 남기지 않았습니다)');
  if (report) console.log(`\nRESULT_FILE=${lastMsg}`);
  console.log('→ 정보가 부족하다는 답이면 지시를 보완해 다시 맡기거나 사용자에게 묻고, 그 밖에는 직접 구현하세요.');
  process.exit(EXIT_FALLBACK);
}

console.log(report || '(Codex가 요약을 남기지 않았습니다)');
console.log('');
tail();
console.log(`RESULT_FILE=${lastMsg}`);
console.log(`SUMMARY changed=${changed.length}`);
