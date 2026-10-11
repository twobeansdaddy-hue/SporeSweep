"""15초 홍보 영상 세 편을 만든다(세로 1080×1920).

자막과 전후 비교 그림, 끝 화면을 그려 두고, 편집 내용을 JSON으로 적어 `promo_render`에 넘긴다.
사용법: python3 Tools/make_promos.py <promo_render 실행 파일>
"""
import json
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
FONT = "SporeSweep/Fonts/Jua-Regular.ttf"
OUT = "Marketing/promo/"
A = OUT + "assets/"
FX = "Marketing/videos/03_effects.mp4"
FAIL = OUT + "src/fail_tokyo.mp4"
MUSIC = "GameScene/Sources/GameScene/Music/music_intro.m4a"
# 음악을 끄고 찍은 것. 효과음만 들어 있어 음악을 따로 깔 수 있다.
FX_SFX = OUT + "src/fx_sfx.mp4"
FAIL_SFX = OUT + "src/fail_sfx.mp4"
GAME_MUSIC = "GameScene/Sources/GameScene/Music/music_game.m4a"


def gradient(top, bottom):
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return image


def caption(name, text, size=120, color=(255, 255, 255), pill=(40, 12, 60, 215)):
    """가운데 정렬한 자막. 어두운 알약 바탕 위에 적어 어떤 화면 위에서도 읽히게 한다."""
    font = ImageFont.truetype(FONT, size)
    lines = text.split("\n")
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    width = max(probe.textlength(line, font=font) for line in lines)
    line_height = round(size * 1.18)
    height = line_height * len(lines) + 70
    image = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((W / 2 - width / 2 - 56, 0, W / 2 + width / 2 + 56, height), radius=64, fill=pill)
    for index, line in enumerate(lines):
        y = 35 + index * line_height + line_height / 2
        draw.text((W / 2 + 3, y + 5), line, font=font, fill=(0, 0, 0, 160), anchor="mm")
        draw.text((W / 2, y), line, font=font, fill=color, anchor="mm")
    image.save(A + name + ".png")
    return {"image": A + name + ".png", "frame": [0, 0, W, height]}


def card(city, state, label):
    """랜드마크 한 곳을 화면 가득 보여주는 그림. 흐린 배경 위에 랜드마크를 크게 놓고 이름을 적는다."""
    art = Image.open(f"Marketing/art/landmark_{city}_{state}.jpg").convert("RGB")
    back = art.resize((round(H * 1.5), H)).crop((round(H * 0.75) - W // 2, 0, round(H * 0.75) + W // 2, H))
    back = back.filter(ImageFilter.GaussianBlur(40)).point(lambda value: value * 0.55)
    # 가로로 긴 그림의 가운데를 4:3으로 잘라 크게 놓는다.
    crop = art.crop((1536 // 2 - 660, 20, 1536 // 2 + 660, 1010)).resize((1040, 780), Image.LANCZOS)
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *crop.size), radius=60, fill=255)
    back.paste(crop, (20, 600), mask)
    draw = ImageDraw.Draw(back)
    draw.rounded_rectangle((16, 596, 1064, 1384), radius=64, outline=(255, 255, 255), width=8)
    font = ImageFont.truetype(FONT, 96)
    draw.text((W // 2 + 3, 1505), label, font=font, fill=(0, 0, 0), anchor="mm")
    draw.text((W // 2, 1500), label, font=font, fill=(255, 226, 120) if state == "restored" else (230, 230, 240), anchor="mm")
    name = f"{city}_{state}"
    back.save(A + name + ".jpg", quality=92)
    return {"image": A + name + ".jpg", "frame": [0, 0, W, H]}


def end_card(name, headline):
    image = gradient((255, 92, 168), (110, 55, 200)).convert("RGBA")
    draw = ImageDraw.Draw(image)
    icon = Image.open("Art/incoming/app_icon.png").convert("RGBA").resize((380, 380), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 380, 380), radius=86, fill=255)
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((350, 500, 730, 880), radius=86, fill=(40, 10, 70, 150))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
    image.paste(icon, (350, 470), mask)
    draw.text((W // 2 + 4, 286), headline, font=ImageFont.truetype(FONT, 92), fill=(70, 15, 80), anchor="mm")
    draw.text((W // 2, 280), headline, font=ImageFont.truetype(FONT, 92), fill="white", anchor="mm")
    draw.text((W // 2 + 5, 1017), "포자 대청소", font=ImageFont.truetype(FONT, 170), fill=(70, 15, 80), anchor="mm")
    draw.text((W // 2, 1010), "포자 대청소", font=ImageFont.truetype(FONT, 170), fill="white", anchor="mm")
    draw.text((W // 2, 1160), "세계 랜드마크 복원 매치3 퍼즐", font=ImageFont.truetype(FONT, 62), fill=(255, 226, 120), anchor="mm")
    draw.rounded_rectangle((300, 1330, 780, 1470), radius=70, fill=(50, 15, 75))
    draw.text((W // 2, 1400), "곧 만나요!", font=ImageFont.truetype(FONT, 76), fill="white", anchor="mm")
    image.convert("RGB").save(A + name + ".jpg", quality=92)
    return {"image": A + name + ".jpg", "frame": [0, 0, W, H]}


def layer(asset, at, dur, y=None, **options):
    item = dict(asset, at=at, dur=dur, **options)
    if y is not None:
        item["frame"] = [0, y, asset["frame"][2], asset["frame"][3]]
    return item


def seg(src, start, at, dur, zoom=(1, 1), focus=(0.5, 0.47), volume=0):
    return dict(src=src, start=start, at=at, dur=dur, zoomFrom=zoom[0], zoomTo=zoom[1], focus=list(focus), volume=volume)


def before_after():
    layers = []
    seoul = [card("seoul", "ruined", "서울, 숭례문"), card("seoul", "restored", "서울, 숭례문")]
    layers.append(layer(seoul[0], 0, 2.9, scaleFrom=1.0, scaleTo=1.06))
    layers.append(layer(caption("a1", "외계 포자가\n지구를 덮쳤다!", 118), 0.25, 2.1, y=170, pop=True, fadeOut=0.15))
    layers.append(layer(seoul[1], 2.3, 2.0, wipe=0.55))
    layers.append(layer(caption("a2", "되살려 주세요!", 124, color=(255, 226, 120)), 2.95, 1.25, y=230, pop=True, fadeOut=0.15))
    at = 4.3
    for city, label in [("rome", "로마, 콜로세움"), ("cairo", "카이로, 피라미드"), ("paris", "파리, 에펠탑")]:
        layers.append(layer(card(city, "ruined", label), at, 1.5))
        layers.append(layer(card(city, "restored", label), at + 0.55, 0.95, wipe=0.35))
        at += 1.5
    layers.append(layer(caption("a3", "세계 24개 도시", 110), 4.4, 4.3, y=230, pop=True, fadeOut=0.15))
    layers.append(layer(caption("a4", "블록을 맞춰\n오염을 치우세요!", 104), 9.0, 2.75, y=150, pop=True, fadeOut=0.15))
    layers.append(layer(end_card("end_a", "지구가 다시 반짝일 때까지"), 12.0, 3.0, fadeIn=0.3))
    return dict(
        output=OUT + "A_before_after.mp4", duration=15,
        segments=[seg(FX, 9, 0, 8.8), seg(FX, 1.7, 8.8, 3.2, zoom=(1.0, 1.1), focus=(0.5, 0.42)), seg(FX, 12, 12.0, 3.0)],
        audio=[dict(src=MUSIC, start=0, at=0, dur=15, volume=0.9)], layers=layers,
    )


def satisfying():
    cuts = [
        seg(FX_SFX, 1.6, 0, 2.9, zoom=(1.12, 1.24), focus=(0.5, 0.40), volume=1),
        seg(FX_SFX, 6.6, 2.9, 2.5, zoom=(1.1, 1.16), focus=(0.5, 0.40), volume=1),
        seg(FAIL_SFX, 6.3, 5.4, 2.3, zoom=(1.16, 1.26), focus=(0.5, 0.42), volume=1),
        seg(FX_SFX, 18.0, 7.7, 2.3, zoom=(1.12, 1.2), focus=(0.5, 0.50), volume=1),
        seg(FX_SFX, 24.0, 10.0, 1.9, zoom=(1.16, 1.3), focus=(0.6, 0.48), volume=1),
        seg(FX_SFX, 9, 11.9, 3.1, volume=0.5),
    ]
    layers = [
        layer(caption("b1", "팡!", 230, color=(255, 226, 120)), 0.35, 1.3, y=1380, pop=True, fadeOut=0.15),
        layer(caption("b2", "팡팡!", 210, color=(255, 226, 120)), 3.1, 1.4, y=1380, pop=True, fadeOut=0.15),
        layer(caption("b3", "속이 뻥!", 190), 5.6, 1.6, y=1380, pop=True, fadeOut=0.15),
        layer(caption("b4", "한 줄 싹쓸이", 150), 7.9, 1.7, y=1400, pop=True, fadeOut=0.15),
        layer(caption("b5", "시원하게\n터뜨려요", 150, color=(255, 226, 120)), 10.1, 1.7, y=1320, pop=True, fadeOut=0.15),
        layer(end_card("end_b", "터뜨리는 맛이 있는 퍼즐"), 11.9, 3.1, fadeIn=0.25),
    ]
    return dict(output=OUT + "B_satisfying.mp4", duration=15, segments=cuts, audio=[dict(src=GAME_MUSIC, start=2, at=0, dur=15, volume=0.45)], layers=layers)


def near_miss():
    cuts = [
        seg(FAIL_SFX, 11.6, 0, 8.6, zoom=(1.0, 1.1), focus=(0.5, 0.45), volume=1),
        seg(FAIL_SFX, 20.2, 8.6, 3.0, zoom=(1.0, 1.14), focus=(0.5, 0.52), volume=1),
        seg(FAIL_SFX, 22.2, 11.6, 3.2, volume=0.4),
    ]
    layers = [
        layer(caption("c1", "이동 2번 남았다", 116), 0.3, 2.5, y=1420, pop=True, fadeOut=0.15),
        layer(caption("c2", "오염 물질이\n바로 코앞인데!", 108), 3.0, 2.6, y=1360, pop=True, fadeOut=0.15),
        layer(caption("c3", "제발, 한 번만 더!", 116, color=(255, 226, 120)), 5.8, 2.6, y=1420, pop=True, fadeOut=0.15),
        layer(caption("c4", "딱 1개 남기고 실패", 112, color=(255, 150, 170)), 8.8, 2.7, y=1500, pop=True, fadeOut=0.15),
        layer(end_card("end_c", "당신은 깰 수 있나요?"), 11.6, 3.4, fadeIn=0.3),
    ]
    return dict(output=OUT + "C_near_miss.mp4", duration=15, segments=cuts, audio=[dict(src=GAME_MUSIC, start=2, at=0, dur=15, volume=0.45)], layers=layers)


for name, edit in [("A", before_after()), ("B", satisfying()), ("C", near_miss())]:
    path = f"{A}edit_{name}.json"
    json.dump(edit, open(path, "w"), ensure_ascii=False, indent=1)
    print(subprocess.run([sys.argv[1], path], capture_output=True, text=True).stdout.strip())
