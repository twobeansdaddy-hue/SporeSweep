import Foundation

/// 레벨 JSON을 읽고 검증한다.
public enum LevelLoader {
    /// JSON 데이터에서 레벨 하나를 읽는다. 형식이 틀리면 `DecodingError`, 값이 틀리면 `LevelError`를 던진다.
    public static func load(_ data: Data) throws -> Level {
        let level = try JSONDecoder().decode(Level.self, from: data)
        try level.validate()
        return level
    }

    public static func load(contentsOf url: URL) throws -> Level {
        try load(Data(contentsOf: url))
    }
}

/// 앱에 들어 있는 레벨 목록.
public enum LevelCatalog {
    /// 도시의 레벨을 순서대로 읽는다. 파일 이름은 `도시-번호.json`이다.
    public static func levels(city: String) throws -> [Level] {
        let urls = (Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(city + "-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map(LevelLoader.load(contentsOf:))
    }

    /// 도시의 ID. 이 순서대로 열린다(8장).
    public static let cityIDs = ["seoul", "tokyo", "beijing", "newdelhi", "bangkok", "singapore", "cairo", "dubai", "capetown",
        "rome", "athens", "barcelona", "paris", "london", "amsterdam",
        "newyork", "sanfrancisco", "washington", "rio", "buenosaires", "easterisland",
        "sydney", "auckland", "antarctica",
    ]

    /// 새 규칙을 시험하는 레벨(5장). 좁은 수거함과 흘러가는 물질을 쓴다. 정식 도시가 아니다.
    public static func lab() throws -> [Level] {
        try levels(city: "lab")
    }

    /// 레벨 생성기로 만든 견본 레벨(9장). 생성기가 만드는 판이 어떤지 해 보기 위한 것이고 정식 도시가 아니다.
    public static func samples() throws -> [Level] {
        try levels(city: "sample")
    }

    /// 첫 도시 서울의 레벨 12개(11장).
    public static func seoul() throws -> [Level] {
        try levels(city: "seoul")
    }

    /// 도시 데이터를 읽고, 그 도시의 레벨 수에 맞는지 검증한다. 파일 이름은 `도시.json`이다.
    public static func city(_ id: String) throws -> City {
        guard let url = Bundle.module.url(forResource: id, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let city = try JSONDecoder().decode(City.self, from: Data(contentsOf: url))
        try city.validate(levelCount: levels(city: id).count)
        return city
    }
}
