#!/usr/bin/env python3
"""효과음을 합성해 GameScene/Sources/GameScene/Sounds에 WAV로 쓴다.

녹음이나 음원 없이 코드로 만든다. 종 소리는 FM 합성, 바람과 깨지는 소리는 걸러낸 잡음,
울림은 짧은 잔향으로 낸다. 같은 이름의 파일로 바꿔 넣으면 다른 소리로 바꿀 수 있다.
사용법: python3 Tools/make_sounds.py (numpy와 scipy가 필요하다)
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "GameScene", "Sources", "GameScene", "Sounds")
rng = np.random.default_rng(404)


def t(duration):
    return np.arange(int(RATE * duration)) / RATE


def envelope(duration, attack=0.004, decay=6.0, release=0.02):
    """빠르게 올라와 지수로 줄어드는 음량. 끝은 딸깍 소리가 나지 않게 0으로 내린다."""
    x = t(duration)
    env = np.minimum(x / attack, 1.0) * np.exp(-decay * x)
    tail = int(RATE * release)
    if 0 < tail < len(env):
        env[-tail:] *= np.linspace(1, 0, tail)
    return env


def sweep(start, end, duration, curve=1.0):
    """start에서 end로 미끄러지는 주파수의 위상."""
    x = np.linspace(0, 1, int(RATE * duration)) ** curve
    freq = start * (end / start) ** x
    return 2 * np.pi * np.cumsum(freq) / RATE


def bell(freq, duration, ratio=3.5, depth=2.5, decay=7.0, volume=1.0):
    """FM 종 소리. 변조가 음량보다 빨리 줄어서 맑게 끝난다."""
    x = t(duration)
    modulator = np.sin(2 * np.pi * freq * ratio * x) * depth * np.exp(-decay * 1.8 * x)
    return np.sin(2 * np.pi * freq * x + modulator) * envelope(duration, decay=decay) * volume


def pluck(freq, duration, decay=10.0, volume=1.0):
    """통통 튀는 음. 배음 몇 개를 더해 장난감 실로폰처럼 만든다."""
    x = t(duration)
    wave_ = sum(np.sin(2 * np.pi * freq * k * x) * a * np.exp(-decay * (k - 1) * 0.8 * x)
                for k, a in [(1, 1.0), (2, 0.45), (3, 0.2), (4.2, 0.1)])
    return wave_ * envelope(duration, attack=0.002, decay=decay) * volume


def noise(duration, low=None, high=None, decay=10.0, volume=1.0, attack=0.002):
    """걸러낸 잡음."""
    x = rng.standard_normal(int(RATE * duration))
    if low and high:
        sos = signal.butter(2, [low, high], "bandpass", fs=RATE, output="sos")
    elif high:
        sos = signal.butter(2, high, "lowpass", fs=RATE, output="sos")
    elif low:
        sos = signal.butter(2, low, "highpass", fs=RATE, output="sos")
    else:
        sos = None
    if sos is not None:
        x = signal.sosfilt(sos, x)
    x /= max(np.abs(x).max(), 1e-9)
    return x * envelope(duration, attack=attack, decay=decay) * volume


def at(*parts):
    """(시작 시각, 소리)를 겹쳐 한 줄로 만든다."""
    length = max(int(RATE * start) + len(sound) for start, sound in parts)
    out = np.zeros(length)
    for start, sound in parts:
        i = int(RATE * start)
        out[i:i + len(sound)] += sound
    return out


def reverb(sound, seconds=0.35, amount=0.22):
    """짧은 방 울림. 줄어드는 잡음과 겹쳐 만든다."""
    n = int(RATE * seconds)
    impulse = rng.standard_normal(n) * np.exp(-np.linspace(0, 7, n))
    impulse = signal.sosfilt(signal.butter(2, 5000, "lowpass", fs=RATE, output="sos"), impulse)
    wet = signal.fftconvolve(sound, impulse)[: len(sound) + n]
    wet /= max(np.abs(wet).max(), 1e-9)
    dry = np.zeros(len(wet))
    dry[: len(sound)] = sound
    return dry + wet * amount * np.abs(sound).max()


def write(name, sound, peak=0.85):
    sound = np.tanh(sound / max(np.abs(sound).max(), 1e-9) * 1.4)  # 살짝 눌러 단단하게
    sound = sound / np.abs(sound).max() * peak
    fade = int(RATE * 0.01)
    sound[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype("<i2").tobytes())


def note(semitones, base=523.25):
    return base * 2 ** (semitones / 12)


os.makedirs(OUT, exist_ok=True)

# 스왑: 짧은 바람 소리와 가벼운 톡.
write("swap", at(
    (0, noise(0.09, 900, 5000, decay=30, volume=0.5, attack=0.012)),
    (0.02, np.sin(sweep(520, 880, 0.07)) * envelope(0.07, decay=35) * 0.6),
), peak=0.55)

# 스왑 거부: 낮게 두 번 막히는 소리.
thud = lambda f: at((0, np.sin(sweep(f, f * 0.6, 0.09)) * envelope(0.09, decay=24)), (0, noise(0.05, None, 700, decay=45, volume=0.5)))
write("reject", at((0, thud(210)), (0.085, thud(165))), peak=0.6)

# 매치 제거: 통통 튀는 음. 연쇄가 이어질수록 음이 올라가고 반짝임이 늘어난다.
for index, step in enumerate([0, 2, 4, 7, 9], start=1):
    parts = [
        (0, pluck(note(step), 0.30, decay=11)),
        (0, noise(0.03, 2500, 9000, decay=70, volume=0.35)),
        (0.015, bell(note(step + 12), 0.26, ratio=2.0, depth=1.2, decay=13, volume=0.35)),
    ]
    if index >= 3:
        parts.append((0.05, bell(note(step + 19), 0.22, ratio=3.0, depth=1.0, decay=16, volume=0.18 + 0.05 * index)))
    write(f"clear{index}", reverb(at(*parts), seconds=0.18, amount=0.15), peak=0.7)

# 특수 블록 생성: 빠르게 올라가는 반짝임.
write("create", reverb(at(
    (0.00, bell(note(7), 0.20, decay=14, volume=0.7)),
    (0.05, bell(note(12), 0.20, decay=14, volume=0.8)),
    (0.10, bell(note(16), 0.22, decay=12, volume=0.9)),
    (0.15, bell(note(19), 0.40, decay=8)),
    (0.00, np.sin(sweep(700, 2800, 0.22)) * envelope(0.22, attack=0.05, decay=9) * 0.25),
), seconds=0.3), peak=0.75)

# 특수 블록 발동: 에너지 빔이 나가는 소리와 낮은 폭발.
zap = np.sign(np.sin(sweep(2400, 180, 0.28, curve=0.6))) * 0.35 + np.sin(sweep(2400, 180, 0.28, curve=0.6))
write("special", reverb(at(
    (0, zap * envelope(0.28, decay=9) * 0.7),
    (0.03, np.sin(sweep(150, 42, 0.45)) * envelope(0.45, attack=0.006, decay=7) * 1.2),
    (0.03, noise(0.40, 200, 3500, decay=11, volume=0.7)),
), seconds=0.4, amount=0.3), peak=0.9)

# 장애물 파괴: 돌이 깨지는 소리. 날카로운 잡음 뒤에 부스러기가 몇 번 떨어진다.
debris = [(0.05 + 0.04 * i + rng.uniform(0, 0.02), noise(0.05, 1200, 6000, decay=60, volume=0.25 + 0.1 * rng.uniform())) for i in range(4)]
write("crack", at(
    (0, noise(0.10, 500, 7000, decay=38)),
    (0, np.sin(sweep(190, 70, 0.14)) * envelope(0.14, decay=20) * 0.9),
    *debris,
), peak=0.8)

# 물질 수거: 컨테이너로 빨려 들어가는 소리와 맑은 확인음.
write("collect", reverb(at(
    (0, np.sin(sweep(900, 140, 0.26, curve=0.7)) * envelope(0.26, attack=0.03, decay=5) * 0.7),
    (0, noise(0.26, 300, 2500, decay=6, volume=0.35, attack=0.05)),
    (0.22, noise(0.06, None, 500, decay=40, volume=0.9)),
    (0.26, bell(note(12), 0.45, ratio=2.0, depth=1.5, decay=7, volume=0.8)),
    (0.34, bell(note(19), 0.50, ratio=2.0, depth=1.2, decay=6, volume=0.7)),
), seconds=0.35), peak=0.8)

# 승리: 밝게 올라가는 음과 마지막 화음.
chord = sum(bell(note(s), 0.95, ratio=2.0, depth=1.0, decay=3.2, volume=v) for s, v in [(12, 1.0), (16, 0.7), (19, 0.7), (24, 0.5)])
write("win", reverb(at(
    (0.00, pluck(note(0), 0.22, decay=9)),
    (0.11, pluck(note(4), 0.22, decay=9)),
    (0.22, pluck(note(7), 0.22, decay=9)),
    (0.33, pluck(note(12), 0.25, decay=8)),
    (0.46, chord),
    (0.46, noise(0.5, 4000, 11000, decay=6, volume=0.15, attack=0.02)),
), seconds=0.45, amount=0.28), peak=0.85)

# 실패: 힘없이 내려가는 음.
sad = lambda s, d: pluck(note(s, base=261.63), d, decay=5) + bell(note(s, base=261.63), d, ratio=1.0, depth=0.6, decay=5, volume=0.5)
write("lose", reverb(at(
    (0.00, sad(7, 0.30)),
    (0.22, sad(3, 0.30)),
    (0.44, sad(0, 0.35)),
    (0.68, np.sin(sweep(note(-5, base=261.63), note(-9, base=261.63), 0.6)) * envelope(0.6, attack=0.02, decay=4) * 0.9),
), seconds=0.4, amount=0.25), peak=0.75)

# 랜드마크 복원: 반짝이며 올라가는 종 소리와 따뜻한 화음.
sparkles = [(0.04 * i, bell(note(s + 12), 0.30, ratio=3.0, depth=1.5, decay=12, volume=0.5)) for i, s in enumerate([0, 4, 7, 12, 16, 19])]
warm = sum(bell(note(s), 1.0, ratio=1.0, depth=0.8, decay=3.0, volume=v) for s, v in [(0, 0.9), (7, 0.7), (16, 0.6)])
write("restore", reverb(at(
    *sparkles,
    (0.22, warm),
    (0.0, np.sin(sweep(300, 1500, 0.30)) * envelope(0.30, attack=0.08, decay=8) * 0.2),
), seconds=0.5, amount=0.3), peak=0.85)

# 버튼: 짧고 부드러운 톡.
write("tap", at(
    (0, np.sin(sweep(1100, 700, 0.05)) * envelope(0.05, decay=60)),
    (0, noise(0.012, 2000, 8000, decay=200, volume=0.3)),
), peak=0.45)

print(sorted(os.listdir(OUT)))
