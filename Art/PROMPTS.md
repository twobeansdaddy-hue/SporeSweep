# ChatGPT 아트 프롬프트

게임의 그림을 ChatGPT 이미지 생성으로 만들기 위한 프롬프트다. 모두 8장이다(1\~7번과 2-B).

## 지금 쓰는 그림 (v2)

실기기에서 보니 처음 그림은 굵은 검은 외곽선과 거친 질감 때문에 투박했다. 그래서 보드에 나오는 그림을 모두 둥글고 선명한 화풍으로 다시 그렸다. 새 블록 시트(`sheet_blocks_v2.png`)를 화풍 기준으로, 예전 시트를 내용 참조로 Codex에 함께 붙여 만들었다.

| 파일 | 내용 |
| --- | --- |
| `sheet_blocks_v2.png` | 일반 블록 6종 |
| `sheet_specials_v2.png` | 중화 폭탄, 정화 코어, 콘크리트 2종, 슬러지 |
| `sheet_cannon_v2.png` | 제염 빔 대포 |
| `sheet_materials_v2.png` | 물질 1칸, 물질 2×2, 철망 |
| `sheet_wide_v2.png` | 물질 2×1, 격리 컨테이너 |
| `sheet_wall.png` | 벽. 부술 수 없는 짙은 남색 암반 타일 |
| `sheet_cocoon.png` | 오염 고치. 분홍 점액 덩어리이고, 가운데의 빈 창에 앱이 갇힌 블록의 그림을 넣는다. 처음에 그린 자물쇠 상자(`old/sheet_lock.png`)는 쓰지 않는다 |
| `sheet_spores_v2.png` | 랜드마크 위에 얹는 비정형 포자 4종 |
| `intro_1.png`\~`intro_5.png` | 인트로 장면 다섯 장(세로 1024×1536). 정화 대원은 `intro_4.png`에서 처음 그렸고, 5번과 타이틀은 그 그림을 참조로 붙여 같은 인물로 그렸다 |
| `title_art.png` | 타이틀 화면의 그림 |
| `logo.png` | 게임 이름. 분홍 젤리 글자이고 O 자리에 포자가 들어간다 |
| `tokyo_restored.png`, `tokyo_ruined.png` | 도쿄타워. 숭례문 그림을 구도 참조로 붙여 같은 틀로 그렸고, 폐허는 복원된 그림을 고쳐 만들었다 |
| `beijing_restored.png`, `beijing_ruined.png` | 만리장성. 가운데 망루와 양옆의 성벽 |
| `sheet_rubble.png` | 잔해 더미. 돌과 벽돌이 쌓인 무더기 |
| `{seoul,tokyo,beijing,bangkok,singapore}_bg_{restored,ruined}_v2.png` | 나머지 다섯 도시의 배경. 뉴델리 배경을 구도 참조로 붙여 지평선(위에서 약 66%)과 해, 구름의 자리를 맞췄다 |
| `{seoul,tokyo,beijing,bangkok,singapore}_building_{restored,ruined}_v2.png` | 나머지 다섯 도시의 건물. 처음 그림과 뉴델리의 새 건물을 함께 붙여 초록 배경 위에 크게 그렸다. 건물에 초록을 쓰지 말라고 적어야 한다. 숭례문의 그림은 앱에서 `landmark_` 접두어를 쓴다. 처음 그림은 `old/*_v1.png` |
| `intro_1.png`, `intro_2.png`, `intro_4.png` | 인트로의 첫째(지구), 둘째(외계인의 침공), 넷째(정화 대원) 장면. 앞 그림과 새 다섯째 장면을 함께 붙여 구도와 색은 그대로 두고 윤곽과 음영만 두툼하게 다시 그렸다. 앞 그림은 `old/intro_*_v1.png` |
| `intro_3.png`, `intro_5.png` | 인트로의 셋째(망가진 랜드마크)와 다섯째(서울 도착) 장면. 숭례문이 새 그림과 달라서, 앞 그림과 새 폐허 숭례문을 함께 붙여 구도는 그대로 두고 다시 그렸다. 앞 그림은 `old/intro_*_v1.png` |
| `cairo_bg_*_v2.png`, `cairo_building_*_v2.png` | 카이로의 피라미드와 스핑크스. 처음부터 배경과 건물을 따로 그렸다. 건물은 뉴델리의 새 건물 그림을 화풍 참조로 붙였다 |
| `map_mideast_africa.png`, `map_mideast_africa_polluted.png` | 중동·아프리카 지도. 동아시아 지도를 화풍 참조로 붙였고, 사하라와 아라비아는 모래색이다 |
| `sheet_sticky.png` | 끈끈이 바닥(1024×1024, 1칸). 청록색 점액 웅덩이. 가운데는 블록이 놓이므로 비워 그렸다. 자홍색 배경 |
| `dubai_bg_*_v2.png`, `dubai_building_*_v2.png` | 두바이의 부르즈 알 아랍. 카이로의 그림을 구도와 화풍 참조로 붙였다. 섬의 야자수는 초록 배경과 섞이지 않게 청록색으로 그렸다 |
| `sheet_egg.png` | 포자 알(1024×1024, 1칸). 철띠를 두른 짙은 남색 알. 자홍색 배경 |
| `capetown_bg_*_v2.png`, `capetown_building_*_v2.png` | 케이프타운의 테이블마운틴 케이블카. 배경에 산을 크게 그렸고(케이블카는 그리지 말라고 적었다), 건물 그림에는 승강장 둘, 철탑, 줄, 둥근 케이블카만 있다. 앱에 넣을 때 배경을 위로 72픽셀 올리고 세로로 늘였다 |
| `{rome,athens,…,antarctica}_{bg,building}_{restored,ruined}_v2.png` | 넷째 권역부터의 도시 15곳. `Tools/cities_batch.py`에 도시마다 먼 풍경, 땅, 건물, 폐허에서 달라지는 점을 적어 두고 한꺼번에 그렸다. 카이로의 그림을 참조로 붙였다. `Tools/install_cities.py`로 앱에 넣는다 |
| `map_{south_europe,west_europe,north_america,south_america,oceania}{,_polluted}.png` | 넷째 권역부터의 지도. `Tools/maps_batch.py`로 그렸다 |
| `sheet_overlays.png` | 블록 위에 얹는 그림 3종(1536×512, 3칸). 자물쇠 달린 쇠사슬, 보호막 고리, 얼음. 자홍색 배경이고 빈 곳은 배경이 비친다. 얼음은 자른 뒤 가운데를 반투명하게 만든다 |
| `sheet_r4.png` | 운석 조각과 안개 굴뚝(온전한 것, 금 간 것). 1536×512, 3칸, 자홍색 배경 |
| `sheet_cannon4.png` | 제염 빔(지금 쓰는 것). 앞 그림이 새 블록 옆에서 가늘어 보여서, 가운데 큰 렌즈와 양 끝의 넓은 금색 포구가 있는 굵은 대포로 다시 그렸다. 높이가 폭의 절반쯤이다. 세로 빔은 90도 돌린 것이다. 앞 그림은 `old/block_beam_*_v3.png` |
| `sheet_tools.png` | 아이템 3종(1536×512, 3칸). 망치, 바꾸기, 섞기. 새 블록 시트를 화풍 참조로 붙였다. 자홍색 배경이고 `Tools/cut_magenta.py`로 자른다 |
| `sheet_blocks_v3.png` | 일반 블록 6종(지금 쓰는 것). 앞 시트와 새 숭례문 그림을 붙여 "같은 물체, 같은 색과 윤곽, 윗면과 옆면이 보이는 두툼한 모습에 세부를 더해서"로 다시 그렸다. 원뿔이 초록이라 배경은 자홍색(#FF00FF)이고 `Tools/cut_magenta.py`로 자른다. 앞 그림은 `old/sprites_blocks_v2/` |
| `newdelhi_bg_restored_v2.png`, `newdelhi_bg_ruined_v2.png` | 인디아 게이트의 배경(풍경 시험판). 건물 없이 하늘, 먼 대통령궁과 가로수, 의장대로와 연못만 그렸다. 폐허는 복원된 그림을 고쳐 만들었다. 지평선은 위에서 68%다 |
| `newdelhi_building_restored_v2.png`, `newdelhi_building_ruined_v2.png` | 인디아 게이트의 건물(풍경 시험판). 순수한 초록 배경 위에 1536×1024 그림의 제자리에 크게 그렸다. 폐허는 복원된 그림을 고쳐 만들었다. `Tools/key_landmark.py`로 초록을 지운다. 처음 그림은 `old/newdelhi_*_v1.png` |
| `sheet_nest.png` | 포자 둥지(앱에서는 분홍을 짙은 포도주색으로 옮겨 쓴다. 고치와 안개도 색을 옮겼고, 옮기기 전 그림은 `old/sprites_pink/`)(가로 1024×512, 2칸). 왼쪽은 온전한 것, 오른쪽은 금이 간 것. 오염 고치 시트를 화풍 참조로 붙였다 |
| `bangkok_restored.png`, `bangkok_ruined.png` | 왓 아룬. 인디아 게이트 그림을 구도와 화풍 참조로 붙여 그렸다. 가운데 큰 탑과 양옆의 작은 탑, 넓은 기단. `split_landmark.py`의 `wall` 모양으로 나눈다 |
| `sheet_timer.png` | 시한 포자(1024×1024, 1칸). 심지가 달린 분홍 포자이고 가운데의 어두운 원은 비어 있다. 숫자는 앱이 적는다 |
| `singapore_restored.png`, `singapore_ruined.png` | 마리나 베이 샌즈. 왓 아룬 그림을 구도와 화풍 참조로 붙여 그렸다. 건물에 하늘색을 쓰지 말라고 적어야 한다(하늘과 함께 지워진다) |
| `sheet_fog.png` | 오염 안개(1024×1024, 1칸). 칸을 다 덮는 불투명한 보라색 구름 |
| `map_world.png` | 세계 지도(가로 1536×1024). 권역의 번호는 앱이 얹는다 |
| `map_south_asia.png` | 남아시아 지도(세로 1024×1536). 동아시아 지도를 화풍 참조로, 앞 그림을 구도 참조로 붙여 "나무·강·바위 없이 매끈한 젤리 땅과 둥근 언덕만"으로 다시 그렸다. 인도 북쪽이 바다였던 첫 그림은 `old/map_south_asia_v1.png`, 지리는 맞지만 나무와 바위산이 자잘했던 그림은 `old/map_south_asia_v2.png` |
| `map_east_asia_polluted.png`, `map_south_asia_polluted.png`, `map_world_polluted.png` | 오염된 지도. 깨끗한 지도를 붙이고 "구도와 해안선은 그대로 두고 땅은 잿빛, 분홍 젤리 얼룩, 바다는 탁하게"로 고쳐 만들었다. 깨끗한 지도를 다시 그리면 이것도 다시 만들어야 한다 |
| `map_east_asia.png` | 동아시아 지도(세로 1024×1536). 도시 표시는 앱이 얹는다 |

화풍 지시는 다음과 같다. 다시 그릴 때 그대로 붙인다.

```text
Cute, soft and toy-like; very rounded, puffy, simplified shapes; bright, clean, highly saturated candy colors with smooth gradients; a big soft white glossy highlight on the upper left and a gentle darker shade at the bottom, like shiny jelly or glazed plastic; thin-to-medium smooth outline in a darker shade of the object's own color (never pure black); no cracks-and-dirt grit, no scratches, no pits, no heavy rivets. Background: one flat, solid, pure green color (#00FF00) everywhere, no glow, no gradient, no shadows, no grid lines, no text.
```

랜드마크도 같은 화풍으로 다시 그렸다. `landmark_restored.png`는 예전 그림을 구도 참조로, 새 블록 시트를 화풍 참조로 붙여 만들었고, `landmark_ruined.png`는 그 결과를 고쳐 만들었다. 예전 그림은 `Art/incoming/old/`에 `_v2`를 붙여 두었다.

앱 아이콘(`app_icon.png`)도 새 포자 그림을 화풍 참조로 붙여 다시 그렸다. 처음에는 둥근 포자로 그렸다가, 한쪽으로 쏠려 흘러내리는 비정형 포자(`sheet_spores_v2.png`의 왼쪽 위 모양)로 바꿨다.

아래 1\~7번은 처음 그림을 만들 때의 기록이다.

## 진행 방법

1. **한 대화에서 순서대로 만든다.** 1번 그림이 화풍의 기준이 된다. 2번부터는 같은 대화에서 이어서 요청해야 화풍이 맞는다. 대화를 새로 열었다면 1번 그림을 첨부하고 "이 그림과 같은 화풍으로"를 덧붙인다.
2. **프롬프트는 영어 그대로 붙여 넣는다.** 한국어로 고쳐 써도 되지만, 격자와 배경 지시는 영어가 더 잘 지켜지는 편이다.
3. **마음에 들지 않으면 그 자리에서 고친다.** "3번 칸의 유리를 더 뾰족하게"처럼 바꿀 부분만 말한다.
4. **받은 그림은 아래 파일 이름으로 `Art/incoming/`에 넣는다.** 자르고 앱에 넣는 일은 Claude가 한다.

**Codex CLI로 만들기.** 4\~7번은 ChatGPT 화면 대신 터미널의 Codex CLI로 만들었다. 이미지 생성 기능이 들어 있어서, 프롬프트와 참조 그림을 주면 파일로 저장까지 한다. 다시 만들 때도 같은 방법을 쓴다.

```bash
codex exec --skip-git-repo-check -s workspace-write -i Art/incoming/sheet_materials.png "Use your built-in image generation tool to create ONE image following the prompt below, using the attached image as the art style reference. Save it as Art/incoming/<파일 이름>.png. <프롬프트>"
```

6번은 5번 그림을 `-i`로 붙이고 "EDIT the attached image"라고 요청해야 구도가 그대로 유지된다.

**배경에 대해.** 1번은 투명 배경을 요청했지만 어두운 배경에 빛 번짐이 들어간 그림이 나왔다. 물체만 잘라내는 도구(`Tools/cut_sprites.swift`)로 해결했으므로 다시 만들 필요는 없다. 2\~4번은 블록 위에 얹는 표식과 철망처럼 가운데가 비어야 하는 그림이 있어서, 처음부터 순수한 초록색(#00FF00) 단색 배경으로 요청한다. 초록 배경은 코드로 정확히 지울 수 있다.

## 확인할 것

그림마다 아래를 보고, 어긋나면 다시 요청한다.

- 격자의 칸 수와 순서가 맞는가
- 칸마다 그림이 가운데에 있고 옆 칸을 침범하지 않는가
- 글자, 숫자, 테두리 선, 그림자 바닥이 들어가지 않았는가
- 작게 줄여도(약 48픽셀) 서로 구분되는가

---

## 1. 일반 블록 6종 — `sheet_blocks.png` (완료)

가로 1536 × 세로 1024. 3열 2행. 화풍의 기준이 되는 그림이다.

처음 만든 그림의 4번 칸은 통나무 단면이었다. 도시 잔해로 보이지 않고 벽돌과 색이 가까워서 전선 릴로 바꾼다. 아래 프롬프트는 바꾼 내용이다. 이미 만든 시트는 4번 칸만 고쳐 달라고 요청한다.

```text
Create a sprite sheet for a mobile match-3 puzzle game. Image size 1536x1024, transparent background.

Layout: a strict 3 columns x 2 rows grid of equal 512x512 cells. One object per cell, centered, filling about 80% of its cell, with clear empty space between objects. No grid lines, no text, no numbers, no drop shadows on the ground.

Style: stylized flat vector game art, bold simple shapes, thick dark outline, soft highlight on the upper left, gentle shading on the lower right, slightly chunky and friendly. Each object must be instantly recognizable at 48 pixels, and each must have a clearly different silhouette AND a clearly different color.

The objects are pieces of post-disaster debris:
Row 1, left to right:
1. BRICK: a red-orange clay brick block, rounded square silhouette.
2. SCRAP METAL: a steel-gray hexagonal bolt nut, hexagon silhouette.
3. GLASS: a cyan glass shard cut like a gem, diamond (rhombus) silhouette.
Row 2, left to right:
4. WOOD: an empty wooden cable reel (cable spool / drum) seen straight from the front, pale sandy-yellow weathered planks, a dark center hole with a ring of bolts around it, a few cracks and chips, circle silhouette. Construction-site debris, not a tree log. Its color must be clearly different from the red-orange brick.
5. PLASTIC: a bright green plastic warning-cone-like wedge, upward triangle silhouette.
6. SOIL: a clump of contaminated soil, violet-purple, pentagon silhouette.
```

## 2. 특수 블록 표식과 장애물 — `sheet_specials.png` (완료)

가로 1536 × 세로 1024. 3열 2행. 1~3번은 일반 블록 위에 얹는 표식이라, 가운데가 비치도록 요청한다.

처음 만든 그림의 1\~3번은 화살표, 해, 무지개 구슬 같은 추상 기호로 나와 잔해 블록과 어울리지 않았다. 블록에 부착하는 장비로 바꾸고 빛 번짐을 금지했다. 4\~6번은 처음 결과를 그대로 쓴다.

```text
In exactly the same art style as the previous sprite sheet (same rendering, outlines, shading and level of detail), create another sprite sheet. Image size 1536x1024. Background: one flat, solid, pure green color (#00FF00) everywhere, with no glow, no gradient, no vignette and no shadows. Strict 3 columns x 2 rows grid of equal 512x512 cells, one object per cell, centered, no grid lines, no text, no ground shadows.

Row 1, left to right:
1. BEAM EMITTER: a piece of decontamination equipment, not an abstract icon. A horizontal dark-steel bar with bolts and a bright cyan energy strip along its middle, with a chunky nozzle at each end, each nozzle firing a short solid cyan beam outward (one to the left, one to the right). It spans about 88% of the cell width and only about 22% of its height, centered. The rest of the cell stays flat green. It will be strapped across other blocks as an overlay.
2. NEUTRALIZER BOMB: a small round charge that clearly reads as a bomb. A dark-steel sphere with a yellow-and-black hazard band around it, a short cap on top, and one bright orange indicator light in the center. About 45% of the cell, centered. The rest of the cell stays flat green. It will be attached to the middle of other blocks as an overlay.
3. PURIFICATION CORE: a complete block on its own, about 80% of the cell. A heavy dark-steel ring frame with four clamps holding a bright white energy sphere, like a small reactor core. Around the ring, six small round indicator lights in these colors: red-orange, steel gray, cyan, sandy yellow, bright lime, violet. No rainbow swirl, no crystals, no gems.
For all three: same chunky debris-and-machinery look as the blocks, thick dark outline, hard clean edges. No outer glow, no halo, no soft light spilling onto the background, and no green anywhere in the objects.
Row 2, left to right:
4. CONCRETE: a plain gray concrete slab block, almost filling the cell as a rounded square, with a few small cracks.
5. REINFORCED CONCRETE: the same gray concrete slab but with a steel plate bolted on its face and four corner bolts, clearly sturdier.
6. SLUDGE: a blob of dark murky brown-black toxic sludge with a sickly yellow slimy rim and a couple of bubbles, irregular round silhouette. Do not use bright green, because the background is green.
```

## 2-B. 제염 빔 대포 — `sheet_cannon3.png` (완료)

처음에는 위에서 내려다본 대포(`sheet_canon_h.png`의 여섯 번째, `sheet_cannon_v.png`)를 썼는데, 몸통이 정사각형에 가까워 한 칸 크기에서 가로와 세로가 잘 구분되지 않았다. 그래서 Codex로 길쭉한 양방향 대포를 다시 그렸다. 길이가 굵기의 약 2.5배이고, 가운데에 바깥을 가리키는 화살표 두 개가 있다. 처음 나온 것(`sheet_cannon2.png`)은 너무 가늘어 굵게 고쳐 달라고 했다. 세로 빔은 이 그림을 90도 돌린 것이다. 아래 프롬프트는 맨 처음 것으로, 참고로 남긴다.

특수 블록은 옆 칸으로 밀면 발동하고 종류가 없다(기획서 4장). 그래서 블록 위에 얹는 표식이 아니라 블록을 통째로 대신하는 그림 하나면 된다. 중화 폭탄과 정화 코어는 2번에서 만든 그림을 블록 크기로 쓴다. 제염 빔은 2번의 막대가 가늘고 옆 칸과 이어져 보여서, 양쪽으로 쏘는 대포로 다시 만든다. 

```text
In exactly the same art style as the previous sprite sheets (same rendering, outlines, shading and level of detail), create one game sprite. Image size 1024x1024. Background: one flat, solid, pure green color (#00FF00) everywhere, with no glow, no gradient, no vignette and no shadows.

One object, centered: a compact double-ended beam cannon, seen straight from the front. In the center, a chunky round armored turret housing made of dark steel with bolts and a bright cyan energy window in its middle. From the housing, two short, thick barrels point in exactly opposite directions, one straight left and one straight right, each ending in a wide muzzle with a bright cyan energy core inside it. The whole object is perfectly horizontal and symmetrical left-to-right. It is about 80% of the image wide and about 50% of the image tall, with clear empty space on all sides. No beams fired outside the muzzles.

It must read as a block of the same size and weight as the other blocks, not a thin bar. Thick dark outline, hard clean edges. No outer glow, no halo, no soft light spilling onto the background, and no green anywhere in the object. No text.
```

## 3. 오염 물질과 철망 — `sheet_materials.png` (완료)

가로 1024 × 세로 1024. 2열 2행.

```text
In exactly the same art style (same rendering, outlines, shading and level of detail), create another sprite sheet. Image size 1024x1024. Background: one flat, solid, pure green color (#00FF00) everywhere, with no glow, no gradient, no vignette and no shadows. Strict 2 columns x 2 rows grid of equal 512x512 cells, one object per cell, centered, no grid lines, no text, no ground shadows.

Row 1, left to right:
1. ALIEN CONTAMINANT (small): a hot-pink spiky alien spore with about ten short rounded spikes and one dark maroon nucleus in the center. Slightly menacing but still cute. Fills about 80% of the cell.
2. ALIEN CONTAMINANT (large, 2x2): a bigger, heavier version of the same pink alien spore mass, shaped as a rounded square that fills about 92% of the cell, with four dark maroon nuclei arranged two by two.
Row 2, left to right:
3. CAGE OVERLAY: a square steel wire mesh cage seen from the front, 3x3 openings, light silver wires, a slightly thicker outer frame, filling about 90% of the cell. The openings between the wires must show the flat green background, because it will be overlaid on top of other blocks.
4. Leave this cell completely empty, flat green only.

Thick dark outlines and hard clean edges on every object. No outer glow, no halo, no soft light spilling onto the background, and no green anywhere in the objects.
```

## 4. 가로로 긴 그림 — `sheet_wide.png` (완료)

가로 1024 × 세로 1024. 위아래 두 칸.

```text
In exactly the same art style (same rendering, outlines, shading and level of detail), create another sprite sheet. Image size 1024x1024. Background: one flat, solid, pure green color (#00FF00) everywhere, with no glow, no gradient, no vignette and no shadows. The image is split into 2 rows of equal 1024x512 cells, one object per row, centered, no grid lines, no text, no ground shadows.

Top row: ALIEN CONTAMINANT (wide, 2x1): the same hot-pink alien spore mass as the large 2x2 one in the previous sheet (same glossy pink blob with small knobby tendrils around its edge and the same glossy dark maroon nuclei), but shaped as a wide rounded rectangle exactly twice as wide as it is tall, with two nuclei side by side. It fills about 92% of the row's width.
Bottom row: QUARANTINE CONTAINER: a very wide, low industrial hazard container seen straight from the front, like a long open-top steel trough. Dark steel body with bolts, yellow-and-black warning stripes along its top rim, and a plain dark steel panel in the middle with no markings. About eight times wider than tall, perfectly horizontal, filling about 95% of the row's width.

Thick dark outlines and hard clean edges on every object. No outer glow, no halo, no soft light spilling onto the background, and no green anywhere in the objects.
```

## 5. 복원된 숭례문 — `landmark_restored.png` (완료)

처음 나온 그림은 선이 가늘고 묘사가 세밀해서 블록과 화풍이 달랐다. 그래서 그 그림을 구도 참조로, `sheet_blocks.png`를 화풍 참조로 붙여 "굵은 외곽선, 큼직한 돌 몇 줄, 굵은 기와 몇 개로 단순하게" 다시 그렸다. 6번도 그 결과를 고쳐서 만들었고, 하늘과 건물을 코드로 가를 수 있게 "하늘은 거의 한 가지 색, 건물에는 보라색을 쓰지 말 것"을 덧붙였다. 처음 그림은 `Art/incoming/old/`에 있다.

가로 1536 × 세로 1024. 배경이 있는 완성된 한 장이다. 부위를 코드로 나누려면 정면에서 본 좌우 대칭 구도여야 한다.

```text
In the same stylized flat vector art style, create a full scene illustration. Image size 1536x1024, landscape. No text, no people, no vehicles, no modern buildings.

Subject: Sungnyemun (Namdaemun), the historic South Gate of Seoul, fully restored on a clear day.

Composition (important, keep it strict): a perfectly straight-on front view, symmetrical, the gate centered horizontally. The whole building is visible with empty sky on both sides and above it. The horizon/ground line is a straight horizontal line at about 82% of the image height.

Building: a wide stone base wall made of large light-gray granite blocks, slightly wider at the bottom, with one arched gateway in the exact center. On top of the stone base, a two-story wooden pavilion: red-brown walls and columns, and two tiers of dark blue-gray tiled roofs with gently upturned eaves, the lower roof wider than the upper one.

Surroundings: bright blue sky with a soft sun in the upper right and no clouds over the building. Fresh green lawn as the ground. Two round green trees on the far left and two on the far right, not overlapping the building.
```

## 6. 폐허가 된 숭례문 — `landmark_ruined.png` (완료)

5번 그림을 만든 직후, 같은 대화에서 바로 요청한다. 구도가 그대로여야 하므로 새로 그리지 말고 고쳐 달라고 한다.

```text
Edit the previous image. Keep exactly the same composition, camera, framing, building position, building size and proportions, and horizon line. Do not move or resize anything. Only change the condition of things:

- Sky: a dark, hazy purple-gray polluted sky. No sun.
- Ground: bare, dark, scorched earth instead of the lawn, with scattered broken stone rubble.
- Trees: remove the leaves; leave only short dead stumps in the same four places.
- Stone base: darker, dirty, cracked granite. The central arched gateway is collapsed and blocked with fallen stone blocks.
- Lower pavilion story: badly damaged; walls broken and faded, the lower roof partly collapsed with missing tiles.
- Upper pavilion story: destroyed; only a few bare broken columns remain where it stood, no upper roof.

Do not add any creatures, spores, fire, smoke, or text.
```

## 7. 앱 아이콘 — `app_icon.png` (완료, 2026-10-29 다시 그림)

2026-10-29에 귀여운 포자 캐릭터로 다시 그렸다. Codex에 예전 아이콘을 화풍·바탕 참조로 붙이고(모양은 따르지 않게), 후보 세 장(`Art/incoming/icon_v3/`) 가운데 C(분홍, 반짝임·비눗방울)를 골랐다. 프롬프트는 `codex exec -i`가 뒤의 문장을 그림으로 읽으므로 표준 입력으로 넘긴다. 아래는 예전 프롬프트다.

가로 1024 × 세로 1024. 투명 없이 꽉 찬 정사각형이어야 한다(앱스토어 규정).

```text
In the same art style, create a mobile app icon. Image size 1024x1024, fully opaque, no transparency, no rounded-corner mask, no text, no border.

A single hot-pink spiky alien spore with a dark maroon nucleus, large and centered, filling about 65% of the icon, on a deep navy-to-dark-purple gradient background with a faint pink glow behind the spore. Bold, simple, readable at small sizes.
```
