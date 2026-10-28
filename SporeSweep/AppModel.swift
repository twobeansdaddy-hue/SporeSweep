import Foundation
import GameCore
import LevelData
import Observation
import Progress

/// 앱 전체가 함께 보는 상태. 도시와 레벨 목록, 진행 상황을 들고, 진행이 바뀔 때마다 파일에 저장한다.
@MainActor
@Observable
final class AppModel {
    /// 지금 고른 도시와 그 레벨. 레벨의 순서가 곧 플레이 순서다.
    private(set) var city: City?
    /// 모든 도시. 이 순서대로 열린다(8장).
    private(set) var cities: [City] = []
    /// 도시 ID → 그 도시의 레벨.
    private var levelsByCity: [String: [Level]] = [:]
    /// 다음 도시로 날아가는 연출을 보여줘야 하면 출발 도시와 도착 도시가 들어 있다. 화면이 보여주고 비운다.
    var pendingFlight: Flight?
    /// 띄운 지도 화면. 없으면 `nil`이다.
    var mapScreen: MapScreen?

    enum MapScreen: Equatable {
        /// 세계 지도. 권역을 고른다.
        case world
        /// 권역 지도. 도시를 고른다.
        case region(String)
    }

    /// 권역 목록. 이 순서대로 열린다.
    /// 권역 목록. 이름은 기기의 언어로 바꿔 둔다.
    let regions: [Region] = RegionCatalog.all.map { region in
        var region = region
        region.name = AppModel.localized(region.name)
        return region
    }

    /// 데이터에 한국어로 적힌 글(도시와 랜드마크의 이름, 레벨 설명)을 기기의 언어로 바꾼다.
    /// 번역이 없으면 그대로다.
    static func localized(_ text: String) -> String {
        Bundle.main.localizedString(forKey: text, value: text, table: nil)
    }

    struct Flight: Equatable {
        var from: String
        var to: String
    }

    /// 다른 권역의 도시로 가는 비행인지. 그런 비행은 세계 지도에서 보여준다.
    func crossesRegions(_ flight: Flight) -> Bool {
        RegionCatalog.region(ofCity: flight.from)?.id != RegionCatalog.region(ofCity: flight.to)?.id
    }

    private static let currentCityKey = "currentCity"
    private(set) var levels: [Level]
    /// 지금 도시의 레벨. 시험판을 보는 동안 `levels`가 바뀌어도 돌아올 수 있게 따로 둔다.
    private var cityLevels: [Level] = []
    /// 새 규칙을 시험하는 레벨을 보고 있는지. 켜면 레벨이 모두 열려 있고 기록은 남지 않는다.
    private(set) var isLabMode = false
    private(set) var progress: GameProgress
    /// 사용자에게 알려야 하는 문제. 데이터나 진행 파일을 읽지 못했을 때 채운다.
    private(set) var problem: String?
    /// 설정에서 인트로를 다시 보겠다고 하면 켜진다. 뼈대 화면이 보고 인트로를 띄운 뒤 끈다.
    var wantsIntro = false
    /// 엔딩을 보여줄 차례인지. 마지막 도시의 레벨을 모두 깼을 때와 설정에서 다시 보겠다고 했을 때 켜진다.
    var wantsEnding = false
    /// 지금 띄우는 엔딩이 마지막 레벨을 깨고 처음 보는 것인지. 설정에서 다시 볼 때는 아니다.
    var isFirstEnding = false
    private static let seenEndingKey = "seenEnding"

    /// 모든 도시의 레벨을 다 깼는지.
    var hasClearedEverything: Bool {
        !cities.isEmpty && cities.allSatisfy { hasClearedAllLevels(cityID: $0.id) }
    }

    /// 게임 전체에서 모은 별과 모을 수 있는 별.
    var totalStars: (earned: Int, total: Int) {
        let ids = cities.flatMap { levelsByCity[$0.id] ?? [] }.map(\.id)
        return (progress.totalStars(in: ids), ids.count * 3)
    }

    /// 다 복원한 랜드마크의 수.
    var restoredLandmarks: Int {
        cities.count { isFullyRestored(cityID: $0.id) }
    }
    /// 방금 클리어한 레벨에서 받은 부스터. 결과 화면이 보여준다.
    private(set) var lastRewards: [Booster] = []
    /// 랜드마크를 방금 다 복원해 선물을 받았는지. 복원 화면이 알리고 끈다.
    var justCompletedLandmark = false
    /// 랜드마크를 다 복원하면 받는 부스터. 종류마다 하나씩이다.
    static let completionRewards = Booster.allCases

    /// 설명을 이미 본 레벨의 ID. 처음 시작할 때만 설명을 띄우려고 기억한다.
    private(set) var seenTutorials: Set<String>

    private static let seenTutorialsKey = "seenTutorials"
    private let store: ProgressStore
    /// 진행 파일을 읽지 못했으면 덮어써서 기록을 잃지 않도록 저장하지 않는다.
    private var canSave = true

    var levelIDs: [String] { levels.map(\.id) }

    init(store: ProgressStore = .standard()) {
        self.store = store
        seenTutorials = Set(UserDefaults.standard.stringArray(forKey: Self.seenTutorialsKey) ?? [])
        #if DEBUG
        // 실행 인자 `-resetProgress 1`을 주면 저장된 진행을 지우고 시작한다.
        if UserDefaults.standard.bool(forKey: "resetProgress") {
            UserDefaults.standard.removeObject(forKey: Self.starterToolsKey)
            try? store.reset()
        }
        #endif

        // 진행부터 읽는다. 도시를 고를 때 어느 도시가 열렸는지 알아야 한다.
        var loadFailed = false
        do {
            progress = try store.load()
        } catch {
            progress = GameProgress()
            canSave = false
            loadFailed = true
        }
        var problems: [String] = loadFailed ? [String(localized: "저장된 진행을 읽지 못했어요. 이번에 한 기록은 저장되지 않아요.")] : []
        levels = []
        city = nil
        for id in LevelCatalog.cityIDs {
            do {
                var loaded = try LevelCatalog.city(id)
                // 이름과 설명을 기기의 언어로 바꿔 둔다.
                loaded.name = Self.localized(loaded.name)
                loaded.landmark.name = Self.localized(loaded.landmark.name)
                for index in loaded.landmark.parts.indices {
                    loaded.landmark.parts[index].name = Self.localized(loaded.landmark.parts[index].name)
                }
                levelsByCity[id] = try LevelCatalog.levels(city: id).map { level in
                    var level = level
                    level.tutorial = level.tutorial.map(Self.localized)
                    return level
                }
                cities.append(loaded)
                // 그림이 모르는 부위가 데이터에 있으면 복원해도 화면이 바뀌지 않는다.
                let known = LandmarkArt.art(for: id)?.partIDs ?? []
                let unknown = loaded.landmark.parts.map(\.id).filter { !known.contains($0) }
                if !unknown.isEmpty {
                    problems.append("\(loaded.name): 그릴 수 없는 복원 부위가 있어요: \(unknown.joined(separator: ", "))")
                }
            } catch {
                problems.append("\(id)의 도시나 레벨 데이터를 읽지 못했어요.")
            }
        }
        #if DEBUG
        // 실행 인자 `-allStars 1`을 주면 모든 레벨을 별 3개로 깬 것으로 보고 시작한다.
        // 복원을 시험해 보기 위한 것이라 이 실행의 기록은 저장하지 않는다.
        if UserDefaults.standard.bool(forKey: "allStars") {
            for id in levelsByCity.values.joined().map(\.id) {
                _ = progress.recordClear(levelID: id, stars: 3, score: 0)
            }
            canSave = false
        }
        // 실행 인자 `-restoreAll 1`을 주면 모든 레벨을 별 3개로 깨고 모든 랜드마크를 다 복원한 것으로 보고 시작한다.
        // 화면을 찍기 위한 것이라 이 실행의 기록은 저장하지 않는다.
        if UserDefaults.standard.bool(forKey: "restoreAll") {
            for id in levelsByCity.values.joined().map(\.id) {
                _ = progress.recordClear(levelID: id, stars: 3, score: 0)
            }
            for city in cities {
                for part in city.landmark.parts {
                    progress.restore(partID: part.id, in: city.id)
                }
            }
            canSave = false
        }
        // 실행 인자 `-clearedCities seoul,tokyo`를 주면 그 도시의 레벨을 모두 별 1개로 깬 것으로 보고 시작한다.
        if let ids = UserDefaults.standard.string(forKey: "clearedCities") {
            for city in ids.split(separator: ",") {
                for level in levelsByCity[String(city)] ?? [] {
                    _ = progress.recordClear(levelID: level.id, stars: 1, score: 0)
                }
            }
            canSave = false
        }
        // 실행 인자 `-clearedLevels 15`를 `-city`와 함께 주면 그 도시의 앞 레벨 15개를 깬 것으로 보고 시작한다.
        let clearedLevels = UserDefaults.standard.integer(forKey: "clearedLevels")
        if clearedLevels > 0, let city = UserDefaults.standard.string(forKey: "city") {
            for level in (levelsByCity[city] ?? []).prefix(clearedLevels) {
                _ = progress.recordClear(levelID: level.id, stars: 1, score: 0)
            }
            canSave = false
        }
        #endif
        problem = problems.isEmpty ? nil : problems.joined(separator: "\n")
        // 마지막에 보던 도시에서 시작한다. 그 도시가 아직 열리지 않았으면 첫 도시다.
        var startID = UserDefaults.standard.string(forKey: Self.currentCityKey) ?? ""
        #if DEBUG
        // 실행 인자 `-city tokyo`를 주면 잠금과 상관없이 그 도시에서 시작한다.
        if let forced = UserDefaults.standard.string(forKey: "city"), cities.contains(where: { $0.id == forced }) {
            startID = forced
            forcedCityID = forced
        }
        #endif
        let start = cities.first { $0.id == startID && isUnlocked(cityID: $0.id) } ?? cities.first
        city = start
        levels = start.flatMap { levelsByCity[$0.id] } ?? []
        cityLevels = levels
        #if DEBUG
        // 실행 인자 `-boosters 숫자`를 주면 부스터를 종류마다 그만큼 갖고 시작한다. 그 실행의 기록은 저장하지 않는다.
        let extra = UserDefaults.standard.integer(forKey: "boosters")
        if extra > 0 {
            for booster in Booster.allCases {
                progress.addBooster(booster.rawValue, count: extra)
            }
            canSave = false
        }
        // 실행 인자 `-tools 숫자`를 주면 아이템을 종류마다 그만큼 갖고 시작한다(0도 된다). 그 실행의 기록은 저장하지 않는다.
        if UserDefaults.standard.object(forKey: "tools") != nil {
            let count = UserDefaults.standard.integer(forKey: "tools")
            for tool in Tool.allCases {
                while progress.useBooster(Self.key(tool)) {}
                progress.addBooster(Self.key(tool), count: count)
            }
            canSave = false
        }
        // 실행 인자 `-lives 숫자`를 주면 생명을 그만큼 갖고 시작한다(0도 된다). 그 실행의 기록은 저장하지 않는다.
        if UserDefaults.standard.object(forKey: "lives") != nil {
            progress.lives.set(UserDefaults.standard.integer(forKey: "lives"), at: .now)
            canSave = false
        }
        // 실행 인자 `-map 1`은 지도 화면에서, `-flight 1`은 첫 도시에서 다음 도시로 날아가는 연출에서 시작한다.
        // `-world 1`은 세계 지도에서, `-region southasia`는 그 권역의 지도에서 시작한다.
        if UserDefaults.standard.bool(forKey: "map"), let region = currentRegion {
            mapScreen = .region(region.id)
        }
        if UserDefaults.standard.bool(forKey: "world") {
            mapScreen = .world
        }
        if let id = UserDefaults.standard.string(forKey: "region"), regions.contains(where: { $0.id == id }) {
            mapScreen = .region(id)
        }
        // `-flight 숫자`는 그 번째 도시에서 다음 도시로 가는 비행이다. 3이면 베이징에서 뉴델리로, 권역을 넘어간다.
        let leg = UserDefaults.standard.integer(forKey: "flight")
        if leg >= 1, cities.indices.contains(leg) {
            for level in levelsByCity[cities[leg - 1].id] ?? [] where !progress.isCleared(level.id) {
                _ = progress.recordClear(levelID: level.id, stars: 1, score: 0)
            }
            canSave = false
            pendingFlight = Flight(from: cities[leg - 1].id, to: cities[leg].id)
            forcedCityID = cities[leg].id
        }
        // 실행 인자 `-ending 1`을 주면 엔딩에서 시작한다.
        if UserDefaults.standard.bool(forKey: "ending") {
            wantsEnding = true
        }
        // 실행 인자 `-lab 1`을 주면 시험판 레벨로 시작한다.
        if UserDefaults.standard.bool(forKey: "lab") {
            setLabMode(true)
        }
        #endif
        // iCloud의 진행(다른 기기, 또는 지우기 전 이 기기)을 먼저 합치고 시작 아이템을 준다.
        // 다시 설치한 기기가 빈 진행으로 iCloud를 덮어쓰지 않게 언제부터 올릴지도 여기서 정한다.
        if canSave {
            cloud.start(local: progress)
        }
        mergeCloud(cloud.pull())
        grantStarterTools()
        cloud.observe { [weak self] remote in
            self?.mergeCloud(remote)
        }
        #if DEBUG
        // 실행 인자 `-dailyGift 1`을 주면 오늘의 선물을 아직 받지 않은 것으로 보고 시작한다.
        if UserDefaults.standard.bool(forKey: "dailyGift") {
            progress.daily = DailyGift()
            canSave = false
        }
        #endif
    }

    #if DEBUG
    /// 실행 인자로 잠금을 풀어 준 도시.
    private var forcedCityID: String?

    /// 설정의 "도시 바로 가기"로 잠금과 상관없이 그 도시로 간다. 그 도시의 레벨도 모두 열린다.
    /// 앱을 다시 켜면 원래 잠금으로 돌아간다. 거기서 깬 판의 기록은 평소처럼 남는다.
    func visit(cityID: String) {
        guard cities.contains(where: { $0.id == cityID }) else { return }
        if isLabMode {
            setLabMode(false)
        }
        forcedCityID = cityID
        select(cityID: cityID)
    }
    #endif

    // MARK: - 도시

    /// 도시가 열려 있는지. 첫 도시는 늘 열려 있고, 나머지는 바로 앞 도시의 레벨을 모두 클리어해야 열린다.
    /// 랜드마크 복원은 조건이 아니다. 별을 덜 모아도 다음 도시로 갈 수 있다.
    func isUnlocked(cityID: String) -> Bool {
        guard let index = cities.firstIndex(where: { $0.id == cityID }) else { return false }
        #if DEBUG
        if cityID == forcedCityID { return true }
        #endif
        return index == 0 || hasClearedAllLevels(cityID: cities[index - 1].id)
    }

    /// 도시의 레벨을 모두 클리어했는지.
    func hasClearedAllLevels(cityID: String) -> Bool {
        let ids = (levelsByCity[cityID] ?? []).map(\.id)
        return !ids.isEmpty && ids.allSatisfy(progress.isCleared)
    }

    func isFullyRestored(cityID: String) -> Bool {
        guard let city = cities.first(where: { $0.id == cityID }) else { return false }
        return city.landmark.isFullyRestored(progress.restoredParts(in: cityID))
    }

    /// 도시에서 모은 별과 모을 수 있는 별.
    func stars(cityID: String) -> (earned: Int, total: Int) {
        let ids = (levelsByCity[cityID] ?? []).map(\.id)
        return (progress.totalStars(in: ids), ids.count * 3)
    }

    // MARK: - 권역

    /// 지금 도시가 속한 권역.
    var currentRegion: Region? {
        city.flatMap { RegionCatalog.region(ofCity: $0.id) } ?? regions.first
    }

    /// 권역이 열려 있는지. 첫 권역은 늘 열려 있고, 나머지는 바로 앞 권역의 도시를 모두 끝내야 열린다.
    /// 도시가 아직 없는 권역 뒤의 권역은 열리지 않는다.
    func isUnlocked(regionID: String) -> Bool {
        guard let index = regions.firstIndex(where: { $0.id == regionID }) else { return false }
        guard index > 0 else { return true }
        let previous = regions[index - 1]
        return previous.isPlayable && previous.cityIDs.allSatisfy(hasClearedAllLevels)
    }

    /// 권역에서 모은 별과 모을 수 있는 별.
    func stars(regionID: String) -> (earned: Int, total: Int) {
        let cityIDs = regions.first { $0.id == regionID }?.cityIDs ?? []
        return cityIDs.map { stars(cityID: $0) }.reduce((0, 0)) { ($0.0 + $1.earned, $0.1 + $1.total) }
    }

    /// 열려 있는 도시로 옮긴다.
    func select(cityID: String) {
        guard isUnlocked(cityID: cityID), let next = cities.first(where: { $0.id == cityID }) else { return }
        city = next
        levels = levelsByCity[cityID] ?? []
        cityLevels = levels
        isLabMode = false
        UserDefaults.standard.set(cityID, forKey: Self.currentCityKey)
    }

    /// 지금 도시의 다음 도시. 마지막 도시면 `nil`이다.
    var nextCity: City? {
        guard let city, let index = cities.firstIndex(of: city), cities.indices.contains(index + 1) else { return nil }
        return cities[index + 1]
    }

    /// 시험판 레벨과 지금 도시의 레벨을 오간다.
    func setLabMode(_ isOn: Bool) {
        if isOn, let lab = try? LevelCatalog.lab(), !lab.isEmpty {
            // 손으로 만든 시험판 뒤에 생성기로 만든 견본 레벨을 잇는다.
            levels = lab + ((try? LevelCatalog.samples()) ?? [])
            isLabMode = true
        } else {
            levels = cityLevels
            isLabMode = false
        }
    }

    // MARK: - 별과 복원

    /// 이 도시에서 모은 별.
    var earnedStars: Int {
        progress.totalStars(in: levelIDs)
    }

    /// 플레이어가 복원한 부위의 ID.
    var restoredParts: Set<String> {
        city.map { progress.restoredParts(in: $0.id) } ?? []
    }

    /// 모은 별 가운데 아직 복원에 쓰지 않은 별.
    var availableStars: Int {
        city?.landmark.availableStars(earned: earnedStars, restored: restoredParts) ?? 0
    }

    var isFullyRestored: Bool {
        city?.landmark.isFullyRestored(restoredParts) ?? false
    }

    /// 부위를 지금 복원할 수 없는 이유. 복원할 수 있으면 `nil`이다.
    func blocker(for part: Landmark.Part) -> RestoreBlocker? {
        guard let city else { return .unknownPart }
        return city.landmark.blocker(for: part.id, earned: earnedStars, restored: restoredParts)
    }

    /// 플레이어가 고른 부위를 별을 써서 복원한다. 마지막 부위를 복원하면 선물로 부스터를 받는다.
    func restore(_ part: Landmark.Part) {
        guard let city, blocker(for: part) == nil else { return }
        if progress.restore(partID: part.id, in: city.id) {
            if isFullyRestored {
                for booster in Self.completionRewards {
                    progress.addBooster(booster.rawValue)
                }
                for tool in Tool.allCases {
                    progress.addBooster(Self.key(tool))
                }
                justCompletedLandmark = true
            }
            Tracker.log(.landmarkRestore(city: city.id, part: part.id, completed: isFullyRestored))
            save()
        }
    }

    // MARK: - 생명력

    /// 생명력을 쓰는 판인지. 시험판은 쓰지 않는다.
    var usesLives: Bool {
        !isLabMode
    }

    /// 지금 가진 생명.
    func lives(at now: Date = .now) -> Int {
        progress.lives.count(at: now)
    }

    /// 다음 생명이 차기까지 남은 시간(초). 가득 차 있으면 `nil`이다.
    func timeUntilNextLife(at now: Date = .now) -> TimeInterval? {
        progress.lives.timeUntilNext(at: now)
    }

    /// 판을 시작할 수 있는지. 생명이 하나는 있어야 한다.
    var canStartLevel: Bool {
        !usesLives || lives() > 0
    }

    /// 판에서 졌거나 하다가 나갔을 때 생명 하나를 잃는다.
    func loseLife() {
        guard usesLives, progress.lives.lose(at: .now) else { return }
        if lives() == 0 {
            Tracker.log(.livesOut)
        }
        save()
    }

    /// 오늘 광고로 더 받을 수 있는 생명.
    func adLivesLeft(at now: Date = .now) -> Int {
        progress.lives.adGrantsLeft(at: now)
    }

    /// 광고를 보고 생명 하나를 받는다.
    @discardableResult
    func grantLifeFromAd() -> Bool {
        guard progress.lives.addFromAd(at: .now) else { return false }
        save()
        return true
    }

    // MARK: - 일일 보상

    /// 오늘의 선물을 받을 수 있는지. 시험판에서는 받지 않는다.
    var canClaimDailyGift: Bool {
        !isLabMode && progress.daily.canClaim(at: .now)
    }

    /// 지금 받으면 몇째 날의 선물인지. 오늘 이미 받았으면 받은 날이다.
    var dailyGiftDay: Int {
        progress.daily.canClaim(at: .now) ? progress.daily.nextDay(at: .now) : max(progress.daily.streak, 1)
    }

    /// 오늘의 선물을 받아 부스터, 아이템, 생명에 더한다.
    @discardableResult
    func claimDailyGift() -> [String]? {
        guard let items = progress.daily.claim(at: .now) else { return nil }
        Tracker.log(.dailyGift(day: progress.daily.streak))
        for item in items {
            let parts = item.split(separator: ":").map(String.init)
            switch parts.first {
            case "booster": progress.addBooster(parts[1])
            case "tool": progress.addBooster("tool_" + parts[1])
            default: progress.lives.set(Lives.maximum, at: .now)
            }
        }
        save()
        return items
    }

    // MARK: - iCloud

    private let cloud = CloudSync()

    /// 진행을 iCloud에 저장하는지.
    var isCloudEnabled: Bool {
        get { cloud.isEnabled }
        set {
            cloud.isEnabled = newValue
            if newValue {
                mergeCloud(cloud.pull())
                save()
            }
        }
    }

    /// 다른 기기의 진행을 이 기기의 진행에 합친다.
    private func mergeCloud(_ remote: GameProgress?) {
        guard canSave, let remote else { return }
        let merged = progress.merging(remote)
        guard merged != progress else { return }
        progress = merged
        // 합친 것을 iCloud에도 올려 이 기기에만 있던 기록을 남긴다.
        save()
    }

    // MARK: - 아이템

    /// 하루에 광고로 받을 수 있는 아이템의 수.
    static let dailyAdTools = 2
    private static let starterToolsKey = "grantedStarterTools"
    private static let adToolDayKey = "adToolDay"
    private static let adToolCountKey = "adToolCount"

    private static func key(_ tool: Tool) -> String {
        "tool_" + tool.rawValue
    }

    /// 가진 아이템의 수.
    func toolCount(_ tool: Tool) -> Int {
        progress.boosterCount(Self.key(tool))
    }

    /// 아이템 하나를 쓴다. 시험판에서는 줄지 않는다.
    func useTool(_ tool: Tool) {
        guard !isLabMode, progress.useBooster(Self.key(tool)) else { return }
        save()
    }

    /// 처음 시작할 때 종류마다 하나씩 준다. 한 번만 준다.
    private func grantStarterTools() {
        // 저장하지 않는 실행(개발용 인자)에서는 주지 않는다. 줬다는 표시만 남고 아이템은 사라지기 때문이다.
        guard canSave, !UserDefaults.standard.bool(forKey: Self.starterToolsKey) else { return }
        // iCloud에서 진행이나 아이템을 되찾은 사람(다시 설치)은 이미 받았던 사람이다.
        guard progress.isEmpty, progress.boosters.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.starterToolsKey)
            return
        }
        // iCloud의 진행보다 먼저 줄 수 있으므로 바꾼 것으로 치지 않는다(GameProgress.addBooster).
        for tool in Tool.allCases {
            progress.addBooster(Self.key(tool), changesStamp: false)
        }
        UserDefaults.standard.set(true, forKey: Self.starterToolsKey)
        save()
    }

    /// 오늘 광고로 더 받을 수 있는 아이템의 수.
    var adToolsLeft: Int {
        let defaults = UserDefaults.standard
        guard let day = defaults.object(forKey: Self.adToolDayKey) as? Date, Calendar.current.isDateInToday(day) else {
            return Self.dailyAdTools
        }
        return max(Self.dailyAdTools - defaults.integer(forKey: Self.adToolCountKey), 0)
    }

    /// 광고를 보고 아이템 하나를 받는다.
    @discardableResult
    func grantToolFromAd(_ tool: Tool) -> Bool {
        let left = adToolsLeft
        guard left > 0 else { return false }
        let defaults = UserDefaults.standard
        defaults.set(Date.now, forKey: Self.adToolDayKey)
        defaults.set(Self.dailyAdTools - left + 1, forKey: Self.adToolCountKey)
        progress.addBooster(Self.key(tool))
        save()
        return true
    }

    // MARK: - 시작 부스터

    /// 가진 부스터의 수.
    func boosterCount(_ booster: Booster) -> Int {
        progress.boosterCount(booster.rawValue)
    }

    /// 고른 부스터를 쓴다. 판을 시작하는 순간에 줄어들고, 실패해도 돌려받지 않는다.
    /// - Returns: 실제로 쓴 부스터.
    func useBoosters(_ boosters: Set<Booster>) -> [Booster] {
        let used = Booster.allCases.filter { boosters.contains($0) && progress.useBooster($0.rawValue) }
        if !used.isEmpty {
            save()
        }
        return used
    }

    // MARK: - 튜토리얼과 초기화

    /// 레벨을 시작할 때 설명을 띄워야 하는지. 설명이 있고 아직 보지 않은 레벨만 그렇다.
    func shouldShowTutorial(for level: Level) -> Bool {
        level.tutorial != nil && !seenTutorials.contains(level.id)
    }

    func markTutorialSeen(for level: Level) {
        guard seenTutorials.insert(level.id).inserted else { return }
        UserDefaults.standard.set(seenTutorials.sorted(), forKey: Self.seenTutorialsKey)
    }

    /// 모든 레벨의 설명을 다시 보게 한다.
    func resetTutorials() {
        seenTutorials = []
        UserDefaults.standard.removeObject(forKey: Self.seenTutorialsKey)
    }

    /// 레벨 기록과 복원한 부위를 모두 지운다. 되돌릴 수 없다.
    func resetProgress() {
        do {
            try store.reset()
            cloud.clear()
            progress = GameProgress()
            canSave = true
            problem = nil
            UserDefaults.standard.removeObject(forKey: Self.starterToolsKey)
            grantStarterTools()
            // 첫 도시로 돌아간다.
            if let first = cities.first {
                select(cityID: first.id)
            }
        } catch {
            problem = String(localized: "진행을 지우지 못했어요.")
        }
    }

    // MARK: - 레벨

    func isUnlocked(_ index: Int) -> Bool {
        #if DEBUG
        // 바로 가기로 온 도시는 레벨이 모두 열려 있다.
        if let city, city.id == forcedCityID { return true }
        #endif
        return isLabMode || progress.isUnlocked(index: index, in: levelIDs)
    }

    /// 끝난 판을 기록한다. 클리어한 판만 진행에 남는다.
    /// - Returns: 이번 판에서 받은 별 수. 실패한 판은 0이다.
    @discardableResult
    func record(_ state: GameState, for level: Level) -> Int {
        lastRewards = []
        guard state.status == .won else { return 0 }
        let stars = level.stars(forScore: state.score)
        // 시험판의 기록은 남기지 않는다.
        guard !isLabMode else { return stars }
        // 처음 클리어한 레벨이면 그 레벨의 부스터를 받는다.
        let isFirstClear = !progress.isCleared(level.id)
        let hadClearedAll = hasClearedAllLevels(cityID: level.city)
        if progress.recordClear(levelID: level.id, stars: stars, score: state.score) {
            if isFirstClear {
                for booster in level.rewards {
                    progress.addBooster(booster.rawValue)
                }
                lastRewards = level.rewards
            }
            save()
            // 도시의 마지막 레벨까지 깼으면 다음 도시가 열린다. 도시 화면으로 돌아갔을 때 그리로 날아간다.
            if !hadClearedAll, hasClearedAllLevels(cityID: level.city) {
                Tracker.log(.cityClear(city: level.city))
            }
            if !hadClearedAll, hasClearedAllLevels(cityID: level.city), let next = nextCity {
                pendingFlight = Flight(from: level.city, to: next.id)
            }
            // 마지막 레벨까지 다 깼으면 엔딩을 보여준다. 처음 한 번만이다.
            if hasClearedEverything, !UserDefaults.standard.bool(forKey: Self.seenEndingKey) {
                UserDefaults.standard.set(true, forKey: Self.seenEndingKey)
                isFirstEnding = true
                wantsEnding = true
            }
        }
        return stars
    }

    private func save() {
        guard canSave else { return }
        do {
            try store.save(progress)
            cloud.push(progress)
        } catch {
            problem = String(localized: "진행을 저장하지 못했어요.")
        }
    }
}
