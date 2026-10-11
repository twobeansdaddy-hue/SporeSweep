import Foundation

/// 권역 하나. 도시 여러 곳을 묶는다(8장).
public struct Region: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// 권역 지도 그림의 이름.
    public var mapImage: String
    /// 이 권역의 도시. 이 순서대로 열린다. 아직 만들지 않은 권역은 비어 있다.
    public var cityIDs: [String]
    /// 권역 지도 위의 도시 자리. 그림의 가로와 세로를 0...1로 본 비율이다.
    public var cityPositions: [String: Spot]
    /// 아직 만들지 않은 도시. 지도에 "준비 중"으로 표시한다.
    public var planned: [Planned]
    /// 세계 지도 위의 권역 자리.
    public var worldSpot: Spot
    /// 권역 지도를 세로 화면에 맞춰 자를 때, 넘치는 폭 가운데 왼쪽에서 잘라낼 비율(0...1).
    public var mapAnchor: Double
    /// 권역을 모두 정화했을 때 세계 지도에서 초록으로 돌아오는 넓이. 그림의 폭을 1로 본 반지름이다.
    public var worldRadius: Double = 0.1

    /// 도시 하나를 정화했을 때 권역 지도에서 초록으로 돌아오는 넓이. 그림의 폭을 1로 본 반지름이다.
    public static let cityRadius: Double = 0.21

    public struct Spot: Hashable, Sendable {
        public var x: Double
        public var y: Double

        public init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Planned: Hashable, Sendable {
        public var name: String
        public var spot: Spot
    }

    /// 도시가 하나도 없는 권역은 아직 준비 중이다.
    public var isPlayable: Bool {
        !cityIDs.isEmpty
    }
}

/// 게임의 권역 목록. 이 순서대로 열린다.
public enum RegionCatalog {
    public static let all: [Region] = [
        Region(
            id: "eastasia", name: "동아시아", mapImage: "map_east_asia",
            cityIDs: ["seoul", "tokyo", "beijing"],
            cityPositions: [
                // 서울은 반도의 서쪽 가운데, 도쿄는 혼슈의 태평양 쪽, 베이징은 보하이만의 북서쪽이다.
                "seoul": .init(0.488, 0.404),
                "tokyo": .init(0.780, 0.540),
                "beijing": .init(0.264, 0.326),
            ],
            planned: [], worldSpot: .init(0.877, 0.39), mapAnchor: 0.58, worldRadius: 0.15
        ),
        Region(
            id: "southasia", name: "남아시아", mapImage: "map_south_asia",
            cityIDs: ["newdelhi", "bangkok", "singapore"],
            cityPositions: [
                // 뉴델리는 히말라야 아래의 평원, 방콕은 타이만의 안쪽 끝, 싱가포르는 말레이반도의 끝이다.
                "newdelhi": .init(0.23, 0.20),
                "bangkok": .init(0.625, 0.345),
                "singapore": .init(0.645, 0.505),
            ],
            planned: [], worldSpot: .init(0.73, 0.50), mapAnchor: 0.5, worldRadius: 0.11
        ),
        Region(
            id: "mideastafrica", name: "중동·아프리카", mapImage: "map_mideast_africa",
            cityIDs: ["cairo", "dubai", "capetown"],
            cityPositions: [
                // 카이로는 아프리카의 북동쪽 끝, 나일강 어귀다. 두바이는 아라비아반도의 페르시아만 쪽이다.
                "cairo": .init(0.58, 0.18),
                "dubai": .init(0.86, 0.30),
                // 케이프타운은 아프리카의 남쪽 끝이다.
                "capetown": .init(0.47, 0.84),
            ],
            planned: [],
            worldSpot: .init(0.54, 0.55), mapAnchor: 0.8, worldRadius: 0.13
        ),
        // 넷째 권역부터는 권역의 첫 도시에만 새 장애물이 나온다.
        Region(
            id: "southeurope", name: "남유럽", mapImage: "map_south_europe",
            cityIDs: ["rome", "athens", "barcelona"],
            cityPositions: ["rome": .init(0.50, 0.40), "athens": .init(0.72, 0.55), "barcelona": .init(0.22, 0.34)],
            planned: [], worldSpot: .init(0.51, 0.37), mapAnchor: 0.25, worldRadius: 0.07
        ),
        Region(
            id: "westeurope", name: "서유럽", mapImage: "map_west_europe",
            cityIDs: ["paris", "london", "amsterdam"],
            cityPositions: ["paris": .init(0.58, 0.58), "london": .init(0.50, 0.40), "amsterdam": .init(0.71, 0.41)],
            planned: [], worldSpot: .init(0.47, 0.28), mapAnchor: 0.7, worldRadius: 0.07
        ),
        Region(
            id: "northamerica", name: "북미", mapImage: "map_north_america",
            // 뉴욕과 워싱턴은 실제로는 훨씬 가깝다. 표시가 겹치지 않게 워싱턴을 조금 더 남서쪽에 찍는다.
            cityIDs: ["newyork", "sanfrancisco", "washington"],
            cityPositions: ["newyork": .init(0.74, 0.33), "sanfrancisco": .init(0.25, 0.44), "washington": .init(0.66, 0.45)],
            planned: [], worldSpot: .init(0.17, 0.33), mapAnchor: 0.38, worldRadius: 0.14
        ),
        Region(
            id: "southamerica", name: "남미", mapImage: "map_south_america",
            cityIDs: ["rio", "buenosaires", "easterisland"],
            cityPositions: ["rio": .init(0.70, 0.52), "buenosaires": .init(0.62, 0.68), "easterisland": .init(0.18, 0.55)],
            planned: [], worldSpot: .init(0.28, 0.68), mapAnchor: 0.38, worldRadius: 0.11
        ),
        Region(
            id: "oceania", name: "오세아니아·극지", mapImage: "map_oceania",
            cityIDs: ["sydney", "auckland", "antarctica"],
            cityPositions: ["sydney": .init(0.72, 0.44), "auckland": .init(0.84, 0.61), "antarctica": .init(0.55, 0.88)],
            planned: [], worldSpot: .init(0.86, 0.74), mapAnchor: 0.75, worldRadius: 0.11
        ),
    ]

    /// 도시가 속한 권역.
    public static func region(ofCity cityID: String) -> Region? {
        all.first { $0.cityIDs.contains(cityID) }
    }

    /// 권역의 도시를 순서대로 이은 것. 도시가 열리는 순서다.
    public static var cityIDs: [String] {
        all.flatMap(\.cityIDs)
    }
}
