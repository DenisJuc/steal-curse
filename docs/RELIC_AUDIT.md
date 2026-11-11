# Relic list v2 (Rosselle's picks, 2026-11-10)

Started from the recognisability audit (see git history for v1). 92 relics → **99**:
10 swapped, 7 added, 1 remodel. Nothing is in the game yet; ids, saves and models change in the build pass.

**Names:** shown names switch to the names players already use. Roblox anime games use the real
names: YBA has DIO's Diary, Rokakaka, Mysterious Arrow and Saint's Corpse parts; AUT has Requiem
Arrow and Sukuna's Finger; Anime Roulette has Dragon Slayer. Internal ids (`Kunay`, `Samehadu`…)
stay as they are, so renaming alone does not touch saves. Earlier docs noted that real names carry
more copyright risk than altered ones; this is the developer's call, same as before.

Legend: **SWAP** = replaces the old relic but keeps its id, so owners of the old relic simply own the
new one (no save migration needed; the id map is at the top of RelicConfig), **NEW** = added relic,
last in its tier (lowest weight), **REMODEL** = new 3D model only.

Status 2026-11-10: in code (RelicConfig), and all 17 new or swapped relics plus the Saint's Corpse
remodel have concept-first models (concepts in work/models/concepts_nov10, Tripo jobs in
work/models/tripo/jobs_nov10b.txt, 720 credits).

## Common (17)

| Id | Shown name | Change |
|---|---|---|
| PaladynsNecklace | **Gon's Fishing Rod** | SWAP (was Paladin's Necklace) |
| Kunay | Kunai | |
| VivraCard | Vivre Card | |
| SealScroll | Sealing Scroll | |
| StealBall | Steel Ball | |
| QuinsyBangle | Quincy Bangle | |
| HoyPoyCapsule | Ichiraku Ramen | SWAP Nov 11 (was Hoi-Poi Capsule, not recognisable) |
| SenzoBean | Den Den Mushi | SWAP Nov 11 (was Senzu Bean, not recognisable) |
| WistariaPoisonVial | Wisteria Poison | |
| *(new)* | **Nezuko's Bamboo Muzzle** | NEW |
| FoxxMask | Fox Mask | |
| HuntarLicense | Hunter License | |
| SlaughterDaemon | **Nobara's Hammer & Nails** | SWAP (was Slaughter Demon) |
| AkatsukoRing | Akatsuki Ring | |
| BlackNichirenBlade | Tanjiro's Nichirin Blade | |
| MagickStone | **Leaf Village Headband** | SWAP (was Magic Stone) |
| DragonsBone | **Inosuke's Boar Mask** | SWAP (was Dragon Bone) |

## Uncommon (15)

| Id | Shown name | Change |
|---|---|---|
| ExplodingTag | Explosive Tag | |
| EternalPoze | Eternal Pose | |
| YutosRing | Yuta's Ring | |
| StoneMasque | Stone Mask | |
| Skouter | Scouter | |
| DragunRadar | Dragon Radar | |
| TriLeafGrimoire | Three-Leaf Grimoire | |
| GreedyIslandBook | **Killua's Yo-yos** | SWAP (was Greed Island Binder) |
| BuraBuraFruit | Bara Bara Fruit | |
| HannaHannaFruit | Hana Hana Fruit | |
| SonaSonaFruit | Suna Suna Fruit | |
| Zangetzu | Zangetsu | |
| PowaPole | Power Pole | |
| ThunderNichirenBlade | Zenitsu's Nichirin Blade | |
| SerratedTwinBlades | Inosuke's Nichirin Blades | renamed Nov 10 to match the model |

## Rare (15)

| Id | Shown name | Change |
|---|---|---|
| HolloBait | **Substitute Soul Reaper Badge** | SWAP (was Hollow Bait) |
| BlackenedRope | **Gojo's Blindfold** | SWAP (was Black Rope) |
| DeosDiary | DIO's Diary | |
| *(new)* | **Jotaro's Cap** | NEW |
| LokakakaFruit | Rokakaka | |
| HiiHiiFruit | Hie Hie Fruit | |
| MochyMochyFruit | Mochi Mochi Fruit | |
| RiskieDice | **Hisoka's Cards** | SWAP (was Risky Dice) |
| Samehadu | Samehada | |
| Zabimara | Zabimaru | |
| Benihima | Benihime | |
| FlameNichirenBlade | Rengoku's Nichirin Blade | |
| InsectNichirenBlade | Shinobu's Nichirin Blade | |
| DemonDwellingSword | Demon-Dweller Sword | |
| PlayfullCloud | Playful Cloud | text fix: it's Toji's staff, no thunder |

## Epic (13)

| Id | Shown name | Change |
|---|---|---|
| QuadLeafGrimoire | Four-Leaf Grimoire | |
| MaraMaraFruit | Mera Mera Fruit | text fix: was "Magma Fruit" |
| GumoGumoFruit | Gomu Gomu Fruit | |
| Senbonsakura | Senbonzakura | |
| StendDisc | Stand Disc | |
| JudgementChain | Judgment Chain | |
| OniSpineNaginata | **Gaara's Gourd** | SWAP (was Oni-Spine Naginata) |
| MadorasGunbai | Madara's Gunbai | |
| Hyorinmara | Hyorinmaru | |
| PotoraEarrings | Potara Earrings | |
| DemonSlayingSword | Demon-Slayer Sword | |
| StaffOfJudgement | **Nezuko's Box** | SWAP (was Staff of Judgement) |
| DemonSlashingKatana | Demon-Slasher Katana | **your call**: Asta's 4th anti-magic sword (Black Clover) |

## Legendary (13)

| Id | Shown name | Change |
|---|---|---|
| KubikiriCleaver | Kubikiribocho | |
| StendArrow | Stand Arrow | |
| SoulSplitKatana | Split Soul Katana | |
| FourStarDragunBall | Four-Star Dragon Ball | |
| GoraGoraFruit | Goro Goro Fruit | |
| PekaPekaFruit | Pika Pika Fruit | |
| Enmah | Zoro's Three Swords | renamed Nov 10 to match the model |
| BashosanFan | Bashosen | |
| KohakoJar | Amber Purifying Jar | |
| QuinsyMedallion | Quincy Medallion | |
| DemonDestroyingSword | Demon-Destroyer Sword | |
| ScarlettEyes | Scarlet Eyes | |
| *(new)* | **Tanjiro's Hanafuda Earrings** | NEW |

## Mythic (11)

| Id | Shown name | Change |
|---|---|---|
| HolloMask | Hollow Mask | |
| SukanasFinger | Sukuna's Finger | |
| DeathPaintWomb | Death Painting Womb | |
| InverseSpearOfHeaven | Inverted Spear of Heaven | |
| OpiOpiFruit | Ope Ope Fruit | |
| YamuYamuFruit | Yami Yami Fruit | |
| Yorru | Yoru | |
| SaintsCorpsePiece | Saint's Corpse Part | **REMODEL**: real skeleton part (bones), current one looks like a zombie lump |
| ToryToryPhoenixFruit | Tori Tori Fruit (Phoenix) | |
| BenihisagaGourd | Benihisago | |
| *(new)* | **Hokage Hat** | NEW |

## Celestial (11)

| Id | Shown name | Change |
|---|---|---|
| Hogyuku | Hogyoku | |
| SuperDragunBall | Super Dragon Ball | |
| *(new)* | **Flying Nimbus** | NEW |
| BeetleStendArrow | Requiem Arrow | |
| *(new)* | **Luffy's Straw Hat** | NEW (could also go Cosmic) |
| Kamutoki | Kamutoke | |
| *(new)* | **Mahoraga's Wheel** | NEW |
| PrizonRealm | Prison Realm | |
| ShichiseiBlade | Shichiseiken | kept for now |
| UwoUwoDragonFruit | Uo Uo Fruit (Azure Dragon) | |
| BlueSpidderLily | Blue Spider Lily | |

## Cosmic (4)

| Id | Shown name | Change |
|---|---|---|
| RedStoneOfAia | Red Stone of Aja | |
| GurraGurraFruit | Gura Gura Fruit | |
| PentaLeafGrimoire | Five-Leaf Grimoire | |
| AncientSunriseBlade | Yoriichi's Nichirin Blade | |

## Later: secret category (roadmap only)

Behelit and Guts' Dragon Slayer (Berserk), as a secret or themed set outside the normal tiers.

## 3D model pass

- New models: 10 swaps + 7 new = **17**, plus the Saint's Corpse remodel = **18**.
- Restyle: old models that look too realistic / "too 3D". Next step is to list them from the Studio shelf.
- Same rule as before: concept art first, Rosselle's OK, then Tripo (40 credits each; 480 left).
