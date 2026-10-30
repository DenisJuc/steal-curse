# Studio progression report — soft A+C + paced collection

**Status:** Simulation + Studio playtest prototype. Live defaults unchanged (`Active = nil`). **Live release blocked.**

**Config:** E20k dens + LuckGrowth **1.25** + CoreLuck soft **k=0.05** + fusion slots / targeted recipes / mutation milestones / Essence sinks.
**Seeds:** 80 (Optimal spend). Alt policies: 40 seeds each. **Duration:** 3h continuous.

## Rarity metric integrity

Roster: **13** exact Epic base relics, **47** Epic+ (Epic through Cosmic).
Soft A+C rarity pacing is unchanged by collection work.

## Rebirth timing (population P50)

- R1: **92.3** min · R2: **116.5** · R3: **137.0**
- First fusion P50: **2.6** min · First mutation goal P50: **19.0** min

### Rebirth depth (not just speed)

- **Each Rebirth** grants a Resonance pick (Collector / Binder / Seeker). Stacks 2–3 unlock Salvage, Daily Attune, Quick Bind, Free Signal, Mutation Tint, Post-R Attune.
- **R1** also adds a fusion board slot. Later Rebirths deepen Resonance identity rather than only multiplying Luck/Income.
- Do **not** automatically slow R2/R3; validate in Studio whether Resonance choices feel like new objectives.

## Event taxonomy (corrected)

Prior 'Meaningful≈2510' counted ordinary mutation drops and repeated sinks. New buckets:

| Bucket | What counts |
|--------|-------------|
| **UniqueMechanics** | Distinct unlock flags (Attune recipe, board slots, Resonance unlocks, etc.) — once each |
| **FirstMilestones** | First fusion, each mutation goal claim, first Epic/Legendary, each Rebirth, first Epic Catalyst, first rank-3 |
| **BuildDecisions** | Charm pick, Charm respec, Resonance pick |
| **Ordinary** | Fuse rank-ups, Attune crafts, pedestal/skill buys, dup mutations, salvage |
| **LongestNewGap** | Longest minutes between UniqueMechanics / FirstMilestones / BuildDecisions |
| **DeadMinutes** | Sum of (gap − 5 min) over gaps between genuinely new objectives |

## Checkpoints (means, Optimal spend)

| Min | Epic | U.Epic | Goals | Board | Fuse | Mech | Mile | Build | Ord | GapMax | Dead | Ess | Spent | R# |
|-----|------|--------|-------|-------|------|------|------|-------|-----|--------|------|-----|-------|----|
| 15 | 0.2 | 0.2 | 0.1/9 | 1.0/1 | 1.1 | 1.2 | 1.4 | 1.1 | 233 | 11.7 | 0.5 | 1019 | 75 | 0.0 |
| 30 | 1.2 | 1.2 | 4.4/9 | 2.3/2 | 4.7 | 7.7 | 7.9 | 3.4 | 335 | 15.2 | 10.5 | 1140 | 2689 | 0.0 |
| 60 | 7.5 | 5.2 | 5.8/9 | 3.0/3 | 6.6 | 9.8 | 10.2 | 6.1 | 482 | 15.8 | 22.5 | 6797 | 5415 | 0.1 |
| 90 | 24.9 | 10.2 | 6.9/9 | 3.8/4 | 8.9 | 12.4 | 12.8 | 7.5 | 764 | 24.8 | 39.0 | 12808 | 8294 | 0.7 |
| 120 | 86.6 | 12.5 | 8.1/9 | 4.9/5 | 11.9 | 15.4 | 15.7 | 9.6 | 1190 | 27.8 | 59.5 | 19148 | 11699 | 1.7 |
| 180 | 569.5 | 13.0 | 8.8/9 | 5.0/5 | 12.3 | 17.4 | 18.9 | 12.1 | 2596 | 34.2 | 100.6 | 41332 | 18073 | 4.1 |

Luck @180: **10.8K** · Catalysts: **12.9** · Resonance picks: **4.1** · Charm changes: **3.0**

## Essence economy (Optimal bot @180m, means)

| Sink | Essence spent | Role |
|------|---------------|------|
| Fusion ranks | **1359** | Board specialization (primary early sink) |
| Epic Catalyst | **1163** | Dup Epic → board access |
| Attune tickets | **2971** | Repeatable Codex soft-lock |
| Targeted Attune | **4444** | Tier Focus bursts |
| Mutation Focus | **5756** | Post-25 unique mutated craft |
| Family Attune | **1020** | Frequency family bias |
| Charm respec | **360** | Build change |
| Attune cap upgrade | **1000** | Permanent charge capacity |
| **Total spent** | **18073** | Bank left ≈ **41332** |

### Suboptimal spend (same dens, alt policies)

| Policy | Bank @180 | Spent | Goals | Notes |
|--------|-----------|-------|-------|-------|
| Optimal | 41332 | 18073 | 8.8 | Uses all unlocked sinks |
| FusionOnly | 44530 | 2462 | 8.9 | Fusion + catalysts; skips Attune/Focus loops |
| Hoard | 46484 | 17 | 7.8 | First fusion only, then banks |

A low Optimal bank is not proof of health alone — FusionOnly/Hoard show whether sinks are optional or mandatory. Studio playtest should feel worthwhile Attune/Focus spends, not obligation.

## Three-hour endgame

By ~180m Optimal bots often finish **~9/9** launch MutationGoals and fill **5/5** board slots. Remaining in-prototype objectives:

1. **Resonance stacks ×2–3** — Salvage Focus, Daily Attune, Quick Bind, Free Signal, Mutation Tint, Post-R Attune
2. **Epic Catalyst specialization** — fuse catalyzed Epics; salvage excess dups
3. **Rank-3 fusions** — needs mutated copy of that relic (rare, intentional)
4. **Legendary+ collecting** — soft A+C rarity still the long chase
5. **Charm respec / Family Attune** — build identity changes

Expansion hooks (config only, not implemented): `CollectionConfig.ExpansionHooks` — LegendaryCatalyst, ResonanceMastery, FusionBranch, VariantCodex, RegionCollection.

## Collection pacing notes

- Board starts at **1** slot; milestones / Rebirth open more (max 5).
- Rank recipes: **3 / 5 / 4** copies (rank 3 needs a mutated copy).
- Prior carpet (~21 Charms @15m) fixed via slots + targeted recipes, not Essence cost inflation.

## Studio playtest checklist

1. Local only: `BalanceTrials.Active = "E20k_L12_C17_HR"` and `CollectionPrototype = true`
2. Open **Collection** panel — confirm Next Goals, Fuse ready, Charm buttons, Attune / Mut Focus
3. First fusion within ~2–5 minutes; Charm choice feels like a decision
4. After Rebirth: Resonance pending; stack unlocks fire Notify
5. Bloodmoon → Epic Catalyst craft → Epic fuse path
6. Revert both flags before any publish. **Do not ship live.**

## Studio enable

```lua
BalanceTrials.Active = "E20k_L12_C17_HR"
BalanceTrials.CollectionPrototype = true
```

```bash
lune run tests/studioProgression 100
```
