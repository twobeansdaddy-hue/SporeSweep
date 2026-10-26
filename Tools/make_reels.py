"""인스타그램 릴스·유튜브 쇼츠용 세로 영상 두 편을 만든다(1080×1920). 2026-10-26.

- R1 복원 편: 폐허가 된 랜드마크가 차례로 살아난다. 권리 문제가 알려진 7곳은 쓰지 않는다.
- R2 예고편(제작기): "AI랑 혼자 게임을 만들었어요" → 기획서, 그림, 봇 시험, 동호회 요청으로 넣은 드론, 세 가지 판 → 끝 화면.

끝 화면에는 회사 로고(code404, `~/Developer/code404-brand`)를 넣는다.
자막·카드 그림은 여기서 그리고, 편집 내용을 JSON으로 적어 `promo_render`에 넘긴다(Tools/make_promos.py와 같은 방식).
사용법:
  swiftc -O Tools/promo_render.swift -o /tmp/promo_render
  python3 Tools/make_reels.py /tmp/promo_render
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
FONT = "SporeSweep/Fonts/Jua-Regular.ttf"
OUT = "Marketing/promo/"
A = OUT + "assets/reels/"
os.makedirs(A, exist_ok=True)
FX = "Marketing/videos/03_effects.mp4"
DRONE = OUT + "src/drone_combo.mp4"  # 시뮬레이터에서 -showcase 1로 찍은 드론+코어 조합과 드론 한 대(소리 없음)
INTRO_MUSIC = "GameScene/Sources/GameScene/Music/music_intro.m4a"
GAME_MUSIC = "GameScene/Sources/GameScene/Music/music_game.m4a"
LOGO_WHITE = os.path.expanduser("~/Developer/code404-brand/logo/code404_horizontal_white@3x.png")
INK = (30, 27, 75)
VIOLET = (124, 58, 237)
YELLOW = (255, 226, 120)


def font(size):
    return ImageFont.truetype(FONT, size)


def gradient(top, bottom):
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return image


def caption(name, text, size=110, color=(255, 255, 255), pill=(30, 12, 55, 220)):
    """가운데 정렬한 자막. 어두운 알약 바탕 위에 적어 어떤 화면 위에서도 읽힌다."""
    f = font(size)
    lines = text.split("\n")
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    width = max(probe.textlength(line, font=f) for line in lines)
    line_height = round(size * 1.2)
    height = line_height * len(lines) + 70
    image = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((W / 2 - width / 2 - 56, 0, W / 2 + width / 2 + 56, height), radius=64, fill=pill)
    for index, line in enumerate(lines):
        y = 35 + index * line_height + line_height / 2
        draw.text((W / 2 + 3, y + 5), line, font=f, fill=(0, 0, 0, 160), anchor="mm")
        draw.text((W / 2, y), line, font=f, fill=color, anchor="mm")
    path = A + name + ".png"
    image.save(path)
    return {"image": path, "frame": [0, 0, W, height]}


def landmark_card(city, state, label):
    """랜드마크 한 곳을 화면 가득. 흐린 배경 위에 그림을 크게 놓고 이름을 적는다."""
    art = Image.open(f"Marketing/art/landmark_{city}_{state}.jpg").convert("RGB")
    back = art.resize((round(H * 1.5), H)).crop((round(H * 0.75) - W // 2, 0, round(H * 0.75) + W // 2, H))
    back = back.filter(ImageFilter.GaussianBlur(40)).point(lambda value: value * 0.55)
    crop = art.crop((art.width // 2 - 660, 20, art.width // 2 + 660, 1010)).resize((1040, 780), Image.LANCZOS)
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *crop.size), radius=60, fill=255)
    back.paste(crop, (20, 600), mask)
    draw = ImageDraw.Draw(back)
    draw.rounded_rectangle((16, 596, 1064, 1384), radius=64, outline=(255, 255, 255), width=8)
    draw.text((W // 2 + 3, 1505), label, font=font(96), fill=(0, 0, 0), anchor="mm")
    draw.text((W // 2, 1500), label, font=font(96), fill=YELLOW if state == "restored" else (230, 230, 240), anchor="mm")
    path = A + f"{city}_{state}.jpg"
    back.save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def picture_card(name, src, title, sub=None, crop=None):
    """그림 한 장을 둥근 틀에 넣고 위에 제목을 단다(제작기의 그림 편)."""
    back = gradient((24, 20, 60), (60, 30, 110)).convert("RGBA")
    art = Image.open(src).convert("RGB")
    if crop:
        art = art.crop(crop)
    box_w = 980
    scale = box_w / art.width
    art = art.resize((box_w, round(art.height * scale)), Image.LANCZOS)
    if art.height > 1150:
        top = (art.height - 1150) // 2
        art = art.crop((0, top, box_w, top + 1150))
    mask = Image.new("L", art.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *art.size), radius=48, fill=255)
    y = 560 + (1150 - art.height) // 2
    back.paste(art, ((W - box_w) // 2, y), mask)
    draw = ImageDraw.Draw(back)
    draw.text((W // 2, 300), title, font=font(104), fill="white", anchor="mm")
    if sub:
        draw.text((W // 2, 430), sub, font=font(60), fill=YELLOW, anchor="mm")
    path = A + name + ".jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def design_card():
    """기획서를 41번 고쳐 쓴 것을 판 번호가 쏟아지는 모양으로 보여 준다."""
    back = gradient((18, 16, 44), (40, 22, 80)).convert("RGBA")
    draw = ImageDraw.Draw(back)
    lines = [l for l in open("DESIGN.md", encoding="utf-8").read().splitlines() if l.startswith("v0.")]
    small = font(40)
    y = 520
    for line in lines[:22]:
        text = line[:30] + "..."
        draw.text((90, y), text, font=small, fill=(200, 190, 240, 170))
        y += 54
    draw.rectangle((0, 1680, W, H), fill=(18, 16, 44, 255))
    draw.text((W // 2, 300), "기획서부터", font=font(110), fill="white", anchor="mm")
    draw.text((W // 2, 430), "v0.1부터 v0.41까지, 41번 고쳐 썼어요", font=font(62), fill=YELLOW, anchor="mm")
    path = A + "design.jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def landmark_grid():
    """폐허와 복원을 나란히 놓은 세 쌍(권리 문제가 없는 곳만: 서울, 로마, 파리)."""
    back = gradient((24, 20, 60), (60, 30, 110)).convert("RGBA")
    draw = ImageDraw.Draw(back)
    draw.text((W // 2, 300), "그림은 고치고 또 고치고", font=font(100), fill="white", anchor="mm")
    draw.text((W // 2, 425), "랜드마크 24곳, 폐허와 복원 두 벌씩", font=font(58), fill=YELLOW, anchor="mm")
    cell_w, cell_h, gap = 470, 340, 24
    for row, city in enumerate(["seoul", "rome", "paris"]):
        for col, state in enumerate(["ruined", "restored"]):
            art = Image.open(f"Marketing/art/landmark_{city}_{state}.jpg").convert("RGB")
            ratio = cell_w / cell_h
            cw = min(art.width, round(art.height * ratio))
            ch = round(cw / ratio)
            art = art.crop(((art.width - cw) // 2, (art.height - ch) // 2, (art.width + cw) // 2, (art.height + ch) // 2)).resize((cell_w, cell_h), Image.LANCZOS)
            mask = Image.new("L", art.size, 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, cell_w, cell_h), radius=36, fill=255)
            x = (W - 2 * cell_w - gap) // 2 + col * (cell_w + gap)
            y = 560 + row * (cell_h + gap)
            back.paste(art, (x, y), mask)
    draw.text((W // 2 - (cell_w + gap) // 2, 1700), "폐허", font=font(64), fill=(220, 215, 235), anchor="mm")
    draw.text((W // 2 + (cell_w + gap) // 2, 1700), "복원", font=font(64), fill=YELLOW, anchor="mm")
    path = A + "landmark_grid.jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def platforms_card():
    back = gradient((40, 20, 90), (124, 58, 237)).convert("RGBA")
    draw = ImageDraw.Draw(back)
    draw.text((W // 2, 420), "한 번 만들어서", font=font(100), fill="white", anchor="mm")
    for i, (name, sub) in enumerate([("iPhone", "App Store 심사 중"), ("Android", "비공개 테스트"), ("웹", "동호회 테스트 중")]):
        y = 700 + i * 300
        draw.rounded_rectangle((140, y, 940, y + 230), radius=60, fill=(255, 255, 255, 235))
        draw.text((W // 2, y + 85), name, font=font(96), fill=INK, anchor="mm")
        draw.text((W // 2, y + 170), sub, font=font(50), fill=VIOLET, anchor="mm")
    path = A + "platforms.jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def end_card(name, headline):
    """끝 화면: 앱 아이콘, 이름, 한 줄 소개, 곧 만나요, 그리고 맨 아래 code404 로고."""
    image = gradient((255, 92, 168), (110, 55, 200)).convert("RGBA")
    draw = ImageDraw.Draw(image)
    icon = Image.open("Art/incoming/app_icon.png").convert("RGBA").resize((360, 360), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 360, 360), radius=82, fill=255)
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((360, 470, 720, 830), radius=82, fill=(40, 10, 70, 150))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
    image.paste(icon, (360, 440), mask)
    draw.text((W // 2 + 4, 266), headline, font=font(88), fill=(70, 15, 80), anchor="mm")
    draw.text((W // 2, 260), headline, font=font(88), fill="white", anchor="mm")
    draw.text((W // 2 + 5, 967), "포자 대청소", font=font(168), fill=(70, 15, 80), anchor="mm")
    draw.text((W // 2, 960), "포자 대청소", font=font(168), fill="white", anchor="mm")
    draw.text((W // 2, 1105), "세계 랜드마크 복원 매치3 퍼즐", font=font(60), fill=YELLOW, anchor="mm")
    draw.rounded_rectangle((300, 1250, 780, 1385), radius=68, fill=(50, 15, 75))
    draw.text((W // 2, 1318), "곧 만나요!", font=font(74), fill="white", anchor="mm")
    logo = Image.open(LOGO_WHITE).convert("RGBA")
    logo_w = 520
    logo = logo.resize((logo_w, round(logo.height * logo_w / logo.width)), Image.LANCZOS)
    image.alpha_composite(logo, ((W - logo_w) // 2, 1620))
    path = A + name + ".jpg"
    image.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def layer(asset, at, dur, y=None, **options):
    item = dict(asset, at=at, dur=dur, **options)
    if y is not None:
        item["frame"] = [0, y, asset["frame"][2], asset["frame"][3]]
    return item


def seg(src, start, at, dur, zoom=(1, 1), focus=(0.5, 0.47), volume=0):
    return dict(src=src, start=start, at=at, dur=dur, zoomFrom=zoom[0], zoomTo=zoom[1], focus=list(focus), volume=volume)


def restore():
    """R1 복원 편, 17초."""
    layers = []
    seoul = [landmark_card("seoul", "ruined", "서울, 숭례문"), landmark_card("seoul", "restored", "서울, 숭례문")]
    layers.append(layer(seoul[0], 0, 2.9, scaleFrom=1.0, scaleTo=1.06))
    layers.append(layer(caption("r1", "외계 포자가\n지구를 덮쳤다!", 118), 0.25, 2.1, y=170, pop=True, fadeOut=0.15))
    layers.append(layer(seoul[1], 2.3, 2.0, wipe=0.55))
    layers.append(layer(caption("r2", "되살려 주세요!", 124, color=YELLOW), 2.95, 1.25, y=230, pop=True, fadeOut=0.15))
    at = 4.3
    for city, label in [("rome", "로마, 콜로세움"), ("cairo", "카이로, 피라미드"), ("paris", "파리, 에펠탑"),
                        ("london", "런던, 빅벤"), ("newyork", "뉴욕, 자유의 여신상")]:
        layers.append(layer(landmark_card(city, "ruined", label), at, 1.4))
        layers.append(layer(landmark_card(city, "restored", label), at + 0.5, 0.9, wipe=0.32))
        at += 1.4
    layers.append(layer(caption("r3", "세계 24개 도시", 110), 4.4, 6.8, y=230, pop=True, fadeOut=0.15))
    layers.append(layer(caption("r4", "블록을 맞춰\n오염을 치우세요!", 104), 11.4, 2.5, y=150, pop=True, fadeOut=0.15))
    layers.append(layer(end_card("end_r1", "지구가 다시 반짝일 때까지"), 14.0, 3.0, fadeIn=0.3))
    return dict(
        output=OUT + "R1_restore.mp4", duration=17,
        segments=[seg(FX, 9, 0, 11.3), seg(DRONE, 4.6, 11.3, 2.7, zoom=(1.0, 1.08), focus=(0.5, 0.45)), seg(FX, 12, 14.0, 3.0)],
        audio=[dict(src=INTRO_MUSIC, start=0, at=0, dur=17, volume=0.9)], layers=layers,
    )


def teaser():
    """R2 예고편(제작기), 19초."""
    layers = [
        layer(caption("t1", "AI랑 둘이서\n게임을 만들었어요", 112), 0.2, 2.9, y=160, pop=True, fadeOut=0.15),
        layer(design_card(), 3.2, 2.3, fadeIn=0.15),
        layer(landmark_grid(), 5.5, 2.5, fadeIn=0.15),
        layer(caption("t2", "봇이 76,000판을 두며\n난이도를 맞췄어요", 96), 8.2, 2.3, y=170, pop=True, fadeOut=0.15),
        layer(caption("t3", "동호회 요청:\n\"2x2 매치도 넣어 주세요!\"", 96, color=YELLOW), 10.6, 1.6, y=170, pop=True, fadeOut=0.12),
        layer(caption("t4", "하루 만에 청소 드론 추가!", 96), 12.2, 1.9, y=170, pop=True, fadeOut=0.12),
        layer(platforms_card(), 14.1, 2.0, fadeIn=0.15),
        layer(end_card("end_r2", "직접 해 보세요"), 16.1, 2.9, fadeIn=0.3),
    ]
    segments = [
        seg(DRONE, 4.6, 0, 3.2, zoom=(1.05, 1.15), focus=(0.5, 0.42)),
        seg(DRONE, 4.6, 3.2, 5.0),           # 카드에 가려진다
        seg(FX, 2.0, 8.2, 2.4, zoom=(1.0, 1.08)),
        seg(DRONE, 35.6, 10.6, 3.5, zoom=(1.0, 1.1), focus=(0.5, 0.55)),
        seg(FX, 12, 14.1, 4.9),
    ]
    return dict(output=OUT + "R2_teaser.mp4", duration=19, segments=segments,
                audio=[dict(src=GAME_MUSIC, start=2, at=0, dur=19, volume=0.6)], layers=layers)


for name, edit in [("R1", restore()), ("R2", teaser())]:
    path = f"{A}edit_{name}.json"
    json.dump(edit, open(path, "w"), ensure_ascii=False, indent=1)
    result = subprocess.run([sys.argv[1], path], capture_output=True, text=True)
    print(name, result.stdout.strip(), result.stderr.strip()[-300:])
