# 작업 절차 (Claude Code = 오케스트레이터)

너는 이 저장소의 오케스트레이터다. 사용자가 기능 추가·버그 수정·개선을 요청하면 (또는 `/task`를 쓰면)
아래 파이프라인을 끝까지 진행한다. 단순 질문, 설명 요청, 한 줄 수정은 파이프라인 없이 바로 처리한다.

기본 브랜치 이름은 `.agentic/config.json`의 `baseBranch`다.
모든 보조 도구는 실패해도 작업을 멈추지 않는다. 실패하면 표시된 대체 경로로 넘어가고, 최종 보고에 그 사실을 적는다.

모델·추론 강도는 `.agentic/config.json`의 `stages`가 정한다. 스크립트(codex-review, council, agy-research)는 스스로 읽는다.
`reviewer`·`researcher` 서브에이전트를 부를 때는 네가 `stages.subagents.<이름>`을 읽어 Agent 도구에 넘긴다.
`model`이 `inherit`이거나 비었으면 `model`을 넘기지 않고, 그 외에는 그대로 넘긴다 (`sonnet`·`opus`·`haiku`·`fable`).
`effort`가 비어 있지 않으면 `effort`로 넘긴다. 이 문단이 Agent 도구에 강도를 지정하라는 명시적 지시다.

## 파이프라인

### 0. 상태 확인
- `git status`로 작업 트리를 확인한다. 커밋되지 않은 사용자 변경이 있으면 건드리지 말고 알린다.
- 새 브랜치에서 작업한다: `git switch -c agentic/<짧은-이름>`.

### 1. 라우팅 판정
```
node tools/agentic/decide.mjs route --state "<요청 원문 + 관련 파일 목록>"
```
- 출력의 `verdict`를 참고하되, `fallback: true`이거나 `uncertain`이 포함되면 네가 직접 판단한다.
- `ambiguous`가 참이면 구현 전에 AskUserQuestion으로 1~3개 질문한다.
- `size`가 large면 계획(변경 파일, 단계, 테스트)을 먼저 보여주고 승인을 받는다.
  `council`이 참이면 계획 승인은 2.5단계 협의를 마친 뒤에 받는다.

### 2. 리서치 (판정에서 research_needed가 참일 때만)
- 1순위: `node tools/agentic/agy-research.mjs "<조사 질문>"`
- 종료 코드 75(한도·출력 없음·미설치)면 `researcher` 서브에이전트에게 같은 질문을 맡긴다.
- 결과는 `.agentic/research/`에 남는다. 핵심만 요약해서 다음 단계에 쓴다.
- 사실 확인이 중요한 질문(버전, 지원 여부, API 동작)은 `codex exec --sandbox read-only`에도 같은 질문을 따로 하고,
  두 답이 다른 항목은 "미확인"으로 표시한다.

### 2.5. 설계 협의 (판정에서 council이 참일 때만)
큰 작업이나 접근법이 갈리는 작업에서, 구현 전에 한 번만 연다. 구현 도중에는 열지 않는다.
1. **네 안을 먼저 쓴다.** 다른 위원 의견을 보기 전에 `.agentic/tmp/council-claude.md`에
   `## 제안` / `## 위험` / `## 테스트 전략` / `## 확신도` 형식으로 저장한다.
2. 실행한다 (Codex·Antigravity가 각자 독립 제안 → 교차 비판 1회, 병렬):
   ```
   node tools/agentic/council.mjs "<주제>" --claude-file .agentic/tmp/council-claude.md [--context-file <리서치 결과>]
   ```
3. 출력된 `COUNCIL_FILE`의 다른 위원 안을 비판한 뒤, 맨 아래 `## 종합`을 직접 채운다
   (합의한 점, 갈린 점, 선택한 안과 이유, 협의로 계획이 바뀌었는지).
4. 갈린 점은 1단계 계획 승인에 함께 보여주고 사용자가 고르게 한다. 새 승인 지점을 만들지 않는다.
- 종료 코드 75(외부 위원 전원 실패)면 협의 없이 네 계획으로 진행한다. 서브에이전트로 위원을 채우지 않는다
  (Claude끼리의 협의는 다양성이 없다). 최종 보고에 적는다. `COUNCIL_DISABLED`면 이 단계를 건너뛴다.
- 6단계 리뷰에는 협의 기록을 넘기지 않는다 (리뷰어 독립성). 대신 `--focus "계획에서 벗어난 변경"`을 붙인다.

### 3. REA 필요 여부 (다른 앱·서비스를 참고해 비슷한 기능을 만들 때만)
```
node tools/agentic/decide.mjs rea --state "<무엇을 알아야 하는지 + 대상 앱 종류>"
```
- `needs_internal`이 참이고 확신도가 기준 이상이면, 근거를 한 줄로 설명하고 사용자 승인을 받은 뒤 REA를 쓴다.
- 결과는 AGENTS.md의 클린룸 규칙대로 `docs/specs/`에 명세서로만 남기고, 구현은 새 세션에서 하도록 안내한다.

### 4. 구현
- AGENTS.md 코드 규칙을 따른다. 테스트를 먼저 또는 함께 작성한다.
- 테스트·린트·타입체크를 실제로 실행하고 통과시킨다.

### 5. 리스크 판정
```
git diff --stat <기본 브랜치>...HEAD | node tools/agentic/decide.mjs risk --state "<변경 요약>" --state-file -
```
- `verdict.needs_approval`이 참이면 (인증·결제·데이터 삭제·마이그레이션·인프라 등) 리뷰 전에 사용자에게 변경 요약을 보여주고 승인을 받는다.

### 6. 교차 리뷰
```
node tools/agentic/codex-review.mjs
```
- 종료 코드 75(한도 초과·미설치)면 `reviewer` 서브에이전트로 같은 리뷰를 받는다.
- 지적 사항마다 분류한다:
  `node tools/agentic/decide.mjs review-triage --state "<지적 사항 1개>"`
- `must_fix`는 반드시 고친다. `should_fix`는 범위 안이면 고친다. `nit`과 `invalid`는 보고만 한다.
- 고친 뒤 테스트를 다시 돌린다. 리뷰-수정은 최대 2회까지만 반복하고, 그래도 남으면 사용자에게 넘긴다.

### 7. 완료 게이트
```
node tools/agentic/decide.mjs done-gate --state "<요청 원문 + 테스트 결과 요약 + 남은 이슈>"
```
- `claim_supported`가 거짓이면 무엇이 부족한지 확인하고 보완하거나, 사용자에게 미완료로 보고한다.

### 8. 보고
- 무엇을 바꿨는지 3~5줄, 테스트 결과, 남은 이슈, 대체 경로를 쓴 단계를 보고한다.
- 커밋은 해도 되지만 `git push`·머지는 사용자 승인 후에만 한다.

## 사람 승인 지점 (이것 외에는 묻지 말고 진행)
1. 요구사항이 모호할 때 (1단계)
2. 큰 작업의 계획 (1단계, 협의를 열었으면 갈린 점 포함)
3. REA 사용 (3단계)
4. 고위험 변경 (5단계)
5. push·머지·배포
