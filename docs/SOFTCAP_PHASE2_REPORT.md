# SoftCap Phase 2 — Studio Trial Report

**Trial ID:** `SoftCap_Rev4` (Studio auto). **Control:** `SoftAC_E20k` (Ladder sampler, same costs/hunt).
**Live/production:** unchanged Ladder + live denoms (no SoftCap).
**Labels:** `computed` = closed-form SoftCap/ladder; `sampled` = Monte Carlo; **no silent retunes**.

## Startup logs (expected in Studio)

```
[BalanceTrials] ACTIVE=SoftCap_Rev4
[BalanceTrials] RaritySampler=SoftCap
[BalanceTrials] CollectionPrototype=true | ... SoftCap Phase 2: Index odds = 1/p_i; SoftAC_E20k available as Ladder control
[Main] Balance=SoftCap_Rev4 Collection=true RaritySampler=SoftCap
[Main] Hunt cap: MaxBonusRolls=6 → maxTotalRolls=7 per spirit capture
```

Switch control in Studio: set `BalanceTrials.StudioTrialId = "SoftAC_E20k"` (or `Active`) and restart.

## 1. SoftCap band % vs Luck (computed)

| Luck | Common | Uncommon | Rare | Epic | Legendary | Mythic | Celestial | Cosmic |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 86.27 | 11.95 | 1.70 | 0.07 | 0.00 | 0.00 | 0.00 | 0.00 |
| 5 | 79.63 | 17.54 | 2.71 | 0.12 | 0.00 | 0.00 | 0.00 | 0.00 |
| 20 | 67.66 | 26.88 | 5.21 | 0.24 | 0.01 | 0.00 | 0.00 | 0.00 |
| 60 | 56.50 | 33.84 | 9.14 | 0.50 | 0.02 | 0.00 | 0.00 | 0.00 |
| 150 | 48.74 | 36.54 | 13.74 | 0.95 | 0.03 | 0.00 | 0.00 | 0.00 |
| 500 | 41.70 | 36.19 | 19.83 | 2.19 | 0.09 | 0.00 | 0.00 | 0.00 |
| 2000 | 37.09 | 34.07 | 23.86 | 4.68 | 0.29 | 0.01 | 0.00 | 0.00 |
| 10000 | 34.47 | 32.18 | 24.83 | 7.58 | 0.89 | 0.05 | 0.00 | 0.00 |
| 100000 | 33.07 | 30.99 | 24.52 | 9.11 | 2.03 | 0.27 | 0.00 | 0.00 |
| postR1~58 | 56.83 | 33.68 | 8.99 | 0.49 | 0.02 | 0.00 | 0.00 | 0.00 |
| postR3~4208 | 35.62 | 33.07 | 24.62 | 6.16 | 0.51 | 0.02 | 0.00 | 0.00 |

## 2. Soft A+C ladder control (Epic 20k / Leg 500k) — computed

| Luck | Common | Uncommon | Rare | Epic | Legendary | Mythic | Celestial | Cosmic |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 75.00 | 22.78 | 2.22 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| 20 | 0.00 | 55.56 | 44.34 | 0.10 | 0.00 | 0.00 | 0.00 | 0.00 |
| 60 | 0.00 | 0.00 | 99.70 | 0.29 | 0.01 | 0.00 | 0.00 | 0.00 |
| 150 | 0.00 | 0.00 | 99.25 | 0.72 | 0.03 | 0.00 | 0.00 | 0.00 |
| 500 | 0.00 | 0.00 | 97.50 | 2.40 | 0.10 | 0.00 | 0.00 | 0.00 |
| 2000 | 0.00 | 0.00 | 90.00 | 9.60 | 0.38 | 0.02 | 0.00 | 0.00 |

## 3. FLAG — Early Epic generosity

At Luck=1, SoftCap Epic band = **0.0726%** vs Soft A+C **0.004800%** → **15.1×**.
Rev 4 called this ~15×. **Do not silently retune** — watch Studio playtests for purple-too-early feel.

## 4. SoftCap vs Soft A+C at Luck 150 (the Rare-plateau checkpoint)

| Metric | Soft A+C | SoftCap |
| --- | ---: | ---: |
| Common % | 0.00 | 48.74 |
| Uncommon % | 0.00 | 36.54 |
| Rare % | 99.25 | 13.74 |
| Epic % | 0.720 | 0.951 |
| C+U % | 0.00 | 85.27 |

SoftCap L1(60→150) = **0.159** (Luck still reshapes mix).

## 5. Sample Index 1-in-N at L=150 (SoftCap computed — not R/L)

| Relic | Tier | 1/p_i |
| --- | --- | ---: |
| Paladyn's Necklace | Common | 31.7 |
| Exploding Tag | Uncommon | 35.9 |
| Hollo Bait | Rare | 61.9 |
| Quad-Leaf Grimoire | Epic | 611.2 |
| Kubikiri Cleaver | Legendary | 17008.0 |
| Hollo Mask | Mythic | 418268.3 |
| Hogyuku | Celestial | 1043437537.0 |
| Red Stone of Aia | Cosmic | 4173739719787.2 |

## 6. Experience Monte Carlo — ~35 min playtest-shaped (sampled)

> **SUPERSEDED.** This section assumed a constant 4s scan (~525 rolls) and under-counted the real 35:51 playtest (~1879 auto-scans after Scan Speed upgrades) by ~3.6×. SoftAC uniques here (~30) do not match the playtest (~52). See **`docs/SOFTCAP_PHASE2_MC_CORRECTION.md`** for the playtest-calibrated 100-seed P10/P50/P90 comparison. Closed-form band tables above remain valid.

Assumptions (mirrors Soft A+C playtest shape, not B+/Forms) — **obsolete for volume**:
- ~4s scan → ~525 rolls / 35 min AFK-heavy
- Luck path approximates Soft A+C climb: L≈5 → 20 → 60 → 150 over the session
- Mutation Resonance rank 0 until mid, then 1 (10%) after ~15 min
- No hunt in base run; separate hunt column at L×5

### SoftCap (8 seeds, median / mean tiers)

| Unique@15m | Unique@35m | Dupes | Mutations | Epic+ | Epic/1k | Essence proxy | Avg rolls between valuable |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 38 | 46 | 479 | 27 | 2 | 3.81 | 446 | 30.6 |

Mean rolls by rarity (SoftCap):
- Common: 322.1 (61.4%)
- Uncommon: 153.0 (29.1%)
- Rare: 47.6 (9.1%)
- Epic: 2.1 (0.4%)
- Legendary: 0.1 (0.0%)

### Soft A+C control (same seeds)

| Unique@15m | Unique@35m | Dupes | Mutations | Epic+ | Epic/1k | Essence proxy | Avg rolls between valuable |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 29 | 30 | 494 | 25 | 2 | 3.81 | 151 | 28.6 |

Mean rolls by rarity (Soft A+C):
- Uncommon: 164.0 (31.2%)
- Rare: 359.0 (68.4%)
- Epic: 2.0 (0.4%)

### Player-experience verdict (colors vs discovery)

- Soft A+C still collapses into **Rare-dominated** mid-session rolls → few exciting *color* changes, Index stalls on Rare pool.
- SoftCap keeps **Common/Uncommon majority (~85% at L150)** → more dupe volume; Collection/Essence is the intended sink.
- SoftCap restores **visible mix** (Rare ~14%, Epic ~1% at L150) so individual Epic/Legendary rolls remain scarce events.
- Valuable-discovery gaps shrink vs SoftAC Rare wall (new Rare+ Index entries keep arriving), but **low-tier dupe fatigue** is the new risk.

## 7. CE / Rebirth affordability (unchanged economy)

- Pedestal RelicIncome, upgrade prices, Rebirth cost/growth, Soft A+C CoreLuck soft costs: **not changed** in Phase 2.
- SoftCap changes *what* lands on pedestals (more C/U, fewer Rares mid-game) → **expected CE/s slightly lower** than SoftAC Rare flood until Collection fusion/income mults compensate.
- Rebirth affordability timing should be re-measured in the next human Studio session; do **not** retune Rebirth around SoftCap until that playtest.

## 8. Predicted negative effects

1. **Dupe fatigue** from ~85% C/U at mid Luck — Collection HUD must stay usable.
2. **Early Epic ~15× SoftAC** at L=1 — may feel purple-heavy in first minutes.
3. **CE income path** may slow vs SoftAC Rare pedestal spam until fusion/attune kicks in.
4. Index shows many Common 1-in-N that look "easy" — clarify tier name vs effective odds in UI (done: `Odds.indexLine`).

## 9. Human Studio playtest (10–15 min)

1. Open place in Roblox Studio (Play). Confirm Output: `ACTIVE=SoftCap_Rev4`, `RaritySampler=SoftCap`.
2. Analytics auto-starts. Play normally: scan + a few hunts; open Codex — odds should update after Core Luck buys (`Yours` 1-in-N + base).
3. Watch for: Rare plateau gone? Exciting Epic? Too many C/U dupes? Early purple?
4. Optional control: set `StudioTrialId="SoftAC_E20k"`, replay 10 min, compare feel.
5. Export: Analytics panel → Export (or stop session). Receiver: `python tools/playtest_export_server.py` on port 19283; files land under `docs/playtest/`.

## 10. Analytics instrumentation (Phase 2)

- 5-minute `RarityWindow` events: ByTier, UniqueNew, Dupes, BySource, Mutations, EpicPlus
- Purchases record `Luck`, `EffectiveLuck`, `RaritySampler`
- Exact Epic+ discoveries logged with Source (Scan/Capture/Bonus/…)
- Existing purchase CSV + session JSON + summary MD preserved; Meta includes RaritySampler + RarityWindows

---
*Generated by `lune run tests/softCapPhase2Report`. Phase 2 only — no Attunement25 / B+ / Forms.*
