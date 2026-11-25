#!/usr/bin/env node
// 지금 이 컴퓨터에서 쓸 수 있는 모델과 각 모델이 받는 추론 강도를 보여 준다 (실행할 때마다 CLI에 직접 묻는다).
// 오케스트레이터는 요청마다 이 목록 안에서 모델·강도를 골라 스크립트의 --model·--effort로 넘긴다 (PIPELINE "모델·추론 강도 고르기").
// 사용: node tools/agentic/models.mjs            codex·agy 둘 다
//       node tools/agentic/models.mjs codex      한 도구만 (codex | agy)
// 종료 코드: 0 (도구가 없거나 목록을 못 받아도 0, 해당 항목에 available: false와 이유) / 2 사용법 오류
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, loadConfig, childEnv, hasCommand, run, stageSettings, parseCodexModels, parseAgyModels, parseCodexDefaults, SUBAGENT_MODELS } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const CONFIG = loadConfig(ROOT);
const TOOLS = ['codex', 'agy'];
const args = process.argv.slice(2);
if (args.length > 1 || (args[0] && !TOOLS.includes(args[0]))) { console.error(`사용: models.mjs [${TOOLS.join('|')}]`); process.exit(2); }
const only = args[0];
const LIST_TIMEOUT = 60000, VERSION_TIMEOUT = 15000;

async function list(cmd, argv, parse) {
  if (!hasCommand(cmd)) return { available: false, reason: `${cmd} CLI가 설치되어 있지 않음`, models: [] };
  const opts = { cwd: ROOT, env: childEnv() }; // 키 파일의 키는 넘기지 않는다
  // 같은 이름의 CLI가 여러 개 설치돼 있으면 키트 스크립트가 부르는 쪽의 버전이 목록을 정한다. 어느 것을 물었는지 남긴다.
  const [res, ver] = await Promise.all([
    run(cmd, argv, { ...opts, timeoutMs: LIST_TIMEOUT }),
    run(cmd, ['--version'], { ...opts, timeoutMs: VERSION_TIMEOUT }),
  ]);
  const version = ver.code === 0 ? ver.stdout.trim().split(/\r?\n/)[0].slice(0, 80) : '';
  if (res.timedOut) return { available: false, version, reason: '시간 초과', models: [] };
  if (res.code !== 0) return { available: false, version, reason: `종료 코드 ${res.code}: ${(res.stderr || res.stdout).trim().slice(-300)}`, models: [] };
  const models = parse(res.stdout);
  return models.length ? { available: true, version, models } : { available: false, version, reason: '목록을 읽지 못함 (출력 형식이 바뀌었을 수 있음)', models: [] };
}

function codexDefaults() {
  try { return parseCodexDefaults(readFileSync(join(process.env.CODEX_HOME || join(homedir(), '.codex'), 'config.toml'), 'utf8')); }
  catch { return { model: '', effort: '', profile: '', provider: '' }; }
}

// 설정 값(config.json stages)이 지금 목록에 있는지. 없으면 오케스트레이터는 목록에서 골라 --model로 덮어쓴다.
// known: 대조에 쓸 ID (codex는 숨김 모델 포함).
function configCheck(tool, known) {
  const stages = tool === 'codex' ? [['review', 'codex'], ['implement', 'codex'], ['council', 'codex']] : [['research', 'agy'], ['council', 'agy']];
  const missing = [];
  for (const [stage, agent] of stages) {
    let model = '';
    try { ({ model } = stageSettings(CONFIG, stage, agent)); } catch { continue; }
    if (!model) continue;
    const base = tool === 'agy' ? model.replace(/-(low|medium|high|xhigh|max)$/, '') : model;
    if (!known.some((m) => m.id === base || m.id === model || m.name === model)) missing.push(`stages.${stage}.${agent}.model=${model}`);
  }
  return missing;
}

const jobs = {
  async codex() {
    const r = await list('codex', ['debug', 'models'], parseCodexModels);
    const defaults = codexDefaults();
    const all = r.models;
    const out = { ...r, models: all.filter((m) => !m.hidden).map(({ hidden, ...m }) => m), defaults };
    if (r.available && !out.models.length) Object.assign(out, { available: false, reason: '숨김 모델만 있어 고를 모델이 없음' });
    if (!out.available) return out;
    // 다른 모델 제공자(model_provider)나 프로필(profile)을 쓰면 실제 모델이 이 목록 밖에서 정해진다. 대조하지 않고 알리기만 한다.
    if (defaults.provider || defaults.profile) {
      out.note = `config.toml에 ${defaults.provider ? `model_provider=${defaults.provider}` : `profile=${defaults.profile}`}가 있어 목록과 설정을 대조하지 않음. 모델은 설정 값 그대로 쓴다`;
      return out;
    }
    const missing = configCheck('codex', all);
    if (missing.length) out.configNotAvailable = missing;
    // 전역 기본 모델이 이 CLI의 목록(숨김 포함)에 없으면 모델을 비워 두는 것(전역 기본값)도 안전하지 않다. 목록의 모델을 직접 넘긴다.
    if (defaults.model && !all.some((m) => m.id === defaults.model)) out.defaultNotAvailable = defaults.model;
    return out;
  },
  async agy() {
    const r = await list('agy', ['models'], parseAgyModels);
    if (!r.available) return r;
    const missing = configCheck('agy', r.models);
    return missing.length ? { ...r, configNotAvailable: missing } : r;
  },
};

const picked = TOOLS.filter((t) => !only || only === t);
const results = await Promise.all(picked.map((t) => jobs[t]()));
const out = { takenAt: new Date().toISOString(), ...Object.fromEntries(picked.map((t, i) => [t, results[i]])) };
if (!only) {
  out.subagents = {
    models: SUBAGENT_MODELS.filter(Boolean),
    note: '이 세션 Agent 도구의 model 선택지가 실제 가용 목록이다. 여기 값은 키트가 아는 별칭일 뿐이며, 목록에 없는 별칭은 넘기지 않는다.',
  };
}
console.log(JSON.stringify(out, null, 2));
