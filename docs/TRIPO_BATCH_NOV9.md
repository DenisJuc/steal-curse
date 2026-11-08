# Tripo batch, Nov 9 credit reset: the last 40 relic models

52 of 92 relics have a model in `assets/RelicModels`. These 40 don't (checked against
`RelicConfig` on 2026-11-07). Spending credits needs Rosselle's OK first.

## Settings (same as every earlier batch)
- Tripo website (credits are on the website account; the API key has 0), **Text to 3D**, model **H3.0**.
- Style **Cartoon/Stylized**, textured, about **9k triangles** (Roblox limit 20k; lower is better on phones). Never mix presets inside the batch.
- Every prompt ends with the fixed style line:
  `single object, stylized low-poly game asset, clean hand-painted texture, no base, no text`
- Blades, staffs and other thin objects already carry `thick blade, oversized hilt, chunky silhouette` in their description (thin meshes read badly at Roblox camera distance).
- No logos, lettering or official emblems (ROSTER naming rule).
- Download **GLB**.

## Pipeline per model (on the PC)
1. Download the GLB, then `python work/models/tripo/grab.py <RelicId>` (copies the newest complete GLB from Downloads).
2. `tools/models/blender/prep_tripo_glb.py` (normalize, export FBX + maps), then `python -I tools/models/upload_model.py <fbx> <RelicId>` (writes `assets/RelicModels/<RelicId>.rbxmx`).
3. In Studio: `/modelcheck`, then compare it on a shelf next to two existing relics (same lighting) before accepting.

## Step 1: test 2 first
- `HoyPoyCapsule` (Common, small round object, the most-seen tier)
- `ThunderNichirenBlade` (Uncommon, thin blade: the style's weak spot)

If both sit well next to the existing models (size, saturation, edge wear), run the rest in order below. If not, change the prompt ending once, re-test the same two, and keep that ending for all 40.

Credit cost: check the balance after the 2 tests and multiply. Earlier estimate in this project: about 40 credits per model (the throne remodel), so 40 relics would be about 1,600 if that holds. Not verified.

## The 40 prompts (Common first: seen most often)

| # | Relic id | Shown as | Tier | Prompt (add the style line) |
|---|---|---|---|---|
| 1 | `HoyPoyCapsule` | Pocket House Capsule | Common | a small white pill-shaped capsule with a round push button on top and a stamped number on the side, chunky rounded shape |
| 2 | `WistariaPoisonVial` | Wisteria Poison Vial | Common | a corked glass vial of glowing lilac liquid with a small purple wisteria sprig tied to the neck with string |
| 3 | `HuntarLicense` | Hunter License | Common | a thick stiff card with a large abstract round emblem and a dark magnetic strip, slightly bent corner |
| 4 | `AkatsukoRing` | Red Dawn Ring | Common | a dark iron ring with one large flat round stone carved with a single abstract symbol, chunky band |
| 5 | `MagickStone` | Kingdom Magic Stone | Common | a faceted glowing blue gem chunk with small rune marks floating around it, rough rocky base edge |
| 6 | `ExplodingTag` | Exploding Tag | Uncommon | a long paper talisman tag with a big red seal mark, one end burnt and smoldering with orange embers |
| 7 | `EternalPoze` | Eternal Island Compass | Uncommon | an hourglass-shaped glass compass held in a carved wooden frame, a floating red needle inside the glass |
| 8 | `StoneMasque` | Vampire Stone Mask | Uncommon | a grey stone face mask with a calm carved face and short bone spikes along the top rim |
| 9 | `Skouter` | Power Scouter | Uncommon | a one-eye headset device with a curved ear piece and a tinted green glass lens, chunky sci-fi shape |
| 10 | `DragunRadar` | Wish Orb Radar | Uncommon | a round handheld radar device with a white casing, a green grid screen with small glowing dots, a button on top |
| 11 | `TriLeafGrimoire` | Three-Leaf Grimoire | Uncommon | a thick closed spellbook, worn brown leather cover with a raised green three-leaf clover emblem, metal corner caps |
| 12 | `GreedyIslandBook` | Greed Game Binder | Uncommon | a thick card binder with a dark cover and rows of glowing card slots, most slots empty, a few cards inside |
| 13 | `Zangetzu` | Crescent Moon Cleaver | Uncommon | a huge guardless cleaver sword, wide straight black blade with a silver edge, long hilt wrapped in white cloth with a trailing cloth strip, thick blade, oversized hilt, chunky silhouette |
| 14 | `PowaPole` | Growing Power Pole | Uncommon | a red staff with thick gold end caps, chunky silhouette |
| 15 | `ThunderNichirenBlade` | Thunder Sun-Steel Blade | Uncommon | a katana with a yellow zig-zag lightning pattern along a dark blade, square guard, wrapped hilt, thick blade, oversized hilt, chunky silhouette |
| 16 | `SerratedTwinBlades` | Serrated Twin Blades | Uncommon | two short wide serrated cleavers joined by a short iron chain, thick blades, chunky silhouette |
| 17 | `HolloBait` | Hollow Lure | Rare | a small round pill-shaped lure, cracked open, leaking purple haze, dark shell |
| 18 | `BlackenedRope` | Blackened Rope | Rare | a coil of thick black braided rope, one frayed end trailing dark wisps, chunky silhouette |
| 19 | `DeosDiary` | Vampire's Heaven Diary | Rare | a small closed leather diary with a gold clasp and a red ribbon bookmark hanging out |
| 20 | `LokakakaFruit` | Wound-Swap Fruit | Rare | a lumpy fruit with grey stone-like patches on its skin, short twig stem with one leaf |
| 21 | `RiskieDice` | Risky Dice | Rare | a large twenty-sided die, dark purple, one face marked with a small skull, chunky shape |
| 22 | `Samehadu` | Shark-Skin Greatsword | Rare | a thick club-shaped greatsword covered in blue shark-skin scales, partly wrapped in bandages, chunky silhouette |
| 23 | `Zabimara` | Snake-Tail Blade | Rare | a segmented whip-sword held in an S-shaped snake curve, red hilt, thick blade segments, chunky silhouette |
| 24 | `Benihima` | Crimson Princess Cane | Rare | a black walking cane with a hidden blade half-drawn from it and a red tassel at the handle, thick blade, chunky silhouette |
| 25 | `FlameNichirenBlade` | Flame Sun-Steel Blade | Rare | a katana with a flame-shaped guard and a red-orange blade, wrapped hilt, thick blade, oversized hilt, chunky silhouette |
| 26 | `InsectNichirenBlade` | Insect Sun-Steel Blade | Rare | a needle-like stinger sword with a butterfly-shaped guard, purple and green, oversized hilt, chunky guard |
| 27 | `DemonDwellingSword` | Demon-Dwelling Sword | Rare | a black katana with dark smoky edges on the blade, plain guard, thick blade, oversized hilt, chunky silhouette |
| 28 | `QuadLeafGrimoire` | Four-Leaf Grimoire | Epic | a thick closed spellbook, dark green leather cover with a raised golden four-leaf clover emblem, gold corner caps, cream page edges |
| 29 | `Senbonsakura` | Thousand Petal Blade | Epic | a katana hilt with no blade, a swirling cloud of small pink petal-shaped blades floating where the blade would be |
| 30 | `StendDisc` | Mysterious Disc | Epic | a shiny iridescent disc, rainbow sheen, a faint figure reflected in its surface, thick rim |
| 31 | `JudgementChain` | Judgement Chain | Epic | a heavy chain hanging from a ring, a small blade-tipped weight at the end, thick links |
| 32 | `OniSpineNaginata` | Oni-Spine Naginata | Epic | a naginata whose shaft is a pale segmented bone spine, curved dark blade, thick blade, chunky silhouette |
| 33 | `MadorasGunbai` | Reflecting War Fan | Epic | a large round war fan on a long handle, red and white, three comma-shaped marks in the center, chunky silhouette |
| 34 | `Hyorinmara` | Ice Dragon Blade | Epic | a katana with a star-shaped guard and a small ice dragon coiling around the blade, pale blue, thick blade, oversized hilt, chunky silhouette |
| 35 | `PotoraEarrings` | Fusion Earrings | Epic | a pair of earrings, each with a round green-yellow gem on a short gold hook, chunky shapes |
| 36 | `DemonSlayingSword` | Demon-Slaying Sword | Epic | a huge rough chipped greatsword, dark iron, cracks along the blade, thick blade, chunky silhouette |
| 37 | `StaffOfJudgement` | Staff of Judgement | Epic | a tall staff topped with a small balance scale, gold and dark wood, chunky silhouette |
| 38 | `DemonSlashingKatana` | Demon-Slashing Katana | Epic | a black katana with a jagged saw-tooth edge and grey smoke wisps, thick blade, oversized hilt, chunky silhouette |
| 39 | `FourStarDragunBall` | Four-Star Wish Orb | Legendary | a glossy orange glass sphere with four red five-pointed stars floating inside |
| 40 | `SuperDragunBall` | Planet Wish Orb | Celestial | a large glossy amber glass sphere with one big glowing star inside, faint swirling clouds in the glass |

## After the batch
- `/modelcheck all` should show 0 relics waiting.
- Re-run the per-relic aura check (every modelled relic gets its own aura, escalating by tier) for the 40 new ones.
- Update `docs/MODEL_BACKLOG.md` to "92/92".
