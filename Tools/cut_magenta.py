"""자홍색(#FF00FF) 배경의 스프라이트 시트를 칸마다 잘라 투명 PNG로 저장한다.

초록 물체(원뿔)가 든 시트는 초록 배경을 쓸 수 없어서 자홍색 배경으로 그린다. 물체 안쪽에 갇힌 배경
(너트의 구멍)도 지운다. 물체마다 정사각형 가운데에 맞춰 넣는다.

사용법: python3 Tools/cut_magenta.py <시트.png> <열> <행> <출력 폴더> <크기> <이름>...
"""
import sys

import numpy as np
from PIL import Image, ImageChops, ImageFilter
from scipy import ndimage

sheet, columns, rows, out, size = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], int(sys.argv[5])
names = sys.argv[6:]
a = np.asarray(Image.open(sheet).convert("RGB")).astype(float)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
background = (g < 90) & (r > 200) & (b > 200) & (abs(r - b) < 60)
solid = ~background
# 배경에 남은 작은 얼룩은 물체로 보지 않는다. 그대로 두면 블록 아래에 점처럼 찍힌다.
labels, count = ndimage.label(solid)
sizes = ndimage.sum(solid, labels, range(1, count + 1))
solid = np.isin(labels, np.flatnonzero(sizes >= 900) + 1)
background = ~solid
# 가장자리에 남은 자홍색 물을 뺀다. 빨강과 파랑이 초록보다 함께 높은 만큼만 낮춘다.
edge = ndimage.binary_dilation(background, iterations=3) & solid
spill = np.clip(np.minimum(r, b) - g, 0, None) * 0.6
for channel in (0, 2):
    a[..., channel] = np.where(edge, a[..., channel] - spill, a[..., channel])
alpha = np.clip(ndimage.gaussian_filter(solid.astype(float), sigma=0.8) * 2 - 0.5, 0, 1)
rgba = np.dstack([a.clip(0, 255), alpha * 255]).astype(np.uint8)
height, width = solid.shape
# 물체가 칸의 경계를 조금 넘기도 한다(원뿔의 꼭대기가 윗칸으로 올라간다). 칸대로 자르면 넘어간 조각이
# 옆 칸의 그림에 점처럼 찍히므로, 이어진 덩어리마다 중심이 놓인 칸에 통째로 넣는다.
labels, count = ndimage.label(solid)
centers = ndimage.center_of_mass(solid, labels, range(1, count + 1))
owner = [int(cy * rows // height) * columns + int(cx * columns // width) for cy, cx in centers]
image = Image.fromarray(rgba, "RGBA")
for index, name in enumerate(names):
    if name == "-":
        continue
    mine = np.isin(labels, [label + 1 for label, cell in enumerate(owner) if cell == index])
    ys, xs = np.nonzero(mine)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    piece = image.crop(box)
    # 같은 사각형에 걸친 남의 조각은 지운다.
    keep = Image.fromarray((mine[box[1]:box[3], box[0]:box[2]] * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    piece.putalpha(ImageChops.multiply(piece.getchannel("A"), keep))
    # 긴 변이 그림의 94%가 되게 맞춘다.
    scale = size * 0.94 / max(piece.size)
    piece = piece.resize((round(piece.width * scale), round(piece.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(piece, ((size - piece.width) // 2, (size - piece.height) // 2), piece)
    canvas.save(f"{out}/{name}.png", optimize=True)
    print(name, piece.size)
