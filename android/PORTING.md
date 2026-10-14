# 안드로이드 이식 진행표

iOS 판(Swift)을 Kotlin으로 옮긴다. 단계마다 **자동으로 확인하는 고리**를 먼저 만들고, 그 고리가 통과할 때까지 고친다.
규칙의 기준은 늘 iOS 판이다. 규칙을 바꿀 때는 Swift를 먼저 고치고 기준 기록을 다시 만든 뒤 Kotlin을 맞춘다.

## 확인하는 고리

| 고리 | 명령 | 통과 조건 |
| --- | --- | --- |
| 규칙 동치 | `cd android && ./gradlew :core:test` | Swift가 둔 판(399레벨, 15,302수)을 다시 두고, 수마다 이벤트·점수·보드·난수 상태가 글자 하나까지 같다 |
| 기준 기록 다시 만들기 | `cd LevelData && swift run -c release paritygen ../android/core/src/test/resources/parity 40` 후 `gzip -9 -f ../android/core/src/test/resources/parity/*.txt` | 규칙을 바꿨을 때만 |
| 진행 저장 | `./gradlew :core:test` | Swift 판의 진행 시험 33개를 옮긴 것이 통과한다(파일 위치를 보는 iOS 전용 시험 1개는 뺐다) |
| 앱 빌드 | `./gradlew :app:assembleDebug` | 경고 없이 빌드된다 |
| 화면 비교 | 에뮬레이터와 iOS 시뮬레이터를 같은 실행 인자로 띄워 찍고 나란히 본다 | 배치와 그림이 같다 |

## 단계

| # | 단계 | 상태 | 완료 조건 |
| --- | --- | --- | --- |
| 1 | 규칙 엔진(GameCore, 레벨 읽기) | **끝** | 규칙 동치 통과 |
| 2 | 진행 저장(Progress: 별, 생명, 일일 보상) | **끝** | Swift 시험 34개를 옮겨 통과 |
| 3 | 앱 뼈대: 앱 모듈, Compose, 그림·소리·레벨을 iOS 폴더에서 가져오기, 에뮬레이터에서 실행 | | 빈 화면이 아니라 타이틀이 뜬다 |
| 4 | 보드(GameScene): 블록 그리기, 이벤트를 차례로 재생하는 애니메이션, 밀기 입력, 특수 효과 | | 한 판을 끝까지 둘 수 있고, iOS와 화면을 나란히 놓고 비교 |
| 5 | 화면: 타이틀·인트로, 도시, 지도·세계·비행, 랜드마크 복원, 결과, 설정, 엔딩, 생명, 일일 보상, 아이템 | | 각 화면을 iOS와 나란히 놓고 비교 |
| 6 | 소리, 음악, 진동 | | 이벤트마다 같은 소리가 난다 |
| 7 | 광고(AdMob), 측정(Firebase), 영어 | | 시험 광고가 뜨고 기록이 찍힌다 |
| 8 | 출시 준비: 아이콘, 서명, Google Play 등록 자료 | | 내부 테스트 트랙에 올라간다 |

## iOS와 다른 점

- **저장**: iCloud 대신 기기 안에만 저장한다.
- **값과 참조**: Swift의 `GameState`는 값 타입이다. Kotlin에서는 공개 함수가 `copy()`로 복사본을 만들어 고친 뒤 돌려준다. 원래 상태는 바뀌지 않는다.
- **이름**: Swift의 `Block.cocoon(kind)`, `Block.frozen(kind)`는 Kotlin에서 `Cocoon(trapped)`, `Frozen(trapped)`다. 이 둘의 종류는 매치에 쓰이지 않기 때문이다.
