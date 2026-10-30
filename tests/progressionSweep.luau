-- Phase 0 parameter sweep. Run from repo root:
--   lune run tests/progressionSweep
-- Optional: lune run tests/progressionSweep 50   (seed count; default 100, use 500 for final)
-- Writes docs/PROGRESSION_SWEEP.md. Does not change live Config defaults.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Format = require("../src/shared/Format")
local Config = require("../src/shared/Config")
local ProgressionSweep = require("./lib/progressionSweep")

local SEED_COUNT = tonumber(process.args[1]) or 100
local HOURS = 2
local BEHAVIOURS = { "passive", "upgrader", "hunter" } :: { ProgressionSweep.Behaviour }

local function huntBaseline()
	return {
		BonusFloor = Config.Hunt.BonusFloor,
		BonusFactor = Config.Hunt.BonusFactor,
		ReferenceScanSeconds = nil,
		HuntLuckFactor = 1,
		MaxBonusRolls = nil,
		CaptureCycleSeconds = 12,
	}
end

local function huntReform()
	return {
		BonusFloor = 2,
		BonusFactor = 0.08,
		ReferenceScanSeconds = 4,
		HuntLuckFactor = 5,
		MaxBonusRolls = 6,
		CaptureCycleSeconds = 12,
	}
end

local function cand(
	id: string,
	label: string,
	epic: number,
	leg: number,
	luckDiv: number,
	costGrowth: number,
	hunt: any
): ProgressionSweep.Candidate
	return {
		Id = id,
		Label = label,
		EpicDenom = epic,
		LegendaryDenom = leg,
		LuckDivisor = luckDiv,
		LuckCostGrowth = costGrowth,
		LuckCostBase = 100,
		Hunt = hunt,
	}
end

-- Candidates: baseline + focused grid (Epic dens × luck curve × moderate cost). Hunt reform on a subset.
local candidates: { ProgressionSweep.Candidate } = {
	ProgressionSweep.baselineCandidate(),
	cand("E5k_L10_C16", "Epic 5k, luck/10, cost 1.6, hunt baseline", 5000, 125000, 10, 1.6, huntBaseline()),
	cand("E10k_L10_C16", "Epic 10k, luck/10, cost 1.6, hunt baseline", 10000, 250000, 10, 1.6, huntBaseline()),
	cand("E20k_L10_C16", "Epic 20k, luck/10, cost 1.6, hunt baseline", 20000, 500000, 10, 1.6, huntBaseline()),
	cand("E40k_L10_C16", "Epic 40k, luck/10, cost 1.6, hunt baseline", 40000, 1000000, 10, 1.6, huntBaseline()),
	cand("E10k_L12_C16", "Epic 10k, luck/12, cost 1.6, hunt baseline", 10000, 250000, 12, 1.6, huntBaseline()),
	cand("E10k_L15_C16", "Epic 10k, luck/15, cost 1.6, hunt baseline", 10000, 250000, 15, 1.6, huntBaseline()),
	cand("E10k_L10_C17", "Epic 10k, luck/10, cost 1.7, hunt baseline", 10000, 250000, 10, 1.7, huntBaseline()),
	cand("E10k_L12_C17", "Epic 10k, luck/12, cost 1.7, hunt baseline", 10000, 250000, 12, 1.7, huntBaseline()),
	cand("E20k_L12_C17", "Epic 20k, luck/12, cost 1.7, hunt baseline", 20000, 500000, 12, 1.7, huntBaseline()),
	cand("E10k_L12_C165_HR", "Epic 10k, luck/12, cost 1.65, hunt reform 4+×5", 10000, 250000, 12, 1.65, huntReform()),
	cand("E20k_L12_C17_HR", "Epic 20k, luck/12, cost 1.7, hunt reform 4+×5", 20000, 500000, 12, 1.7, huntReform()),
	cand("E40k_L15_C175_HR", "Epic 40k, luck/15, cost 1.75, hunt reform 4+×5", 40000, 1000000, 15, 1.75, huntReform()),
}

local function fmtMin(seconds: number?): string
	if not seconds then
		return "—"
	end
	return string.format("%.1f", seconds / 60)
end

local function fmtNum(n: number?): string
	if n == nil then
		return "—"
	end
	return Format.number(n)
end

type Agg = {
	Candidate: ProgressionSweep.Candidate,
	Behaviour: ProgressionSweep.Behaviour,
	N: number,
	EpicP10: number?,
	EpicP50: number?,
	EpicP90: number?,
	EpicRate: number,
	LegP10: number?,
	LegP50: number?,
	LegP90: number?,
	LegRate: number,
	RebirthP10: number?,
	RebirthP50: number?,
	RebirthP90: number?,
	RebirthRate: number,
	Sat15: { EpicTotal: number, EpicUnique: number, LegTotal: number, LegUnique: number, Unique: number, Luck: number, Income: number },
	Sat30: typeof(nil) | any,
	Sat60: any,
	Sat120: any,
	MeanGapMin: number?,
	MeanRoutine: number,
	MeanSignificant: number,
	MeanLifetimeCE: number,
	MeanFinalLuck: number,
	MeanFinalIncome: number,
}

local function satAt(results: { ProgressionSweep.RunResult }, minute: number)
	local epicT, epicU, legT, legU, unique, luck, income = 0, 0, 0, 0, 0, 0, 0
	local n = 0
	for _, r in results do
		for _, s in r.Saturations do
			if s.Minute == minute then
				n += 1
				epicT += s.EpicTotal
				epicU += s.EpicUnique
				legT += s.LegendaryTotal
				legU += s.LegendaryUnique
				unique += s.UniqueRelics
				luck += s.Luck
				income += s.IncomePerSec
			end
		end
	end
	if n == 0 then
		return { EpicTotal = 0, EpicUnique = 0, LegTotal = 0, LegUnique = 0, Unique = 0, Luck = 0, Income = 0 }
	end
	return {
		EpicTotal = epicT / n,
		EpicUnique = epicU / n,
		LegTotal = legT / n,
		LegUnique = legU / n,
		Unique = unique / n,
		Luck = luck / n,
		Income = income / n,
	}
end

-- Population percentile: time when p fraction of ALL seeds have achieved the event.
-- If fewer than p of seeds ever succeed in the window, returns nil.
local function popPct(sortedTimes: { number }, n: number, p: number): number?
	local need = math.ceil(n * p)
	if #sortedTimes < need then
		return nil
	end
	return sortedTimes[need]
end

local function aggregate(candidate: ProgressionSweep.Candidate, behaviour: ProgressionSweep.Behaviour, results: { ProgressionSweep.RunResult }): Agg
	local epicT = ProgressionSweep.times(results, "FirstEpicAt")
	local legT = ProgressionSweep.times(results, "FirstLegendaryAt")
	local rebT = ProgressionSweep.times(results, "FirstRebirthAt")
	local gaps = {}
	local routine, significant, lifetime, finalLuck, finalIncome = 0, 0, 0, 0, 0
	for _, r in results do
		for _, g in r.SignificantGaps do
			table.insert(gaps, g)
		end
		routine += r.RoutinePurchaseCount
		significant += r.SignificantEventCount
		lifetime += r.LifetimeCE
		finalLuck += r.FinalLuck
		finalIncome += r.FinalIncome
	end
	table.sort(gaps)
	local n = #results
	return {
		Candidate = candidate,
		Behaviour = behaviour,
		N = n,
		EpicP10 = popPct(epicT, n, 0.10),
		EpicP50 = popPct(epicT, n, 0.50),
		EpicP90 = popPct(epicT, n, 0.90),
		EpicRate = #epicT / n,
		LegP10 = popPct(legT, n, 0.10),
		LegP50 = popPct(legT, n, 0.50),
		LegP90 = popPct(legT, n, 0.90),
		LegRate = #legT / n,
		RebirthP10 = popPct(rebT, n, 0.10),
		RebirthP50 = popPct(rebT, n, 0.50),
		RebirthP90 = popPct(rebT, n, 0.90),
		RebirthRate = #rebT / n,
		Sat15 = satAt(results, 15),
		Sat30 = satAt(results, 30),
		Sat60 = satAt(results, 60),
		Sat120 = satAt(results, 120),
		MeanGapMin = if #gaps > 0 then (ProgressionSweep.mean(gaps) :: number) / 60 else nil,
		MeanRoutine = routine / n,
		MeanSignificant = significant / n,
		MeanLifetimeCE = lifetime / n,
		MeanFinalLuck = finalLuck / n,
		MeanFinalIncome = finalIncome / n,
	}
end

print(`Phase 0 sweep: {SEED_COUNT} seeds × {#candidates} candidates × {#BEHAVIOURS} behaviours × {HOURS}h`)
assert(ProgressionSweep.incomesFrozen(), "frozen incomes must match live RelicIncome")

local allAggs: { Agg } = {}
local byKey: { [string]: Agg } = {}

for ci, candidate in candidates do
	for _, behaviour in BEHAVIOURS do
		local results = {}
		for seed = 1, SEED_COUNT do
			table.insert(
				results,
				ProgressionSweep.run({
					Seed = seed,
					Hours = HOURS,
					Behaviour = behaviour,
					Candidate = candidate,
				})
			)
		end
		local agg = aggregate(candidate, behaviour, results)
		table.insert(allAggs, agg)
		byKey[`{candidate.Id}|{behaviour}`] = agg
		print(
			string.format(
				"  [%d/%d] %s / %s  epicP50=%s (%.0f%%)  legP50=%s  rebP50=%s  epic@15=%.1f",
				ci,
				#candidates,
				candidate.Id,
				behaviour,
				fmtMin(agg.EpicP50),
				agg.EpicRate * 100,
				fmtMin(agg.LegP50),
				fmtMin(agg.RebirthP50),
				agg.Sat15.EpicTotal
			)
		)
	end
end

-- Score upgrader behaviour against dual pacing targets (fun-oriented, not max delay).
local function scoreUpgrader(a: Agg): number
	-- Prefer: epic not too early (punish <20m median), not too late for upgrader (>90m),
	-- low epic saturation at 15m, legendary later, rebirth feasible, gaps not huge.
	local score = 0
	local epicMed = a.EpicP50
	if epicMed then
		local m = epicMed / 60
		if m < 15 then
			score -= (15 - m) * 8
		elseif m <= 40 then
			score += 40 - math.abs(m - 30)
		elseif m <= 75 then
			score += 25 - (m - 40) * 0.5
		else
			score -= (m - 75) * 0.8
		end
	else
		score -= 30
	end
	-- Punish epic flood at 15 min
	score -= math.min(40, a.Sat15.EpicTotal * 3)
	score += math.min(10, a.Sat15.EpicUnique) -- some uniqueness ok
	-- Legendary: reward having some path by 120m without flooding at 30m
	score -= math.min(20, a.Sat30.LegTotal * 5)
	if a.LegP50 then
		local lm = a.LegP50 / 60
		if lm >= 60 and lm <= 180 then
			score += 15
		elseif lm < 45 then
			score -= 20
		end
	end
	-- Rebirth: reward happening sometime in 60-150 for upgrader
	if a.RebirthP50 then
		local rm = a.RebirthP50 / 60
		if rm >= 60 and rm <= 150 then
			score += 20
		elseif rm < 40 then
			score -= 10
		end
	else
		score -= 5
	end
	-- Meaningful events exist
	score += math.min(15, a.MeanSignificant)
	-- Extreme luck treadmill at 20-equivalent: use sat15 luck
	if a.Sat15.Luck > 80 then
		score -= 15
	elseif a.Sat15.Luck > 40 then
		score -= 5
	end
	return score
end

local upgraderAggs = {}
for _, a in allAggs do
	if a.Behaviour == "upgrader" and a.Candidate.Id ~= "baseline" then
		table.insert(upgraderAggs, a)
	end
end
table.sort(upgraderAggs, function(x, y)
	return scoreUpgrader(x) > scoreUpgrader(y)
end)

local top3 = {}
local seenIds = {}
for _, a in upgraderAggs do
	if not seenIds[a.Candidate.Id] then
		seenIds[a.Candidate.Id] = true
		table.insert(top3, a.Candidate)
		if #top3 >= 3 then
			break
		end
	end
end

local lines = {}
local function w(s: string)
	table.insert(lines, s)
end

w("# Progression Parameter Sweep (Phase 0)")
w("")
w("**Status:** Simulation only. Live economy defaults were **not** changed.")
w("")
w(`- Seeds per cell: **{SEED_COUNT}** (identical seeds 1..N across every candidate × behaviour)`)
w(`- Duration: **{HOURS} hours** simulated`)
w("- Income: **frozen per-relic baseline** from live `RelicIncome` at luck 1 (weights/individual CE preserved; denom changes do not rewrite income)")
w("- Luck stack in sim: Core Luck × Rebirth luck (no potions/Codex/Showcase — those would make rare finds *more* common)")
w("- Scan Speed: purchased by upgrader/hunter; affects AFK roll rate; hunt bonus uses live scan unless candidate sets `ReferenceScanSeconds`")
w("")
w("## Design targets (score against, not hard gates)")
w("")
w("| Milestone | Passive | Active hunter |")
w("|-----------|--------|---------------|")
w("| First Epic | 45–75 min | 20–40 min |")
w("| First Legendary | 2–4 h | 60–120 min |")
w("| First Rebirth | test 90–150 min | test 60–90 min |")
w("")
w("Optimization goal: **fun, meaningful progression, retention** — not maximizing time-to-Legendary.")
w("")
w("## Behaviours")
w("")
w("| Id | Meaning |")
w("|----|---------|")
w("| `passive` | Auto-scan only; **no** CE spending (luck stays ×1 aside from nothing) |")
w("| `upgrader` | Auto-scan + cheapest upgrades + rebirth ASAP when affordable (playtest-like) |")
w("| `hunter` | Upgrader + signal regen/captures (`CaptureCycleSeconds=12`) with candidate hunt tune |")
w("")
w("## Baseline (live) — reference")
w("")

local function writeAggTable(title: string, ids: { string })
	w(`### {title}`)
	w("")
	w("| Candidate | Beh | Epic P10/P50/P90 (min) | Epic% | Leg P50 | Leg% | Rebirth P50 | Epic tot @15 / @60 | Luck @15 | Gap min |")
	w("|-----------|-----|------------------------|-------|---------|------|-------------|--------------------|----------|---------|")
	for _, id in ids do
		for _, beh in BEHAVIOURS do
			local a = byKey[`{id}|{beh}`]
			if a then
				w(
					string.format(
						"| %s | %s | %s / %s / %s | %.0f%% | %s | %.0f%% | %s | %.1f / %.1f | %s | %s |",
						a.Candidate.Id,
						beh,
						fmtMin(a.EpicP10),
						fmtMin(a.EpicP50),
						fmtMin(a.EpicP90),
						a.EpicRate * 100,
						fmtMin(a.LegP50),
						a.LegRate * 100,
						fmtMin(a.RebirthP50),
						a.Sat15.EpicTotal,
						a.Sat60.EpicTotal,
						fmtNum(a.Sat15.Luck),
						if a.MeanGapMin then string.format("%.1f", a.MeanGapMin) else "—"
					)
				)
			end
		end
	end
	w("")
end

writeAggTable("All candidates", (function()
	local ids = {}
	for _, c in candidates do
		table.insert(ids, c.Id)
	end
	return ids
end)())

w("## Saturation detail (upgrader) — mean across seeds")
w("")
w("| Candidate | t | Epic tot/uniq | Leg tot/uniq | Unique relics | Luck | CE/s | Rebirths |")
w("|-----------|---|---------------|--------------|---------------|------|------|----------|")
for _, c in candidates do
	local a = byKey[`{c.Id}|upgrader`]
	if a then
		for _, sat in { a.Sat15, a.Sat30, a.Sat60, a.Sat120 } do
			-- recover minute from which sat — Sat15 etc don't store minute; hardcode order
		end
		local pairs_ = {
			{ 15, a.Sat15 },
			{ 30, a.Sat30 },
			{ 60, a.Sat60 },
			{ 120, a.Sat120 },
		}
		for _, pair in pairs_ do
			local t, s = pair[1], pair[2]
			w(
				string.format(
					"| %s | %d | %.1f / %.1f | %.2f / %.2f | %.1f | %s | %s | (see rate) |",
					c.Id,
					t,
					s.EpicTotal,
					s.EpicUnique,
					s.LegTotal,
					s.LegUnique,
					s.Unique,
					fmtNum(s.Luck),
					fmtNum(s.Income)
				)
			)
		end
	end
end
w("")

w("## Three strongest configurations (not auto-picked as winner)")
w("")
w("Scored primarily on **upgrader** behaviour (matches the playtest), with hunter/passive checked for active advantage and AFK floor. Scoring penalizes Epic floods at 15 minutes and rewards Epic medians in a mid band, later Legendaries, feasible Rebirth, and significant events.")
w("")

for i, c in top3 do
	local u = byKey[`{c.Id}|upgrader`]
	local p = byKey[`{c.Id}|passive`]
	local h = byKey[`{c.Id}|hunter`]
	local b = byKey[`baseline|upgrader`]
	w(`### #{i}: \'{c.Id}\' — {c.Label}`)
	w("")
	w("**Parameters**")
	w("")
	w(`- Epic+ denom: **{c.EpicDenom}** (baseline 500)`)
	w(`- Legendary+ denom: **{c.LegendaryDenom}** (baseline 25000)`)
	w(`- Core Luck: \`10^(rank/{c.LuckDivisor})\`, cost growth **{c.LuckCostGrowth}**`)
	w(
		`- Hunt: floor={c.Hunt.BonusFloor}, factor={c.Hunt.BonusFactor}, huntLuck=×{c.Hunt.HuntLuckFactor}, refScan={c.Hunt.ReferenceScanSeconds or "live"}, maxBonus={c.Hunt.MaxBonusRolls or "none"}`
	)
	w("")
	w("**Upgrader (playtest-like)**")
	w("")
	w(`| Metric | This | Baseline |`)
	w(`|--------|------|----------|`)
	w(`| Epic P50 (min) | {fmtMin(u.EpicP50)} | {fmtMin(b.EpicP50)} |`)
	w(`| Epic reach rate (2h) | {string.format("%.0f%%", u.EpicRate * 100)} | {string.format("%.0f%%", b.EpicRate * 100)} |`)
	w(`| Mean Epic total @15 / @60 | {string.format("%.1f / %.1f", u.Sat15.EpicTotal, u.Sat60.EpicTotal)} | {string.format("%.1f / %.1f", b.Sat15.EpicTotal, b.Sat60.EpicTotal)} |`)
	w(`| Legendary P50 (min) | {fmtMin(u.LegP50)} | {fmtMin(b.LegP50)} |`)
	w(`| Rebirth P50 (min) | {fmtMin(u.RebirthP50)} | {fmtMin(b.RebirthP50)} |`)
	w(`| Luck @15 | {fmtNum(u.Sat15.Luck)} | {fmtNum(b.Sat15.Luck)} |`)
	w(`| Mean significant events | {string.format("%.1f", u.MeanSignificant)} | {string.format("%.1f", b.MeanSignificant)} |`)
	w(`| Mean gap between significant (min) | {if u.MeanGapMin then string.format("%.1f", u.MeanGapMin) else "—"} | {if b.MeanGapMin then string.format("%.1f", b.MeanGapMin) else "—"} |`)
	w("")
	w("**Passive vs hunter**")
	w("")
	w(`| | Passive Epic P50 | Hunter Epic P50 | Hunter Epic@15 |`)
	w(`|-|----------------|-----------------|----------------|`)
	w(
		`| | {fmtMin(p.EpicP50)} | {fmtMin(h.EpicP50)} | {string.format("%.1f", h.Sat15.EpicTotal)} |`
	)
	w("")
	w("**Advantages**")
	w("")
	-- heuristic bullets
	if u.Sat15.EpicTotal < b.Sat15.EpicTotal * 0.5 then
		w("- Much less Epic saturation in the first 15 minutes than baseline (addresses the playtest flood).")
	end
	if u.EpicP50 and b.EpicP50 and u.EpicP50 > b.EpicP50 then
		w("- First Epic arrives later for the typical upgrader, restoring a sense of rarity.")
	end
	if h.EpicP50 and p.EpicP50 and h.EpicP50 < p.EpicP50 then
		w("- Active hunting still reaches Epic sooner than pure passive (active > AFK).")
	end
	if c.Hunt.ReferenceScanSeconds then
		w("- Hunt bonus decoupled from Scan Speed; Scan remains AFK QoL without multiplying capture loot.")
	end
	if c.LuckDivisor > 10 or c.LuckCostGrowth > 1.6 then
		w("- Slower Core Luck climb reduces early ×100 luck without the most extreme cost ramps.")
	end
	w("")
	w("**Disadvantages / risks**")
	w("")
	if u.RebirthRate < 0.5 then
		w("- Rebirth is uncommon within 2h for many seeds — may need Rebirth cost or income remap in Phase 1.")
	end
	if u.EpicRate < 0.7 then
		w("- Some seeds never see Epic in 2h as upgrader — watch P90 and passive column.")
	end
	if not c.Hunt.ReferenceScanSeconds then
		w("- Hunt still coupled to scan interval; active EV can explode once Scan is maxed.")
	end
	if u.MeanGapMin and u.MeanGapMin > 12 then
		w("- Long gaps between significant events — needs Phase 2 chase (Essence/fusion/collections) so waiting is not empty.")
	end
	w("- Collection systems (Essence, fusion, mutation unlocks) are **not** simulated; rarity timing alone understates midgame fun.")
	w("")
	w("**Fit vs targets**")
	w("")
	local function band(med: number?, lo: number, hi: number): string
		if not med then
			return "miss (never)"
		end
		local m = med / 60
		if m >= lo and m <= hi then
			return "in band"
		elseif m < lo then
			return "early"
		else
			return "late"
		end
	end
	w(`- Upgrader Epic vs active band 20–40: **{band(u.EpicP50, 20, 40)}** (P50={fmtMin(u.EpicP50)} min)`)
	w(`- Passive Epic vs passive band 45–75: **{band(p.EpicP50, 45, 75)}** (P50={fmtMin(p.EpicP50)} min)`)
	w(`- Upgrader Legendary vs 60–240: **{band(u.LegP50, 60, 240)}**`)
	w(`- Upgrader Rebirth vs 60–150: **{band(u.RebirthP50, 60, 150)}**`)
	w("")
end

w("## Recommendation (for humans — no auto-apply)")
w("")
w("1. **Do not ship baseline.** Upgrader Epic saturation and early P50 confirm the playtest.")
w("2. Among the three strongest above, prefer a candidate that:")
w("   - Cuts mean Epic@15 dramatically vs baseline")
w("   - Keeps hunter Epic earlier than passive")
w("   - Uses hunt reform (decoupled scan + capped batches) if hunter still floods")
w("   - Avoids CostGrowth ≥ 1.75 unless the milder options still flood")
w("3. **Phase 1** should apply the chosen row’s denom/luck/hunt knobs **and** keep frozen (or permanently decoupled) incomes.")
w("4. **Phase 2** (Essence/fusion/mutation unlocks) is still required so slower rarity is not empty waiting — this sweep only measures roll/CE pacing.")
w("")
w("## Extensibility note")
w("")
w("This harness accepts candidate tables only (denoms, luck curve, hunt tune). Future fusion/Essence/zone tables can plug into a later sim layer without rewriting RollMath.")
w("")
w("## How to reproduce")
w("")
w("```bash")
w("lune run tests/progressionSweep        # 100 seeds")
w("lune run tests/progressionSweep 500    # fuller percentiles")
w("```")
w("")

local out = table.concat(lines, "\n")
fs.writeFile("docs/PROGRESSION_SWEEP.md", out)
print("Wrote docs/PROGRESSION_SWEEP.md")
print("Top 3 (upgrader score):")
for i, c in top3 do
	print(`  #{i} {c.Id}  score={string.format("%.1f", scoreUpgrader(byKey[`{c.Id}|upgrader`]))}`)
end
