# UI/UX 레퍼런스 가이드

화면을 새로 만들거나 레이아웃·흐름을 바꾸는 작업에서 리서치(파이프라인 2단계)할 때 이 문서의 출처부터 본다.
여기서 얻는 것은 **패턴과 근거**다. 다른 서비스의 화면·문구·이미지·디자인 자산은 결과물에 옮기지 않는다 (AGENTS.md 금지 항목).

## 언제 쓰나

- 새 화면, 새 사용자 흐름(가입·구매·온보딩·결제 등)을 기획할 때
- 기존 화면의 레이아웃·정보 구조를 바꿀 때
- "요즘 이 카테고리는 보통 어떻게 하나"를 확인해야 할 때

단순 스타일 수정(색, 여백, 문구)에는 쓰지 않는다.

## 조사 순서

1. **누구를 볼지 정한다** — 카테고리 상위 서비스 3~5개를 고른다 (국내: 모바일인덱스·와이즈앱).
2. **화면과 흐름을 모은다** — 화면은 Mobbin·Refero, 흐름은 Page Flows. 게임은 Game UI Database.
   🔒 표시는 로그인이나 유료 구독이 있어야 제대로 볼 수 있는 출처다. 에이전트가 열지 못하면 공개 출처(NN/g, HIG, Material, Game UI Database, 각 서비스 공식 스토어 페이지)로 대신하고, 못 연 출처는 `미확인`에 적는다.
3. **근거를 확인한다** — 왜 그 배치인지 Baymard(커머스)·NN/g(일반)에서 확인한다.
4. **플랫폼 기준과 맞춘다** — Apple HIG / Material Design과 어긋나는 패턴은 이유를 적는다.

## 출처

### 화면·흐름 레퍼런스 (카테고리 필터 있음)

| 출처 | 쓰임 | 주소 |
|---|---|---|
| Mobbin 🔒 | 출시된 앱·웹 화면, 카테고리·화면 유형별 | https://mobbin.com |
| Refero 🔒 | 웹 강점, 요소 단위 검색(필터, 장바구니, 빈 상태) | https://refero.design |
| Page Flows 🔒 | 가입·구매·해지 등 흐름을 단계별로 | https://pageflows.com |

### 카테고리별

| 카테고리 | 출처 | 쓰임 | 주소 |
|---|---|---|---|
| 쇼핑·커머스 | Baymard Institute 🔒 | 목록·상세·장바구니·체크아웃 사용성 연구와 근거 (공개 아티클도 많음) | https://baymard.com |
| 게임 | Game UI Database | 메뉴·HUD·인벤토리·상점, 장르·화면 유형별 | https://www.gameuidatabase.com |
| 게임 | Interface In Game | 게임 UI 캡처 모음 | https://interfaceingame.com |
| 블로그·콘텐츠·랜딩 | Land-book / Lapa Ninja / One Page Love | 랜딩·포트폴리오 레이아웃 | https://land-book.com · https://www.lapa.ninja · https://onepagelove.com |
| 웹 트렌드 | Awwwards / Godly | 실험적·트렌디한 웹 (비주얼 무드 참고) | https://www.awwwards.com · https://godly.website |

모바일 캐주얼 게임은 상위권 게임을 직접 플레이하고 캡처하는 것이 가장 정확하다.
다른 서비스의 캡처는 git에서 무시되는 `.agentic/tmp/ui-refs/`에만 두고 커밋하지 않는다. 결과에는 캡처 대신 관찰한 패턴을 글로 적는다.

### 원칙·리서치

| 출처 | 쓰임 | 주소 |
|---|---|---|
| Nielsen Norman Group | 주제별 UX 리서치 아티클, 레이아웃 원칙의 근거 | https://www.nngroup.com |
| Apple HIG | iOS·macOS 기본 패턴 기준 | https://developer.apple.com/design/human-interface-guidelines |
| Material Design | Android·웹 기본 패턴 기준 | https://m3.material.io |
| Dribbble / Behance | 비주얼 무드만. 컨셉 작업이 많아 기획 근거로는 쓰지 않는다 | https://dribbble.com · https://www.behance.net |

### 국내

| 출처 | 쓰임 | 주소 |
|---|---|---|
| 토스·우아한형제들·당근·카카오 기술/디자인 블로그 | 국내 사용자 맥락의 의사결정 과정 | https://toss.tech · https://techblog.woowahan.com · https://medium.com/daangn · https://tech.kakao.com |
| 요즘IT / 브런치(UX) | 실무자 회고·분석 | https://yozm.wishket.com · https://brunch.co.kr |
| 모바일인덱스 / 와이즈앱·리테일 🔒 | 카테고리 상위 앱 선정 | https://www.mobileindex.com · https://www.wiseapp.co.kr |

## 결과 형식

리서치의 기본 형식(`## 결론` / `## 근거` / `## 미확인`)은 그대로 쓰고, UI 조사에서는 `## 근거` 아래를 이렇게 나눈다.

```
## 결론
(3~5줄. 공통 패턴과 우리에게 맞는 선택)
## 근거
### 참고 서비스
- (서비스 3~5개, 고른 이유)
### 공통 패턴
- (대부분이 쓰는 배치·흐름. 출처 링크)
### 갈리는 지점
- (서비스마다 다른 선택과 각각의 근거)
### 우리 결정 제안
| 항목 | 따름 / 변형 / 안 씀 | 이유 |
## 미확인
- (확인 못 한 것, 로그인·유료라 열지 못한 출처)
```

이 문서의 출처 목록은 바뀔 수 있다. 사이트가 닫혔거나 유료로 바뀐 것을 발견하면 결과의 `미확인`에 적고 최종 보고에서 사용자에게 알린다.
이 파일은 키트 관리 파일이므로 프로젝트에서 직접 고치지 않는다 (고치면 다음 `--update` 때 충돌이 난다). 고칠 내용은 키트 저장소에서 반영한다.
