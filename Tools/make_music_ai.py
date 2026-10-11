#!/usr/bin/env python3
"""ElevenLabs의 음악 생성으로 배경 음악을 만들어 GameScene/Sources/GameScene/Music에 넣는다.

API 키는 맥의 키체인(elevenlabs-api-key)에서 읽는다(Tools/make_sounds_ai.py와 같다).
받은 곡은 앞뒤 무음을 자르고, 끝부분을 처음과 겹쳐 섞어 끊김 없이 반복되게 만든 뒤 AAC로 줄인다.
원본은 Art/sounds/에 남긴다.

사용법: python3 Tools/make_music_ai.py [이름 ...]      (이름을 주면 그 곡만 다시 만든다)
        python3 Tools/make_music_ai.py --loop [이름 ...]  (API를 부르지 않고 원본에서 반복 처리만 다시 한다)
"""
import json
import os
import subprocess
import sys
import urllib.request
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "GameScene", "Sources", "GameScene", "Music")
RAW = os.path.join(ROOT, "Art", "sounds")
RATE = 44100
# 끝과 처음을 겹쳐 섞는 길이(초).
CROSSFADE = 3.0
COMMON = (" Instrumental only, no vocals. It will loop as video game background music, so keep the same"
          " instruments, tempo and energy from the first second to the last: no intro build-up, no breakdown,"
          " no big ending, no fade out.")

# 이름: (프롬프트, 길이(초))
TRACKS = {
    "music_intro": (
        "Playful, adventurous storybook theme for the title screen and intro of a cute casual puzzle game about"
        " a little hero cleaning up pink alien goo from the Earth. Bouncy pizzicato strings, marimba, light"
        " glockenspiel, soft brass accents and a gentle sci-fi theremin-like whistle. Curious and a little"
        " mischievous but warm and hopeful. Mid tempo around 105 BPM, C major.", 45),
    "music_city": (
        "Calm, hopeful, slightly wistful music for the menu screen of a casual puzzle game about cleaning up and"
        " rebuilding a ruined city. Soft felt piano melody, warm pads, a little glockenspiel, very light percussion."
        " Slow tempo around 80 BPM, C major.", 60),
    "music_game": (
        "Light, playful, relaxed music for a casual match-3 puzzle game. Marimba and soft plucked synth melody,"
        " gentle lo-fi beat, warm bass, a few subtle sci-fi sparkles. Mid tempo around 100 BPM, C major."
        " Pleasant in the background for a long time, never busy or loud.", 60),
}


def api_key():
    result = subprocess.run(
        ["security", "find-generic-password", "-a", os.environ["USER"], "-s", "elevenlabs-api-key", "-w"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit("키체인에 elevenlabs-api-key가 없다. Tools/make_sounds_ai.py 위쪽의 등록 명령을 먼저 실행한다.")
    return result.stdout.strip()


def generate(key, prompt, seconds):
    body = json.dumps({"prompt": prompt + COMMON, "music_length_ms": seconds * 1000}).encode()
    request = urllib.request.Request(
        "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128",
        data=body, headers={"xi-api-key": key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        sys.exit(f"ElevenLabs 요청 실패 {error.code}: {error.read().decode(errors='replace')[:400]}")


def make_loop(name):
    """원본을 끊김 없이 반복되는 곡으로 만든다."""
    mp3_path = os.path.join(RAW, name + ".mp3")
    temp = os.path.join(RAW, name + ".tmp.wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "2", mp3_path, temp], check=True)
    with wave.open(temp) as f:
        sound = np.frombuffer(f.readframes(f.getnframes()), "<i2").astype(float).reshape(-1, 2) / 32768
    level = np.abs(sound).max(axis=1)
    loud = np.flatnonzero(level > 0.02 * level.max())
    sound = sound[loud[0]: loud[-1] + 1]
    # 끝부분을 처음 위에 겹쳐 섞고 끝을 잘라낸다. 그러면 마지막 칸 다음에 첫 칸이 자연스럽게 이어진다.
    n = int(RATE * CROSSFADE)
    x = np.linspace(0, np.pi / 2, n)[:, None]
    head = sound[:n] * np.sin(x) + sound[-n:] * np.cos(x)
    sound = np.concatenate([head, sound[n:-n]])
    sound = sound / np.abs(sound).max() * 0.8
    with wave.open(temp, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((sound * 32767).astype("<i2").tobytes())
    out = os.path.join(OUT, name + ".m4a")
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "128000", temp, out], check=True)
    os.remove(temp)
    return len(sound) / RATE, os.path.getsize(out) / 1e6


def main():
    args = sys.argv[1:]
    only_loop = args[:1] == ["--loop"]
    names = (args[1:] if only_loop else args) or list(TRACKS)
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    key = None if only_loop else api_key()
    for name in names:
        if not only_loop:
            prompt, seconds = TRACKS[name]
            with open(os.path.join(RAW, name + ".mp3"), "wb") as f:
                f.write(generate(key, prompt, seconds))
        seconds, megabytes = make_loop(name)
        print(f"{name}: {seconds:.1f}초, {megabytes:.1f}MB")


main()
