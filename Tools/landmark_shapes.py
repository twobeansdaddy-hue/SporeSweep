"""넷째 권역부터의 도시 15곳의 랜드마크 부위를 정한다.

부위마다 이름, 별의 수, 먼저 복원해야 하는 부위, 그림에서 차지하는 영역을 적어 둔다. 영역은 건물의 모양에 맞춰
손으로 잡은 것이다(그림의 가로와 세로를 0...1로 본 비율). 이 표에서 도시 데이터(`Levels/도시.json`)와
`SporeSweep/LandmarkTiers.swift`를 함께 써서 둘이 어긋나지 않게 한다.

영역은 사각형 (x0, y0, x1, y1), 타원 ("ellipse", x0, y0, x1, y1), 다각형 ("poly", [(x, y), ...]) 가운데 하나다.
`minus`는 그 부위의 영역에서 빼는 다른 부위다. 뒤에 적은 부위가 위에 그려진다.

사용법: python3 Tools/landmark_shapes.py
"""
import json

from cities_data import CITIES

B = 0.97  # 건물의 바닥보다 조금 아래. 발치의 잔해까지 넣는다.


def part(id, name, cost, shapes, requires=(), minus=(), spore=None):
    return dict(id=id, name=name, cost=cost, shapes=shapes, requires=list(requires), minus=list(minus), spore=spore)


SAILS = [("poly", [(0.22, 0.13), (0.30, 0.04), (0.79, 0.58), (0.71, 0.67)]),
         ("poly", [(0.70, 0.025), (0.78, 0.115), (0.29, 0.675), (0.21, 0.585)])]
GG_TOWERS = [(0.235, 0, 0.37, 0.50), (0.635, 0, 0.77, 0.50)]

SHAPES = {
    "rome": [
        part("ring1", "1층 아치", 5, [(0, 0.76, 1, B)]),
        part("ring2", "2층 아치", 5, [(0, 0.585, 1, 0.76)], ["ring1"]),
        part("ring3", "3층 아치", 5, [(0, 0.40, 1, 0.585)], ["ring2"]),
        part("inner", "안쪽 벽 위층", 5, [(0.59, 0, 1, 0.40)], ["ring3"], spore=(0.72, 0.36)),
        part("outer", "바깥벽 위층", 6, [(0, 0, 0.59, 0.40)], ["ring3"], spore=(0.30, 0.25)),
    ],
    "athens": [
        part("steps", "기단", 5, [(0, 0.745, 1, B)]),
        part("columnsLeft", "왼쪽 기둥", 5, [(0, 0.37, 0.5, 0.745)], ["steps"]),
        part("columnsRight", "오른쪽 기둥", 5, [(0.5, 0.37, 1, 0.745)], ["steps"]),
        part("frieze", "띠 장식", 5, [(0, 0.255, 1, 0.37)], ["columnsLeft", "columnsRight"]),
        part("pediment", "지붕", 6, [(0, 0, 1, 0.255)], ["frieze"], spore=(0.5, 0.18)),
    ],
    "barcelona": [
        part("portals", "정문", 5, [(0, 0.75, 1, B)]),
        part("rose", "장미창", 5, [(0, 0.52, 1, 0.75)], ["portals"]),
        part("towerLeft", "왼쪽 탑", 5, [(0, 0, 0.405, 0.52)], ["rose"], spore=(0.37, 0.36)),
        part("towerRight", "오른쪽 탑", 5, [(0.595, 0, 1, 0.52)], ["rose"], spore=(0.63, 0.36)),
        part("towersCenter", "가운데 두 탑", 6, [(0.405, 0, 0.595, 0.52)], ["rose"], spore=(0.445, 0.25)),
    ],
    "paris": [
        part("legs", "받침 다리", 5, [(0, 0.625, 1, B)], spore=(0.40, 0.78)),
        part("deck1", "1층 전망대", 5, [(0, 0.445, 1, 0.625)], ["legs"]),
        part("deck2", "2층 전망대", 5, [(0, 0.27, 1, 0.445)], ["deck1"]),
        part("body", "철탑 몸통", 5, [(0, 0.135, 1, 0.27)], ["deck2"]),
        part("top", "꼭대기", 6, [(0, 0, 1, 0.135)], ["body"], spore=(0.5, 0.10)),
    ],
    "london": [
        part("hall", "의사당 아래층", 5, [(0, 0.72, 0.585, B)]),
        part("hallRoof", "의사당 지붕", 5, [(0, 0, 0.585, 0.72)], ["hall"], spore=(0.33, 0.66)),
        part("shaft", "시계탑 몸통", 5, [(0.585, 0.50, 1, B)], spore=(0.665, 0.72)),
        part("clock", "시계", 5, [(0.585, 0.36, 1, 0.50)], ["shaft"], spore=(0.665, 0.43)),
        part("spire", "첨탑", 6, [(0.585, 0, 1, 0.36)], ["clock"], spore=(0.665, 0.22)),
    ],
    "amsterdam": [
        part("base", "벽돌 받침", 5, [(0, 0.80, 1, B)], minus=["sails"]),
        part("gallery", "발코니", 5, [(0, 0.62, 1, 0.80)], ["base"], minus=["sails"], spore=(0.5, 0.70)),
        part("body", "몸통", 5, [(0, 0.42, 1, 0.62)], ["gallery"], minus=["sails"], spore=(0.5, 0.55)),
        part("cap", "지붕", 5, [(0, 0, 1, 0.42)], ["body"], minus=["sails"], spore=(0.5, 0.24)),
        part("sails", "날개", 6, SAILS, ["cap"], spore=(0.33, 0.20)),
    ],
    "newyork": [
        part("star", "별 모양 기단", 5, [(0, 0.80, 1, B)]),
        part("pedestal", "받침대", 5, [(0, 0.60, 1, 0.80)], ["star"]),
        part("robe", "옷자락", 5, [(0, 0.40, 1, 0.60)], ["pedestal"]),
        part("head", "몸과 왕관", 5, [(0.435, 0, 1, 0.40)], ["robe"], spore=(0.52, 0.30)),
        part("torch", "횃불", 6, [(0, 0, 0.435, 0.40)], ["robe"], spore=(0.405, 0.12)),
    ],
    "sanfrancisco": [
        part("piers", "교각", 5, [(0.235, 0.62, 0.37, B), (0.635, 0.62, 0.77, B)], spore=(0.30, 0.72)),
        part("deck", "다리 상판", 5, [(0, 0.50, 1, 0.62)], ["piers"], spore=(0.5, 0.57)),
        part("towerLeft", "왼쪽 탑", 5, [GG_TOWERS[0]], ["deck"], spore=(0.30, 0.30)),
        part("towerRight", "오른쪽 탑", 5, [GG_TOWERS[1]], ["deck"], spore=(0.70, 0.30)),
        part("cables", "주 케이블", 6, [(0, 0, 1, 0.50)], ["towerLeft", "towerRight"], minus=["towerLeft", "towerRight"], spore=(0.5, 0.41)),
    ],
    "washington": [
        part("wingLeft", "왼쪽 날개", 5, [(0, 0.505, 0.30, B)]),
        part("wingRight", "오른쪽 날개", 5, [(0.70, 0.505, 1, B)]),
        part("portico", "가운데 현관", 5, [(0.30, 0.505, 0.70, B)]),
        part("drum", "돔 받침", 5, [(0, 0.385, 1, 0.505)], ["portico"], spore=(0.5, 0.45)),
        part("dome", "돔", 6, [(0, 0, 1, 0.385)], ["drum"], spore=(0.5, 0.26)),
    ],
    "rio": [
        part("rock", "바위와 받침대", 5, [(0, 0.855, 1, B)]),
        part("robe", "옷자락", 5, [(0, 0.52, 1, 0.855), (0.425, 0.185, 0.575, 0.52)], ["rock"], spore=(0.5, 0.55)),
        part("armLeft", "왼팔", 5, [(0, 0, 0.425, 0.52)], ["robe"], spore=(0.32, 0.23)),
        part("armRight", "오른팔", 5, [(0.575, 0, 1, 0.52)], ["robe"], spore=(0.68, 0.23)),
        part("head", "머리", 6, [(0.425, 0, 0.575, 0.185)], ["robe"], spore=(0.5, 0.11)),
    ],
    "buenosaires": [
        part("buildingLeft", "왼쪽 건물", 5, [(0, 0.40, 0.42, B)], spore=(0.26, 0.75)),
        part("buildingRight", "오른쪽 건물", 5, [(0.58, 0.40, 1, B)], spore=(0.74, 0.75)),
        part("obeliskBase", "탑 아래", 5, [(0.42, 0.62, 0.58, B)]),
        part("obeliskMiddle", "탑 가운데", 5, [(0.42, 0.30, 0.58, 0.62), (0, 0.30, 1, 0.40)], ["obeliskBase"], spore=(0.5, 0.46)),
        part("obeliskTop", "탑 꼭대기", 6, [(0, 0, 1, 0.30)], ["obeliskMiddle"], spore=(0.5, 0.18)),
    ],
    "easterisland": [
        part("moai1", "첫째 석상", 5, [(0, 0, 0.22, B)], spore=(0.13, 0.55)),
        part("moai2", "둘째 석상", 5, [(0.22, 0, 0.41, B)], spore=(0.31, 0.50)),
        part("moai3", "가운데 큰 석상", 6, [(0.41, 0, 0.595, B)], spore=(0.50, 0.50)),
        part("moai4", "넷째 석상", 5, [(0.595, 0, 0.78, B)], spore=(0.69, 0.55)),
        part("moai5", "다섯째 석상", 5, [(0.78, 0, 1, B)], spore=(0.87, 0.58)),
    ],
    "sydney": [
        part("podium", "기단", 5, [(0, 0.655, 1, B)], spore=(0.5, 0.72)),
        part("shellsLeft", "왼쪽 작은 지붕", 5, [(0, 0, 0.245, 0.655)], ["podium"], spore=(0.16, 0.54)),
        part("shellsMiddle", "가운데 지붕", 5, [(0.245, 0, 0.50, 0.655)], ["podium"], spore=(0.36, 0.42)),
        part("shellsBig", "큰 지붕", 6, [(0.50, 0, 0.805, 0.655)], ["podium"], spore=(0.66, 0.35)),
        part("shellsRight", "오른쪽 지붕", 5, [(0.805, 0, 1, 0.655)], ["podium"], spore=(0.88, 0.50)),
    ],
    "auckland": [
        part("base", "아래 건물", 5, [(0, 0.74, 1, B)], spore=(0.44, 0.83)),
        part("shaft", "탑 기둥", 5, [(0, 0.43, 1, 0.74)], ["base"]),
        part("pod", "전망대", 5, [(0, 0.25, 1, 0.43)], ["shaft"], spore=(0.5, 0.33)),
        part("upper", "윗부분", 5, [(0, 0.16, 1, 0.25)], ["pod"]),
        part("mast", "안테나", 6, [(0, 0, 1, 0.16)], ["upper"], spore=(0.5, 0.12)),
    ],
    "antarctica": [
        part("module1", "첫째 기지", 5, [(0, 0.45, 0.285, B)], spore=(0.19, 0.50)),
        part("module2", "둘째 기지", 5, [(0.285, 0.45, 0.50, B)], spore=(0.39, 0.60)),
        part("module3", "셋째 기지", 5, [(0.50, 0.45, 0.715, B)], spore=(0.60, 0.60)),
        part("module4", "넷째 기지와 설상차", 5, [(0.715, 0.45, 1, B)], spore=(0.82, 0.55)),
        part("roof", "지붕 장비", 6, [(0, 0, 1, 0.45)], spore=(0.35, 0.32)),
    ],
}


def bounds(shape):
    if shape[0] == "poly":
        xs, ys = [p[0] for p in shape[1]], [p[1] for p in shape[1]]
        return min(xs), min(ys), max(xs), max(ys)
    return shape[-4:]


def swift(shape):
    if shape[0] == "poly":
        return ".poly([" + ", ".join(f"({x}, {y})" for x, y in shape[1]) + "])"
    kind = "ellipse" if shape[0] == "ellipse" else "rect"
    x0, y0, x1, y1 = shape[-4:]
    return f".{kind}({x0}, {y0}, {x1}, {y1})"


def main():
    lines = [
        "// Tools/landmark_shapes.py가 쓴 파일이다. 손으로 고치지 말고 그 표를 고친 뒤 다시 돌린다.",
        "// 넷째 권역부터의 랜드마크. 부위의 영역은 건물의 모양에 맞춰 잡았다(그림의 가로와 세로를 0...1로 본 비율).",
        "",
        "extension LandmarkArt {",
        "    static let shapedCities: [String: LandmarkArt] = [",
    ]
    for city, name, landmark, title, _, greenery in CITIES:
        parts = SHAPES[city]
        assert len(parts) == 5 and sum(p["cost"] for p in parts) == 26, city
        data = [dict(id=p["id"], name=p["name"], cost=p["cost"], **({"requires": p["requires"]} if p["requires"] else {})) for p in parts]
        data += [
            {"id": "pollution", "name": "오염 제거", "cost": 4},
            {"id": "ground", "name": "잔해 정리", "cost": 3},
            {"id": "greenery", "name": greenery, "cost": 3, "requires": ["ground"]},
            {"id": "sky", "name": "맑은 하늘", "cost": 4, "requires": ["pollution"]},
        ]
        with open(f"LevelData/Sources/LevelData/Levels/{city}.json", "w") as file:
            json.dump({"id": city, "name": name, "landmark": {"id": landmark, "name": title, "parts": data}}, file, ensure_ascii=False, indent=2)
            file.write("\n")
        lines.append(f'        "{city}": .shaped(prefix: "{city}", name: "{title}", parts: [')
        for p in parts:
            x0, y0, x1, y1 = bounds(p["shapes"][0])
            sx, sy = p["spore"] or ((x0 + x1) / 2, (y0 + min(y1, 0.9)) / 2)
            shapes = ", ".join(swift(s) for s in p["shapes"])
            minus = ", ".join(f'"{m}"' for m in p["minus"])
            lines.append(f'            ShapedPart(id: "{p["id"]}", shapes: [{shapes}], minus: [{minus}], spore: ({round(sx, 3)}, {round(sy, 3)})),')
        lines.append("        ]),")
    lines += ["    ]", "}", ""]
    with open("SporeSweep/LandmarkTiers.swift", "w") as file:
        file.write("\n".join(lines))
    print(len(SHAPES), "곳")


main()
