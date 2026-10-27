"""안드로이드 앱에 넣을 파일을 만든다. iOS 폴더에서 모은 파일(sporeAssets)의 그림을 WebP로 줄이고 나머지는 그대로 옮긴다.

그림(images, sprites)이 앱 용량의 대부분이라서 웹판(make_web_assets.py)과 같은 품질로 줄인다.
게임은 그림을 확장자가 아닌 이름으로 찾으므로 코드는 그대로다.

사용법: python3 Tools/make_android_assets.py <sporeAssets 폴더> <내보낼 폴더>
(android에서 ./gradlew :app:androidSporeAssets가 부른다)
"""
import os
import shutil
import sys

from PIL import Image

source, out = sys.argv[1:3]
QUALITY = {"images": 82, "sprites": 90}  # make_web_assets.py와 같다.

wanted = set()
for folder in sorted(os.listdir(source)):
    src_dir = os.path.join(source, folder)
    if not os.path.isdir(src_dir):
        continue
    target = os.path.join(out, folder)
    os.makedirs(target, exist_ok=True)
    for name in sorted(os.listdir(src_dir)):
        src = os.path.join(src_dir, name)
        base, ext = os.path.splitext(name)
        convert = folder in QUALITY and ext.lower() in (".png", ".jpg", ".jpeg")
        path = os.path.join(target, base + ".webp" if convert else name)
        wanted.add(path)
        # 바뀌지 않았으면 다시 만들지 않는다.
        if os.path.exists(path) and os.path.getmtime(path) >= os.path.getmtime(src):
            continue
        if convert:
            image = Image.open(src)
            image = image.convert("RGBA") if image.mode in ("RGBA", "LA", "P") else image.convert("RGB")
            image.save(path, "WEBP", quality=QUALITY[folder], method=6)
        else:
            shutil.copy2(src, path)

# 원본에서 없어진 파일은 지운다.
for d, _, names in os.walk(out):
    for name in names:
        path = os.path.join(d, name)
        if path not in wanted:
            os.remove(path)

total = sum(os.path.getsize(p) for p in wanted)
print(f"안드로이드 파일 {total / 1e6:.1f}MB ({len(wanted)}개)")
