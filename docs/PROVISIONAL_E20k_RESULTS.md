# Provisional candidate results — E20k_L12_C17_HR

**For Astra + human review. Live economy defaults were not shipped.**

## Configuration under test

| Knob | Value |
|------|-------|
| Epic+ denom | 20,000 (live 500) |
| Legendary+ denom | 500,000 (live 25,000) |
| Core Luck | `10^(rank/12)`, cost growth 1.7 |
| Hunt | floor 2, factor 0.08, ref scan 4s, max bonus 6, hunt luck ×5 |
| Relic CE/sec | **Frozen** to live per-relic incomes (weights preserved) |

## Sim setup

- Seeds: **500** identical across baseline and candidate
- Candidate duration: **4 h**; baseline comparison: **2 h**
- Behaviours: `passive` (scan, no spend), `upgrader` (scan+buys+rebirth), `hunter` (upgrader + signals)
- **Full luck stack:** Core × Rebirth × (1+Codex essential luck) × (1+Showcase luck) × potion (×2 while buff up)
  - Codex milestones from unique Essential relics (Common→Legendary)
  - Showcase: buys Simple Stance when affordable, upgrades when CE allows
  - Potions: hunter 12% Luck potion per capture; upgrader ~35% chance every 10 min (offering proxy)
- **Hunter fidelity:** start 3 signals, max 5, +1 / 120s; capture cycle = hold 6s + travel 14s = **20s**; cannot capture without a signal (after burst, ~1 capture / 120s)
- Low-tier mass: P(Common)+P(Uncommon) under MaxLuck vs Focus=Common (collection soft-lock check)

## Headline table

| Build | Beh | Epic P10/P50/P90 | Epic% | Leg P50 | Rebirth1 P50 | Rebirth2 P50 | Epic@15 | Luck@15 | LowTier@60 (MaxLuck / Focus Common) |
|-------|-----|------------------|-------|---------|--------------|--------------|---------|---------|-------------------------------------|
| baseline | passive | 2.9 / 19.0 / 61.6 | 99% | — | — | — | 0.5 | 1.15 | 0.9725 / 0.9778 |
| baseline | upgrader | 1.7 / 4.0 / 6.3 | 100% | 12.1 | 24.1 | 35.2 | 107.3 | 238 | 0.0000 / 0.9778 |
| baseline | hunter | 0.7 / 2.3 / 4.3 | 100% | 9.1 | 20.7 | 31.8 | 248.3 | 276 | 0.0000 / 0.9778 |
| E20k_L12_C17_HR | passive | 116.8 / — / — | 22% | — | — | — | 0.0 | 1.15 | 0.9729 / 0.9778 |
| E20k_L12_C17_HR | upgrader | 10.2 / 22.7 / 39.5 | 100% | 80.0 | 97.1 | 127.5 | 0.3 | 24.5 | 0.0000 / 0.9778 |
| E20k_L12_C17_HR | hunter | 6.3 / 18.3 / 37.1 | 100% | 76.4 | 93.0 | 122.9 | 0.5 | 23.5 | 0.0044 / 0.9778 |

## Interpretation for Astra

### vs playtest / baseline

- Baseline upgrader Epic P50 **4.0 min**, Epic@15 **107.3**, luck@15 **238**.
- Candidate upgrader Epic P50 **22.7 min**, Epic@15 **0.3**, luck@15 **24.5**.
- Full stack (Codex/Showcase/potions) makes candidate luck higher than the Phase-0 core-only sweep — expect somewhat earlier Epics than the 25.7 min core-only figure.

### Hunter model check

- Mean captures over 4h hunter: **122** (~30.5 / hour).
- With 20s cycle and 120s regen, after the opening burst the binder is **signal-gated** (~30 captures/hour theoretical max from regen alone; lower if walking longer).
- Hunter Epic P50 18.3 vs upgrader 22.7 — active should stay ahead without returning to baseline flood (Epic@15 hunter 0.5).

### Post-Rebirth escalation (important)

- Rebirth1 P50: **97.1**; Rebirth2 P50: **127.5**; Rebirth3 P50: **~150**.
- Mean Epics in the **30 minutes after first Rebirth**: **44.1** (skills reset; Rebirth luck ×1.5 + kept high-income relics + Codex/Showcase + potions remain).
- Mean luck in that post-R1 window: **~834**.
- **Review flag:** the first hour is fixed, but **post-Rebirth re-opens an Epic flood** unless Phase 1 also softens Rebirth luck growth, adds a post-Rebirth Focus default, or gates Rebirth permanent power differently. Do not ship rarity-only without addressing this.

### High-luck low-tier collection

- At 60 min upgrader, P(Common∪Uncommon) under **MaxLuck**: **0.0000** (≈0 means soft-locked).
- Same moment with **Rarity Focus = Common**: **0.9778**.
- **Conclusion:** MaxLuck erases low tiers; Focus restores them. Phase 1 must ship Focus UX / prompts — not optional.

### Entertainment (not just delay)

- Candidate removes the 15‑minute Epic carpet-bomb; Epic becomes a mid-session event for upgraders.
- Passive-without-upgrades rarely completes Epic (by design of dual matrix) — spending CE on luck/scan is the on-ramp.
- **Still missing for fun:** duplicate sinks, fusion, mutation unlocks (see Phase 2 plan). Slower rarity without those is emptier waiting.

## Studio test build (not live)

`BalanceTrials.Active` remains **`nil`** in the repo (shipping path unchanged).

1. Open [`src/shared/BalanceTrials.luau`](../src/shared/BalanceTrials.luau).
2. Locally set `BalanceTrials.Active = "E20k_L12_C17_HR"` for a Studio test play session only.
3. Rolls / Core Luck / hunt reform use the trial; **relic CE/sec stays on live per-relic incomes**.
4. Revert `Active` to `nil` before any production publish.

Wired for trials (only when Active is set): `RollRules`, `RollService` CoreLuck, `SkillService` CoreLuck cost, `BindService` hunt batch/luck, UI CoreLuck labels. `RelicIncome` always uses live denoms.

## Phase 2 (fun layer)

See [`docs/PHASE2_COLLECTION_PLAN.md`](PHASE2_COLLECTION_PLAN.md) — Essence, fusion cap 3, mutation goals that unlock mechanics, family perks, Focus/Attune for Codex soft-lock.

## Reproduce

```bash
lune run tests/provisionalCandidate 500
```
