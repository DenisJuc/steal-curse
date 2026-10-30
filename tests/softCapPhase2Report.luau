-- Phase 2 SoftCap validation report (computed + Monte Carlo). Does not retune numbers.
-- Run: lune run tests/softCapPhase2Report

local fs = require("@lune/fs")
local SoftCapRarity = require("./lib/softCapRarity")
local RelicConfig = require("../src/shared/RelicConfig")
local Formulas = require("../src/shared/Formulas")
local RollMath = require("../src/shared/RollMath")
local rules = require("./lib/rules")

local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }
local LUCKS = { 1, 5, 20, 60, 150, 500, 2000, 10000, 100000 }

local lines = {}
local function w(s: string?)
	table.insert(lines, s or "")
end

local function fmt(n: number, d: number?): string
	return string.format(`%.{d or 2}f`, n)
end

local function pctRow(b: { [string]: number }): string
	local parts = {}
	for _, t in TIER_ORDER do
		table.insert(parts, fmt(b[t] or 0, 2))
	end
	return table.concat(parts, " | ")
end

w("# SoftCap Phase 2 — Studio Trial Report")
w()
w("**Trial ID:** `SoftCap_Rev4` (Studio auto). **Control:** `SoftAC_E20k` (Ladder sampler, same costs/hunt).")
w("**Live/production:** unchanged Ladder + live denoms (no SoftCap).")
w("**Labels:** `computed` = closed-form SoftCap/ladder; `sampled` = Monte Carlo; **no silent retunes**.")
w()
w("## Startup logs (expected in Studio)")
w()
w("```")
w("[BalanceTrials] ACTIVE=SoftCap_Rev4")
w("[BalanceTrials] RaritySampler=SoftCap")
w("[BalanceTrials] CollectionPrototype=true | ... SoftCap Phase 2: Index odds = 1/p_i; SoftAC_E20k available as Ladder control")
w("[Main] Balance=SoftCap_Rev4 Collection=true RaritySampler=SoftCap")
w("[Main] Hunt cap: MaxBonusRolls=6 → maxTotalRolls=7 per spirit capture")
w("```")
w()
w("Switch control in Studio: set `BalanceTrials.StudioTrialId = \"SoftAC_E20k\"` (or `Active`) and restart.")
w()

w("## 1. SoftCap band % vs Luck (computed)")
w()
w("| Luck | Common | Uncommon | Rare | Epic | Legendary | Mythic | Celestial | Cosmic |")
w("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
for _, L in LUCKS do
	w(`| {L} | {pctRow(SoftCapRarity.softCapBandPercents(L))} |`)
end
-- Post-rebirth samples: Soft A LuckGrowth 1.25, CoreLuck divisor 12
local postR1 = Formulas.coreLuck(20, 12) * (1.25 ^ 1)
local postR3 = Formulas.coreLuck(40, 12) * (1.25 ^ 3)
w(`| postR1~{fmt(postR1, 0)} | {pctRow(SoftCapRarity.softCapBandPercents(postR1))} |`)
w(`| postR3~{fmt(postR3, 0)} | {pctRow(SoftCapRarity.softCapBandPercents(postR3))} |`)
w()

w("## 2. Soft A+C ladder control (Epic 20k / Leg 500k) — computed")
w()
w("| Luck | Common | Uncommon | Rare | Epic | Legendary | Mythic | Celestial | Cosmic |")
w("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
for _, L in { 1, 20, 60, 150, 500, 2000 } do
	w(`| {L} | {pctRow(SoftCapRarity.ladderBandPercents(L, 20000, 500000))} |`)
end
w()

local sc1 = SoftCapRarity.softCapBandPercents(1)
local lad1 = SoftCapRarity.ladderBandPercents(1, 20000, 500000)
local epicRatio = (sc1.Epic or 0) / math.max(1e-12, lad1.Epic or 0)
w("## 3. FLAG — Early Epic generosity")
w()
w(`At Luck=1, SoftCap Epic band = **{fmt(sc1.Epic, 4)}%** vs Soft A+C **{fmt(lad1.Epic, 6)}%** → **{fmt(epicRatio, 1)}×**.`)
w("Rev 4 called this ~15×. **Do not silently retune** — watch Studio playtests for purple-too-early feel.")
w()

local sc150 = SoftCapRarity.softCapBandPercents(150)
local lad150 = SoftCapRarity.ladderBandPercents(150, 20000, 500000)
w("## 4. SoftCap vs Soft A+C at Luck 150 (the Rare-plateau checkpoint)")
w()
w("| Metric | Soft A+C | SoftCap |")
w("| --- | ---: | ---: |")
w(`| Common % | {fmt(lad150.Common)} | {fmt(sc150.Common)} |`)
w(`| Uncommon % | {fmt(lad150.Uncommon)} | {fmt(sc150.Uncommon)} |`)
w(`| Rare % | {fmt(lad150.Rare)} | {fmt(sc150.Rare)} |`)
w(`| Epic % | {fmt(lad150.Epic, 3)} | {fmt(sc150.Epic, 3)} |`)
w(`| C+U % | {fmt(lad150.Common + lad150.Uncommon)} | {fmt(sc150.Common + sc150.Uncommon)} |`)
w()
w(`SoftCap L1(60→150) = **{fmt(SoftCapRarity.l1Distance(60, 150), 3)}** (Luck still reshapes mix).`)
w()

w("## 5. Sample Index 1-in-N at L=150 (SoftCap computed — not R/L)")
w()
w("| Relic | Tier | 1/p_i |")
w("| --- | --- | ---: |")
local seenTier = {}
for _, relic in RelicConfig.Relics do
	if not seenTier[relic.Tier] then
		seenTier[relic.Tier] = true
		local n = SoftCapRarity.effectiveOneIn(150, relic.Id)
		w(`| {relic.Name} | {relic.Tier} | {fmt(n, 1)} |`)
	end
end
w()

w("## 6. Experience Monte Carlo — ~35 min playtest-shaped (sampled)")
w()
w("Assumptions (mirrors Soft A+C playtest shape, not B+/Forms):")
w("- ~4s scan → ~525 rolls / 35 min AFK-heavy")
w("- Luck path approximates Soft A+C climb: L≈5 → 20 → 60 → 150 over the session")
w("- Mutation Resonance rank 0 until mid, then 1 (10%) after ~15 min")
w("- No hunt in base run; separate hunt column at L×5")
w()

local function runSession(seed: number, useSoftCap: boolean): any
	local state = seed
	local function rng()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	local byTier = {}
	local byRelic = {}
	local unique = {}
	local uniqueCount = 0
	local mutCount = 0
	local epicPlus = 0
	local uniqueTimeline = {} -- minute -> unique count
	local lastValuableAt = 0 -- roll index of last Rare+ unique or Epic+
	local gaps = {}
	local rolls = 525
	local essence = 0 -- crude: +1 per dupe Common/Uncommon (Collection sink proxy)
	for i = 1, rolls do
		local t = i / rolls
		local L = if t < 0.2 then 5 elseif t < 0.45 then 20 elseif t < 0.7 then 60 else 150
		local mutRank = if t < 0.45 then 0 else 1
		local relicId, tierId
		if useSoftCap then
			relicId, tierId = SoftCapRarity.roll(L, rng)
		else
			local softTiers = {}
			for _, tier in rules.Tiers do
				local denom = tier.Denominator
				if tier.Id == "Epic" then
					denom = 20000
				elseif tier.Id == "Legendary" then
					denom = 500000
				end
				table.insert(softTiers, { Id = tier.Id, Denominator = denom })
			end
			local softRules = table.clone(rules)
			softRules.Tiers = softTiers
			local ctx = RollMath.contextFor(softRules, { FullLuck = L, Sampler = "Ladder", MutationRank = mutRank })
			local relic, _ = RollMath.roll(ctx, rng)
			relicId, tierId = relic.Id, relic.Tier
		end
		local mut = SoftCapRarity.rollMutation(mutRank, rng)
		byTier[tierId] = (byTier[tierId] or 0) + 1
		byRelic[relicId] = (byRelic[relicId] or 0) + 1
		local first = not unique[relicId]
		if first then
			unique[relicId] = true
			uniqueCount += 1
		end
		if mut then
			mutCount += 1
		end
		local tierI = 0
		for ti, tname in TIER_ORDER do
			if tname == tierId then
				tierI = ti
			end
		end
		if tierI >= 4 then
			epicPlus += 1
		end
		local valuable = first and tierI >= 3 -- new Rare+ Index entry
		if valuable or (tierI >= 4) then
			if lastValuableAt > 0 then
				table.insert(gaps, i - lastValuableAt)
			end
			lastValuableAt = i
		end
		if not first and tierI <= 2 then
			essence += 1
		end
		local minute = math.floor((i / rolls) * 35)
		uniqueTimeline[minute] = uniqueCount
	end
	return {
		ByTier = byTier,
		Unique = uniqueCount,
		Dupes = rolls - uniqueCount,
		Mutations = mutCount,
		EpicPlus = epicPlus,
		EpicPer1k = epicPlus * (1000 / rolls),
		EssenceProxy = essence,
		AvgGapRolls = if #gaps > 0 then (function()
			local s = 0
			for _, g in gaps do
				s += g
			end
			return s / #gaps
		end)() else rolls,
		UniqueAt15 = uniqueTimeline[15] or uniqueCount,
		UniqueAt35 = uniqueCount,
		Rolls = rolls,
	}
end

local softSeeds = {}
local softACSeeds = {}
for seed = 1, 8 do
	table.insert(softSeeds, runSession(1000 + seed * 17, true))
	table.insert(softACSeeds, runSession(1000 + seed * 17, false))
end

local function medianField(rows: { any }, key: string): number
	local vals = {}
	for _, r in rows do
		table.insert(vals, r[key])
	end
	table.sort(vals)
	return vals[math.ceil(#vals / 2)]
end

local function avgTier(rows: { any }, tier: string): number
	local s = 0
	for _, r in rows do
		s += (r.ByTier[tier] or 0)
	end
	return s / #rows
end

w("### SoftCap (8 seeds, median / mean tiers)")
w()
w(`| Unique@15m | Unique@35m | Dupes | Mutations | Epic+ | Epic/1k | Essence proxy | Avg rolls between valuable |`)
w(`| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |`)
w(
	`| {fmt(medianField(softSeeds, "UniqueAt15"), 0)} | {fmt(medianField(softSeeds, "UniqueAt35"), 0)} | {fmt(medianField(softSeeds, "Dupes"), 0)} | {fmt(medianField(softSeeds, "Mutations"), 0)} | {fmt(medianField(softSeeds, "EpicPlus"), 0)} | {fmt(medianField(softSeeds, "EpicPer1k"), 2)} | {fmt(medianField(softSeeds, "EssenceProxy"), 0)} | {fmt(medianField(softSeeds, "AvgGapRolls"), 1)} |`
)
w()
w("Mean rolls by rarity (SoftCap):")
for _, t in TIER_ORDER do
	local m = avgTier(softSeeds, t)
	if m > 0.05 then
		w(`- {t}: {fmt(m, 1)} ({fmt(100 * m / 525, 1)}%)`)
	end
end
w()
w("### Soft A+C control (same seeds)")
w()
w(
	`| Unique@15m | Unique@35m | Dupes | Mutations | Epic+ | Epic/1k | Essence proxy | Avg rolls between valuable |`
)
w(`| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |`)
w(
	`| {fmt(medianField(softACSeeds, "UniqueAt15"), 0)} | {fmt(medianField(softACSeeds, "UniqueAt35"), 0)} | {fmt(medianField(softACSeeds, "Dupes"), 0)} | {fmt(medianField(softACSeeds, "Mutations"), 0)} | {fmt(medianField(softACSeeds, "EpicPlus"), 0)} | {fmt(medianField(softACSeeds, "EpicPer1k"), 2)} | {fmt(medianField(softACSeeds, "EssenceProxy"), 0)} | {fmt(medianField(softACSeeds, "AvgGapRolls"), 1)} |`
)
w()
w("Mean rolls by rarity (Soft A+C):")
for _, t in TIER_ORDER do
	local m = avgTier(softACSeeds, t)
	if m > 0.05 then
		w(`- {t}: {fmt(m, 1)} ({fmt(100 * m / 525, 1)}%)`)
	end
end
w()

w("### Player-experience verdict (colors vs discovery)")
w()
w("- Soft A+C still collapses into **Rare-dominated** mid-session rolls → few exciting *color* changes, Index stalls on Rare pool.")
w("- SoftCap keeps **Common/Uncommon majority (~85% at L150)** → more dupe volume; Collection/Essence is the intended sink.")
w("- SoftCap restores **visible mix** (Rare ~14%, Epic ~1% at L150) so individual Epic/Legendary rolls remain scarce events.")
w("- Valuable-discovery gaps shrink vs SoftAC Rare wall (new Rare+ Index entries keep arriving), but **low-tier dupe fatigue** is the new risk.")
w()

w("## 7. CE / Rebirth affordability (unchanged economy)")
w()
w("- Pedestal RelicIncome, upgrade prices, Rebirth cost/growth, Soft A+C CoreLuck soft costs: **not changed** in Phase 2.")
w("- SoftCap changes *what* lands on pedestals (more C/U, fewer Rares mid-game) → **expected CE/s slightly lower** than SoftAC Rare flood until Collection fusion/income mults compensate.")
w("- Rebirth affordability timing should be re-measured in the next human Studio session; do **not** retune Rebirth around SoftCap until that playtest.")
w()

w("## 8. Predicted negative effects")
w()
w("1. **Dupe fatigue** from ~85% C/U at mid Luck — Collection HUD must stay usable.")
w("2. **Early Epic ~15× SoftAC** at L=1 — may feel purple-heavy in first minutes.")
w("3. **CE income path** may slow vs SoftAC Rare pedestal spam until fusion/attune kicks in.")
w("4. Index shows many Common 1-in-N that look \"easy\" — clarify tier name vs effective odds in UI (done: `Odds.indexLine`).")
w()

w("## 9. Human Studio playtest (10–15 min)")
w()
w("1. Open place in Roblox Studio (Play). Confirm Output: `ACTIVE=SoftCap_Rev4`, `RaritySampler=SoftCap`.")
w("2. Analytics auto-starts. Play normally: scan + a few hunts; open Codex — odds should update after Core Luck buys (`Yours` 1-in-N + base).")
w("3. Watch for: Rare plateau gone? Exciting Epic? Too many C/U dupes? Early purple?")
w("4. Optional control: set `StudioTrialId=\"SoftAC_E20k\"`, replay 10 min, compare feel.")
w("5. Export: Analytics panel → Export (or stop session). Receiver: `python tools/playtest_export_server.py` on port 19283; files land under `docs/playtest/`.")
w()

w("## 10. Analytics instrumentation (Phase 2)")
w()
w("- 5-minute `RarityWindow` events: ByTier, UniqueNew, Dupes, BySource, Mutations, EpicPlus")
w("- Purchases record `Luck`, `EffectiveLuck`, `RaritySampler`")
w("- Exact Epic+ discoveries logged with Source (Scan/Capture/Bonus/…)")
w("- Existing purchase CSV + session JSON + summary MD preserved; Meta includes RaritySampler + RarityWindows")
w()

w("---")
w("*Generated by `lune run tests/softCapPhase2Report`. Phase 2 only — no Attunement25 / B+ / Forms.*")

local body = table.concat(lines, "\n") .. "\n"
fs.writeFile("docs/SOFTCAP_PHASE2_REPORT.md", body)
print("Wrote docs/SOFTCAP_PHASE2_REPORT.md")
print(`Early Epic SoftCap/SoftAC @L1 = {fmt(epicRatio, 2)}x`)
print(`SoftCap @L150 Rare={fmt(sc150.Rare)}% Epic={fmt(sc150.Epic, 3)}% C+U={fmt(sc150.Common + sc150.Uncommon)}%`)
