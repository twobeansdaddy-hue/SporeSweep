import Foundation

/// 진행 상황을 JSON 파일로 기기에 저장한다(10장). iCloud 동기화는 앱의 `CloudSync`가 한다.
public struct ProgressStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// 앱의 Application Support 폴더에 있는 기본 저장 파일.
    public static func standard(fileName: String = "progress.json") -> ProgressStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return ProgressStore(url: directory.appendingPathComponent(fileName))
    }

    /// 저장된 진행 상황을 읽는다. 파일이 없으면 빈 진행 상황이다.
    /// 파일이 깨져 읽을 수 없으면 오류를 던진다. 조용히 덮어써서 기록을 잃지 않게 하기 위해서다.
    public func load() throws -> GameProgress {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return GameProgress()
        }
        return try JSONDecoder().decode(GameProgress.self, from: Data(contentsOf: url))
    }

    /// 진행 상황을 저장한다. 쓰는 도중에 앱이 꺼져도 이전 파일이 깨지지 않게 한 번에 바꿔 쓴다.
    public func save(_ progress: GameProgress) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(progress).write(to: url, options: .atomic)
    }

    /// 저장 파일을 지운다.
    public func reset() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
