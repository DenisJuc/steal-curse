# Relic model review (2026-11-10)

All 99 relic models were photographed up close in Studio (3 at a time, the way they face on a pedestal)
and judged harshly. Question asked of every model: does it clearly look like that anime item, in a clean
Roblox-cartoon style?

**Owner's call (Nov 10): 24 get a new model, 6 are kept for now and judged again on the final
sweep, 69 pass.** Tengen's cleavers was renamed Inosuke's Nichirin Blades (that's what the model
shows) and Enma was renamed Zoro's Three Swords, so neither needs a new model.

Original review: 31 fail, 68 pass. The fail list lives in code at `src/shared/ModelReview.luau`; every relic not in
it counts as approved. In Studio, `/modelreview` puts the failing ones on spinning stands on a lit
platform above you (walk up to a stand to read why it failed), `/modelreview later` shows the 6 kept for the
final sweep, `/modelreview all` shows all 99 (redo red, later amber), `/modelreview clear` removes them and takes you back.

## Redo: needs a new model (6, owner's Nov 11 review)

| Relic | Why |
|---|---|
| Shinobu's Nichirin Blade | old model is broken; new concept approved |
| Yoru | blade too small next to the guard; Tripo free retry on the existing job |
| Death Painting Womb | solid jar read poorly; new no-jar concept approved |
| Tobi's Mask (id ScarlettEyes) | swapped from Scarlet Eyes; needs its model |
| Tengen's Nichirin Cleavers (new) | new relic, no model yet |

Also fixed by display turn only (`RelicModels.DisplayTurn`): Nobara's hammer flipped, Three-Leaf Grimoire
and DIO's Diary stood up, 10 swords/rods tilted onto a diagonal.

### Nov 11 batch

**Nov 11:** all 24 were remade from the owner-approved concepts (`work/models/concepts_redo/`, sheet
`concepts_redo_24_v2.jpg`) with Tripo image-to-3D H3.0 (960 credits, job ids in
`work/models/tripo/jobs_nov11.txt`) and checked in Studio. Contact sheet: `research_shots/models_nov11/`.
The Redo list is empty; put an id back in `ModelReview.Redo` (with a row here) if a model fails review.

Still weaker than the rest (glass jars: Tripo bakes whatever is behind the glass into a blur):
Scarlet Eyes (eye reads as a red glow, not a sharp eye) and Death Painting Womb (the foetus is a soft
purple shape). Demon-Dweller lost the red flame streaks on the blade.
Yoru's blade came out shorter than Mihawk's, so it looks small next to the other swords. Quincy
Medallion's mesh is tilted 30 degrees, fixed with a `DisplayRotation` attribute (-30, 0, 0) in its .rbxmx.
Fronts face -Z like every other Tripo model (the review stands turn them 180 degrees).

## Later: kept for now, judged again on the final sweep (6)

In code as `ModelReview.Later`.

| Tier | Relic | Why it was flagged |
|---|---|---|
| Common | Quincy Bangle | rough stone band with a plain cross, realistic |
| Common | Fox Mask | realistic weathered wolf head, not a clean flat fox mask |
| Uncommon | Suna Suna Fruit | odd lumps stick out like handles |
| Epic | Four-Leaf Grimoire | plain dark green book, no clover |
| Mythic | Sukuna's Finger | red sausage with a bandage |
| Celestial | Kamutoke | odd dagger-staff |

## Pass (69)

Gon's Fishing Rod, Kunai, Vivre Card, Sealing Scroll, Wisteria Poison, Hunter License, Nobara's Hammer
& Nails, Akatsuki Ring, Leaf Village Headband, Inosuke's Boar Mask, Nezuko's Bamboo Muzzle, Explosive
Tag, Eternal Pose, Yuta's Ring, Stone Mask, Scouter, Dragon Radar, Three-Leaf Grimoire, Killua's
Yo-yos, Bara Bara Fruit, Hana Hana Fruit, Zangetsu, Power Pole, Zenitsu's Nichirin Blade, Substitute
Soul Reaper Badge, Gojo's Blindfold, DIO's Diary, Rokakaka, Hie Hie Fruit, Mochi Mochi Fruit, Hisoka's
Cards, Samehada, Zabimaru, Benihime, Rengoku's Nichirin Blade, Shinobu's Nichirin Blade, Playful
Cloud, Jotaro's Cap, Mera Mera Fruit, Gomu Gomu Fruit, Stand Disc, Judgment Chain, Gaara's Gourd,
Hyorinmaru, Potara Earrings, Nezuko's Box, Demon-Slasher Katana, Stand Arrow, Split Soul Katana,
Four-Star Dragon Ball, Goro Goro Fruit, Pika Pika Fruit, Zoro's Three Swords, Inosuke's Nichirin Blades, Tanjiro's Hanafuda Earrings, Inverted
Spear of Heaven, Ope Ope Fruit, Yami Yami Fruit, Saint's Corpse Part, Benihisago, Hokage Hat, Hogyoku,
Super Dragon Ball, Uo Uo Fruit, Blue Spider Lily, Flying Nimbus, Luffy's Straw Hat, Mahoraga's Wheel,
Gura Gura Fruit.

Notes on passes:
- **Zoro's Three Swords** (id `Enmah`, was "Enma") and **Inosuke's Nichirin Blades** (id
  `SerratedTwinBlades`, was "Tengen's Nichirin Cleavers") were renamed to match their models.
- **Three-Leaf Grimoire** has the clover on its cover, but the cover faces up, so on a pedestal you
  mostly see the spine. Display angle, not the model.
- Closest calls that still passed: Vivre Card (a plain paper scrap, but that's what it is), DIO's Diary
  (plain book), Stand Disc (a CD, as in the show), Rengoku's blade (more curved and orange than the show).
