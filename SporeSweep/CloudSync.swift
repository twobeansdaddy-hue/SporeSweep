import Foundation
import Progress

/// 진행을 iCloud에 올리고 내려받는다(10장).
///
/// iCloud 키-값 저장소에 진행 전체를 JSON 하나로 둔다. 크기가 작아서(수십 KB) 한도 안에 든다.
/// 앱에 iCloud 권한이 없거나 기기가 iCloud에 로그인하지 않았으면 저장소가 아무 일도 하지 않으므로,
/// 그때는 기기에만 저장되는 지금까지의 동작 그대로다.
@MainActor
final class CloudSync {
    private static let key = "progress"
    static let enabledKey = "iCloudEnabled"
    private let store = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    /// 켜져 있는지. 설정에서 끌 수 있고, 처음에는 켜져 있다.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    /// iCloud에 있는 진행. 없거나 읽을 수 없으면 `nil`이다.
    func pull() -> GameProgress? {
        guard isEnabled else { return nil }
        store.synchronize()
        guard let data = store.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(GameProgress.self, from: data)
    }

    func push(_ progress: GameProgress) {
        guard isEnabled, let data = try? JSONEncoder().encode(progress) else { return }
        store.set(data, forKey: Self.key)
    }

    /// 다른 기기에서 진행이 바뀌면 알려 준다.
    func observe(_ onChange: @escaping @MainActor (GameProgress) -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if let remote = self?.pull() {
                    onChange(remote)
                }
            }
        }
    }
}
