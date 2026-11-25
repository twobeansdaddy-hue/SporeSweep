#!/usr/bin/env node
// 키트가 부르는 외부 CLI(codex·agy)가 최신인지 보고, 필요하면 업데이트한다.
// 사용: node tools/agentic/cli-update.mjs [check] [codex|agy]           업데이트가 필요한지 본다 (기본, 아무것도 바꾸지 않음)
//       node tools/agentic/cli-update.mjs update [codex|agy] [--yes]   --yes가 없으면 check와 같다. 있으면 업데이트하고 버전을 다시 확인한다
// 업데이트는 이 컴퓨터 전체의 CLI를 바꾼다. 설정(auto·commands)은 저장소가 아니라 사용자 설정 파일
// (~/.config/agentic-kit/cli-update.json, lib.mjs의 cliUpdateSettingsPath)에서만 읽는다.
// 오케스트레이터는 auto가 참일 때만 묻지 않고 --yes를 붙이고, 아니면 check 출력을 사용자에게 보이고 승인을 받은 뒤 붙인다 (PIPELINE "CLI 업데이트").
// 종료 코드: 0 모두 최신(또는 판단 불가)·업데이트 성공 / 3 업데이트 필요(check·--yes 없는 update) / 1 업데이트 실패 / 2 사용법 오류
import { appendFileSync, mkdirSync, readFileSync, realpathSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, childEnv, compareVersions, parseVersion, resolveCommand, updatePlan, isNpmInstall, isAppBundled, loadCliUpdateSettings, cliUpdateSettingsPath } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const SETTINGS = loadCliUpdateSettings();
const TOOLS = ['codex', 'agy'];
const WIN = process.platform === 'win32';

const args = process.argv.slice(2);
let action = 'check', only = '', yes = false;
for (const a of args) {
  if (a === '--yes') yes = true;
  else if (a === 'check' || a === 'update') action = a;
  else if (TOOLS.includes(a) && (!only || only === a)) only = a;
  else { console.error(`사용: cli-update.mjs [check|update] [${TOOLS.join('|')}] [--yes]`); process.exit(2); }
}

// 명령 실행. Windows의 npm은 .cmd라 셸로만 실행된다. 이때 인자는 모두 고정 문자열이거나 SAFE_ARG_RE로 검사한 값이고,
// 배열 + shell 조합(Node 24 DEP0190)을 피하려고 명령 문자열 하나로 넘긴다.
function sh(cmd, argv, timeout = 60000) {
  const opts = { encoding: 'utf8', timeout, env: childEnv(), stdio: ['ignore', 'pipe', 'pipe'] };
  const r = WIN && cmd === 'npm' ? spawnSync(['npm', ...argv].join(' '), { ...opts, shell: true }) : spawnSync(cmd, argv, opts);
  return { ok: !r.error && r.status === 0, out: `${r.stdout ?? ''}`.trim(), err: `${r.stderr ?? ''}${r.error ? String(r.error) : ''}`.trim(), code: r.status };
}

function where(cmd) {
  const r = WIN ? sh('where', [cmd]) : sh('which', ['-a', cmd]);
  return resolveCommand(r.ok ? r.out : '');
}

function realpath(p) { try { return realpathSync(p); } catch { return p; } }

function installMethod(path) {
  if (isAppBundled(path) || isAppBundled(realpath(path))) return 'app';
  const root = sh('npm', ['root', '-g']);
  if (root.ok && isNpmInstall(realpath(path), root.out)) return 'npm';
  // 그 실행 파일이 update 하위 명령을 갖고 있을 때만 스스로 업데이트하게 한다.
  const help = sh(path, ['--help'], 15000);
  return help.ok && /^\s+update\s/m.test(help.out) ? 'self' : '';
}

function codexLatest() {
  const r = sh('npm', ['view', '@openai/codex', 'version']);
  const v = r.ok ? parseVersion(r.out) : '';
  if (v) return { latest: v, latestFrom: 'npm' };
  // npm을 못 쓰면 codex가 스스로 남긴 확인 기록 (~/.codex/version.json)
  try {
    const j = JSON.parse(readFileSync(join(process.env.CODEX_HOME || join(homedir(), '.codex'), 'version.json'), 'utf8'));
    const c = parseVersion(j.latest_version);
    if (c) return { latest: c, latestFrom: 'codex version.json' };
  } catch { /* 없음 */ }
  return { latest: '', latestFrom: '' };
}

function inspect(tool) {
  const { path, all } = where(tool);
  if (!all.length) return { tool, installed: '', needsUpdate: null, command: null, reason: `${tool} CLI가 설치되어 있지 않음` };
  if (!path) return { tool, installed: '', paths: all, needsUpdate: null, command: null, reason: 'Node가 실행할 수 있는 실행 파일이 없음 (Windows에서 .cmd만 있으면 키트 스크립트가 부르지 못함)' };
  const ver = sh(path, ['--version'], 15000);
  const installed = ver.ok ? parseVersion(ver.out) : '';
  const override = SETTINGS.commands?.[tool];
  let info = { installed, path, override };
  if (tool === 'codex') info = { ...info, ...codexLatest(), method: installMethod(path) };
  const plan = updatePlan(tool, info);
  // Windows에서 .cmd·.bat은 셸 없이 실행되지 않으므로 사용자 명령으로 받지 않는다.
  if (WIN && plan.command && Array.isArray(override) && override.length && /\.(cmd|bat)$/i.test(override[0])) {
    Object.assign(plan, { command: null, reason: `commands.${tool}의 첫 인자가 .cmd·.bat이라 실행할 수 없음 (.exe 경로나 node 스크립트를 지정)` });
  }
  return { ...plan, ...(info.latestFrom ? { latestFrom: info.latestFrom } : {}), ...(all.length > 1 ? { paths: all } : {}) };
}

function logUpdate(entry) {
  try {
    mkdirSync(join(ROOT, '.agentic', 'logs'), { recursive: true });
    appendFileSync(join(ROOT, '.agentic', 'logs', 'cli-updates.jsonl'), JSON.stringify({ at: new Date().toISOString(), ...entry }) + '\n');
  } catch { /* 기록 실패는 무시 */ }
}

const picked = TOOLS.filter((t) => !only || only === t);
const plans = picked.map(inspect);

if (action === 'check' || !yes) {
  console.log(JSON.stringify({ action: 'check', auto: SETTINGS.auto, settings: cliUpdateSettingsPath(), tools: plans }, null, 2));
  process.exit(plans.some((p) => p.needsUpdate === true) ? 3 : 0);
}

// update --yes: 최신보다 낮은 도구만. 최신을 알 수 없는 도구는 이름을 콕 집었고 사용자 설정 명령이 있을 때만 실행한다.
const results = [];
for (const p of plans) {
  const custom = Array.isArray(SETTINGS.commands?.[p.tool]) && SETTINGS.commands[p.tool].length > 0;
  const run = p.needsUpdate === true || (p.needsUpdate === null && only === p.tool && custom);
  if (!run) { results.push({ tool: p.tool, skipped: p.needsUpdate === false ? '이미 최신' : (p.reason || '최신 버전을 알 수 없음'), installed: p.installed }); continue; }
  if (!p.command) { results.push({ tool: p.tool, ok: false, error: p.reason || '업데이트 명령 없음', installed: p.installed }); continue; }
  const [cmd, ...rest] = p.command;
  const r = sh(cmd, rest, 600000);
  const after = sh(p.path || p.tool, ['--version'], 15000);
  const now = after.ok ? parseVersion(after.out) : '';
  const ok = r.ok && (!p.latest || (!!now && compareVersions(now, p.latest) >= 0));
  const res = { tool: p.tool, ok, before: p.installed, after: now, latest: p.latest, command: p.command.join(' ') };
  if (!r.ok) res.error = (r.err || r.out).slice(-500);
  else if (!ok) res.error = `명령은 끝났지만 버전이 ${now || '확인 불가'}로 최신(${p.latest})보다 낮음 (다른 설치본이 먼저 잡히는지 paths 확인)`;
  results.push(res);
  logUpdate(res);
}
console.log(JSON.stringify({ action: 'update', tools: results }, null, 2));
process.exit(results.some((r) => r.ok === false) ? 1 : 0);
