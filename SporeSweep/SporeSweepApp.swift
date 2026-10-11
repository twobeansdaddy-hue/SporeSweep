import SwiftUI

@main
struct SporeSweepApp: App {
    @State private var model = AppModel()

    init() {
        Tracker.start()
        RewardedAds.shared.start()
        #if DEBUG
        // 실행 인자 `-heartbeat 1`을 주면 1초마다 화면의 상태를 콘솔에 적는다. 화면이 멈췄을 때 원인을 찾는 데 쓴다.
        if UserDefaults.standard.bool(forKey: "heartbeat") {
            Task { @MainActor in
                var count = 0
                while true {
                    try? await Task.sleep(for: .seconds(1))
                    count += 1
                    let windows = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap(\.windows)
                        .map { "\(type(of: $0))\($0.isKeyWindow ? "*" : "")\($0.isHidden ? "(숨김)" : "") lv\(Int($0.windowLevel.rawValue))" }
                    print("[박동] \(count) \(windows)")
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}
