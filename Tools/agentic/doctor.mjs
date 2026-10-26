#!/usr/bin/env node
// 환경 점검: 필요한 CLI, 로그인 상태, 키, 판정 모델 연결, Antigravity 금지 목록을 확인한다.
// 사용: node tools/agentic/doctor.mjs [--ping]   (--ping: 판정 모델에 실제 요청 1건)
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, loadConfig, globalEnvPath, readRegistry, compareVersions, stageSettings, codexModelArgs, agyModelArgs, hasCommand, run } from './lib.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = findRoot(HERE);
loadEnv(ROOT);
const ping = process.argv.includes('--ping');

const rows = [];
const add = (status, item, detail = '') => rows.push({ status, item, detail });

// Node
const [maj, min] = process.versions.node.split('.').map(Number);
const nodeOk = (maj === 22 && min >= 19) || (maj === 24 && min >= 11) || maj >= 26;
add(nodeOk ? 'OK' : 'WARN', `Node ${process.versions.node}`, nodeOk ? '' : 'REA는 22.19+ / 24.11+ / 26+ 필요');

// CLI
for (const [cmd, hint] of [
  ['git', 'Xcode Command Line Tools 또는 brew install git'],
  ['claude', 'Claude Code 설치'],
  ['codex', 'npm i -g @openai/codex → codex login'],
  ['agy', 'curl -fsSL https://antigravity.google/cli/install.sh | bash → agy 실행 후 로그인'],
]) add(hasCommand(cmd) ? 'OK' : (cmd === 'git' || cmd === 'claude' ? 'FAIL' : 'WARN'), `${cmd} 설치`, hasCommand(cmd) ? '' : hint);

if (hasCommand('codex')) {
  const r = await run('codex', ['login', 'status'], { timeoutMs: 20000 });
  const lines = `${r.stdout}${r.stderr}`.trim().split('\n');
  const out = lines.find((l) => /logged in/i.test(l)) ?? lines.pop();
  add(r.code === 0 ? 'OK' : 'WARN', 'codex 로그인', r.code === 0 ? out : '`codex login` 실행 (ChatGPT 계정)');
}

// Antigravity 금지 목록
const agySettings = join(homedir(), '.gemini', 'antigravity-cli', 'settings.json');
if (hasCommand('agy')) {
  let deny = [];
  try { deny = JSON.parse(readFileSync(agySettings, 'utf8'))?.permissions?.deny ?? []; } catch { /* 없음 */ }
  const hasRm = deny.includes('command(rm)');
  add(hasRm ? 'OK' : 'WARN', 'agy 금지 목록', hasRm ? deny.join(', ') : `${agySettings} 에 permissions.deny 추가 (bash setup-mac.sh)`);
  // 공용 키 파일 읽기 금지 규칙: 사용자가 직접 연 agy도 막는다 (키트 스크립트는 따로 PreToolUse 가드를 씀).
  const keyRule = `read_file(${globalEnvPath()})`;
  add(deny.includes(keyRule) ? 'OK' : 'WARN', 'agy 공용 키 파일 읽기 차단', deny.includes(keyRule) ? '' : `${keyRule} 를 permissions.deny에 추가 (bash setup-mac.sh)`);
}

// 결정 모델 키
const cf = process.env.CLOUDFLARE_ACCOUNT_ID && process.env.CLOUDFLARE_API_TOKEN;
add(cf ? 'OK' : 'WARN', 'Cloudflare 키', cf ? '' : `${globalEnvPath()} 에 채우기 (모든 프로젝트 공용) — 없으면 판정 단계를 건너뜀`);
for (const k of ['TYPESAFE_API_KEY', 'OPENROUTER_API_KEY', 'DECIDE_LOCAL_URL']) if (process.env[k]) add('OK', `${k} 설정됨`);

if (ping) {
  const r = await run(process.execPath, [join(HERE, 'decide.mjs'), 'review-triage', '--state', 'Variable name `x` could be more descriptive.'], { cwd: ROOT, timeoutMs: 30000 });
  let j = {};
  try { j = JSON.parse(r.stdout); } catch { /* 무시 */ }
  if (j.fallback === false) add('OK', `판정 모델 응답 (${j.provider}/${j.model})`, `${j.latencyMs}ms, 결과=${j.answers?.severity?.value}`);
  else add('WARN', '판정 모델 응답 실패', JSON.stringify(j.attempts ?? j.error ?? r.stdout).slice(0, 300));
}

// 단계별 모델·추론 강도 (config.json stages). 빈 값은 도구 기본값.
const CONFIG = loadConfig(ROOT);
const AGY_EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max'];          // agy --help 기준
const SUBAGENT_MODELS = ['', 'inherit', 'sonnet', 'opus', 'haiku', 'fable']; // Agent 도구가 받는 별칭
for (const [stage, agent] of [['review', 'codex'], ['council', 'codex'], ['council', 'agy'], ['research', 'agy'], ['subagents', 'reviewer'], ['subagents', 'researcher']]) {
  let model = '', effort = '';
  const problems = [];
  try { ({ model, effort } = stageSettings(CONFIG, stage, agent)); } catch (e) { problems.push(e.message); }
  if (!problems.length && stage !== 'subagents') {
    try { (agent === 'agy' ? agyModelArgs : codexModelArgs)({ model, effort }); } catch (e) { problems.push(e.message); }
  }
  if (stage === 'subagents' && effort && !/^[a-z]+$/.test(effort)) problems.push(`강도 "${effort}"는 소문자 단어여야 함`);
  else if (effort && agent !== 'codex' && !AGY_EFFORTS.includes(effort)) problems.push(`강도는 ${AGY_EFFORTS.join('|')} 중 하나`);
  if (stage === 'subagents' && !SUBAGENT_MODELS.includes(model)) problems.push(`모델은 ${SUBAGENT_MODELS.filter(Boolean).join('|')} 중 하나`);
  add(problems.length ? 'WARN' : 'OK', `모델 ${stage}.${agent}`, problems.length ? problems.join(', ') : `${model || '기본값'} / 강도 ${effort || '기본값'}`);
}

// 설치된 키트 버전 (install.mjs가 기록)
let selfPkg = null;
try { selfPkg = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8')); } catch { /* 일반 프로젝트 */ }
if (selfPkg?.name === 'agentic-kit') add('OK', `키트 저장소 자체 (${selfPkg.version})`);
else try {
  const kit = JSON.parse(readFileSync(join(ROOT, '.agentic', 'kit.json'), 'utf8'));
  add('OK', `키트 ${kit.version}`, `${kit.commit ?? '커밋 정보 없음'}, 설치 ${kit.installedAt?.slice(0, 10) ?? '?'}`);
  // 등록된 키트 폴더에 더 새 버전이 있으면 알린다.
  const { kitPath } = readRegistry();
  let latest = null;
  try { latest = JSON.parse(readFileSync(join(kitPath, 'package.json'), 'utf8')).version; } catch { /* 키트 폴더를 모름 */ }
  if (latest && compareVersions(latest, kit.version) > 0) add('WARN', `키트 새 버전 ${latest}`, `node ${join(kitPath, 'install.mjs')} --update-all`);
} catch { add('WARN', '키트 버전 기록 없음', 'install.mjs <경로> --update 로 .agentic/kit.json 생성'); }

// install.mjs --update가 남긴 파일: .kit-new(합칠 새 버전), .kit-old·.kit-new.bak(덮어쓰기 전 보관본)
const pending = [], kept = [];
(function scan(dir, depth) {
  if (depth > 4) return;
  let entries = [];
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; } // 없거나 읽을 수 없는 폴더
  for (const e of entries) {
    const rel = join(dir, e.name).slice(ROOT.length + 1);
    if (e.name.endsWith('.kit-new')) pending.push(rel);
    else if (e.name.endsWith('.kit-old') || e.name.endsWith('.kit-new.bak')) kept.push(rel);
    else if (e.isDirectory() && ['.agentic', '.claude', 'tools', 'agents', 'commands', 'agentic', 'decisions'].includes(e.name)) scan(join(dir, e.name), depth + 1);
  }
})(ROOT, 0);
if (pending.length) add('WARN', `합치지 않은 키트 새 버전 ${pending.length}개`, `${pending.join(', ')} — 원본과 비교해 합친 뒤 지우세요`);
if (kept.length) add('WARN', `키트 업데이트 보관본 ${kept.length}개`, `${kept.join(', ')} — 확인한 뒤 지우세요`);

// 파일
for (const f of ['AGENTS.md', 'CLAUDE.md', '.agentic/PIPELINE.md', '.claude/settings.json', '.mcp.json'])
  add(existsSync(join(ROOT, f)) ? 'OK' : 'FAIL', `파일 ${f}`);

const icon = { OK: '✔', WARN: '!', FAIL: '✘' };
console.log(`저장소: ${ROOT}\n`);
for (const r of rows) console.log(`${icon[r.status]} ${r.item}${r.detail ? `  — ${r.detail}` : ''}`);
const fails = rows.filter((r) => r.status === 'FAIL').length, warns = rows.filter((r) => r.status === 'WARN').length;
console.log(`\n${fails ? '필수 항목이 빠져 있습니다.' : warns ? '동작은 하지만 일부 단계가 대체 경로로 진행됩니다.' : '모든 준비가 끝났습니다.'}`);
process.exit(fails ? 1 : 0);
