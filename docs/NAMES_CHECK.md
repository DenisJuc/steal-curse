# Parody names and model originality check (2026-11-08)

Rule from the review: keep the hint names (they're fine), keep the **models** original. Risk goes up
when a model copies the anime object's distinctive design, especially together with a hint name.
All 52 modelled relics were laid out in Studio and compared; all 40 prompts for the Nov 9 Tripo batch
were reviewed. Not legal advice: this is a design pass to remove the obvious look-alikes.

## Existing models

| Risk | Relics | Why | Fix |
| --- | --- | --- | --- |
| High | 14 fruits: Rubber, Magma (Flame), Quake, Ice, Dough, Lightning, Light, Operation, Darkness, Phoenix, Azure Dragon, Split, Blossom, Sand | All share the swirl-pattern skin and curly stem, the signature One Piece devil-fruit look. Rubber (purple, tight swirls) and Magma (orange flame swirls) are almost exact. | Remake with a "cursed fruit" design (thorny black stem, cracks/veins/glow, no swirls). Prompts ready in `work/models/tripo_remakes.json`. 14 × 40 = 560 credits. |
| High | Enma | Three sheathed katanas in purple, white and red with gold fittings: Zoro's three-sword set. | Remake as one talisman-bound katana. 40 credits. |
| Medium | Prison Realm Cube | A cube covered in eyes, close to the Jujutsu Kaisen object. | Remake as a chained stone cube with seal marks. 40 credits. |
| Medium | Inverse Spear of Heaven | Forked blade on a long chain, close to the JJK weapon. | Remake as a forked ritual dagger with a tassel. 40 credits. |
| OK | The other 34 | Generic objects (rings, masks, swords, scrolls, gourds from public-domain Journey to the West, a skull mask, a mummified finger, a gold arrow). | None. |

All four remakes together: 17 models, about 680 credits. That's the owner's call (credits).

## Nov 9 batch prompts (fixed before any credits are spent)

14 of the 40 prompts described the anime design itself. Rewritten in `work/models/tripo_batch2.json`
(old file kept as `tripo_batch2.before_names_check.json`):

| Relic | Was (too close) | Now |
| --- | --- | --- |
| Four-Star Wish Orb | orange ball with four red stars (Dragon Ball) | amber orb in an iron claw cage with four ember sparks |
| Planet Wish Orb | sphere with seven gold stars | cracked obsidian sphere with gold motes |
| Power Scouter | one-eye headset, green lens (DBZ scouter) | brass monocle, violet lens, bent antenna |
| Wish Orb Radar | round radar with green grid (Dragon Radar) | brass pocket compass with a violet dial |
| Fusion Earrings | gold ring + green gem pair (Potara) | silver teardrop amethysts joined by a thread |
| Red Dawn Ring | red stone with a black kanji (Akatsuki ring) | iron ring with a cracked crimson moonstone |
| Reflecting War Fan | tomoe symbol | ring-shaped sigil |
| Crescent Moon Cleaver | guardless black cleaver, bandaged hilt (Zangetsu) | crescent-tipped cleaver, ring pommel, chain grip |
| Shark-Skin Greatsword | scale-covered sword with an eye (Samehada) | club-sword lined with shark teeth |
| Growing Power Pole | red staff, gold caps (Power Pole) | dark staff with bronze dragon-head caps |
| Eternal Island Compass | hourglass glass compass (Eternal Pose) | round compass in a skull-shaped frame |
| Thunder / Flame / Insect Sun-Steel Blades | Zenitsu's zig-zag blade, Rengoku's flame guard, Shinobu's butterfly guard | cracked-lightning blade, ember cut-out guard, lotus guard |

Kept as they are: Pocket House Capsule (already a dark metal capsule), the clover grimoires (a clover
is a generic symbol), Mysterious Disc (a disc), Judgement Chain, Snake-Tail Blade, Thousand Petal
Blade, Ice Dragon Blade and the rest: generic shapes.
