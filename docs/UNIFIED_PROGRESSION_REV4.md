# Unified Progression Rev 4 — Simulation Results

**Status:** Design validation only. Live Config, RollService, skills, Rebirth, and data schemas were **not** modified.

**Seeds per cell:** 40 (mulberry32). Checkpoints at 5 / 15 / 30 / 45 / 60 / 90 / 120 / 180 minutes.

**Labels:** `computed` = closed-form SoftCap/ladder math; `simulated` = multi-seed policy runs; `candidate` = proposed economy not in live SkillConfig.

## 1. Recommended gameplay loop

Discover relics → strengthen build (pedestals / scan / energy / attunement) → earn CE & Essence → collect (fuse / forms / goals) → Rebirth (CE prestige + Resonance + gated tracks) → discover with better odds.

| Step | Systems |
|------|---------|
| Discover | SoftCap Index rolls, hunt native bias, mutations as spice |
| Strengthen | Ped soft-cap + Mastery, Scan, Energy±II, Attunement (CL25 candidate) |
| Earn | Pedestal CE/s, dupe sells, hunt Essence |
| Collect | HUD Collection (must ship), Essence sinks, optional Forms |
| Rebirth | **B+** provisional: reset CE; keep builds; unlock II/Mastery/MutDeep + Resonance |

## 2. SoftCap rarity validation (computed on all 92 relics)

### 2.1 Band % vs Luck — Soft A+C ladder (Studio Epic 20k)

| L | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|--------|----------|------|------|-----------|--------|
| 1 | 75.0 | 22.8 | 2.2 | 0.0 | 0.0 | 0.0 |
| 20 | 0.0 | 55.6 | 44.3 | 0.1 | 0.0 | 0.0 |
| 60 | 0.0 | 0.0 | 99.7 | 0.3 | 0.0 | 0.0 |
| 150 | 0.0 | 0.0 | 99.2 | 0.7 | 0.0 | 0.0 |
| 500 | 0.0 | 0.0 | 97.5 | 2.4 | 0.1 | 0.0 |
| 10000 | 0.0 | 0.0 | 50.0 | 48.0 | 1.9 | 0.1 |
| 100000 | 0.0 | 0.0 | 0.0 | 80.0 | 19.0 | 1.0 |
| 10000000 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 100.0 |

### 2.2 Band % vs Luck — SoftCap authored R + M (candidate)

| L | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|--------|----------|------|------|-----------|--------|
| 1 | 86.3 | 12.0 | 1.7 | 0.1 | 0.0 | 0.0 |
| 20 | 67.7 | 26.9 | 5.2 | 0.2 | 0.0 | 0.0 |
| 60 | 56.5 | 33.8 | 9.1 | 0.5 | 0.0 | 0.0 |
| 150 | 48.7 | 36.5 | 13.7 | 1.0 | 0.0 | 0.0 |
| 500 | 41.7 | 36.2 | 19.8 | 2.2 | 0.1 | 0.0 |
| 10000 | 34.5 | 32.2 | 24.8 | 7.6 | 0.9 | 0.0 |
| 100000 | 33.1 | 31.0 | 24.5 | 9.1 | 2.0 | 0.3 |
| 10000000 | 32.7 | 30.6 | 24.3 | 9.3 | 2.4 | 0.7 |

SoftCap L1-distance Luck 60→150: **0.159** (Luck reshapes mix).
SoftCap L1-distance Luck 0.5→0.8: **0.0303** (does not fully cancel).

### 2.3 Epic accessibility critique

| Metric | Soft A+C | SoftCap |
|--------|----------|---------|
| Epic % at L=1 | 0.005% | 0.073% |
| Epic % at L=150 | 0.720% | 0.951% |
| Rare % at L=150 | 99.2% | 13.7% |
| Epic rolls / 1000 at L=150 | 7.2 | 9.5 |

At L=1, SoftCap Epic band share is ~**15.1×** the Soft A+C ladder (ladder Epic denom 20k makes early Epic vanishingly small). This is intentional for long-shots without waiting for Rare-cap, but must be watched for “purple too early” feel — tune (R)/(M) if Studio playtests feel flooded.

### 2.4 Sample Index 1-in-N at L=150 (SoftCap, computed)

| Relic | Tier | N_eff |
|-------|------|-------|
| PaladynsNecklace | Common | 1 in 32 |
| HolloBait | Rare | 1 in 62 |
| StaffOfJudgement | Epic | 1 in 3920 |
| KubikiriCleaver | Legendary | 1 in 17008 |
| HolloMask | Mythic | 1 in 418268 |
| AncientSunriseBlade | Cosmic | 1 in 25042438287420 |

### 2.5 Endgame scarcity (SoftCap at extreme L)

At L=1e7 (beyond R3 Soft A CL100): C 32.7% / R 24.3% / E 9.3% / Leg 2.4% / Myth 0.7% / Cel 0.0109% / Cos 0.0000% — Cosmic remains scarce via (M); not uniform 1/92.

Through typical R3 Luck (~5k–20k simulated): Legendary band stays ~1–2%, Mythic ≪1%, Celestial/Cosmic effectively long-shot Index targets — not AFK wallpaper.

### 2.6 Scan vs hunt (SoftCap, computed at L=150)

Hunt applies Soft A ×5 luck factor in the sim (same as Soft A trial). Family Frequency multiplies matching-family weight via lowered (R).

| Mode | Common | Uncommon | Rare | Epic | Legendary |
|------|--------|----------|------|------|-----------|
| Scan L=150 | 48.7 | 36.5 | 13.7 | 1.0 | 0.0 |
| Hunt L=750 | 40.0 | 35.6 | 21.4 | 2.8 | 0.1 |

Hunt shifts mass into Rare/Epic without collapsing Commons (SoftCap soft-caps), so hunting remains a meaningful conditional bonus rather than a pure Rare faucet.

### 2.7 Monte Carlo SoftCap roll check (10k rolls @ L=150)

| Tier | Expected % | Observed % |
|------|------------|------------|
| Common | 48.7 | 48.4 |
| Uncommon | 36.5 | 36.5 |
| Rare | 13.7 | 14.3 |
| Epic | 1.0 | 0.8 |
| Legendary | 0.0 | 0.0 |

## 3. Integrated policy simulations (simulated)

### Approximations (disclose)

- Pedestal income uses frozen live RelicIncome bases (not SoftCap-retuned CE/s).
- Hunt uses simplified cadence + Soft A ×5 luck; not full BindService signal graph.
- Collection fuse is a stub Essence sink (+FormsProgress), not full CollectionMath board.
- Codex luck approximated as unique/92 * 0.5 capped.
- Core Luck 25-rank curve is sim-candidate (10^(rank*1.6/12)), not live SkillConfig.
- SpiritMerchant omitted (candidate merge/remove).

### 3.1 SoftCap + B+ — AfkUpgrader (Collection HUD **off**, playtest-like)

| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |
|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|
| 5 | 7.2 | 3.2 | 0.14 | 27 | 1288 | 5053 | 6 | 0 | 76 | 9 | 0 |
| 15 | 125.0 | 12.8 | 0.84 | 46 | 27251 | 590920 | 15 | 0 | 509 | 1 | 0 |
| 30 | 128.3 | 12.9 | 0.85 | 52 | 61377 | 38437733 | 15 | 0 | 1428 | 0 | 0 |
| 45 | 129.9 | 13.0 | 0.86 | 55 | 74880 | 116399461 | 15 | 0 | 2347 | 0 | 0 |
| 60 | 131.0 | 13.0 | 0.86 | 57 | 147995 | 168511936 | 15 | 0 | 3267 | 0 | 0 |
| 90 | 3585.8 | 24.5 | 5.85 | 61 | 1193378 | 278610573 | 25 | 1 | 5107 | 1 | 0 |
| 120 | 4592.1 | 24.7 | 6.32 | 66 | 4529045 | 958036889 | 25 | 2 | 6946 | 1 | 0 |
| 180 | 9076.1 | 24.8 | 7.45 | 70 | 211524637 | 105749311453 | 25 | 5 | 10634 | 0 | 0 |

P10–P90 bands (selected):

| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |
|-----|----------------|---------------|------------------|----------------|
| 5 | 24–28 | 2.0–3.7 | 0–0 | 825–2896 |
| 15 | 43–48 | 9.6–12.8 | 0–0 | 14496–48437 |
| 30 | 50–54 | 12.9–13.0 | 0–0 | 49997–140706 |
| 45 | 52–56 | 12.9–13.0 | 0–0 | 63218–231621 |
| 60 | 54–59 | 13.0–23.2 | 0–1 | 67617–797593 |
| 90 | 55–67 | 13.0–24.7 | 0–2 | 75494–18759975 |
| 120 | 58–69 | 22.5–24.8 | 1–4 | 343613–133301449 |
| 180 | 68–74 | 24.7–24.8 | 2–7 | 9684700–2454239957 |

### 3.2 SoftCap + B+ — Casual (HUD on)

| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |
|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|
| 5 | 1.1 | 1.7 | 0.07 | 25 | 994 | 25784 | 0 | 0 | 68 | 9 | 0 |
| 15 | 36.0 | 7.1 | 0.35 | 40 | 11627 | 404528 | 11 | 0 | 413 | 6 | 7 |
| 30 | 127.7 | 12.9 | 0.85 | 51 | 60124 | 25809107 | 15 | 0 | 1352 | 1 | 45 |
| 45 | 129.9 | 13.0 | 0.86 | 55 | 73064 | 92910212 | 15 | 0 | 2308 | 1 | 94 |
| 60 | 130.4 | 13.0 | 0.86 | 56 | 147611 | 168723196 | 15 | 0 | 3266 | 1 | 144 |
| 90 | 3600.5 | 24.5 | 5.86 | 62 | 1657057 | 272008440 | 25 | 1 | 5182 | 2 | 233 |
| 120 | 4592.1 | 24.7 | 6.32 | 67 | 4637446 | 2285582429 | 25 | 2 | 7093 | 2 | 327 |
| 180 | 9111.8 | 24.8 | 7.46 | 71 | 288187909 | 126752967050 | 25 | 5 | 10931 | 1 | 528 |

P10–P90 bands (selected):

| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |
|-----|----------------|---------------|------------------|----------------|
| 5 | 22–27 | 1.7–1.7 | 0–0 | 420–1579 |
| 15 | 37–42 | 1.9–9.6 | 0–0 | 10027–20500 |
| 30 | 48–54 | 12.8–13.0 | 0–0 | 47925–129147 |
| 45 | 52–57 | 12.9–13.0 | 0–0 | 61735–235201 |
| 60 | 54–58 | 13.0–17.5 | 0–1 | 68870–543061 |
| 90 | 56–66 | 13.0–24.7 | 0–2 | 76875–20314604 |
| 120 | 58–69 | 21.5–24.8 | 1–4 | 351499–134623412 |
| 180 | 69–73 | 24.8–24.8 | 3–7 | 20130851–1827354582 |

### 3.3 SoftCap + B+ — Hunter (HUD on)

| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |
|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|
| 5 | 1.2 | 1.7 | 0.07 | 30 | 1939 | 8469 | 0 | 0 | 115 | 10 | 2 |
| 15 | 123.4 | 12.7 | 0.83 | 46 | 34432 | 1232568 | 15 | 0 | 721 | 1 | 52 |
| 30 | 129.9 | 13.0 | 0.86 | 55 | 164439 | 99588216 | 15 | 0 | 1934 | 0 | 150 |
| 45 | 132.1 | 13.1 | 0.87 | 59 | 253384 | 259512257 | 15 | 0 | 3152 | 0 | 248 |
| 60 | 2648.7 | 24.2 | 5.25 | 62 | 1483242 | 119935519 | 24 | 1 | 4372 | 2 | 345 |
| 90 | 5785.8 | 24.8 | 6.74 | 69 | 42004049 | 11315770637 | 25 | 3 | 6806 | 1 | 550 |
| 120 | 9147.6 | 24.8 | 7.46 | 72 | 539350281 | 167089486949 | 25 | 5 | 9248 | 0 | 768 |
| 180 | 18075.7 | 24.8 | 8.26 | 76 | 8301503881 | 6271284251156 | 25 | 8 | 14128 | 0 | 1213 |

P10–P90 bands (selected):

| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |
|-----|----------------|---------------|------------------|----------------|
| 5 | 27–33 | 1.7–1.9 | 0–0 | 965–3191 |
| 15 | 44–50 | 8.3–12.8 | 0–0 | 18430–49971 |
| 30 | 53–58 | 12.9–13.0 | 0–0 | 64676–270442 |
| 45 | 56–61 | 13.0–22.5 | 0–1 | 78486–953644 |
| 60 | 58–65 | 13.1–24.5 | 0–1 | 235278–9217896 |
| 90 | 65–71 | 24.5–24.8 | 1–5 | 1801835–504059160 |
| 120 | 70–75 | 24.8–24.8 | 3–7 | 54020691–3547936865 |
| 180 | 73–78 | 24.8–24.8 | 6–8 | 1363652305–9437757418 |

### 3.4 SoftCap + B+ — Optimized (HUD on)

| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |
|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|
| 5 | 18.7 | 5.0 | 0.23 | 34 | 3098 | 5026 | 9 | 0 | 125 | 9 | 9 |
| 15 | 126.6 | 12.8 | 0.84 | 49 | 50892 | 2773821 | 15 | 0 | 736 | 0 | 53 |
| 30 | 129.9 | 13.0 | 0.86 | 55 | 140400 | 70769567 | 15 | 0 | 1859 | 0 | 142 |
| 45 | 131.5 | 13.0 | 0.87 | 58 | 162521 | 172731511 | 15 | 0 | 2981 | 0 | 230 |
| 60 | 1415.9 | 23.2 | 3.98 | 59 | 577555 | 188980904 | 22 | 1 | 4097 | 1 | 319 |
| 90 | 4592.1 | 24.7 | 6.32 | 67 | 12421824 | 1243301537 | 25 | 2 | 6344 | 1 | 498 |
| 120 | 9076.1 | 24.8 | 7.45 | 71 | 225785973 | 36919451818 | 25 | 5 | 8592 | 0 | 692 |
| 180 | 14404.7 | 24.8 | 8.03 | 74 | 3894819926 | 2217830774657 | 25 | 7 | 13089 | 0 | 1096 |

P10–P90 bands (selected):

| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |
|-----|----------------|---------------|------------------|----------------|
| 5 | 31–36 | 3.7–5.1 | 0–0 | 1648–7037 |
| 15 | 47–52 | 12.8–12.9 | 0–0 | 36166–157815 |
| 30 | 53–58 | 12.9–13.0 | 0–0 | 61939–241646 |
| 45 | 56–60 | 13.0–24.2 | 0–1 | 69816–1207719 |
| 60 | 57–66 | 13.0–24.5 | 0–1 | 142471–7922963 |
| 90 | 60–71 | 24.2–24.8 | 1–4 | 630731–363428748 |
| 120 | 67–73 | 24.7–24.8 | 2–6 | 4620260–1842456686 |
| 180 | 72–76 | 24.8–24.8 | 6–8 | 663265794–9018113521 |

### 3.5 Soft A+C ladder + B+ — AfkUpgrader (control)

| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |
|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|
| 5 | 2.2 | 4.9 | 0.01 | 32 | 2633 | 9738 | 2 | 0 | 66 | 9 | 0 |
| 15 | 125.0 | 99.4 | 0.60 | 46 | 35082 | 1105404 | 15 | 0 | 548 | 1 | 0 |
| 30 | 127.2 | 99.4 | 0.61 | 50 | 60533 | 45296430 | 15 | 0 | 1468 | 0 | 0 |
| 45 | 128.8 | 99.4 | 0.62 | 53 | 69202 | 102855371 | 15 | 0 | 2386 | 0 | 0 |
| 60 | 129.9 | 99.3 | 0.62 | 55 | 78639 | 164892737 | 15 | 0 | 3306 | 0 | 0 |
| 90 | 1421.7 | 82.2 | 6.82 | 59 | 1815872 | 328155451 | 22 | 1 | 5147 | 1 | 0 |
| 120 | 5785.8 | 64.4 | 27.77 | 68 | 45406781 | 10161707980 | 25 | 3 | 6987 | 1 | 0 |
| 180 | 14069.7 | 28.8 | 67.53 | 73 | 2631911768 | 1007879949203 | 25 | 7 | 10669 | 0 | 0 |

P10–P90 bands (selected):

| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |
|-----|----------------|---------------|------------------|----------------|
| 5 | 30–37 | 2.6–16.7 | 0–0 | 1805–3256 |
| 15 | 42–48 | 99.4–99.4 | 0–0 | 26617–46327 |
| 30 | 47–53 | 99.4–99.4 | 0–0 | 45317–193925 |
| 45 | 48–56 | 99.3–99.4 | 0–0 | 49153–232542 |
| 60 | 51–61 | 81.9–99.4 | 0–1 | 64701–2076804 |
| 90 | 55–69 | 71.1–99.4 | 0–3 | 76875–65775585 |
| 120 | 58–73 | 42.6–90.4 | 1–6 | 218113–1120093863 |
| 180 | 68–76 | 8.9–63.7 | 3–8 | 43378890–8535015404 |

### 3.6 SoftCap + B+ — AfkUpgrader with HUD on (counterfactual fusion)

| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |
|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|
| 5 | 5.3 | 2.8 | 0.12 | 27 | 1323 | 5283 | 5 | 0 | 77 | 10 | 3 |
| 15 | 123.9 | 12.7 | 0.83 | 44 | 26669 | 959964 | 15 | 0 | 517 | 1 | 33 |
| 30 | 128.3 | 12.9 | 0.85 | 52 | 61965 | 35998659 | 15 | 0 | 1436 | 0 | 102 |
| 45 | 129.3 | 13.0 | 0.86 | 54 | 70200 | 108040925 | 15 | 0 | 2354 | 0 | 171 |
| 60 | 130.4 | 13.0 | 0.86 | 56 | 78102 | 154621584 | 15 | 0 | 3275 | 0 | 240 |
| 90 | 1932.6 | 23.8 | 4.61 | 60 | 1032170 | 299127789 | 23 | 1 | 5113 | 1 | 379 |
| 120 | 4573.8 | 24.7 | 6.32 | 66 | 4529045 | 1234437370 | 25 | 2 | 6953 | 1 | 522 |
| 180 | 9040.4 | 24.8 | 7.44 | 70 | 189252206 | 195747593084 | 25 | 5 | 10639 | 0 | 832 |

P10–P90 bands (selected):

| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |
|-----|----------------|---------------|------------------|----------------|
| 5 | 25–29 | 1.7–3.2 | 0–0 | 744–2608 |
| 15 | 43–48 | 9.6–12.8 | 0–0 | 14510–56978 |
| 30 | 50–54 | 12.9–13.0 | 0–0 | 53935–157406 |
| 45 | 53–56 | 12.9–13.0 | 0–0 | 62962–227427 |
| 60 | 54–59 | 13.0–23.8 | 0–1 | 69433–1298680 |
| 90 | 57–67 | 13.0–24.8 | 0–3 | 76261–38284045 |
| 120 | 58–71 | 23.2–24.8 | 1–5 | 191909–287320701 |
| 180 | 68–74 | 24.8–24.8 | 3–7 | 9224657–2519386288 |

## 4. Rebirth models (SoftCap AfkUpgrader)

| Model | R1 P10 | R1 P50 | R1 P90 | R2 P50 | R3 P50 | Fraction with R1 by 180m |
|-------|--------|--------|--------|--------|--------|--------------------------|
| A full reset | 54 | 78 | 113 | 123 | 152 | 100% |
| B cash-only naked | 54 | 78 | 113 | 112 | 161 | 100% |
| B+ cash + gates | 55 | 75 | 113 | 109 | 120 | 100% |
| C hybrid (CE+peds) | 54 | 78 | 113 | 115 | 158 | 100% |

Useful upgrades remaining at 35m / 60m (P50) under SoftCap:

| Model | UsefulLeft@35* | UsefulLeft@60 |
|-------|----------------|---------------|
| B+ | ~0 (30m) / ~0 (45m) | 0 |
| B naked | ~1 / ~1 | 1 |
| A | ~1 / ~1 | 1 |
| C | ~1 / ~1 | 1 |

## 5. Calibration vs real 35:51 playtest

| Signal | Real playtest | SoftCap AfkUpgrader P50 @30m | SoftAC Afk P50 @30m |
|--------|---------------|------------------------------|---------------------|
| Rare domination | ~99% rolls Rare mid-session | Rare% 12.9 | Rare% 99.4 |
| Unique relics ~30m | ~50 uniques by ~25–30m | 52 | 50 |
| Core Luck | 21 @ ~29m | CL 15 (25-cap candidate) | CL 15 |
| Rebirth | 0 (400M unaffordable) | Rebirths 0 @30m; R1 P50 75m | same cost |
| Fusion | 0 (no HUD) | Fusions 0 with HUD off | — |
| Fusion if HUD on | — | Afk+HUD Fusions@30 102 | — |

Playtest match goals: SoftCap should **not** reproduce 99% Rare; should keep early excitement (uniques climbing by 5–15m); AfkUpgrader with HUD off should show **0 fusions** like reality.

## 6. Candidate upgrade economy (costs computed; timelines simulated)

| Upgrade | Cap (candidate) | Sample costs | Notes |
|---------|-----------------|--------------|-------|
| Attunement (CL) | 25 | 0→1: 100; 14→15: ~344661; 24→25: ~98411247 | Soft-C style; ranks 16–25 gated in B+ |
| Scan Speed | 10 | live-like 250×2.2^r | Early foundation |
| Energy | 15 + II×10 | 500×1.7^r; II from 2M×1.8^r | II after R1 (B+) |
| Pedestal | Soft 30 + Mastery 5 | 60×1.32^(L-1); Mastery 500k×3^r | Avoid live L50 finish void |
| MutationRes | 2 pre / 5 post | live ladder 250k…40B | Deep ranks post-R1 |
| SpiritMerchant | **removed** in sim | — | Redundant with pedestals |

AfkUpgrader SoftCap B+ (HUD off): median time to **zero useful buys before R1 gates** = **18** min (P10 16 / P90 20).

### Critical finding: pre-R1 shop void under B+

B+ gates CL16–25 / Energy II / Mastery / MutDeep behind R1. With ped soft-cap finishing ~15–20m, **UsefulLeft hits 0 around minute 18**, while R1 P50 is ~75m. That leaves ~45–60 minutes of CE bank-up with no shop purchases — passive waiting, not collecting joy.

Naked B/A/C keep Attunement open to 25 pre-R1, so UsefulLeft stays ≥1 longer — but naked B still has no *new* gated fantasy after foundations, and A resets the build.

**Design implication (not implemented):** prefer one of: (1) pre-R1 Mastery crumb or CL16–18 ungated; (2) lower BaseCost so R1 lands nearer 45–55m; (3) Collection HUD as the primary mid-session sink (already mandatory for engagement). Do **not** inflate costs just to stretch time.

### Dupes per minute (SoftCap B+ AfkUpgrader P50)

| Window | Dupes Δ | Dupes/min |
|--------|---------|-----------|
| 0→5 | 76 | 15.2 |
| 5→15 | 433 | 43.3 |
| 15→30 | 919 | 61.3 |
| 30→45 | 919 | 61.3 |
| 45→60 | 920 | 61.3 |
| 60→90 | 1840 | 61.3 |
| 90→120 | 1839 | 61.3 |
| 120→180 | 3688 | 61.5 |

Under SoftCap, mid-session dupe rate stays high (Commons/Uncommons keep dropping) — Collection Essence sinks are the intended absorber, not rarity inflation.

## 7. Recommendations by system

### 7.1 Luck & rarity — **SoftCap YES for Studio trial**

| Verdict | SoftCap over Soft A+C ladder |
|---------|------------------------------|
| Why | Kills 99% Rare wall; Luck L1-distance meaningful; Index 1/p_i readable; Cosmic/Celestial stay scarce |
| Trade-off | Early Epic ~15× Soft A+C at L=1; Common/Uncommon stay majority → dupe flood needs Collection |
| Not enough | Colorful band % alone ≠ better game — shop void + missing HUD still ruin the loop |

- Retune Epic (R)/(M) if Studio feels purple-early.
- Index must show (1/p_i), never raw (R/L).

### 7.2 CE & upgrades — **direction YES; B+ gate timing NO as-is**

| Verdict | Keep CL25 + ped soft-cap/Mastery; fix pre-R1 sink |
|---------|---------------------------------------------------|
| Why | Addresses CL wall + L50 finish void from playtest |
| Trade-off | UsefulLeft=0 @~18m under B+ while R1@~75m |
| Action | Pre-R1 Mastery crumb and/or CL16–18 open; merge SpiritMerchant |

### 7.3 Collection — **HUD Phase 1 mandatory before rarity ship**

| Verdict | Ship Collection opener first |
|---------|------------------------------|
| Why | HUD-off = 0 fusions (matches playtest); HUD-on absorbs Essence; SoftCap *needs* a dupe sink |
| Trade-off | Fuse stub ≠ full board; Forms optional, not 276 stamps |

### 7.4 Rebirth — **B+ preferred with timing fix; not naked B**

| Verdict | B+ structure yes; pair with shorter void or lower BaseCost |
|---------|-------------------------------------------------------------|
| R1 P50 | SoftCap Afk ~75m (soft 45–75 band upper edge) |
| vs A | Full reset slower R2/R3; collector-hostile |
| vs B | Naked keeps CL open but no post-R1 fantasy; still CE wait |
| vs C | Ped rebuild acceptable fallback if B+ feels too soft |

Priority is enjoyable collecting — cut waiting, do not inflate costs.

## 8. First-three-hour journey (SoftCap B+ Optimized P50 — simulated)

| Min | Focus |
|-----|-------|
| 5 | Luck~19, Rare~5%, Epic~0.2%, Uniques~34, CL~9, R~0, UsefulLeft~9, Fusions~9 |
| 15 | Luck~127, Rare~13%, Epic~0.8%, Uniques~49, CL~15, R~0, UsefulLeft~0, Fusions~53 |
| 30 | Luck~130, Rare~13%, Epic~0.9%, Uniques~55, CL~15, R~0, UsefulLeft~0, Fusions~142 |
| 45 | Luck~132, Rare~13%, Epic~0.9%, Uniques~58, CL~15, R~0, UsefulLeft~0, Fusions~230 |
| 60 | Luck~1416, Rare~23%, Epic~4.0%, Uniques~59, CL~22, R~1, UsefulLeft~1, Fusions~319 |
| 90 | Luck~4592, Rare~25%, Epic~6.3%, Uniques~67, CL~25, R~2, UsefulLeft~1, Fusions~498 |
| 120 | Luck~9076, Rare~25%, Epic~7.4%, Uniques~71, CL~25, R~5, UsefulLeft~0, Fusions~692 |
| 180 | Luck~14405, Rare~25%, Epic~8.0%, Uniques~74, CL~25, R~7, UsefulLeft~0, Fusions~1096 |

## 9. Retain / simplify / remove

| Action | Item |
|--------|------|
| Retain | 92 relics, pedestals, hunt, Soft A luck growth trial, Collection data, Resonance |
| Simplify | Attune sprawl until Index live; Focus copy → Index chase |
| Merge/remove | SpiritMerchant |
| Replace (Studio trial) | Tier ladder sampler → SoftCap |
| Add | Collection HUD, ped Mastery, B+ gates, Attunement 25 |

## 10. Implementation sequence (after approval — not done now)

1. Collection HUD + onboarding  
2. SoftCap + Index (1/p_i) behind Studio flag  
3. Upgrade/pedestal candidates behind flag  
4. Rebirth B+  
5. Forms / hunt targeting  

Full `lune run tests/run` after each phase. Production `Active = nil`.

## 11. Risks & acceptance criteria

| Risk | Mitigation / acceptance |
|------|-------------------------|
| Early Epic too common | Raise Epic R or cut M; accept if Epic/1000 @L=150 in 4–12 |
| Common dupe flood | Forms/Essence sinks; Focus missing Index |
| UsefulLeft=0 before R1 | Pre-R1 Mastery crumb or BaseCost tweak |
| Sim ≠ BindService | Studio human playtest after Phase 1–2 |
| Frozen incomes vs SoftCap odds | Later retune RelicIncome if trial ships |

**Acceptance for next human playtest:** Rare% mid-session ≪ 50%; Collection opens; at least one post-foundation sink before R1 or R1 inside soft band with nonempty post-R1 shop.

## 12. Probability invariants (this run)

- SoftCap Σp = 1 at tested L (unit tests).
- SoftCap L1(60,150) > 0.05.
- Ladder Rare @150 > 95%; SoftCap Rare @150 < 40%.
- Roster size 92. Rebirth BaseCost 400000000.

---

*Generated by `lune run tests/unifiedProgression` with 40 seeds.*