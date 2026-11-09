# Seal a Curse: handoff, end of Nov 9 2026

Read this first in a new session, then the roadmap artifact
(https://claude.ai/artifact/J3mXhZ3WUduLF8F1FFGxPj, `items` collection). The code is the authority.

## Working rules (from Rosselle)

- Claude is the main co-developer and may change code freely. **Commit locally anytime.**
  Ask first for: pushing, spending money/credits (Tripo), publishing places, balance/progression
  changes, anything that risks player saves. Never publish to Roblox. Never print ROBLOX_API_KEY.
- Branch `claude/project-thread-u2odko` pushes (fast-forward) to `origin/claude/project-thread-bpsr32`:
  `git push origin HEAD:claude/project-thread-bpsr32`.
- Don't disturb Rosselle's open Studio (`RelicCollector.rbxl`). Test in a second Studio: build
  `rojo build -o work/street/ShrineStreet.rbxl`, open it with RobloxStudioBeta.exe, use the
  `.studio-lock` file (create before, delete after). Click UI by `instance_path`.
- Checks: `lune run tests/run` (312 pass), `selene src` (baseline 2 errors, 17 warnings).
- Commit messages via a file (`git commit -F`); PowerShell breaks quoted `-m` messages.
- The Studio test player is flagged AFK and auto-rolls; move it with `PivotTo`; Studio's screenshot
  tool can leave the camera Scriptable.
- Rosselle wants plain short answers, they/them pronouns, and dislikes text-only UI.

## What was done on Nov 9 (all pushed except where noted)

- **Rebirth curve G** (0f83a29): 500K first, x8 per Rebirth, +50% income and +10% luck each, additive
  (`Rebirth.luau` IncomeStep/LuckStep). Not hand-playtested.
- **Journal removed**; its Zones tab is now the Codex's third tab (`UI/ZonesPage.luau`).
- **Base fixes:** paved strips between plots (no grass gap), showcase preview discs, no z-fighting
  (lanes, border, pads, seal ring, walls, kerbs, street slabs), pool lanterns removed, pool water
  blue, hub kiosks spaced, spawn moved in so the camera starts clear of the torii.
- **Codex:** Huge/Titanic cards taller with bigger renders (~1.7x / ~2.4x).
- **Footsteps:** soft step on grass/dirt only, Roblox's step on stone/wood; step rate follows speed.
- **Phones/performance:** Effects setting "Auto" (Low on touch devices), map touch/shadow flags
  trimmed, `Effects/DecorLOD.luau` parks far small wild props. Phone layout only code-audited
  (this PC's Studio can't be resized to a landscape phone viewport).
- **Music** (`Effects/Music.luau`, `Config.Music`): koto playlist in town, dark ambient in the wild,
  crossfading; ambience loops (crickets, rain, drones) play under it; Music volume setting.
- **Loading screen** (`src/first/LoadingScreen.client.luau`, ReplicatedFirst): preloads assets,
  koto track, seal-ring spinner, Skip. Looks are a first pass.
- **Intro hunt for new players** (`Config.Intro`, `shared/IntroLayout`, `World/IntroBuilder`,
  `Services/IntroService`, `client/Intro/IntroController`): wake-up cinematic in a cut-off glade,
  glowing fox spirit, pulse to track (it only flees after a pulse), twice, then hold to bind at a
  ruined shrine with the game's chain rig, seal circle, speed lines, impact frame, seal stamp,
  SEALED, home with the Warding Fox Mask. Skip always available. `data.IntroDone` (older saves are
  marked done). Commits 37142a6 and a4a80d0 (title card removed) were local at the time of writing;
  see git log.
- Rosselle's direction for the intro: the "anime opening" idea is a **philosophy** (best polish on
  the hook), not literal anime title cards. No "Episode" text.

## Priorities next (review of Nov 9, also on the roadmap as items 1-7)

1. Let players hunt right after the intro (Spirit Sight is locked until 50 rolls).
2. Skittish spirits in real hunts (reuse the intro chase).
3. Brighter, readable world on phones (the wild is near black).
4. Sealed-relic stand-in for the ~40% unmodelled relics on pedestals.
5. Limited-time event relics (balance change: needs Rosselle's call).
6. Server-wide great spirit event.
7. UI icon and button pass (menus are text-heavy).

Also open: Tripo credits reset Nov 10 (model batch, a real fox spirit for the intro), intro polish
and hand playtest, real-phone check, publish a private test place (Rosselle), passes/products ids.
