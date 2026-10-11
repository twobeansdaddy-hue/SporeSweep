"""초록 배경에 그린 랜드마크 건물을 자리와 크기를 그대로 둔 투명 그림으로 바꾼다.

풍경이 들어간 랜드마크는 배경과 건물을 따로 그린다(Art/PROMPTS.md). 배경에 먼 도시가 들어가면
`split_landmark.py`처럼 하늘색으로 건물을 가려낼 수 없기 때문이다. 건물은 순수한 초록(#00FF00) 위에
1536×1024 그림의 제자리에 그리고, 이 도구로 초록만 지운다. 물체에 꼭 맞게 자르지 않는다.

사용법: python3 Tools/key_landmark.py <건물.png> <출력.png>
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 1536, 1024


def main():
    source, out = sys.argv[1:3]
    a = np.asarray(Image.open(source).convert("RGB").resize((W, H), Image.LANCZOS)).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > 110) & (g > r * 1.35) & (g > b * 1.35)
    # 작은 얼룩은 건물로 보지 않는다.
    labels, count = ndimage.label(~green)
    sizes = ndimage.sum(~green, labels, range(1, count + 1))
    solid = np.isin(labels, np.flatnonzero(sizes >= 80) + 1)
    # 가장자리에 남은 초록 물을 뺀다. 초록이 빨강과 파랑의 평균보다 높은 만큼만 낮춘다.
    edge = ndimage.binary_dilation(~solid, iterations=3) & solid
    limit = (r + b) / 2
    a[..., 1] = np.where(edge & (g > limit), limit, g)
    alpha = ndimage.gaussian_filter(solid.astype(float), sigma=0.7)
    alpha = (np.clip(alpha * 2 - 0.5, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([a.astype(np.uint8), alpha]), "RGBA").save(out, optimize=True)
    ys, xs = np.nonzero(solid)
    print(f"건물 {int(solid.sum())}칸, 가로 {xs.min() / W:.3f}~{xs.max() / W:.3f}, 세로 {ys.min() / H:.3f}~{ys.max() / H:.3f}")


main()
