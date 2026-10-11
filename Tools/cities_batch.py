"""남은 다섯 권역의 도시 그림을 Codex로 한꺼번에 그린다(Art/PROMPTS.md).

도시마다 배경(복원, 폐허)과 건물(복원, 폐허) 네 장이다. 이미 있는 그림은 건너뛴다.
사용법: python3 Tools/cities_batch.py [도시 ID ...]
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

I = "Art/incoming"
STYLE = "Style: very rounded, puffy, simplified shapes; bright clean candy colors with smooth gradients; soft glossy highlights; thin smooth outlines in darker shades of each object's own color."

# id: (먼 풍경, 땅, 건물, 폐허에서 달라지는 점)
CITIES = {
    "rome": ("a pale skyline of old Rome: low terracotta-roofed buildings, a few domes and umbrella pine trees.",
             "a wide plaza of pale travertine paving with a path to the horizon center, green lawn at the sides, umbrella pines and cypress trees near the left and right edges, a few fallen ancient column drums, small red poppies.",
             "the COLOSSEUM in Rome seen from the front: a wide oval amphitheatre of warm cream travertine with three stacked tiers of round arches and a plain fourth tier on top; the taller outer wall on the left half steps down to the lower inner wall on the right half, as in reality. It spans from about 10% to 90% of the image width; its top is at about 14% from the top.",
             "large sections of the upper tiers are collapsed, many arches broken, the top edge jagged."),
    "athens": ("pale hills with small white houses and a strip of blue Aegean sea with tiny islands.",
               "a rocky hilltop of pale stone with a stepped marble path to the horizon center, olive trees with silvery leaves near the left and right edges, a few fallen marble blocks and small yellow flowers.",
               "the PARTHENON in Athens seen straight from the front: a white-cream marble temple with eight tall fluted Doric columns on a three-step base, a carved frieze band and a triangular pediment roof with a few simple relief shapes. It spans from about 14% to 86% of the image width; its top is at about 12% from the top.",
               "the pediment and roof are mostly fallen, several columns are broken into stumps, the frieze has gaps."),
    "barcelona": ("a pale skyline of Barcelona with low buildings, a hill on the left and a strip of blue Mediterranean sea on the right.",
                  "a park: a pale paved path to the horizon center, green lawn, a small pond on the lower left, plane trees and palm trees near the left and right edges, colorful mosaic benches in blue, yellow and orange.",
                  "the SAGRADA FAMILIA basilica in Barcelona seen from the front: a sandy-stone church facade with four very tall, slender, tapering spindle-shaped towers (two taller in the middle, two shorter outside) covered in small round openings and topped with colorful mosaic finials in yellow, red and white, above a richly carved facade with three pointed portals and a rose window in deep blue glass. It spans from about 22% to 78% of the image width; its top is at about 4% from the top.",
                  "the tops of all four towers are broken off at different heights, the rose window is shattered, parts of the facade have fallen."),
    "paris": ("a pale skyline of Paris with low cream buildings, gray-blue mansard roofs, a small dome and rows of trees.",
              "a formal garden (Champ de Mars): a long green lawn with a pale gravel path to the horizon center, clipped round trees in rows near the left and right edges, flower beds in red, white and blue, and two small green street lamps.",
              "the EIFFEL TOWER in Paris: a tall iron lattice tower in warm bronze-brown with four splayed legs joined by big arches, a first platform, a second platform, a slender upper section and a small top cabin with a short antenna. The lattice is drawn as chunky, thick, simplified crossed beams with the chroma green visible through the gaps. It spans from about 30% to 70% of the image width at the feet; its tip is at about 3% from the top.",
              "the top third is bent over and broken, beams are missing and twisted, one leg is buckled."),
    "london": ("a pale skyline of London with a big observation wheel on the left, a dome on the right and low buildings.",
               "the River Thames as a band of blue water just below the horizon across the full width, then a stone embankment with a pale paved promenade to the bottom, black-and-gold street lamps, a red telephone box near the left edge, plane trees and flower planters near the edges.",
               "BIG BEN (the Elizabeth Tower) with a part of the Palace of Westminster in London: a tall square Gothic clock tower of honey-colored stone with a large round white clock face framed in gold, a tiered dark slate spire roof with small gold details, and to its left a lower, long Gothic hall with pointed windows and small turrets. The clock tower stands at about 55% to 68% of the image width with its tip at about 3% from the top; the hall spans from about 16% to 55% of the width and is about a third as tall.",
               "the spire roof and the top of the tower are broken off, the clock face is cracked with its hands hanging, the hall roof has collapsed in places."),
    "amsterdam": ("a pale row of tall narrow Dutch canal houses with stepped gables and a small church tower.",
                  "a canal as a band of blue water just below the horizon, a small arched brick bridge over it in the middle distance, then green meadow with a pale brick path to the bottom, rows of red, yellow and orange tulips near the left and right edges, and a wooden fence.",
                  "a traditional DUTCH WINDMILL: a stout octagonal tower with a brick base and a dark thatched upper body, a wooden gallery balcony around its middle, a rounded cap on top, and four big lattice sails with cream cloth forming an X in front. It spans from about 24% to 76% of the image width including the sails; the top sail tip is at about 4% from the top.",
                  "two sails are broken off and the others are torn, the cap is half collapsed, the gallery is broken, holes in the walls."),
    "newyork": ("a pale skyline of Manhattan skyscrapers across the horizon with one pointed Art Deco tower.",
                "New York harbor as a band of blue water below the horizon across the full width, then a small grassy island lawn with a pale star-shaped stone terrace path to the bottom, low round bushes, old-fashioned lamp posts and a few benches near the edges.",
                "the STATUE OF LIBERTY in New York: a robed figure in soft verdigris teal-blue (blue-leaning teal, not green) holding a golden torch high in the right hand and a tablet in the left arm, wearing a seven-ray crown, with a very simple, calm, stylized face (two small closed-eye arcs and a tiny smile), standing on a tall stepped granite pedestal on a low star-shaped stone base. It spans from about 30% to 70% of the image width; the torch tip is at about 3% from the top.",
                "the torch arm is broken off at the elbow, several crown rays are missing, the robe is cracked, the pedestal has missing blocks."),
    "sanfrancisco": ("pale rounded hills of the Marin headlands on the right and a pale city skyline with a pointed pyramid tower on the left, with a soft band of white fog along the horizon.",
                     "San Francisco Bay as a wide band of blue water below the horizon, then a grassy headland with a pale path to the bottom, orange California poppies, low bushes and a wooden fence near the left and right edges.",
                     "the GOLDEN GATE BRIDGE seen from the side: a long suspension bridge in international orange-red with two tall Art Deco towers (each with four cross braces), two big main cables sweeping in curves from tower to tower and down to both ends, many thin vertical suspender cables, and a straight road deck. The whole bridge spans from about 3% to 97% of the image width; the towers stand at about 28% and 72% of the width with their tops at about 8% from the top; the deck is at about 62% from the top and the tower legs go down to 86%.",
                     "one tower top is broken, the main cables are snapped and hanging, the middle of the deck has collapsed, leaving a gap."),
    "washington": ("a pale skyline with a tall thin obelisk on the left and rows of cherry trees in soft cream-white blossom.",
                   "a long rectangular reflecting pool of blue water running from the bottom center toward the horizon center, green lawns on both sides, pale paths, round trees and flower beds in red, white and blue near the left and right edges.",
                   "the UNITED STATES CAPITOL in Washington: a wide white neoclassical building with a central columned portico and broad steps, two long wings with columns, and a big tall white dome on a columned drum, topped with a small lantern and a tiny bronze statue. It spans from about 8% to 92% of the image width; the top of the dome is at about 5% from the top.",
                   "the dome is cracked open with half of it fallen, columns are broken on both wings, the steps are cracked."),
    "rio": ("pale rounded granite peaks (including the Sugarloaf shape) rising from a blue bay with a strip of pale beach and tiny city buildings.",
            "a mountain-top terrace of pale stone with a balustrade and steps to the bottom, lush tropical bushes, palm fronds and bright orange and yellow flowers near the left and right edges, two small colorful toucans sitting on the balustrade.",
            "the CHRIST THE REDEEMER statue of Rio de Janeiro: a tall pale soapstone figure in a long robe with both arms stretched straight out to the sides, with a very simple, calm, stylized face (two small closed-eye arcs), standing on a square dark stone pedestal on a small rocky peak. The arms span from about 22% to 78% of the image width; the head top is at about 5% from the top.",
            "one arm is broken off at the elbow, the other hand is missing, the robe is cracked, the pedestal has missing blocks."),
    "buenosaires": ("a pale skyline of Buenos Aires with elegant old buildings, a few domes and jacaranda trees in soft blue-violet bloom.",
                    "a very wide avenue plaza of pale paving with a round plaza in the middle, green lawn islands, flower beds in sky blue and white, old-fashioned street lamps and jacaranda trees near the left and right edges.",
                    "the OBELISCO of Buenos Aires on its plaza: a tall, slender, four-sided white stone obelisk with a pointed pyramid tip and a small window near the top, standing on a low round stepped base, flanked by two elegant low Belle-Epoque buildings with cream walls, dark slate mansard roofs and small domes (one on each side, each about a third as tall as the obelisk). The group spans from about 14% to 86% of the image width; the obelisk tip is at about 3% from the top.",
                    "the top third of the obelisk is broken off, cracks run down it, the side buildings have collapsed roofs and broken walls."),
    "easterisland": ("the deep blue Pacific ocean horizon with a pale extinct volcano cone on the right.",
                     "a grassy coastal slope with a pale dirt path to the bottom, low dry-stone walls, tufts of golden grass, a few dark volcanic boulders and small red flowers near the left and right edges, and a strip of ocean with white surf at the far right.",
                     "the MOAI of Easter Island: a row of five giant stone head-and-torso statues of dark gray-brown volcanic rock standing side by side on one long low stone platform (ahu), of slightly different heights, the tallest in the middle; each has a long simple face with a heavy brow, a long nose and a thin straight mouth, drawn very simply and a little cute; the middle one and one other wear a round red-brown stone topknot (pukao), and the middle one has white coral eyes. The row spans from about 12% to 88% of the image width; the top of the tallest topknot is at about 8% from the top.",
                     "two statues have fallen over and lie broken on the platform, the topknots have rolled off, the others are cracked and chipped."),
    "sydney": ("a pale skyline of Sydney towers on the left and a pale steel arch bridge (the Harbour Bridge) on the right.",
               "Sydney Harbour as a band of bright blue water below the horizon across the full width, then a pale stone waterfront promenade to the bottom, green lawn at the sides, palm trees and red bottlebrush flowers near the left and right edges, and a few white harbor lamps.",
               "the SYDNEY OPERA HOUSE seen from the front-side: three groups of big, glossy, white-cream sail-shaped shell roofs (the largest group on the right, a slightly smaller one in the middle-left, a small one in front on the far left), with dark navy glass walls in their openings, all standing on a wide low podium of pinkish-beige stone with broad steps. It spans from about 6% to 94% of the image width; the top of the tallest shell is at about 12% from the top.",
               "several shells are cracked and broken with big pieces missing, the glass walls are shattered, the podium steps are cracked."),
    "auckland": ("a pale skyline of Auckland with low towers, and a pale green extinct volcano cone (Rangitoto) across a strip of blue sea on the right.",
                 "a harbor: a band of blue water below the horizon with two tiny white sailboats without any text, then a wooden wharf promenade to the bottom, green lawn at the sides, tree ferns and red pohutukawa flowers near the left and right edges.",
                 "the SKY TOWER of Auckland: a tall, slender concrete tower shaft in pale gray, with a large round multi-level observation pod near the top (dark navy windows, white rings, a thin band of light blue), a narrower section above it and a long thin red-and-white mast, standing on a wide low base building with dark navy glass. To the left and right of the base, two modern low buildings about a quarter as tall. The group spans from about 24% to 76% of the image width; the mast tip is at about 2% from the top.",
                 "the mast and the top section are broken off, the pod is tilted and cracked open, the shaft has big chunks missing."),
    "antarctica": ("a range of pale icy mountains and a glacier under a soft sky; no trees at all.",
                   "white snow field with soft blue shadows and gentle drifts, a packed-snow path to the horizon center, turquoise-blue ice blocks, a few colorful marker flags without any text, and four small cute penguins (black and white, simple) standing near the left and right edges.",
                   "an ANTARCTIC RESEARCH STATION: a long row of four connected, rounded, bright red and orange module buildings raised above the snow on chunky steel legs, with round dark navy porthole windows, white stripes, a staircase at one end, a white satellite dome and a dish antenna on the roof, a tall thin weather mast with a small wind gauge, and a chunky orange tracked snow vehicle parked at the lower right. It spans from about 8% to 92% of the image width; the mast tip is at about 10% from the top.",
                   "two modules are crushed and tilted off their legs, the dome is cracked open, the mast is snapped, the dish has fallen, the vehicle is overturned."),
}


def codex(prompt, images):
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write"]
    for image in images:
        args += ["-i", image]
    subprocess.run(args + ["-"], input=prompt.encode(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def background(city):
    far, ground, _, _ = CITIES[city]
    out = f"{I}/{city}_bg_restored_v2.png"
    if not os.path.exists(out):
        codex(f"""Use your built-in image generation tool to create ONE image and save it as a PNG at {out} (1536x1024, landscape). Do not modify any other file.
The attached image is a background scene from a casual puzzle game (the scenery behind a landmark). Create the same kind of BACKGROUND SCENERY for another place, in exactly the same cute toy-like art style, the same flat front camera and the same structure. No landmark is drawn in the middle: it will be added later as a separate layer, so keep the center of the picture (25%-75% of the width) free of tall objects.
- Horizon: the ground line is at exactly the same height as in the reference (about 66% from the top), straight across the full width.
- Sky (top): the same bright candy blue with a soft lighter gradient toward the horizon, the same yellow sun in the upper right, and four or five puffy white toy clouds near the left and right sides.
- Distant scenery (a band sitting on the horizon, from about 52% to 66%, pale, hazy, low-contrast, clearly far away): {far}
- Below the horizon (66%-100%): {ground}
No people, no vehicles, no flags with symbols, no text. {STYLE}""", [f"{I}/cairo_bg_restored_v2.png"])
    ruined = f"{I}/{city}_bg_ruined_v2.png"
    if os.path.exists(out) and not os.path.exists(ruined):
        codex(f"""Use your built-in image generation tool to EDIT the FIRST attached image and save the result as a PNG at {ruined} (1536x1024). Do not modify any other file.
The first image is a background scene (sky, distant scenery, ground). The second image is only a reference for the look of a ruined background in this game (dark purple-gray overcast sky with heavy dark clouds, dark broken silhouettes in the distance, lifeless dark ground, dead trees).
Produce the RUINED version of the first image with exactly the same composition and the horizon at exactly the same height:
- Sky: flat dull dark purple-gray overcast with heavy darker clouds in the same places as the white clouds, no sun.
- Distant scenery: the same shapes in the same places but as dark gray-purple, broken, lifeless silhouettes.
- Ground: dull gray-brown and lifeless; any water dark and murky; paths cracked and darker; plants reduced to bare twigs and stumps; a few gray boulders and broken pieces. Any animals are removed.
Keep the same cute, rounded, toy-like rendering with smooth shading. No slime, no pink, no fire, no text.""", [out, f"{I}/cairo_bg_ruined_v2.png"])


def building(city):
    _, _, what, ruin = CITIES[city]
    out = f"{I}/{city}_building_restored_v2.png"
    if not os.path.exists(out):
        codex(f"""Use your built-in image generation tool to create ONE image and save it as a PNG at {out} (1536x1024, landscape). Do not modify any other file.
The attached image shows how a landmark of a casual puzzle game is drawn: big, rich in detail, chunky toy-like 3D, on a plain chroma background. Use it as the example for style, level of detail, rendering and background.
Draw this landmark in exactly that cute toy-like art style and flat straight-front view, on a plain chroma background: {what}
- Background: one flat, solid, pure green color (#00FF00) everywhere, including every opening and gap you can see through. No sky, no ground, no trees, no water, no sun, no shadow on the ground, no glow.
- It is horizontally centered and its base sits at exactly 86% from the top of the image; nothing is drawn below 88%.
- Rich but chunky detail: two-tone shading, bright rim light, soft white glossy highlights on the upper left, smooth gradients, thin smooth outline in a darker shade of each part's own color (never pure black).
- IMPORTANT: do not use green or yellow-green anywhere on it. No people, no flags, no logos, no text, no inscriptions.""", [f"{I}/cairo_building_restored_v2.png"])
    ruined = f"{I}/{city}_building_ruined_v2.png"
    if os.path.exists(out) and not os.path.exists(ruined):
        codex(f"""Use your built-in image generation tool to EDIT the FIRST attached image and save the result as a PNG at {ruined} (1536x1024). Do not modify any other file.
The first image shows a landmark on a flat pure green (#00FF00) chroma background. The second image is only a reference for how a ruined landmark looks in this game (dull gray-brown cracked surfaces, broken top, fallen blocks) on the same chroma background.
Produce the RUINED version of the first image: the background stays exactly the same flat pure green (#00FF00) everywhere; the landmark stays in exactly the same position and size, with the same footprint at its base. Changes to the landmark only:
- All surfaces turned dull gray-brown, cracked and lifeless; all bright colors and gold gone; windows dark and broken.
- {ruin}
- Piles of fallen blocks at its foot (nothing below 90% of the image height).
Keep the same cute, rounded, toy-like rendering with smooth shading. No slime, no pink, no fire, no text, and no green on the landmark.""", [out, f"{I}/cairo_building_ruined_v2.png"])


if __name__ == "__main__":
    cities = sys.argv[1:] or list(CITIES)
    with ThreadPoolExecutor(max_workers=8) as pool:
        for city in cities:
            pool.submit(background, city)
            pool.submit(building, city)
