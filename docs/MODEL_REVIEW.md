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

## Redo: needs a new model (24)

| Tier | Relic | Why |
|---|---|---|
| Common | Steel Ball | black bomb with a red band, not a shiny dimpled steel ball |
| Common | Ichiraku Ramen (id HoyPoyCapsule) | swapped from Hoi-Poi Capsule Nov 11; needs its new model |
| Common | Den Den Mushi (id SenzoBean) | swapped from Senzu Bean Nov 11; needs its new model |
| Common | Tanjiro's Nichirin Blade | thin purple dagger, not a black katana with the round guard |
| Rare | Demon-Dweller Sword | spiky dagger, not a thin black katana |
| Epic | Senbonzakura | a square guard and a handle, no blade or petals |
| Epic | Madara's Gunbai | plain tan disc like a frying pan |
| Epic | Demon-Slayer Sword | realistic rock texture, doesn't read as Asta's |
| Legendary | Kubikiribocho | grey jagged dagger, no huge blade with the round hole |
| Legendary | Bashosen | realistic palm leaf |
| Legendary | Amber Purifying Jar | realistic brown pot |
| Legendary | Quincy Medallion | realistic grey puck |
| Legendary | Demon-Destroyer Sword | generic skull fantasy sword |
| Legendary | Scarlet Eyes | murky realistic jar, the eye barely shows |
| Mythic | Hollow Mask | generic skull with yellow eyes, not Ichigo's mask |
| Mythic | Death Painting Womb | grimy pickle jar |
| Mythic | Yoru | thin curved sabre, not Mihawk's huge black cross sword |
| Mythic | Tori Tori Fruit (Phoenix) | green pineapple |
| Celestial | Requiem Arrow | lumpy gold blob |
| Celestial | Prison Realm | right shape but dark red; should be pale |
| Celestial | Shichiseiken | generic realistic sword with stars |
| Cosmic | Red Stone of Aja | red gem on a realistic rock lump |
| Cosmic | Five-Leaf Grimoire | muddy black slab, no clover |
| Cosmic | Yoriichi's Nichirin Blade | plain black katana, no sun guard |

Cost at 40 credits each: 960 of the 2,860 left.

Owner's rule: Celestial and Cosmic models must be the best-looking in the game (VFX helps, but the
model itself has to be good), so their concepts get extra detail and polish.

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
