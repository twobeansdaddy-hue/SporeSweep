#!/usr/bin/env python3
"""ElevenLabs의 효과음 생성으로 효과음을 만들어 GameScene/Sources/GameScene/Sounds에 WAV로 쓴다.

API 키는 맥의 키체인에서 읽는다. 저장소나 셸 기록에 남기지 않기 위해서다. 먼저 터미널에서 한 번 등록한다.
    security add-generic-password -U -a "$USER" -s elevenlabs-api-key -w
받은 소리는 앞뒤의 무음을 잘라내고, 정해 둔 길이로 줄이고, 음량을 맞춘다. 원본은 Art/sounds/에 남긴다.

사용법: python3 Tools/make_sounds_ai.py [이름 ...]   (이름을 주면 그 소리만 다시 만든다)
        python3 Tools/make_sounds_ai.py --derive   (API를 부르지 않고 clear3에서 나머지 단계만 다시 만든다)
"""
import json
import os
import subprocess
import sys
import urllib.request
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "GameScene", "Sources", "GameScene", "Sounds")
RAW = os.path.join(ROOT, "Art", "sounds")
RATE = 44100
STYLE = "Casual mobile puzzle game sound effect, clean, bright, cartoonish, no voice, no music bed, no background noise. "

# 이름: (프롬프트, 요청 길이(초), 잘라 쓸 최대 길이(초), 최대 음량)
SOUNDS = {
    "swap": ("A very short soft whoosh with a tiny pop, two game tiles sliding past each other.", 0.5, 0.18, 0.55),
    "reject": ("A short dull low double thud, a blocked move, gentle negative feedback.", 0.5, 0.30, 0.60),
    # 매치 제거음은 하나만 만들고, 나머지 단계는 이것의 음높이를 바꿔 만든다(CLEAR_STEPS).
    "clear3": ("A single short bubbly pop with a bright marimba note and a little sparkle, medium pitch.", 0.5, 0.45, 0.70),
    "create": ("A quick rising magical shimmer, a power-up item appearing, sci-fi energy charging up.", 0.8, 0.80, 0.75),
    "special": ("A sci-fi energy beam cannon firing followed by a short punchy explosion.", 1.0, 0.95, 0.90),
    "drone": ("A tiny cute cleaning drone zipping away with a quick rising propeller whir, then a light bubbly pop as it hits.", 0.9, 0.80, 0.80),
    "crack": ("A short stone block cracking and crumbling into small rubble.", 0.6, 0.45, 0.80),
    "collect": ("A quick suction whoosh pulling something into a metal container, then a clean confirmation chime.", 1.2, 1.20, 0.80),
    "win": ("A short cheerful victory jingle, bright bells and marimba rising to a happy final chord.", 1.9, 1.90, 0.85),
    "lose": ("A short gentle sad descending jingle, soft marimba, level failed, not harsh.", 1.8, 1.80, 0.75),
    "restore": ("A warm magical restoration sound, sparkling chimes rising into a soft glowing chord.", 1.8, 1.80, 0.85),
    "tap": ("A tiny soft UI button click.", 0.5, 0.10, 0.45),
    # 인트로의 장면마다 하나씩.
    "introEarth": ("A gentle magical sparkle chime, peaceful and dreamy, like a calm morning in a storybook.", 1.8, 1.80, 0.60),
    "introInvasion": ("A cartoon flying saucer swooping in with a wobbly sci-fi hum, then gooey slime splats and plops.", 1.9, 1.90, 0.80),
    "introRuin": ("A sad cartoon descending tone with a low rumble and a few stones crumbling, gentle, not scary.", 1.9, 1.90, 0.75),
    "introHero": ("A short heroic cartoon power-up fanfare with a bright rising sparkle, a hero appears.", 1.8, 1.80, 0.80),
    "introArrival": ("A sci-fi cleaning device charging up with a bright rising whoosh and a confident ding.", 1.6, 1.60, 0.80),
}


# 연쇄 단계별 매치 제거음의 음높이(반음). 따로 만들면 음색과 음정이 제각각이라 clear3 하나에서 만든다.
CLEAR_STEPS = {"clear1": -4, "clear2": -2, "clear4": 3, "clear5": 5}


def read_wav(name):
    with wave.open(os.path.join(OUT, name + ".wav")) as f:
        return np.frombuffer(f.readframes(f.getnframes()), "<i2").astype(float) / 32768


def write_wav(name, sound):
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype("<i2").tobytes())


def derive_clears():
    """clear3을 빠르거나 느리게 다시 읽어 음높이를 바꾼다."""
    base = read_wav("clear3")
    for name, semitones in CLEAR_STEPS.items():
        ratio = 2 ** (semitones / 12)
        positions = np.arange(0, len(base) - 1, ratio)
        sound = np.interp(positions, np.arange(len(base)), base)
        fade = min(int(RATE * 0.04), len(sound) // 3)
        sound[-fade:] *= np.linspace(1, 0, fade)
        write_wav(name, sound / np.abs(sound).max() * np.abs(base).max())
        print(f"{name}: clear3에서 {semitones:+d}반음, {len(sound) / RATE:.2f}초")


def api_key():
    result = subprocess.run(
        ["security", "find-generic-password", "-a", os.environ["USER"], "-s", "elevenlabs-api-key", "-w"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit("키체인에 elevenlabs-api-key가 없다. 파일 위쪽의 등록 명령을 먼저 실행한다.")
    return result.stdout.strip()


def generate(key, text, seconds):
    body = json.dumps({"text": STYLE + text, "duration_seconds": seconds, "prompt_influence": 0.6}).encode()
    request = urllib.request.Request(
        "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128",
        data=body, headers={"xi-api-key": key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        sys.exit(f"ElevenLabs 요청 실패 {error.code}: {error.read().decode(errors='replace')[:300]}")


def finish(name, mp3_path, limit, peak):
    """무음을 잘라내고, 길이와 음량을 맞춰 WAV로 쓴다."""
    temp = os.path.join(RAW, name + ".tmp.wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1", mp3_path, temp], check=True)
    with wave.open(temp) as f:
        sound = np.frombuffer(f.readframes(f.getnframes()), "<i2").astype(float) / 32768
    os.remove(temp)
    loud = np.flatnonzero(np.abs(sound) > 0.02 * np.abs(sound).max())
    sound = sound[max(loud[0] - int(RATE * 0.003), 0): loud[-1] + int(RATE * 0.02)]
    sound = sound[: int(RATE * limit)]
    fade = min(int(RATE * 0.04), len(sound) // 3)
    sound[-fade:] *= np.linspace(1, 0, fade)
    write_wav(name, sound / np.abs(sound).max() * peak)
    return len(sound) / RATE


def main():
    if sys.argv[1:] == ["--derive"]:
        return derive_clears()
    names = sys.argv[1:] or list(SOUNDS)
    os.makedirs(RAW, exist_ok=True)
    key = api_key()
    for name in names:
        text, seconds, limit, peak = SOUNDS[name]
        mp3_path = os.path.join(RAW, name + ".mp3")
        with open(mp3_path, "wb") as f:
            f.write(generate(key, text, seconds))
        print(f"{name}: {finish(name, mp3_path, limit, peak):.2f}초")
    if "clear3" in names:
        derive_clears()


main()
