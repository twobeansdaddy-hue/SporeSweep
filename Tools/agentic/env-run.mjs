#!/usr/bin/env node
// 공용 키 파일과 프로젝트 .env를 합친 환경으로 명령 하나를 실행한다. 프로젝트 스크립트가 키를 각자 복사해 두지 않아도 된다.
// 우선순위: 셸 환경변수 > 프로젝트 .env > 공용 키 파일(~/.config/agentic-kit/.env). 값은 화면에 출력하지 않는다.
// 사용: node tools/agentic/env-run.mjs [--only KEY,KEY] -- <명령> [인자...]
//       node tools/agentic/env-run.mjs --check KEY [KEY...]     키가 설정됐는지만 보여 준다 (값은 보이지 않음)
//   --only: 키 파일에서 읽은 변수 중 이 이름들만 명령에 넘긴다 (최소 권한). 셸 환경변수는 그대로 넘어간다.
// 종료 코드: 명령의 종료 코드 / --check에서 빠진 키가 있으면 1 / 사용법 오류 2
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnvFile, globalEnvPath } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
const args = process.argv.slice(2);
const usage = (msg) => {
  console.error(`오류: ${msg}\n사용: env-run.mjs [--only KEY,KEY] -- <명령> [인자...]\n      env-run.mjs --check KEY [KEY...]`);
  process.exit(2);
};

// 셸에 원래 있던 변수는 그대로 두고, 키 파일에서 읽은 것만 따로 모은다 (--only로 거르기 위해).
const shell = { ...process.env };
loadEnvFile(join(ROOT, '.env'));
loadEnvFile(globalEnvPath());
const fromFiles = Object.fromEntries(Object.entries(process.env).filter(([k]) => !(k in shell)));

if (args[0] === '--check') {
  const keys = args.slice(1);
  if (!keys.length) usage('--check 뒤에 확인할 키 이름이 필요합니다');
  let missing = 0;
  for (const k of keys) {
    const where = k in shell && shell[k] !== '' ? '셸' : k in fromFiles ? '키 파일' : null;
    if (!where) missing++;
    console.log(`${where ? '✔' : '✘'} ${k}${where ? ` (${where})` : ` — ${globalEnvPath()} 또는 프로젝트 .env에 넣으세요`}`);
  }
  process.exit(missing ? 1 : 0);
}

const sep = args.indexOf('--');
if (sep < 0 || sep === args.length - 1) usage('-- 뒤에 실행할 명령이 필요합니다');
let only = null;
for (let i = 0; i < sep; i++) {
  if (args[i] === '--only') {
    const v = args[++i];
    if (!v || i >= sep) usage('--only 값 없음');
    only = new Set(v.split(',').map((x) => x.trim()).filter(Boolean));
  } else usage(`알 수 없는 인자: ${args[i]}`);
}
const env = { ...shell, ...Object.fromEntries(Object.entries(fromFiles).filter(([k]) => !only || only.has(k))) };
const [cmd, ...rest] = args.slice(sep + 1);
const r = spawnSync(cmd, rest, { stdio: 'inherit', env });
if (r.error) { console.error(`실행 실패: ${cmd} (${r.error.code ?? r.error.message})`); process.exit(127); }
process.exit(r.status ?? 1);
