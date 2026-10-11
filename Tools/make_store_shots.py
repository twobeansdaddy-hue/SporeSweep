"""스토어 스크린샷을 만든다. 화면 캡처 위에 문구를 얹는다(1290×2796, 6.9인치).

사용법: python3 Tools/make_store_shots.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1290, 2796
FONT = "SporeSweep/Fonts/Jua-Regular.ttf"
SHOTS = "Marketing/screenshots/"
ART = "Marketing/art/"
OUT = "Marketing/store/ko/"


def backdrop(top, bottom):
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return image


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def caption(image, title, subtitle, brand=None):
    draw = ImageDraw.Draw(image)
    big = ImageFont.truetype(FONT, 118)
    small = ImageFont.truetype(FONT, 58)
    y = 150
    if brand:
        # 첫 장에는 게임 이름을 알약 모양 바탕 위에 적는다.
        font = ImageFont.truetype(FONT, 64)
        width = draw.textlength(brand, font=font)
        draw.rounded_rectangle((W / 2 - width / 2 - 44, 62, W / 2 + width / 2 + 44, 158), radius=48, fill=(60, 15, 70))
        draw.text((W // 2, 110), brand, font=font, fill=(255, 226, 120), anchor="mm")
        y = 196
    for line in title.split("\n"):
        draw.text((W // 2 + 4, y + 6), line, font=big, fill=(60, 15, 70), anchor="ma")
        draw.text((W // 2, y), line, font=big, fill="white", anchor="ma")
        y += 140
    draw.text((W // 2, y + 16), subtitle, font=small, fill=(255, 226, 120), anchor="ma")


def place(image, screen, top=560):
    """화면 캡처를 둥근 테두리의 기기 모양으로 아래쪽에 놓는다."""
    width = 1010
    screen = screen.resize((width, round(screen.height * width / screen.width)), Image.LANCZOS)
    frame = Image.new("RGBA", (screen.width + 36, screen.height + 36), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width, frame.height), radius=96, fill=(20, 20, 36, 255))
    frame.alpha_composite(rounded(screen, 80), (18, 18))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        ((W - frame.width) // 2, top + 30, (W + frame.width) // 2, top + 30 + frame.height), radius=96, fill=(0, 0, 0, 130)
    )
    image.paste(shadow.filter(ImageFilter.GaussianBlur(28)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(28)))
    image.paste(frame, ((W - frame.width) // 2, top), frame)


def shot(name):
    return Image.open(SHOTS + name + ".jpg").convert("RGB")


def split(ruined, restored):
    """복원된 도시 화면에서 랜드마크 그림의 왼쪽 절반만 폐허로 바꾼다. 가운데에 흰 선을 긋는다."""
    out = restored.copy()
    half = restored.width // 2
    top, bottom = 386, 1086
    out.paste(ruined.crop((0, top, half, bottom)), (0, top))
    ImageDraw.Draw(out).line([(half, top + 14), (half, bottom - 14)], fill="white", width=8)
    return out


def landmarks(cities):
    """랜드마크 그림 여섯 장을 두 줄로 놓은 화면."""
    out = Image.new("RGB", (1206, 2622), (26, 28, 56))
    for index, city in enumerate(cities):
        art = Image.open(f"{ART}landmark_{city}_restored.jpg").convert("RGB").resize((1126, 750))
        out.paste(rounded(art, 60), (40, 70 + index * 850), rounded(art, 60))
    return out


PINK = ((255, 92, 168), (120, 60, 200))
BLUE = ((60, 150, 255), (70, 50, 170))
PURPLE = ((150, 80, 220), (40, 30, 110))
GREEN = ((60, 200, 140), (30, 90, 160))
ORANGE = ((255, 150, 70), (200, 60, 130))

PAGES = [
    ("01_restore", PINK, "망가진 랜드마크를\n되살려요", "퍼즐을 풀어 모은 별로 한 부위씩 복원해요", lambda: split(shot("10_seoul_ruined"), shot("10_seoul_restored"))),
    ("02_play", BLUE, "분홍 오염 물질을\n아래로, 아래로!", "블록을 맞춰 길을 열고 격리 컨테이너에 쏙", lambda: shot("40_play_seoul_tutorial")),
    ("03_effects", PURPLE, "특수 블록으로\n시원하게 팡!", "제염 빔, 중화 폭탄, 정화 코어", lambda: shot("80_effect_3")),
    ("04_world", GREEN, "세계 24개 도시\n380개 레벨", "서울에서 남극까지, 여덟 권역의 여행", lambda: landmarks(["rome", "cairo", "paris"])),
    ("05_map", ORANGE, "정화할수록\n지도가 살아나요", "잿빛 대륙이 다시 초록으로", lambda: shot("61_map_world_progress")),
    ("06_obstacles", BLUE, "도시마다\n새로운 장애물", "고치, 둥지, 안개, 얼음까지 열일곱 가지", lambda: shot("55_play_all_pieces")),
]

for name, colors, title, subtitle, screen in PAGES:
    page = backdrop(*colors)
    first = name.startswith("01")
    caption(page, title, subtitle, brand="포자 대청소" if first else None)
    place(page, screen(), top=600 if first else 560)
    page.save(f"{OUT}{name}.jpg", quality=92)
print(len(PAGES), "장")
