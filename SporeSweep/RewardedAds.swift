import GoogleMobileAds
import StoreKit
import UIKit

/// 보상형 광고를 불러오고 보여준다(6장). 광고 SDK(AdMob)는 이 파일에서만 부른다.
///
/// 광고는 미리 하나 불러 두고, 보여주고 나면 다음 것을 다시 불러 둔다.
/// 앱 ID(`GADApplicationIdentifier`)와 실제 광고 단위 ID(`RewardedAdUnitID`)는 `SporeSweep-Info.plist`에 있다.
@MainActor
final class RewardedAds: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAds()

    /// 광고가 끝났을 때의 결과.
    enum Outcome {
        /// 끝까지 봐서 보상을 받는다.
        case rewarded
        /// 보다가 닫았다.
        case skipped
        /// 광고를 띄우지 못했다.
        case failed
    }

    /// 실제 광고를 쓰는지. 디버그 빌드에서 실행 인자 `-fakeAds 1`을 주면 자리 표시 광고만 쓴다.
    static let isEnabled: Bool = {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "fakeAds") { return false }
        #endif
        return realUnitID != nil
    }()

    /// AdMob에 등록한 실제 광고 단위.
    private static let realUnitID = Bundle.main.object(forInfoDictionaryKey: "RewardedAdUnitID") as? String
    /// 구글이 공개한 시험용 광고 단위. 시험 광고만 나오고 수익은 없다.
    private static let testUnitID = "ca-app-pub-3940256099942544/1712485313"

    /// 이 빌드가 쓸 광고 단위를 고른다. App Store에서 받은 앱만 실제 단위를 쓴다.
    ///
    /// 디버그 빌드와 TestFlight 빌드는 시험용 단위를 쓴다. 개발하거나 시험하면서 실제 광고를 보거나 누르면
    /// 무효 트래픽으로 계정이 정지될 수 있기 때문이다.
    private static func chooseUnitID() async -> String? {
        #if DEBUG
        return testUnitID
        #else
        guard let result = try? await AppTransaction.shared else {
            // 어디서 받은 앱인지 알 수 없으면 실제 단위를 쓴다. 출시한 앱에 시험 광고가 나가는 쪽이 더 나쁘다.
            return realUnitID
        }
        let transaction: AppTransaction
        switch result {
        case let .verified(value): transaction = value
        case let .unverified(value, _): transaction = value
        }
        return transaction.environment == .production ? realUnitID : testUnitID
        #endif
    }

    private var unitID: String?
    /// 광고 단위를 아직 고르는 중인지.
    private var isPreparing = false
    private var ad: RewardedAd?
    private var isLoading = false
    private var earned = false
    private var onFinish: ((Outcome) -> Void)?

    /// 앱을 시작할 때 한 번 부른다.
    func start() {
        guard Self.isEnabled else { return }
        MobileAds.shared.start()
        isPreparing = true
        Task {
            unitID = await Self.chooseUnitID()
            isPreparing = false
            load()
        }
    }

    /// 보여줄 광고가 준비됐는지.
    var isReady: Bool { ad != nil }

    /// 광고 하나를 불러 둔다. 이미 있거나 부르는 중이면 아무것도 하지 않는다.
    func load() {
        guard Self.isEnabled, let unitID, ad == nil, !isLoading else { return }
        isLoading = true
        Task {
            do {
                ad = try await RewardedAd.load(with: unitID, request: Request())
                note("불러옴")
            } catch {
                note("불러오지 못함: \(error.localizedDescription)")
            }
            ad?.fullScreenContentDelegate = self
            isLoading = false
        }
    }

    /// 준비될 때까지 잠깐 기다린다.
    /// - Returns: 준비됐으면 참.
    func waitUntilReady(seconds: Double) async -> Bool {
        load()
        let end = Date.now.addingTimeInterval(seconds)
        while ad == nil, isLoading || isPreparing, Date.now < end {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return ad != nil
    }

    /// 불러 둔 광고를 화면 위에 띄운다. 끝나면 결과를 알린다.
    func show(onFinish: @escaping (Outcome) -> Void) {
        guard let ad else {
            note("띄울 광고가 없음")
            onFinish(.failed)
            return
        }
        self.ad = nil
        self.onFinish = onFinish
        earned = false
        note("띄움")
        ad.present(from: makeStage()) { [weak self] in
            self?.note("보상 받음")
            self?.earned = true
        }
    }

    /// 광고를 띄울 창. 광고가 떠 있는 동안에만 있다.
    private var stage: UIWindow?

    /// 광고만 띄울 빈 창을 게임 화면 위에 하나 만든다.
    ///
    /// 게임 화면에서 바로 띄우면 광고가 덮는 동안 게임 화면이 사라졌다가 다시 나타난 것으로 처리된다.
    /// 그러면 화면이 나타날 때 하는 일(판을 새로 시작하기, 광고 다시 부르기)이 광고를 닫을 때 또 돌아간다.
    private func makeStage() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.windowLevel = .normal + 1
        window.makeKeyAndVisible()
        stage = window
        return root
    }

    /// 디버그 빌드에서 광고가 어디까지 갔는지 콘솔에 적는다.
    private func note(_ text: String) {
        #if DEBUG
        print("[광고] \(text)")
        #endif
    }

    private func finish(_ outcome: Outcome) {
        let handler = onFinish
        onFinish = nil
        // 광고의 창을 치우고 게임의 창으로 돌아간다.
        stage?.isHidden = true
        stage = nil
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { !$0.isHidden }?
            .makeKey()
        handler?(outcome)
        // 다음에 볼 것을 미리 불러 둔다.
        load()
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        note(earned ? "닫음, 보상 있음" : "닫음, 보상 없음")
        finish(earned ? .rewarded : .skipped)
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        note("띄우지 못함: \(error.localizedDescription)")
        finish(.failed)
    }
}
