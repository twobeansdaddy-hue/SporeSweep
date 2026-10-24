"""남은 다섯 권역 15개 도시의 도시 데이터(JSON)를 쓰고, 레벨 생성 명령을 출력한다."""
import json

# id, 이름, 랜드마크 id, 랜드마크 이름, 아래에서 위로 다섯 토막의 이름, "녹지"의 이름
CITIES = [
    ("rome", "로마", "colosseum", "콜로세움", ["1층 아치", "2층 아치", "3층 아치", "맨 위층", "바깥벽 꼭대기"], "소나무 숲"),
    ("athens", "아테네", "parthenon", "파르테논 신전", ["기단", "기둥 아래", "기둥 위", "띠 장식", "지붕"], "올리브 숲"),
    ("barcelona", "바르셀로나", "sagradafamilia", "첨탑 대성당", ["정문", "장미창", "탑 아래", "탑 가운데", "탑 꼭대기"], "공원"),
    ("paris", "파리", "eiffel", "에펠탑", ["받침 다리", "1층 전망대", "2층 전망대", "철탑 몸통", "꼭대기"], "정원"),
    ("london", "런던", "bigben", "빅벤", ["의사당 아래층", "의사당 지붕", "시계탑 몸통", "시계", "첨탑"], "강변"),
    ("amsterdam", "암스테르담", "windmill", "풍차", ["벽돌 받침", "발코니", "몸통", "지붕", "날개"], "튤립밭"),
    ("newyork", "뉴욕", "liberty", "자유의 여신상", ["별 모양 기단", "받침대", "옷자락", "몸과 머리", "횃불"], "섬 잔디밭"),
    ("sanfrancisco", "샌프란시스코", "goldengate", "금문교", ["교각", "다리 상판", "탑 아래", "주 케이블", "탑 꼭대기"], "양귀비 언덕"),
    ("washington", "워싱턴", "capitol", "국회의사당", ["계단", "양쪽 날개", "가운데 현관", "돔 받침", "돔"], "잔디 광장"),
    ("rio", "리우데자네이루", "redeemer", "언덕 위 거상", ["바위 봉우리", "받침대", "옷자락", "두 팔", "머리"], "열대 숲"),
    ("buenosaires", "부에노스아이레스", "obelisco", "오벨리스코", ["광장 받침", "양옆 건물", "탑 아래", "탑 가운데", "탑 꼭대기"], "자카란다 길"),
    ("easterisland", "이스터섬", "moai", "모아이", ["돌 제단", "석상 몸통", "석상 어깨", "석상 얼굴", "돌 모자"], "풀밭"),
    ("sydney", "시드니", "operahouse", "조개 지붕 공연장", ["기단", "유리벽", "작은 지붕", "가운데 지붕", "큰 지붕"], "항구 공원"),
    ("auckland", "오클랜드", "skytower", "항구 전망탑", ["아래 건물", "탑 기둥", "전망대", "윗부분", "안테나"], "부두 공원"),
    ("antarctica", "남극", "station", "과학 기지", ["기둥 다리", "기지 아래", "기지 창문", "지붕 장비", "기상 탑"], "얼음 벌판"),
]
IDS = ["base", "tier2", "tier3", "tier4", "top"]
COSTS = [5, 5, 5, 5, 6]

if __name__ == "__main__":
    for city, name, landmark, title, tiers, greenery in CITIES:
        parts = []
        for index, tier in enumerate(tiers):
            part = {"id": IDS[index], "name": tier, "cost": COSTS[index]}
            if index > 0:
                part["requires"] = [IDS[index - 1]]
            parts.append(part)
        parts += [
            {"id": "pollution", "name": "오염 제거", "cost": 4},
            {"id": "ground", "name": "잔해 정리", "cost": 3},
            {"id": "greenery", "name": greenery, "cost": 3, "requires": ["ground"]},
            {"id": "sky", "name": "맑은 하늘", "cost": 4, "requires": ["pollution"]},
        ]
        data = {"id": city, "name": name, "landmark": {"id": landmark, "name": title, "parts": parts}}
        with open(f"LevelData/Sources/LevelData/Levels/{city}.json", "w") as file:
            json.dump(data, file, ensure_ascii=False, indent=2)
            file.write("\n")
    print(len(CITIES))
