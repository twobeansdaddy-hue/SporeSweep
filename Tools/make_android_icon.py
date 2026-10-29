"""안드로이드 적응형 아이콘을 앱 아이콘에서 만든다.

적응형 아이콘은 108dp 판의 가운데 72dp만 원이나 둥근 네모로 잘라 보여준다. 앱 아이콘을 그대로 넣으면 포자가
잘리므로, 아이콘을 줄여 가운데에 두고 둘레는 아이콘을 흐리게 키운 바탕으로 채운다.

사용법: python3 Tools/make_android_icon.py
"""
from PIL import Image, ImageDraw, ImageFilter

RES = "android/app/src/main/res/"
icon = Image.open("SporeSweep/Assets.xcassets/AppIcon.appiconset/AppIcon.png").convert("RGB")

N = 432
layer = icon.resize((N, N), Image.LANCZOS).filter(ImageFilter.GaussianBlur(60))
inner = round(N * 0.76)  # 아이콘 가장자리가 보이는 72dp 밖에 오게 한다
mask = Image.new("L", (inner, inner), 0)
margin = round(inner * 0.04)
ImageDraw.Draw(mask).ellipse((margin, margin, inner - margin, inner - margin), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(inner * 0.07))
layer.paste(icon.resize((inner, inner), Image.LANCZOS), ((N - inner) // 2, (N - inner) // 2), mask)

for folder, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)]:
    layer.resize((round(108 * scale),) * 2, Image.LANCZOS).save(f"{RES}mipmap-{folder}/ic_launcher_layer.png")
print("적응형 아이콘")
