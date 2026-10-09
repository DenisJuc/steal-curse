# Supernatural Relic Collector (Roblox)

An AFK-friendly supernatural relic collector. The game is built in small tested **slices**; this repo is currently at **Slice 2 - Persistence and probability core**.

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

## 6. Debug commands (Studio only)

Type these in the chat box during Play. They do not exist outside Studio.

| Command | What it does |
| --- | --- |
| `/help` | Lists all debug commands in chat |
| `/roll [count]` | Runs instant extra scans, e.g. `/roll 50` (max 1000) |
| `/roll <tier>` | Gives one relic of that tier, e.g. `/roll cosmic` |
| `/scanspeed <seconds>` | Changes your scan interval, e.g. `/scanspeed 0.5`; `/scanspeed reset` restores 4 s |
| `/wipedata` | Resets your data |
| `/hunt` | Teleports you to the Haunted Grove entrance |
| `/spawnsignal` | Spawns one of your signals right in front of you (ignores the 5-signal cap) |
| `/regen` | Refills your signals to the maximum (5) |
| `/bindtime <seconds>` | Changes your hold time, e.g. `/bindtime 1`; `/bindtime reset` restores 6 s |
| `/huntstats` | Shows captures, cancels and average time between captures this session |
| `/forgecomplete` | Pretends to be a cheater sending "capture complete" without holding; the server must reject it |
| `/forceroll <tier or relicId> [mutation]` | Gives an exact relic, e.g. `/forceroll cosmic abyssal` |
| `/simroll [count]` | Simulates rolls with your current luck/focus/frequency/mutation rank and compares them with the math (results in Output; nothing is granted). Max 1,000,000 |
| `/setluck <x>` | Extra debug luck multiplier, e.g. `/setluck 1e10`; `/setluck reset` |
| `/luckrank <0-100>` | Sets your Core Luck rank (rank 100 = 10 billion x) |
| `/focus <tier or max>` | Sets Rarity Focus, e.g. `/focus legendary` |
| `/freq <family or all>` | Sets Signal Frequency, e.g. `/freq demonic` |
| `/mutrank <0-5>` | Sets your Mutation Resonance rank |
| `/savestatus` | Save mode (real or mock), time since the last save, relic and Codex counts |
| `/runtests` | Runs the persistence tests on ProfileStore's mock store (never touches real data) |

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

## 8. Project layout

```
default.project.json   Rojo mapping of src/ into the Roblox game tree; declares all remotes
src/shared/            ReplicatedStorage.Shared - config and pure math used by server, client and tests
  Config.luau            tunable numbers (scan, plots, feed, remote limits, saving, focus, frequency, luck)
  RarityConfig.luau      the 8 rarity tiers and their base cumulative odds
  RelicConfig.luau       relic definitions (10 original placeholders)
  MutationConfig.luau    the 5 mutations, unlock ranks, weights and chance per rank
  RollMath.luau          ALL probability math: tiers, focus cap, frequency, mutations, joint odds, sampler
  RollRules.luau         RollMath rules assembled from config (shared by server rolls and UI odds)
  Stats.luau             chi-square and waiting-time helpers
  Formulas.luau          gameplay formulas (Core Luck, hunt bonus rolls)
  Format.luau            number / odds formatting (1.5K, 1 in 1.32Qd)
src/server/            ServerScriptService.Server
  Main.server.luau       builds the map, then starts services in order
  DiscoveryPipeline.luau the single path every relic grant goes through
  DebugCommands.luau     Studio-only chat commands
  Data/                  saved data template + migrations (pure, tested by Lune)
  Services/              one module per system (Data, Multiplier, Roll, Settings, Plot, Scan, Signal, Bind, RemoteGuard, GameEvents)
  Tests/                 Studio persistence tests (/runtests)
  World/                 code-built map (BuildUtil, MapBuilder, PlotBuilder, HuntAreaBuilder)
src/client/            StarterPlayerScripts.Client
  Main.client.luau       builds the UI and hunt controls
  UI/                    UIKit, HUD, FocusPanel, Odds, DiscoveryFeed, Toasts, HuntHUD
  Hunt/HuntController    Spirit Sight / pulse / hold-to-bind input and state
  Effects/               SpiritSight (orbs, trails, tint), BindEffects (chains, camera, seal flash)
  StudioCommands.luau    Studio-only /help and /forgecomplete
tests/                 Lune headless tests (lune run tests/run)
```

## 9. How the systems work

- **Server authority.** The server rolls every relic and owns all data. The client only displays results.
- **Passive scanner.** `ScanService` runs one loop for all players. Every 4 seconds (Config.Scan.BaseIntervalSeconds) each player gets exactly one relic. It never pauses for menus or effects. After a server hitch it grants at most 3 overdue scans.
- **Rolls.** `RollMath` uses the GDD tier odds (Uncommon+ 1 in 4 ... Cosmic 1 in 1.32 quadrillion). It climbs tier by tier, then picks a relic inside the tier by its weight, then rolls at most one mutation. The server and the UI build the same roll context with `RollMath.contextFor`, so every displayed "1 in X" is the real chance.
- **Luck.** `MultiplierService` multiplies every luck source (Core Luck rank now; Codex, Showcases, consumables and events later). Core Luck = 10^(rank/10), so rank 100 = 10 billion x.
- **Rarity Focus.** Picking a tier caps the luck used for rolls so that tier (or higher) comes up 50% of the time. Your bought luck is never removed; "Max Luck" uses all of it. Focus only lowers luck when your luck is above the cap.
- **Signal Frequency.** Picking a family (Demonic, Spiritual, Arcane, Astral) multiplies that family's weight inside whatever tier was rolled (1.5x at Frequency Focus rank 0, up to 3x at rank 5). It never changes tier chances.
- **Mutations.** Mutation Resonance rank 0 = none. Each rank unlocks one more (Golden, Corrupted, Bloodmoon, Divine, Abyssal) and raises the total chance (10% ... 50%). Weights 30/22/18/15/15 split that chance among unlocked mutations. A mutated relic counts as the same Codex entry as the normal one.
- **Discovery pipeline.** Every grant goes through `DiscoveryPipeline.GrantBatch`: store the relic, record a first Codex discovery (by base relic id), add Epic+ finds (and mutated Legendary+) to the rare history (last 50), request a priority save for rare finds, then tell the owner's client.
- **Saving.** ProfileStore autosaves every 5 minutes and saves when you leave and when the server shuts down. A first discovery, any Mythic+ or any mutated Legendary+ requests an extra save, merged to at most one save every 7 seconds. Limit: if a Roblox server crashes hard, finds made after the last completed save can be lost; priority saves keep that window to about 7 seconds for rare finds.
- **Plots.** 8 shrine plots surround the hub. Each player gets the first free plot, their name appears on the gate sign, and they spawn there. **Set Max Players to 8 or fewer** when publishing.
- **UI.** The top-left panel shows the scan progress bar, interval, total scans, relics held, signals sealed and a luck/focus button that opens the Rarity Focus & Odds panel (read from player attributes). The right-side feed shows each discovery with its tier (or mutation) color and base odds; "NEW!" marks first discoveries.
- **Haunted Grove.** A greybox hunting ground between plots 1 and 2, reached by its own path from the hub. Trees, rocks and ruined walls block line of sight. 15 hidden spawn points (tagged `SignalSpawn`) are where signals can appear.
- **Personal signals.** `SignalService` gives each player 3 signals at start, adds 1 every 2 minutes up to 5, and sends positions only to that player. Other players never see or receive them. All signals look identical, and no rarity exists until a capture succeeds.
- **Spirit Sight.** A client view mode: it hides the resonator panel, tints the screen, shows your signal orbs within 90 studs, and a pulse draws trails to all of them. Passive scanning keeps running.
- **Hold to Bind.** Within 12 studs you hold the bind input. The server checks the signal is yours, you are close, you aren't already binding and not on cooldown, then starts its own timer. After 6 seconds (server-measured) the client asks to complete; the server re-checks time, distance and that you're alive, consumes the signal, then rolls **1 captured relic + bonus relics** (11 at a 4 s scan interval: `max(10, ceil(0.35 x 120 / interval))`). Releasing early, moving away, dying or leaving cancels with no reward and keeps the signal (1.5 s cooldown).

## 10. Publishing (needed from Slice 2 for saving)

1. File > **Publish to Roblox**, create a new experience.
2. Home > **Game Settings** > **Security** > turn on **Enable Studio Access to API Services** > Save.
3. Game Settings > **Places** (or Avatar/World settings) > set **Max Players** to 8 or fewer.
