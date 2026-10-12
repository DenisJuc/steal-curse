# Supernatural Relic Collector (Roblox)

An AFK-friendly supernatural relic collector. The game is built in small tested **slices**; this repo is currently at **Slice 8b - Relic model pipeline and 5-model Meshy pilot** (roster in `docs/ROSTER.md`, pilot steps in `docs/MESHY_PILOT.md`).

Design sources (outside this repo): `Supernatural_Relic_Collector_GDD_FINAL.md`, `CURSOR_RELIC_GAME_BLUEPRINT.md`, `ROBLOX_GAME_PLAYBOOK.md`.

---

## 1. One-time setup

You only do this once per computer.

1. Install **Roblox Studio** and **Git**.
2. Install **Rokit** (the tool manager): https://github.com/rojo-rbx/rokit
3. Open a terminal (PowerShell) in this folder (`C:\steal-curse`) and run:
   ```
   rokit install
   wally install
   rojo plugin install
   ```
   - `rokit install` downloads the pinned tools: Rojo 7.7.0, Selene 0.31.0, Wally 0.3.2, Lune 0.10.4.
   - `wally install` downloads ProfileStore into `ServerPackages/` (used from Slice 2).
   - `rojo plugin install` adds the Rojo plugin to Roblox Studio. Restart Studio afterwards if it was open.

## 2. Build and open the game

1. In the terminal, in this folder:
   ```
   rojo build -o build/RelicCollector.rbxl
   ```
2. Open `build/RelicCollector.rbxl` in Roblox Studio (double-click it, or File > Open from File).

## 3. Live-sync code while you work (Rojo)

1. In the terminal run:
   ```
   rojo serve
   ```
   Leave this terminal open.
2. In Studio: **Plugins** tab > **Rojo** > click **Connect**.
3. Code changes now appear in Studio automatically.

If `default.project.json` changes (for example when new remotes are added), stop `rojo serve` (Ctrl+C), start it again, and click **Connect** again in Studio. You will be told when this is needed.

## 4. Play test

- Press **Play** (Home tab, or F5). The map is built by server code when the game starts.
- For 2 players: **Test** tab > **Clients and Servers** > set Players to **2** > **Start**. Close all test windows with **Cleanup** when done.
- Phone layout check: **Test** tab > **Device** (Device Emulator), pick a phone.
- Watch for errors: **View** tab > **Output**. Red text means an error.

Data is saved with **ProfileStore**. In an unpublished place (or without API access) ProfileStore uses a **mock** store: saving works during the session but everything resets when you stop Play. For real saving across sessions, publish the place and enable API access (section 10). `/savestatus` tells you which mode you are in.

## 5. Hunt controls

| Action | Keyboard | Gamepad | Phone / mouse |
| --- | --- | --- | --- |
| Toggle Spirit Sight | F | Y | "Spirit Sight" button (bottom right) |
| Pulse (show trails to your signals) | Q | R1 | "Pulse" button |
| Hold to Bind (when close to a signal) | hold E | hold X | hold the "Hold to Bind" button |

Menus with a gamepad: press **View/Select** to jump onto the menu buttons (or the open menu), move with the D-pad or left stick, press **A** to click, **B** to close the menu. **B** (or Enter on a keyboard) also skips a big Celestial/Cosmic reveal.

## 6. Debug commands (Studio only)

Type these in the chat box during Play. They do not exist outside Studio.

| Command | What it does |
| --- | --- |
| `/help` | Lists all debug commands in chat |
| `/roll [count]` | Runs instant extra scans, e.g. `/roll 50` (max 1000) |
| `/roll <tier>` | Gives one relic of that tier, e.g. `/roll cosmic` |
| `/scanspeed <seconds>` | Changes your scan interval, e.g. `/scanspeed 0.5`; `/scanspeed reset` restores 4 s |
| `/wipedata` | Resets your data |
| `/hunt [forest, village or ruins]` | Teleports you to the middle of that wild area; with no word, of the area you are facing from the town |
| `/mapstats` | Map part count vs the part budget, props per area and the number of signal spots (also printed in Output) |
| `/modelcheck [all or clear]` | Builds a row of stands in front of you with every imported relic model and its warnings (details in Output); `all` also shows relics still without a model, `clear` removes the row. Output also lists which map props are imported, which are still primitive stand-ins, and any wrongly named file in `assets/MapProps` |
| `/spawnsignal` | Spawns one of your signals right in front of you (ignores the 5-signal cap) |
| `/regen` | Refills your signals to the maximum (5) |
| `/relocate` | Moves your signals near you right now |
| `/potion <luck, haste, fortune or all> [count]` | Gives you potions, e.g. `/potion all 3` |
| `/clearbuffs` | Ends every active potion buff |
| `/bindtime <seconds>` | Changes your hold time, e.g. `/bindtime 1`; `/bindtime reset` restores 6 s |
| `/huntstats` | Shows captures, cancels and average time between captures this session |
| `/forgecomplete` | Pretends to be a cheater sending "capture complete" without holding; the server must reject it |
| `/forceroll <tier or relicId> [mutation]` | Gives an exact relic, e.g. `/forceroll cosmic abyssal` |
| `/simroll [count]` | Simulates rolls with your current luck/focus/frequency/mutation rank and compares them with the math (results in Output; nothing is granted). Max 1,000,000 |
| `/setluck <x>` | Extra debug luck multiplier, e.g. `/setluck 1e10`; `/setluck reset` |
| `/luckrank <0-100>` | Sets your Core Luck rank (rank 100 = 10 billion x) |
| `/skill <node> <rank>` | Sets any skill rank for free, e.g. `/skill mutationresonance 3`, `/skill scanspeed 12` (no node = list of nodes) |
| `/grantshowcase <id or all>` | Unlocks a Showcase at level 1, e.g. `/grantshowcase crimsonthrone` |
| `/showcaselevel <id> <1-4>` | Sets an owned Showcase's level, e.g. `/showcaselevel simplestance 4` |
| `/focus <tier or max>` | Sets Rarity Focus, e.g. `/focus legendary` |
| `/freq <family or all>` | Sets Signal Frequency, e.g. `/freq demonic` |
| `/savestatus` | Save mode (real or mock), time since the last save, relic and Codex counts |
| `/runtests` | Runs the persistence tests on ProfileStore's mock store (never touches real data) |
| `/ce <amount>` | Adds Cursed Energy (negative removes), e.g. `/ce 20000`; `/ce set 0` |
| `/offline <seconds>` | Pays offline earnings as if you had been away that long and opens the Welcome Back screen, e.g. `/offline 3600` |
| `/pedlevel <slot> <level>` | Sets a pedestal's level directly, e.g. `/pedlevel 1 10` |
| `/give <relicId> [mutation or none] [count]` | Grants exact copies through the full pipeline (auto-sell, Codex), e.g. `/give SenzoBean golden 5` or `/give SenzoBean none 5` |
| `/codexfill [n]` | Marks the first n relics (rarity order; default all) as discovered without giving items |
| `/afksim [minutes]` | Simulates AFKing that long (the scans you'd have done, shrine CE, anti-AFK hops), then opens Welcome Back as if you just came back, e.g. `/afksim 60` (default 30) |
| `/afkhop` | Skips your idle timer to the anti-AFK warning; touch nothing for 15 s to see the hop message (Studio can't really teleport) |
| `/hints` | Replays the beginner hints |
| `/rollstyle [flicker\|flame\|omikuji]` | Switches the roll animation style (no name: the next one) |
| `/rolldemo [tier or relicId]` | Plays a roll in the current style without granting anything, e.g. `/rolldemo cosmic` |
| `/sealpose` | Plays the bind's seal pose on your character for 5 s and says which joint type it has |

## 7. Automated checks (run before every commit)

```
selene src
lune run tests/run
rojo build -o build/RelicCollector.rbxl
```

All three must finish with no errors and no warnings.

Rare-find waiting times under max boosts (mean, median, 90th percentile) can be printed with:

```
lune run tests/rareWaitReport
```

The roster's odds and balance (per-tier and per-relic "1 in X", family and object type counts, essential Codex time, Cosmic count tradeoff) can be printed with:

```
lune run tests/oddsReport
```

AFK shrine pacing (when pedestals 4, 5 and 6 get bought at base luck) can be printed with:

```
lune run tests/economyReport
```

## 8. Project layout

```
default.project.json   Rojo mapping of src/ into the Roblox game tree; declares all remotes
src/shared/            ReplicatedStorage.Shared - config and pure math used by server, client and tests
  Config.luau            tunable numbers (scan, plots, feed, remote limits, saving, focus, frequency, luck)
  RarityConfig.luau      the 8 rarity tiers and their base cumulative odds
  RelicConfig.luau       the 92 relics (tier, in-tier weight, family, object type, VFX profile, lore); briefs in docs/ROSTER.md
  MutationConfig.luau    the 5 mutations, unlock ranks, weights and chance per rank
  RollMath.luau          ALL probability math: tiers, focus cap, frequency, mutations, joint odds, sampler
  RollRules.luau         RollMath rules assembled from config (shared by server rolls and UI odds)
  Stats.luau             chi-square and waiting-time helpers
  Formulas.luau          gameplay formulas (Core Luck, hunt bonus rolls)
  Economy.luau           shrine economy formulas (pedestal costs/levels, income, selling, offline, Equip Best)
  AutoSell.luau          auto-sell rule order (decide), defaults and input cleaning
  CodexConfig.luau       Codex milestone data (essential pool, titles, family sets)
  Codex.luau             Codex rules: thresholds, progress, bonuses, frequency unlocks, collection-time math
  CodexBook.luau         the game's Codex built from the real config (server + UI)
  Presentation.luau      reveal categories and timings, the reveal queue, announcement rule
  ClientSettings.luau    the Settings menu options, defaults and validation
  SessionReport.luau     session report counting (Journal)
  AfkSummary.luau        Welcome Back AFK summary: when it shows and the "Unlocked" list
  RelicShapes.luau       placeholder relic shapes for relics without a model (also the display size of imported ones)
  RelicModels.luau       builds every relic visual: the imported model, or the placeholder shape if none
  ModelCheck.luau        imported model sizing and the /modelcheck warnings (tested by Lune)
  WorldLayout.luau       ring map math: which area a point is in (with blend weight), wild entry, signal spawn grid
  WildLayout.luau        wild landmarks (houses, ruins, signposts, bridges), path width, prop scatter rules
  MapPropConfig.luau     the 29 map props: size, collision, light, primitive fallback (tested by Lune)
  ItemConfig.luau        potions: effects, durations, stacking cap, drop sources, timer math (tested by Lune)
  CaptureFamilies.luau   the 5 shared capture animation families and their lengths
  CaptureSummary.luau    the captured-plus-bonus summary built after a capture
  SkillConfig.luau       the skill tree: nodes, cost curves, effects per rank, validated bulk buy
  ShowcaseConfig.luau    the Showcases, their shared level table, unlocks and accessories
  Showcases.luau         Showcase rules: active-only bonus, upgrade cost, unlock checks, accessories
  Format.luau            number / odds formatting (1.5K, 1 in 1.32Qd)
src/server/            ServerScriptService.Server
  Main.server.luau       builds the map, then starts services in order
  DiscoveryPipeline.luau the single path every relic grant goes through
  DebugCommands.luau     Studio-only chat commands
  Data/                  saved data template + migrations (pure, tested by Lune)
  Services/              one module per system (Data, Economy, Pedestal, Sell, AutoSell, Inventory, Codex, Journal, Afk, Multiplier, Roll, Settings, Plot, Scan, Signal, Bind, Skill, Showcase, CosmeticEquip, Item, Travel, RemoteGuard, GameEvents)
  Tests/                 Studio persistence tests (/runtests)
  World/                 code-built map (BuildUtil, MapBuilder, HubBuilder, PlotBuilder, PedestalVisuals, ShowcaseVisuals,
                         WildBuilder: terrain, paths, stream, landmarks, scatter; MapProps + PropFallbacks: imported
                         map props or primitive stand-ins)
src/client/            StarterPlayerScripts.Client
  Main.client.luau       builds the UI and hunt controls
  UI/                    UIKit (style rules, palette, skinned panels/buttons, coin), Spring (spring animation),
                         Motion (button juice, pop, shake, shine, badges, counters, flying coins),
                         MenuMotion (menu open/close, blur and dim, PopIn stagger), Icons + IconAssets
                         (uploaded icon images, drawn placeholders until then), HUD,
                         menus (Shrine, Showcase, Focus, Inventory, AutoSell, SkillTree, Codex, Journal, Settings),
                         WelcomeBack, Onboarding, ReportCard, Odds, DiscoveryFeed, Toasts, Banner, HuntHUD,
                         RollBar, RollReel + RollStyles/ (RollKit, Flicker, Flame, Omikuji)
  Controllers/           RevealController (reveal queue and overlay), GamepadController (menu navigation),
                         AfkController (idle reports, anti-AFK hop), KioskController (hub kiosks open menus)
  Hunt/HuntController    Spirit Sight / pulse / hold-to-bind input and state
  Effects/               SpiritSight, BindEffects, ChainRig (mesh chains), SealPose (procedural seal pose),
                         SealBurst (jar seal), HuntFX (rune rings, shockwaves, bursts, camera shake),
                         HuntModels (hunt meshes), CaptureAnimation (5 families),
                         OtherBinds (other players' chains and captures), MutationVFX, RelicProjection,
                         ShowcaseLOD (Showcase lights/particles off when far or on Low effects),
                         Ambience (per-area fog, tint, particles, sounds), MapLightLOD (far map lights off)
  Settings / Sounds / Session / Announcements   client settings, sounds, discovery reports, chat announcements
  StudioCommands.luau    Studio-only /help, /forgecomplete, /afkhop, /hints, /sealpose, /rollstyle, /rolldemo
assets/RelicModels/    imported relic models, one <RelicId>.rbxm each (ReplicatedStorage.RelicModels)
assets/HuntModels/     hunt VFX meshes: SignalCore, OfudaTalisman, ChainLink, SealJar (ReplicatedStorage.HuntModels)
assets/MapProps/       imported map props, one <PropId>.rbxm each (ServerStorage.MapProps; ids in MapPropConfig)
docs/                  ROSTER.md (relic briefs and odds), MESHY_PILOT.md (model import steps)
tests/                 Lune headless tests (lune run tests/run)
```

## 9. How the systems work

- **Server authority.** The server rolls every relic and owns all data. The client only displays results.
- **Passive scanner.** `ScanService` runs one loop for all players. Every 4 seconds (Config.Scan.BaseIntervalSeconds) each player gets exactly one relic. It never pauses for menus or effects. After a server hitch it grants at most 3 overdue scans.
- **Rolls.** `RollMath` uses the GDD tier odds (Uncommon+ 1 in 4 ... Cosmic 1 in 1.32 quadrillion). It climbs tier by tier, then picks a relic inside the tier by its weight, then rolls at most one mutation. The server and the UI build the same roll context with `RollMath.contextFor`, so every displayed "1 in X" is the real chance.
- **Luck.** `MultiplierService` multiplies every luck source (Core Luck rank, Codex and the active Showcase now; consumables and events later). Core Luck = 10^(rank/10), so rank 100 = 10 billion x.
- **Rarity Focus.** Picking a tier caps the luck used for rolls so that tier (or higher) comes up 50% of the time. Your bought luck is never removed; "Max Luck" uses all of it. Focus only lowers luck when your luck is above the cap.
- **Signal Frequency.** Picking a family (Demonic, Spiritual, Arcane, Astral) multiplies that family's weight inside whatever tier was rolled (1.5x at Frequency Focus rank 0, up to 3x at rank 5). It never changes tier chances.
- **Mutations.** Mutation Resonance rank 0 = none. Each rank unlocks one more (Golden, Corrupted, Bloodmoon, Divine, Abyssal) and raises the total chance (10% ... 50%). Weights 30/22/18/15/15 split that chance among unlocked mutations. A mutated relic counts as the same Codex entry as the normal one.
- **Discovery pipeline.** Every grant goes through `DiscoveryPipeline.GrantBatch`: store the relic, record a first Codex discovery (by base relic id) and any new mutation, add Epic+ finds (and mutated Legendary+) to the rare history (last 50), auto-sell (rules, then capacity), claim Codex milestones, add to the AFK log if you're AFK, request a priority save for rare finds, then tell the owner's client. New finds are never put on pedestals automatically.
- **Saving.** ProfileStore autosaves every 5 minutes and saves when you leave and when the server shuts down. A first discovery, any Mythic+ or any mutated Legendary+ requests an extra save, merged to at most one save every 7 seconds. Limit: if a Roblox server crashes hard, finds made after the last completed save can be lost; priority saves keep that window to about 7 seconds for rare finds.
- **Cursed Energy (CE).** The only currency. Every second, each relic displayed on a pedestal pays its tier's CE/min (Common 10 ... Cosmic 20,000) x its mutation multiplier (Golden 1.5x ... Abyssal 4x) x the pedestal's level multiplier (x1 at level 1 up to x2 at level 10). Global income bonuses (Codex, the active Showcase and Energy Conduction) add together into one multiplier applied once.
- **Pedestals.** Pedestals 1-3 are free. Pedestals 4, 5 and 6 cost 500, 15,000 and 250,000 CE. Each pedestal has its own level 1-10; level 1 to 2 costs 500 CE and each next level costs double (255,500 CE for a full pedestal). "Max" buys as many levels as you can afford. Levels stay with the pedestal when relics move.
- **Shrine vs Relics menus.** The **Shrine** menu is only about pedestals: buy, upgrade, lock, and what each one earns. **Choose** on a pedestal opens the Relics menu in pick mode ("Pick a relic for pedestal 3"): tap a relic to place it, or **Empty pedestal** / **Back**. The **Relics** menu is the one list of your relics: tap one to select it, then use the bar at the bottom (**Equip/Unequip**, **Sell 1**, **Sell all**, **Lock**, **Favorite**). **Equip** puts one copy on the unlocked pedestal where it adds the most CE/min; **Unequip** takes it off every unlocked pedestal.
- **Equip Best.** Pedestals only change when you place a relic yourself or press **Equip Best** in the Relics menu. Equip Best fills every unlocked pedestal with your highest-earning relics, the best one on the highest-level pedestal, and tells you how much CE/min it added. Locked pedestals and their relics are never touched. Displayed relics stay in your inventory and can't be sold. (GDD 6.4 describes an optional automatic display; replaced by this button on request.)
- **Selling.** A sale pays 1% of one minute of that relic's income, so Commons sell for 0.1 CE: a small top-up, not the main income. Displayed and locked copies are never sold by any path.
- **Inventory.** Every relic is its own item with a unique id; the Relics menu groups them by relic + mutation and shows base and your current "1 in X" odds. Capacity is 100 (Config.Inventory). **Favorite** (per relic + mutation) pins it to the top and auto-sell never sells new copies. **Lock** stops the copies from being sold at all. **Inventory full:** at 100 relics the resonator pauses (red "[INVENTORY FULL]" in the HUD and a red message) and resumes with a fresh timer as soon as you sell something. Other sources (signal captures, debug grants) still work when full: a find the rules would keep is sold instead, unless it is a first discovery, Legendary or rarer, or a mutated Epic or rarer; those go over the limit ("protected") and are never discarded.
- **Auto-sell.** Runs on new finds. Rule order (first match wins): favorite = keep; first discovery = keep if "Protect first discoveries" is on; mutated = keep if "Protect mutated relics" is on; rarity rule Sell All = sell; duplicate with Sell Duplicates (or the global "duplicates of every rarity" toggle) = sell; base odds more common than your "1 in X" setting = sell; otherwise keep. A duplicate means you already hold a copy of the same relic that earns at least as much, so a stronger mutated copy is never a duplicate. The rules menu previews what happens to your next find of each relic. Sold finds show in the feed with the CE earned and the reason.
- **Codex.** Every first find is recorded by base relic id, even if it is auto-sold right away; mutated finds count for the same entry and add a colored mutation dot on the relic's card. A reached milestone puts a "!" on the Codex icon; open the Codex and press **Claim** (or **Claim all**) to get the reward, confirmed by a banner at the top of the screen. Rewards only apply once claimed. Reached and claimed milestones are saved and never taken away:
  - Essential (unique Common-Legendary relics, any mutation counts): at 20/40/60/80/100% of that pool you get +5/+10/+10/+10/+15% Luck (total +50%) and +5% CE income at each step from 40% (total +20%). Mythic and rarer relics never gate power.
  - Family frequencies: discovering half of a family's Common-Legendary relics unlocks its Signal Frequency (a family with none starts unlocked). All of them gives a "<Family> Archivist" title.
  - Prestige titles: half / all of the roster, and any mutated Legendary+ or Cosmic. Titles only, no power.
  Counts are fractions of the pool (70 essential relics in the current roster); earned milestones stay earned when relics are added.
- **Skill tree** (rune tree icon). Everything is bought with CE; there are no skill points. **Resonance:** Core Luck (x10 luck every 10 ranks, 100 ranks, cost 20 x 1.12^rank), Scan Speed (4 s down to 1 s over 12 ranks), Frequency Focus (Signal Frequency x1.5 up to x3) and Mutation Resonance (unlocks mutations; costs are provisional until balancing). **Sanctuary:** Energy Conduction (+2% income per rank, 20 ranks), Spirit Merchant (+10% sell value per rank), Spirit Reservoir (offline cap 2 h -> 3 h -> 4 h). **Binding Arts:** Spirit Sight (see signals 15 studs farther and pulse 0.3 s sooner per rank), Binding Efficiency (hold to bind 0.5 s shorter per rank), Resonant Harvest (+10% bonus finds per capture per rank, rounded up) and Swift Step (+4 walk speed per rank, 16 up to 56 over 10 ranks; set by the server on every spawn). **+1**, **+10** and **Max** buy ranks one at a time on the server, and stop at the first rank you can't afford. All numbers live in `SkillConfig` and Lune checks them against the GDD.
- **Showcases** (Shrine menu > **Showcases >**). A Showcase is a display/pose setup on your plot's podium. There are three: **Simple Stance** (bought for 25K CE), **Crimson Throne** (unlocked by discovering Sukana's Finger, a Mythic) and **Golden Guardian** (unlocked by reaching the Codex 60% milestone). Relic and Codex unlocks happen automatically. Every Showcase uses the same levels: Lv 1 +2% income / +1% luck, Lv 2 +5% / +3% (5K CE), Lv 3 +10% / +5% (250K), Lv 4 +15% / +10% (5M). Only the **active** Showcase gives its bonus; switching is free and moves the bonus at once. Higher levels look grander: Lv 2 adds an aura ring and light, Lv 3 sparkles and orbiting ornaments, Lv 4 a light pillar and big ornaments. Far away (150+ studs) or on Low effects, the lights, sparkles and pillar are switched off on your screen. Each Showcase has a cosmetic accessory that unlocks when you discover a particular relic, and you can show or hide it. Posing is optional: on your podium press **G** (gamepad L1 or tap the prompt) to sit on the throne or strike the pose. Moving ends a standing pose.
- **Carried relic.** In the Relics menu, **Carry** makes the selected relic float beside you; press again (**Hold**) to hold it in your hand, and once more (**Put away**) to stop. Everyone sees it. It's for show only: it stays in your inventory, gives no bonus, and disappears if you sell the last copy.
- **Offline earnings.** Scanning stops when you leave. Your CE/min at the moment you left pays 25% for up to 2 hours of absence (3-4 h with Spirit Reservoir), once, when you return (nothing for absences under a minute). The **Welcome Back** screen shows it (no relics are found offline).
- **Reveals.** Rewards are granted and saved first; reveals only show them and never slow scanning or movement. Common-Rare: a small spectral copy of the relic floats above your head (0.5 s) plus the feed line. Epic-Mythic: a card with the spinning relic, a rarity-colored flash and a sound (about 1-2 s). Celestial-Cosmic: the screen dims, light rays spin, the camera zooms in, about 3-5 s, with a **Skip** button. A mutated find shows the base relic first, then "+ ABYSSAL MUTATION (x4 income)" in the mutation color. Reveal cards play in the order you found them; if more than 3 are waiting, the least rare waiting one is skipped and the next card says "+N more rare finds in your Journal". Mutations use one reusable look (tint, outline, sparkles) on any relic.
- **Announcements.** A Celestial or rarer find (or a mutated Mythic or rarer) posts one colored line in everyone's chat: "[RELIC] Name found ... (Cosmic, 1 in 1.32Qd)!". At most one per batch (Config.Announce).
- **Journal** (scroll icon). This session's report (time, scans, discoveries, new relics, best find, best mutation, auto-sold, shrine income) and your saved rare finds (Epic or rarer, mutated Legendary or rarer; last 50) with base odds and how long ago.
- **AFK.** AFKing in game just keeps scanning; nothing pops up while you play. After 1 minute with no input you're marked AFK and the stretch is logged and saved (scans, finds, auto-sales, shrine CE). **Anti-AFK:** Roblox disconnects players idle for 20 minutes, so at 17 minutes a banner warns you and 15 s later you're moved to a fresh server of the game and keep AFKing (any input cancels). **Welcome Back** opens when you open the game again, or when you come back after one or more anti-AFK hops: the total CE (offline earnings plus the AFK stretch), the AFK stats, and a scrollable **Unlocked** list (new relics, new mutation variants, rare finds with counts, Codex milestones ready to claim; best first). Coming back in the same server without a hop shows nothing. "Welcome Back summary" in Settings turns the AFK part off.
- **Settings** (gear icon). Visual effects Full/Low, rare reveals Full/Short/Off, camera effects On/Reduced, a sound volume slider (drag it, or use -/+), interface size Small/Medium/Big, Welcome Back summary, beginner hints. Saved with your data.
- **Beginner hints.** New players get six short tips in the first minute, each pointing at the thing it explains (Next / Skip tips). Turn "Beginner hints" back on in Settings to replay them.
- **Phones and gamepads.** On short screens (phones) the HUD buttons wrap into rows of three and the feed shows 2 lines; everything scales with the screen and the Interface size setting. Gamepad: see section 5.
- **Sounds.** Placeholder sounds from Roblox's built-in library (Config.Sounds) until Slice 8 adds real audio.
- **Plots.** 8 shrine plots surround the hub. Each player gets the first free plot, their name appears on the gate sign, and they spawn there. **Set Max Players to 8 or fewer** when publishing.
- **UI.** Top-left column, one under the other: the Spirit Resonator box (scan progress, interval, scans, relics held, signals sealed), your Cursed Energy number, a **pedestal** icon (Shrine menu: buy, upgrade and lock pedestals, CE/min), a **cursed lucky flower** (Luck menu: Rarity Focus, Signal Frequency, live odds), a **chest** (Relics menu: your relics, Equip Best, equip, sell, lock, favorite, carry, Auto-Sell Rules), a **rune tree** (Skills menu), a **book** (Codex menu: milestones, titles, relic cards), a **scroll** (Journal) and a **gear** (Settings). Menus open in the screen center, fit phone screens and scroll when they don't fit. The top-middle feed shows each discovery with its tier (or mutation) color and base odds; "NEW!" marks first discoveries. Server messages (errors, debug replies) appear at the bottom center. Icons come from game-icons.net (CC BY 3.0, credited in the game description): white 512 px PNGs uploaded to Roblox, with their image ids in `UI/IconAssets.luau`. The game tints them gold with a soft shadow; any icon left empty keeps its frame-drawn placeholder (`UI/Icons.luau`), and text buttons (travel, hunt) simply show no icon.
- **UI feel.** Dark mystic shrine style: plum-to-ink panels with gold trim, gold for value, violet for actions, vermilion for refusals. Every button grows on hover, squishes on press and bounces back with hover/click sounds (gold outline on gamepad). Menus pop open with a spring, shrink closed, blur and dim the world behind them (no blur on Low effects), and close when you click empty space. CE rolls up instead of jumping; a windfall (more than 5 seconds of passive income at once, like a sale) bursts coins into the counter. In the Skills menu, rows pop in one by one, a purchase flashes the row gold and springs its rank bar forward, and buttons you can't afford shake and say how much CE is missing. Every menu works the same way: rows pop in (anything marked with the `PopIn` attribute), purchases and upgrades flash gold with the purchase sound, claims shine, and sales and collections fly coins from the button you pressed into the counter. Outside menus: the banner springs in with a light sweep, potion pills pop in and bounce through their last 10 seconds, travel buttons grey out and say when they're ready, the hunt buttons pop in when they become usable (Pulse shines when it recharges) and the capture card pops open. `Toasts.Show(text, kind?)` shows a short pill message from any client script.
- **Hub.** The plaza in the middle has the obelisk (replaced by the `HubTemple` prop once imported), stone lanterns, the spawn, a signpost pointing at the three wild areas, and five kiosks: **Codex Archive** (Codex), **Rune Monolith** (Skills), **Fortune Shrine** (Luck), **Relic Keeper** (Relics) and **Journal Board** (Journal). Walk up to one and press the prompt (E / tap) to open that menu.
- **Open world.** The shrine town (hub + plot ring at 140 studs, out to 190 studs) sits inside one continuous wild ring (190-410 studs) with no walls between areas: **Haunted Forest** (around 22.5 degrees: an ancient tree, dead trees, Jizo statues, glowing mushrooms), **Abandoned Village** (around 157.5: a bell tower, ruined houses and huts, a well, a cart, crates) and **Ancient Ruins** (around 292.5: a giant guardian head, arches, rune obelisks, broken pillars). Each area's path leaves town through a gap between two plots (Lune checks the clearance). Within 25 degrees of a border the two areas mix their terrain, props and ambience. Terrain grass/mud/rock paints the ground, glowing paths lead from the town to the edge of each area, a stream circles the ring (six bridges), and hills plus an invisible wall close the outer edge. Landmark positions live in `WildLayout`; props are scattered by seeded rules per area.
- **Map props.** Every map object (trees, houses, lanterns, pillars, kiosk props...) is a prop id in `MapPropConfig`. Drop `assets/MapProps/<PropId>.rbxm` (one model per file, made in Tripo or similar) and restart `rojo serve`: the server scales it to the configured height, gives it a simple box collider and its light. Until then a primitive stand-in is built and tagged `ModelNeeded`. `/modelcheck` lists the status.
- **Ambience.** Your screen's fog, tint, floating particles (fireflies, embers, glyphs, low mist) and optional ambient loops follow the area you stand in and blend at borders (`Config.Ambience`; the sound ids are empty until real tracks are chosen). Low effects turns the particles off; map lights farther than 120 studs (or all, on Low) are switched off on your screen.
- **Rolling.** A roll charges every scan interval (4 s base). With **Auto Roll** on (the default) the bottom bar shows only Backpack, a slim AUTO ROLL pill that fills as the next roll charges (red "FULL" when the backpack is full; click it to turn auto off) and Upgrades; with it off the big ROLL button appears and waits for a press (R / L1). Each roll plays out above the bar in the style picked in Settings > **Roll style** (`UI/RollStyles`): **Omikuji** (default) rattles a fortune box, unrolls a paper slip in about a third of a second, then flickers relics on the paper with a rising tick until the result sticks and a seal in its tier color stamps down; **Flicker** does the same cycling on a plain plate; **Flame** climbs a spirit flame through the tier colors before bursting into the relic. All three tease rarer results (cosmetic only; the server already rolled the result) and hit harder the rarer the landing (`RollKit.impact`): every landing bursts, Rare adds sparks, Epic a light sweep, and Legendary and up add turning light rays, a screen flash, a camera kick (off with Camera effects: Reduced) and a heavy stamp sound, each tier bigger; Celestial and Cosmic white out first and Cosmic's seal cycles rainbow. Legendary and up also get a hush before landing (0.45 s, up to 1.2 s for Cosmic; half on Fast): the relic hides behind "? ? ?", the world dims, the paper trembles in a pulsing aura of the result's tier color while heartbeat ticks quicken and a riser builds. Roll length is 60% of the scan interval, 0.35 to 1.6 s ("Fast" 0.35 s, "Off" none).
- **Potions** (Backpack > **Items**). **Luck Potion** (x2 luck, within the GDD's x2 consumable cap), **Haste Potion** (rolls charge in 75% of the time) and **Fortune Potion** (+50% CE income, added to the other income bonuses). Each lasts 10 minutes; using another of the same kind adds 10 minutes, up to 60 (a full timer refuses another). Timers only count down while you are online and are saved. Active timers show at the bottom right. Earned only by playing: a 12% chance per hunt capture, fixed rewards when you claim some Codex milestones (Essential 20/40/60/80/100%, Collection 50%) and a one-time reward for your first Legendary-or-rarer find. All numbers live in `ItemConfig` (tested by Lune).
- **Travel.** Top-right **Home** (your shrine), **Hub** (the plaza) and **Wild** (straight out to the nearest edge of the wild) buttons. The server picks the spot, there is a 4 s cooldown, and travel is refused while you are binding.
- **Relic models.** `RelicModels.build` makes every relic visual: pedestals, the reveal card, the capture summary card, the carried relic, and the glowing silhouettes (projection above your head, capture animation). If `assets/RelicModels/<RelicId>.rbxm` exists, its first part is used, scaled to the placeholder's size (optional `DisplayScale` / `DisplayRotation` attributes fine-tune it). Otherwise the placeholder shape is shown and tagged with a `ModelNeeded` attribute. Glowing silhouettes strip the texture and glow in the tier color.
- **Part budget.** The server counts the map's parts at start and prints a `[Map]` summary in Output (parts vs the 9000 budget, wild props, signal spots; a warning if over). `StreamingEnabled` stays off unless that number or phone testing shows it is needed; `/mapstats` shows the current counts.
- **Personal signals.** `SignalService` gives each player 3 signals at start, adds 1 every 2 minutes up to 5, and sends positions only to that player. Other players never see or receive them. All signals look identical, and no rarity exists until a capture succeeds. Signals appear anywhere in the wild, 25-90 studs from you (from the nearest wild edge while you are in the town), on a generated grid of spots that avoids landmarks, props and the stream. They **follow you**: walk 160 studs away from all of them and they move near you again (same count; one you are binding stays put). The hunt line above the buttons shows which area they are in, e.g. "Ancient Ruins: signals 3/5".
- **Spirit Sight.** A client view mode: it hides the resonator panel, tints the screen and shows your signals within 90 studs. Each signal is a spirit core circled by three ofuda talismans above a rune ring, with a light pillar; the ring lights up and the talismans speed up once you are close enough to bind. A pulse sends a ground shockwave and a wisp flying to every signal; each pings when its wisp arrives and shows its pillar for 4 s, even beyond 90 studs. Every signal looks identical (no rarity hints). Passive scanning keeps running. Meshes come from `assets/HuntModels` (primitives if missing).
- **Hold to Bind.** Within 12 studs you hold the bind input. The server checks the signal is yours, you are close, you aren't already binding and not on cooldown, then starts its own timer. After 6 seconds (server-measured) the client asks to complete; the server re-checks time, distance and that you're alive, consumes the signal, then rolls **1 captured relic + bonus relics** (11 at a 4 s scan interval: `max(10, ceil(0.35 x 120 / interval))`). Releasing early, moving away, dying or leaving cancels with no reward and keeps the signal (1.5 s cooldown). While binding, your character drops into a braced seal pose (palm thrust at the spirit, other hand gripping the wrist, trembling harder as it tightens, a two-handed yank at the end), iron chains shoot from the hand into the spirit, the talismans lock into a seal and one burns away per chain beat (1/3, 2/3, the last at the pull at 90%), and the camera closes in and shakes. Then, with the camera still on it, a spirit jar rises, swallows the spirit and slams shut (flash, shockwave and burst that grow with the captured relic's tier) before the capture animation rises out of it. All UI except the bind bar and hint is hidden until you let go, and Spirit Sight can't be left mid-seal.
- **Capture presentation.** After a successful capture the relic appears where the signal was and plays its family's animation (about 1.5 s), then flies into you: **Weapons** spin up and cut a slash arc, **Books/Scrolls** fan pages around them, **Masks/Vessels** turn to stare at you inside a ghostly aura, **Crystals/Fragments** pull orbiting shards together, **Special/Legendary** artifacts rise in orbiting sparks and burst with light. Five shared animations cover every relic. Low effects keeps only the relic's motion.
- **Capture summary.** Then a card shows the captured relic (spinning model, name, rarity, base odds, mutation, NEW!), "+N bonus discoveries", the 3 most notable bonus finds, and how many were new or auto-sold. Tap it or wait 6 s. Big reveal cards for rare finds (Epic and up) wait until the card closes, so nothing overlaps.
- **Other players' hunts.** Other players within 200 studs see your seal pose and chains into a plain spirit while you bind (never your signals or anything about rarity), and the jar seal plus the captured relic's animation flying into you. This is cosmetic and drawn on each viewer's screen from attributes the server sets.

## 10. Publishing (needed from Slice 2 for saving)

1. File > **Publish to Roblox**, create a new experience.
2. Home > **Game Settings** > **Security** > turn on **Enable Studio Access to API Services** > Save.
3. Game Settings > **Places** (or Avatar/World settings) > set **Max Players** to 8 or fewer.
