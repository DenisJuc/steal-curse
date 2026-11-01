# Seal a Curse v0.1: release checklist

Status on 2026-11-01. Everything listed as done is committed locally on `claude/project-thread-u2odko`. Nothing is pushed or published.

## Done (checked in Studio unless noted)

| Area | What | Where |
| --- | --- | --- |
| Core loop | Scan, reel, reveals (Legendary+ waits for a click), Codex, pedestals, rebirth | earlier work |
| Skill tree | Branch trees with icon nodes, lit paths, tap sheet with x1/x10/Max, sparks; Huge/Titanic Attunement and Kindred Spirits nodes; nodes unlock from the node above | `SkillTreePanel.luau`, `SkillConfig.luau` |
| Social | Celestial+ banner for the whole server, Cosmic server sound, friend luck bonus, town leaderboards and player list stats | `Announcements.luau`, `FriendService`, `LeaderboardService` |
| Retention | Daily/weekly bounties incl. sealing tasks, 7-day streak, playtime gifts saved per day, zone event countdown, Codex "N more" toast | `Bounties`, `PlaytimeService`, `BuffTimers` |
| Status | Floating relic carries its aura | `CosmeticEquipService`, `PedestalAuras` |
| Shop | 4 passes, 3 products, receipts confirmed only after the save | `ShopService`, `ShopPanel` |
| Codes | LAUNCH, SEALED; group reward ready | `CodeService` |
| Data | Onboarding funnel, rebirth, rare finds, CE flow to the Creator Dashboard (live servers only) | `LiveAnalytics` |
| Names | 75 relic display names de-parodied (ids unchanged) | `docs/RENAMES.md` |

Unit tests: `lune run tests/run` (295 passing).

## Rosselle must do

1. Publish a **private test place** (not the main game) and turn on API access, so real saves, leaderboards, receipts and the friend bonus can be tested with two accounts.
2. Create the 4 passes and 3 products on the Creator Dashboard and send their ids (`Config.GamePasses`, `Config.DevProducts`). Until then the shop shows "Soon".
3. Optional: create a Roblox group (100 Robux) and send its id (`Config.Group.GroupId`).
4. Restart `rojo serve` once (new remotes: RedeemCode, ClaimGroupReward, ServerLuckBought, ClaimPlaytimeGift).

## Known issues / not verified

- Real ProfileStore saves (collection, sizes, playtime gifts, purchases) are untested outside the Studio mock.
- Sealing bounties are unit-tested; not yet seen in Studio (today's random picks had none).
- Gift, code and bounty CE rewards use current income, which includes the Fortune potion buff.
- On very small screens (660x333) every menu is cramped; 844x390 is fine.
- The Auto Roll tutorial bubble covers the Upgrades button for that step.
- 45 of 92 relics still have no model (Tripo credits reset 2026-11-09).
- Live servers run the Studio balance trial on purpose (`BalanceTrials.ShipTrial`).

## First update after launch (suggested)

- The remaining relic models plus one new zone event.
- One new weekly bounty set and a Codex title.
- Review the Creator Dashboard funnel after the first week: fix the step with the biggest drop first.
