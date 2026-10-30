# Automation-First Testing Workflow

Human playtests are scarce. **Automated simulations are the primary balance validation method.** Humans validate fun/usability at milestones only.

## Principles

1. After every meaningful balance change (rarity, relic odds, upgrades, pedestal income, Collection/Essence, Rebirth), run the integrated progression suite before asking for human time.
2. Prefer **shared gameplay formulas** (`SoftCapRarity`, `RollMath`, `Formulas`, `SkillConfig`, `CollectionMath`, `RelicIncome`, `Rebirth`) over one-off playtest-fit curves.
3. **Disclose approximations** in every report (hunt cadence, BindService, fusion board stubs, frozen incomes, etc.).
4. Do **not** calibrate exclusively to a single recorded session. Use playtests as anchors, multi-seed P10/P50/P90 as truth.
5. Never request a long human test while essential systems are inaccessible or known softlocks remain.

## Automated suites (run these)

| Command | Purpose |
|---------|---------|
| `lune run tests/run` | Full unit/spec suite (must stay green) |
| `lune run tests/unifiedProgression [seeds]` | SoftCap + upgrade/Rebirth policy matrix (writes Rev4-style report) |
| `lune run tests/softCapPlaytestCorrected` | Playtest-volume SoftCap vs SoftAC check |
| `lune run tests/simPerfBenchmark` | Event vs PerSecond regression + SoftCap cache microbench |
| `lune run tests/phase34Proposal QUICK` | Fast iterate (5 seeds, 2 variants × 2 policies) — **default for dev** |
| `lune run tests/phase34Proposal STANDARD` | 10 seeds, full variant/policy matrix before recommendations |
| `lune run tests/phase34Proposal FULL` | 40 seeds final validation only — do **not** run after every edit |

### Performance targets (same machine)

| Mode | Budget |
|------|--------|
| QUICK | ≤ 30s |
| STANDARD | ≤ 2 min |
| FULL | ≤ 5 min if feasible |

Sims use **event-driven** time + cached SoftCap weight tables. FusionIncome in proposal sims is still a **stub** — never ship economy from its ×lift.

### Policies (player behaviours)

Always cover at least:

- **AfkUpgrader** — scan-heavy, buys upgrades, rare hunts  
- **Casual** — slower buys, occasional Collection  
- **Hunter** — frequent captures + hunt luck  
- **Optimized** — aggressive buys + Collection sinks  

### Scenario checks (automated)

Sims / specs should catch:

- Fresh start → first discoveries  
- Upgrade purchases until caps  
- Duplicate → Essence → fusion recipes (when HUD on)  
- Pre-R1 shop emptiness (`UsefulLeft` / `UsefulEmptyAt`)  
- Rebirth affordability and post-R1 unlocks  
- Invalid / unaffordable paths (failed purchase pressure)  
- Softlocks: no useful spend for long droughts while CE piles up  

### Player-experience proxies (track these)

| Proxy | Counts as meaningful? |
|-------|------------------------|
| First Unique (esp. Rare+) / first-of-tier | Yes |
| First Epic+ / Unique Epic | Yes |
| Significant upgrade unlocks (CL×5, Scan max, slot unlock, Mastery) | Yes |
| Rebirth R1/R2/R3 | Yes |
| Collection board unlock / first 1–3 fusions / mutation goals | Yes |
| Routine CoreLuck +1, every fuse after the first few, every mutation spice | **No** (noise) |

Also track: longest drought (min), dupe volume, minutes with `UsefulLeft=0`, Luck upgrade → odds L1-distance, R1/R2/R3 timing, goals across 0–180 min.

## Human testing schedule

| Trigger | Human time | Goal |
|---------|------------|------|
| New UI / feature wire-up | **2–5 min smoke** | Opens, clicks, no crash |
| Several systems integrated (e.g. SoftCap + Collection + shop fix) | **One 15–30 min** | Feel: discovery mix, dupe fatigue, shop void, Index odds |
| Stable release candidate | **45–60+ min** | Full loop including Rebirth if intended |

Do **not** ask for 30–35 min after every tweak.

## Studio vs production

- SoftCap and Collection prototypes: **Studio trial only** (`BalanceTrials.StudioTrialId`).  
- Production: live rarity ladder + live defaults until a milestone ships.  
- Proposal sims may use candidate costs/gates; they must not silently edit live `Config` / `SkillConfig`.

## Report checklist

Every automation report should state:

1. What changed (or “proposal only — not implemented”)  
2. Seeds, policies, minutes  
3. Approximations / non-shared stubs  
4. P10/P50/P90 for proxies  
5. Whether a human test is **requested** and at which tier (smoke / 15–30 / RC)  
