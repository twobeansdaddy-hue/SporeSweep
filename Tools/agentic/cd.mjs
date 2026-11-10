#!/usr/bin/env node
// 배포 도우미 (CD). 설정은 .agentic/config.json의 "cd" 항목이고 기본은 꺼짐이다.
//
//   node tools/agentic/cd.mjs plan                       (기본) 설정 검사 + 무엇을 어디에 어떤 명령으로 올리는지 출력. 밖으로 아무것도 보내지 않는다
//   node tools/agentic/cd.mjs deploy [--yes]             --yes가 없으면 plan과 같다. 있으면 실제로 올리고 확인한다
//   node tools/agentic/cd.mjs verify                     올린 주소만 확인한다 (GET 요청만)
//   node tools/agentic/cd.mjs rollback [--tag T] [--yes] docker-ssh: 직전에 성공한 태그(또는 T)로 되돌린다
//   node tools/agentic/cd.mjs actions-plan               .github/workflows/agentic-cd.yml이 부른다 (GitHub Actions 출력)
//
// 대상 두 가지:
//   pages      — Cloudflare Pages 정적 사이트. 로컬과 GitHub Actions(수동 실행) 모두에서 된다.
//   docker-ssh — 로컬에서 이미지를 빌드해 SSH로 서버에 옮기고 docker compose로 띄운다. 로컬에서만 된다
//                (SSH 키·사설망 인증을 GitHub에 두지 않는다). 서버에서 빌드하지 않는다.
// 배포는 밖으로 나가는 일이라 에이전트는 plan을 사용자에게 보이고 승인을 받은 뒤에만 --yes를 붙인다 (PIPELINE 승인 지점 5).
// 토큰 값은 출력·기록하지 않는다. 기록은 .agentic/logs/deploys.jsonl (gitignore 대상).
import { existsSync, readFileSync, statSync, readdirSync, appendFileSync, mkdirSync } from 'node:fs';
import { join, dirname, basename, isAbsolute } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { findRoot, loadConfig, loadEnv } from './lib.mjs';
import { runSteps, scanDir } from './ci.mjs';

export const CD_DEFAULTS = {
  enabled: false,
  target: '',
  pages: { project: '', dir: '', branch: 'main', wrangler: '4.151.3', node: '22', build: [], required: ['index.html'], verifyUrl: '', verifyPaths: ['/'] },
  dockerSsh: {
    host: '', identityFile: '', remoteDir: '', composeProject: '',
    image: '', dockerfile: 'Dockerfile', context: '.', platform: 'linux/amd64', buildArgs: {},
    files: [], remoteHealthUrl: '', healthUrl: '',
  },
  verify: { attempts: 6, delaySeconds: 10 },
};
// Cloudflare Pages 한도 (무료 플랜): 파일 하나 25 MiB, 파일 20,000개
export const PAGES_MAX_FILE = 25 * 1024 * 1024;
export const PAGES_MAX_FILES = 20000;

const obj = (x) => (x && typeof x === 'object' && !Array.isArray(x) ? x : {});
export function cdConfig(config) {
  const c = obj(config?.cd);
  return {
    ...CD_DEFAULTS, ...c,
    pages: { ...CD_DEFAULTS.pages, ...obj(c.pages) },
    dockerSsh: { ...CD_DEFAULTS.dockerSsh, ...obj(c.dockerSsh) },
    verify: { ...CD_DEFAULTS.verify, ...obj(c.verify) },
  };
}

// 셸에 넘길 때 따옴표로 감싼다 (안전한 글자만 있으면 그대로).
export const q = (s) => (/^[\w@%+=:,./-]+$/.test(String(s)) ? String(s) : `'${String(s).replace(/'/g, `'\\''`)}'`);
const relOk = (p) => typeof p === 'string' && p.trim() !== '' && !isAbsolute(p) && !p.split(/[\\/]/).includes('..');
const urlOk = (u) => /^https?:\/\/[^\s'"]+$/.test(u);
const SEG = /^[A-Za-z0-9._-]+$/;

// 원격 폴더는 프로젝트 전용 폴더만: /opt/<이름>…, /srv/<이름>…, /home/<사용자>/<이름>…
// 공용 서버에서 다른 서비스 폴더나 시스템 폴더를 건드리지 않게 한다.
export function remoteDirError(d) {
  if (typeof d !== 'string' || !d.startsWith('/')) return '절대 경로여야 합니다 (예: /opt/<프로젝트>)';
  const segs = d.replace(/\/+$/, '').split('/').slice(1);
  if (segs.some((s) => !SEG.test(s) || s === '.' || s === '..')) return '영문·숫자·._- 로 된 경로만 쓸 수 있습니다';
  const min = segs[0] === 'home' ? 3 : 2;
  if (!['opt', 'srv', 'home'].includes(segs[0]) || segs.length < min) return '/opt/<이름>, /srv/<이름>, /home/<사용자>/<이름> 아래의 프로젝트 전용 폴더만 쓸 수 있습니다';
  return '';
}

export function normFiles(files) {
  return (Array.isArray(files) ? files : []).map((f) => (typeof f === 'string' ? { from: f, to: basename(f) } : { from: f?.from, to: f?.to ?? (typeof f?.from === 'string' ? basename(f.from) : undefined) }));
}
const isCompose = (to) => /(^|\/)(docker-)?compose(\.[\w-]+)?\.ya?ml$/.test(to);

// compose 파일에서 이 이미지를 쓰는 서비스가 모두 ${IMAGE_TAG} 태그를 쓰는지. 주석(#…)은 빼고 실제 image 키만 본다.
// 블록 형식(image: x), 따옴표 키("image": x), 한 줄 형식({image: x})을 모두 찾는다.
// 같은 이미지의 다이제스트 고정(myapp@sha256:…)도 고정으로 본다.
// (YAML 전체를 해석하지 않는 근사: 따옴표 안의 #, 여러 줄 값은 드물어 무시)
const IMAGE_KEY = /(?:^|[\s{,])["']?image["']?\s*:\s*["']?((?:\$\{[^}]*\}|[^"'\s,}])+)/g;
export function composeImageError(text, image) {
  const esc = image.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
  const lines = text.split('\n').map((l) => l.replace(/(^|\s)#.*$/, '')).flatMap((l) => [...l.matchAll(IMAGE_KEY)].map((m) => m[1]));
  const mine = lines.filter((v) => new RegExp(`^${esc}(?::|@|$)`).test(v));
  if (!mine.length) return `image: ${image}:\${IMAGE_TAG} 를 쓰는 서비스가 없습니다. 배포한 태그로 뜨도록 compose 파일을 고치세요`;
  const fixed = mine.filter((v) => !new RegExp(`^${esc}:\\$\\{IMAGE_TAG(?::?-[^}]*)?\\}$`).test(v));
  return fixed.length ? `${fixed.join(', ')} 은 고정 태그입니다. ${image}:\${IMAGE_TAG} 로 바꾸세요` : '';
}

// 설정 검사. errors가 있으면 배포하지 않는다.
export function validate(cd, root) {
  const errors = [], notes = [];
  if (cd.enabled !== true) notes.push('cd.enabled가 true가 아니라 꺼져 있습니다.');
  if (!['pages', 'docker-ssh'].includes(cd.target)) { errors.push(`cd.target은 "pages" 또는 "docker-ssh"여야 합니다 (지금: ${JSON.stringify(cd.target)})`); return { errors, notes }; }
  const v = cd.verify;
  if (!Number.isInteger(v.attempts) || v.attempts < 1 || v.attempts > 30) errors.push('cd.verify.attempts는 1~30 정수여야 합니다');
  if (!(typeof v.delaySeconds === 'number' && v.delaySeconds >= 0 && v.delaySeconds <= 120)) errors.push('cd.verify.delaySeconds는 0~120이어야 합니다');

  if (cd.target === 'pages') {
    const p = cd.pages;
    if (!/^[a-z0-9][a-z0-9-]{0,57}$/.test(p.project)) errors.push('cd.pages.project: Pages 프로젝트 이름(소문자·숫자·-)이 필요합니다');
    if (!relOk(p.dir)) errors.push('cd.pages.dir: 올릴 폴더를 저장소 기준 상대 경로로 적으세요 (.. 불가)');
    if (typeof p.branch !== 'string' || !/^[\w./-]+$/.test(p.branch) || p.branch.startsWith('-')) errors.push('cd.pages.branch 값이 올바르지 않습니다');
    if (!/^\d+\.\d+\.\d+$/.test(p.wrangler)) errors.push('cd.pages.wrangler는 고정 판 번호여야 합니다 (예: 4.151.3)');
    if (!/^[\w.*/-]+$/.test(String(p.node))) errors.push('cd.pages.node 값이 올바르지 않습니다 (예: "22")');
    if (!Array.isArray(p.build) || p.build.some((s) => !s || typeof s.run !== 'string' || !s.run.trim())) errors.push('cd.pages.build는 { "name", "run" } 단계 목록이어야 합니다');
    if (!Array.isArray(p.required) || p.required.some((r) => !relOk(r))) errors.push('cd.pages.required는 올릴 폴더 기준 상대 경로 목록이어야 합니다');
    if (p.verifyUrl && !urlOk(p.verifyUrl)) errors.push('cd.pages.verifyUrl은 http(s) 주소여야 합니다');
    if (!Array.isArray(p.verifyPaths) || p.verifyPaths.some((x) => typeof x !== 'string' || !x.startsWith('/'))) errors.push('cd.pages.verifyPaths는 /로 시작하는 경로 목록이어야 합니다');
    if (Array.isArray(p.build) && !p.build.length) notes.push('cd.pages.build가 비어 있어 빌드 없이 지금 폴더를 그대로 올립니다.');
  }

  if (cd.target === 'docker-ssh') {
    const d = cd.dockerSsh;
    if (!/^[A-Za-z0-9_][\w.@-]*$/.test(d.host)) errors.push('cd.dockerSsh.host: SSH 접속 대상이 필요합니다 (예: ubuntu@my-server, -로 시작 불가)');
    if (d.identityFile && (typeof d.identityFile !== 'string' || /[\n\r]/.test(d.identityFile) || d.identityFile.startsWith('-'))) errors.push('cd.dockerSsh.identityFile 값이 올바르지 않습니다');
    const rd = remoteDirError(d.remoteDir);
    if (rd) errors.push(`cd.dockerSsh.remoteDir: ${rd}`);
    if (d.composeProject && !/^[a-z0-9][a-z0-9_-]*$/.test(d.composeProject)) errors.push('cd.dockerSsh.composeProject는 소문자·숫자·_- 이름이어야 합니다');
    if (!/^[a-z0-9][a-z0-9._/-]*$/.test(d.image)) errors.push('cd.dockerSsh.image: 이미지 이름(소문자)이 필요합니다 (태그는 커밋으로 자동)');
    for (const k of ['dockerfile', 'context']) if (!relOk(d[k])) errors.push(`cd.dockerSsh.${k}는 저장소 기준 상대 경로여야 합니다`);
    if (relOk(d.dockerfile) && root && !existsSync(join(root, d.dockerfile))) errors.push(`cd.dockerSsh.dockerfile 파일이 없습니다: ${d.dockerfile}`);
    if (!/^[\w./-]+$/.test(d.platform)) errors.push('cd.dockerSsh.platform 값이 올바르지 않습니다 (예: linux/amd64)');
    for (const [k, val] of Object.entries(obj(d.buildArgs))) if (!/^[A-Za-z_]\w*$/.test(k) || typeof val !== 'string') errors.push(`cd.dockerSsh.buildArgs.${k}: 이름은 영문·숫자·_, 값은 문자열이어야 합니다`);
    const files = normFiles(d.files);
    if (!files.length) errors.push('cd.dockerSsh.files: 서버로 옮길 compose 파일 등을 적으세요');
    for (const f of files) {
      if (!relOk(f.from) || !relOk(f.to)) { errors.push(`cd.dockerSsh.files: 상대 경로만 쓸 수 있습니다 (${JSON.stringify(f)})`); continue; }
      if (root && !existsSync(join(root, f.from))) errors.push(`cd.dockerSsh.files: 파일이 없습니다: ${f.from}`);
    }
    const compose = files.find((f) => relOk(f.to) && isCompose(f.to));
    if (!compose) errors.push('cd.dockerSsh.files에 compose 파일(docker-compose.yml 등)이 없습니다. 원격 폴더 바로 아래로 옮겨야 합니다');
    else if (compose.to.includes('/')) errors.push(`compose 파일은 원격 폴더 바로 아래로 옮겨야 합니다 (지금: ${compose.to})`);
    else if (root && existsSync(join(root, compose.from)) && typeof d.image === 'string') {
      // 고정 태그(app:latest 등)면 새 이미지를 쓰지 않고도 예전 컨테이너가 응답해 성공으로 기록될 수 있어 막는다.
      const bad = composeImageError(readFileSync(join(root, compose.from), 'utf8'), d.image);
      if (bad) errors.push(`${compose.from}: ${bad}`);
    }
    for (const k of ['remoteHealthUrl', 'healthUrl']) if (d[k] && !urlOk(d[k])) errors.push(`cd.dockerSsh.${k}는 http(s) 주소여야 합니다`);
    if (!d.remoteHealthUrl && !d.healthUrl) notes.push('확인 주소(remoteHealthUrl·healthUrl)가 없어 배포 뒤 확인을 하지 않습니다.');
  }
  return { errors, notes };
}

// ~/로 시작하는 키 경로는 직접 펼친다 (따옴표로 감싸면 셸이 펼치지 않음). BatchMode: 암호·호스트 키 질문에 멈추지 않고 실패한다.
const idArgs = (d) => (d.identityFile ? ['-i', d.identityFile.startsWith('~/') ? join(homedir(), d.identityFile.slice(2)) : d.identityFile] : []);
const sshBase = (d) => ['ssh', ...idArgs(d), '-o', 'BatchMode=yes', d.host].map(q).join(' ');
const scpBase = (d) => ['scp', ...idArgs(d), '-o', 'BatchMode=yes'].map(q).join(' ');
export const composeProject = (d) => d.composeProject || basename(d.remoteDir.replace(/\/+$/, '')).toLowerCase().replace(/[^a-z0-9_-]/g, '-');

// 설정에서 고른 compose 파일 (원격 폴더 바로 아래 이름). 검사한 그 파일만 -f로 쓴다.
export const composeFile = (d) => normFiles(d.files).find((f) => typeof f.to === 'string' && isCompose(f.to))?.to;

// 원격에서 compose로 띄우고(선택) 서버 안에서 확인하는 단계. deploy와 rollback이 같이 쓴다.
export const UP_STEP = '컨테이너 올리기';
// 배포마다 옮긴 설정 파일의 사본을 남기는 원격 폴더 (rollback이 태그와 함께 설정도 되돌리게)
export const SNAP_DIR = '.agentic-deploys';
function upSteps(d, tag, compose = composeFile(d)) {
  const dir = d.remoteDir.replace(/\/+$/, '');
  const steps = [{ name: UP_STEP, run: `${sshBase(d)} ${q(`cd ${q(dir)} && IMAGE_TAG=${q(tag)} docker compose -f ${q(compose)} -p ${q(composeProject(d))} up -d --no-build`)}` }];
  if (d.remoteHealthUrl) steps.push({ name: '서버 안 확인', run: `${sshBase(d)} ${q(`curl -fsS -o /dev/null --retry 5 --retry-connrefused --retry-delay 2 ${q(d.remoteHealthUrl)}`)}` });
  return steps;
}

// 되돌리기: 그 태그로 배포할 때 남긴 설정 사본을 복원한 뒤 띄운다. 사본이 없으면(test -d 실패) 아무것도 바꾸지 않고 멈춘다.
export function rollbackSteps(d, tag, compose = composeFile(d)) {
  const dir = d.remoteDir.replace(/\/+$/, '');
  return [{ name: '설정 되돌리기', run: `${sshBase(d)} ${q(`cd ${q(dir)} && test -d ${q(`${SNAP_DIR}/${tag}`)} && cp -R ${q(`${SNAP_DIR}/${tag}`)}/. .`)}` }, ...upSteps(d, tag, compose)];
}

export function dockerSshSteps(d, tag) {
  const dir = d.remoteDir.replace(/\/+$/, '');
  const files = normFiles(d.files);
  const ref = `${d.image}:${tag}`;
  const args = Object.entries(obj(d.buildArgs)).map(([k, v]) => `--build-arg ${q(`${k}=${v}`)}`);
  const dirs = [...new Set([dir, ...files.map((f) => dirname(f.to)).filter((x) => x !== '.').map((x) => `${dir}/${x}`)])];
  return [
    { name: '이미지 빌드', run: ['docker build --platform', q(d.platform), '-f', q(d.dockerfile), ...args, '-t', q(ref), q(d.context)].join(' ') },
    { name: '원격 폴더 준비', run: `${sshBase(d)} ${q(`mkdir -p ${dirs.map(q).join(' ')}`)}` },
    ...files.map((f) => ({ name: `파일 복사 ${f.to}`, run: `${scpBase(d)} ${q(f.from)} ${q(`${d.host}:${dir}/${f.to}`)}` })),
    { name: '설정 사본 보관', run: `${sshBase(d)} ${q(`cd ${q(dir)} && ${files.map((f) => `mkdir -p ${q(`${SNAP_DIR}/${tag}/${dirname(f.to)}`)} && cp ${q(f.to)} ${q(`${SNAP_DIR}/${tag}/${f.to}`)}`).join(' && ')}`)}` },
    { name: '이미지 전송', run: `docker save ${q(ref)} | gzip | ${sshBase(d)} ${q('gunzip | docker load')}` },
    ...upSteps(d, tag),
  ];
}

const wranglerCmd = (p, ...args) => ['npx', '--yes', `wrangler@${p.wrangler}`, ...args, '--env-file', '/dev/null'].map(q).join(' ');
export function pagesDeployCmd(p, { commit, dirty }) {
  return wranglerCmd(p, 'pages', 'deploy', p.dir, `--project-name=${p.project}`, `--branch=${p.branch}`,
    ...(commit ? [`--commit-hash=${commit}`] : []), ...(dirty ? ['--commit-dirty=true'] : []));
}
export const pagesUrls = (p) => {
  const base = (p.verifyUrl || `https://${p.project}.pages.dev`).replace(/\/+$/, '');
  return p.verifyPaths.map((x) => base + x);
};

// wrangler에 넘길 환경. .env의 CLOUDFLARE_API_TOKEN은 다른 도구(판정 모델)용일 수 있어 넘기지 않고,
// Pages 전용 토큰(CLOUDFLARE_PAGES_API_TOKEN)이 있을 때만 그 값을 wrangler가 읽는 이름으로 넘긴다. 없으면 wrangler 로그인을 쓴다.
export function wranglerEnv(env) {
  const out = { ...env };
  delete out.CLOUDFLARE_API_TOKEN; delete out.CLOUDFLARE_ACCOUNT_ID;
  const token = env.CLOUDFLARE_PAGES_API_TOKEN;
  const account = env.CLOUDFLARE_PAGES_ACCOUNT_ID || env.CLOUDFLARE_ACCOUNT_ID;
  if (token) out.CLOUDFLARE_API_TOKEN = token;
  // 계정은 토큰과 따로 고른다: wrangler 로그인이 여러 계정에 닿아도 지정한 계정으로만 올리게
  if (account) out.CLOUDFLARE_ACCOUNT_ID = account;
  return { env: out, auth: token ? 'Pages 토큰(CLOUDFLARE_PAGES_API_TOKEN)' : 'wrangler 로그인 (npx wrangler login)' };
}

// wrangler pages deploy 출력에서 이번 배포 주소를 꺼낸다 (예: https://1a2b3c4d.<프로젝트>.pages.dev, "Take a peek over at <주소>").
export function deploymentUrl(text, project) {
  const esc = project.replace(/[-]/g, '\\-');
  const own = text.match(new RegExp(`https://[\\w-]+\\.${esc}\\.pages\\.dev\\b`));
  if (own) return own[0];
  return text.match(/Take a peek over at (https?:\/\/[^\s'"]+)/)?.[1] ?? null;
}

// 올릴 폴더 점검: 있음, 필수 파일, Pages 한도, .env·키 형식 값.
export function checkPagesDir(root, p) {
  const dir = join(root, p.dir);
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return [`올릴 폴더가 없습니다: ${p.dir} (빌드를 먼저 하세요)`];
  const errors = [];
  for (const r of p.required) if (!existsSync(join(dir, r))) errors.push(`필수 파일이 없습니다: ${p.dir}/${r}`);
  let count = 0;
  (function walk(abs, rel) {
    for (const e of readdirSync(abs, { withFileTypes: true })) {
      const a = join(abs, e.name), r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(a, r);
      else if (e.isFile()) { count++; if (statSync(a).size > PAGES_MAX_FILE) errors.push(`25MiB를 넘는 파일: ${r}`); }
    }
  })(dir, '');
  if (count > PAGES_MAX_FILES) errors.push(`파일이 ${count}개로 Pages 한도(${PAGES_MAX_FILES}개)를 넘습니다`);
  for (const f of scanDir(dir).filter((x) => x.severity === 'error')) errors.push(`비밀값 의심: ${p.dir}/${f.file}:${f.line} ${f.message}`);
  return errors;
}

// 배포 기록
const logPath = (root) => join(root, '.agentic', 'logs', 'deploys.jsonl');
export function readDeploys(root) {
  if (!existsSync(logPath(root))) return [];
  return readFileSync(logPath(root), 'utf8').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
}
function logDeploy(root, entry) {
  mkdirSync(dirname(logPath(root)), { recursive: true });
  appendFileSync(logPath(root), JSON.stringify({ at: new Date().toISOString(), ...entry }) + '\n');
}

// 되돌릴 태그. current: 서버에 마지막으로 올라간 태그 (compose up을 시도했으면 실패·부분 교체·확인 실패여도 포함 — applied),
// prev: current가 아닌, 확인까지 성공한(ok) 가장 최근 태그. 예전 기록(applied 없음)은 ok를 적용된 것으로 본다.
export function rollbackTag(deploys, d) {
  const mine = deploys.filter((x) => x.target === 'docker-ssh' && x.host === d.host && x.remoteDir === d.remoteDir && x.tag);
  const current = [...mine].reverse().find((x) => x.applied ?? x.ok)?.tag;
  const prev = [...mine].reverse().find((x) => x.ok && x.tag !== current)?.tag;
  return { current, prev };
}

const gitOut = (root, ...a) => spawnSync('git', ['-C', root, ...a], { encoding: 'utf8' });
function commitInfo(root) {
  const r = gitOut(root, 'rev-parse', '--short', 'HEAD');
  return { commit: r.status === 0 ? r.stdout.trim() : '', dirty: Boolean(gitOut(root, 'status', '--porcelain').stdout.trim()) };
}

async function verifyUrls(urls, { attempts, delaySeconds }, log = console.log) {
  const results = [];
  for (const url of urls) {
    let status = null, err = '';
    for (let i = 1; i <= attempts; i++) {
      try { status = (await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(15000) })).status; err = ''; } catch (e) { status = null; err = e.cause?.code || e.message; }
      if (status === 200) break;
      if (i < attempts) await new Promise((r) => setTimeout(r, delaySeconds * 1000));
    }
    log(`${status === 200 ? '✔' : '✘'} ${url}  ${status ?? err}`);
    results.push({ url, ok: status === 200, status });
  }
  return results;
}

function printPlan(cd, root, { commit, dirty }, log) {
  if (cd.target === 'pages') {
    const p = cd.pages;
    log(`대상: Cloudflare Pages 프로젝트 ${p.project} (브랜치 ${p.branch})${dirty ? '  ! 커밋 안 한 수정 포함' : ''}`);
    for (const s of p.build) log(`  빌드  ${s.name || ''}: ${s.run}`);
    log(`  점검  ${p.dir}: 필수 파일 ${p.required.join(', ') || '없음'}, Pages 한도, .env·비밀값`);
    log(`  확인  ${wranglerCmd(p, 'pages', 'project', 'list', '--json')}  (프로젝트가 없으면 멈춤 — 대시보드에서 먼저 만드세요)`);
    log(`  올림  ${pagesDeployCmd(p, { commit, dirty })}`);
    log(`  확인  ${pagesUrls(p).join(', ')}`);
    log(`  권한  ${wranglerEnv(process.env).auth}`);
  } else {
    const d = cd.dockerSsh;
    log(`대상: ${d.host}:${d.remoteDir} (compose 프로젝트 ${composeProject(d)}), 이미지 ${d.image}:${commit || '<커밋>'}`);
    if (dirty) log('  ! 커밋 안 한 수정이 있어 deploy는 거부됩니다 (태그가 커밋을 가리켜야 함)');
    for (const s of dockerSshSteps(d, commit || '<커밋>')) log(`  ${s.name}: ${s.run}`);
    if (d.healthUrl) log(`  확인: ${d.healthUrl}`);
    const { current, prev } = rollbackTag(readDeploys(root), d);
    if (current) log(`  최근 배포 태그 ${current}${prev ? `, 되돌릴 태그 ${prev}` : ''}`);
  }
}

export async function main(argv = process.argv.slice(2), { log = console.log, root } = {}) {
  const [cmd = 'plan', ...args] = argv;
  const ROOT = root ?? findRoot(dirname(fileURLToPath(import.meta.url)));
  const cd = cdConfig(loadConfig(ROOT));
  const inActions = process.env.GITHUB_ACTIONS === 'true';

  if (cmd === 'actions-plan') {
    const { errors } = validate(cd, ROOT);
    const enabled = cd.enabled === true && cd.target === 'pages' && !errors.length;
    const out = [`enabled=${enabled}`, `node=${/^[\w.*/-]+$/.test(String(cd.pages.node)) ? cd.pages.node : '22'}`];
    if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, out.join('\n') + '\n'); else log(out.join('\n'));
    if (!enabled) {
      const why = cd.enabled !== true ? 'cd.enabled가 꺼져 있습니다' : cd.target !== 'pages' ? `GitHub Actions 배포는 pages 대상만 지원합니다 (지금: ${cd.target || '없음'}). docker-ssh는 로컬에서 cd.mjs deploy로 하세요` : `설정 오류: ${errors.join('; ')}`;
      log(inActions ? `::notice title=agentic-cd::배포하지 않음 — ${why}` : `배포하지 않음 — ${why}`);
    }
    return 0;
  }

  if (!['plan', 'deploy', 'verify', 'rollback'].includes(cmd)) {
    log('사용: node tools/agentic/cd.mjs <plan|deploy [--yes]|verify|rollback [--tag T] [--yes]>');
    return 2;
  }
  const { errors, notes } = validate(cd, ROOT);
  if (cd.target === 'pages') loadEnv(ROOT); // 권한 표시와 wrangler 환경에 프로젝트 .env·전역 키 파일을 반영 (값은 출력하지 않음)
  for (const n of notes) log(`! ${n}`);
  if (errors.length) { log(`✘ 설정 오류 (.agentic/config.json "cd"):\n${errors.map((e) => `  - ${e}`).join('\n')}`); return 1; }
  const info = commitInfo(ROOT);

  if (cmd === 'verify') {
    const urls = cd.target === 'pages' ? pagesUrls(cd.pages) : [cd.dockerSsh.healthUrl].filter(Boolean);
    if (!urls.length) { log('확인할 주소가 없습니다 (cd.dockerSsh.healthUrl).'); return 1; }
    return (await verifyUrls(urls, cd.verify, log)).every((r) => r.ok) ? 0 : 1;
  }

  const yes = args.includes('--yes');
  if (cmd === 'plan' || (cmd === 'deploy' && !yes)) {
    printPlan(cd, ROOT, info, log);
    if (cd.enabled !== true) log('\ncd.enabled가 꺼져 있어 deploy는 거부됩니다.');
    log(`\n실제로 올리려면: node tools/agentic/cd.mjs deploy --yes  (밖으로 나가는 일 — 사용자 승인 후)`);
    return 0;
  }
  if (cd.enabled !== true) { log('✘ cd.enabled가 꺼져 있어 배포하지 않습니다.'); return 1; }

  // --- rollback (docker-ssh) ---
  if (cmd === 'rollback') {
    if (cd.target !== 'docker-ssh') { log('✘ rollback은 docker-ssh 대상만 지원합니다. Pages는 대시보드에서 이전 배포로 되돌리세요.'); return 1; }
    if (inActions) { log('✘ docker-ssh는 로컬에서만 실행합니다.'); return 1; }
    const d = cd.dockerSsh;
    const tagArg = args.includes('--tag') ? args[args.indexOf('--tag') + 1] : undefined;
    if (tagArg !== undefined && !/^[\w.-]+$/.test(tagArg)) { log('✘ --tag 값이 올바르지 않습니다.'); return 2; }
    const { current, prev } = rollbackTag(readDeploys(ROOT), d);
    const tag = tagArg ?? prev;
    if (!tag) { log('✘ 되돌릴 태그가 없습니다 (배포 기록에 성공한 다른 태그가 없음). --tag로 지정하세요.'); return 1; }
    const target = [...readDeploys(ROOT)].reverse().find((x) => x.target === 'docker-ssh' && x.host === d.host && x.remoteDir === d.remoteDir && x.tag === tag);
    const usedCompose = target?.composeFile ?? composeFile(d);
    const steps = rollbackSteps(d, tag, usedCompose);
    if (!yes) {
      log(`되돌리기: ${current ?? '?'} → ${tag} (${d.host}:${d.remoteDir})  그 태그의 이미지와 설정 사본(${SNAP_DIR}/${tag})이 서버에 있어야 합니다`);
      for (const s of steps) log(`  ${s.name}: ${s.run}`);
      log('\n실행하려면 --yes (사용자 승인 후)');
      return 0;
    }
    const results = runSteps(ROOT, steps, { log });
    let ok = results.length === steps.length && results.every((r) => r.ok);
    if (ok && d.healthUrl) ok = (await verifyUrls([d.healthUrl], cd.verify, log)).every((r) => r.ok);
    // compose up은 일부 컨테이너만 바꾸고 실패할 수 있으므로, 시도했으면 적용된 것으로 본다 (rollback이 직전 성공 태그로 가게)
    const applied = results.some((r) => r.name === UP_STEP);
    logDeploy(ROOT, { target: 'docker-ssh', host: d.host, remoteDir: d.remoteDir, tag, commit: info.commit, image: target?.image ?? d.image, composeFile: usedCompose, rollbackFrom: current ?? null, applied, ok, failedStep: results.find((r) => !r.ok)?.name ?? (ok ? null : '확인') });
    log(ok ? `\n✔ ${tag}로 되돌렸습니다.` : '\n✘ 되돌리기 실패');
    return ok ? 0 : 1;
  }

  // --- deploy --yes ---
  if (cd.target === 'docker-ssh') {
    const d = cd.dockerSsh;
    if (inActions) { log('✘ docker-ssh는 로컬에서만 실행합니다 (SSH 키·사설망 인증을 GitHub에 두지 않음).'); return 1; }
    if (!info.commit) { log('✘ git 커밋을 알 수 없습니다. 이미지 태그는 커밋 해시를 씁니다.'); return 1; }
    if (info.dirty) { log('✘ 커밋 안 한 수정이 있습니다. 커밋한 뒤 배포하세요 (태그가 실제 코드를 가리키도록).'); return 1; }
    const steps = dockerSshSteps(d, info.commit);
    const results = runSteps(ROOT, steps, { log });
    let ok = results.length === steps.length && results.every((r) => r.ok);
    const failedStep = results.find((r) => !r.ok)?.name ?? null;
    if (ok && d.healthUrl) ok = (await verifyUrls([d.healthUrl], cd.verify, log)).every((r) => r.ok);
    // compose up은 일부 컨테이너만 바꾸고 실패할 수 있으므로, 시도했으면 적용된 것으로 본다 (rollback이 직전 성공 태그로 가게)
    const applied = results.some((r) => r.name === UP_STEP);
    logDeploy(ROOT, { target: 'docker-ssh', host: d.host, remoteDir: d.remoteDir, tag: info.commit, commit: info.commit, image: d.image, composeFile: composeFile(d), applied, ok, failedStep: failedStep ?? (ok ? null : '확인') });
    if (!ok && failedStep === '원격 폴더 준비') log(`  원격 폴더를 만들 권한이 없으면 서버에서 한 번: sudo install -d -o <사용자> ${d.remoteDir}`);
    log(ok ? `\n✔ ${d.image}:${info.commit} 배포 완료` : `\n✘ 배포 실패${failedStep ? ` (${failedStep})` : ' (확인)'}${applied ? ' — 새 컨테이너가 올라간 상태입니다. 되돌리려면: node tools/agentic/cd.mjs rollback (승인 후 --yes)' : ''}`);
    return ok ? 0 : 1;
  }

  // pages
  const p = cd.pages;
  if (inActions) {
    const ref = process.env.GITHUB_REF_NAME;
    if (ref && ref !== p.branch) { log(`✘ ${ref} 브랜치에서는 배포하지 않습니다. cd.pages.branch(${p.branch})에서 실행하세요.`); return 1; }
    if (!process.env.CLOUDFLARE_PAGES_API_TOKEN) { log('✘ GitHub 저장소 비밀값 CLOUDFLARE_PAGES_API_TOKEN이 없습니다 (Settings → Secrets and variables → Actions).'); return 1; }
  }
  const { env, auth } = wranglerEnv(process.env);
  log(`권한: ${auth}`);
  if (p.build.length) {
    const results = runSteps(ROOT, p.build, { log });
    if (!results.every((r) => r.ok) || results.length !== p.build.length) { logDeploy(ROOT, { target: 'pages', project: p.project, commit: info.commit, ok: false, failedStep: '빌드' }); log('\n✘ 빌드 실패'); return 1; }
  }
  const dirErrors = checkPagesDir(ROOT, p);
  if (dirErrors.length) { log(`✘ 올릴 폴더 점검 실패:\n${dirErrors.map((e) => `  - ${e}`).join('\n')}`); logDeploy(ROOT, { target: 'pages', project: p.project, commit: info.commit, ok: false, failedStep: '점검' }); return 1; }
  log(`✔ 점검 통과: ${p.dir}`);
  const list = spawnSync('bash', ['-c', wranglerCmd(p, 'pages', 'project', 'list', '--json')], { cwd: ROOT, env, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  if (list.status !== 0) { log('✘ Pages 프로젝트 목록을 받지 못했습니다. 권한(Pages 토큰 또는 npx wrangler login)을 확인하세요.'); return 1; }
  let projects = [];
  try { projects = JSON.parse(list.stdout.slice(list.stdout.indexOf('['))); } catch { /* 목록 해석 실패는 아래에서 없음으로 처리 */ }
  if (!projects.some((x) => (x['Project Name'] ?? x.name) === p.project)) {
    log(`✘ Pages 프로젝트 ${p.project}가 없습니다. 새 프로젝트는 만들지 않습니다 — Cloudflare 대시보드(Workers & Pages → Pages)에서 프로덕션 브랜치 ${p.branch}로 먼저 만드세요.`);
    return 1;
  }
  // runSteps는 process.env를 다시 합치므로(지운 CLOUDFLARE_API_TOKEN이 되살아남) wrangler는 만든 환경 그대로 실행한다.
  log(`\n▶ Pages 올리기: ${pagesDeployCmd(p, info)}`);
  const dep = spawnSync('bash', ['-eo', 'pipefail', '-c', pagesDeployCmd(p, info)], { cwd: ROOT, env, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (dep.stdout) process.stdout.write(dep.stdout);
  if (dep.stderr) process.stderr.write(dep.stderr);
  if (dep.status !== 0) { logDeploy(ROOT, { target: 'pages', project: p.project, commit: info.commit, ok: false, failedStep: 'Pages 올리기' }); log('\n✘ 배포 실패'); return 1; }
  // 이번에 올린 배포의 주소를 확인한다 (브랜치가 프로덕션이 아니면 verifyUrl은 예전 프로덕션이라 의미가 없음).
  const deployUrl = deploymentUrl(`${dep.stdout ?? ''}\n${dep.stderr ?? ''}`, p.project);
  if (!deployUrl) log(`! wrangler 출력에서 배포 주소를 찾지 못해 ${pagesUrls(p)[0]} 기준으로 확인합니다 (브랜치 ${p.branch}가 프로덕션이 아니면 예전 배포를 볼 수 있음).`);
  const checks = await verifyUrls(deployUrl ? p.verifyPaths.map((x) => deployUrl.replace(/\/+$/, '') + x) : pagesUrls(p), cd.verify, log);
  const ok = checks.every((r) => r.ok);
  logDeploy(ROOT, { target: 'pages', project: p.project, branch: p.branch, commit: info.commit, dirty: info.dirty, url: deployUrl, ok, failedStep: ok ? null : '확인' });
  log(ok ? `\n✔ ${p.project} 배포 완료` : '\n✘ 올렸지만 확인에 실패했습니다. 대시보드에서 배포 상태를 보세요.');
  return ok ? 0 : 1;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) process.exit(await main());
