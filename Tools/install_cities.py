"""Codex가 그린 15개 도시의 그림을 에셋 카탈로그에 넣고, 건물이 차지한 자리를 재어 보여준다. 부위의 영역은 `Tools/landmark_shapes.py`가 정한다.

그림 네 장이 다 있는 도시만 넣는다. 다시 돌려도 된다.
"""
import os
import re
import subprocess

from PIL import Image

from cities_data import CITIES

A = "SporeSweep/Assets.xcassets"
I = "Art/incoming"
CONTENTS = '{\n  "images" : [\n    {\n      "filename" : "%s",\n      "idiom" : "universal"\n    }\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }%s\n}\n'
# PNG는 손실 압축(HEVC)으로 앱에 넣는다. 앱 용량의 대부분이 그림이다.
LOSSY = ',\n  "properties" : {\n    "compression-type" : "lossy"\n  }'


def imageset(name, filename):
    os.makedirs(f"{A}/{name}.imageset", exist_ok=True)
    with open(f"{A}/{name}.imageset/Contents.json", "w") as file:
        file.write(CONTENTS % (filename, LOSSY if filename.lower().endswith(".png") else ""))
    return f"{A}/{name}.imageset/{filename}"


rows = []
for city, _, _, title, _, _ in CITIES:
    sources = {k: f"{I}/{city}_{k}_v2.png" for k in ("bg_restored", "bg_ruined", "building_restored", "building_ruined")}
    if not all(os.path.exists(path) for path in sources.values()):
        print("아직 없음:", city)
        continue
    box = None
    for state in ("restored", "ruined"):
        Image.open(sources[f"bg_{state}"]).convert("RGB").resize((1536, 1024)).save(imageset(f"{city}_bg_{state}", f"{city}_bg_{state}.jpg"), quality=88)
        Image.new("RGBA", (16, 16), (0, 0, 0, 0)).save(imageset(f"{city}_trees_{state}", f"{city}_trees_{state}.png"))
        out = subprocess.run(
            ["python3", "Tools/key_landmark.py", sources[f"building_{state}"], imageset(f"{city}_building_{state}", f"{city}_building_{state}.png")],
            capture_output=True, text=True,
        ).stdout
        if state == "restored":
            box = [float(value) for value in re.findall(r"\d\.\d+", out)]
    rows.append((city, title, box))
    print(city, box)

print(len(rows), "곳")
