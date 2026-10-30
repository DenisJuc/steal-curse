# Progression Sim Performance

**Status:** Optimization only — no gameplay balance / SoftCap R/M / costs / Rebirth changes.

## Bottlenecks (before)

| Hot spot | Cost |
|----------|------|
| Per-second loop × 10800 for 180m | Always woke every second |
| SoftCap `roll`: rebuild 92 weights every roll | Dominated rarity sampling |
| `rollMutation`: `require` MutationConfig/RollMath every roll | Extreme overhead in Lune |
| `incomePerSec` / `luck` recomputed every second/roll | Extra churn |

Old `phase34Proposal` FULL (~40 seeds × full matrix) ≈ **20–30 minutes**.

## Changes

1. **SoftCap weight sampler cache** (`SoftCapRarity.samplerFor`) — rebuild only when Luck / family / mult change.
2. **Mutation pick** — cached module refs + unlocked-by-rank lists; inline weighted pick.
3. **Event-driven tick** (`TickMode = "Event"`, default) — jump idle seconds between scan/hunt/buy/checkpoint; `PerSecond` kept for regression.
4. **Cached luck + income** — dirty on skill/unique/rebirth/equip/fusion.
5. **Modes:** `QUICK` / `STANDARD` / `FULL` on `tests/phase34Proposal`.
6. **Runtime reporting** + budget warnings (`tests/lib/simRuntime.luau`).

## Benchmarks (this machine)

From `lune run tests/simPerfBenchmark`:

| Metric | Result |
|--------|--------|
| SoftCap 50k rolls cached | **0.03s** |
| SoftCap 50k rolls invalidate-each (old cost) | **0.70s** (~22×) |
| Event vs PerSecond fingerprints (5 seeds × 180m) | **0 mismatches** |
| Event | ~**0.02s/seed** |
| QUICK-like 20 runs | **~0.6s** (budget 30s) |
| STANDARD estimate (240 runs) | **~5s** (budget 120s) |

`lune run tests/phase34Proposal QUICK` → **~0.4s**.

## Modes

```
lune run tests/phase34Proposal QUICK      # iterate
lune run tests/phase34Proposal STANDARD   # before recommending
lune run tests/phase34Proposal FULL       # final only
lune run tests/simPerfBenchmark           # regression + microbench
```

## Fusion STUB reminder

Proposal sims still use unbounded FusionIncome stack proxy. **Do not** implement Rebirth/CE changes from ×lift until board-slot `FusionIncomeMultByRank` is wired.
