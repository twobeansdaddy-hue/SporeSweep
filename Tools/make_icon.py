#!/usr/bin/env python3
"""자리 표시 앱 아이콘(1024×1024, 투명 없음)을 만든다.

어두운 바탕에 분홍색 오염 물질 하나를 그린다. 정식 아이콘이 생기면 같은 파일을 바꿔 넣는다.
사용법: python3 Tools/make_icon.py
"""
import math
import os
import struct
import zlib

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "SporeSweep", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def coverage(distance, edge, softness=2.5):
    """경계에서 부드럽게 0~1로 바뀌는 덮임 정도."""
    return max(0.0, min(1.0, (edge - distance) / softness + 0.5))


rows = []
center = SIZE / 2
for y in range(SIZE):
    row = bytearray([0])
    for x in range(SIZE):
        dx, dy = x - center, y - center
        distance = math.hypot(dx, dy)
        angle = math.atan2(dy, dx)
        # 바탕: 위에서 아래로 어두워지는 남색
        color = mix((38, 30, 62), (14, 18, 28), y / SIZE)
        # 퍼지는 오염의 옅은 빛
        color = mix(color, (255, 56, 148), 0.28 * max(0.0, 1 - distance / 520) ** 2)
        # 뾰족한 포자 모양의 물질
        spore = 300 + 46 * math.cos(10 * angle + 0.3)
        color = mix(color, (120, 12, 70), coverage(distance, spore + 14))
        color = mix(color, (255, 56, 148), coverage(distance, spore))
        # 위쪽의 밝은 면
        highlight = math.hypot(dx + 70, dy + 90)
        color = mix(color, (255, 150, 200), 0.35 * coverage(highlight, 150, 60) * coverage(distance, spore))
        # 어두운 핵
        color = mix(color, (64, 5, 41), coverage(distance, 118))
        row.extend(int(round(c)) for c in color)
    rows.append(bytes(row))


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
png += chunk(b"IEND", b"")
with open(OUT, "wb") as f:
    f.write(png)
print(OUT, len(png))
