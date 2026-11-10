#!/usr/bin/env node
// 요청 난이도 등급에서 쓸 모델·추론 강도를 보여 준다 (config.json의 autoSelect.tiers를 stages 위에 덮은 값).
// 사용: node tools/agentic/tier.mjs <등급>     그 등급의 값 (서브에이전트를 부를 때 여기 값을 Agent 도구에 넘긴다)
//       node tools/agentic/tier.mjs            등급 목록과 각 등급의 값
// 종료 코드: 0 성공 / 2 없는 등급·설정 값 오류
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findRoot, loadConfig, autoSelectOn, tierNames, tierSelection } from './lib.mjs';

const ROOT = findRoot(dirname(fileURLToPath(import.meta.url)));
const CONFIG = loadConfig(ROOT);
const args = process.argv.slice(2);
if (args.length > 1 || args[0]?.startsWith('-')) { console.error('사용: tier.mjs [등급]'); process.exit(2); }
const enabled = autoSelectOn(CONFIG);

try {
  if (args[0]) {
    // 꺼져 있으면 등급과 상관없이 stages 값을 그대로 낸다.
    console.log(JSON.stringify({ tier: args[0], enabled, selection: tierSelection(CONFIG, args[0]) }, null, 2));
  } else {
    const tiers = Object.fromEntries(tierNames(CONFIG).map((t) => [t, tierSelection(CONFIG, t)]));
    console.log(JSON.stringify({ enabled, tiers }, null, 2));
  }
} catch (e) {
  console.error(e.message);
  process.exit(2);
}
