# 안드로이드 이식 진행표

iOS 판(Swift)을 Kotlin으로 옮긴다. 단계마다 **자동으로 확인하는 고리**를 먼저 만들고, 그 고리가 통과할 때까지 고친다.
규칙의 기준은 늘 iOS 판이다. 규칙을 바꿀 때는 Swift를 먼저 고치고 기준 기록을 다시 만든 뒤 Kotlin을 맞춘다.

## 확인하는 고리

| 고리 | 명령 | 통과 조건 |
| --- | --- | --- |
| 규칙 동치 | `cd android && ./gradlew :core:allTests` | Swift가 둔 판(399레벨, 15,302수)을 다시 두고, 수마다 이벤트·점수·보드·난수 상태가 글자 하나까지 같다. JVM과 웹(Wasm, Node) 양쪽에서 돈다 |
| 기준 기록 다시 만들기 | `cd LevelData && swift run -c release paritygen ../android/core/src/commonTest/resources/parity 40` 후 `gzip -9 -f ../android/core/src/commonTest/resources/parity/*.txt` | 규칙을 바꿨을 때만 |
| 진행 저장 | `./gradlew :core:allTests` | Swift 판의 진행 시험 33개를 옮긴 것이 통과한다(파일 위치를 보는 iOS 전용 시험 1개는 뺐다) |
| 앱 빌드 | `./gradlew :app:assembleDebug` | 경고 없이 빌드된다 |
| 화면 비교 | 에뮬레이터와 iOS 시뮬레이터를 같은 실행 인자로 띄워 찍고 나란히 본다 | 배치와 그림이 같다 |

## 단계

| # | 단계 | 상태 | 완료 조건 |
| --- | --- | --- | --- |
| 1 | 규칙 엔진(GameCore, 레벨 읽기) | **끝** | 규칙 동치 통과 |
| 2 | 진행 저장(Progress: 별, 생명, 일일 보상) | **끝** | Swift 시험 34개를 옮겨 통과 |
| 3 | 앱 뼈대: 앱 모듈, Compose, 그림·소리·레벨을 iOS 폴더에서 가져오기, 에뮬레이터에서 실행 | **끝** | 빈 화면이 아니라 타이틀이 뜬다 |
| 4 | 보드(GameScene): 블록 그리기, 이벤트를 차례로 재생하는 애니메이션, 밀기 입력, 특수 효과 | **끝** | 한 판을 끝까지 둘 수 있고, iOS와 화면을 나란히 놓고 비교 |
| 5 | 화면: 타이틀·인트로, 도시, 지도·세계·비행, 랜드마크 복원, 결과, 설정, 엔딩, 생명, 일일 보상, 아이템 | **끝**. 화면마다 iOS와 나란히 찍어 비교했다 | 각 화면을 iOS와 나란히 놓고 비교 |
| 6 | 소리, 음악, 진동 | **끝**. 귀로는 확인하지 못했다 | 이벤트마다 같은 소리가 난다 |
| 7 | 광고(AdMob), 측정(Firebase), 영어 | **끝**. 실기기(Lenovo 태블릿 TB320FC, Android 15)에서 시험 광고 세 곳의 보상까지 확인했다(2026-10-14). 실제 AdMob ID는 `config.properties`에 넣었고 출시용 빌드만 실제 광고 단위를 쓴다. Firebase(sporesweep-dev)도 붙여 패드에서 `level_start`·`level_end`가 올라가는 것을 확인했다(2026-10-14) | 시험 광고가 뜨고 기록이 찍힌다 |
| 8 | 출시 준비: 아이콘, 서명, Google Play 등록 자료 | 진행 중. Google Play 개발자 계정을 만들었고(2026-10-16) 업로드 키를 만들었다. 남은 것: 앱 만들기와 비공개 테스트 트랙에 첫 번들 올리기, 스토어 등록정보와 그림(`Marketing/store/STORE_LISTING.md`), 데이터 보안 설문, 콘텐츠 등급, 실기기에서 소리·진동 확인 | 내부 테스트 트랙에 올라간다 |

## iOS와 다른 점

- **저장**: iCloud 대신 기기 안에만 저장한다.
- **값과 참조**: Swift의 `GameState`는 값 타입이다. Kotlin에서는 공개 함수가 `copy()`로 복사본을 만들어 고친 뒤 돌려준다. 원래 상태는 바뀌지 않는다.
- **이름**: Swift의 `Block.cocoon(kind)`, `Block.frozen(kind)`는 Kotlin에서 `Cocoon(trapped)`, `Frozen(trapped)`다. 이 둘의 종류는 매치에 쓰이지 않기 때문이다.
- **그리기**: SpriteKit 대신 `stage/Stage.kt`의 작은 엔진을 쓴다. 노드와 동작(SKAction)의 이름과 뜻이 SpriteKit과 같고, 좌표도 y가 위쪽인 dp라서 `BoardScene.swift`를 거의 줄 단위로 옮길 수 있다.

## 실행과 설정

```bash
cd android && ./gradlew :app:assembleDebug
```

- **개발용 실행 인자**는 iOS 판과 이름이 같다. `adb shell am start -n dev.code404.sporesweep/.MainActivity --es city tokyo --ei level 2 --ez autoplay true`처럼 준다. 디버그 빌드에서만 읽는다.
- **광고 ID**: `android/config.properties`에 `ADMOB_APP_ID`, `REWARDED_AD_UNIT_ID`를 적는다(저장소에 올리지 않는다). 없으면 구글 시험용 ID다. 디버그 빌드는 늘 시험 광고이고, 출시 빌드는 실제 광고다. 내부 테스트 트랙에 올릴 빌드는 `./gradlew :app:bundleRelease -PtestAds`로 만들어 시험 광고만 나오게 한다.
- **업로드 키**: `~/Developer/keys/sporesweep-upload.jks`(저장소 밖, 별칭 `upload`). 비밀번호는 맥 키체인의 `sporesweep-upload-key`에 있고 빌드할 때만 읽는다. `config.properties`의 `UPLOAD_KEYSTORE`에 위치를 적으면 출시 빌드가 이 키로 서명되고, 없으면 개발용 열쇠로 서명된다. 앱 서명 키는 Google Play가 맡는다(Play 앱 서명). 업로드 키를 잃어버려도 Play Console에서 바꿀 수 있지만, 키 파일과 비밀번호는 따로 백업해 둔다.
- **올릴 번들**: 비공개 테스트용은 `./gradlew :app:bundleRelease -PtestAds`(시험 광고), 정식 출시용은 `-PtestAds` 없이. 올릴 때마다 `versionCode`를 하나씩 올린다.
- **광고 식별자**: iOS 판처럼 쓰지 않는다. 광고 SDK와 Firebase가 넣는 `AD_ID` 권한을 매니페스트에서 뺐다.
- **Firebase**: `android/app/google-services.json`을 넣으면 붙는다(저장소에 올리지 않는다). 화면 자동 기록은 iOS처럼 껐다. 디버그 빌드는 실행 인자 `--ez analytics true`를 줄 때만 보낸다(켜고 끈 값이 다음 실행까지 남으므로 매번 분명히 정한다). DebugView로 보려면 `adb shell setprop debug.firebase.analytics.app dev.code404.sporesweep`.
- **랜드마크 영역**: iOS의 랜드마크 그림이나 영역을 바꾸면 `Tools/landmark_export.sh`를 다시 돌린다.
- **광고 시험**: 개발용 빌드의 설정 화면에 "광고 시험" 칸이 있다. 생명 비우기, 아이템 비우기, 이동 2번으로 시작.
- **실기기 연결**: 무선 디버깅으로 붙인다. 처음 한 번 `adb pair 주소:포트 코드`로 페어링하면, 그 뒤로는 같은 와이파이에서 자동으로 연결된다.
- **시작 시간**: 레벨 파일은 도시를 열 때 읽는다. 에뮬레이터에서 출시 빌드가 약 3초에 뜬다(디버그 빌드는 더 느리다).
