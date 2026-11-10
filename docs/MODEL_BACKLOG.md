# 3D model backlog

**Done, 2026-11-10: 92 of 92 relics have a model.** The last 40 were made from ChatGPT concept
images Rosselle approved (`work/models/concepts_nov9/`, anime-accurate, Roblox-cartoon style), then
Tripo image-to-3D (H3.0), `tools/models/blender/prep_tripo_glb.py` and `tools/models/upload_model.py`.
Rule for any future model: recognisable as the anime item, Roblox-cartoon look, owner approves the
concept or test before credits are spent. The table below is the old backlog, kept for reference.

(Old status:) 26 of 92 relics have a model in `assets/RelicModels`; the 66 below still render as placeholder shapes.
Ordered by how often players see them (Common drops most). Design briefs per relic are in `docs/ROSTER.md`; generation settings in `docs/MESHY_PILOT.md` (same settings work in Tripo: stylized, ~5k tris, textured, no base, no text).

Suggested batches: 1 = Common + Uncommon (seen every few scans), 2 = Rare + Epic, 3 = the rest.

| # | Relic id | Name | Tier | Type | Batch |
|---|---|---|---|---|---|
| 1 | `PaladynsNecklace` | Paladyn's Necklace | Common | Crystal | 1 |
| 2 | `Kunay` | Kunay | Common | Weapon | 1 |
| 3 | `SealScroll` | Seal Scroll | Common | Book | 1 |
| 4 | `StealBall` | Steal Ball | Common | Crystal | 1 |
| 5 | `QuinsyBangle` | Quinsy Bangle | Common | Crystal | 1 |
| 6 | `HoyPoyCapsule` | Hoy-Poy Capsule | Common | Crystal | 1 |
| 7 | `SenzoBean` | Senzo Bean | Common | Special | 1 |
| 8 | `WistariaPoisonVial` | Wistaria Poison Vial | Common | Mask | 1 |
| 9 | `FoxxMask` | Foxx Mask | Common | Mask | 1 |
| 10 | `HuntarLicense` | Huntar License | Common | Book | 1 |
| 11 | `AkatsukoRing` | Akatsuko Ring | Common | Crystal | 1 |
| 12 | `BlackNichirenBlade` | Black Nichiren Blade | Common | Weapon | 1 |
| 13 | `MagickStone` | Magick Stone | Common | Crystal | 1 |
| 14 | `ExplodingTag` | Exploding Tag | Uncommon | Book | 1 |
| 15 | `EternalPoze` | Eternal Poze | Uncommon | Special | 1 |
| 16 | `StoneMasque` | Stone Masque | Uncommon | Mask | 1 |
| 17 | `Skouter` | Skouter | Uncommon | Mask | 1 |
| 18 | `DragunRadar` | Dragun Radar | Uncommon | Special | 1 |
| 19 | `TriLeafGrimoire` | Tri-Leaf Grimoire | Uncommon | Book | 1 |
| 20 | `GreedyIslandBook` | Greedy Island Book | Uncommon | Book | 1 |
| 21 | `Zangetzu` | Zangetzu | Uncommon | Weapon | 1 |
| 22 | `PowaPole` | Powa Pole | Uncommon | Weapon | 1 |
| 23 | `ThunderNichirenBlade` | Thunder Nichiren Blade | Uncommon | Weapon | 1 |
| 24 | `SerratedTwinBlades` | Serrated Twin Blades | Uncommon | Weapon | 1 |
| 25 | `HolloBait` | Hollo Bait | Rare | Special | 2 |
| 26 | `BlackenedRope` | Blackened Rope | Rare | Special | 2 |
| 27 | `DeosDiary` | DEO's Diary | Rare | Book | 2 |
| 28 | `LokakakaFruit` | Lokakaka Fruit | Rare | Special | 2 |
| 29 | `RiskieDice` | Riskie Dice | Rare | Crystal | 2 |
| 30 | `Samehadu` | Samehadu | Rare | Weapon | 2 |
| 31 | `Zabimara` | Zabimara | Rare | Weapon | 2 |
| 32 | `Benihima` | Benihima | Rare | Weapon | 2 |
| 33 | `FlameNichirenBlade` | Flame Nichiren Blade | Rare | Weapon | 2 |
| 34 | `InsectNichirenBlade` | Insect Nichiren Blade | Rare | Weapon | 2 |
| 35 | `DemonDwellingSword` | Demon-Dwelling Sword | Rare | Weapon | 2 |
| 36 | `QuadLeafGrimoire` | Quad-Leaf Grimoire | Epic | Book | 2 |
| 37 | `Senbonsakura` | Senbonsakura | Epic | Special | 2 |
| 38 | `StendDisc` | Stend Disc | Epic | Crystal | 2 |
| 39 | `JudgementChain` | Judgement Chain | Epic | Special | 2 |
| 40 | `OniSpineNaginata` | Oni-Spine Naginata | Epic | Weapon | 2 |
| 41 | `MadorasGunbai` | Madora's Gunbai | Epic | Special | 2 |
| 42 | `Hyorinmara` | Hyorinmara | Epic | Weapon | 2 |
| 43 | `PotoraEarrings` | Potora Earrings | Epic | Crystal | 2 |
| 44 | `DemonSlayingSword` | Demon-Slaying Sword | Epic | Weapon | 2 |
| 45 | `StaffOfJudgement` | Staff of Judgement | Epic | Weapon | 2 |
| 46 | `DemonSlashingKatana` | Demon-Slashing Katana | Epic | Weapon | 2 |
| 47 | `KubikiriCleaver` | Kubikiri Cleaver | Legendary | Weapon | 3 |
| 48 | `StendArrow` | Stend Arrow | Legendary | Special | 3 |
| 49 | `FourStarDragunBall` | Four-Star Dragun Ball | Legendary | Crystal | 3 |
| 50 | `BashosanFan` | Bashosan Fan | Legendary | Special | 3 |
| 51 | `KohakoJar` | Kohako Jar | Legendary | Mask | 3 |
| 52 | `QuinsyMedallion` | Quinsy Medallion | Legendary | Crystal | 3 |
| 53 | `DemonDestroyingSword` | Demon-Destroying Sword | Legendary | Weapon | 3 |
| 54 | `ScarlettEyes` | Scarlett Eyes | Legendary | Mask | 3 |
| 55 | `HolloMask` | Hollo Mask | Mythic | Mask | 3 |
| 56 | `DeathPaintWomb` | Death Paint Womb | Mythic | Mask | 3 |
| 57 | `SaintsCorpsePiece` | Saint's Corpse Piece | Mythic | Special | 3 |
| 58 | `BenihisagaGourd` | Benihisaga Gourd | Mythic | Mask | 3 |
| 59 | `Hogyuku` | Hogyuku | Celestial | Special | 3 |
| 60 | `SuperDragunBall` | Super Dragun Ball | Celestial | Crystal | 3 |
| 61 | `BeetleStendArrow` | Beetle Stend Arrow | Celestial | Special | 3 |
| 62 | `ShichiseiBlade` | Shichisei Blade | Celestial | Weapon | 3 |
| 63 | `BlueSpidderLily` | Blue Spidder Lily | Celestial | Special | 3 |
| 64 | `RedStoneOfAia` | Red Stone of Aia | Cosmic | Crystal | 3 |
| 65 | `PentaLeafGrimoire` | Penta-Leaf Grimoire | Cosmic | Book | 3 |
| 66 | `AncientSunriseBlade` | Ancient Sunrise Blade | Cosmic | Weapon | 3 |
