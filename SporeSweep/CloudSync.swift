import Foundation
import Progress

/// 진행을 iCloud에 올리고 내려받는다(10장).
///
/// iCloud 키-값 저장소에 진행 전체를 JSON 하나로 둔다. 크기가 작아서(수십 KB) 한도 안에 든다.
/// 앱을 지우고 다시 설치해도, 같은 Apple 계정의 다른 기기에서도 진행이 이어진다.
/// 기기가 iCloud에 로그인하지 않았으면 저장소가 아무 일도 하지 않으므로 기기에만 저장된다.
@MainActor
final class CloudSync {
    private static let key = "progress"
    static let enabledKey = "iCloudEnabled"
    private let store = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?
    /// 다시 설치한 기기가 빈 진행으로 iCloud를 덮어쓰지 않게 막는다.
    private var gate: CloudGate?
    /// 이 기기의 가장 최근 진행. 문이 열리거나 iCloud가 바뀌면 이것을 iCloud의 진행과 합쳐 올린다.
    private var latest: GameProgress?

    /// 이 앱에서 iCloud 저장을 쓸 수 있는지. 꺼져 있으면 설정의 스위치를 숨기고 올리지도 내려받지도 않는다.
    static let isAvailable = true

    /// 켜져 있는지. 설정에서 끌 수 있고, 처음에는 켜져 있다.
    var isEnabled: Bool {
        get { Self.isAvailable && (UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    /// 앱을 켤 때 부른다. 이 기기의 진행을 보고 언제부터 올릴지 정한다.
    func start(local: GameProgress) {
        var gate = CloudGate(local: local, now: .now)
        if pull() != nil {
            gate.cloudSeen()
        }
        self.gate = gate
        // 업데이트한 기존 사용자의 진행도 처음 한 번 올린다. 저장할 일이 없어도 다시 설치에 대비한다.
        latest = local
        flush()
        guard !gate.isOpen else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(CloudGate.maxWait))
            self?.gate?.tick(now: .now)
            self?.flush()
        }
    }

    /// iCloud에 있는 진행. 없거나 읽을 수 없으면 `nil`이다.
    func pull() -> GameProgress? {
        guard isEnabled else { return nil }
        store.synchronize()
        guard let data = store.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(GameProgress.self, from: data)
    }

    /// 진행을 올린다. iCloud의 진행과 합친 것을 올리고, 다시 설치한 직후라면 iCloud의 진행을 볼 때까지 미룬다.
    func push(_ progress: GameProgress) {
        latest = progress
        flush()
    }

    private func flush() {
        guard isEnabled, let latest, let gate else { return }
        // iCloud에 무언가 있는데 읽지 못하면 비어 있는 것으로 보지 않는다. 덮어써서 잃지 않게 올리지 않는다.
        store.synchronize()
        let cloud = pull()
        if cloud == nil, store.data(forKey: Self.key) != nil { return }
        guard let upload = gate.upload(latest, cloud: cloud),
              let data = try? JSONEncoder().encode(upload) else { return }
        store.set(data, forKey: Self.key)
    }

    /// iCloud의 진행을 지운다("처음부터 다시 하기").
    func clear() {
        latest = nil
        // iCloud를 비웠으니 기다릴 것이 없다. 진행을 읽지 못해 문이 없던 기기도 이제부터 올린다.
        if gate == nil {
            gate = CloudGate(local: GameProgress(), now: .now)
        }
        gate?.cloudSeen()
        guard isEnabled else { return }
        store.removeObject(forKey: Self.key)
        store.synchronize()
    }

    /// iCloud에서 진행이 바뀌면(다른 기기, 또는 다시 설치한 뒤 처음 내려받을 때) 알려 준다.
    func observe(_ onChange: @escaping @MainActor (GameProgress) -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.gate?.cloudSeen()
                if let remote = self.pull() {
                    onChange(remote)
                }
                // iCloud가 충돌을 풀며 이 기기보다 뒤진 진행을 남겼으면 다시 올린다.
                self.flush()
            }
        }
    }
}
