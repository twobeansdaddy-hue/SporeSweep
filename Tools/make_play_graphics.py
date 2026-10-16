"""Google Play에 올릴 그림을 만든다. 아이콘(512×512)과 그래픽 이미지(1024×500).

사용법: python3 Tools/make_play_graphics.py → Marketing/store/play/
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "Marketing/store/play/"
FONT = "SporeSweep/Fonts/Jua-Regular.ttf"
os.makedirs(OUT, exist_ok=True)

# 아이콘: 앱 아이콘을 줄인다. Play는 32비트 PNG를 받는다.
Image.open("SporeSweep/Assets.xcassets/AppIcon.appiconset/AppIcon.png").convert("RGBA").resize((512, 512), Image.LANCZOS).save(OUT + "icon_512.png")

# 그래픽 이미지: 숭례문의 폐허와 복원된 모습을 반씩 깔고 가운데에 로고와 한글 이름을 얹는다.
W, H = 1024, 500


def cover(path):
    image = Image.open(path).convert("RGB")
    scale = max(W / image.width, H / image.height)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left, top = (image.width - W) // 2, round((image.height - H) * 0.45)
    return image.crop((left, top, left + W, top + H))


ruined = cover("Marketing/art/landmark_seoul_ruined.jpg")
page = cover("Marketing/art/landmark_seoul_restored.jpg")
page.paste(ruined.crop((0, 0, W // 2, H)), (0, 0))
ImageDraw.Draw(page).line([(W // 2, 0), (W // 2, H)], fill="white", width=6)

# 가운데를 어둡게 해 글자가 읽히게 한다.
shade = Image.new("L", (W, H), 0)
ImageDraw.Draw(shade).ellipse((W * 0.18, H * 0.05, W * 0.82, H * 0.95), fill=170)
shade = shade.filter(ImageFilter.GaussianBlur(70))
page = Image.composite(Image.new("RGB", (W, H), (30, 14, 60)), page, shade)

logo = Image.open("SporeSweep/Assets.xcassets/logo.imageset/logo.png").convert("RGBA")
logo = logo.resize((560, round(logo.height * 560 / logo.width)), Image.LANCZOS)
page.paste(logo, ((W - logo.width) // 2, 40), logo)

draw = ImageDraw.Draw(page)
font = ImageFont.truetype(FONT, 64)
y = 40 + logo.height + 6
draw.text((W // 2 + 3, y + 5), "포자 대청소", font=font, fill=(60, 15, 70), anchor="ma")
draw.text((W // 2, y), "포자 대청소", font=font, fill=(255, 226, 120), anchor="ma")
page.save(OUT + "feature_1024x500.png")
print("아이콘, 그래픽 이미지")
