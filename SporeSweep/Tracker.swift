import FirebaseAnalytics
import FirebaseCore
import Foundation

/// 플레이 기록을 측정 도구(Firebase Analytics)로 보낸다(10장).
///
/// 게임 코드는 Firebase를 직접 부르지 않고 여기에 사건만 알린다. 측정 도구를 바꿔도 이 파일만 고치면 된다.
/// 디버그 빌드에서는 보내지 않고 콘솔에만 적는다. 실행 인자 `-analytics 1`을 주면 디버그 빌드에서도 보낸다.
enum Tracker {
    /// 기록할 사건.
    enum Event {
        /// 인트로를 끝까지 봤거나 건너뛰었다.
        case introDone
        /// 판을 시작했다.
        case levelStart(city: String, level: Int, boosters: Int, seed: Int)
        /// 판이 끝났다. `result`는 won, lost, quit 가운데 하나다.
        case levelEnd(city: String, level: Int, result: String, stars: Int, score: Int, movesLeft: Int, materialsLeft: Int, continued: Bool)
        /// 이동을 다 써서 이어 할지 물었다.
        case continueOffer(city: String, level: Int, materialsLeft: Int)
        /// 광고를 다 보고 보상을 받았다. `reward`는 life, moves, tool_이름 가운데 하나다.
        case adReward(reward: String)
        /// 광고를 보다가 닫았다.
        case adSkip(reward: String)
        /// 광고를 불러오거나 띄우지 못했다.
        case adFail(reward: String)
        /// 생명이 다 떨어졌다.
        case livesOut
        /// 판 안에서 아이템을 썼다.
        case toolUse(tool: String, city: String, level: Int)
        /// 일일 보상을 받았다.
        case dailyGift(day: Int)
        /// 랜드마크의 부위를 복원했다.
        case landmarkRestore(city: String, part: String, completed: Bool)
        /// 도시의 레벨을 처음으로 모두 클리어했다.
        case cityClear(city: String)
        /// 엔딩 화면이 떴다. 마지막 레벨을 깨고 처음 본 것이면 `first`가 참이고, 설정에서 다시 본 것이면 거짓이다.
        case ending(first: Bool)

        var name: String {
            switch self {
            case .introDone: "intro_done"
            case .levelStart: "level_start"
            case .levelEnd: "level_end"
            case .continueOffer: "continue_offer"
            case .adReward: "ad_reward"
            case .adSkip: "ad_skip"
            case .adFail: "ad_fail"
            case .livesOut: "lives_out"
            case .toolUse: "tool_use"
            case .dailyGift: "daily_gift"
            case .landmarkRestore: "landmark_restore"
            case .cityClear: "city_clear"
            case .ending: "ending"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .introDone, .livesOut:
                [:]
            case let .levelStart(city, level, boosters, seed):
                ["city": city, "level": level, "boosters": boosters, "seed": seed]
            case let .levelEnd(city, level, result, stars, score, movesLeft, materialsLeft, continued):
                [
                    "city": city, "level": level, "result": result, "stars": stars, "score": score,
                    "moves_left": movesLeft, "materials_left": materialsLeft, "continued": continued ? 1 : 0,
                ]
            case let .continueOffer(city, level, materialsLeft):
                ["city": city, "level": level, "materials_left": materialsLeft]
            case let .adReward(reward), let .adSkip(reward), let .adFail(reward):
                ["reward": reward]
            case let .toolUse(tool, city, level):
                ["tool": tool, "city": city, "level": level]
            case let .dailyGift(day):
                ["day": day]
            case let .landmarkRestore(city, part, completed):
                ["city": city, "part": part, "completed": completed ? 1 : 0]
            case let .cityClear(city):
                ["city": city]
            case let .ending(first):
                ["first": first ? 1 : 0]
            }
        }
    }

    /// 측정 도구로 보내는지. 디버그 빌드에서는 실행 인자를 줘야 보낸다.
    private static let sends: Bool = {
        // 설정 파일이 없으면 Firebase가 앱을 멈추므로 보내지 않는다.
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return false }
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "analytics")
        #else
        return true
        #endif
    }()

    /// 앱을 시작할 때 한 번 부른다.
    static func start() {
        guard sends else { return }
        FirebaseApp.configure()
    }

    /// 사건 하나를 기록한다.
    static func log(_ event: Event) {
        guard sends else {
            #if DEBUG
            print("[기록] \(event.name) \(event.parameters)")
            #endif
            return
        }
        Analytics.logEvent(event.name, parameters: event.parameters.isEmpty ? nil : event.parameters)
    }
}
