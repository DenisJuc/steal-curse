# Progression Systems — How Luck, CE, Hunting, and Rewards Actually Work

Hand this document to another model (or a designer) as the **source-of-truth summary** of the live codebase. Numbers and formulas below are taken from `src/shared` and `src/server/Services`, not from design intent alone.

**Repo:** Relic Collector / Steal Curse (Roblox Luau)  
**Balance sim:** `lune run tests/economyReport`  
**Related:** `docs/ROSTER.md` (relic names), `tests/lib/economySim.luau` (AFK progression model)

---

## 1. What the player is complaining about (and why it is real)

A ~15 minute organic play session reached Epics and Legendaries quickly. After that, many cheap skills and pedestal upgrades felt “done,” leaving **Core Luck** as the long remaining grind. Catching one spirit also dumps a large batch of rolls (often described as “15 rolls”), which feels disconnected from the idea of a rare find.

The AFK economy simulator already reproduces the pacing problem. From `tests/economyReport.luau`, seed 1 roughly shows:

| Time | Luck | Best tier seen | Notes |
|------|------|----------------|-------|
| 5 min | ×10 | Rare | Core Luck rank ~10 |
| 10 min | ×31.6 | Epic | |
| 20 min | ×100 | Epic | ~1M CE, still pre-Rebirth |
| 30 min | ×251 | Legendary | |
| ~32 min | — | — | First Rebirth |

The report’s own comment targets say “luck ≤ ×20 at 5 min” and “~1M CE by 20 min,” but they do **not** constrain tier pacing. At ×100 luck, Epic is already a large fraction of every roll (see §3). Active hunting makes this worse than AFK because each capture grants many rolls at once.

**Models:** there are **92** relics in data and about **26** 3D models under `assets/RelicModels/`. More models improve presentation; they do **not** fix rarity pacing. The roster size (92) is enough to rebalance against; the systems are the problem.

---

## 2. The game loop in one picture

There is a single currency: **Cursed Energy (CE)**. Relics on pedestals generate CE/sec. Relics come from rolls. Rolls use **luck** to pick a **rarity tier**, then a relic inside that tier.

```
                    ┌─────────────────┐
                    │  Luck stack     │  CoreLuck × Codex × Showcase × Potion × …
                    └────────┬────────┘
                             │ EffectiveLuck (may be capped by Rarity Focus)
                             ▼
   AFK Scan ──1 roll──► RollMath ──► Relic (+ optional Mutation)
                             ▲
   Hunt Bind ──1 + N rolls───┘
                             │
                             ▼
                      Inventory / Auto-sell
                             │
                             ▼
                   Pedestals → CE/sec → buy skills, slots, showcases, rebirth
```

Everything that “gives free rolls” (hard bounties, offering boxes, Lost One gifts) uses the **same** `RollService` / `RollMath` path as hunting and scanning.

---

## 3. Rarity and luck math

### 3.1 Tier ladder

Defined in `src/shared/RarityConfig.luau`. The denominator is the base “1 in X” chance of rolling **this tier or higher** at 1× luck:

| Tier | Denominator |
|------|-------------|
| Common | 1 |
| Uncommon | 4 |
| Rare | 45 |
| Epic | 500 |
| Legendary | 25,000 |
| Mythic | 10,000,000 |
| Celestial | 1e11 |
| Cosmic | 1.32e15 |

### 3.2 Probability formulas

All rolling and all odds UI go through `src/shared/RollMath.luau`. The important identities:

```luau
-- Chance of tier T or higher
Q(T+) = min(1, Luck / Denominator(T))

-- Exact tier mass
P(T) = Q(T+) - Q(next tier +)

-- Inside the tier: weighted pick by Relic.Weight
-- Signal Frequency may multiply Weight for one Family; it never changes tier masses.
```

Tier roll uses a chained conditional ladder so tiny probabilities stay numerically stable (`RollMath.rollTierIndex`).

### 3.3 Worked example: luck ×100

At EffectiveLuck = 100 (typical ~20 minutes of AFK sim progression):

| Tier or higher | Q |
|----------------|---|
| Common+ | 100% |
| Uncommon+ | 100% |
| Rare+ | 100% |
| **Epic+** | **100/500 = 20%** |
| Legendary+ | 100/25000 = 0.4% |
| Mythic+ | ~0.001% |

So about **one in five rolls is Epic or better**. A single hunt capture that grants ~12 rolls expects multiple Epics. Legendary is uncommon per roll but common across a short hunt session.

### 3.4 Full luck stack (product)

`MultiplierService` defines Luck as a **Product** kind: every source multiplies.

| Source | How it works | Soft caps |
|--------|--------------|-----------|
| **CoreLuck** skill | `10 ^ (rank / 10)` — rank 0 = ×1, 10 = ×10, 20 = ×100, 100 = ×10 billion | Main purchased luck |
| **Codex** essential milestones | Additive bonuses totaling up to **+50%** luck (`Config.Luck.CodexMaxBonus`) | From collecting Common→Legendary |
| **Showcase** (active only) | Up to **+10%** luck at level 4 | `ShowcaseConfig.Levels` |
| **Luck Potion** | Factor up to **×2** | `Config.Luck.MaxConsumable` |
| **Lightning Luck** | ×1.5 for 60s per struck capture, refreshable to 180s | Struck binds give **no relic rolls** |
| **Rebirth** | Permanent `1.5 ^ rebirthCount` | Skills reset on rebirth; this does not |
| **Zone event** | Extra factor on that capture batch | Capped at **×1.5** (`Config.Luck.MaxEvent`) |

Registration sites: `RollService` (CoreLuck), `CodexService`, `ShowcaseService`, `ItemService`, `LightningService`, `RebirthService`. Zone event luck is applied as `RollOptions.LuckFactor` inside `BindService`, not as a persistent multiplier.

### 3.5 Rarity Focus

From `Config.Focus`:

- Default focus is **`MaxLuck`**: no cap; EffectiveLuck = FullLuck.
- Focusing a specific tier caps luck so that `P(that tier or higher) = 50%`, i.e. `cap = 0.5 × Denominator(tier)`.
- Purchased luck is never removed; focus only lowers the **working** value for rolls.

Because default is MaxLuck, early Core Luck ranks feed straight into Epic odds with no player opt-in.

### 3.6 Core Luck cost curve

```luau
-- Formulas.coreLuck
luck = 10 ^ (rank / 10)

-- SkillConfig CoreLuck cost from rank n → n+1
cost = ceil(100 * 1.6 ^ n)
```

Design comment in SkillConfig: “×10 luck costs about ×100 CE” (sqrt relationship). In practice early ranks are cheap enough that ×100 luck arrives while the player still feels early-game, and later ranks become a dull sink after other skills are finished.

---

## 4. Relic roster and unused axes

### 4.1 Counts

From `RelicConfig.luau` comments / entries (**92** total):

| Tier | Count |
|------|------:|
| Common | 16 |
| Uncommon | 15 |
| Rare | 14 |
| Epic | 13 |
| Legendary | 12 |
| Mythic | 10 |
| Celestial | 8 |
| Cosmic | 4 |

Each relic has a unique **Weight** inside its tier so every item has distinct base odds. Base income is derived from those odds (see §6), never hand-authored per relic (optional `IncomeBonus` exists for exceptions).

### 4.2 Metadata that exists but barely affects rarity

| Field | Values | Used for today |
|-------|--------|----------------|
| **Family** | Demonic, Spiritual, Arcane, Astral | Signal Frequency reweights that family **inside** the rolled tier; Codex theme completion unlocks focusing a family |
| **ObjectType** | Weapon, Book, Mask, Crystal, Special | Capture animation family only |
| **Vfx** | Ember, Frost, Storm, Shadow, Blood, Holy, Spirit, Bloom, Void, Starlight, Sand, Toxin, None | Pedestal / reveal cosmetics |
| **Mutation** | Golden → Abyssal | Income multiplier only (see §7) |

These fields are the natural place for a second rarity layer (themes, variants, “size” style systems) without inventing hundreds of new base relics.

### 4.3 3D models

About **26** `.rbxm` files exist for **92** relic ids. Recommendation for balance work: treat the data roster as complete enough; queue model coverage separately.

---

## 5. Hunting, scanning, and why “15 rolls” exists

### 5.1 Personal signals

`Config.Signals`: start with 3, max 5, one regenerates every **120 seconds**, spawn 25–90 studs from the player, personal-only.

### 5.2 Bind

`Config.Bind`: hold ~6 seconds (shortened by Binding Efficiency and zone mastery). On success the signal is consumed and rewards are granted once.

### 5.3 Bonus discoveries per capture

Documented in GDD terms as “active hunting should beat AFK.” Implementation:

```luau
-- Formulas.bonusRolls
B = max(BonusFloor, ceil(BonusFactor * RegenSeconds / scanIntervalSeconds))

-- Config.Hunt
BonusFloor = 10
BonusFactor = 0.35
-- Config.Signals.RegenSeconds = 120
```

Then in `BindService`:

```luau
base = bonusRolls(scanInterval, 120, Hunt)
bonusCount = ceil(base * ResonantHarvestMult * BonusMultiplier)
rolls = RollMany(player, 1 + bonusCount)  -- first roll = "capture", rest = "bonus"
```

`BonusMultiplier` is the product of hunt streak × zone-event bonus × purified-zone factor, then capped by `Config.Hunt.MaxBonusMultiplier = 3`.

**Base bonus vs scan speed (before streak/harvest/events):**

| Scan interval | B | Rolls per capture (1+B) |
|---------------|--:|------------------------:|
| 4.0 s (default) | 11 | 12 |
| 2.0 s | 21 | 22 |
| 1.0 s (max Scan Speed) | 42 | 43 |

Resonant Harvest adds up to +50% on that count. With the ×3 bonus multiplier cap, a late kit can produce on the order of **100+ rolls from one bind**.

Hard daily bounty reward is literally `{ Rolls = 15 }` — the same ballpark as one ordinary capture’s floor. That is why “15 rolls” feels like the unit of reward everywhere.

### 5.4 Design tension: Scan Speed

Buying Scan Speed:

1. Speeds up AFK auto-rolls (more relics per minute while idle).
2. **Increases** hunt bonus rolls, because `B` uses `1 / scanInterval`.

So the skill that feels like “QoL for AFK” also multiplies active loot volume.

### 5.5 Lightning exception

If the signal is lightning-struck, the bind grants **no relic rolls**. The whole reward is Lightning Luck on the multiplier stack for a while. Easy to read as a failed capture.

### 5.6 AFK scanning

`ScanService` rolls **1** relic every scan interval (modified by Haste potions). Auto-roll defaults on. Hunting’s intended advantage is entirely the bonus-roll batch.

---

## 6. CE economy

### 6.1 Income formula

From `Config.Economy` comments and `Economy` / `RelicIncome`:

```
CE/sec = IncomeMultiplier
       × RebirthIncomeMultiplier
       × Σ ( relicBaseIncome × mutationIncomeMult × pedestalLevelMult )
```

```luau
relicBaseIncome = round(IncomeScale * oneInOdds ^ IncomeExponent)
-- IncomeScale = 1, IncomeExponent = 0.6
pedestalMult = LevelGrowth ^ (level - 1)  -- 1.1^(level-1), level 50 ≈ ×100
```

`oneInOdds` is computed once at load from RollMath at luck 1 with no focus (`RelicIncome`).

Global income bonuses (Codex, Showcase, Energy Conduction, Fortune potion, Rebirth income) are an **Additive** multiplier stack: `1 + sum(bonuses)`, so they do not compound with each other accidentally.

### 6.2 Pedestals and selling

| Thing | Value |
|-------|-------|
| Starting pedestals | 3 free |
| Slot 4 / 5 / 6 prices | 2,500 / 150,000 / 25,000,000 CE |
| Max pedestal level | 50 |
| First upgrade cost | 60 CE |
| Upgrade cost growth | ×1.28 per level |
| Sell value | 30 seconds of that relic’s income (× merchant bonus) |

### 6.3 Offline

25% of online income rate, capped at 2 hours by default (Spirit Reservoir extends), ignored if away &lt; 60 seconds.

### 6.4 Rebirth

```luau
cost(n) = 4e8 * 4^n
incomeMult = 2^n
luckMult = 1.5^n
```

On rebirth: CE → 0, every pedestal level → 1, **every skill rank → 0**. Kept: relics, unlocked slots, Codex, showcases, titles, lanterns, mastery, potions. Permanent luck/income multipliers stay.

Important implication: after rebirth, Core Luck is low again but Rebirth luck (×1.5, ×2.25, …) and leftover income/relic quality still accelerate the climb — the early Epic flood can repeat each cycle unless denominators or roll volume change.

### 6.5 Skill tree CE sinks (summary)

Three branches in `SkillConfig.luau`:

**Resonance** — Core Luck, Scan Speed (4s→1s), Frequency Focus, Mutation Resonance (expensive; rank 1 at 250k CE).

**Sanctuary** — Energy Conduction (+2% income/rank), Spirit Merchant (sell %), Spirit Reservoir (offline cap).

**Binding Arts** — Spirit Sight, Binding Efficiency (shorter hold), Resonant Harvest (+10% bonus rolls/rank), Swift Step.

Player-felt order: cheap Binding/Sanctuary/Scan complete the “game feels finished” kit; Core Luck remains as the long geometric sink. That matches the complaint.

---

## 7. Mutations

`MutationConfig.luau`:

| Resonance rank | Mutation chance | Newly unlocked | Income × |
|----------------|----------------:|----------------|----------|
| 0 | 0% | — | — |
| 1 | 10% | Golden | 1.5 |
| 2 | 20% | Corrupted | 2 |
| 3 | 30% | Bloodmoon | 2.5 |
| 4 | 40% | Divine | 3 |
| 5 | 50% | Abyssal | 4 |

Rules:

- Rolled **after** the relic is chosen.
- At most one mutation per discovery.
- Among unlocked mutations, pick by Weight.
- Zone event Star Fall can multiply mutation chance ×2 for captures in Ancient Ruins.
- Codex treats mutated Legendary/Cosmic finds as **title prestige**, not power for Essential luck.

**Gameplay identity today:** mutations are almost entirely “more CE/sec.” They do not gate content, change hunt rules, or create a chase layer comparable to Big Gardens–style variants.

---

## 8. Side systems that also dump rewards

### 8.1 Daily / weekly bounties

`Config.Bounties`:

| Difficulty | Reward shape |
|------------|--------------|
| Easy | 3 minutes of current income |
| Medium | 6 minutes + 1 random potion |
| Hard | 12 minutes + **15 discovery rolls** |
| Weekly | 40 minutes + potion bundle |
| Streak chests (days 3 / 5 / 7) | Larger CE + potions |

Pool goals are things like “capture 5 spirits,” “capture in Heart,” “open an offering,” “cleanse a shrine.” Progress is event-driven (`Bounties.luau` + `BountyService`).

### 8.2 Lost offering boxes

`Config.Offerings` + `Offerings.luau`:

- Weighted tiers: Common 70 / Uncommon 25 / Rare 5.
- Pity: after 9 commons in a row, next box is at least Uncommon.
- Rewards include CE minutes, **5–30 rolls**, potions, and a rare lantern chance on the top tier.
- Paid out through `WildFindsService` using `RollService.RollMany`.

### 8.3 Lift the Curse (shrines)

Cleanse a shrine: CE minutes (min floor), random potion, lore page. Purifying a whole zone grants title/lantern and **×1.1 bonus rolls** in that zone (inside the hunt bonus multiplier cap).

### 8.4 Potions

Three consumables (`ItemConfig`):

| Potion | Effect | Duration |
|--------|--------|----------|
| Luck | up to ×2 luck | 10 min (stack time to 1 h) |
| Haste | scan interval ×0.75 | 10 min |
| Fortune | +50% income | 10 min |

**12%** chance to drop one potion on a successful (non-lightning) capture. Also from bounties, offerings, Codex milestones, first Legendary, curse cleanses.

### 8.5 Zone events

Rotate on a long timer (`Config.ZoneEvents`):

| Event | Area | Effect on captures there |
|-------|------|--------------------------|
| Blood Moon | Abandoned Village | Luck ×1.5 (event cap) |
| Spirit Storm | Haunted Forest | Bonus roll multiplier ×2 |
| Star Fall | Ancient Ruins | Mutation chance ×2 |

### 8.6 Hunt streak

Depth bands from hub center (Edge / Deep / Heart) add +0.1 / +0.2 / +0.3 per capture to a streak multiplier, max ×2, resets in town or after idle. Multiplies bonus roll **count**, not luck (unless combined with events).

---

## 9. Codex and Showcases (small luck, big collection)

### Codex (`CodexConfig`)

Essential milestones track unique base relic ids from Common through Legendary (mutations and Mythic+ do not add Essential power). Fractions 20%→100% grant luck bonuses totaling +50% and some income %. Potion bundles on claim. Collection/mutated milestones are titles.

### Showcases (`ShowcaseConfig`)

Pose displays on the plot podium. Only the **active** showcase grants buffs. Levels 1–4 share one table (max +15% income, +10% luck). Unlocks via CE purchase, specific relic, Codex milestone, or zone mastery.

---

## 10. What is and is not balanced today

### Working as implemented (internally consistent)

- Single roll pipeline for server + odds UI (`RollMath.contextFor` + `RollRules`).
- Luck as a product stack; income as additive-then-multiply.
- Relic income derived from odds (rarer → more CE/sec).
- Active hunting mathematically dominates AFK via bonus batches.
- Rebirth, Codex, showcases, potions, events all plug into the same multipliers.

### Broken relative to a healthy rarity fantasy

1. **Roll volume × early luck** — Denominators assume sparse rolls; hunting and rewards grant batches of 10–40+.
2. **Scan Speed double-dip** — Faster AFK and larger hunt payouts.
3. **Spend order** — Kit skills finish first; Core Luck is both too strong early (ranks 10–20) and the boring endgame sink.
4. **Mutations / families / ObjectType / Vfx** — Do not create a second chase axis; CE/sec is the only prize.
5. **Reward pipes** — Bounties and offerings reprint the same roll spam.
6. **Stated sim targets vs reality** — Luck/CE targets ignore “when should Epic feel special?”

---

## 11. Open questions for redesign (for Astra + Composer)

Do not answer with code yet; pick a direction first.

1. Should one capture be **1–3 meaningful rolls** (collector fantasy) or a **large batch** (current GDD active-vs-AFK target)? Those goals conflict at current denominators.
2. Should Scan Speed **stop** increasing hunt bonus rolls (decouple `B` from scan interval)?
3. Is Epic-by-20-minutes intentional for retention, or a bug versus “luck stays low early”?
4. Prefer a second rarity axis via: **mutations as true variants**, **family/theme locks**, **ObjectType sets**, **size/variant (Big Gardens style)**, **zone-exclusive pools**, or a mix?
5. Keep **92 base relics** and deepen variants, or grow the roster?
6. After Rebirth resets Core Luck, should the early Epic flood return each cycle?

---

## 12. File index

| Concern | Primary files |
|---------|----------------|
| Tier odds | `src/shared/RarityConfig.luau`, `RollMath.luau`, `RollRules.luau` |
| Server rolls | `src/server/Services/RollService.luau` |
| Hunt capture batch | `src/server/Services/BindService.luau` |
| AFK scan | `src/server/Services/ScanService.luau` |
| Bonus / luck formulas | `src/shared/Formulas.luau` |
| Multipliers | `src/server/Services/MultiplierService.luau` |
| Skills | `src/shared/SkillConfig.luau` |
| Economy | `src/shared/Economy.luau`, `RelicIncome.luau`, `Config.Economy` |
| Mutations | `src/shared/MutationConfig.luau` |
| Roster | `src/shared/RelicConfig.luau` |
| Bounties | `src/shared/Config.luau` (`Config.Bounties`), `Bounties.luau`, `BountyService.luau` |
| Offerings | `Config.Offerings`, `Offerings.luau`, `WildFindsService.luau` |
| Progression sim | `tests/economyReport.luau`, `tests/lib/economySim.luau` |

---

## 13. Suggested next step for the collaboration

Astra should read this document and propose **2–3 concrete redesign packages** (each with: what changes, what stays, expected early-game tier timing, impact on AFK vs hunt, impact on mutations/themes). Composer will map each package onto the actual config/service touch points and estimate risk. Then pick one package to implement and re-run `lune run tests/economyReport` against new targets that include **tier timing**, not only CE and luck multipliers.
