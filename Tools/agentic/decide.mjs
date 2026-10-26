#!/usr/bin/env node
// System 1 결정 레이어: Jev 호환(System One) API로 정해진 질문에 대한 판정을 받는다.
// 사용: node tools/agentic/decide.mjs <kind> [--state "..."] [--state-file path]... [--provider name] [--dry-run]
//       node tools/agentic/decide.mjs --list
// 어떤 오류가 나도 종료 코드 0과 함께 {"fallback": true}를 출력한다 (fail-open). 사용법 오류만 2.
import { readFileSync, existsSync, mkdirSync, appendFileSync, readdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findRoot, loadEnv, loadConfig } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
loadEnv(ROOT);
const CONFIG = loadConfig(ROOT).decide ?? {};
const DECISIONS_DIR = join(ROOT, '.agentic', 'decisions');

const PROVIDERS = {
  cloudflare: {
    maxStateChars: 120000,
    ready: () => process.env.CLOUDFLARE_ACCOUNT_ID && process.env.CLOUDFLARE_API_TOKEN
      ? null : 'CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN 없음',
    request: (model) => ({
      url: `${(process.env.CLOUDFLARE_API_BASE || 'https://api.cloudflare.com/client/v4').replace(/\/$/, '')}/accounts/${process.env.CLOUDFLARE_ACCOUNT_ID}/ai/run/@cf/cloudflare/${model}`,
      headers: { Authorization: `Bearer ${process.env.CLOUDFLARE_API_TOKEN}` },
    }),
    defaultModel: 'clef-flash',
  },
  jev: {
    maxStateChars: 60000,
    ready: () => process.env.TYPESAFE_API_KEY ? null : 'TYPESAFE_API_KEY 없음',
    request: () => ({
      url: `${(process.env.TYPESAFE_BASE_URL || 'https://api.typesafe.ai/v1').replace(/\/$/, '')}/systemone`,
      headers: { Authorization: `Bearer ${process.env.TYPESAFE_API_KEY}` },
    }),
    defaultModel: 'jev-latest',
  },
  openrouter: {
    maxStateChars: 60000,
    ready: () => process.env.OPENROUTER_API_KEY ? null : 'OPENROUTER_API_KEY 없음',
    request: () => ({
      url: 'https://openrouter.ai/api/alpha/decisions',
      headers: { Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}` },
    }),
    defaultModel: 'typesafe/jev-1.13',
  },
  local: {
    // Laya 등 로컬 서버 (예: Unsloth Decision API). 컨텍스트가 짧으므로 상태를 많이 자른다.
    maxStateChars: 2000,
    ready: () => process.env.DECIDE_LOCAL_URL ? null : 'DECIDE_LOCAL_URL 없음',
    request: () => ({
      url: process.env.DECIDE_LOCAL_URL,
      headers: process.env.DECIDE_LOCAL_KEY ? { Authorization: `Bearer ${process.env.DECIDE_LOCAL_KEY}` } : {},
    }),
    defaultModel: 'laya-multilingual',
  },
};

function usage(msg) {
  if (msg) console.error(`오류: ${msg}`);
  console.error('사용: decide.mjs <kind> [--state "..."] [--state-file 경로]... [--provider 이름] [--dry-run]');
  console.error('      decide.mjs --list');
  process.exit(2);
}

function parseArgs(argv) {
  const out = { kind: null, states: [], provider: null, dryRun: false, list: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--state') out.states.push(argv[++i] ?? usage('--state 값 없음'));
    else if (a === '--state-file') {
      const p = argv[++i] ?? usage('--state-file 값 없음');
      out.states.push(p === '-' ? readFileSync(0, 'utf8') : readFileSync(resolve(p), 'utf8'));
    } else if (a === '--provider') out.provider = argv[++i];
    else if (a === '--dry-run') out.dryRun = true;
    else if (a === '--list') out.list = true;
    else if (!a.startsWith('--') && !out.kind) out.kind = a;
    else usage(`알 수 없는 인자 ${a}`);
  }
  return out;
}

// 확률 분포의 집중도: 1 - H(p)/ln(N). Jev/Clef 문서의 confidence 정의와 같다.
function concentration(probs) {
  const ps = probs.filter((p) => p > 0);
  const n = probs.length;
  if (n < 2) return 1;
  const h = -ps.reduce((s, p) => s + p * Math.log(p), 0);
  return Math.max(0, Math.min(1, 1 - h / Math.log(n)));
}

function summarize(answers, minConfidence, noulMargin) {
  const out = {};
  for (const [id, a] of Object.entries(answers ?? {})) {
    if (a.type === 'noul') {
      // 예/아니오는 0.5 근처(기본 0.35~0.65)만 불확실로 본다.
      const p = Number(a.noul);
      out[id] = { type: 'noul', value: p, confidence: round(concentration([p, 1 - p])), uncertain: Math.abs(p - 0.5) < noulMargin };
    } else if (a.type === 'choice') {
      const conf = a.confidence ?? concentration(Object.values(a.probabilities ?? {}));
      out[id] = { type: 'choice', value: a.choice, probabilities: a.probabilities, confidence: round(conf), uncertain: conf < minConfidence };
    } else if (a.type === 'score') {
      const conf = a.confidence ?? concentration(Object.values(a.probabilities ?? {}));
      const idx = Math.round(Number(a.score));
      const label = a.legend?.[String(idx)];
      out[id] = { type: 'score', value: Number(a.score), label, confidence: round(conf), uncertain: conf < minConfidence };
    } else {
      out[id] = { type: a.type ?? 'unknown', raw: a, uncertain: true };
    }
  }
  return out;
}

const round = (x) => Math.round(x * 1000) / 1000;

// 규칙 → true / false / "uncertain"
function evalRule(rule, s) {
  if (rule.any || rule.all) {
    const vals = (rule.any ?? rule.all).map((r) => evalRule(r, s));
    if (rule.any) {
      if (vals.includes(true)) return true;
      return vals.includes('uncertain') ? 'uncertain' : false;
    }
    if (vals.includes(false)) return false;
    return vals.includes('uncertain') ? 'uncertain' : true;
  }
  const q = s[rule.from];
  if (!q) return 'uncertain';
  let v;
  if ('noulAtLeast' in rule) v = q.value >= rule.noulAtLeast;
  else if ('scoreAtLeast' in rule) v = q.value >= rule.scoreAtLeast;
  else if ('choiceIn' in rule) v = rule.choiceIn.includes(q.value);
  else return 'uncertain';
  return q.uncertain ? 'uncertain' : v;
}

async function callProvider(name, model, body, timeoutMs) {
  const p = PROVIDERS[name];
  const { url, headers } = p.request(model);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 300)}`);
    let json = JSON.parse(text);
    if (json && json.result && json.result.answers) json = json.result; // Cloudflare REST 래퍼 해제
    if (!json.answers) throw new Error(`answers 없음: ${text.slice(0, 300)}`);
    return json;
  } finally {
    clearTimeout(timer);
  }
}

function log(entry) {
  if (CONFIG.log === false) return;
  try {
    const dir = join(ROOT, '.agentic', 'logs');
    mkdirSync(dir, { recursive: true });
    appendFileSync(join(dir, 'decisions.jsonl'), JSON.stringify(entry) + '\n');
  } catch { /* 로그 실패는 무시 */ }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.list) {
    for (const f of readdirSync(DECISIONS_DIR).filter((f) => f.endsWith('.json'))) {
      const d = JSON.parse(readFileSync(join(DECISIONS_DIR, f), 'utf8'));
      console.log(`${f.replace(/\.json$/, '').padEnd(16)} ${d.description ?? ''}`);
    }
    return;
  }
  if (!args.kind) usage('판정 종류(kind)가 필요합니다');
  const defPath = join(DECISIONS_DIR, `${args.kind}.json`);
  if (!existsSync(defPath)) usage(`판정 정의 없음: ${defPath} (--list로 확인)`);
  const def = JSON.parse(readFileSync(defPath, 'utf8'));
  const state = args.states.join('\n\n').trim();
  if (!state) usage('--state 또는 --state-file이 필요합니다');

  const minConfidence = CONFIG.minConfidence ?? 0.35;
  const timeoutMs = CONFIG.timeoutMs ?? 15000;
  const order = args.provider ? [args.provider] : (CONFIG.providers ?? ['cloudflare', 'off']);
  const attempts = [];
  const started = Date.now();

  for (const name of order) {
    if (name === 'off') break;
    const p = PROVIDERS[name];
    if (!p) { attempts.push({ provider: name, skipped: '알 수 없는 provider' }); continue; }
    const notReady = p.ready();
    if (notReady) { attempts.push({ provider: name, skipped: notReady }); continue; }
    const model = CONFIG.models?.[name] || p.defaultModel;
    const body = { model, state: state.slice(0, p.maxStateChars), questions: def.questions };
    if (args.dryRun) {
      console.log(JSON.stringify({ provider: name, request: { url: p.request(model).url, body } }, null, 2));
      return;
    }
    const t0 = Date.now();
    try {
      const raw = await callProvider(name, model, body, timeoutMs);
      const answers = summarize(raw.answers, minConfidence, CONFIG.noulMargin ?? 0.15);
      const verdict = {};
      for (const [k, rule] of Object.entries(def.verdict ?? {})) verdict[k] = evalRule(rule, answers);
      const result = {
        kind: args.kind, provider: name, model: raw.model ?? model, fallback: false,
        verdict, answers, latencyMs: Date.now() - t0, usage: raw.usage,
        ...(attempts.length ? { attempts } : {}),
      };
      console.log(JSON.stringify(result, null, 2));
      log({ ts: new Date().toISOString(), kind: args.kind, provider: name, model: result.model, state: state.slice(0, 4000), answers, verdict });
      return;
    } catch (e) {
      attempts.push({ provider: name, error: String(e.message ?? e).slice(0, 300) });
    }
  }

  const result = {
    kind: args.kind, provider: 'off', fallback: true,
    message: '판정 모델을 쓰지 못했습니다. 오케스트레이터가 직접 판단하세요.',
    attempts, latencyMs: Date.now() - started,
  };
  console.log(JSON.stringify(result, null, 2));
  log({ ts: new Date().toISOString(), kind: args.kind, provider: 'off', state: state.slice(0, 4000), attempts });
}

main().catch((e) => {
  console.log(JSON.stringify({ provider: 'off', fallback: true, error: String(e?.message ?? e) }));
});
