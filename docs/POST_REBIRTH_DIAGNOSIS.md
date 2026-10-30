# Post-Rebirth diagnosis + proposed fixes + minimal Phase 2 scope

**Status:** Investigation complete; Studio prototype in progress (see [`STUDIO_PROTOTYPE.md`](STUDIO_PROTOTYPE.md), [`AC_FIX_MATRIX.md`](AC_FIX_MATRIX.md)). Live balance **not** shipped. `BalanceTrials.Active` remains `nil`.

**Candidate:** `E20k_L12_C17_HR` (full luck stack to reach each Rebirth, then 30‑minute ablation windows).
**Seeds:** 200 (identical across ablations). **Window:** 30 minutes after Rebirth N.

## Executive verdict

The post-Rebirth Epic flood is **not** “kept relics are too strong by themselves.” It is a **CE fuel → Core Luck rebuy → Scan Speed → Epic carpet** loop:

1. **Kept high-income relics** restore CE/sec immediately (good fantasy — keep this).
2. That CE **rebuy Core Luck** from 0 → ~30 ranks in minutes (ablation kill-switch: blocking Core Luck drops Epics to ~0.3 / 30m).
3. **Scan Speed repurchase** multiplies throughput (blocking it cuts ~78% of Epics).
4. **Rebirth luck ×1.5 / ×2.25 / …** and Codex/Showcase/potions amplify the product; they matter more at R2/R3.
5. Relics+income with **no luck climb** produce **~0 Epics** — so do not nerf CE recovery; gate the luck rebuy curve and replace Epic as the post-R goal.

Isolated ablation window after R1 control: **66 Epics / 30m** (luck end ~1.26K). Continuous provisional sim previously reported **44.1** in the same band — both are floods; ablation is higher because the window starts mid-rebuild with full buy pressure and no R2 saving.

## 1. Ablation tables

### After Rebirth 1

Reach rate within 6h: **100%**. Population P50 time to this Rebirth: **95.7 min**.

| Ablation | Epic / 30m | Leg / 30m | Luck start→end | CE/s start→end | CoreLuck end | Scan end | Sig buys | Gap min |
|----------|------------|-----------|----------------|----------------|--------------|----------|----------|---------|
| full | 65.7 | 2.55 | 2.74→1.26K | 17.9K→6.86M | 31.5 | 1.00s | 18.1 | 1.2 |
| noKeptRelics | 8.6 (13% of ctrl) | 0.39 | 2.74→249 | 0→794K | 22.3 | 1.00s | 16.2 | 1.5 |
| noCoreLuckBuy | 0.3 (0% of ctrl) | 0.01 | 2.74→2.8 | 17.9K→2.61M | 0.0 | 1.00s | 12.0 | 0.2 |
| noScanBuy | 14.4 (22% of ctrl) | 0.53 | 2.74→1.07K | 17.9K→3.1M | 30.9 | 4.00s | 6.0 | 4.2 |
| noRebirthMult | 25.1 (38% of ctrl) | 0.97 | 1.83→553 | 8.93K→2.52M | 29.1 | 1.00s | 17.3 | 1.1 |
| noCodexShowPotion | 32.1 (49% of ctrl) | 1.32 | 1.5→623 | 16.4K→4.4M | 31.0 | 1.00s | 18.0 | 1.2 |
| relicsIncomeOnly | 0.0 (0% of ctrl) | 0.00 | 1→1 | 16.4K→2.45M | 0.0 | 4.00s | 0.0 | — |
| luckStackOnly | 3.9 (6% of ctrl) | 0.20 | 2.74→111 | 0→156K | 18.9 | 1.07s | 14.6 | 1.8 |

**Contribution read (share of control Epic count removed when factor is disabled):**

- Wipe kept relics: **87%** of Epics disappear → pedestal CE recovery / roll fuel from kept relics.
- Block Core Luck repurchase: **100%**.
- Block Scan Speed repurchase: **78%**.
- Remove Rebirth luck+income mults: **62%**.
- Remove Codex/Showcase/potions: **51%**.
- Relics+income only (no luck climb): **0%** of control Epics remain.
- Luck stack only (no kept relics): **6%** of control Epics remain.

### After Rebirth 2

Reach rate within 6h: **100%**. Population P50 time to this Rebirth: **123.5 min**.

| Ablation | Epic / 30m | Leg / 30m | Luck start→end | CE/s start→end | CoreLuck end | Scan end | Sig buys | Gap min |
|----------|------------|-----------|----------------|----------------|--------------|----------|----------|---------|
| full | 209.2 | 8.36 | 4.29→3.91K | 74.5K→33.7M | 35.1 | 1.00s | 18.4 | 0.5 |
| noKeptRelics | 40.8 (20% of ctrl) | 1.61 | 4.29→1.38K | 0→5.5M | 29.4 | 1.00s | 17.4 | 1.4 |
| noCoreLuckBuy | 0.3 (0% of ctrl) | 0.01 | 4.29→4.29 | 74.5K→10.9M | 0.0 | 1.00s | 12.0 | 0.0 |
| noScanBuy | 46.7 (22% of ctrl) | 1.94 | 4.29→3.16K | 74.5K→16.9M | 34.2 | 4.00s | 6.2 | 1.3 |
| noRebirthMult | 43.5 (21% of ctrl) | 1.59 | 1.91→803 | 18.6K→3.97M | 31.3 | 1.00s | 18.1 | 1.2 |
| noCodexShowPotion | 104.0 (50% of ctrl) | 4.30 | 2.25→1.77K | 68K→21M | 34.5 | 1.00s | 18.3 | 0.5 |
| relicsIncomeOnly | 0.0 (0% of ctrl) | 0.00 | 1→1 | 68K→10.2M | 0.0 | 4.00s | 0.0 | — |
| luckStackOnly | 6.7 (3% of ctrl) | 0.23 | 4.29→187 | 0→247K | 19.4 | 1.04s | 15.0 | 1.8 |

**Contribution read (share of control Epic count removed when factor is disabled):**

- Wipe kept relics: **80%** of Epics disappear → pedestal CE recovery / roll fuel from kept relics.
- Block Core Luck repurchase: **100%**.
- Block Scan Speed repurchase: **78%**.
- Remove Rebirth luck+income mults: **79%**.
- Remove Codex/Showcase/potions: **50%**.
- Relics+income only (no luck climb): **0%** of control Epics remain.
- Luck stack only (no kept relics): **3%** of control Epics remain.

### After Rebirth 3

Reach rate within 6h: **100%**. Population P50 time to this Rebirth: **147.8 min**.

| Ablation | Epic / 30m | Leg / 30m | Luck start→end | CE/s start→end | CoreLuck end | Scan end | Sig buys | Gap min |
|----------|------------|-----------|----------------|----------------|--------------|----------|----------|---------|
| full | 555.5 | 22.33 | 6.78→9.84K | 315K→128M | 38.0 | 1.00s | 19.2 | 0.8 |
| noKeptRelics | 169.5 (31% of ctrl) | 7.03 | 6.78→4.73K | 0→35.8M | 33.7 | 1.00s | 18.2 | 1.1 |
| noCoreLuckBuy | 0.6 (0% of ctrl) | 0.04 | 6.78→6.25 | 315K→46.1M | 0.0 | 1.00s | 12.0 | 0.0 |
| noScanBuy | 132.7 (24% of ctrl) | 5.47 | 6.78→8.62K | 315K→67.1M | 37.2 | 4.00s | 7.1 | 2.1 |
| noRebirthMult | 68.1 (12% of ctrl) | 2.81 | 2.01→1.09K | 39.3K→7.4M | 32.7 | 1.00s | 18.4 | 1.0 |
| noCodexShowPotion | 277.3 (50% of ctrl) | 11.31 | 3.38→4.45K | 284K→81.3M | 37.1 | 1.00s | 19.1 | 0.8 |
| relicsIncomeOnly | 0.0 (0% of ctrl) | 0.01 | 1→1 | 284K→42.4M | 0.0 | 4.00s | 0.0 | — |
| luckStackOnly | 13.6 (2% of ctrl) | 0.48 | 6.78→358 | 0→539K | 20.3 | 1.01s | 15.7 | 1.8 |

**Contribution read (share of control Epic count removed when factor is disabled):**

- Wipe kept relics: **69%** of Epics disappear → pedestal CE recovery / roll fuel from kept relics.
- Block Core Luck repurchase: **100%**.
- Block Scan Speed repurchase: **76%**.
- Remove Rebirth luck+income mults: **88%**.
- Remove Codex/Showcase/potions: **50%**.
- Relics+income only (no luck climb): **0%** of control Epics remain.
- Luck stack only (no kept relics): **2%** of control Epics remain.

### Factor ranking (after R1)

| Rank | Factor | Role |
|------|--------|------|
| 1 | Core Luck repurchase | Necessary condition for the flood |
| 2 | Kept relics (CE fuel) | Enables the rebuy; **do not wipe** |
| 3 | Scan Speed repurchase | Throughput multiplier |
| 4 | Rebirth luck+income | Amplifier (grows with R#) |
| 5 | Codex / Showcase / potions | ~2× amplifier; keep for identity |

## 2. Fix probes (tested, non-punishing)

Same R1 snapshot → 30m window. Relics kept. No forced Rarity Focus.

| Ablation | Epic / 30m | Leg / 30m | Luck start→end | CE/s start→end | CoreLuck end | Scan end | Sig buys | Gap min |
|----------|------------|-----------|----------------|----------------|--------------|----------|----------|---------|
| full | 65.7 | 2.55 | 2.74→1.26K | 17.9K→6.86M | 31.5 | 1.00s | 18.1 | 1.2 |
| fixSoftLuck125 | 51.2 (78% of ctrl) | 1.91 | 2.29→1.03K | 17.9K→5.41M | 31.3 | 1.00s | 18.1 | 1.2 |
| fixIncomeOnlyLuck | 41.7 (63% of ctrl) | 1.84 | 1.83→810 | 17.9K→5.11M | 31.2 | 1.00s | 18.1 | 1.2 |
| fixCostGrowth185 | 27.8 (42% of ctrl) | 1.04 | 2.74→526 | 17.9K→4.03M | 27.0 | 1.00s | 17.1 | 0.9 |
| fixCoreCap20 | 10.0 (15% of ctrl) | 0.34 | 2.74→124 | 17.9K→3.18M | 20.0 | 1.00s | 16.0 | 0.2 |
| fixPersistScan | 61.8 (94% of ctrl) | 2.25 | 2.74→1.2K | 17.9K→5.93M | 31.3 | 1.00s | 6.1 | 4.0 |
| fixSoftLuck125_Cost185 | 24.1 (37% of ctrl) | 0.94 | 2.29→436 | 17.9K→4.18M | 27.0 | 1.00s | 17.1 | 0.9 |

**Read:**

- Soft LuckGrowth 1.25: **51.2** Epics (78% of control).
- Income-only Rebirth luck (×1 luck): **41.7** Epics (63%).
- CoreLuck cost growth 1.85: **27.8** Epics (42%).
- CoreLuck cap 20 in window: **10.0** Epics (15%).
- Persist Scan (QoL, not a nerf): **61.8** Epics (94%) — helps feel, does not fix flood alone.
- **Recommended probe combo** LuckGrowth 1.25 + cost 1.85: **24.1** Epics (37% of control).

### Preferred fix directions (do not auto-force Focus)

| Idea | Intent | Avoids |
|------|--------|--------|
| **A. Soft Rebirth luck curve** — LuckGrowth 1.5→1.25 (or income-first for R1–R2) | Slows product without deleting power | Punishing reset |
| **B. Post-Rebirth Resonance choice** — permanent specialization (Phase 2) instead of flat luck alone | New goal when power returns | Forced Focus UI |
| **C. Soft Core Luck rebuy** — post-R cost growth bump or temporary rank soft-cap that decays | Cuts the kill-loop; keeps CE fantasy | Wiping relics |
| **D. Persist Scan Speed** — keep QoL; still require Core Luck rebuild | Rebirth feels less stripped | Using Scan as the only nerf |
| **E. Epic spotlight** — first post-R Epic featured (mutation/Essence); later Epics quieter | Keeps dopamine, reduces carpet feel | Nerfing CE recovery |

**Approved for Studio trial:** LuckGrowth **1.25** + soft CoreLuck **k=0.05** (not flat 1.85). See [`STUDIO_PROTOTYPE.md`](STUDIO_PROTOTYPE.md) / [`STUDIO_PROGRESSION_REPORT.md`](STUDIO_PROGRESSION_REPORT.md). Focus remains a **helper** for Codex holes (Attune + Focus Common in Luck menu).

## 3. Minimal playable Phase 2 scope (for approval before implementation)

Fun-first: a second progression path that creates **decisions**, not only CE/sec. Data-driven for updates.

### 3.1 Relic Essence (currency)

| Earn | Spend |
|------|-------|
| Auto-sell / dismantle duplicates → Essence by tier (Commons drip, Rares matter) | Fusion ranks, Attune tickets, mutation goal crafts |
| +small Essence per hunt capture | |

- **No CE→Essence convert.**
- **Auto-sell safe for fusion:** default Keep for Uncommon+; Commons can auto-sell to Essence but **pin 3 copies** of any relic marked Favourite / in an active fusion recipe.
- New players can earn Essence from Common duplicates **before first Epic**.

### 3.2 Fusion (cap 3) + Charm specialization (the meaningful decision)

Fusion rank still gives a **small** income bump (so pedestals care), but **rank 1 unlocks a Charm choice** on that relic:

| Charm (pick one per fused relic) | Gameplay effect (not just CE) |
|----------------------------------|-------------------------------|
| **Hunt Charm** | While on a pedestal: +Family weight on **hunt** rolls only (targeted collecting) |
| **Workshop Charm** | Duplicates of this relic yield +50% Essence |
| **Shrine Charm** | Pedestal pulse: once / 90s outlines nearest signal (mini Spirit Sight) |

Decision: *specialize this favourite for hunting, farming Essence, or QoL?* Expandable via `CharmConfig` rows in later updates.

### 3.3 Mutation goals (mechanics)

| Goal | Unlock |
|------|--------|
| 1 Golden | Workshop Charm unlocked globally |
| 3 unique mutated | Attune ticket (10 Focused scans) recipe |
| First Corrupted | Hunt Charm Family bias +10% when mutated |

### 3.4 Rebirth permanent goal — Resonance

On each Rebirth, choose **one Resonance** (permanent, light stacks):

| Resonance | Effect |
|-----------|--------|
| Collector | +15% Essence from duplicates |
| Binder | −0.4s bind hold |
| Seeker | +12 Spirit Sight range |

Pairs with fix A/C so Rebirth is not “flat luck + Epic carpet.”

### 3.5 Explicitly deferred

Zone exclusives, advanced fusion branches, BGH sizes, pedestal set synergies beyond Charms — **Update hooks only**.

### 3.6 Studio prototype config (not live)

1. Locally set `BalanceTrials.Active = "E20k_L12_C17_HR"` for Studio only.
2. After Phase 2 approval: add trial flag `CollectionPrototype = true` (Essence/fusion/Charms/Resonance) behind the same Active gate.
3. Keep shipping `Active = nil` until combined playtest passes §4.

## 4. Experience checkpoints (E20k full stack, sim)

Means over 200 seeds, 3h. **Routine** = pedestal levels / Energy Conduction. **Significant** = new pedestal slots, Scan ranks, CoreLuck ×5 milestones, Showcase unlock/upgrade, Codex luck steps, first Rare/Epic/Legendary, Rebirth, (Phase 2) Charm/Resonance.

### Upgrader

| Min | Epic | Leg | Unique | Essential | Luck | CE/s | R# | CoreLuck | Scan | Showcase | Potion% | LowMass MaxLuck/Focus | Modal best tier |
|-----|------|-----|--------|-----------|------|------|----|----------|------|----------|---------|-----------------------|-----------------|
| 15 | 0.4 | 0.01 | 41 | 41 | 24 | 10.1K | 0.0 | 14 | 1.47s | 0.0 | 32% | 0.470 / 0.978 | Rare |
| 30 | 1.6 | 0.07 | 42 | 42 | 50.7 | 42.9K | 0.0 | 18 | 1.18s | 1.8 | 37% | 0.134 / 0.978 | Epic |
| 60 | 9.3 | 0.41 | 47 | 47 | 154 | 555K | 0.1 | 22 | 1.01s | 2.2 | 42% | 0.000 / 0.978 | Epic |
| 90 | 42.0 | 1.95 | 53 | 53 | 708 | 19.1M | 0.6 | 26 | 1.02s | 2.9 | 35% | 0.008 / 0.978 | Legendary |
| 120 | 155.7 | 11.41 | 57 | 56 | 4.85K | 247M | 1.7 | 28 | 1.03s | 3.2 | 36% | 0.011 / 0.978 | Legendary |
| 180 | 1232.3 | 247.49 | 66 | 63 | 86.2K | 4.1B | 4.6 | 36 | 1.00s | 3.8 | 32% | 0.000 / 0.978 | Mythic |

### Hunter

| Min | Epic | Leg | Unique | Essential | Luck | CE/s | R# | Captures | Scan | Showcase | Potion% | LowMass MaxLuck/Focus | Modal best tier |
|-----|------|-----|--------|-----------|------|------|----|----------|------|----------|---------|-----------------------|-----------------|
| 15 | 0.6 | 0.01 | 38 | 38 | 23.2 | 12.9K | 0.0 | 10 | 1.41s | 0.0 | 24% | 0.489 / 0.978 | Rare |
| 30 | 2.1 | 0.09 | 40 | 40 | 49.4 | 55.7K | 0.0 | 17 | 1.15s | 2.0 | 25% | 0.148 / 0.978 | Epic |
| 60 | 10.8 | 0.50 | 45 | 45 | 135 | 766K | 0.1 | 32 | 1.01s | 2.2 | 27% | 0.004 / 0.978 | Epic |
| 90 | 48.7 | 2.21 | 51 | 51 | 1.09K | 33.5M | 0.8 | 47 | 1.02s | 3.0 | 22% | 0.006 / 0.978 | Legendary |
| 120 | 192.7 | 15.11 | 55 | 54 | 7.11K | 453M | 1.9 | 62 | 1.02s | 3.2 | 24% | 0.005 / 0.978 | Legendary |
| 180 | 1462.8 | 322.94 | 64 | 60 | 107K | 5.75B | 5.1 | 92 | 1.00s | 3.8 | 25% | 0.000 / 0.978 | Mythic |

### Player narrative (provisional + Phase 2 intent)

| Time | Achievable (sim now) | Chasing next | Meaningful decisions |
|------|----------------------|--------------|----------------------|
| 15m | Rares, pedestals, early CoreLuck/Scan; ~0–1 Epic | First Epic; Essence stockpile (Phase 2) | Upgrade order; Favourite Commons for fusion pin |
| 30m | Epic likely (upgrader P50 ~23m); Codex climbing | Fusion rank 1 + Charm; more Essentials | Hunt vs Workshop vs Shrine Charm |
| 60m | Multiple Epics; Showcase online; MaxLuck soft-locks Commons | Legendary; mutation goal #1; Attune | Focus helper vs MaxLuck; which relic to fuse |
| 90m | Approaching Rebirth 1 (P50 ~96–97m) | Rebirth cost; Resonance prep | Save vs spend; Resonance pick planned |
| 120m | Past R1 for most; post-R rebuild (flood risk without A+C) | Resonance active; Legendary; Charm board | Collector vs Binder vs Seeker; soft luck rebuild |
| 180m | R2 territory; Legendary chase; high luck | Mutation sets; deeper fusion; R3 | Shrine vs hunt identity; update-ready goals |

Ordinary pedestal level-ups stay **routine**. Charm unlocks, Resonance picks, mutation goals, Attune, Showcase unlocks, and Rebirth itself are **significant**.

## 5. Ask for Astra / human

1. Confirm ablation read — **Core Luck rebuy + CE fuel** is the flood; keep relics.
2. Approve fix combo **A+C** (and Resonance **B**) for the next sim pass; optionally Persist Scan **D**.
3. Approve **minimal Phase 2 scope** (§3, Charm specialization + Resonance) for a Studio prototype on top of `E20k_L12_C17_HR`.
4. **Do not** enable live defaults until a combined playtest passes the checkpoint table.

## Reproduce

```bash
lune run tests/rebirthAblation 200
```
