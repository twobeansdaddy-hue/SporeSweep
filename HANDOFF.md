# 인수인계 문서

다른 사람이나 다른 Claude 계정이 이 프로젝트를 이어받을 때 처음 읽는 문서다. 이 문서와 [DESIGN.md](DESIGN.md)(기획서), [README.md](README.md)(빌드와 시험), [android/PORTING.md](android/PORTING.md)(안드로이드·웹·mods 진행표)를 읽으면 바로 일을 시작할 수 있게 쓴다.

**원칙: 모든 작업은 진행하면서 이 문서를 고친다.** 작업을 마칠 때가 아니라, 무언가 정하거나 바꾸거나 막힐 때마다 적는다. 중간에 계정이 바뀌어도 이어서 할 수 있어야 하기 때문이다. 고칠 곳은 셋이다.

- 맨 아래 **작업 기록**에 날짜와 한 일을 한 줄씩 더한다(새것이 위).
- **지금 상태와 다음 할 일**을 지금에 맞게 고친다.
- 새로 생긴 계정, 비밀값의 위치, 주의할 점이 있으면 그 절에 적는다.

마지막으로 고친 날: 2026-10-27

## 1. 프로젝트 한눈에

- **포자 대청소(SporeSweep).** 외계 오염 물질을 보드 아래 격리 컨테이너까지 내려보내 도시를 정화하는 매치3 모바일 게임이다. 24개 도시, 380개 레벨이 있다.
- **iOS 판이 기준이다.** Swift 6, SpriteKit. 규칙은 Swift 패키지 `GameCore`에 있다.
- **안드로이드·웹·mods 판은 Kotlin으로 옮긴 것이다.** 규칙이 iOS와 수마다 똑같은지 기준 기록으로 시험한다(아래 4절).
- **웹판** `https://play.code404.app`은 출시 전에 동호회 사람들이 해 보라고 연 것이다. 광고 대신 바로 보상을 준다.
- **mods판**은 Claude Code 안에서 하는 작은 판이다. 배포는 별도 공개 저장소 `twobeansdaddy-hue/sporesweep-mod`에서 한다.
- **출시는 한국과 해외(중국 본토 제외)에 함께 한다(2026-10-24에 바꿨다).** 권리 문제가 알려진 랜드마크 7곳은 이름만 일반 이름으로 바꿨다(DESIGN.md v0.41). Google Play는 비공개 테스트(12명×14일)를 거쳐야 한다. Apple 개발자 계정은 2026-10-24에 열렸다.

## 2. 일하는 방식 (계정 주인이 정한 것)

- **대답은 한국어 해요체로 한다.** 문서는 기존 문서처럼 "~다"체로 쓴다.
- **기획서(DESIGN.md)와 다르게 하려면 먼저 묻는다.** 정한 것을 바꾸면 DESIGN.md와 관련 문서(README, PORTING, PLAN)에 함께 적는다. 기획서는 판(v0.40 같은)을 올리고 맨 앞에 그 판에서 바뀐 것을 한 단락으로 적는다.
- **자동 확인을 먼저 만든다.** 무엇이 통과면 끝인지 시험이나 명령으로 정한 뒤, 구현 → 확인 → 고치기를 되풀이한다.
- **빌드하고, 시험하고, 기기에서 본다.** iOS 시뮬레이터, 안드로이드 에뮬레이터, 브라우저에서 실제로 돌려 본다. 보지 못했으면 보지 못했다고 말한다.
- **커밋과 GitHub에 올리기는 계정 주인이 말할 때만 한다.** 커밋 메시지는 한국어로, 무엇을 왜 바꿨는지 쓴다.
- **돈이 드는 생성은 먼저 묻는다.** ElevenLabs(효과음·음악)는 크레딧을 쓴다. 그림은 Codex(계정 주인의 ChatGPT 계정)로 만든다.
- **분홍색은 오염 물질과 목표에만 쓴다.** 그림을 새로 만들 때 지킨다.

## 3. 저장소 구조

| 곳 | 무엇 |
| --- | --- |
| `GameCore/` | 규칙(매치, 낙하, 특수 블록, 장애물, 점수). 다른 판이 모두 이것을 따른다 |
| `GameScene/` | SpriteKit 씬, 그림(`Sprites/`), 소리(`Sounds/`) |
| `LevelData/` | 레벨 JSON 380개(`Sources/LevelData/Levels/`), 레벨 도구 `levelgen`·`levelaudit`·`paritygen`·`leveldebug` |
| `Progress/` | 저장, 생명, 일일 보상, 진행 합치기 |
| `SporeSweep/` | iOS 앱(화면, 광고, Firebase) |
| `android/core` | 규칙·레벨·진행의 Kotlin판. JVM, 웹(Wasm), JS로 빌드한다 |
| `android/game` | 그리기 엔진과 화면. 안드로이드와 웹이 함께 쓴다(Compose Multiplatform) |
| `android/app` | 안드로이드 앱(AdMob, Firebase) |
| `android/web` | 웹판 |
| `android/mod` | mods판의 규칙 엔진(Kotlin/JS를 esbuild로 한 파일로 묶는다) |
| `mods/sporesweep/` | mods판의 개발용 원본(화면 `hooks/game.tsx`, 훅 `hooks/register.tsx`, 시험) |
| `Tools/` | 그림·소리·스토어 자료·웹 자료·mods 데이터를 만드는 스크립트 |
| `Reports/` | 레벨 점검 보고서(`LEVEL_AUDIT.md`, `level_audit.csv`) |
| `Art/` | 그림과 소리의 원본 |

## 4. 자주 쓰는 명령

자세한 것은 README.md와 PORTING.md에 있다.

| 하는 일 | 명령 |
| --- | --- |
| iOS 규칙 시험 | `cd GameCore && swift test` (GameScene, LevelData, Progress도 같다) |
| iOS 빌드 | `xcodebuild -project SporeSweep.xcodeproj -scheme SporeSweep -destination 'generic/platform=iOS Simulator' build` |
| Kotlin 시험 전부 | `cd android && ./gradlew :core:allTests` (JVM, Wasm, JS 세 곳) |
| 안드로이드 설치 | `cd android && ./gradlew :app:installDebug` |
| 안드로이드 출시 묶음(AAB) | `cd android && ./gradlew :app:bundleRelease` (업로드 키가 있어야 한다, 6절) |
| 웹판 만들기 | `cd android && ./gradlew :web:webSite` → `android/web/build/site`를 zip으로 묶는다 |
| mods판 데이터 | `cd android && ./gradlew :mod:modEngine` 후 `python3 Tools/make_mod.py` |
| mods판 시험 | `claude plugin validate mods/sporesweep`, `claude plugin test mods/sporesweep` |
| 레벨 점검 | `cd LevelData && swift run -c release levelaudit --csv ../Reports/level_audit.csv` (`--recalibrate`는 이동 횟수를 다시 잰다. 약 1시간) |

**규칙을 바꿀 때의 순서.** Swift(`GameCore`)를 먼저 고치고 시험한다 → 판이 쉬워지거나 어려워지면 `levelaudit --recalibrate`로 레벨을 다시 잰다 → 기준 기록을 다시 만든다(`cd LevelData && swift run -c release paritygen ../android/core/src/commonTest/resources/parity 40` 후 `gzip -9 -f ../android/core/src/commonTest/resources/parity/*.txt`) → Kotlin(`android/core`)을 맞춰 `:core:allTests`가 통과하게 한다 → 화면(iOS `GameScene`, Kotlin `android/game`)과 mods판(`mods/sporesweep/hooks/game.tsx`)을 고친다 → mods 데이터를 다시 만든다.

## 5. 저장소 밖에 있는 것

다른 컴퓨터에서 이어받으면 아래는 저장소에 없다. 계정 주인에게 받아야 한다. 값은 이 문서에 적지 않는다(저장소가 공개다).

| 무엇 | 있는 곳(계정 주인의 맥) | 없으면 |
| --- | --- | --- |
| 출시·사업 계획서 `PLAN.md`, 스토어 자료 `Marketing/` | 저장소 폴더 안. `.gitignore`로 뺐다 | 출시 준비 일정과 스토어 문구를 모른다 |
| iOS 광고 ID, 개발 팀 | `Config/Local.xcconfig` (예시: `Local.example.xcconfig`) | 시험 광고로 돈다 |
| iOS Firebase | `SporeSweep/GoogleService-Info.plist` | 기록을 보내지 않는다 |
| 안드로이드 광고 ID | `android/config.properties` (예시: `config.example.properties`) | 시험 광고로 돈다 |
| 안드로이드 Firebase | `android/app/google-services.json` | 기록을 보내지 않는다. 예전 ID로 등록한 개발용 파일 둘은 `~/Developer/sporesweep-firebase-dev/`로 옮겨 두었다(새 ID와 맞지 않아 안드로이드 빌드가 실패한다) |
| 웹 Firebase | `android/web/firebase-config.js` (예시: `firebase-config.example.js`) | 웹판이 기록을 보내지 않는다 |
| 안드로이드 업로드 키 | `~/Developer/keys/` (저장소 밖). 비밀번호는 macOS 키체인 `sporesweep-upload-key` | 출시 묶음에 서명할 수 없다. 잃으면 Play Console에서 키 재설정을 해야 한다 |
| ElevenLabs API 키 | macOS 키체인 `elevenlabs-api-key`. 스크립트 안에서만 꺼내 쓴다. 화면에 찍거나 파일에 적지 않는다 | 소리를 새로 만들 수 없다 |
| 회사 사이트 `code404.app` | `~/Developer/code404-site/` (git 아님). 개인정보 처리방침과 `app-ads.txt` | 사이트를 고칠 수 없다 |

## 6. 계정과 서비스

| 서비스 | 쓰는 곳 | 메모 |
| --- | --- | --- |
| GitHub `twobeansdaddy-hue/SporeSweep` | 이 저장소(공개) | 공개는 유지한다(계정 주인이 정했다) |
| GitHub `twobeansdaddy-hue/code404-brand` | 회사 CI(비공개). 로고, 색, 안내판, 상표 검색 기록 | 2026-10-26에 만들었다. 로고는 Gemini 시안을 다듬은 것(남색 #1E1B4B + 보라 #7C3AED, `>/.` 심볼). 포자 대청소와 색을 엮지 않는다 |
| GitHub `twobeansdaddy-hue/sporesweep-mod` | mods판 배포용(공개) | `mods/sporesweep`를 복사해 올린다. `marketplace.json`, `README.md`, `.gitignore`는 그쪽 것을 둔다 |
| Cloudflare Pages `sporesweep-play` | `play.code404.app` | 웹판 zip을 새 배포로 올린다. 계정 주인이 대시보드에서 한다 |
| Cloudflare Pages `code404-site` | `code404.app` | 회사 사이트 |
| Firebase `sporesweep-7943b` | 출시용. iOS·안드로이드의 플레이 기록 | 2026-10-24에 만들었다. 번들 `app.code404.sporesweep` |
| Firebase `sporesweep-dev` | 개발용. 웹판의 플레이 기록 | 예전 ID(`dev.code404.sporesweep`)로 등록한 앱 파일은 `~/Developer/sporesweep-firebase-dev/`에 있다 |
| AdMob | 보상형 광고(iOS, 안드로이드 따로) | 실제 광고는 스토어에서 받은 앱에서만 나온다. 개발 중에 자기 광고를 누르면 안 된다 |
| Google Play Console | 앱 ID를 `app.code404.sporesweep`로 바꿨다(2026-10-24). 예전 `dev.code404.sporesweep`로 만든 Play 앱은 쓰지 않고 새 앱을 만든다 | 개인 계정이라 프로덕션 전에 테스터 12명 × 14일 비공개 테스트가 필요하다 |
| Apple Developer | 2026-10-24 등록됨 | Xcode에는 아직 개인 팀(무료)만 있다. 유료 팀의 Apple ID를 Xcode 계정에 넣어야 출시 빌드를 올릴 수 있다 |
| ElevenLabs | 효과음과 음악 | 크레딧을 쓴다. 먼저 묻는다 |
| Codex(ChatGPT) | 그림 | 계정 주인의 계정 |

## 7. 지금 상태와 다음 할 일

**지금(2026-10-21).** 기획서 v0.40. 2×2 매치와 청소 드론, 판마다 무작위 시작 보드가 들어갔고, 380레벨을 다시 쟀다. iOS·안드로이드·웹·mods 모두 빌드되고 시험이 통과한다. 웹판은 최신으로 올라가 있다. mods판은 배포용 저장소에 올렸다.

| 시험 | 수 |
| --- | --- |
| GameCore | 322 |
| GameScene | 66 |
| LevelData | 109 |
| Progress | 34 |
| Kotlin `:core:allTests` | JVM 36, Wasm 31, JS 31 (기준 기록 399레벨, 15,070수) |
| mods판 | 8 (터미널 4, 데스크톱 4) |

**다음 할 일.**

1. 동호회 사람들의 웹판·mods판 반응을 듣고 난이도와 화면을 고친다. Firebase의 `level_start`(시드 포함), `level_end`로 포기 지점을 본다.
2. mods판을 실제로 설치해 보고 확인한다. 계정 주인의 맥에서는 개발용으로 불러오므로 다른 사람의 컴퓨터에서 본다.
3. **안드로이드 비공개 테스트 게시됨(2026-10-27).** Play 새 앱 "포자 대청소: SporeSweep"(`app.code404.sporesweep`)의 비공개 테스트 Alpha에 버전 3(0.2, 시험 광고)을 냈다. 테스터 목록 "포자 대청소 비공개 테스터"에 Gmail 14명을 넣었다(2026-10-27, 캣타워 비공개 테스터 목록도 같은 14명; 캣타워 패키지 `app.code404.cattower`, 참여 링크 https://play.google.com/apps/testing/app.code404.cattower). 테스터들에게 참여 링크를 보내 각자 참여·설치하게 하고 14일 동안 둔다. 그 뒤 "프로덕션 액세스 신청" → 출시용 Firebase `google-services.json`을 넣고 `-PtestAds` 없이 versionCode 5로 만들어 프로덕션에 낸다. 소리·용량을 고친 versionCode 4(시험 광고)는 비공개 테스트에 올릴 차례다(AAB 26MB).
4. **iOS 1.0 심사 대기 중(2026-10-25 제출).** 결과 메일을 기다린다. 거절되면 사유를 보고 고쳐 다시 낸다. 승인되면 자동 공개 → AdMob에 App Store 주소를 연결한다. (아래는 지난 기록) **iOS 출시 진행 중(2026-10-24).** 앱 버전을 1.0(빌드 1)으로 올렸다. 개인정보 매니페스트와 암호화 신고(`ITSAppUsesNonExemptEncryption` false)는 있다. 막힌 것: (가) Xcode → Settings → Accounts에 유료 팀의 Apple ID를 넣고 `Config/Local.xcconfig`의 `DEVELOPMENT_TEAM`을 그 팀 ID로 바꾼다, (나) App Store Connect에서 앱을 만든다(번들 ID `app.code404.sporesweep`), (다) 출시용 Firebase 파일. 셋이 되면 `xcodebuild archive` → App Store Connect에 올려 TestFlight에서 확인하고 심사에 낸다. 스토어 문구는 `Marketing/store/STORE_LISTING.md`(한국어, English).
5. **출시용 Firebase 프로젝트**(2026-10-24에 만들기로 정했다): 계정 주인이 콘솔에서 만들고 iOS(`app.code404.sporesweep`)와 안드로이드(같은 ID)를 등록해 `GoogleService-Info.plist`, `google-services.json`을 받는다. 웹판은 개발용(`sporesweep-dev`)을 그대로 쓴다. 출시 뒤 AdMob에 스토어 주소를 연결한다.
6. Google Play의 국가를 모든 국가로 넓힌다(프로덕션 때).
8. **AdMob 지급 계좌 확인 대기.** Google이 2026-10-25쯤 ₩250 미만 시험 입금을 보냈다(10-27까지 계좌에 안 보임). 10-29~31에 은행 입금 내역에서 금액을 찾아 AdMob → 결제 → 결제 수단에서 고른다(계정 주인이 한다, 기회가 적다).
7. **홍보 계정.** 유튜브 `@code404app`은 브랜드 계정으로 옮겼다(끝). 인스타 `code404.app`은 게시물 1개·팔로워 0이라 새로 만들지 않고, 계정 센터 연락처에 hello@code404.app을 더했다(끝, 개인 Gmail은 복구용으로 남김, 페이스북은 연결하지 않음). R2는 며칠 뒤 두 곳에 올린다.

## 8. 알아 둘 점

- **Xcode 화면에서 올리면 프로젝트 파일에 팀 ID(`DEVELOPMENT_TEAM`)를 적어 넣는다.** 팀 ID는 `Config/Local.xcconfig`에서만 넣는다. 커밋 전에 `git diff SporeSweep.xcodeproj`로 보고 그 줄을 지운다(2026-10-24에 한 번 섞여 올라갔다가 지웠다. 예전 커밋에는 남아 있다). "암호화 안 씀"은 이제 빌드 설정 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`에 있다.
- **기록이 안 보이면 광고 차단부터 본다.** 계정 주인의 맥(AdGuard, DNS 필터)과 아이폰(Unicorn Pro)이 Firebase·AdMob을 막는다. 코드를 보기 전에 DNS를 확인한다.
- **mods판은 창의 줄 수가 바뀌면 누른 칸이 어긋난다.** 화면의 줄은 줄바꿈하지 않게 했다(`wrap="truncate-end"`). 줄을 더하면 `HEADER_ROWS`와 단추의 줄 번호를 함께 맞춘다. 이모지가 든 줄이 더 높게 그려지는 환경에서는 아래로 갈수록 어긋날 수 있다(아직 보지 못했다).
- **mods판 화면은 Claude 데스크톱 앱에서 Claude가 직접 볼 수 없다**(화면 제어 대상에 없다). 계정 주인에게 화면을 받아 본다.
- mods판 시험 파일(`tests/sporesweep.test.tsx`)은 `tsc`에서 `props` 형식 경고가 난다. 시험은 돈다.
- `android/core/build/test-results/wasmJsBrowserTest`는 예전 결과다. 브라우저 시험은 꺼 두었다(파일을 읽을 수 없다).
- `xcodebuild`가 "Supported platforms ... is empty" 경고를 내지만 앱은 빌드된다.
- 레벨 설명(튜토리얼)이 있는 판은 늘 같은 보드로 시작한다. 나머지는 판마다 시드를 새로 뽑는다(DEBUG에서는 `-seed`로 고정).

## 9. 작업 기록

새것이 위다.

- **2026-10-27** 안드로이드 versionCode 4(0.2, 시험 광고)를 만들었다(브랜치 `agentic/android-audio-size`). ① 테스터 제보 "진동은 되는데 배경음악·효과음이 안 난다": 벨소리 모드가 '소리'가 아니면 무음으로 판정하던 것을 없애 미디어 볼륨만 따르게 했다(계정 주인 승인, DESIGN.md 효과음·배경 음악 문단에 적음). ② 용량: AAB 111MB → 26MB. 그림을 빌드 때 WebP로 줄이고(`Tools/make_android_assets.py`, 웹판과 같은 품질 82/90, 원본은 그대로) R8 축소를 켰다. R8을 켜자 WorkManager의 Room DB가 지워져 시작하자마자 멈춰서 `app/proguard-rules.pro`에 규칙을 넣었다. 에뮬레이터(진동 모드)에서 타이틀·인트로·도시·레벨 1·일일 선물이 그려지고 음악(MediaPlayer started)과 효과음(SoundPool started)이 나는 것, 광고 SDK가 실패 없이 받는 것을 봤다. 맥의 AdGuard DNS가 광고를 막으므로 에뮬레이터는 `-dns-server 8.8.8.8`로 켠다. 보상형 광고를 끝까지 보는 흐름은 실기기에서 아직 못 봤다.
- **2026-10-27** 테스터 1명을 더해 "포자 대청소 비공개 테스터"·"CatTower 비공개 테스터" 두 목록 모두 14명이 됐다. 테스터에게 보낼 안내 문구(두 참여 링크, 같은 Gmail로 "테스터 되기" → 설치 → 14일 유지, 의견은 hello@code404.app)를 만들어 계정 주인에게 줬다.
- **2026-10-27** 계정 주인이 준 테스터 Gmail 13명(본인 포함)을 Play 이메일 목록 "포자 대청소 비공개 테스터"에 넣고 저장했다(사용자 13). "CatTower 비공개 테스터" 목록에도 이미 같은 13명이 들어 있다. 주소는 공개 저장소에 적지 않는다. 다음: 테스터에게 참여 링크 전달, 14일 경과 확인.
- **2026-10-27** 포자 대청소 비공개 테스트 Alpha가 같은 날 검토를 통과해 게시됐다(게시 개요 "최근 게시일 10월 27일"). 테스터 참여 링크: 웹 https://play.google.com/apps/testing/app.code404.sporesweep , 안드로이드 https://play.google.com/store/apps/details?id=app.code404.sporesweep (목록에 든 Gmail만 받을 수 있다). 14일은 테스터 12명이 모인 날부터 센다. 캣타워(Play 앱 ID 4976183947764305656)도 비공개 테스트 Alpha 버전 2(1.0)를 검토에 냈다: 국가를 대한민국에서 전체로 넓히고 의견 주소를 hello@code404.app으로 바꿨다(계정 주인 요청). Play 알림에 "결제 계정에 긴급한 문제"가 떠 있다(시험 입금 확인 대기로 보인다, 확인 필요).
- **2026-10-27** Play 새 앱 채우기: 비공개 테스트 Alpha에 번들 3(0.2)을 올리고(계정 주인이 끌어다 놓음) 출시 노트를 넣어 임시 저장했다. 개인정보처리방침 URL, 광고 있음, 로그인 없음, 카테고리 퍼즐, 연락처 hello@code404.app·웹사이트 code404.app/sporesweep/, 기본 스토어 등록정보(이름 "포자 대청소: SporeSweep", 짧은·자세한 설명, 아이콘, 그래픽 이미지, 스크린샷 6장)를 넣었다. 법적 신고(광고 ID, 콘텐츠 등급, 타겟층, 데이터 보안, 정부 앱, 금융, 건강, 스토어 AI 애셋 선언)는 자동 모드가 막아 계정 주인이 답한다. 앱 콘텐츠 신고와 스토어 AI 애셋 선언(AI 생성 라벨)은 계정 주인이 끝냈다(설정 11/11). 같은 날 비공개 테스트 Alpha 버전 3(0.2)을 "검토를 위해 변경사항 16개 전송"으로 Google 검토에 냈다(관리형 게시 꺼짐: 승인되면 바로 테스터에게 열린다, 보통 7일 안). 경고 2개(난독화 매핑 파일, 네이티브 디버그 기호 없음)는 비정상 종료 분석에만 영향이 있다. 그다음 비공개 테스트에서 "검토를 위해 전송".
- **2026-10-27** Play Console에 새 앱 "포자 대청소"(`app.code404.sporesweep`, 앱 ID 4972676795805289304, 한국어, 게임, 무료)를 만들었다(정책·수출법 동의는 계정 주인이 눌렀다). 비공개 테스트 Alpha 트랙: 178개 국가, 테스터 이메일 목록 "포자 대청소 비공개 테스터"(지금은 계정 주인 한 명), 의견 주소 hello@code404.app. 번들은 패키지를 바꾼 뒤로 다시 만들었다(`bundleRelease -PtestAds`, versionCode 3, 111MB, 업로드 키 서명). 크롬 파일 올리기는 10MB까지라 AAB는 계정 주인이 끌어다 놓는다. 예전 `dev.code404.sporesweep` 임시 앱은 쓰지 않는다. 출시용 안드로이드 Firebase 파일은 아직 없어 이 판은 기록을 보내지 않는다.
- **2026-10-27** code404.app의 연락처를 개인 Gmail에서 `hello@code404.app`으로 바꿔 다시 올렸다(홈, `/sporesweep/`, 개인정보 처리방침 두 곳). Cloudflare가 사이트의 메일 주소를 가려서 보내므로 `curl`로는 주소가 안 보이고 `data-cfemail`로 확인했다. 계정 정리 방침(계정 주인과 정함): 바깥에 보이는 연락처만 hello@로 바꾸고, 로그인 계정(Apple·Play 개발자, Firebase, GA, AdMob, Cloudflare)은 개인 Gmail 그대로 둔다. 회사 명의로 옮기는 것은 사업자등록 뒤에 정한다. Play 새 앱의 개발자 이메일은 hello@로 넣는다. 유튜브는 브랜드 계정 code404를 만들어 @code404app 채널(R1 쇼츠, 프로필, 링크 포함)을 그쪽으로 이전했다. 개인 구글 계정(조민하)에는 이제 채널이 없다. 예전 개인 라이브 영상 2개도 함께 옮겨져 계정 주인이 지웠다. 회사 채널로 작업할 때는 유튜브에서 계정 전환으로 code404를 고른다.
- **2026-10-27** 회사 메일 `hello@code404.app`을 만들었다(Cloudflare 이메일 라우팅, 받으면 계정 주인의 Gmail로 넘긴다. MX 3개·SPF TXT 확인). 유튜브와 인스타가 모두 개인 계정이라, 회사 계정을 따로 두기로 했다(계정 주인 결정): 유튜브는 개인 구글 계정 아래 브랜드 채널 code404를 새로 만들고, 인스타는 hello@code404.app으로 새 계정을 만들어 code404.app 아이디를 옮긴다. 만들기는 계정 주인이, 꾸미기·R1 다시 올리기·개인 계정 되돌리기는 Claude가 한다. DNS·메일 전달 설정은 자동 모드가 막아 계정 주인이 눌렀다.
- **2026-10-27** 릴스 R1을 유튜브 쇼츠로 올렸다(`@code404app`, https://youtube.com/shorts/ipAkTTz3wnA, 공개, 아동용 아님은 계정 주인이 정했다). 계정 주인 요청으로 이 계정의 채널 구독 11개를 모두 취소했다. 예전 개인 영상 2개(2년 전 실시간 스트림)는 계정 주인이 지운다(Claude는 영구 삭제를 하지 않는다).
- **2026-10-27** 유튜브 채널(계정 주인의 twobeansdaddy 구글 계정, 채널 ID `UCrLuA3VsMllx26mpTqcwZIg`)을 code404 채널로 바꿨다: 사진은 CI 심볼, 이름 `code404`, 핸들 `@code404app`(`youtube.com/@code404app`), 설명 "찾을 수 없던 것을 만듭니다. AI와 함께 작은 게임과 앱을 만드는 1인 스튜디오.", 링크 code404.app·인스타그램. 이름과 핸들은 14일에 두 번까지만 바꿀 수 있다. 공개 채널 화면에는 옛 이름이 잠시 남아 있었다(반영 지연). 다음은 R1을 이 채널 쇼츠로 올리기.
- **2026-10-27** code404.app 홈을 회사 소개 사이트로 새로 만들어 올렸다(`~/Developer/code404-site`의 `index.html`·`home.css`, 한국어·영어). 첫 화면 "찾을 수 없던 것을 만듭니다", 하는 일·일하는 방식, 만든 것(포자 대청소·캣타워, 곧 출시), 연락. 기존 `/sporesweep/`, 개인정보 처리방침, `app-ads.txt` 주소는 그대로다. 웹판은 광고 없이 보상을 주는 문제가 있어 사이트에서 "웹에서 해 보기" 링크를 뺐다(계정 주인 결정). 두 웹판(`play.code404.app`, `cattower.code404.app`)은 주소를 아는 사람만 들어오게 그대로 둔다. 캣타워의 처리방침은 `cattower.code404.app/privacy/`에 있어 웹판을 지우면 안 된다.
- **2026-10-27** 릴스 R1 복원 편을 인스타그램 `code404.app` 계정에 올렸다(Claude in Chrome, 표지는 복원된 숭례문, 설명 글은 `Marketing/promo/README.md`의 초안). 크롬 파일 올리기는 10MB까지라 `R1_restore_upload.mp4`(3.8Mbps로 다시 압축, 7.7MB)를 올렸다. 유튜브 쇼츠는 업로드 전에 YouTube가 본인 인증을 요구해 멈췄다(계정 주인이 해야 한다). R2 예고편은 며칠 뒤 올린다. 인스타 프로필 사진을 CI 심볼(네모 판, `code404_symbol_square_1024.png`)로 넣었다.
- **2026-10-26** code404.app에 새 CI를 넣었다(로고, 파비콘, 아이폰 홈 아이콘, 공유 그림, 사이트 색을 남색·보라로). Claude in Chrome으로 Cloudflare Pages(`code404-site`, 프로덕션)에 직접 올렸고 code404.app에 반영된 것을 확인했다. 올린 묶음은 `~/Developer/code404-site.zip`(작업 폴더 안 사본 `Marketing/code404-site.zip`). 파일 올리기 도구는 작업 폴더 안의 파일만 올릴 수 있다. 릴스 초안 두 편(`Marketing/promo/R1_restore.mp4`, `R2_teaser.mp4`)을 `Tools/make_reels.py`로 만들었다. 자막 글꼴은 Pretendard ExtraBold이고, 동호회 이야기는 빼고 "테스터 한마디"로 풀었다(계정 주인 요청). 소리는 크기만 확인했고 들어 보지 못했다.
- **2026-10-26** 회사 code404(개인사업자 등록 중)의 CI를 만들어 비공개 저장소 `code404-brand`(`~/Developer/code404-brand`)에 올렸다. KIPRIS에서 code404·코드404는 국내 0건(일본에 "404"가 든 다른 상표 20건). 글자만으로는 식별력 거절 가능성이 있어 출원은 로고 결합상표로 권했다. 홍보 릴스는 인스타그램과 유튜브 쇼츠에 낸다(제작기 + 플레이 장면, 아직 만들지 않음). iOS 심사는 정보 요청에 답장한 뒤 기다리는 중.
- **2026-10-25** Apple이 "Guideline 2.1 - Information Needed"(처음 내는 개발자 계정이라 앱 설명과 실기기 녹화를 달라는 요청, 거절 아님)를 보냈다. 답장 글(영어)은 `Marketing/store/APP_REVIEW_REPLY.md`, 녹화는 `Marketing/store/app_review_recording.mov`(TestFlight 1.0 (2), 아이폰 15 Pro Max). 녹화는 아이폰 미러링을 Claude가 조작하고, 그 창만 ScreenCaptureKit으로 찍었다(`screencapture -R`로 영역을 찍으면 겹친 다른 창이 찍힌다). 같은 내용을 버전의 "앱 심사 정보 → 메모"에 넣었다(2,669자, 사용자의 크롬에서 Claude in Chrome으로). 계정 주인이 답장(글과 영상)을 보냈다. 이제 심사 결과를 기다린다. 광고 조사 때 아이폰에 개발용 빌드를 직접 깔아 TestFlight 판을 덮어썼던 것을 TestFlight로 다시 깔았다.
- **2026-10-25** **iOS 1.0 (빌드 2)을 App Store 심사에 제출했다(상태: 심사 대기 중).** 승인되면 자동으로 공개된다. 제출 전에 확인한 것: 스크린샷 6장(1206×2622로 맞춘 `Marketing/store/ko_1206`, 순서 01~06), 앱 개인정보 6개 항목 게시(분석·제3자 광고, 사용자와 연결 안 됨, 추적 안 함), 콘텐츠 권한 "타사 콘텐츠 없음", 연령 등급 4+, 심사 연락처, 영어 쪽 개인정보 처리방침 URL(빠져 있어 제출이 막혔다). TestFlight 1.0 (2)에서 광고가 되는 것을 계정 주인이 확인했다. EU 디지털 서비스법은 계정 주인이 "비거래자"로 신고했다(광고 수익이 있어 나중에 다시 볼 수 있다). 개인정보 처리방침 페이지에는 영어 전문이 이미 들어 있다(같은 페이지의 `#en`). App Store의 영어 쪽 처리방침 URL은 `https://code404.app/sporesweep/privacy/#en`으로 바꿨다(심사 중에도 바꿀 수 있었다).
- **2026-10-25** App Store Connect(앱 ID 6826591259)를 내장 브라우저로 채웠다: 한국어 부제, 1.0 버전의 한국어·영어 홍보 문구·설명·키워드·지원 URL·마케팅 URL, 저작권 `2026 code404`, 심사 메모, "로그인 필요" 끔. 이미 되어 있던 것: 카테고리(게임·퍼즐·캐주얼), 영어 이름·부제, 무료, 중국 본토 제외, 개인정보 처리방침 URL. 신고 항목(콘텐츠 권한, 앱 개인정보 데이터 유형, 연령 등급, EU 거래자 신고, 심사 제출)은 계정 주인이 직접 한다(자동 모드가 대신 답하는 것을 막는다). **앱 개인정보가 "데이터가 수집되지 않음"으로 되어 있어 고쳐야 한다**(`Marketing/store/STORE_LISTING.md`의 "앱 개인정보 신고" 표). 스크린샷은 내장 브라우저로 파일을 올릴 수 없어 계정 주인이 올린다. 1.0 (2)가 처리되면 버전에 빌드를 고른다.
- **2026-10-24** TestFlight 1.0 (1)을 아이폰에서 확인했다. 광고만 "광고를 불러오지 못했어요"가 떴다. 같은 아이폰에서 개발용 빌드는 시험 광고를 잘 불러온다. 앱이 TestFlight인지 알아내지 못해 실제 광고 단위(출시 전이라 광고가 없다)를 쓴 것으로 본다. TestFlight 확인에 영수증 이름(`sandboxReceipt`)을 더하고, 스토어 판이 아니면 실패 화면에 쓴 단위와 오류를 작게 보여 주게 했다. 빌드 번호를 2로 올렸다. 오늘의 선물 창은 받은 뒤 "내일 또 만나요!"를 한 번 더 누르는 지금 방식을 유지하기로 했다.
- **2026-10-24** Apple 멤버십이 열렸다(팀 ID는 그대로, Individual). 계정 주인이 번들 ID `app.code404.sporesweep`를 등록하고 App Store Connect에 앱(포자 대청소, SKU `sporesweep`)을 만들어 Xcode 화면에서 1.0 (1)을 TestFlight에 올렸다. 명령줄 `xcodebuild archive -allowProvisioningUpdates`는 "No Accounts"로 실패했다(Xcode 계정을 쓰지 못한다). 다음 올리기도 Xcode 화면에서 하거나, App Store Connect API 키를 만들어 명령줄로 한다.
- **2026-10-24** 출시용 Firebase 프로젝트 `sporesweep-7943b`의 iOS 파일을 넣었다(`SporeSweep/GoogleService-Info.plist`, 번들 `app.code404.sporesweep`). 앱에 들어간 것은 확인했지만, 이 맥의 DNS가 `app-analytics-services.com`을 막아 기록 도착은 확인하지 못했다. 안드로이드 파일은 아직이다.
- **2026-10-24** 번들 ID와 안드로이드 앱 ID를 회사 도메인에 맞춰 `app.code404.sporesweep`로 바꿨다(코드의 패키지 이름은 그대로). 예전 ID로 등록한 개발용 Firebase 파일은 저장소 밖으로 옮겼다. 출시용 Firebase와 App Store Connect, Play Console의 새 앱은 새 ID로 만든다.
- **2026-10-24** Apple 개발자 계정이 열려 iOS 출시를 시작했다. 출시 범위를 한국과 해외(중국 본토 제외)로 넓히고, 위험이 높은 랜드마크 7곳의 이름을 일반 이름으로 바꿨다(기획서 v0.41, PLAN.md, RIGHTS_CHECK.md, 스토어 문구). iOS 앱 버전을 1.0으로 올렸다. 출시용 Firebase 프로젝트를 새로 만들기로 했다.
- **2026-10-22** 안드로이드 출시 시작. versionCode 3(versionName 0.2)으로 올리고 비공개 테스트용 번들(시험 광고)을 만들었다. 개인 계정이라 프로덕션 전에 비공개 테스트 12명×14일이 필요하다.
- **2026-10-21** 인수인계 문서(이 문서)와 `CLAUDE.md`를 만들었다. 앞으로 모든 작업은 이 문서를 고치며 한다.
- **2026-10-20** README에 mods판 설치 방법을 넣었다. mods판 배포용 공개 저장소 `sporesweep-mod`를 만들었다.
- **2026-10-20** mods판 화면을 고쳤다: 이모지 블록, 끌어서 바꾸기, 범례, 이어하기, 잠긴 도시 숨기기, 6초 뒤 힌트 깜박임. 범례가 보드 쪽 글을 줄바꿈시켜 두 칸 아래가 골라지던 것을 고쳤다.
- **2026-10-20** 380레벨을 무작위 시작 보드로 다시 쟀다. 276개가 5~20수 줄었다. 기준 기록을 다시 만들고 mods용 JS 엔진도 시험에 넣었다. 웹판을 다시 올렸다.
- **2026-10-20** 2×2 매치와 청소 드론, 판마다 무작위 시작(v0.40). 드론 그림(Codex)과 효과음(ElevenLabs). 첫 mods판.
- **2026-10-20** 웹판(Kotlin/Wasm)을 만들어 `play.code404.app`에 올렸다. Firebase 웹 기록.
- **2026-10-14~16** 안드로이드판: Firebase, AdMob, 업로드 키 서명, Play용 그림. `code404.app`에 개인정보 처리방침.
