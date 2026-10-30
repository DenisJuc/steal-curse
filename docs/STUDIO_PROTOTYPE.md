# Studio prototype — soft A+C + paced collection (auto in Studio)

**Status:** Soft A+C + collection pacing prototype. **Live release blocked.**

## Automatic Studio activation

No manual edits required. On a Roblox Studio server:

- `RunService:IsStudio()` → trial `E20k_L12_C17_HR` + `CollectionPrototype` auto-on
- Published / production servers → always **LIVE** defaults (Studio trial fields ignored)

Kill switch (force live even in Studio):

```lua
BalanceTrials.StudioAutoDisabled = true
```

## Expected Server Output

```
[BalanceTrials] ACTIVE=E20k_L12_C17_HR
[BalanceTrials] CollectionPrototype=true | StudioAuto=true | ... MaxBonusRolls=6 maxTotalRolls=7
[DataService] Studio isolated ProfileStore.Mock — store="PlayerData_v2" (mock only; never touches production DataStores)...
[Main] Balance=E20k_L12_C17_HR Collection=true
[Main] Hunt cap: MaxBonusRolls=6 → maxTotalRolls=7 per spirit capture
```

If you see `LIVE defaults — not Studio`, you are not on a Studio server (or `StudioAutoDisabled`).

## Hunt cap

With the trial active, `MaxBonusRolls=6` applies **after** Resonant Harvest + streak/zone multipliers. Total rolls per spirit capture ≤ **7**.

## Soft A+C (trial only)

| Knob | Live | Trial Active |
|------|------|----------------|
| Rebirth LuckGrowth | 1.5 | **1.25** |
| Core Luck cost | growth 1.6 (config node) | base growth **1.7** × soft **(1+0.05·rank)^1.35** |
| IncomeGrowth | 2 | 2 (unchanged) |
| Epic/Legendary dens | live | 20k / 500k |

## Collection pacing (Studio auto)

- Board slots, targeted fusion recipes, mutation goals, Essence sinks
- ProfileStore in Studio uses **`.Mock` only** — never production DataStore keys

## Reproduce sims

```bash
lune run tests/studioProgression 100
lune run tests/essenceTiming 150
lune run tests/run
```

## Still not live

Do not ship trial economy as production defaults. Production ignores Studio auto-trial by design.
