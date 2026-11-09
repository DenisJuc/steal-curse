# Fresh-eyes pass (2026-11-08 evening)

Rosselle's ask: stop judging the game by what we're used to; find what still reads as primitive.
Went through the HUD, Settings, Luck, Codex, Skills, Shop, the street, the plaza, the town ground and
a town path in Studio, as a returning player.

## Fixed in this pass

| What | Before | Now |
| --- | --- | --- |
| Footsteps | One step sound on every floor | Grass, stone (slate, flagstone, cobble, street), wood and dirt each have their own looping step (free Creator Store audio, all checked to load) |
| Town sound | Silent (the wild had ambience, the town had none) | Night crickets loop (Roblox library) + wind chimes now and then |
| Settings | 12 rows | 6: Effects, Animations (one row for rolls + reveals), Camera shake, Sound, Tutorial, Code. Roll style, reveal sound, menu size and Welcome Back are hidden; saved choices still apply |
| Town paths and street | Terrain voxels: 4-stud staircase edges, blurry cobble from above ("pixelated") | Part slabs with the generated flagstone material and dark kerbs: crisp edges |
| Town ground | A grid of single props, 3-4 models repeated, flat green lawn | Composed scenes (bamboo groves, sakura glades, rock gardens, roadside jizo shrines, withered corners, open grass), a bamboo/dead-tree treeline at the town edge with gaps at the exits, lawn patches of leafy grass and bare earth |
| Realistic bamboo (new today) | Grey papery leaves, clashed with the low-poly style | Taken back out |

Part count: 10,127 of the 12,000 budget (was ~9,300 this morning; first draft of the new
dressing hit 11,227, cut back by using fewer spider-lily patches, which are 14 parts each).

## Still to rework (ranked)

1. **Relic models.** 40 grey placeholders and 17 look-alikes (see NAMES_CHECK.md). Biggest thing a
   player sees. Tripo, from Nov 9.
2. **Menus are text tables.** Luck is a list of odds; at high luck Common and Uncommon say
   "1 in ∞" (confusing: should read "Never" or drop off). Codex cards have no rarity colour or frame.
   The skill tree reuses icons (the pedestal icon on Huge Attunement). Shop icons are painted, HUD
   icons are a different style. A UI art pass (or the UI artist on the decisions list) fixes these
   together.
3. **Two names for one thing.** The NEXT card says "Index 0/92" while the button says Codex 40/92.
   Pick one word ("Codex") everywhere and make the card count the same thing.
4. **The wild has the same voxel-staircase paths and flat grass** as the town had. The wild paths
   could get stepping-stone parts near the town edge, and terrain material overrides (MaterialService,
   set through the Rojo project) could give grass, ground and cobble better textures everywhere.
5. **Wild scatter repetition.** 1,123 wild props, mostly 3-4 models per area on random scatter.
   Same treatment as the town: composed scenes per area. Spider-lily patches (14 parts each,
   ~2,700 parts map-wide) should become a cheaper single mesh.
6. **Plot interiors are identical apart from the garden.** A new player's base is an empty dais and
   sealed slots. Once relics land it fills up, but the first minutes look bare.
7. **Sound levels need a listen.** Step volumes and the cricket/chime mix were set blind (no way to
   hear audio from here). Rosselle should walk grass, slate and the street with sound on.

## Rebirth cost review (proposal, not applied)

Today: first Rebirth costs 400M CE, then x4 each time. Simulated progression (SoftCap + B+) shows
the problem: by minute 15 a player has ~1 useful upgrade left and luck sits flat (~x125-131) from
minute 15 to 60, then R1 lands around 70-90 min. The real 35-minute playtest never reached a Rebirth.
Competitor RNG/collector games let you rebirth around 10-20 minutes in.

Core-loop simulator, 10 seeds, 2 hours (`tests/lib/coreLoopSim`):

| BaseCost | CostGrowth | R1 P50 | R1 P10-P90 | Rebirths by 2h |
| --- | --- | --- | --- | --- |
| 400M (now) | 4 | 68 min | 39-78 | 3 |
| 2M | 4 | 25 min | 20-30 | 14 |
| 1M | 10 | 22 min | 16-23 | 6 |
| **500K** | **10** | **17 min** | **11-19** | **7** |

Proposal: **BaseCost 500K, CostGrowth 10.** R1 lands at ~17 min (where upgrades run out), later
Rebirths stay spaced out (7 by 2h instead of 14 with the old x4 growth). Watch-out: more Rebirths
means more Rebirth luck early (x1.5 each), so rarity pacing should be re-checked in a playtest.
Balance change: needs Rosselle's OK.
