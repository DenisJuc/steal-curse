# Slice 8b: Meshy pilot (5 relics)

Goal: take 5 relics from Meshy into the game, check how they look and perform, and lock the art
style before making the other 87. One relic per object type, so every capture animation family
gets tested.

| Relic id (file name) | Name | Tier | Type |
| --- | --- | --- | --- |
| `Zangetzu` | Zangetzu | Uncommon | Weapon |
| `QuadLeafGrimoire` | Quad-Leaf Grimoire | Epic | Book |
| `HolloMask` | Hollo Mask | Mythic | Mask |
| `FourStarDragunBall` | Four-Star Dragun Ball | Legendary | Crystal |
| `GumoGumoFruit` | Gumo Gumo Fruit | Epic | Special (fruit) |

## 1. Generate in Meshy

Use **Text to 3D** with these settings:
- Art style **Cartoon/Stylized** (not realistic). Keep the same choice for all five.
- Target polycount about **5,000 triangles**. Roblox's limit is 20,000 per mesh, and lower is better on phones.
- Texture **on**. PBR maps are optional, because the base color is what matters.
- If Meshy asks about symmetry or a pose, pick **auto** or **on**.

Prompts (paste one at a time). The ending is the same each time, so the style stays consistent:

- **Zangetzu:** `a huge guardless cleaver sword, wide straight black blade with a silver edge, long hilt wrapped in white cloth with a trailing cloth strip, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`
- **Quad-Leaf Grimoire:** `a thick closed spellbook, dark green leather cover with a raised golden four-leaf clover emblem, gold corner caps, cream page edges, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`
- **Hollo Mask:** `a white bone demon mask covering the whole face, dark empty eye holes, red stripes over one side, sharp teeth carved along the mouth, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`
- **Four-Star Dragun Ball:** `a glossy orange glass sphere with four red five-pointed stars floating inside, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`
- **Gumo Gumo Fruit:** `a round purple fruit covered in swirling curly line patterns, short curly green stem on top, single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`

Generate a few times if needed and keep the one with the clearest silhouette. Download each one
as **FBX** (or GLB).

## 2. Import into Roblox Studio

Do this once per relic:

1. Open the game in Studio (you must be logged in, because Studio uploads the mesh to your account).
2. **Home** tab > **Import 3D** (or File > Import 3D). Pick the downloaded file and click
   **Import** with the default settings.
3. The model appears in **Workspace**. In the Explorer, **rename the top item** to the exact relic
   id from the table, e.g. `Zangetzu`. Spelling and capitals matter.
4. Right-click it > **Save to File...** and save it in `C:\steal-curse\assets\RelicModels\` as
   `Zangetzu.rbxm` (file name = relic id).
5. Delete the copy in Workspace. The game loads it from the file through Rojo.

The game uses only the **first part** of each model and scales it automatically to the same size
as the old placeholder shape. You don't need to resize anything.

Optional fixes, set as attributes on the top item **before** step 4 (Properties > Attributes > +):
- `DisplayScale` (number): e.g. `1.3` makes it 30% bigger.
- `DisplayRotation` (Vector3, degrees): e.g. `0, 90, 0` turns it to face forward.

## 3. Sync and check

1. `default.project.json` changed in this slice (new RelicModels folder), so **stop `rojo serve`
   (Ctrl+C), start it again, and click Connect** in Studio. New `.rbxm` files sync on their own
   after that.
2. If a model looks like a plain grey block or has no texture while syncing, run
   `rojo build -o build/RelicCollector.rbxl` and open that file instead, then connect again.
3. Press **Play** and type `/modelcheck`. A row of stands appears in front of you, one per
   imported model. Each label shows **ok** or the first warning; the full list is in Output.
   `/modelcheck all` also shows the 87 relics still waiting for a model, and `/modelcheck clear`
   removes the row.

## 4. What to look at

- **Pedestal:** `/give Zangetzu`, then Relics menu > select it > **Equip**. Is it readable from
  a few steps away? Is the size right next to the other placeholders?
- **Reveal:** `/forceroll HolloMask`. Check the turning model in the reveal card, then the
  glowing silhouette that floats above your head.
- **Carry:** Relics menu > select it > **Carry**, then **Hold**. Check it floating and in your hand.
- **Phone:** Test tab > Device, pick a phone, and repeat `/modelcheck`. It should still run
  smoothly.

Then tell me: is the style right (keep, or change the prompt ending)? Do any need `DisplayScale`
or `DisplayRotation` fixes? Are any too detailed or too plain? Once the style is approved, 8c
does the other 87 the same way.
