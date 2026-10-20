"""Claude Code mods판(mods/sporesweep)에 넣을 데이터와 엔진을 모은다.

- 레벨과 도시 JSON을 ES 모듈 하나(hooks/levels.mjs)로 묶는다. mods는 파일을 읽을 수 없고 모듈만 불러온다.
- 규칙 엔진(:mod를 esbuild로 묶은 것)을 hooks/engine.mjs로 복사한다.

사용법: python3 Tools/make_mod.py   (엔진은 먼저 cd android && ./gradlew :mod:modEngine 으로 만든다)
"""
import json
import os
import shutil

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
LEVELS = os.path.join(ROOT, "LevelData", "Sources", "LevelData", "Levels")
MOD = os.path.join(ROOT, "mods", "sporesweep", "hooks")
ENGINE = os.path.join(ROOT, "android", "mod", "build", "engine", "sporesweep-engine.mjs")

# 도시의 순서(LevelCatalog.cityIDs).
CITIES = [
    "seoul", "tokyo", "beijing", "newdelhi", "bangkok", "singapore", "cairo", "dubai", "capetown",
    "rome", "athens", "barcelona", "paris", "london", "amsterdam",
    "newyork", "sanfrancisco", "washington", "rio", "buenosaires", "easterisland",
    "sydney", "auckland", "antarctica",
]

levels = {}
cities = []
for city in CITIES:
    with open(os.path.join(LEVELS, city + ".json"), encoding="utf-8") as f:
        info = json.load(f)
    ids = sorted(name[:-5] for name in os.listdir(LEVELS) if name.startswith(city + "-") and name.endswith(".json"))
    for level_id in ids:
        with open(os.path.join(LEVELS, level_id + ".json"), encoding="utf-8") as f:
            levels[level_id] = f.read()
    cities.append({"id": city, "name": info["name"], "landmark": info["landmark"]["name"], "levels": ids})

os.makedirs(MOD, exist_ok=True)
with open(os.path.join(MOD, "levels.mjs"), "w", encoding="utf-8") as f:
    f.write("// Tools/make_mod.py가 만든다. 고치지 않는다.\n")
    f.write("export const cities = " + json.dumps(cities, ensure_ascii=False) + ";\n")
    f.write("export const levels = " + json.dumps(levels, ensure_ascii=False) + ";\n")
with open(os.path.join(MOD, "levels.d.mts"), "w", encoding="utf-8") as f:
    f.write("// Tools/make_mod.py가 만든다.\n")
    f.write("export declare const cities: { id: string; name: string; landmark: string; levels: string[] }[]\n")
    f.write("export declare const levels: Record<string, string>\n")
shutil.copyfile(ENGINE, os.path.join(MOD, "engine.mjs"))
shutil.copyfile(ENGINE.replace("engine/sporesweep-engine.mjs", "compileSync/js/main/productionLibrary/kotlin/sporesweep-mod.d.mts"), os.path.join(MOD, "engine.d.mts"))
print(f"도시 {len(cities)}곳, 레벨 {len(levels)}개, 엔진 {os.path.getsize(ENGINE) // 1024}KB")
