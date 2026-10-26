#!/usr/bin/env node
// Antigravity CLI(agy)로 보조 리서치를 맡긴다. 결과는 .agentic/research/에 저장된다.
// 사용: node tools/agentic/agy-research.mjs "<조사 질문>" [--dir 경로] [--model gemini-3.8-flash-low] [--effort low]
//       --model·--effort를 주지 않으면 config.json의 stages.research.agy, 그것도 비면 agy 전역 기본값.
// 종료 코드: 0 성공 / 75 대체 경로 필요(미설치·한도·시간 초과·빈 출력) / 2 사용법 오류
//
// 주의: agy의 print 모드는 모든 도구 호출을 자동 승인합니다.
// ~/.gemini/antigravity-cli/settings.json 에 금지 목록을 꼭 넣으세요 (README 참고).
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, loadConfig, childEnv, agyWorkspace, stageSettings, agyModelArgs, hasCommand, run, agyFailure, exitFailure, EXIT_FALLBACK } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const CONFIG = loadConfig(ROOT);
const CFG = CONFIG.agy ?? {};

const args = process.argv.slice(2);
let question = '', dir = ROOT, model = '', effort = '';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--dir') dir = resolve(args[++i]);
  else if (args[i] === '--model') model = args[++i] ?? '';
  else if (args[i] === '--effort') effort = args[++i] ?? '';
  else if (!question) question = args[i];
  else { console.error(`알 수 없는 인자: ${args[i]}`); process.exit(2); }
}
if (!question) { console.error('사용: agy-research.mjs "<조사 질문>" [--dir 경로] [--model 이름] [--effort 강도]'); process.exit(2); }
let modelArgs;
try {
  const stage = stageSettings(CONFIG, 'research', 'agy');
  modelArgs = agyModelArgs({ model: model || stage.model, effort: effort || stage.effort });
} catch (e) { console.error(e.message); process.exit(2); }

function fallback(reason, detail = '') {
  console.log(`AGY_UNAVAILABLE: ${reason}`);
  if (detail) console.log(detail.trim().slice(-800));
  console.log('→ researcher 서브에이전트로 같은 질문을 조사하세요.');
  process.exit(EXIT_FALLBACK);
}

if (!hasCommand('agy')) fallback('Antigravity CLI(agy)가 설치되어 있지 않습니다.');

const outDir = join(ROOT, '.agentic', 'research');
mkdirSync(outDir, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const reportPath = join(outDir, `agy-${stamp}.md`);

const prompt = `너는 조사 전용 에이전트다. 소스 코드를 수정하거나 삭제하지 말고, 명령은 읽기 전용으로만 실행하라.
명령 출력이나 검색 결과를 지어내지 말고, 확인하지 못한 것은 "미확인"이라고 써라.
조사 질문: ${question}

최종 보고서를 마크다운으로 화면에 출력하라. 파일로 저장하지 말라.
형식: "## 결론"(3~5줄), "## 근거"(출처 URL 또는 파일:줄), "## 미확인".`;

// 플래그는 반드시 --print 앞에 둔다 (뒤에 두면 프롬프트로 처리됨).
const argv = ['--add-dir', dir, '--print-timeout', CFG.printTimeout ?? '10m'];
argv.push(...modelArgs);
argv.push('--print', prompt);

// 키 파일 가드가 걸린 전용 폴더에서 실행하고(조사 대상은 --add-dir), 키트 키를 지운 환경만 넘긴다.
const res = await run('agy', argv, { cwd: agyWorkspace(ROOT), timeoutMs: CFG.timeoutMs ?? 600000, pty: true, env: childEnv() });
const combined = `${res.stdout}\n${res.stderr}`;

if (res.timedOut) fallback('시간 초과');
// 0이 아닌 종료 코드면 화면에 찍힌 오류 안내를 보고서로 저장하지 않는다.
if (res.code !== 0) fallback(`Antigravity ${exitFailure(res)}`, combined);

// 파일 저장은 요청하지 않는다: headless 모드는 write_file을 자동 거부해 답 전체가 사라진다.
// 출력 누락은 가짜 터미널(pty)로 막고, 화면 출력을 이쪽에서 파일로 남긴다.
const report = res.stdout.trim();
if (!report) fallback(`출력이 비어 있습니다 (종료 코드 ${res.code})`, res.stderr);
const notice = agyFailure(report);
if (notice) fallback(`Antigravity ${notice}`, report);
writeFileSync(reportPath, report + '\n');

console.log(report);
console.log(`\nRESEARCH_FILE=${reportPath}`);
