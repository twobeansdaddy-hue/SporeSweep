// Tools/landmark_shapes.py가 쓴 파일이다. 손으로 고치지 말고 그 표를 고친 뒤 다시 돌린다.
// 넷째 권역부터의 랜드마크. 부위의 영역은 건물의 모양에 맞춰 잡았다(그림의 가로와 세로를 0...1로 본 비율).

extension LandmarkArt {
    static let shapedCities: [String: LandmarkArt] = [
        "rome": .shaped(prefix: "rome", name: "콜로세움", parts: [
            ShapedPart(id: "ring1", shapes: [.rect(0, 0.76, 1, 0.97)], minus: [], spore: (0.5, 0.83)),
            ShapedPart(id: "ring2", shapes: [.rect(0, 0.585, 1, 0.76)], minus: [], spore: (0.5, 0.672)),
            ShapedPart(id: "ring3", shapes: [.rect(0, 0.4, 1, 0.585)], minus: [], spore: (0.5, 0.492)),
            ShapedPart(id: "inner", shapes: [.rect(0.59, 0, 1, 0.4)], minus: [], spore: (0.72, 0.36)),
            ShapedPart(id: "outer", shapes: [.rect(0, 0, 0.59, 0.4)], minus: [], spore: (0.3, 0.25)),
        ]),
        "athens": .shaped(prefix: "athens", name: "파르테논 신전", parts: [
            ShapedPart(id: "steps", shapes: [.rect(0, 0.745, 1, 0.97)], minus: [], spore: (0.5, 0.823)),
            ShapedPart(id: "columnsLeft", shapes: [.rect(0, 0.37, 0.5, 0.745)], minus: [], spore: (0.25, 0.557)),
            ShapedPart(id: "columnsRight", shapes: [.rect(0.5, 0.37, 1, 0.745)], minus: [], spore: (0.75, 0.557)),
            ShapedPart(id: "frieze", shapes: [.rect(0, 0.255, 1, 0.37)], minus: [], spore: (0.5, 0.312)),
            ShapedPart(id: "pediment", shapes: [.rect(0, 0, 1, 0.255)], minus: [], spore: (0.5, 0.18)),
        ]),
        "barcelona": .shaped(prefix: "barcelona", name: "사그라다 파밀리아", parts: [
            ShapedPart(id: "portals", shapes: [.rect(0, 0.75, 1, 0.97)], minus: [], spore: (0.5, 0.825)),
            ShapedPart(id: "rose", shapes: [.rect(0, 0.52, 1, 0.75)], minus: [], spore: (0.5, 0.635)),
            ShapedPart(id: "towerLeft", shapes: [.rect(0, 0, 0.405, 0.52)], minus: [], spore: (0.37, 0.36)),
            ShapedPart(id: "towerRight", shapes: [.rect(0.595, 0, 1, 0.52)], minus: [], spore: (0.63, 0.36)),
            ShapedPart(id: "towersCenter", shapes: [.rect(0.405, 0, 0.595, 0.52)], minus: [], spore: (0.445, 0.25)),
        ]),
        "paris": .shaped(prefix: "paris", name: "에펠탑", parts: [
            ShapedPart(id: "legs", shapes: [.rect(0, 0.625, 1, 0.97)], minus: [], spore: (0.4, 0.78)),
            ShapedPart(id: "deck1", shapes: [.rect(0, 0.445, 1, 0.625)], minus: [], spore: (0.5, 0.535)),
            ShapedPart(id: "deck2", shapes: [.rect(0, 0.27, 1, 0.445)], minus: [], spore: (0.5, 0.358)),
            ShapedPart(id: "body", shapes: [.rect(0, 0.135, 1, 0.27)], minus: [], spore: (0.5, 0.203)),
            ShapedPart(id: "top", shapes: [.rect(0, 0, 1, 0.135)], minus: [], spore: (0.5, 0.1)),
        ]),
        "london": .shaped(prefix: "london", name: "빅벤", parts: [
            ShapedPart(id: "hall", shapes: [.rect(0, 0.72, 0.585, 0.97)], minus: [], spore: (0.292, 0.81)),
            ShapedPart(id: "hallRoof", shapes: [.rect(0, 0, 0.585, 0.72)], minus: [], spore: (0.33, 0.66)),
            ShapedPart(id: "shaft", shapes: [.rect(0.585, 0.5, 1, 0.97)], minus: [], spore: (0.665, 0.72)),
            ShapedPart(id: "clock", shapes: [.rect(0.585, 0.36, 1, 0.5)], minus: [], spore: (0.665, 0.43)),
            ShapedPart(id: "spire", shapes: [.rect(0.585, 0, 1, 0.36)], minus: [], spore: (0.665, 0.22)),
        ]),
        "amsterdam": .shaped(prefix: "amsterdam", name: "풍차", parts: [
            ShapedPart(id: "base", shapes: [.rect(0, 0.8, 1, 0.97)], minus: ["sails"], spore: (0.5, 0.85)),
            ShapedPart(id: "gallery", shapes: [.rect(0, 0.62, 1, 0.8)], minus: ["sails"], spore: (0.5, 0.7)),
            ShapedPart(id: "body", shapes: [.rect(0, 0.42, 1, 0.62)], minus: ["sails"], spore: (0.5, 0.55)),
            ShapedPart(id: "cap", shapes: [.rect(0, 0, 1, 0.42)], minus: ["sails"], spore: (0.5, 0.24)),
            ShapedPart(id: "sails", shapes: [.poly([(0.22, 0.13), (0.3, 0.04), (0.79, 0.58), (0.71, 0.67)]), .poly([(0.7, 0.025), (0.78, 0.115), (0.29, 0.675), (0.21, 0.585)])], minus: [], spore: (0.33, 0.2)),
        ]),
        "newyork": .shaped(prefix: "newyork", name: "자유의 여신상", parts: [
            ShapedPart(id: "star", shapes: [.rect(0, 0.8, 1, 0.97)], minus: [], spore: (0.5, 0.85)),
            ShapedPart(id: "pedestal", shapes: [.rect(0, 0.6, 1, 0.8)], minus: [], spore: (0.5, 0.7)),
            ShapedPart(id: "robe", shapes: [.rect(0, 0.4, 1, 0.6)], minus: [], spore: (0.5, 0.5)),
            ShapedPart(id: "head", shapes: [.rect(0.435, 0, 1, 0.4)], minus: [], spore: (0.52, 0.3)),
            ShapedPart(id: "torch", shapes: [.rect(0, 0, 0.435, 0.4)], minus: [], spore: (0.405, 0.12)),
        ]),
        "sanfrancisco": .shaped(prefix: "sanfrancisco", name: "금문교", parts: [
            ShapedPart(id: "piers", shapes: [.rect(0.235, 0.62, 0.37, 0.97), .rect(0.635, 0.62, 0.77, 0.97)], minus: [], spore: (0.3, 0.72)),
            ShapedPart(id: "deck", shapes: [.rect(0, 0.5, 1, 0.62)], minus: [], spore: (0.5, 0.57)),
            ShapedPart(id: "towerLeft", shapes: [.rect(0.235, 0, 0.37, 0.5)], minus: [], spore: (0.3, 0.3)),
            ShapedPart(id: "towerRight", shapes: [.rect(0.635, 0, 0.77, 0.5)], minus: [], spore: (0.7, 0.3)),
            ShapedPart(id: "cables", shapes: [.rect(0, 0, 1, 0.5)], minus: ["towerLeft", "towerRight"], spore: (0.5, 0.41)),
        ]),
        "washington": .shaped(prefix: "washington", name: "국회의사당", parts: [
            ShapedPart(id: "wingLeft", shapes: [.rect(0, 0.505, 0.3, 0.97)], minus: [], spore: (0.15, 0.703)),
            ShapedPart(id: "wingRight", shapes: [.rect(0.7, 0.505, 1, 0.97)], minus: [], spore: (0.85, 0.703)),
            ShapedPart(id: "portico", shapes: [.rect(0.3, 0.505, 0.7, 0.97)], minus: [], spore: (0.5, 0.703)),
            ShapedPart(id: "drum", shapes: [.rect(0, 0.385, 1, 0.505)], minus: [], spore: (0.5, 0.45)),
            ShapedPart(id: "dome", shapes: [.rect(0, 0, 1, 0.385)], minus: [], spore: (0.5, 0.26)),
        ]),
        "rio": .shaped(prefix: "rio", name: "구세주 그리스도상", parts: [
            ShapedPart(id: "rock", shapes: [.rect(0, 0.855, 1, 0.97)], minus: [], spore: (0.5, 0.877)),
            ShapedPart(id: "robe", shapes: [.rect(0, 0.52, 1, 0.855), .rect(0.425, 0.185, 0.575, 0.52)], minus: [], spore: (0.5, 0.55)),
            ShapedPart(id: "armLeft", shapes: [.rect(0, 0, 0.425, 0.52)], minus: [], spore: (0.32, 0.23)),
            ShapedPart(id: "armRight", shapes: [.rect(0.575, 0, 1, 0.52)], minus: [], spore: (0.68, 0.23)),
            ShapedPart(id: "head", shapes: [.rect(0.425, 0, 0.575, 0.185)], minus: [], spore: (0.5, 0.11)),
        ]),
        "buenosaires": .shaped(prefix: "buenosaires", name: "오벨리스코", parts: [
            ShapedPart(id: "buildingLeft", shapes: [.rect(0, 0.4, 0.42, 0.97)], minus: [], spore: (0.26, 0.75)),
            ShapedPart(id: "buildingRight", shapes: [.rect(0.58, 0.4, 1, 0.97)], minus: [], spore: (0.74, 0.75)),
            ShapedPart(id: "obeliskBase", shapes: [.rect(0.42, 0.62, 0.58, 0.97)], minus: [], spore: (0.5, 0.76)),
            ShapedPart(id: "obeliskMiddle", shapes: [.rect(0.42, 0.3, 0.58, 0.62), .rect(0, 0.3, 1, 0.4)], minus: [], spore: (0.5, 0.46)),
            ShapedPart(id: "obeliskTop", shapes: [.rect(0, 0, 1, 0.3)], minus: [], spore: (0.5, 0.18)),
        ]),
        "easterisland": .shaped(prefix: "easterisland", name: "모아이", parts: [
            ShapedPart(id: "moai1", shapes: [.rect(0, 0, 0.22, 0.97)], minus: [], spore: (0.13, 0.55)),
            ShapedPart(id: "moai2", shapes: [.rect(0.22, 0, 0.41, 0.97)], minus: [], spore: (0.31, 0.5)),
            ShapedPart(id: "moai3", shapes: [.rect(0.41, 0, 0.595, 0.97)], minus: [], spore: (0.5, 0.5)),
            ShapedPart(id: "moai4", shapes: [.rect(0.595, 0, 0.78, 0.97)], minus: [], spore: (0.69, 0.55)),
            ShapedPart(id: "moai5", shapes: [.rect(0.78, 0, 1, 0.97)], minus: [], spore: (0.87, 0.58)),
        ]),
        "sydney": .shaped(prefix: "sydney", name: "오페라하우스", parts: [
            ShapedPart(id: "podium", shapes: [.rect(0, 0.655, 1, 0.97)], minus: [], spore: (0.5, 0.72)),
            ShapedPart(id: "shellsLeft", shapes: [.rect(0, 0, 0.245, 0.655)], minus: [], spore: (0.16, 0.54)),
            ShapedPart(id: "shellsMiddle", shapes: [.rect(0.245, 0, 0.5, 0.655)], minus: [], spore: (0.36, 0.42)),
            ShapedPart(id: "shellsBig", shapes: [.rect(0.5, 0, 0.805, 0.655)], minus: [], spore: (0.66, 0.35)),
            ShapedPart(id: "shellsRight", shapes: [.rect(0.805, 0, 1, 0.655)], minus: [], spore: (0.88, 0.5)),
        ]),
        "auckland": .shaped(prefix: "auckland", name: "스카이타워", parts: [
            ShapedPart(id: "base", shapes: [.rect(0, 0.74, 1, 0.97)], minus: [], spore: (0.44, 0.83)),
            ShapedPart(id: "shaft", shapes: [.rect(0, 0.43, 1, 0.74)], minus: [], spore: (0.5, 0.585)),
            ShapedPart(id: "pod", shapes: [.rect(0, 0.25, 1, 0.43)], minus: [], spore: (0.5, 0.33)),
            ShapedPart(id: "upper", shapes: [.rect(0, 0.16, 1, 0.25)], minus: [], spore: (0.5, 0.205)),
            ShapedPart(id: "mast", shapes: [.rect(0, 0, 1, 0.16)], minus: [], spore: (0.5, 0.12)),
        ]),
        "antarctica": .shaped(prefix: "antarctica", name: "과학 기지", parts: [
            ShapedPart(id: "module1", shapes: [.rect(0, 0.45, 0.285, 0.97)], minus: [], spore: (0.19, 0.5)),
            ShapedPart(id: "module2", shapes: [.rect(0.285, 0.45, 0.5, 0.97)], minus: [], spore: (0.39, 0.6)),
            ShapedPart(id: "module3", shapes: [.rect(0.5, 0.45, 0.715, 0.97)], minus: [], spore: (0.6, 0.6)),
            ShapedPart(id: "module4", shapes: [.rect(0.715, 0.45, 1, 0.97)], minus: [], spore: (0.82, 0.55)),
            ShapedPart(id: "roof", shapes: [.rect(0, 0, 1, 0.45)], minus: [], spore: (0.35, 0.32)),
        ]),
    ]
}
