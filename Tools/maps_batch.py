"""남은 다섯 권역의 지도(깨끗한 것과 오염된 것)를 Codex로 그린다. 이미 있는 그림은 건너뛴다."""
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor

I = "Art/incoming"
MAPS = {
    "south_europe": "SOUTHERN EUROPE AND THE MEDITERRANEAN. The Mediterranean Sea fills the lower half; the North African coast is a thin strip of sandy-yellow land along the very bottom edge. The Iberian peninsula (Spain) is the big block on the left (Barcelona is on its east coast at about 27% from the left and 38% from the top). The Italian boot hangs down in the center with Sicily at its toe and Sardinia to its left (Rome is at about 50% from the left and 43% from the top). The Balkan peninsula with Greece and its many small islands is on the right (Athens is at about 73% from the left and 57% from the top). France, the Alps (a band of bigger hills) and central Europe fill the top and continue off the top edge. Turkey continues off the right edge.",
    "west_europe": "WESTERN EUROPE. The British Isles (Great Britain and Ireland) are the two islands on the upper left (London is at about 36% from the left and 45% from the top). France is the big block in the lower center, with the Atlantic and the Bay of Biscay to its left (Paris is at about 44% from the left and 60% from the top). The Low Countries and Germany are on the right side of the North Sea (Amsterdam is at about 57% from the left and 42% from the top). Scandinavia hangs down from the top right. The Iberian peninsula and the Alps are at the bottom and continue off the bottom edge; central Europe continues off the right edge.",
    "north_america": "NORTH AMERICA. Canada fills the top with Hudson Bay as a big bite of sea at the top center and continues off the top edge; Alaska is at the upper left; Greenland peeks in at the top right. The United States is the wide middle band, with the Great Lakes as small blue lakes in the upper middle-right, the Rocky Mountains as a band of bigger hills down the left third, and Florida hanging down at the lower right. Mexico narrows toward the bottom center and the Gulf of Mexico and the Caribbean with a few islands are at the lower right. San Francisco is on the west coast at about 22% from the left and 50% from the top; New York is on the east coast at about 77% from the left and 41% from the top. Use sandy-yellow for the dry southwest and Mexico, green elsewhere, and white for the far north.",
    "south_america": "SOUTH AMERICA. The whole recognizable outline of South America fills the center and right: wide at the top (the Amazon, deep green), the bulge of Brazil on the right (Rio de Janeiro is on its southeast coast at about 72% from the left and 52% from the top), narrowing to the pointed tip of Patagonia at about 86% from the top (Buenos Aires is on the east coast at about 55% from the left and 70% from the top). The Andes run down the whole left (west) coast as a band of bigger hills. Central America enters at the top left. The Pacific Ocean fills the left side; far out in it, one tiny lonely island (Easter Island) sits at about 20% from the left and 62% from the top.",
    "oceania": "OCEANIA AND ANTARCTICA. Australia is the big landmass in the center (sandy-yellow in the middle, green along the east and north coasts; Sydney is on its southeast coast at about 62% from the left and 47% from the top), with Tasmania below it. New Guinea and a few Indonesian islands are along the top. New Zealand is the two long islands at the lower right (Auckland is at about 78% from the left and 56% from the top). A scattering of tiny Pacific islands is at the upper right. The bottom 16% of the image is the white icy coast of Antarctica with soft blue shadows, stretching across the full width, with a few small icebergs in the sea above it.",
}


def codex(prompt, images):
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write"]
    for image in images:
        args += ["-i", image]
    subprocess.run(args + ["-"], input=prompt.encode(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def draw(name):
    clean = f"{I}/map_{name}.png"
    if not os.path.exists(clean):
        codex(f"""Use your built-in image generation tool to create ONE image and save it as a PNG at {clean} (1024x1536, portrait). Do not modify any other file.
The attached image is the East Asia map of a casual puzzle game. Draw another region in exactly the same art style (cute toy-like map seen from above; flat bright saturated blue sea; smooth, glossy, chunky rounded landmasses like soft clay with big soft highlights and a thin light-cyan shallow-water rim; only a few large rounded glossy hills; NO trees, NO rivers, NO fine texture; a few puffy white clouds and tiny wave marks over the sea), with correct simplified geography: {MAPS[name]}
Keep everything important between 14% and 86% of the width. No borders, no flags, no labels, no text, no markers, no pins, no ships or planes.""", [f"{I}/map_east_asia.png"])
    polluted = f"{I}/map_{name}_polluted.png"
    if os.path.exists(clean) and not os.path.exists(polluted):
        codex(f"""Use your built-in image generation tool to EDIT the FIRST attached image and produce ONE image with exactly the same size, composition, coastlines, landmasses, hills, clouds and waves in exactly the same places. Do not move, add or remove any land. The SECOND attached image shows the look of a contaminated map in this game. Only change the condition, to show the same world contaminated by pink alien goo before it has been cleaned:
- Land (including sand and ice): a dull, sickly gray-olive / ashen brown-gray color, dry and lifeless, still glossy and soft like clay, with the hills in the same places but gray.
- On the land: many splats and puddles of glossy hot-pink alien jelly with small dark maroon nuclei, of different sizes, scattered over all the landmasses, some dripping over the coast into the sea.
- Sea: a darker, murky slate-blue with a slight purple tint instead of bright blue; waves and clouds stay but the clouds are dull gray-purple.
Keep the same cute toy-like art style. No text, no labels, no markers, no pins, no borders.
Save the result as a PNG at {polluted} (1024x1536). Do not modify any other file.""", [clean, f"{I}/map_east_asia_polluted.png"])


with ThreadPoolExecutor(max_workers=3) as pool:
    list(pool.map(draw, MAPS))
