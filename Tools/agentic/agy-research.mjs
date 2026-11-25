#!/usr/bin/env node
// Antigravity CLI(agy)로 보조 리서치를 맡긴다. 결과는 .agentic/research/에 저장된다.
// 사용: node tools/agentic/agy-research.mjs "<조사 질문>" [--dir 경로] [--model gemini-3.8-flash-low] [--effort low] [--tier 등급] [--draft]
//       --draft: 조사 보고서 대신 문서 초안(기획서 등)을 받는다. 질문 자리에 무엇을 어떤 구성으로 쓸지 적는다. 결과 파일은 agy-draft-*.md.
//       --model·--effort를 주지 않으면 --tier 등급 값(config.json의 autoSelect.tiers), 다음은 stages.research.agy, 그것도 비면 agy 전역 기본값.
//       --effort default: 강도를 넘기지 않는다 (강도를 받지 않는 모델용). --model을 바꿀 때는 --effort도 같이 준다.
// 종료 코드: 0 성공 / 75 대체 경로 필요(미설치·한도·시간 초과·빈 출력) / 2 사용법 오류
//
// 주의: agy의 print 모드는 모든 도구 호출을 자동 승인합니다.
// ~/.gemini/antigravity-cli/settings.json 에 금지 목록을 꼭 넣으세요 (README 참고).
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, loadConfig, childEnv, agyWorkspace, stageSettings, withTier, agyModelArgs, agyPinned, pickEffort, hasCommand, run, agyFailure, exitFailure, EXIT_FALLBACK } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const CONFIG = loadConfig(ROOT);
const CFG = CONFIG.agy ?? {};

const args = process.argv.slice(2);
let question = '', dir = ROOT, model = '', effort = '', tier = '', draft = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--dir') dir = resolve(args[++i]);
  else if (args[i] === '--model' || args[i] === '--effort') {
    const v = args[++i];
    if (v === undefined || v.trim() === '') { console.error(`${args[i - 1]}에 값이 없습니다`); process.exit(2); }
    if (args[i - 1] === '--model') model = v; else effort = v;
  }
  else if (args[i] === '--tier') tier = args[++i] ?? '';
  else if (args[i] === '--draft') draft = true;
  else if (!question) question = args[i];
  else { console.error(`알 수 없는 인자: ${args[i]}`); process.exit(2); }
}
if (!question) { console.error('사용: agy-research.mjs "<조사 질문>" [--dir 경로] [--model 이름] [--effort 강도] [--tier 등급] [--draft]'); process.exit(2); }
let modelArgs;
try {
  const stage = stageSettings(withTier(CONFIG, tier, model ? { 'research.agy': model } : {}), 'research', 'agy');
  // --model에 강도가 들어 있으면(…-low, 표시 이름) 설정·등급의 강도를 얹지 않는다.
  // --effort default는 강도를 넘기지 않는다 (efforts가 빈 모델용).
  modelArgs = agyModelArgs({ model: model || stage.model, effort: pickEffort(effort, agyPinned(model) ? '' : stage.effort) });
} catch (e) { console.error(e.message); process.exit(2); }

function fallback(reason, detail = '') {
  console.log(`AGY_UNAVAILABLE: ${reason}`);
  if (detail) console.log(detail.trim().slice(-800));
  console.log(draft ? '→ 초안은 직접 쓰세요 (조사가 필요하면 researcher 서브에이전트).' : '→ researcher 서브에이전트로 같은 질문을 조사하세요.');
  process.exit(EXIT_FALLBACK);
}

if (!hasCommand('agy')) fallback('Antigravity CLI(agy)가 설치되어 있지 않습니다.');

const outDir = join(ROOT, '.agentic', 'research');
mkdirSync(outDir, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const reportPath = join(outDir, `agy-${draft ? 'draft-' : ''}${stamp}.md`);

// 초안 모드: 결정은 오케스트레이터와 사용자가 한다. 초안은 제안일 뿐이므로 정하지 못한 것을 따로 적게 한다.
const draftPrompt = `너는 문서 초안 작성자다. 파일을 만들거나 고치거나 지우지 말고, 명령은 읽기 전용으로만 실행하라.
저장소에 이미 있는 문서·코드와 어긋나지 않게 쓰고, 필요한 파일은 직접 읽어 확인하라.
측정하지 않은 수치나 확인하지 못한 사실을 지어내지 말라. 임의로 정한 값은 "가정"이라고 표시하라.
요청: ${question}

초안 전문을 마크다운으로 화면에 출력하라. 파일로 저장하지 말라.
맨 끝에 "## 미확인"을 두고, 가정한 것과 사람이 정해야 하는 것을 목록으로 적어라.`;

const prompt = draft ? draftPrompt : `너는 조사 전용 에이전트다. 소스 코드를 수정하거나 삭제하지 말고, 명령은 읽기 전용으로만 실행하라.
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
