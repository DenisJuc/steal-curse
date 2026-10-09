# Relic Roster (Slice 8a)

The 92 relics in `src/shared/RelicConfig.luau`: exactly the GDD section 11 reference roster
(12 Jujutsu Kaisen, 18 One Piece, 11 Naruto, 9 JoJo, 10 Bleach, 8 Dragon Ball, 9 Demon Slayer,
8 Black Clover, 7 Hunter x Hunter), each released under a lightly altered name. This file is the
design brief for model generation (Slice 8b/8c). The "Ref" notes are for us only; docs are never
synced into the game.

Naming rule (developer decision): a light spelling twist that keeps the item recognizable
(Sukuna's Finger -> Sukana's Finger, Gomu Gomu -> Gumo Gumo, Senzu -> Senzo). Models should
follow the same idea: recognizable object, our own low-poly Roblox take, no copied logos,
lettering or official emblems. Note: the GDD warns that renaming alone does not remove
copyright risk; this is the developer's accepted choice.

Run `lune run tests/oddsReport` for live odds and `lune run tests/rareWaitReport` for rare-find
waits. The numbers below come from those reports.

## Rules every relic follows

- **One tier, one weight.** Weights inside a tier are all different (steps of 4, from 100 down),
  so every relic has its own odds. No relic gets less than 40% of an even share of its tier
  (checked by `config_spec`).
- **One primary family** (Demonic, Spiritual, Arcane, Astral) for the themed Codex sets and
  Signal Frequency.
- **One object type** (Weapon, Book, Mask, Crystal, Special) for the shared capture animation.
  Masks also cover jars and vials, Crystals cover orbs, rings and round fruits, Special covers
  anything held or hung (fruits, fans, chains, arrows, compasses).
- **One VFX profile** for the pedestal aura, reveal burst and carried glow (built in 8c):
  None, Ember, Frost, Storm, Shadow, Blood, Holy, Spirit, Bloom, Void, Starlight, Sand, Toxin.
- **Income** uses the tier default (CE per minute: Common 10, Uncommon 25, Rare 75, Epic 200,
  Legendary 600, Mythic 2,000, Celestial 6,000, Cosmic 20,000). No per-relic override.
- **No weapon pile-up.** 29 of 92 relics are weapons (under a third) and no tier is more than
  half weapons. The four Nichiren blades and four demon swords each get a distinct silhouette.

## Tier sizes

| Tier      | Relics | Tier odds (luck 1) |
| --------- | -----: | -----------------: |
| Common    |     16 |         1 in 1.33 |
| Uncommon  |     15 |         1 in 4.39 |
| Rare      |     14 |         1 in 49.5 |
| Epic      |     13 |          1 in 510 |
| Legendary |     12 |        1 in 25.1K |
| Mythic    |     10 |          1 in 10M |
| Celestial |      8 |         1 in 100B |
| Cosmic    |      4 |       1 in 1.32Qd |

Counts shrink as tiers get rarer: lots of variety where players spend most of their time. The
GDD's provisional bands (30 Common/Rare, 34 Epic/Legendary, 28 Mythic/Cosmic) were shifted down
for the first-hour variety the GDD asks for: a few "Epic/Legendary" references sit in
Common-Rare (e.g. Paladyn's Necklace, Dragon's Bone, the Nichiren blades) and a few
"Mythic/Cosmic" ones in Legendary (Bashosan Fan, Kohako Jar, Quinsy Medallion, Demon-Destroying
Sword, Scarlett Eyes).

**Essential Codex** (Common to Legendary): 70 relics: Demonic 17, Spiritual 19, Arcane 17,
Astral 17. Expected time to finish at the mid-game reference (luck 10K, one scan every 2 s,
focusing each tier in turn): about 0.3 h, well under the 10 h target.

**Family totals:** Demonic 22, Spiritual 24, Arcane 23, Astral 23.
**Object types:** Weapon 29, Special 27, Crystal 18, Book 9, Mask 9.

## Cosmic count (approved: 4)

Weights 28 / 26 / 24 / 22 (rarest gets 22% of the tier). At max boosts while AFK (mean hours):

| Cosmic relics  | One specific Cosmic | That Cosmic with Abyssal |
| -------------- | ------------------: | -----------------------: |
| 1              |               7.4 h |                     99 h |
| 2              |              14.8 h |                    198 h |
| 3              |              22.2 h |                    296 h |
| **4 (chosen)** |  **29.6 to 33.7 h** |         **395 to 449 h** |
| 6              |              44.4 h |                    593 h |
| 8              |              59.3 h |                    790 h |

"Any Cosmic" stays at 7.4 h AFK (5.5 h active) whatever the count. Named mutated Cosmics are an
accepted long tail.

## Showcase hooks

| Showcase        | Hook                                                         | Status |
| --------------- | ------------------------------------------------------------ | ------ |
| Crimson Throne  | Unlocks on discovering **Sukana's Finger** (Mythic)            | Built  |
| Crimson Throne  | Exploding Tag Banners accessory from **Exploding Tag**         | Built  |
| Simple Stance   | Hollo Bait Charm accessory from **Hollo Bait**                 | Built  |
| Golden Guardian | Guardian's Grimoire accessory from **Quad-Leaf Grimoire**      | Built  |
| Golden Guardian | Future: **Stone Masque** worn by the guardian, **Stend Arrow** variant | Future |
| Spectral Warlord (future) | **Madora's Gunbai**                                  | Future |
| Forbidden Archivist (future) | **Penta-Leaf Grimoire**                           | Future |

## Save data

The ten Slice 0 placeholder relics were replaced. Data migration step 4 renames their ids in
inventories, the Codex, mutation records, favorites, rare history and the carried relic:
Cracked Prayer Bead -> Paladyn's Necklace, Rusted Ward Nail -> Kunay, Ashen Paper Charm ->
Exploding Tag, Moth-Wing Lantern -> Eternal Poze, Hollow Bone Flute -> Hollo Bait, Inkbound
Sigil Tome -> Quad-Leaf Grimoire, Weeping Iron Halberd -> Kubikiri Cleaver, Veil of the Ninth
Moon -> Hollo Mask, Starforged Reliquary -> Hogyuku, Heart of the Last Eclipse -> Red Stone of
Aia (same tiers).

## Briefs

Each line: **Name** (`Id`), Family · Type · VFX · weight. Ref. Look. *Lore line.*

### Common (16)

- **Paladyn's Necklace** (`PaladynsNecklace`), Spiritual · Crystal · Holy · 100. Ref: Paladin's Necklace (HxH). A rosary-style bead chain with a small cross pendant, soft white glow. *Tell a lie while wearing it and it tightens.*
- **Kunay** (`Kunay`), Demonic · Weapon · Blood · 96. Ref: Kunai (Naruto). Leaf-shaped throwing blade, wrapped grip, ring pommel. *Every ninja's first blade, and usually their last resort.*
- **Vivra Card** (`VivraCard`), Astral · Book · Starlight · 92. Ref: Vivre Card (One Piece). A torn white paper square slowly creeping along the pedestal, edges singed. *Crawls toward its owner. Burns away as they grow weaker.*
- **Seal Scroll** (`SealScroll`), Arcane · Book · Spirit · 88. Ref: Sealing Scroll (Naruto). Large rolled scroll on thick rods, spiral seal on the outer wrap. *Whatever was sealed inside keeps knocking.*
- **Steal Ball** (`StealBall`), Astral · Crystal · Storm · 84. Ref: Steel Ball (JoJo SBR). Fist-sized metal ball with raised dimples, always spinning. *It never stops spinning, even in a locked box.*
- **Quinsy Bangle** (`QuinsyBangle`), Spiritual · Crystal · Holy · 80. Ref: Quincy Bangle (Bleach). Thin silver bracelet with a hanging five-point cross charm. *Pull the charm and a bow of light snaps into your hand.*
- **Hoy-Poy Capsule** (`HoyPoyCapsule`), Arcane · Crystal · Spirit · 76. Ref: Hoi-Poi Capsule (Dragon Ball). Small white pill capsule with a push button and a number stamp. *Click, throw, and a whole house pops out.*
- **Senzo Bean** (`SenzoBean`), Astral · Special · Bloom · 72. Ref: Senzu Bean (Dragon Ball). A small green bean, oversized for display, in a tiny cloth pouch. *One bite heals everything. Ten days without food, too.*
- **Wistaria Poison Vial** (`WistariaPoisonVial`), Spiritual · Mask · Toxin · 68. Ref: Wisteria Poison (Demon Slayer). Corked glass vial of lilac liquid with a wisteria sprig. *Demons start coughing the moment you uncork it.*
- **Foxx Mask** (`FoxxMask`), Spiritual · Mask · Spirit · 64. Ref: Fox Mask (Demon Slayer). White fox mask with red markings and a small scar line. *Carved to keep its wearer safe. It remembers every one of them.*
- **Huntar License** (`HuntarLicense`), Arcane · Book · None · 60. Ref: Hunter License (HxH). A stiff card with a large emblem and a magnetic strip. *Opens doors that appear on no map.*
- **Slaughter Daemon** (`SlaughterDaemon`), Demonic · Weapon · Shadow · 56. Ref: Slaughter Demon (JJK). Short knife with a cursed-tool grip and dark wisps. *A cursed knife that cuts best when it shouldn't.*
- **Akatsuko Ring** (`AkatsukoRing`), Demonic · Crystal · Shadow · 52. Ref: Akatsuki Ring (Naruto). Dark ring with a single kanji-style stone. *Ten were forged. The other nine are watching.*
- **Black Nichiren Blade** (`BlackNichirenBlade`), Demonic · Weapon · Shadow · 48. Ref: Black Nichirin Blade (Demon Slayer). Katana with a fully black blade and square guard. *Its color turned black the moment it was drawn. Nobody knows why.*
- **Magick Stone** (`MagickStone`), Arcane · Crystal · Spirit · 44. Ref: Magic Stone (Black Clover). Faceted glowing gem chunk with floating runes. *One of the stones that holds the magic of the kingdom.*
- **Dragon's Bone** (`DragonsBone`), Astral · Weapon · Storm · 40. Ref: Dragon Bone (JJK). Huge bone-like cleaver sword with a jet vent near the hilt. *Every blow it takes, it gives back louder.*

### Uncommon (15)

- **Exploding Tag** (`ExplodingTag`), Arcane · Book · Ember · 100. Ref: Explosive Tag (Naruto). Long paper tag with a red seal, smoldering edge. *The ink smolders when no one is looking.*
- **Eternal Poze** (`EternalPoze`), Spiritual · Special · Spirit · 96. Ref: Eternal Pose (One Piece). Hourglass-shaped glass compass on a wooden stand, floating needle. *Its needle points to one island, forever.*
- **Yuto's Ring** (`YutosRing`), Spiritual · Crystal · Spirit · 92. Ref: Yuta's Ring (JJK). Plain silver band with a faint ghostly hand curled around it. *Someone still lives inside the promise.*
- **Stone Masque** (`StoneMasque`), Demonic · Mask · Blood · 88. Ref: Stone Mask (JoJo). Grey stone face mask with bone spikes along the rim. *Spines slide out of its rim when it tastes blood.*
- **Skouter** (`Skouter`), Astral · Mask · Starlight · 84. Ref: Scouter (Dragon Ball). One-eye headset with a tinted lens showing numbers. *It tells you exactly how strong someone is. Rudely.*
- **Dragun Radar** (`DragunRadar`), Astral · Special · Starlight · 80. Ref: Dragon Radar (Dragon Ball). Round handheld device with a grid screen and blinking dots. *Seven blips. Seven wishes waiting.*
- **Tri-Leaf Grimoire** (`TriLeafGrimoire`), Arcane · Book · Bloom · 76. Ref: Three-Leaf Grimoire (Black Clover). Book with a three-leaf clover on the cover. *Faith, hope and love, pressed into a cover.*
- **Greedy Island Book** (`GreedyIslandBook`), Arcane · Book · Spirit · 72. Ref: Greed Island binder (HxH). Card binder with glowing slots, many still empty. *Every card inside is a door. Most of them are locked.*
- **Bura Bura Fruit** (`BuraBuraFruit`), Arcane · Special · Bloom · 68. Ref: Bara Bara no Mi (One Piece). Swirl-patterned fruit split into floating pieces. *Eat it and you come apart. In a good way.*
- **Hanna Hanna Fruit** (`HannaHannaFruit`), Spiritual · Special · Bloom · 64. Ref: Hana Hana no Mi (One Piece). Pink swirl fruit with small hand-shaped petals. *Hands bloom wherever you look.*
- **Sona Sona Fruit** (`SonaSonaFruit`), Astral · Special · Sand · 60. Ref: Suna Suna no Mi (One Piece). Sandy swirl fruit trickling sand. *Sand runs through it, but never runs out.*
- **Zangetzu** (`Zangetzu`), Spiritual · Weapon · Spirit · 56. Ref: Zangetsu (Bleach). Huge guardless cleaver-sword with a cloth-wrapped grip. *Its slash leaves a crescent hanging in the air.*
- **Powa Pole** (`PowaPole`), Astral · Weapon · Storm · 52. Ref: Power Pole (Dragon Ball). Red staff with gold end caps. *Say "extend" and mean it.*
- **Thunder Nichiren Blade** (`ThunderNichirenBlade`), Demonic · Weapon · Storm · 48. Ref: Thunder Nichirin Blade (Demon Slayer). Katana with a yellow zig-zag pattern along the blade. *One draw, one flash, one strike.*
- **Serrated Twin Blades** (`SerratedTwinBlades`), Demonic · Weapon · Blood · 44. Ref: Serrated dual blades (Demon Slayer). Two short wide serrated cleavers joined by a chain. *Made for a demon's neck. Two at a time.*

### Rare (14)

- **Hollo Bait** (`HolloBait`), Demonic · Special · Shadow · 100. Ref: Hollow Bait (Bleach). Small round pill-like lure, cracked, leaking purple haze. *Crush it and every hungry spirit nearby comes running.*
- **Blackened Rope** (`BlackenedRope`), Arcane · Special · Void · 96. Ref: Black Rope (JJK). Coil of black braided rope, frayed end trailing void threads. *Any technique it touches comes loose like a bad knot.*
- **DEO's Diary** (`DeosDiary`), Demonic · Book · Blood · 92. Ref: DIO's Diary (JoJo). Small leather diary with a gold clasp and red ribbon. *The last entry describes a heaven that hasn't happened yet.*
- **Lokakaka Fruit** (`LokakakaFruit`), Spiritual · Special · Bloom · 88. Ref: Locacaca (JoJo). Lumpy fruit with stone-like patches. *It heals one wound by opening another.*
- **Hii Hii Fruit** (`HiiHiiFruit`), Arcane · Crystal · Frost · 84. Ref: Hie Hie no Mi (One Piece). Icy blue swirl fruit with frost spikes. *Your breath turns to snow around it.*
- **Mochy Mochy Fruit** (`MochyMochyFruit`), Astral · Special · Starlight · 80. Ref: Mochi Mochi no Mi (One Piece). Soft pale swirl fruit, slightly squashed and dripping. *Soft as dough, sticky as a promise.*
- **Riskie Dice** (`RiskieDice`), Astral · Crystal · Void · 76. Ref: Risky Dice (HxH). Large twenty-sided die, one face marked with a skull. *Great luck on most faces. On one face, something terrible.*
- **Samehadu** (`Samehadu`), Demonic · Weapon · Shadow · 72. Ref: Samehada (Naruto). Bandaged club-sword covered in shark-skin scales. *It feeds on whatever power you swing at it.*
- **Zabimara** (`Zabimara`), Spiritual · Weapon · Spirit · 68. Ref: Zabimaru (Bleach). Segmented whip-sword held in a snake curve. *Its blade comes apart into a striking snake.*
- **Benihima** (`Benihima`), Arcane · Weapon · Blood · 64. Ref: Benihime (Bleach). Walking cane with the hidden blade half-drawn, red tassel. *A cane, a hidden blade, and very good manners.*
- **Flame Nichiren Blade** (`FlameNichirenBlade`), Spiritual · Weapon · Ember · 60. Ref: Flame Nichirin Blade (Demon Slayer). Katana with a flame-shaped guard and red-orange blade. *Set your heart ablaze.*
- **Insect Nichiren Blade** (`InsectNichirenBlade`), Spiritual · Weapon · Toxin · 56. Ref: Insect Nichirin Blade (Demon Slayer). Needle-thin stinger blade with a butterfly guard. *Too thin to cut. It doesn't need to.*
- **Demon-Dwelling Sword** (`DemonDwellingSword`), Demonic · Weapon · Void · 52. Ref: Demon-Dweller Sword (Black Clover). Thin black katana with a dark aura. *Cast at it and it swallows the magic.*
- **Playfull Cloud** (`PlayfullCloud`), Astral · Weapon · Storm · 48. Ref: Playful Cloud (JJK). Three red staff sections linked by chains. *Three sections, three thunderclaps.*

### Epic (13)

- **Quad-Leaf Grimoire** (`QuadLeafGrimoire`), Arcane · Book · Spirit · 100. Ref: Four-Leaf Grimoire (Black Clover). Book with a four-leaf clover on the cover, wind swirling off the pages. *The fourth leaf holds luck. Nobody knows whose.*
- **Mara Mara Fruit** (`MaraMaraFruit`), Demonic · Special · Ember · 96. Ref: Mera Mera no Mi (One Piece). Orange flame-swirl fruit with a curly stem. *Hot enough to hurt. Hungry enough to hurt more.*
- **Gumo Gumo Fruit** (`GumoGumoFruit`), Spiritual · Special · Bloom · 92. Ref: Gomu Gomu no Mi (One Piece). Purple swirl fruit with a curly stem. *Press an ear to it: a heartbeat like distant drums.*
- **Senbonsakura** (`Senbonsakura`), Spiritual · Special · Bloom · 88. Ref: Senbonzakura (Bleach). Katana hilt with a cloud of floating pink blade-petals. *Scatter, and a thousand blades fall like petals.*
- **Stend Disc** (`StendDisc`), Astral · Crystal · Starlight · 84. Ref: Stand DISC (JoJo). Shiny iridescent disc with a faint figure reflected in it. *Slide it in and remember a power that was not yours.*
- **Judgement Chain** (`JudgementChain`), Arcane · Special · Spirit · 80. Ref: Judgment Chain (HxH). Chain hanging from a ring with a small blade-tipped weight. *Break the promise and the chain closes.*
- **Chain of Thousand Miles** (`ChainOfThousandMiles`), Arcane · Weapon · Void · 76. Ref: Chain of a Thousand Miles (JJK). Long coiled chain whose far end disappears into a void ripple. *Nobody has ever found its other end.*
- **Madora's Gunbai** (`MadorasGunbai`), Astral · Special · Storm · 72. Ref: Madara's Gunbai (Naruto). Large round war fan on a long handle, three-tomoe motif. *It once turned an army's charge back on itself.*
- **Hyorinmara** (`Hyorinmara`), Astral · Weapon · Frost · 68. Ref: Hyorinmaru (Bleach). Katana with a star-shaped guard and an ice dragon coiling around it. *A dragon of ice uncoils from every swing.*
- **Potora Earrings** (`PotoraEarrings`), Spiritual · Crystal · Spirit · 64. Ref: Potara Earrings (Dragon Ball). Pair of earrings with green-yellow round gems. *Two people wear one each, and walk away as one.*
- **Demon-Slaying Sword** (`DemonSlayingSword`), Demonic · Weapon · Void · 60. Ref: Demon-Slayer Sword (Black Clover). Huge rough chipped greatsword. *Ugly, heavy, and every spell dies on it.*
- **Staff of Judgement** (`StaffOfJudgement`), Arcane · Weapon · Holy · 56. Ref: Staff of Judgment (HxH). Tall staff topped with a balance scale. *It weighs the lie you are about to tell.*
- **Demon-Slashing Katana** (`DemonSlashingKatana`), Demonic · Weapon · Shadow · 52. Ref: Demon-Slasher Katana (Black Clover). Black katana with a jagged edge and grey aura. *Cuts the spell first and the caster second.*

### Legendary (12)

- **Kubikiri Cleaver** (`KubikiriCleaver`), Demonic · Weapon · Blood · 100. Ref: Kubikiribocho (Naruto). Giant cleaver with a round hole near the tip and a half-moon notch. *Break it, and it drinks blood to make itself whole.*
- **Stend Arrow** (`StendArrow`), Spiritual · Special · Holy · 96. Ref: Stand Arrow (JoJo). Gold arrowhead with an ornate pattern on a short broken shaft. *It chooses who it cuts. The chosen wake up changed.*
- **Soul Split Katana** (`SoulSplitKatana`), Spiritual · Weapon · Spirit · 92. Ref: Split Soul Katana (JJK). Long katana with a pale blade and a faint ghost-copy trailing it. *Cuts the soul and leaves the body very confused.*
- **Four-Star Dragun Ball** (`FourStarDragunBall`), Astral · Crystal · Starlight · 88. Ref: Four-Star Dragon Ball (Dragon Ball). Orange glass orb with four red stars inside. *Gather all seven and the sky starts listening.*
- **Gora Gora Fruit** (`GoraGoraFruit`), Astral · Crystal · Storm · 84. Ref: Goro Goro no Mi (One Piece). Blue-yellow swirl fruit crackling with lightning. *Lightning sleeps inside it. Lightly.*
- **Peka Peka Fruit** (`PekaPekaFruit`), Spiritual · Special · Holy · 80. Ref: Pika Pika no Mi (One Piece). Bright yellow swirl fruit leaking light. *Bite it and you're gone at the speed of light.*
- **Enmah** (`Enmah`), Arcane · Weapon · Shadow · 76. Ref: Enma (One Piece). Long katana with a dark purple sheath and a gold guard. *It pulls power out of whoever holds it. Only the strong keep up.*
- **Bashosan Fan** (`BashosanFan`), Astral · Special · Storm · 72. Ref: Bashosen (Naruto). Big leaf-shaped fan on a long handle. *Each wave brings a different element.*
- **Kohako Jar** (`KohakoJar`), Spiritual · Mask · Spirit · 68. Ref: Kohaku no Johei (Naruto). Squat amber gourd-jar with a stopper. *Say your favorite word near it and you're inside.*
- **Quinsy Medallion** (`QuinsyMedallion`), Arcane · Crystal · Starlight · 64. Ref: Quincy Medallion (Bleach). Round silver medallion with a star-cross and a socket. *It steals the power you lean on most.*
- **Demon-Destroying Sword** (`DemonDestroyingSword`), Demonic · Weapon · Blood · 60. Ref: Demon-Destroyer Sword (Black Clover). Broad black greatsword with red runes. *A demon is still screaming somewhere inside the steel.*
- **Scarlett Eyes** (`ScarlettEyes`), Demonic · Mask · Blood · 56. Ref: Scarlet Eyes (HxH). Two glowing scarlet eyes floating in a sealed glass jar. *Two scarlet eyes float in the jar. They follow you.*

### Mythic (10)

- **Hollo Mask** (`HolloMask`), Astral · Mask · Starlight · 100. Ref: Hollow Mask (Bleach). White bone mask with red stripes and dark eye holes. *Put it on and something else looks out through your eyes.*
- **Sukana's Finger** (`SukanasFinger`), Demonic · Special · Blood · 96. Ref: Sukuna's Finger (JJK). Long withered black-nailed finger wrapped in a talisman cloth. *One of twenty. It still twitches toward its throne.* (Crimson Throne unlock.)
- **Death Paint Womb** (`DeathPaintWomb`), Demonic · Mask · Toxin · 92. Ref: Death Painting Womb (JJK). Specimen jar of green brine with a curled shadowy shape. *Something unborn floats in the brine. It is growing.*
- **Inverse Spear of Heaven** (`InverseSpearOfHeaven`), Arcane · Weapon · Void · 88. Ref: Inverted Spear of Heaven (JJK). Short three-pronged dagger-spear with a chain on the pommel. *Every technique it touches unravels into nothing.*
- **Opi Opi Fruit** (`OpiOpiFruit`), Arcane · Special · Spirit · 84. Ref: Ope Ope no Mi (One Piece). Heart-shaped swirl fruit inside a pale-blue light dome. *Inside its glowing room, you are the surgeon.*
- **Yamu Yamu Fruit** (`YamuYamuFruit`), Astral · Crystal · Void · 80. Ref: Yami Yami no Mi (One Piece). Dark purple swirl fruit pulling light motes inward. *Light falls into it and does not come back out.*
- **Yorru** (`Yorru`), Demonic · Weapon · Shadow · 76. Ref: Yoru (One Piece). Huge black cross-guard greatsword. *It split an iceberg in half, then went back to sleep.*
- **Saint's Corpse Piece** (`SaintsCorpsePiece`), Spiritual · Special · Holy · 72. Ref: Saint's Corpse Part (JoJo SBR). Mummified relic part in a small gilded reliquary. *Part of a saint who walked across a continent. It wants to keep walking.*
- **Tory Tory Phoenix Fruit** (`ToryToryPhoenixFruit`), Spiritual · Special · Ember · 68. Ref: Tori Tori no Mi, Phoenix (One Piece). Blue-gold flame-swirl fruit with feather tufts. *It burns blue, and heals whatever it burns.*
- **Benihisaga Gourd** (`BenihisagaGourd`), Arcane · Mask · Spirit · 64. Ref: Benihisago (Naruto). Red lacquered gourd with a rope sash. *Answer when it calls your name, and you're sealed inside.*

### Celestial (8)

- **Hogyuku** (`Hogyuku`), Astral · Special · Starlight · 100. Ref: Hogyoku (Bleach). Small glowing purple orb in a metal cage. *It grants what its holder's heart truly wants.*
- **Super Dragun Ball** (`SuperDragunBall`), Arcane · Crystal · Starlight · 96. Ref: Super Dragon Ball (Dragon Ball). Large amber orb with a glowing star inside. *Big as a planet once. Folded small for travel.*
- **Beetle Stend Arrow** (`BeetleStendArrow`), Spiritual · Special · Holy · 92. Ref: Requiem / beetle-emblem Stand Arrow (JoJo). Gold arrowhead with a beetle clamped on top. *Pierce what you are; become what you will be.*
- **Kamutoki** (`Kamutoki`), Astral · Weapon · Storm · 88. Ref: Kamutoke (JJK). Short-handled lightning hammer crackling with blue bolts. *Strike it once: a drum. Strike it twice: the sky answers.*
- **Prizon Realm** (`PrizonRealm`), Arcane · Special · Void · 84. Ref: Prison Realm (JJK). Small stone cube covered in eyes. *Bigger inside than the world outside, and much harder to leave.*
- **Shichisei Blade** (`ShichiseiBlade`), Spiritual · Weapon · Spirit · 80. Ref: Shichiseiken (Naruto). Hilt with a blade made of glowing chakra-like light and seven stars. *No steel at all: seven stars and a will.*
- **Uwo Uwo Dragon Fruit** (`UwoUwoDragonFruit`), Astral · Crystal · Storm · 76. Ref: Uo Uo no Mi, Azure Dragon (One Piece). Deep blue swirl fruit with a dragon curled around it. *An azure dragon sleeps curled up inside the rind.*
- **Blue Spidder Lily** (`BlueSpidderLily`), Demonic · Special · Bloom · 72. Ref: Blue Spider Lily (Demon Slayer). Pale blue spider lily under a small glass dome. *Blooms only in daylight. Demons would kill for one.*

### Cosmic (4)

- **Red Stone of Aia** (`RedStoneOfAia`), Astral · Crystal · Starlight · 28. Ref: Red Stone of Aja (JoJo). Large faceted red gem glowing from inside. *Focus sunlight through it and it pierces anything.*
- **Gurra Gurra Fruit** (`GurraGurraFruit`), Arcane · Special · Storm · 26. Ref: Gura Gura no Mi (One Piece). Pale swirl fruit with glowing cracks in the air around it. *Tap it and the air cracks like glass.*
- **Penta-Leaf Grimoire** (`PentaLeafGrimoire`), Demonic · Book · Void · 24. Ref: Five-Leaf Grimoire (Black Clover). Black worn book with a five-leaf clover, one leaf darker than the rest. *A devil lives on its fifth leaf. It is very patient.* (Future Forbidden Archivist.)
- **Ancient Sunrise Blade** (`AncientSunriseBlade`), Spiritual · Weapon · Holy · 22. Ref: Ancient Sun Blade (Demon Slayer). Katana with a sun-disk guard and a deep red blade. *The blade that taught demons to fear the morning.*
