"""영어 번역표를 쓴다. 키는 앱에 적힌 한국어 그대로다(DESIGN.md 10장).

화면의 글은 SwiftUI가 한국어 문장을 키로 찾고, 데이터의 글(도시와 부위의 이름, 레벨 설명)은 앱이 읽을 때
같은 표에서 찾는다. 숫자가 들어가는 자리는 %lld, 글이 들어가는 자리는 %@다.
사용법: python3 Tools/make_strings.py
"""
import glob
import json

UI = {
    # 타이틀, 인트로, 엔딩
    "시작": "Start", "건너뛰기": "Skip", "출동!": "Let's go!", "다음": "Next", "계속하기": "Continue",
    "푸르고 평화롭던 지구.": "Earth was green and peaceful.",
    "어느 날, 장난꾸러기 외계인들이 나타나 끈적한 오염 물질을 마구 뿌렸어요!": "One day, mischievous aliens showed up and splattered sticky goo everywhere!",
    "오염 물질은 온 세상으로 번졌고, 나라마다 아끼던 랜드마크가 망가져 버렸어요.": "The goo spread across the world and ruined every country's beloved landmarks.",
    "하지만 걱정 마세요. 정화 대원이 출동했으니까요!": "But don't worry. The Cleanup Ranger is on the way!",
    "첫 번째 목적지는 서울, 숭례문! 오염 물질을 격리 컨테이너로 내려보내고 도시를 되살려 주세요.": "First stop: Sungnyemun Gate in Seoul! Drop the goo into the containment tank and bring the city back.",
    "지구 정화 완료!": "Earth is clean!",
    "외계인들은 꼬리를 내리고 돌아갔어요.\n온 세상의 랜드마크가 다시 빛나요.\n고마워요, 정화 대원!": "The aliens slunk away.\nLandmarks shine again all over the world.\nThank you, Ranger!",
    "도시": "Cities", "%lld곳": "%lld", "모은 별": "Stars", "복원한 랜드마크": "Landmarks restored",
    "아직 복원하지 못한 랜드마크가 있어요. 별을 더 모아 마저 되살려 보세요!": "Some landmarks still need restoring. Earn more stars and finish the job!",
    # 도시 화면과 복원
    "시험판": "Lab", "지도": "Map", "설정": "Settings", "복원 완료!": "Restored!", "복원 완료": "Restored",
    "시험판 레벨": "Lab levels", "레벨": "Levels", "복원하러 가기": "Go restore", "지금 할 수 있어요!": "Ready now!",
    "복원하러 가기, 지금 복원할 수 있는 부위가 있어요": "Go restore, a part is ready to restore", "도시로 돌아가기": "Back to city",
    "%@ 복원": "Restore %@", "%@을 되살렸어요. 선물로 시작 부스터를 받았어요!": "You brought %@ back. Here are some boosters as a gift!",
    "좋아요!": "Nice!", "%@ · %lld/%lld 복원": "%1$@ · %2$lld/%3$lld restored",
    "쓸 수 있는 별 %lld개": "%lld stars to spend", "· 모은 별 %lld/%lld": "· %lld/%lld earned",
    "복원": "Restore", "%@ 복원, 별 %lld개": "Restore %1$@, %2$lld stars",
    "%@부터 복원해야 해요": "Restore %@ first", "별이 %lld개 더 필요해요": "%lld more stars needed",
    "레벨 %lld, 별 %lld개": "Level %lld, %lld stars", "레벨 %lld, 잠김": "Level %lld, locked", "별 %lld개": "%lld stars",
    # 게임 화면
    "레벨 %lld": "Level %lld", "설명 보기": "Show tip", "이동 +%lld": "+%lld moves",
    "레벨을 찾지 못했어요.": "Level not found.",
    "정화 완료!": "Cleaned up!", "아쉬워요!": "So close!", "%@점": "%@ pts",
    "최고 기록! · 남은 이동 %lld": "New best! · %lld moves left", "남은 이동 %lld": "%lld moves left",
    "선물을 받았어요!": "You got a gift!", "별 %lld개로 랜드마크를 복원할 수 있어요": "You can restore the landmark with %lld stars",
    "이동 횟수를 다 썼어요. 물질이 %lld개 남았어요.": "Out of moves. %lld goo left.",
    "생명 −1 · 남은 생명 %lld개": "−1 life · %lld left",
    "다음 레벨": "Next level", "한 번 더": "Play again", "다시 도전": "Try again",
    "물질이 %lld개 남았어요!": "Only %lld goo left!",
    "이동 %lld번을 더 받아 이어 할 수 있어요.\n한 판에 한 번만 돼요.": "Get %lld more moves and keep going.\nOnce per level.",
    "광고 보고 이동 +%lld": "Watch ad for +%lld moves", "그만하기": "Give up",
    "그만할까요?": "Quit this level?", "지금 나가면 생명이 하나 줄어요": "Leaving now costs one life", "나가기": "Quit",
    "시작!": "Start!", "클리어": "Clear", "별 1개 클리어, 별 2개 %lld점, 별 3개 %lld점": "1 star to clear, 2 stars at %lld, 3 stars at %lld",
    "정화 망치": "Cleanup Hammer", "자리 바꾸기": "Free Swap", "섞기": "Shuffle", "망치": "Hammer", "바꾸기": "Swap",
    "부술 칸을 눌러 주세요": "Tap a tile to smash", "바꿀 블록을 옆으로 밀어 주세요": "Swipe a block to swap it",
    "%@, %lld개%@": "%1$@, %2$lld%3$@", ", 들고 있음": ", selected", ", 고름": ", chosen",
    "제염 빔": "Beam", "중화 폭탄": "Bomb", "정화 코어": "Core",
    "시작 부스터를 골라 보세요": "Pick starting boosters", "사용": "On", "%lld개": "×%lld",
    # 지도
    "준비 중": "Coming soon", "%@, 준비 중": "%@, coming soon", "세계 지도": "World Map",
    "%@ 도착!": "Welcome to %@!", "다음 목적지는 %@!": "Next stop: %@!", "다음 목적지는 %@의 %@!": "Next stop: %2$@, %1$@!",
    "%@, 별 %lld개": "%1$@, %2$lld stars", "%@, 잠김": "%@, locked",
    "앞 권역을 끝내면 열려요": "Finish the previous region to unlock", "준비 중이에요": "Coming soon",
    "도시 %lld곳 · ★ %lld/%lld": "%lld cities · ★ %lld/%lld",
    "%@, %lld개 부위 복원": "%1$@, %2$lld parts restored",
    # 생명력과 광고
    "생명 %lld개": "%lld lives", "생명": "Lives", "생명이 다 떨어졌어요": "Out of lives",
    "다음 생명까지 %@": "Next life in %@", "가득 찼어요": "Full",
    "판에서 지면 하나 줄고, %lld분마다 하나씩 차요.": "You lose one when you fail a level. One refills every %lld minutes.",
    "광고 보고 생명 +1": "Watch ad for +1 life", "오늘은 광고로 더 받을 수 없어요": "No more ad rewards today", "닫기": "Close",
    "생명 +1": "+1 life", "광고 자리예요": "Ad placeholder",
    "광고를 불러오는 중이에요": "Loading ad…", "광고를 불러오지 못했어요": "Couldn't load the ad", "잠시 뒤에 다시 해 보세요.": "Please try again in a moment.",
    "아직 실제 광고는 나오지 않아요.\n%lld초 뒤에 %@을 받아요.": "No real ads yet.\nYou'll get %2$@ in %1$lld seconds.",
    "광고 자리, %lld초 남음": "Ad placeholder, %lld seconds left",
    # 설정
    "배경 음악": "Music", "효과음": "Sound effects", "진동": "Haptics", "켜짐": "On", "꺼짐": "Off",
    "다른 앱으로 음악을 듣고 있으면 배경 음악은 나오지 않아요.": "Music stays off while another app is playing audio.",
    "다음 판부터 다시 보여 드려요": "Tips will show again", "레벨 설명 다시 보기": "Show level tips again",
    "새 규칙이 나오는 레벨을 시작할 때 설명이 다시 떠요.": "Tips appear again when a level introduces a new rule.",
    "인트로 다시 보기": "Watch intro again", "엔딩 다시 보기": "Watch ending again",
    "서울로 돌아가기": "Back to Seoul", "시험판 레벨 해 보기": "Try lab levels",
    "새 규칙을 시험하는 레벨 3개와 레벨 생성기로 만든 견본 16개예요. 기록은 남지 않아요.": "3 test levels and 16 generator samples. Nothing is saved.",
    "엔딩 보기": "Show ending",
    "다 깨지 않아도 엔딩을 볼 수 있어요. 기록은 지금 모은 만큼만 나와요. 개발용 빌드에만 있어요.": "See the ending without finishing. Debug builds only.",
    "도시 바로 가기": "Jump to city",
    "잠금과 상관없이 그 도시로 가고, 그 도시의 레벨이 모두 열려요. 앱을 다시 켜면 원래대로 돌아가요. 거기서 깬 판의 기록은 남아요. 개발용 빌드에만 있어요.": "Opens any city with all its levels unlocked until you restart the app. Clears are saved. Debug builds only.",
    "처음부터 다시 하기": "Start over", "레벨 기록과 복원한 랜드마크가 모두 지워져요.": "Erases all level records and restored landmarks.",
    "정말 처음부터 다시 할까요?": "Really start over?",
    "레벨 기록과 복원한 랜드마크가 사라지고 되돌릴 수 없어요.": "All level records and restored landmarks will be lost for good.",
    "그만두기": "Cancel", "모두 지우기": "Erase all",
    "저장된 진행을 읽지 못했어요. 이번에 한 기록은 저장되지 않아요.": "Couldn't read your saved progress. This session won't be saved.",
    "진행을 지우지 못했어요.": "Couldn't erase progress.", "진행을 저장하지 못했어요.": "Couldn't save progress.",
    # 일일 보상과 iCloud
    "오늘의 선물": "Daily Gift", "%lld일째": "Day %lld", "매일 들르면 선물이 커져요. 하루를 거르면 처음부터예요.": "Come back every day for bigger gifts. Miss a day and the streak restarts.",
    "받기": "Claim", "오늘": "Today", "생명 가득": "Full lives", "선물 받기": "Claim gift", "내일 또 만나요!": "See you tomorrow!",
    "iCloud에 저장": "Save to iCloud", "기기를 바꿔도 진행이 이어져요. 같은 Apple 계정으로 로그인한 기기끼리 맞춰져요.": "Keeps your progress across devices signed in to the same Apple Account.",
    # 보드
    "이동 %lld": "Moves %lld", "%lld점": "%lld pts", "물질 %lld/%lld": "Goo %lld/%lld",
    "멋져요!": "Great!", "굉장해요!": "Awesome!", "환상적이에요!": "Fantastic!",
    # 권역
    "동아시아": "East Asia", "남아시아": "South Asia", "중동·아프리카": "Middle East & Africa", "남유럽": "Southern Europe",
    "서유럽": "Western Europe", "북미": "North America", "남미": "South America", "오세아니아·극지": "Oceania & Antarctica",
}

NAMES = {
    "서울": "Seoul", "도쿄": "Tokyo", "베이징": "Beijing", "뉴델리": "New Delhi", "방콕": "Bangkok", "싱가포르": "Singapore",
    "카이로": "Cairo", "두바이": "Dubai", "케이프타운": "Cape Town", "로마": "Rome", "아테네": "Athens", "바르셀로나": "Barcelona",
    "파리": "Paris", "런던": "London", "암스테르담": "Amsterdam", "뉴욕": "New York", "샌프란시스코": "San Francisco", "워싱턴": "Washington",
    "리우데자네이루": "Rio de Janeiro", "부에노스아이레스": "Buenos Aires", "이스터섬": "Easter Island", "시드니": "Sydney", "오클랜드": "Auckland", "남극": "Antarctica",
    "숭례문": "Sungnyemun Gate", "도쿄타워": "Tokyo Tower", "만리장성": "Great Wall", "인디아 게이트": "India Gate", "왓 아룬": "Wat Arun",
    "마리나 베이 샌즈": "Marina Bay Sands", "피라미드와 스핑크스": "Pyramids & Sphinx", "부르즈 알 아랍": "Burj Al Arab",
    "테이블마운틴 케이블카": "Table Mountain Cableway", "콜로세움": "Colosseum", "파르테논 신전": "Parthenon", "사그라다 파밀리아": "Sagrada Família",
    "에펠탑": "Eiffel Tower", "빅벤": "Big Ben", "풍차": "Windmill", "자유의 여신상": "Statue of Liberty", "금문교": "Golden Gate Bridge",
    "국회의사당": "US Capitol", "구세주 그리스도상": "Christ the Redeemer", "오벨리스코": "Obelisco", "모아이": "Moai",
    "오페라하우스": "Opera House", "스카이타워": "Sky Tower", "과학 기지": "Research Station",
    "오염 제거": "Clear the goo", "잔해 정리": "Clear the rubble", "맑은 하늘": "Clear sky", "녹지": "Greenery", "오아시스": "Oasis", "해변": "Beach",
    "꽃밭": "Flower field", "소나무 숲": "Pine grove", "올리브 숲": "Olive grove", "공원": "Park", "정원": "Garden", "강변": "Riverside",
    "튤립밭": "Tulip field", "섬 잔디밭": "Island lawn", "양귀비 언덕": "Poppy hill", "잔디 광장": "Lawn", "열대 숲": "Rainforest",
    "자카란다 길": "Jacaranda avenue", "풀밭": "Grassland", "항구 공원": "Harbor park", "부두 공원": "Wharf park", "얼음 벌판": "Ice field",
    "홍예문": "Arched gateway", "왼쪽 석축": "Left stone wall", "오른쪽 석축": "Right stone wall", "1층 문루": "Lower pavilion", "2층 문루": "Upper pavilion",
    "받침 다리": "Legs", "대전망대": "Main deck", "철탑 몸통": "Tower body", "특별전망대": "Top deck", "안테나": "Antenna",
    "왼쪽 성벽": "Left wall", "오른쪽 성벽": "Right wall", "망루 아래층": "Watchtower base", "망루 위층": "Watchtower top", "누각 지붕": "Pavilion roof",
    "왼쪽 난간": "Left balustrade", "오른쪽 난간": "Right balustrade", "왼쪽 기둥": "Left pier", "오른쪽 기둥": "Right pier", "아치": "Arch", "꼭대기": "Top",
    "기단": "Base", "왼쪽 탑": "Left tower", "오른쪽 탑": "Right tower", "중앙 탑 아래층": "Central tower base", "중앙 탑 첨탑": "Central spire",
    "저층부": "Podium", "왼쪽 타워": "Left tower", "가운데 타워": "Middle tower", "오른쪽 타워": "Right tower", "스카이파크": "SkyPark",
    "왼쪽 피라미드": "Left pyramid", "오른쪽 피라미드": "Right pyramid", "스핑크스": "Sphinx", "대피라미드 아래": "Great Pyramid base",
    "대피라미드 가운데": "Great Pyramid middle", "대피라미드 꼭대기": "Great Pyramid top",
    "인공섬": "Island", "아래층": "Lower floors", "가운데층": "Middle floors", "위층과 헬기장": "Upper floors & helipad", "돛대": "Mast",
    "아래 승강장": "Lower station", "철탑과 줄": "Pylon & cables", "산 위 승강장": "Upper station", "케이블카": "Cable car",
    "1층 아치": "First arcade", "2층 아치": "Second arcade", "3층 아치": "Third arcade", "안쪽 벽 위층": "Inner wall top", "바깥벽 위층": "Outer wall top",
    "띠 장식": "Frieze", "지붕": "Roof", "정문": "Portals", "장미창": "Rose window", "가운데 두 탑": "Two middle towers",
    "1층 전망대": "First platform", "2층 전망대": "Second platform",
    "의사당 아래층": "Palace hall", "의사당 지붕": "Palace roof", "시계탑 몸통": "Clock tower", "시계": "Clock", "첨탑": "Spire",
    "벽돌 받침": "Brick base", "발코니": "Gallery", "몸통": "Body", "날개": "Sails",
    "별 모양 기단": "Star base", "받침대": "Pedestal", "옷자락": "Robe", "몸과 왕관": "Body & crown", "횃불": "Torch",
    "교각": "Piers", "다리 상판": "Deck", "주 케이블": "Main cables",
    "왼쪽 날개": "Left wing", "오른쪽 날개": "Right wing", "가운데 현관": "Portico", "돔 받침": "Drum", "돔": "Dome",
    "바위와 받침대": "Rock & pedestal", "왼팔": "Left arm", "오른팔": "Right arm", "머리": "Head",
    "왼쪽 건물": "Left building", "오른쪽 건물": "Right building", "탑 아래": "Obelisk base", "탑 가운데": "Obelisk middle", "탑 꼭대기": "Obelisk tip",
    "첫째 석상": "First moai", "둘째 석상": "Second moai", "가운데 큰 석상": "Big middle moai", "넷째 석상": "Fourth moai", "다섯째 석상": "Fifth moai",
    "왼쪽 작은 지붕": "Small left shells", "가운데 지붕": "Middle shells", "큰 지붕": "Big shells", "오른쪽 지붕": "Right shells",
    "아래 건물": "Base building", "탑 기둥": "Shaft", "전망대": "Observation pod", "윗부분": "Upper section",
    "첫째 기지": "Module 1", "둘째 기지": "Module 2", "셋째 기지": "Module 3", "넷째 기지와 설상차": "Module 4 & snowcat", "지붕 장비": "Roof gear",
}

TUTORIALS = {
    "블록을 옆 칸으로 밀어": "Swipe a block to its neighbor to match 3 of the same shape. Clear the blocks under the pink goo and drop it all the way into the containment tank at the bottom!",
    "물질이 여러 개면": "When there are several goo blobs, drop them all. The screen follows the one furthest behind. The bar on the right shows the whole board and where the goo is. Goo can also slide diagonally when the tile below is blocked.",
    "4개를 일렬로": "Match 4 in a row for a Beam, an L or T shape for a Bomb, and 5 in a row for a Core. Swipe a special block to set it off where it lands. Beams clear a line, Bombs clear the area, and Cores clear every block of the type you swap with. Swap two specials for a bigger blast!",
    "콘크리트는 움직이지": "Concrete doesn't move and blocks the goo. Match next to it or hit it with a special block to break it.",
    "보드 아래의 아이템": "The items under the board don't use up moves. The Hammer smashes one tile, Swap trades two blocks even if they don't match, and Shuffle mixes the board. Save them for when you're stuck. The Hammer doesn't work on goo or walls.",
    "화면 위에서 기다리는": "Some goo is waiting above the screen. Clear as many blocks in that column as the number shows and the goo drops in.",
    "가로 2칸짜리": "Wide goo needs the whole space under it cleared at once. Match horizontally right below it or use a Beam. Big goo can't be moved sideways.",
    "철망에 갇힌": "Caged blocks can't move. Include one in a match to break the cage, then match it again to clear it.",
    "벽은 어떤": "Walls can't be broken. When the tile below is blocked, goo slides to an empty tile diagonally below. Clear the block there and roll the goo down the slope.",
    "2×2 물질은": "2×2 goo needs two columns cleared under it at once. Break the concrete first to open the way.",
    "오염 슬러지는": "Sludge spreads to a neighbor every turn you don't clear any. Match next to it to wipe it out!",
    "오염 고치는": "A cocoon is alien slime hardened around a block. Match the same shape as the block inside, right next to it, to pop it. Other shapes won't work, but special blocks will.",
    "잔해 더미는": "Rubble is a pile of fallen stone. You can't swipe it, but it falls like a block. Match next to it or hit it with a special block to clear it.",
    "포자 둥지는": "A spore nest turns a neighboring block into sludge every three turns. Match next to it twice, or hit it twice with special blocks, to destroy it. Hurry before the sludge spreads.",
    "시한 포자는": "A timed spore sticks to a block and counts down every turn. At 0 it bursts and covers the area in sludge. Match that block or clear it with a special block before then.",
    "오염 안개가": "Fog hides the blocks under it. You can still swipe them. Match next to the fog or hit it with a special block to clear it.",
    "끈끈이 바닥": "Blocks on sticky floor can't be swiped. Slide a neighbor in to match that block, or hit it with a special block, and the sticky floor is gone.",
    "포자 알은": "A spore egg has a hard shell, so matching next to it does nothing. Only special blocks like the Beam, Bomb and Core can crack it. The Hammer works too.",
    "쇠사슬에 감긴": "A chained block is locked twice. Match it once to break the chain and leave a cage, then match again to break the cage.",
    "포자 보호막": "Blocks inside a spore shield can't be cleared by special blocks. Match the block itself to pop the shield.",
    "운석 조각은": "Meteorite chunks fall when the tile below is empty. Matching next to them does nothing; only special blocks can break them.",
    "안개 굴뚝은": "A fog vent puffs fog onto a neighboring tile every three turns. Match next to it twice, or hit it twice with special blocks, to destroy it.",
    "얼음 블록은": "Frozen blocks can't be swiped or matched. Match next to one or hit it with a special block and it thaws into a normal block.",
}


def escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main():
    table = dict(UI)
    missing = []
    for path in sorted(glob.glob("LevelData/Sources/LevelData/Levels/*.json")):
        data = json.load(open(path))
        if "landmark" in data:
            names = [data["name"], data["landmark"]["name"]] + [part["name"] for part in data["landmark"]["parts"]]
            for name in names:
                if name in NAMES:
                    table[name] = NAMES[name]
                else:
                    missing.append(name)
        elif data.get("tutorial") and not data["id"].startswith(("lab", "sample")):
            text = data["tutorial"]
            match = [english for start, english in TUTORIALS.items() if text.startswith(start)]
            if match:
                table[text] = match[0]
            else:
                missing.append(text[:30])
    with open("SporeSweep/en.lproj/Localizable.strings", "w") as file:
        file.write("/* Tools/make_strings.py가 쓴 파일이다. 손으로 고치지 말고 그 표를 고친 뒤 다시 돌린다. */\n")
        for key in sorted(table):
            file.write(f'"{escape(key)}" = "{escape(table[key])}";\n')
    with open("SporeSweep/ko.lproj/Localizable.strings", "w") as file:
        file.write("/* 한국어는 앱에 적힌 글을 그대로 쓴다. 이 파일은 한국어를 지원한다고 알리기 위해 둔다. */\n")
    print(len(table), "개. 번역이 없는 것:", sorted(set(missing)))


main()
