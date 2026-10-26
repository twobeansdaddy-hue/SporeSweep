#!/usr/bin/env node
// Codex로 교차 리뷰를 받는다 (읽기 전용 샌드박스).
// 사용: node tools/agentic/codex-review.mjs [--base main] [--uncommitted] [--focus "중점 사항"]
// 종료 코드: 0 성공 / 75 대체 경로 필요(미설치·한도 초과·시간 초과·빈 출력) / 2 사용법 오류
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, loadConfig, stageSettings, codexModelArgs, hasCommand, run, exitFailure, EXIT_FALLBACK } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const CONFIG = loadConfig(ROOT);
const CFG = CONFIG.codex ?? {};

const args = process.argv.slice(2);
let base = CONFIG.baseBranch ?? 'main', uncommitted = false, focus = '';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--base') base = args[++i];
  else if (args[i] === '--uncommitted') uncommitted = true;
  else if (args[i] === '--focus') focus = args[++i] ?? '';
  else { console.error(`알 수 없는 인자: ${args[i]}`); process.exit(2); }
}

function fallback(reason, detail = '') {
  console.log(`CODEX_UNAVAILABLE: ${reason}`);
  if (detail) console.log(detail.trim().slice(-800));
  console.log('→ reviewer 서브에이전트로 같은 리뷰를 진행하세요.');
  process.exit(EXIT_FALLBACK);
}

if (!hasCommand('codex')) fallback('codex CLI가 설치되어 있지 않습니다 (npm i -g @openai/codex).');

const scope = uncommitted
  ? '커밋되지 않은 변경 (`git diff HEAD`와 새 파일)'
  : `\`git diff ${base}...HEAD\` 의 변경 (기본 브랜치 ${base} 대비 현재 브랜치)`;

const prompt = `너는 이 저장소의 독립 리뷰어다. 파일을 수정하지 말고 리뷰만 한다.
리뷰 대상: ${scope}.
먼저 AGENTS.md를 읽고 프로젝트 규칙을 확인한 뒤, git 명령으로 변경 내용을 직접 확인하라.
중점: 정확성(엣지 케이스, 오류 처리), 보안(입력 검증, 인증, 비밀값 노출), 테스트 누락, 요청 범위를 벗어난 변경.${focus ? `\n추가 중점: ${focus}` : ''}
출력은 아래 형식의 목록만 쓴다. 설명 문단은 쓰지 않는다.
- [must_fix|should_fix|nit] 파일:줄 — 문제 — 제안
지적 사항이 없으면 NO_ISSUES 한 줄만 출력한다.`;

const outDir = join(ROOT, '.agentic', 'reviews');
mkdirSync(outDir, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const lastMsg = join(outDir, `codex-${stamp}.md`);

let modelArgs;
try { modelArgs = codexModelArgs(stageSettings(CONFIG, 'review', 'codex')); } catch (e) { console.error(e.message); process.exit(2); }

const res = await run('codex', [
  'exec',
  ...modelArgs,
  '--sandbox', CFG.sandbox ?? 'read-only',
  '--cd', ROOT,
  '--output-last-message', lastMsg,
  prompt,
], { cwd: ROOT, timeoutMs: CFG.timeoutMs ?? 900000 });

const combined = `${res.stdout}\n${res.stderr}`;
if (res.timedOut) fallback('시간 초과');
if (res.code !== 0) {
  const reason = exitFailure(res);
  fallback(reason === '모델 용량 부족' ? 'Codex 모델 용량 부족 (잠시 뒤 다시 하거나 stages.review.codex.model로 다른 모델 지정)' : `Codex ${reason}`, combined);
}

const review = existsSync(lastMsg) ? readFileSync(lastMsg, 'utf8').trim() : res.stdout.trim();
if (!review) fallback('리뷰 출력이 비어 있습니다');
if (!existsSync(lastMsg)) writeFileSync(lastMsg, review + '\n');

const counts = { must_fix: 0, should_fix: 0, nit: 0 };
for (const m of review.matchAll(/^\s*-\s*\[(must_fix|should_fix|nit)\]/gm)) counts[m[1]]++;
console.log(review);
console.log(`\nREVIEW_FILE=${lastMsg}`);
console.log(`SUMMARY must_fix=${counts.must_fix} should_fix=${counts.should_fix} nit=${counts.nit}`);
