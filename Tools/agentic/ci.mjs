#!/usr/bin/env node
// CI 도우미. .github/workflows/agentic-ci.yml 이 부르고, 로컬에서도 같은 검사를 돌릴 수 있다.
//
//   node tools/agentic/ci.mjs guard            비밀값·.env 커밋 검사 (모든 저장소에서 항상 돈다)
//   node tools/agentic/ci.mjs plan             config.json의 ci 설정을 GitHub Actions 출력으로 낸다
//   node tools/agentic/ci.mjs run              ci.steps를 차례로 실행한다 (로컬에서도 같다)
//   node tools/agentic/ci.mjs suggest [--write [--force]] 프로젝트를 보고 ci.steps를 제안한다 (--write: config.json에 켜서 저장)
//
// 설정은 .agentic/config.json의 "ci" 항목이다. 기본값은 꺼짐(enabled: false)이라
// 키트를 갱신해도 비밀값 검사 외에는 아무것도 돌지 않는다. 켜는 것은 프로젝트에서 정한다.
import { existsSync, readFileSync, writeFileSync, statSync, readdirSync, appendFileSync, openSync, readSync, closeSync } from 'node:fs';
import { join, basename, relative, sep } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import { findRoot, loadConfig } from './lib.mjs';

export const CI_DEFAULTS = {
  enabled: false,
  runner: 'ubuntu-latest',
  node: '22',
  timeoutMinutes: 20,
  steps: [],
  secretScan: { enabled: true, ignore: [] },
};

export function ciConfig(config) {
  const c = config?.ci && typeof config.ci === 'object' ? config.ci : {};
  return {
    ...CI_DEFAULTS, ...c,
    secretScan: { ...CI_DEFAULTS.secretScan, ...(c.secretScan || {}) },
    steps: Array.isArray(c.steps) ? c.steps.filter((s) => s && typeof s.run === 'string' && s.run.trim()) : [],
  };
}

// ---------------------------------------------------------------------------------------------
// 비밀값 검사
// severity: error는 CI 실패, warning은 주석만 남긴다 (공개용 키일 수 있는 것: Firebase 웹 키 등).
export const SECRET_RULES = [
  { id: 'anthropic', severity: 'error', re: /sk-ant-(?:api|oat|admin)\d{2}-[A-Za-z0-9_-]{20,}/ },
  { id: 'openai', severity: 'error', re: /\bsk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{20,}/ },
  { id: 'openai-legacy', severity: 'error', re: /\bsk-[A-Za-z0-9]{48}\b/ },
  { id: 'aws-access-key', severity: 'error', re: /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/ },
  { id: 'github-token', severity: 'error', re: /\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b/ },
  { id: 'slack-token', severity: 'error', re: /\bxox[abprs]-[A-Za-z0-9-]{10,}/ },
  { id: 'stripe-live', severity: 'error', re: /\b(?:sk|rk)_live_[A-Za-z0-9]{20,}/ },
  { id: 'telegram-bot', severity: 'error', re: /\b\d{8,10}:AA[A-Za-z0-9_-]{33}\b/ },
  { id: 'private-key', severity: 'error', re: /-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY(?: BLOCK)?-----/ },
  { id: 'google-api-key', severity: 'warning', re: /\bAIza[0-9A-Za-z_-]{35}\b/, hint: 'Firebase 웹 설정처럼 공개용이면 무시해도 됩니다' },
  { id: 'assigned-secret', severity: 'warning', re: /(?:api[_-]?key|secret|token|passwd|password)["']?\s*[:=]\s*["'][A-Za-z0-9_\-/+=.]{24,}["']/i },
];
const ALLOW_MARK = 'agentic-ci: allow';
const DEFAULT_IGNORE = ['**/package-lock.json', '**/pnpm-lock.yaml', '**/yarn.lock', '**/*.lock', '**/*.min.js', '**/*.map', '**/.env.example', '**/.env.sample', '**/.env.template'];
const ENV_FILE_RE = /^\.env(\..+)?$/;
const ENV_OK_RE = /^\.env\.(example|sample|template|dist)$/;
const MAX_BYTES = 1024 * 1024;

export function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const ch = glob[i];
    if (ch === '*' && glob[i + 1] === '*') { re += glob[i + 2] === '/' ? '(?:.*/)?' : '.*'; i += glob[i + 2] === '/' ? 2 : 1; }
    else if (ch === '*') re += '[^/]*';
    else if (ch === '?') re += '[^/]';
    else re += /[.+^${}()|[\]\\]/.test(ch) ? `\\${ch}` : ch;
  }
  return new RegExp(`^${re}$`);
}

function listFiles(root, { requireGit = false } = {}) {
  const r = spawnSync('git', ['-C', root, 'ls-files', '-z'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.status === 0) return { files: r.stdout.split('\0').filter(Boolean), tracked: true };
  // CI에서 git이 실패하면(소유권 오류, git 없음, .git 없이 받은 소스) 커밋된 .env를 놓칠 수 있으므로 멈춘다.
  if (requireGit) throw new Error(`git ls-files 실패 — 추적 파일을 알 수 없어 검사하지 않습니다: ${(r.stderr || r.error?.message || '').trim()}`);
  const inside = spawnSync('git', ['-C', root, 'rev-parse', '--is-inside-work-tree'], { encoding: 'utf8' });
  if (inside.status === 0 && inside.stdout.trim() === 'true') throw new Error(`git ls-files 실패: ${(r.stderr || '').trim()}`);
  // git 저장소가 아니면 직접 훑는다 (로컬 시험용). 이때는 무엇이 커밋될지 알 수 없다.
  const out = [];
  (function walk(dir) {
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      if (['.git', 'node_modules', '.agentic'].includes(e.name)) continue;
      const p = join(dir, e.name);
      if (e.isDirectory()) walk(p); else out.push(relative(root, p).split(sep).join('/'));
    }
  })(root);
  return { files: out, tracked: false };
}

function readText(path, maxBytes = MAX_BYTES) {
  let st;
  try { st = statSync(path); } catch { return null; }
  if (!st.isFile() || st.size > maxBytes) return null;
  const fd = openSync(path, 'r');
  const head = Buffer.alloc(Math.min(8192, st.size));
  readSync(fd, head, 0, head.length, 0);
  closeSync(fd);
  if (head.includes(0)) return null; // 바이너리
  return readFileSync(path, 'utf8');
}

export const mask = (s) => (s.length <= 8 ? '****' : `${s.slice(0, 6)}…(${s.length}자)`);

// requireGit: CI처럼 반드시 git 저장소여야 하는 곳에서는 git 실패를 오류로 본다 (디렉터리 순회로 떨어지지 않음).
export function scanSecrets(root, { ignore = [], requireGit = false } = {}) {
  const ignores = [...DEFAULT_IGNORE, ...ignore].map(globToRegExp);
  const findings = [];
  const { files, tracked } = listFiles(root, { requireGit });
  for (const rel of files) {
    const name = basename(rel);
    const ignored = ignores.some((re) => re.test(rel));
    if (ENV_FILE_RE.test(name) && !ENV_OK_RE.test(name)) {
      if (ignored) continue; // 비밀값 없는 기본값만 일부러 커밋하는 프로젝트(.env.test 등)는 ignore에 넣는다
      findings.push(tracked
        ? { file: rel, line: 1, rule: 'env-file', severity: 'error', message: `${name} 파일이 저장소에 올라가 있습니다. git rm --cached ${rel} 후 .gitignore에 추가하고, 안의 키는 교체하세요.` }
        : { file: rel, line: 1, rule: 'env-file', severity: 'warning', message: `git 저장소가 아니라 커밋 여부를 알 수 없습니다. git을 쓰게 되면 ${name} 파일을 .gitignore에 넣으세요.` });
      continue;
    }
    if (name.endsWith('.kit-new')) findings.push({ file: rel, line: 1, rule: 'kit-new', severity: 'warning', message: '합치지 않은 키트 새 버전(.kit-new)이 커밋돼 있습니다' });
    if (ignored) continue;
    const text = readText(join(root, rel));
    if (text === null) continue;
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.includes(ALLOW_MARK)) continue;
      for (const rule of SECRET_RULES) {
        const m = rule.re.exec(line);
        if (!m) continue;
        findings.push({ file: rel, line: i + 1, rule: rule.id, severity: rule.severity,
          message: `${rule.id} 형식의 값 ${mask(m[0])}${rule.hint ? ` — ${rule.hint}` : ''}` });
        break; // 한 줄에 하나만
      }
    }
  }
  return findings;
}

// 올릴 폴더(빌드 결과물) 검사: git과 상관없이 폴더 안의 모든 파일을 본다 (cd.mjs가 배포 전에 쓴다).
// 배포물은 공개되므로 .env 파일은 이름만으로 오류, 키 형식 값은 규칙의 등급을 그대로 쓴다.
// 심볼릭 링크는 오류다 (wrangler는 링크 대상을 올리므로 폴더 밖 비밀 파일이 섞일 수 있음).
// 큰 번들도 검사하도록 maxBytes까지 읽는다 (기본: Pages 파일 한도 25MiB).
export function scanDir(dir, { maxBytes = 25 * 1024 * 1024 } = {}) {
  const findings = [];
  (function walk(abs, rel) {
    for (const e of readdirSync(abs, { withFileTypes: true })) {
      const a = join(abs, e.name), r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isSymbolicLink()) { findings.push({ file: r, line: 1, rule: 'symlink', severity: 'error', message: '심볼릭 링크는 올리지 않습니다 (링크 대상이 그대로 올라감) — 실제 파일로 바꾸세요' }); continue; }
      if (e.isDirectory()) { walk(a, r); continue; }
      if (!e.isFile()) continue;
      if (ENV_FILE_RE.test(e.name)) { findings.push({ file: r, line: 1, rule: 'env-file', severity: 'error', message: `${e.name} 파일이 올릴 폴더에 있습니다` }); continue; }
      const text = readText(a, maxBytes);
      if (text === null) continue;
      const lines = text.split('\n');
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].includes(ALLOW_MARK)) continue;
        const rule = SECRET_RULES.find((x) => x.re.test(lines[i]));
        if (rule) findings.push({ file: r, line: i + 1, rule: rule.id, severity: rule.severity, message: `${rule.id} 형식의 값${rule.hint ? ` — ${rule.hint}` : ''}` });
      }
    }
  })(dir, '');
  return findings;
}

// ---------------------------------------------------------------------------------------------
// GitHub Actions 출력 도우미
const inActions = () => process.env.GITHUB_ACTIONS === 'true';
const esc = (s) => String(s).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
const escProp = (s) => esc(s).replace(/:/g, '%3A').replace(/,/g, '%2C');
function annotate(f) {
  if (inActions()) console.log(`::${f.severity} file=${escProp(f.file)},line=${f.line},title=${escProp(`agentic-ci ${f.rule}`)}::${esc(f.message)}`);
  else console.log(`${f.severity === 'error' ? '✘' : '!'} ${f.file}:${f.line} [${f.rule}] ${f.message}`);
}
function summary(md) {
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, md + '\n');
}

// ---------------------------------------------------------------------------------------------
export function plan(config) {
  const ci = ciConfig(config);
  const notes = [];
  const runner = /^[\w.-]+$/.test(String(ci.runner)) ? String(ci.runner) : 'ubuntu-latest';
  const node = /^[\w.*/-]+$/.test(String(ci.node)) ? String(ci.node) : '22'; // setup-node의 with:로만 들어간다 (셸을 거치지 않음)
  const timeout = Number.isInteger(ci.timeoutMinutes) && ci.timeoutMinutes > 0 && ci.timeoutMinutes <= 360 ? ci.timeoutMinutes : 20;
  const enabled = ci.enabled === true && ci.steps.length > 0;
  if (ci.enabled !== true && ci.enabled !== false) notes.push(`ci.enabled 값(${JSON.stringify(ci.enabled)})이 true/false가 아니어서 꺼진 것으로 봅니다.`);
  if (ci.enabled === true && !ci.steps.length) notes.push('ci.enabled가 true인데 ci.steps가 비어 있어 검사 단계를 건너뜁니다. node tools/agentic/ci.mjs suggest 로 제안을 보세요.');
  if (runner !== String(ci.runner)) notes.push(`ci.runner 값(${ci.runner})을 쓸 수 없어 ubuntu-latest로 실행합니다.`);
  if (node !== String(ci.node)) notes.push(`ci.node 값(${ci.node})을 쓸 수 없어 22로 실행합니다 (예: "22", "24", "lts/*").`);
  if (timeout !== ci.timeoutMinutes) notes.push(`ci.timeoutMinutes 값(${JSON.stringify(ci.timeoutMinutes)})은 1~360 사이 정수여야 해서 20분으로 실행합니다.`);
  return { enabled, runner, node, timeout, steps: ci.steps.length, notes };
}

export function runSteps(root, steps, { log = console.log } = {}) {
  const results = [];
  for (const [i, step] of steps.entries()) {
    const name = step.name || `단계 ${i + 1}`;
    const cwd = step.workingDirectory ? join(root, step.workingDirectory) : root;
    if (inActions()) log(`::group::${name}`); else log(`\n▶ ${name}: ${step.run}`);
    const started = Date.now();
    const r = spawnSync('bash', ['-eo', 'pipefail', '-c', step.run], {
      cwd, stdio: 'inherit', env: { ...process.env, ...(step.env || {}) },
    });
    const ok = r.status === 0;
    const secs = ((Date.now() - started) / 1000).toFixed(1);
    if (inActions()) log('::endgroup::');
    results.push({ name, ok, secs, code: r.status ?? (r.error ? 127 : 1) });
    if (!ok) {
      log(inActions() ? `::error title=agentic-ci::${esc(`${name} 실패 (종료 코드 ${r.status ?? r.error?.message})`)}` : `✘ ${name} 실패 (종료 코드 ${r.status ?? r.error?.message})`);
      if (!step.continueOnError) break;
    }
  }
  return results;
}

// ---------------------------------------------------------------------------------------------
// 제안: 프로젝트 파일을 보고 ci 설정을 만든다. 확신할 수 없는 것은 후보로만 보여 준다.
const PLACEHOLDER_RE = /^\(예:/;

export function suggest(root) {
  const steps = [];
  const hints = [];
  let runner = 'ubuntu-latest';

  const pkgPath = join(root, 'package.json');
  if (existsSync(pkgPath)) {
    let pkg = {};
    try { pkg = JSON.parse(readFileSync(pkgPath, 'utf8')); } catch { hints.push('package.json을 읽지 못했습니다'); }
    const scripts = pkg.scripts || {};
    const install = existsSync(join(root, 'package-lock.json')) || existsSync(join(root, 'npm-shrinkwrap.json')) ? 'npm ci'
      : existsSync(join(root, 'pnpm-lock.yaml')) ? 'corepack pnpm install --frozen-lockfile'
      : existsSync(join(root, 'yarn.lock')) ? `corepack yarn install ${existsSync(join(root, '.yarnrc.yml')) || /^yarn@[2-9]/.test(pkg.packageManager || '') ? '--immutable' : '--frozen-lockfile'}`
      : 'npm install';
    const pm = install.includes('pnpm') ? 'pnpm' : install.includes('yarn') ? 'yarn' : 'npm';
    const runScript = (s) => (pm === 'npm' ? (s === 'test' ? 'npm test' : `npm run ${s}`) : `corepack ${pm} ${s}`);
    steps.push({ name: '설치', run: install });
    if (pm !== 'npm') hints.push('pnpm·yarn은 Node에 들어 있는 corepack으로 실행합니다. Node 25 이상은 corepack이 빠져 있으니 ci.node를 올리면 설치 앞에 { "name": "corepack", "run": "npm i -g corepack" }을 넣으세요.');
    for (const s of ['lint', 'typecheck']) if (scripts[s]) steps.push({ name: s === 'lint' ? '린트' : '타입체크', run: runScript(s) });
    if (scripts.test && !/no test specified/.test(scripts.test)) steps.push({ name: '테스트', run: runScript('test') });
    if (scripts.build) hints.push(`build 스크립트가 있습니다. 빌드에 비밀값이 필요 없으면 { "name": "빌드", "run": "${runScript('build')}" }를 더하세요.`);
    if (steps.length === 1) { steps.length = 0; hints.push('package.json에 test·lint·typecheck 스크립트가 없어 Node 단계를 만들지 않았습니다.'); }
  }

  if (existsSync(join(root, 'Package.swift'))) {
    runner = 'macos-latest';
    steps.push({ name: 'Swift 테스트', run: 'swift test' });
    hints.push('Swift 패키지는 macOS 러너에서 돕니다. 비공개 저장소에서 macOS 러너는 GitHub Actions 사용 시간을 Linux의 10배로 셉니다.');
  }
  let entries = [];
  try { entries = readdirSync(root); } catch { /* 없음 */ }
  if (entries.some((n) => n.endsWith('.xcodeproj') || n.endsWith('.xcworkspace'))) {
    runner = 'macos-latest';
    hints.push('Xcode 프로젝트가 있습니다. xcodebuild 테스트는 시뮬레이터 이름이 러너 이미지에 맞아야 해서 자동으로 넣지 않았습니다. AGENTS.md 테스트 명령을 확인해 직접 추가하세요.');
  }
  if (existsSync(join(root, 'project.godot'))) hints.push('Godot 프로젝트입니다. 러너에 Godot을 설치하는 단계(예: 공식 릴리스 내려받기)를 테스트 앞에 직접 넣어야 합니다.');

  // AGENTS.md "## 프로젝트" 절의 테스트·린트 명령 (예시 문구가 아니면 후보로 보여 준다)
  const agents = existsSync(join(root, 'AGENTS.md')) ? readFileSync(join(root, 'AGENTS.md'), 'utf8') : '';
  const candidates = [];
  for (const label of ['테스트', '린트·타입체크']) {
    const line = agents.split('\n').find((l) => l.startsWith(`- ${label}:`));
    if (!line) continue;
    // 명령처럼 보이는 것만 (띄어쓰기가 없는 `@cloudflare/vitest-pool-workers` 같은 이름은 뺀다)
    for (const m of line.matchAll(/`([^`]+)`/g)) if (!PLACEHOLDER_RE.test(m[1]) && /\s/.test(m[1].trim())) candidates.push({ label, run: m[1] });
  }
  const known = new Set(steps.map((s) => s.run));
  const extra = candidates.filter((c) => !known.has(c.run));

  return { ci: { enabled: steps.length > 0, runner, steps }, hints, candidates: extra };
}

// 제안을 기존 설정에 합친다. 사용자가 기본값이 아닌 러너를 골랐으면 그대로 둔다.
export function mergeSuggestion(existing, suggested) {
  const runner = existing.runner !== CI_DEFAULTS.runner ? existing.runner : suggested.runner;
  return { ...existing, ...suggested, runner };
}

// ---------------------------------------------------------------------------------------------
function main() {
  const [cmd, ...args] = process.argv.slice(2);
  const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
  const config = loadConfig(ROOT);

  if (cmd === 'guard') {
    const ci = ciConfig(config);
    if (!ci.secretScan.enabled) { console.log('비밀값 검사 꺼짐 (ci.secretScan.enabled = false)'); return 0; }
    let findings;
    try { findings = scanSecrets(ROOT, { ignore: ci.secretScan.ignore, requireGit: inActions() }); }
    catch (e) { console.log(inActions() ? `::error title=agentic-ci::${esc(e.message)}` : `✘ ${e.message}`); return 1; }
    findings.forEach(annotate);
    const errors = findings.filter((f) => f.severity === 'error');
    const warns = findings.length - errors.length;
    const line = errors.length ? `✘ 비밀값 의심 ${errors.length}건${warns ? `, 확인 필요 ${warns}건` : ''}` : warns ? `! 확인 필요 ${warns}건 (실패 아님)` : '✔ 비밀값·.env 커밋 없음';
    console.log(line);
    summary(`### agentic-ci 비밀값 검사\n${line}\n${findings.length ? `\n| 파일 | 줄 | 규칙 | 등급 |\n|---|---|---|---|\n${findings.map((f) => `| \`${f.file}\` | ${f.line} | ${f.rule} | ${f.severity} |`).join('\n')}\n` : ''}` +
      (findings.length ? `\n오탐이면 그 줄에 \`${ALLOW_MARK}\` 주석을 달거나 \`.agentic/config.json\`의 \`ci.secretScan.ignore\`에 경로를 넣으세요.\n` : ''));
    return errors.length ? 1 : 0;
  }

  if (cmd === 'plan') {
    const p = plan(config);
    const out = [`enabled=${p.enabled}`, `runner=${p.runner}`, `node=${p.node}`, `timeout=${p.timeout}`];
    if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, out.join('\n') + '\n');
    else console.log(out.join('\n'));
    for (const n of p.notes) console.log(inActions() ? `::warning title=agentic-ci::${esc(n)}` : `! ${n}`);
    const desc = p.enabled ? `검사 ${p.steps}단계를 ${p.runner}에서 실행` : '비밀값 검사만 실행 (프로젝트 검사 꺼짐 — 켜려면 node tools/agentic/ci.mjs suggest)';
    console.error(desc);
    summary(`### agentic-ci\n${desc}\n`);
    return 0;
  }

  if (cmd === 'run') {
    const ci = ciConfig(config);
    if (!ci.steps.length) { console.log('ci.steps가 비어 있습니다. node tools/agentic/ci.mjs suggest 로 제안을 보세요.'); return 0; }
    const results = runSteps(ROOT, ci.steps);
    const failed = results.some((r) => !r.ok);
    summary(`### agentic-ci 검사\n| 단계 | 결과 | 시간 |\n|---|---|---|\n${results.map((r) => `| ${r.name} | ${r.ok ? '✔' : `✘ (${r.code})`} | ${r.secs}s |`).join('\n')}\n`);
    console.log(`\n${failed ? '✘ 실패' : '✔ 모든 단계 통과'}: ${results.map((r) => `${r.name} ${r.ok ? '✔' : '✘'}`).join(', ')}`);
    return failed ? 1 : 0;
  }

  if (cmd === 'suggest') {
    const s = suggest(ROOT);
    const current = ciConfig(config);
    const merged = mergeSuggestion(current, s.ci);
    console.log(`현재: ${current.enabled ? `켜짐 (${current.steps.length}단계, ${current.runner})` : '꺼짐 (비밀값 검사만)'}\n`);
    if (s.ci.steps.length) {
      console.log(`제안하는 .agentic/config.json "ci":\n${JSON.stringify(merged, null, 2)}`);
      if (merged.runner !== s.ci.runner) console.log(`\n! 지금 설정한 러너(${merged.runner})를 유지합니다. 제안 러너는 ${s.ci.runner}입니다 — 바꾸려면 ci.runner를 직접 고치세요.`);
    } else {
      console.log('자동으로 만들 수 있는 검사 단계가 없습니다.');
    }
    if (s.candidates.length) console.log(`\nAGENTS.md에 적힌 명령 (필요하면 steps에 직접 추가):\n${s.candidates.map((c) => `  - ${c.label}: ${c.run}`).join('\n')}`);
    if (s.hints.length) console.log(`\n참고:\n${s.hints.map((h) => `  - ${h}`).join('\n')}`);
    if (args.includes('--write')) {
      if (!s.ci.steps.length) { console.log('\n저장할 단계가 없어 config.json을 바꾸지 않았습니다.'); return 1; }
      const cfgPath = join(ROOT, '.agentic', 'config.json');
      let cur;
      try { cur = JSON.parse(readFileSync(cfgPath, 'utf8')); } catch (e) { console.error(`config.json을 읽지 못했습니다: ${e.message}`); return 1; }
      const existing = ciConfig(cur);
      if (existing.steps.length && !args.includes('--force')) {
        console.log(`\n이미 ci.steps가 ${existing.steps.length}개 있어 바꾸지 않았습니다. 제안으로 바꾸려면 --write --force (지금 단계는 사라집니다).`);
        return 1;
      }
      cur.ci = mergeSuggestion(existing, s.ci);
      writeFileSync(cfgPath, JSON.stringify(cur, null, 2) + '\n');
      console.log(`\n저장했습니다: ${relative(process.cwd(), cfgPath) || cfgPath}. 로컬 확인: node tools/agentic/ci.mjs run`);
    } else if (s.ci.steps.length) console.log('\n이대로 켜려면: node tools/agentic/ci.mjs suggest --write');
    return 0;
  }

  console.log(`사용: node tools/agentic/ci.mjs <guard|plan|run|suggest [--write [--force]]>`);
  return cmd ? 2 : 0;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) process.exit(main());
