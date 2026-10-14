// 안드로이드 판에 쓸 랜드마크 그림 데이터를 뽑는다.
//
// iOS 판의 LandmarkView.swift와 LandmarkTiers.swift를 그대로 함께 빌드해, 부위의 영역(Path)을 1×1 크기에서
// 그려 보고 그 경로를 JSON으로 적는다. 영역을 손으로 옮기지 않으므로 두 판의 영역이 정확히 같다.
//
// 사용법: Tools/landmark_export.sh

import Foundation
import SwiftUI

/// LandmarkView.swift가 쓰는 색. 영역을 뽑는 데는 쓰이지 않는다.
enum Palette {
    static let material = Color.pink
}

@MainActor
func export() throws {
    func commands(_ path: Path) -> [[Double]] {
        // [0, x, y] 이동, [1, x, y] 직선, [2, x1, y1, x2, y2, x, y] 3차 곡선, [3, cx, cy, x, y] 2차 곡선, [4] 닫기
        var out: [[Double]] = []
        path.forEach { element in
            switch element {
            case .move(let p): out.append([0, p.x, p.y])
            case .line(let p): out.append([1, p.x, p.y])
            case .curve(let p, let c1, let c2): out.append([2, c1.x, c1.y, c2.x, c2.y, p.x, p.y])
            case .quadCurve(let p, let c): out.append([3, c.x, c.y, p.x, p.y])
            case .closeSubpath: out.append([4])
            }
        }
        return out
    }
    let unit = CGSize(width: 1, height: 1)
    var cities: [String: Any] = [:]
    // LevelData의 LevelCatalog.cityIDs와 같은 순서다.
    let cityIDs = ["seoul", "tokyo", "beijing", "newdelhi", "bangkok", "singapore", "cairo", "dubai", "capetown",
        "rome", "athens", "barcelona", "paris", "london", "amsterdam", "newyork", "sanfrancisco", "washington",
        "rio", "buenosaires", "easterisland", "sydney", "auckland", "antarctica"]
    for id in cityIDs {
        guard let art = LandmarkArt.art(for: id) else { continue }
        cities[id] = [
            "prefix": art.prefix,
            "horizon": art.horizon,
            "parts": art.parts.map { part -> [String: Any] in
                var item: [String: Any] = ["id": part.id, "region": commands(part.region(unit))]
                if let hole = part.hole { item["hole"] = commands(hole(unit)) }
                return item
            },
            "spores": art.spores.map {
                ["x": $0.x, "y": $0.y, "radius": $0.radius, "degrees": $0.degrees, "part": $0.part, "shape": $0.shape] as [String: Any]
            },
        ]
    }
    let data = try JSONSerialization.data(withJSONObject: cities, options: [.sortedKeys, .prettyPrinted])
    let out = URL(fileURLWithPath: CommandLine.arguments[1])
    try data.write(to: out)
    print("랜드마크 \(cities.count)곳을 \(out.path)에 적었다")
}

@main
struct LandmarkExport {
    @MainActor
    static func main() throws {
        try export()
    }
}
