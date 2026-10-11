"""랜드마크 그림 두 장(복원, 폐허)을 배경, 건물, 나무로 나눈다.

부위마다 따로 복원하려면 건물과 하늘이 떨어져 있어야 한다. 그림마다 하늘을 가장자리에서부터 지워
건물만 남긴 투명 그림(building)과 나무만 남긴 투명 그림(trees), 그 자리를 주변 색으로 메운 배경(bg)을 만든다.

사용법: python3 Tools/split_landmark.py <복원.png> <폐허.png> <출력 폴더> [모양] [접두어]
  모양은 gate(숭례문, 기본), tower(도쿄타워), wall(만리장성)이다. 접두어는 출력 파일 이름의 앞부분이고 기본은 landmark다.
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 1536, 1024
# 땅이 시작하는 줄. 그 위는 하늘을 지워 물체를 찾고, 아래는 건물 밑동만 사다리꼴로 넣는다.
# 복원된 그림은 풀숲 아래의 잔디가, 폐허 그림은 맨땅이 여기서 시작한다.
GROUND_RESTORED = 806
GROUND_RUINED = 798
# 건물 밑동의 사다리꼴. (세로, 왼쪽 끝, 오른쪽 끝)이 위와 아래에 하나씩이다.
BASE_TOP = (608, 268, 1266)
BASE_BOTTOM = (808, 208, 1326)
# 사다리꼴보다 위에서 건물이 차지하는 가로 범위.
BUILDING = (240, 1296)


def sky_restored(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # 파란 기와와 헷갈리지 않게 초록도 충분히 밝은 것만 하늘로 본다. 하늘은 초록이 176 이상이고 기와는 160 아래다.
    return (b > 170) & (b > r + 40) & (b >= g) & (g > r + 60) & (g > 165)


def sky_ruined(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # 어두운 외곽선은 하늘과 색이 비슷해도 하늘로 보지 않는다.
    return (b - g >= 20) & (b - r >= 12) & (r - g >= 5) & (r + g + b >= 200)


def sky_ruined_tower(a):
    """도쿄타워의 폐허 그림은 하늘과 구름의 색 차이가 작아서 기준을 느슨하게 잡는다."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (b - g >= 15) & (b - r >= 7) & (r - g >= 3) & (r + g + b >= 170)


def connected_to_top(candidate, bottom):
    """위쪽과 양옆 가장자리에서 이어진 칸만 남긴다."""
    labels, _ = ndimage.label(candidate)
    edge = np.unique(np.concatenate([labels[0], labels[:bottom, 0], labels[:bottom, -1]]))
    return np.isin(labels, edge[edge > 0])


def drop_specks(mask):
    labels, count = ndimage.label(mask)
    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    return np.isin(labels, np.flatnonzero(sizes >= 60) + 1)


# 탑은 가운데의 좁은 띠에 서 있고, 살 사이로 하늘이 비친다.
TOWER = (470, 1066)
TOWER_BOTTOM = 814
SHAPE = "gate"


def simple_masks(a, is_sky, restored, xs, ys, span, ground, bottom):
    """건물이 가로 범위 `span` 안에 서 있는 그림. 그 바깥은 나무다."""
    in_building = (xs >= span[0]) & (xs <= span[1])
    sky = connected_to_top(is_sky(a), ground) | ndimage.binary_dilation(is_sky(a), iterations=1)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    soil = (g > r + 40) if restored else ((r > g + 12) & (g > b + 8) & (r < 150))
    horizon = min(ground, bottom - 16)
    building = ~sky & in_building & (ys < horizon)
    building |= in_building & (ys >= horizon) & (ys < bottom) & ~soil & ~sky
    trees = ~sky & ~in_building & (ys > 500) & (ys < ground)
    # 해처럼 건물과 떨어져 있는 것은 건물이 아니다. 가장 큰 덩어리와 견줄 만한 것만 남긴다.
    labels, count = ndimage.label(building)
    sizes = ndimage.sum(building, labels, range(1, count + 1))
    building = np.isin(labels, np.flatnonzero(sizes >= sizes.max() * 0.05) + 1)
    return building, drop_specks(trees)


def masks(a, is_sky, restored):
    """(건물, 나무)의 칸."""
    ys, xs = np.mgrid[0:H, 0:W]
    # 건물과 나무를 가르는 선. 밑동은 아래로 갈수록 넓어진다.
    t = np.clip((ys - BASE_TOP[0]) / (BASE_BOTTOM[0] - BASE_TOP[0]), 0, 1)
    left = np.where(ys < BASE_TOP[0], BUILDING[0], BASE_TOP[1] - t * (BASE_TOP[1] - BASE_BOTTOM[1]))
    right = np.where(ys < BASE_TOP[0], BUILDING[1], BASE_TOP[2] + t * (BASE_BOTTOM[2] - BASE_TOP[2]))
    in_building = (xs >= left) & (xs <= right)
    if SHAPE == "wall":
        # 성벽은 그림의 가운데 넓은 띠를 차지하고, 지평선이 다른 그림보다 높다.
        return simple_masks(a, is_sky, restored, xs, ys, span=(150, 1386), ground=780 if restored else 760, bottom=776)
    if SHAPE == "tower":
        in_building = (xs >= TOWER[0]) & (xs <= TOWER[1])

    ground = GROUND_RESTORED if restored else GROUND_RUINED
    sky = connected_to_top(is_sky(a), ground)
    if restored:
        # 홍예문 안쪽이나 나무 사이처럼 가장자리와 이어지지 않은 하늘 조각도 지운다.
        sky |= ndimage.binary_dilation(is_sky(a), iterations=1)
    if SHAPE == "tower":
        # 살 사이로 비치는 하늘은 가장자리와 이어지지 않아도 지운다. 발판은 땅 위에 얹혀 있어서 색으로 가른다.
        sky |= ndimage.binary_dilation(is_sky(a), iterations=1) if not restored else sky
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        soil = (g > r + 40) if restored else ((r > g + 12) & (g > b + 8) & (r < 150))
        building = ~sky & in_building & (ys < ground)
        building |= in_building & (ys >= ground) & (ys < TOWER_BOTTOM) & ~soil
        trees = ~sky & ~in_building & (ys > 500) & (ys < ground)
        return drop_specks(building), drop_specks(trees)
    building = ~sky & in_building & (ys < ground)
    building |= in_building & (ys >= ground) & (ys < BASE_BOTTOM[0])
    # 나무와 풀숲(폐허에서는 그루터기).
    trees = ~sky & ~in_building & (ys > 500) & (ys < ground)
    return drop_specks(building), drop_specks(trees)


def inpaint(a, mask):
    """가려진 자리를 같은 줄의 양옆 색으로 메우고, 메운 자리만 흐린다."""
    hole = ndimage.binary_dilation(mask, iterations=6)
    out = a.astype(float).copy()
    xs = np.arange(W)
    for y in range(H):
        row = hole[y]
        if not row.any() or row.all():
            continue
        for c in range(3):
            out[y, row, c] = np.interp(xs[row], xs[~row], out[y, ~row, c])
    blurred = np.stack([ndimage.gaussian_filter(out[..., c], sigma=6) for c in range(3)], axis=-1)
    soft = ndimage.gaussian_filter(hole.astype(float), sigma=2)[..., None]
    return (out * (1 - soft) + blurred * soft).clip(0, 255).astype(np.uint8)


def cutout(a, mask):
    alpha = ndimage.gaussian_filter(mask.astype(float), sigma=0.7)
    alpha = (np.clip(alpha * 2 - 0.5, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([a.astype(np.uint8), alpha]), "RGBA")


def main():
    global SHAPE
    restored_path, ruined_path, out = sys.argv[1:4]
    SHAPE = sys.argv[4] if len(sys.argv) > 4 else "gate"
    prefix = sys.argv[5] if len(sys.argv) > 5 else "landmark"
    for name, path, is_sky, restored in [
        ("restored", restored_path, sky_restored, True),
        ("ruined", ruined_path, sky_ruined_tower if SHAPE in ("tower", "wall") else sky_ruined, False),
    ]:
        a = np.asarray(Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS)).astype(int)
        building, trees = masks(a, is_sky, restored)
        cutout(a, building).save(f"{out}/{prefix}_building_{name}.png", optimize=True)
        cutout(a, trees).save(f"{out}/{prefix}_trees_{name}.png", optimize=True)
        Image.fromarray(inpaint(a, building | trees)).save(f"{out}/{prefix}_bg_{name}.jpg", quality=88)
        print(name, "건물", int(building.sum()), "나무", int(trees.sum()))


main()
