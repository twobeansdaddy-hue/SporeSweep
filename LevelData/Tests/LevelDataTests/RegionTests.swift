import Testing
@testable import LevelData

@Suite("권역")
struct RegionTests {
    @Test("권역은 여덟 곳이고 첫 권역은 동아시아다")
    func catalog() {
        #expect(RegionCatalog.all.count == 8)
        #expect(Set(RegionCatalog.all.map(\.id)).count == 8)
        #expect(RegionCatalog.all[0].name == "동아시아")
        #expect(RegionCatalog.all[0].cityIDs == ["seoul", "tokyo", "beijing"])
    }

    @Test("권역의 도시를 이으면 도시가 열리는 순서와 같다")
    func cityOrder() {
        #expect(RegionCatalog.cityIDs == LevelCatalog.cityIDs)
        #expect(RegionCatalog.region(ofCity: "tokyo")?.id == "eastasia")
        #expect(RegionCatalog.region(ofCity: "nowhere") == nil)
    }

    @Test("도시가 있는 권역은 지도와 모든 도시의 자리가 있다")
    func playableRegionsAreComplete() {
        for region in RegionCatalog.all where region.isPlayable {
            #expect(!region.mapImage.isEmpty)
            #expect(region.cityIDs.allSatisfy { region.cityPositions[$0] != nil })
        }
    }

    @Test("자리는 모두 그림 안에 있다")
    func spotsAreInsideTheImage() {
        for region in RegionCatalog.all {
            let spots = [region.worldSpot] + Array(region.cityPositions.values) + region.planned.map(\.spot)
            #expect(spots.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) }, "\(region.id)")
        }
    }

    @Test("남아시아는 뉴델리, 방콕, 싱가포르다")
    func southAsia() {
        let region = RegionCatalog.all[1]
        #expect(region.name == "남아시아")
        #expect(region.cityIDs == ["newdelhi", "bangkok", "singapore"])
        #expect(region.mapImage == "map_south_asia")
        #expect(region.planned.isEmpty)
        #expect(RegionCatalog.region(ofCity: "newdelhi")?.id == "southasia")
    }
}
