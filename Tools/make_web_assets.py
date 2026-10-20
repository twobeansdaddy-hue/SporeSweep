"""웹판에 올릴 파일을 만든다. 안드로이드 빌드가 iOS 폴더에서 모은 파일(sporeAssets)을 웹에 맞게 바꾼다.

- 그림(images, sprites)은 WebP로 줄인다. 웹은 파일을 내려받아야 해서 크기가 곧 기다리는 시간이다.
- 레벨, 번역, 랜드마크 영역처럼 작은 글 파일은 bundle.json 하나로 묶는다. 400개 넘는 파일을 따로 받지 않게 한다.
- manifest.json에 폴더마다 파일 이름을 적는다. 게임은 이것으로 파일 목록을 안다.

사용법: python3 Tools/make_web_assets.py <sporeAssets 폴더> <landmarks.json> <내보낼 폴더>
(android에서 ./gradlew :web:webAssets가 부른다)
"""
import json
import os
import shutil
import sys

from PIL import Image

source, landmarks, out = sys.argv[1:4]
assets = os.path.join(out, "assets")
os.makedirs(assets, exist_ok=True)

manifest = {}
bundle = {}


def convert_images(folder, quality):
    target = os.path.join(assets, folder)
    os.makedirs(target, exist_ok=True)
    names = []
    for name in sorted(os.listdir(os.path.join(source, folder))):
        base, ext = os.path.splitext(name)
        if ext.lower() not in (".png", ".jpg", ".jpeg"):
            continue
        path = os.path.join(target, base + ".webp")
        src = os.path.join(source, folder, name)
        # 바뀌지 않았으면 다시 줄이지 않는다.
        if not os.path.exists(path) or os.path.getmtime(path) < os.path.getmtime(src):
            image = Image.open(src)
            image = image.convert("RGBA") if image.mode in ("RGBA", "LA", "P") else image.convert("RGB")
            image.save(path, "WEBP", quality=quality, method=6)
        names.append(base + ".webp")
    manifest[folder] = names


def copy_files(folder):
    target = os.path.join(assets, folder)
    os.makedirs(target, exist_ok=True)
    names = sorted(os.listdir(os.path.join(source, folder)))
    for name in names:
        shutil.copy2(os.path.join(source, folder, name), os.path.join(target, name))
    manifest[folder] = names


def bundle_texts(folder):
    names = sorted(os.listdir(os.path.join(source, folder)))
    for name in names:
        with open(os.path.join(source, folder, name), encoding="utf-8") as f:
            bundle[f"{folder}/{name}"] = f.read()
    manifest[folder] = names


convert_images("images", 82)
convert_images("sprites", 90)
copy_files("sounds")
copy_files("music")
copy_files("fonts")
bundle_texts("levels")
bundle_texts("strings")
with open(landmarks, encoding="utf-8") as f:
    bundle["landmarks.json"] = f.read()

with open(os.path.join(assets, "bundle.json"), "w", encoding="utf-8") as f:
    json.dump(bundle, f, ensure_ascii=False, separators=(",", ":"))
with open(os.path.join(assets, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, separators=(",", ":"))

total = sum(os.path.getsize(os.path.join(d, n)) for d, _, ns in os.walk(assets) for n in ns)
print(f"웹 파일 {total / 1e6:.1f}MB (그림 {len(manifest['images'])}장, 조각 {len(manifest['sprites'])}장, 글 {len(bundle)}개)")
