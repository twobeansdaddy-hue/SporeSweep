import Foundation

/// iCloud에 진행을 올려도 되는지 정한다(10장).
///
/// 앱을 지우고 다시 설치하면 이 기기의 진행은 비어 있고, iCloud의 진행은 조금 뒤에야 내려온다.
/// 그 사이에 빈 진행을 올리면 iCloud의 진행을 덮어쓴다. 그래서 iCloud의 진행을 한 번 보거나
/// 기다릴 만큼 기다리기 전에는 올리지 않고, 올릴 때는 늘 iCloud의 진행과 합친 것을 올린다.
public struct CloudGate: Sendable, Equatable {
    /// 내려오기를 기다리는 가장 긴 시간. 이 뒤에도 소식이 없으면 iCloud에 진행이 없는 것으로 본다.
    public static let maxWait: TimeInterval = 60

    /// 올려도 되는지.
    public private(set) var isOpen: Bool
    private let startedAt: Date

    /// - Parameters:
    ///   - local: 앱을 켤 때 이 기기에 있던 진행.
    ///   - now: 앱을 켠 때.
    public init(local: GameProgress, now: Date) {
        startedAt = now
        // 이미 기록이 있는 기기는 진행을 들고 있으므로 바로 올려도 된다(합쳐서 올리므로 iCloud의 것을 줄이지 않는다).
        isOpen = !local.isEmpty
    }

    /// iCloud의 진행을 받았거나, iCloud에서 바뀌었다는 알림이 왔다.
    public mutating func cloudSeen() {
        isOpen = true
    }

    /// 시간이 지났는지 본다.
    public mutating func tick(now: Date) {
        if now.timeIntervalSince(startedAt) >= Self.maxWait {
            isOpen = true
        }
    }

    /// iCloud에 올릴 진행. 닫혀 있거나 iCloud에 이미 같은 것이 있으면 `nil`이다.
    /// 이 기기의 진행을 iCloud의 진행과 합쳐서, 올리는 쪽이 iCloud의 기록을 줄이지 않게 한다.
    /// iCloud가 충돌을 풀며 이 기기보다 뒤진 진행을 남겼어도, 합친 것이 달라지므로 다시 올린다.
    public func upload(_ local: GameProgress, cloud: GameProgress?) -> GameProgress? {
        guard isOpen else { return nil }
        guard let cloud else { return local }
        let merged = local.merging(cloud)
        // 생명력과 일일 보상은 기기마다 따로라 비교하지 않는다. 그것만 다르면 올리지 않는다.
        return merged.sharesProgress(with: cloud) ? nil : merged
    }
}

extension GameProgress {
    /// 깬 레벨도, 복원한 부위도 없는지. 새로 설치한 기기의 진행이다.
    public var isEmpty: Bool {
        stars.isEmpty && restoredParts.values.allSatisfy(\.isEmpty)
    }
}
