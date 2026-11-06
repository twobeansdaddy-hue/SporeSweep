"""인스타그램 릴스·유튜브 쇼츠용 세로 영상 두 편을 만든다(1080×1920). 2026-10-26.

- R1 복원 편: 폐허가 된 랜드마크가 차례로 살아난다. 권리 문제가 알려진 7곳은 쓰지 않는다.
- R2 예고편(제작기): "AI랑 혼자 게임을 만들었어요" → 기획서, 그림, 봇 시험, 테스터 한마디로 넣은 드론, 세 가지 판 → 끝 화면.

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
# 자막 글꼴: 회사 CI와 같은 Pretendard ExtraBold(SIL OFL).
FONT = os.path.expanduser("~/Developer/code404-brand/fonts/otf/Pretendard-ExtraBold.otf")
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
    draw.text((W // 2, 430), "v0.1 → v0.41, 41번 고쳐 썼어요", font=font(62), fill=YELLOW, anchor="mm")
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
    # 웹판은 광고 없이 보상을 주는 문제가 있어 내세우지 않는다(2026-10-28 계정 주인 결정).
    for i, (name, sub) in enumerate([("iPhone", "App Store 출시"), ("Android", "비공개 테스트")]):
        y = 800 + i * 330
        draw.rounded_rectangle((140, y, 940, y + 230), radius=60, fill=(255, 255, 255, 235))
        draw.text((W // 2, y + 85), name, font=font(96), fill=INK, anchor="mm")
        draw.text((W // 2, y + 170), sub, font=font(50), fill=VIOLET, anchor="mm")
    path = A + "platforms.jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def end_card(name, headline):
    """끝 화면: 앱 아이콘, 이름, 한 줄 소개, App Store에서 지금 받기, 그리고 맨 아래 code404 로고.
    안드로이드는 아직 비공개 테스트라 받는 곳으로 App Store만 적는다."""
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
    draw.rounded_rectangle((170, 1250, 910, 1385), radius=68, fill=(50, 15, 75))
    draw.text((W // 2, 1318), "App Store에서 지금 받기", font=font(64), fill="white", anchor="mm")
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
        layer(caption("t3", "테스터 한마디:\n\"2×2도 되면 좋겠다\"", 96, color=YELLOW), 10.6, 1.6, y=170, pop=True, fadeOut=0.12),
        layer(caption("t4", "다음 날, 청소 드론 등장!", 96), 12.2, 1.9, y=170, pop=True, fadeOut=0.12),
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


SHARE_CARDS = OUT + "src/share_cards/"  # 시뮬레이터에서 -skipTitle 1 -shareCard <도시>로 쓴 실제 자랑 그림(1080×1920)


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    return mask


def share_frame(name, city, title, sub=None):
    """앱이 만든 자랑 그림을 화면 가운데 휴대전화 크기로 놓고 위에 자막을 단다."""
    back = gradient((24, 20, 60), (60, 30, 110)).convert("RGBA")
    card = Image.open(f"{SHARE_CARDS}{city}.png").convert("RGB").resize((820, 1458), Image.LANCZOS)
    shadow = Image.new("RGBA", back.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((130, 420, 950, 1878), radius=48, fill=(10, 0, 30, 170))
    back.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30)))
    back.paste(card, (130, 400), rounded(card, 48))
    draw = ImageDraw.Draw(back)
    draw.text((W // 2 + 3, 175), title, font=font(92), fill=(0, 0, 0), anchor="mm")
    draw.text((W // 2, 170), title, font=font(92), fill="white", anchor="mm")
    if sub:
        draw.text((W // 2, 300), sub, font=font(58), fill=YELLOW, anchor="mm")
    path = A + name + ".jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def share_fan():
    """자랑 그림 세 장을 부채꼴로 펼친다(권리 문제가 없는 서울·로마·파리만)."""
    back = gradient((40, 20, 90), (124, 58, 237)).convert("RGBA")
    for city, angle, x in [("rome", 9, 90), ("paris", -9, 470), ("seoul", 0, 280)]:
        card = Image.open(f"{SHARE_CARDS}{city}.png").convert("RGBA").resize((520, 924), Image.LANCZOS)
        card.putalpha(rounded(card, 36))
        card = card.rotate(angle, resample=Image.BICUBIC, expand=True)
        back.alpha_composite(card, (x, 560 - (card.height - 924) // 2))
    draw = ImageDraw.Draw(back)
    draw.text((W // 2, 260), "랜드마크 24곳", font=font(104), fill="white", anchor="mm")
    draw.text((W // 2, 390), "하나씩 되살리고 자랑해요", font=font(64), fill=YELLOW, anchor="mm")
    path = A + "share_fan.jpg"
    back.convert("RGB").save(path, quality=92)
    return {"image": path, "frame": [0, 0, W, H]}


def brag():
    """R3 자랑하기 편(1.0.1 새 기능), 16초. 자랑 그림은 앱이 실제로 만든 것을 쓴다."""
    seoul = [landmark_card("seoul", "ruined", "서울, 숭례문"), landmark_card("seoul", "restored", "서울, 숭례문")]
    layers = [
        layer(seoul[0], 0, 2.9, scaleFrom=1.0, scaleTo=1.05),
        layer(seoul[1], 1.1, 1.8, wipe=0.55),
        layer(caption("b3_1", "랜드마크를\n다 되살리면?", 112), 0.2, 2.6, y=170, pop=True, fadeOut=0.15),
        layer(share_frame("b3_seoul", "seoul", "'자랑하기' 한 번이면", "폐허와 복원을 한 장에!"), 2.9, 3.9, fadeIn=0.2, scaleFrom=0.97, scaleTo=1.0),
        layer(share_frame("b3_rome", "rome", "친구에게 보내 보세요"), 6.8, 1.9, fadeIn=0.15),
        layer(share_frame("b3_paris", "paris", "친구에게 보내 보세요"), 8.7, 1.9, fadeIn=0.15),
        layer(share_fan(), 10.6, 2.6, fadeIn=0.2, scaleFrom=0.98, scaleTo=1.03),
        layer(end_card("end_r3", "다 되살리고 자랑해요"), 13.2, 2.8, fadeIn=0.3),
    ]
    return dict(output=OUT + "R3_brag.mp4", duration=16,
                segments=[seg(FX, 9, 0, 16)],  # 그림에 가려진다(영상 트랙 자리)
                audio=[dict(src=INTRO_MUSIC, start=0, at=0, dur=16, volume=0.9)], layers=layers)


# 이름을 주면 그것만 다시 만든다(이미 올린 R1·R2를 덮지 않게): python3 Tools/make_reels.py /tmp/promo_render R3
EDITS = {"R1": restore, "R2": teaser, "R3": brag}
for name in sys.argv[2:] or list(EDITS):
    edit = EDITS[name]()
    path = f"{A}edit_{name}.json"
    json.dump(edit, open(path, "w"), ensure_ascii=False, indent=1)
    result = subprocess.run([sys.argv[1], path], capture_output=True, text=True)
    print(name, result.stdout.strip(), result.stderr.strip()[-300:])
