# Progression Parameter Sweep (Phase 0)

**Status:** Simulation only. Live economy defaults were **not** changed.

## Executive summary

| Finding | Evidence (upgrader, 200 seeds) |
|---------|--------------------------------|
| Baseline is broken for the playtest loop | Epic P50 **4.2 min**; mean **61.5** Epic drops by 15 min; luck ~×124 @15 |
| Raising Epic denom alone helps a lot | Epic 5k→20k cuts @15 Epic totals from 61 → ~0.2–2.5 |
| Slowing luck curve matters as much as denoms | `10^(rank/12)` + cost 1.7 keeps luck @15 ~×15 instead of ×124 |
| Passive (no upgrades) almost never hits Epic once denoms rise | Population Epic P50 is **—** for most non-baseline rows (reach rate 8–32%) |
| Active hunting still beats upgrader AFK | Hunter Epic P50 earlier than upgrader on every candidate |
| Hunt reform (cap + decouple + ×5) barely changes upgrader; mainly caps hunter spam | Compare `E20k_L12_C17` vs `_HR` — identical upgrader row; hunter @15 Epic 0.4 either way at this denseness |
| Rebirth@~25 min was a baseline artifact | Stronger rows push Rebirth P50 to **~90–120 min** (still often in the 60–150 test band) |
| Phase 2 chase systems are still required | Significant-event gaps grow to ~2–3 min mean; without Essence/fusion, slower rarity is emptier waiting |

**P10/P50/P90** = time when that fraction of **all** seeds have achieved the event (not conditional on success). `—` means fewer than that fraction succeeded within 2h. **Epic% / Leg%** = reach rate by 2h.

Reproduce: `lune run tests/progressionSweep 200` (or `500`). Harness: [`tests/lib/progressionSweep.luau`](../tests/lib/progressionSweep.luau), runner: [`tests/progressionSweep.luau`](../tests/progressionSweep.luau).

- Seeds per cell: **200** (identical seeds 1..N across every candidate × behaviour; use `500` for tighter tails)
- Duration: **2 hours** simulated
- Income: **frozen per-relic baseline** from live `RelicIncome` at luck 1 (weights/individual CE preserved; denom changes do not rewrite income)
- Luck stack in sim: Core Luck × Rebirth luck (no potions/Codex/Showcase — those would make rare finds *more* common)
- Scan Speed: purchased by upgrader/hunter; affects AFK roll rate; hunt bonus uses live scan unless candidate sets `ReferenceScanSeconds`

## Design targets (score against, not hard gates)

| Milestone | Passive | Active hunter |
|-----------|--------|---------------|
| First Epic | 45–75 min | 20–40 min |
| First Legendary | 2–4 h | 60–120 min |
| First Rebirth | test 90–150 min | test 60–90 min |

Optimization goal: **fun, meaningful progression, retention** — not maximizing time-to-Legendary.

## Behaviours

| Id | Meaning |
|----|---------|
| `passive` | Auto-scan only; **no** CE spending (luck stays ×1 aside from nothing) |
| `upgrader` | Auto-scan + cheapest upgrades + rebirth ASAP when affordable (playtest-like) |
| `hunter` | Upgrader + signal regen/captures (`CaptureCycleSeconds=12`) with candidate hunt tune |

## Baseline (live) — reference

### All candidates

| Candidate | Beh | Epic P10/P50/P90 (min) | Epic% | Leg P50 | Leg% | Rebirth P50 | Epic tot @15 / @60 | Luck @15 | Gap min |
|-----------|-----|------------------------|-------|---------|------|-------------|--------------------|----------|---------|
| baseline | passive | 3.1 / 22.2 / 72.7 | 97% | — | 10% | — | 0.5 / 1.8 | 1 | 27.1 |
| baseline | upgrader | 1.9 / 4.2 / 6.8 | 100% | 13.5 | 100% | 26.3 | 61.5 / 2074.4 | 124 | 0.6 |
| baseline | hunter | 0.6 / 2.3 / 4.3 | 100% | 10.7 | 100% | 23.4 | 128.4 / 2998.1 | 160 | 0.6 |
| E5k_L10_C16 | passive | 26.1 / — / — | 32% | — | 2% | — | 0.1 / 0.2 | 1 | 52.7 |
| E5k_L10_C16 | upgrader | 4.9 / 9.9 / 14.9 | 100% | 31.6 | 100% | 47.5 | 2.5 / 289.2 | 52.5 | 0.7 |
| E5k_L10_C16 | hunter | 2.2 / 7.8 / 12.2 | 100% | 25.8 | 100% | 41.8 | 5.0 / 529.6 | 68.6 | 0.7 |
| E10k_L10_C16 | passive | 40.1 / — / — | 23% | — | 2% | — | 0.0 / 0.1 | 1 | 51.0 |
| E10k_L10_C16 | upgrader | 5.5 / 11.5 / 19.5 | 100% | 42.0 | 100% | 60.1 | 1.3 / 88.3 | 47.7 | 0.9 |
| E10k_L10_C16 | hunter | 4.2 / 9.1 / 16.8 | 100% | 34.3 | 100% | 51.5 | 2.3 / 175.5 | 58.4 | 0.8 |
| E20k_L10_C16 | passive | 108.9 / — / — | 14% | — | 1% | — | 0.0 / 0.1 | 1 | 58.2 |
| E20k_L10_C16 | upgrader | 7.5 / 15.5 / 29.1 | 100% | 58.0 | 100% | 76.2 | 0.6 / 31.6 | 43.4 | 1.2 |
| E20k_L10_C16 | hunter | 5.4 / 13.4 / 24.2 | 100% | 46.3 | 100% | 64.1 | 1.1 / 55.5 | 49.7 | 0.9 |
| E40k_L10_C16 | passive | — / — / — | 8% | — | 0% | — | 0.0 / 0.0 | 1 | 61.9 |
| E40k_L10_C16 | upgrader | 8.3 / 21.9 / 37.5 | 100% | 76.8 | 96% | 93.9 | 0.3 / 13.4 | 41.7 | 1.6 |
| E40k_L10_C16 | hunter | 7.6 / 20.2 / 34.2 | 100% | 64.2 | 100% | 81.7 | 0.5 / 24.5 | 45.1 | 1.3 |
| E10k_L12_C16 | passive | 40.1 / — / — | 23% | — | 2% | — | 0.0 / 0.1 | 1 | 51.0 |
| E10k_L12_C16 | upgrader | 6.1 / 14.6 / 29.7 | 100% | 59.7 | 98% | 82.1 | 0.8 / 23.5 | 23.7 | 1.6 |
| E10k_L12_C16 | hunter | 5.2 / 12.2 / 24.4 | 100% | 50.2 | 100% | 70.6 | 1.1 / 38.1 | 25.8 | 1.3 |
| E10k_L15_C16 | passive | 40.1 / — / — | 23% | — | 2% | — | 0.0 / 0.1 | 1 | 51.0 |
| E10k_L15_C16 | upgrader | 8.0 / 20.5 / 40.9 | 100% | 99.2 | 72% | 114.2 | 0.4 / 7.0 | 11.9 | 2.8 |
| E10k_L15_C16 | hunter | 5.5 / 16.2 / 32.2 | 100% | 77.3 | 88% | 96.4 | 0.6 / 10.8 | 12.6 | 2.3 |
| E10k_L10_C17 | passive | 40.1 / — / — | 23% | — | 2% | — | 0.0 / 0.1 | 1 | 51.0 |
| E10k_L10_C17 | upgrader | 5.5 / 14.0 / 24.9 | 100% | 54.5 | 100% | 73.1 | 0.8 / 36.6 | 28.9 | 1.3 |
| E10k_L10_C17 | hunter | 4.2 / 11.5 / 21.8 | 100% | 43.1 | 100% | 62.2 | 1.5 / 64.0 | 33.8 | 1.1 |
| E10k_L12_C17 | passive | 40.1 / — / — | 23% | — | 2% | — | 0.0 / 0.1 | 1 | 51.0 |
| E10k_L12_C17 | upgrader | 7.2 / 18.2 / 35.2 | 100% | 75.7 | 88% | 95.0 | 0.5 / 11.1 | 15.6 | 2.3 |
| E10k_L12_C17 | hunter | 5.4 / 14.2 / 28.8 | 100% | 62.2 | 96% | 83.8 | 0.8 / 18.8 | 16.9 | 1.8 |
| E20k_L12_C17 | passive | 108.9 / — / — | 14% | — | 1% | — | 0.0 / 0.1 | 1 | 58.2 |
| E20k_L12_C17 | upgrader | 9.8 / 25.7 / 49.3 | 100% | 104.9 | 62% | 119.6 | 0.2 / 4.8 | 15 | 3.0 |
| E20k_L12_C17 | hunter | 7.6 / 21.2 / 42.8 | 100% | 90.2 | 76% | 107.2 | 0.4 / 7.6 | 15.7 | 2.4 |
| E10k_L12_C165_HR | passive | 40.1 / — / — | 23% | — | 2% | — | 0.0 / 0.1 | 1 | 51.0 |
| E10k_L12_C165_HR | upgrader | 7.4 / 17.2 / 34.5 | 100% | 68.5 | 96% | 89.5 | 0.5 / 14.6 | 18.7 | 2.0 |
| E10k_L12_C165_HR | hunter | 4.2 / 13.4 / 28.2 | 100% | 62.2 | 99% | 82.2 | 0.9 / 20.9 | 20.2 | 1.7 |
| E20k_L12_C17_HR | passive | 108.9 / — / — | 14% | — | 1% | — | 0.0 / 0.1 | 1 | 58.2 |
| E20k_L12_C17_HR | upgrader | 9.8 / 25.7 / 49.3 | 100% | 104.9 | 62% | 119.6 | 0.2 / 4.8 | 15 | 3.0 |
| E20k_L12_C17_HR | hunter | 7.2 / 21.3 / 40.0 | 100% | 92.2 | 73% | 110.0 | 0.4 / 6.5 | 15.7 | 2.6 |
| E40k_L15_C175_HR | passive | — / — / — | 8% | — | 0% | — | 0.0 / 0.0 | 1 | 61.9 |
| E40k_L15_C175_HR | upgrader | 20.2 / 55.3 / 119.5 | 90% | — | 12% | — | 0.1 / 0.9 | 7.57 | 4.6 |
| E40k_L15_C175_HR | hunter | 16.1 / 47.5 / 102.2 | 94% | — | 15% | — | 0.1 / 1.2 | 8.48 | 4.6 |

## Saturation detail (upgrader) — mean across seeds

| Candidate | t | Epic tot/uniq | Leg tot/uniq | Unique relics | Luck | CE/s | Rebirths |
|-----------|---|---------------|--------------|---------------|------|------|----------|
| baseline | 15 | 61.5 / 13.6 | 1.27 / 1.16 | 52.4 | 124 | 265K | (see rate) |
| baseline | 30 | 461.7 / 19.3 | 9.38 / 6.30 | 58.1 | 336 | 2.55M | (see rate) |
| baseline | 60 | 2074.4 / 25.8 | 282.94 / 12.80 | 64.6 | 11.8K | 165M | (see rate) |
| baseline | 120 | 5667.1 / 35.1 | 3316.82 / 22.07 | 73.8 | 11.9M | 624B | (see rate) |
| E5k_L10_C16 | 15 | 2.5 / 2.2 | 0.09 / 0.09 | 41.0 | 52.5 | 32.6K | (see rate) |
| E5k_L10_C16 | 30 | 21.4 / 10.3 | 0.80 / 0.76 | 49.1 | 199 | 321K | (see rate) |
| E5k_L10_C16 | 60 | 289.2 / 19.2 | 13.03 / 6.22 | 58.0 | 2.65K | 9.3M | (see rate) |
| E5k_L10_C16 | 120 | 3070.6 / 33.0 | 1177.89 / 20.02 | 71.8 | 3.04M | 107B | (see rate) |
| E10k_L10_C16 | 15 | 1.3 / 1.2 | 0.06 / 0.06 | 40.0 | 47.7 | 23.1K | (see rate) |
| E10k_L10_C16 | 30 | 8.7 / 6.0 | 0.32 / 0.30 | 44.9 | 154 | 181K | (see rate) |
| E10k_L10_C16 | 60 | 88.3 / 15.4 | 3.73 / 2.77 | 54.3 | 1.3K | 8.8M | (see rate) |
| E10k_L10_C16 | 120 | 1914.7 / 30.1 | 529.75 / 17.14 | 69.0 | 811K | 21.2B | (see rate) |
| E20k_L10_C16 | 15 | 0.6 / 0.6 | 0.01 / 0.01 | 39.5 | 43.4 | 13.3K | (see rate) |
| E20k_L10_C16 | 30 | 3.5 / 3.0 | 0.15 / 0.15 | 41.9 | 116 | 121K | (see rate) |
| E20k_L10_C16 | 60 | 31.6 / 11.6 | 1.39 / 1.18 | 50.5 | 1.04K | 5.64M | (see rate) |
| E20k_L10_C16 | 120 | 855.5 / 24.8 | 214.58 / 11.82 | 63.7 | 495K | 1.05T | (see rate) |
| E40k_L10_C16 | 15 | 0.3 / 0.3 | 0.01 / 0.01 | 39.2 | 41.7 | 10.6K | (see rate) |
| E40k_L10_C16 | 30 | 1.4 / 1.4 | 0.08 / 0.08 | 40.2 | 96 | 76.8K | (see rate) |
| E40k_L10_C16 | 60 | 13.4 / 7.0 | 0.58 / 0.49 | 45.8 | 962 | 7.95M | (see rate) |
| E40k_L10_C16 | 120 | 371.3 / 19.6 | 111.02 / 6.71 | 58.5 | 246K | 25.5B | (see rate) |
| E10k_L12_C16 | 15 | 0.8 / 0.7 | 0.04 / 0.04 | 41.1 | 23.7 | 17.3K | (see rate) |
| E10k_L12_C16 | 30 | 3.5 / 2.9 | 0.14 / 0.14 | 43.3 | 53.4 | 80.4K | (see rate) |
| E10k_L12_C16 | 60 | 23.5 / 10.7 | 1.03 / 0.93 | 51.1 | 202 | 909K | (see rate) |
| E10k_L12_C16 | 120 | 441.7 / 20.5 | 40.95 / 7.50 | 60.9 | 11.5K | 379M | (see rate) |
| E10k_L15_C16 | 15 | 0.4 / 0.4 | 0.02 / 0.02 | 42.5 | 11.9 | 11.8K | (see rate) |
| E10k_L15_C16 | 30 | 1.4 / 1.4 | 0.05 / 0.05 | 43.6 | 20.7 | 39.1K | (see rate) |
| E10k_L15_C16 | 60 | 7.0 / 5.3 | 0.21 / 0.20 | 47.5 | 44.7 | 201K | (see rate) |
| E10k_L15_C16 | 120 | 53.1 / 13.6 | 2.08 / 1.61 | 55.9 | 293 | 18.5M | (see rate) |
| E10k_L10_C17 | 15 | 0.8 / 0.8 | 0.04 / 0.04 | 40.4 | 28.9 | 17.8K | (see rate) |
| E10k_L10_C17 | 30 | 4.4 / 3.7 | 0.18 / 0.18 | 43.3 | 75.6 | 120K | (see rate) |
| E10k_L10_C17 | 60 | 36.6 / 12.6 | 1.53 / 1.33 | 52.2 | 382 | 6.56M | (see rate) |
| E10k_L10_C17 | 120 | 857.9 / 23.7 | 134.61 / 10.74 | 63.4 | 59.7K | 1.08B | (see rate) |
| E10k_L12_C17 | 15 | 0.5 / 0.5 | 0.03 / 0.03 | 41.5 | 15.6 | 12.7K | (see rate) |
| E10k_L12_C17 | 30 | 2.0 / 1.8 | 0.05 / 0.05 | 42.9 | 31.1 | 45.7K | (see rate) |
| E10k_L12_C17 | 60 | 11.1 / 7.2 | 0.41 / 0.40 | 48.3 | 79.3 | 355K | (see rate) |
| E10k_L12_C17 | 120 | 122.1 / 16.2 | 6.82 / 3.37 | 57.3 | 1.24K | 56.4M | (see rate) |
| E20k_L12_C17 | 15 | 0.2 / 0.2 | 0.01 / 0.01 | 41.3 | 15 | 9.29K | (see rate) |
| E20k_L12_C17 | 30 | 1.0 / 1.0 | 0.04 / 0.04 | 42.0 | 28.4 | 32K | (see rate) |
| E20k_L12_C17 | 60 | 4.8 / 3.9 | 0.20 / 0.19 | 45.0 | 63.9 | 438K | (see rate) |
| E20k_L12_C17 | 120 | 50.2 / 12.5 | 2.17 / 1.48 | 53.6 | 721 | 53.7M | (see rate) |
| E10k_L12_C165_HR | 15 | 0.5 / 0.5 | 0.03 / 0.03 | 41.5 | 18.7 | 13K | (see rate) |
| E10k_L12_C165_HR | 30 | 2.4 / 2.2 | 0.09 / 0.09 | 43.2 | 38.7 | 55.4K | (see rate) |
| E10k_L12_C165_HR | 60 | 14.6 / 8.6 | 0.57 / 0.53 | 49.6 | 110 | 584K | (see rate) |
| E10k_L12_C165_HR | 120 | 211.2 / 17.8 | 14.29 / 4.78 | 58.8 | 3.17K | 133M | (see rate) |
| E20k_L12_C17_HR | 15 | 0.2 / 0.2 | 0.01 / 0.01 | 41.3 | 15 | 9.29K | (see rate) |
| E20k_L12_C17_HR | 30 | 1.0 / 1.0 | 0.04 / 0.04 | 42.0 | 28.4 | 32K | (see rate) |
| E20k_L12_C17_HR | 60 | 4.8 / 3.9 | 0.20 / 0.19 | 45.0 | 63.9 | 438K | (see rate) |
| E20k_L12_C17_HR | 120 | 50.2 / 12.5 | 2.17 / 1.48 | 53.6 | 721 | 53.7M | (see rate) |
| E40k_L15_C175_HR | 15 | 0.1 / 0.1 | 0.00 / 0.00 | 43.0 | 7.57 | 6.68K | (see rate) |
| E40k_L15_C175_HR | 30 | 0.2 / 0.2 | 0.01 / 0.01 | 43.7 | 11.4 | 36.6K | (see rate) |
| E40k_L15_C175_HR | 60 | 0.9 / 0.8 | 0.04 / 0.04 | 44.3 | 22.7 | 1.81M | (see rate) |
| E40k_L15_C175_HR | 120 | 5.1 / 2.8 | 0.27 / 0.20 | 46.3 | 75.4 | 9.42M | (see rate) |

## Three strongest configurations (not auto-picked as winner)

Scored primarily on **upgrader** behaviour (matches the playtest), with hunter/passive checked for active advantage and AFK floor. Scoring penalizes Epic floods at 15 minutes and rewards Epic medians in a mid band, later Legendaries, feasible Rebirth, and significant events.

### #1: 'E20k_L12_C17' — Epic 20k, luck/12, cost 1.7, hunt baseline

**Parameters**

- Epic+ denom: **20000** (baseline 500)
- Legendary+ denom: **500000** (baseline 25000)
- Core Luck: `10^(rank/12)`, cost growth **1.7**
- Hunt: floor=10, factor=0.35, huntLuck=×1, refScan=live, maxBonus=none

**Upgrader (playtest-like)**

| Metric | This | Baseline |
|--------|------|----------|
| Epic P50 (min) | 25.7 | 4.2 |
| Epic reach rate (2h) | 100% | 100% |
| Mean Epic total @15 / @60 | 0.2 / 4.8 | 61.5 / 2074.4 |
| Legendary P50 (min) | 104.9 | 13.5 |
| Rebirth P50 (min) | 119.6 | 26.3 |
| Luck @15 | 15 | 124 |
| Mean significant events | 36.7 | 183.0 |
| Mean gap between significant (min) | 3.0 | 0.6 |

**Passive vs hunter**

| | Passive Epic P50 | Hunter Epic P50 | Hunter Epic@15 |
|-|----------------|-----------------|----------------|
| | — | 21.2 | 0.4 |

**Advantages**

- Much less Epic saturation in the first 15 minutes than baseline (addresses the playtest flood).
- First Epic arrives later for the typical upgrader, restoring a sense of rarity.
- Slower Core Luck climb reduces early ×100 luck without the most extreme cost ramps.

**Disadvantages / risks**

- Hunt still coupled to scan interval; active EV can explode once Scan is maxed.
- Collection systems (Essence, fusion, mutation unlocks) are **not** simulated; rarity timing alone understates midgame fun.

**Fit vs targets**

- Upgrader Epic vs active band 20–40: **in band** (P50=25.7 min)
- Passive Epic vs passive band 45–75: **miss (never)** (P50=— min)
- Upgrader Legendary vs 60–240: **in band**
- Upgrader Rebirth vs 60–150: **in band**

### #2: 'E20k_L12_C17_HR' — Epic 20k, luck/12, cost 1.7, hunt reform 4+×5

**Parameters**

- Epic+ denom: **20000** (baseline 500)
- Legendary+ denom: **500000** (baseline 25000)
- Core Luck: `10^(rank/12)`, cost growth **1.7**
- Hunt: floor=2, factor=0.08, huntLuck=×5, refScan=4, maxBonus=6

**Upgrader (playtest-like)**

| Metric | This | Baseline |
|--------|------|----------|
| Epic P50 (min) | 25.7 | 4.2 |
| Epic reach rate (2h) | 100% | 100% |
| Mean Epic total @15 / @60 | 0.2 / 4.8 | 61.5 / 2074.4 |
| Legendary P50 (min) | 104.9 | 13.5 |
| Rebirth P50 (min) | 119.6 | 26.3 |
| Luck @15 | 15 | 124 |
| Mean significant events | 36.7 | 183.0 |
| Mean gap between significant (min) | 3.0 | 0.6 |

**Passive vs hunter**

| | Passive Epic P50 | Hunter Epic P50 | Hunter Epic@15 |
|-|----------------|-----------------|----------------|
| | — | 21.3 | 0.4 |

**Advantages**

- Much less Epic saturation in the first 15 minutes than baseline (addresses the playtest flood).
- First Epic arrives later for the typical upgrader, restoring a sense of rarity.
- Hunt bonus decoupled from Scan Speed; Scan remains AFK QoL without multiplying capture loot.
- Slower Core Luck climb reduces early ×100 luck without the most extreme cost ramps.

**Disadvantages / risks**

- Collection systems (Essence, fusion, mutation unlocks) are **not** simulated; rarity timing alone understates midgame fun.

**Fit vs targets**

- Upgrader Epic vs active band 20–40: **in band** (P50=25.7 min)
- Passive Epic vs passive band 45–75: **miss (never)** (P50=— min)
- Upgrader Legendary vs 60–240: **in band**
- Upgrader Rebirth vs 60–150: **in band**

### #3: 'E10k_L15_C16' — Epic 10k, luck/15, cost 1.6, hunt baseline

**Parameters**

- Epic+ denom: **10000** (baseline 500)
- Legendary+ denom: **250000** (baseline 25000)
- Core Luck: `10^(rank/15)`, cost growth **1.6**
- Hunt: floor=10, factor=0.35, huntLuck=×1, refScan=live, maxBonus=none

**Upgrader (playtest-like)**

| Metric | This | Baseline |
|--------|------|----------|
| Epic P50 (min) | 20.5 | 4.2 |
| Epic reach rate (2h) | 100% | 100% |
| Mean Epic total @15 / @60 | 0.4 / 7.0 | 61.5 / 2074.4 |
| Legendary P50 (min) | 99.2 | 13.5 |
| Rebirth P50 (min) | 114.2 | 26.3 |
| Luck @15 | 11.9 | 124 |
| Mean significant events | 39.3 | 183.0 |
| Mean gap between significant (min) | 2.8 | 0.6 |

**Passive vs hunter**

| | Passive Epic P50 | Hunter Epic P50 | Hunter Epic@15 |
|-|----------------|-----------------|----------------|
| | — | 16.2 | 0.6 |

**Advantages**

- Much less Epic saturation in the first 15 minutes than baseline (addresses the playtest flood).
- First Epic arrives later for the typical upgrader, restoring a sense of rarity.
- Slower Core Luck climb reduces early ×100 luck without the most extreme cost ramps.

**Disadvantages / risks**

- Hunt still coupled to scan interval; active EV can explode once Scan is maxed.
- Collection systems (Essence, fusion, mutation unlocks) are **not** simulated; rarity timing alone understates midgame fun.

**Fit vs targets**

- Upgrader Epic vs active band 20–40: **in band** (P50=20.5 min)
- Passive Epic vs passive band 45–75: **miss (never)** (P50=— min)
- Upgrader Legendary vs 60–240: **in band**
- Upgrader Rebirth vs 60–150: **in band**

## Recommendation (for humans — no auto-apply)

1. **Do not ship baseline.** Upgrader Epic saturation and early P50 confirm the playtest.
2. Among the three strongest above, prefer a candidate that:
   - Cuts mean Epic@15 dramatically vs baseline
   - Keeps hunter Epic earlier than passive
   - Uses hunt reform (decoupled scan + capped batches) if hunter still floods
   - Avoids CostGrowth ≥ 1.75 unless the milder options still flood
3. **Phase 1** should apply the chosen row’s denom/luck/hunt knobs **and** keep frozen (or permanently decoupled) incomes.
4. **Phase 2** (Essence/fusion/mutation unlocks) is still required so slower rarity is not empty waiting — this sweep only measures roll/CE pacing.

## Extensibility note

This harness accepts candidate tables only (denoms, luck curve, hunt tune). Future fusion/Essence/zone tables can plug into a later sim layer without rewriting RollMath.

## How to reproduce

```bash
lune run tests/progressionSweep        # 100 seeds
lune run tests/progressionSweep 500    # fuller percentiles
```
