# Map props to generate in Tripo

28 models to go (StoneLantern is done). Text prompts only. Each prompt below is ready to paste
as-is: it already ends with the shared style suffix.

## Tripo settings (same for every model)


| Setting            | Value                                       |
| ------------------ | ------------------------------------------- |
| Ultra Mesh Quality | Off (turn on only if a result looks blobby) |
| Texture            | On, 2K                                      |
| Remove Lighting    | On                                          |
| PBR                | On                                          |
| Topology           | Triangle                                    |
| Polycount          | the number listed for each model            |
| Generate in Parts  | Off                                         |
| 8K Texture         | Off                                         |
| T-Pose             | Off                                         |
| AI Model           | H3.1 – Best Quality                         |


Download as **FBX**.

## Adding each model

1. Studio: Home > Import 3D > pick the FBX > Import (default settings).
2. Rename the top item in the Explorer to the exact **File name** below (capitals matter).
3. Right-click > Save to File... > `C:\steal-curse\assets\MapProps\<File name>.rbxm`.
4. Delete the copy in Workspace.
5. `rojo serve` picks new files up by itself. If a model looks grey or untextured, run
  `rojo build -o build/RelicCollector.rbxl`, open that file and connect again.

The game scales each model to the listed **height** and stands it on the ground. You never resize
anything. Glow lights are added by the game for the props marked "light", so the model doesn't
need to emit light (glowing colors in the texture still help).

Fixes, as attributes on the top item **before** saving (Properties > Attributes > +):

- `DisplayScale` (number): `1.2` = 20% bigger.
- `DisplayRotation` (Vector3, degrees): `0, 90, 0` or `0, 180, 0` if it faces the wrong way.

Check with `/modelcheck` in Play. Output lists `map props imported N/29` and anything still
missing or wrongly named.

## Suggested order

1. Finish the pilot: DeadTree1, BrokenPillar1.
2. Shrine town (seen first by every player).
3. One area at a time: Forest, Village, Ruins.
4. Shared props last.

---

## Done

- [x] **StoneLantern** | height 7 | polycount 3000 | hub lanterns, light

## Pilot (2 left)

- [x] **DeadTree1** | height 22 | polycount 3000 | forest, scattered many times
  `tall twisted dead tree, leafless, dark grey-brown bark, long crooked branches reaching up and out, no leaves, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **BrokenPillar1** | height 13 | polycount 2000 | ruins, scattered
  `tall broken ancient stone column, fluted pale limestone, snapped jagged top, cracks and chipped edges, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

## Shrine town (7)

- [x] **ShrineGate** | height 18 | polycount 5000 | one where each path leaves town (3 copies)
  `Japanese torii shrine gate, two thick round red lacquered pillars with black feet, a curved black top beam with upturned ends, a straight red lower crossbeam, a small blank wooden plaque between the beams, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **HubTemple** | height 40 | polycount 8000 | landmark in the hub center (replaces the obelisk), light
  `two-tier Japanese pagoda shrine, dark red wooden walls and pillars, two stacked curved dark grey tile roofs with upturned corners, a golden spire on top, short stone steps at the front, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **RelicPedestal** | height 4.6 | polycount 1500 | 48 copies on the plots, keep it light
  `short wide carved stone relic pedestal, round column with a flat top for displaying an item, a ring of glowing purple runes carved around the side, dark grey stone, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **SpiritResonator** | height 14 | polycount 4000 | one per plot, light
  `mystical ritual device, a brass tripod frame holding a large floating purple crystal, thin brass rings circling the crystal, dark stone foot, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **CodexLectern** | height 6 | polycount 3000 | beside the Codex kiosk
  `wooden book stand lectern with a slanted top, a large open ancient tome floating just above it with softly glowing golden pages, dark carved wood, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **RuneMonolith** | height 12 | polycount 3000 | beside the Skills kiosk, light
  `tall flat standing stone slab, dark slate, glowing purple runes carved in a branching tree pattern on the front face, slightly rough edges, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **OfferingBox** | height 3.6 | polycount 1500 | beside the Luck kiosk
  `small Japanese wooden offering box, slatted wooden top, red lacquered trim, small gold metal corners, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

## Haunted Forest (5)

- [x] **DeadTree2** | height 18 | polycount 3000 | scattered
  `short wide gnarled dead tree, leafless, thick bent trunk leaning slightly, a few broken branches, exposed roots, dark bark, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **AncientTree** | height 60 | polycount 8000 | forest landmark
  `huge ancient gnarled tree, massive twisted trunk with thick exposed roots, dark green leafy canopy, a thick straw rope with white zigzag paper streamers tied around the trunk, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **MossyRocks** | height 5 | polycount 1500 | scattered
  `cluster of three rounded grey boulders of different sizes, patches of green moss on top, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **GlowMushrooms** | height 2.5 | polycount 1500 | scattered, light
  `cluster of five small fantasy mushrooms of different heights, glowing cyan-teal caps with pale spots, thin white stems, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **JizoStatue** | height 4 | polycount 2000 | forest statues
  `small Japanese Jizo stone statue, simple round-headed monk figure with hands pressed together, red cloth bib around the neck, weathered grey stone, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

## Abandoned Village (6)

- [x] **RuinedHouse** | height 16 | polycount 6000 | 6 copies
  `small abandoned Japanese wooden house, partly collapsed, broken dark tile roof with a hole, weathered wooden plank walls, a broken sliding door, a boarded-up window, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **RuinedHut** | height 11 | polycount 4000 | 4 copies
  `small abandoned wooden hut, sagging thatched straw roof, weathered plank walls, a dark open doorway, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **OldWell** | height 8 | polycount 2500 | village center
  `old stone water well, round cobblestone ring, two wooden posts holding a small tiled roof, a wooden bucket hanging on a rope, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **BrokenCart** | height 5 | polycount 2500
  `broken wooden hand cart, two large wooden wheels with one cracked, tilted cart bed with a few planks missing, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **CrateBarrelPile** | height 7 | polycount 2000 | scattered
  `pile of old wooden crates and two barrels stacked together, weathered wood with dark iron bands, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **BellTower** | height 34 | polycount 6000 | village landmark, light
  `tall wooden watchtower on four long legs with cross braces, a small platform on top with a bronze temple bell hanging under a small tiled roof, a ladder up one side, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

## Ancient Ruins (4)

- [x] **BrokenPillar2** | height 7 | polycount 2000 | scattered
  `short broken ancient stone column stump, fluted pale limestone, jagged broken top, a small chunk of rubble beside it, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **RuinArch** | height 18 | polycount 4000 | 3 copies
  `crumbling ancient stone archway, two thick pillars joined by a rounded arch, missing stones and cracks, pale weathered limestone with moss, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **GuardianStatueHead** | height 16 | polycount 8000 | ruins landmark (tilted 70 degrees to face the sky)
  `giant ancient stone guardian statue head, stern face with closed eyes, cut off flat at the neck, cracked pale stone with moss and hanging vines, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **RuneObelisk** | height 16 | polycount 2500 | 4 copies, light
  `tall narrow four-sided stone obelisk with a pointed top, dark basalt, glowing violet runes carved down each face, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

## Shared / blend zones (4)

- [x] **FernBush** | height 3 | polycount 1500 | scattered everywhere (walk-through)
  `lush fern bush, many long green fern fronds spreading out from the center, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **WoodenBridge** | length 26 | polycount 4000 | 6 copies over the stream
  `long flat wooden footbridge, straight plank deck, low simple wooden railings on both sides, very slightly arched, much longer than wide, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`
  Note: scaled by its length (26 studs) and turned across the stream automatically; an invisible walkway makes it walkable.

- [x] **Signpost** | height 9 | polycount 1500 | 3 copies (the game adds the area name above it)
  `wooden signpost, one tall post with three blank wooden arrow boards pointing in different directions, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

- [x] **FallenLog** | length 16 (scaled by length) | polycount 2000 | scattered
  `fallen tree log lying on its side, long, cracked bark, broken ends, patches of moss, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

---

The game scales every model by height only, so wide or long props (bridge, fallen log, arch) can
come out too short or too long; `DisplayScale` fixes that. If a model fights you after 2-3 tries,
we switch that one to an image prompt.

When everything is added, run `/modelcheck` (it should say 29/29) and `/mapstats`, then send
screenshots of the hub, each area and the bridges.