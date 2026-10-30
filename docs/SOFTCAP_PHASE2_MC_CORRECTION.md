# SoftCap Phase 2 — Corrected Monte Carlo (Playtest-Calibrated)

**Supersedes** the under-rolled MC in `SOFTCAP_PHASE2_REPORT.md` §6 (fixed 525 rolls @ 4s).
**Calibration source:** `docs/playtest/pt_153530464_36f8c545` (35:51, Soft A+C Studio trial).
**Studio trial:** `SoftCap_Rev4` remains the default SoftCap Studio experiment (unchanged).
**N = 100** seeded runs each. Values are **P10 / P50 / P90** (mean noted where useful).

No SoftCap R/M, upgrade prices, Rebirth rules, or live defaults were changed.

## 0. Why the old MC was wrong

| | Old Phase-2 MC | Real playtest |
| --- | ---: | ---: |
| Duration | ~35 min | 35:51 |
| Scan model | constant **4 s** | Scan Speed 0→12 (→ **1 s**) |
| Auto-scan rewards | **525** | **1879** (ScanAgg) |
| Underestimate | — | **~3.6×** fewer rolls |
| SoftAC uniques @35m | ~30 (P50-ish) | **52** |

ScanSpeed path used (from purchases): 0 @0s → 6 @3:40 → 10 @9:50 → 12 @16:29.
CoreLuck / MutRes / FrequencyFocus follow the same session’s purchase times.
Hunt: 26 captures paced ~every 83s with trial-capped bonus rolls.
Playtest also shows a **Common Rarity Focus** burst ~15:51–16:30 (extra Commons in ScanAgg); both sims replay that window.
Scan clock uses a **1.074×** timing factor so ScanSpeed ranks produce ~1879 scans (closed-form path alone ≈1750).

## 1. Roll volume validation (must match playtest first)

| Metric | Playtest | SoftAC P10/P50/P90 | SoftCap P10/P50/P90 |
| --- | ---: | ---: | ---: |
| Total rolls | ~1879 scans + hunt bonuses | 2016 / **2016** / 2016 | 2016 / **2016** / 2016 |
| Scan rolls | 1879 | 1881 / **1881** / 1881 | 1881 / **1881** / 1881 |
| Hunt rolls | (26 captures × bonus) | 135 / **135** / 135 | 135 / **135** / 135 |

Scan-roll P50 vs playtest 1879: SoftAC **100.1%**, SoftCap **100.1%** (identical ScanSpeed clock).

## 2. Discovery comparison @ 35:51

| Metric | Playtest (SoftAC) | SoftAC sim | SoftCap sim |
| --- | ---: | ---: | ---: |
| Unique @15m | 41 | 33 / **35** / 37 | 44 / **45** / 48 |
| Unique @30m | 52 | 45 / **48** / 51 | 50 / **52** / 54 |
| Unique @35m | 52 | 47 / **50** / 53 | 52 / **53** / 55 |
| Dupes | ~1667 sells | 1963 / **1966** / 1969 | 1961 / **1963** / 1964 |
| Mutations | (many milestones) | 158 / **171** / 184 | 153 / **170** / 189 |
| Epic exact | 11 | 5 / **10** / 13 | 10 / **14** / 18 |
| Epic+ | — | 5 / **10** / 14 | 10 / **14** / 19 |
| Unique Epic IDs | 7 | 4 / **7** / 10 | 7 / **8** / 10 |
| Essence (proxy) | ~7697 @30m | 2117 / **2132** / 2146 | 2108 / **2124** / 2141 |
| CE/s end (proxy) | ~134318 @30m | 1402 / **1678** / 4128 | 1530 / **1799** / 5636 |
| Rare % of rolls | ~91.9% (scans) | 91.0 / **91.6** / 92.2 | 9.7 / **10.7** / 11.5 |
| Common+Uncommon % | ~8.1% | 7.3 / **7.9** / 8.5 | 87.6 / **88.5** / 89.6 |

### Mean rolls by tier (P50-adjacent mean)

| Tier | SoftAC mean | SoftCap mean |
| --- | ---: | ---: |
| Common | 34.3 | 1104.5 |
| Uncommon | 124.9 | 681.3 |
| Rare | 1846.8 | 215.7 |
| Epic | 9.6 | 14.0 |

## 3. Desirable discoveries (corrected definition)

**Desirable** = new Unique Rare+, new Unique Epic+, or first-ever of a rarity tier.
**Not desirable:** plain Common/Uncommon dupes, or mutation spice on an already-known relic.

| Metric | SoftAC | SoftCap |
| --- | ---: | ---: |
| Desirable events | 20 / **23** / 26 | 23 / **24** / 26 |
| Avg gap (rolls) | 70.3 / **83.0** / 95.0 | 64.4 / **77.9** / 85.1 |
| Avg gap (seconds) | 76.9 / **89.6** / 102.1 | 72.2 / **84.4** / 91.5 |
| Epic / 1000 rolls (from P50 EpicExact) | 4.96 | 6.94 |

## 4. Why the old “30.6 vs 28.6 valuable gap” looked backwards

The superseded report defined “valuable” as **new Rare+ unique OR any Epic+ drop**, then measured **gap in rolls**.

Under Soft A+C’s Rare wall (~99% Rare mid-session):
- Almost every roll can advance the **Rare Index** until that small pool (~14 relics) is exhausted.
- So “new Rare unique” events cluster early → average gap **in rolls** looks short.
- After the Rare Index fills, desirable Index progress **stalls** even though rolls continue (unique count ~30–52 depending on volume).

Under SoftCap:
- Rare rolls are ~14% at L150, so Rare Index fills **slower per roll** → longer average gap *in roll space* for Rare+ events.
- But Commons/Uncommons keep unlocking early Index entries, and wall-clock gaps matter more than roll gaps when scan rate is 1/s.

Corrected sim legacy metric (same bad definition) for transparency:

| Legacy valuable avg gap (rolls) | SoftAC 66.7 / **82.1** / 100.4 | SoftCap 60.0 / **68.7** / 80.5 |

Use **seconds between desirable events** and **unique@15/30/35** as the player-experience scores, not the old roll-gap alone.

## 5. 85% C/U at mid Luck with realistic 1s scanning

SoftCap P50 Common+Uncommon share of all rolls: **88.5%** (session average; midgame Luck is higher C/U than SoftAC’s Rare flood).
At ~1 scan/s after Scan Speed 12 (~16:29→end ≈ 19 min): SoftCap still delivers ~1035 low-tier rolls in that window alone (order-of-magnitude) — Collection/Essence is the intended sink.

Player-feel risk remains **dupe fatigue**, not Rare color plateau. SoftCap’s win condition is restoring a mixed Index climb without SoftAC’s midgame Rare wallpaper.

## 6. Experience verdict (corrected — no retunes)

- SoftAC unique@35 P50 **50** vs playtest **52** (calibration check).
- SoftCap unique@35 P50 **53** under the same ScanSpeed/Luck path.
- SoftAC Rare% P50 **91.6%** vs SoftCap **10.7%** — SoftCap still kills the Rare wall.
- SoftCap Epic exact P50 **14** vs SoftAC **10** / playtest 11 — flag early-Epic generosity if SoftCap >> SoftAC.
- CE/s proxy is **directional only** (simplified pedestals); SoftCap may land lower-tier income earlier — confirm in Studio, do not retune Rebirth yet.

**Recommendation:** proceed with the planned short Studio SoftCap playtest. Do not balance costs around SoftCap until that human session.

## 7. Studio safety

- `BalanceTrials.StudioTrialId = "SoftCap_Rev4"` still active for Studio.
- Control: `SoftAC_E20k`. Production: live Ladder.
- SoftCap coefficients untouched.

---
*Generated by `lune run tests/softCapPlaytestCorrected` (100 seeds/side).*
