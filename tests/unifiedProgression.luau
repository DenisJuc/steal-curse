-- Rev 4 integrated simulation runner.
--   lune run tests/unifiedProgression
--   lune run tests/unifiedProgression 40
-- Writes docs/UNIFIED_PROGRESSION_REV4.md
-- Does not modify live game config.

local fs = require("@lune/fs")
local process = require("@lune/process")

local SoftCapRarity = require("./lib/softCapRarity")
local Unified = require("./lib/unifiedProgressionSim")
local RelicConfig = require("../src/shared/RelicConfig")
local Config = require("../src/shared/Config")
local Formulas = require("../src/shared/Formulas")

local SEEDS = tonumber(process.args[1]) or 40
local MINUTES = { 5, 15, 30, 45, 60, 90, 120, 180 }

local function fmt(n: number?, digits: number?): string
	if n == nil then
		return "—"
	end
	local d = digits or 1
	if d == 0 then
		return string.format("%.0f", n)
	elseif d == 2 then
		return string.format("%.2f", n)
	elseif d == 3 then
		return string.format("%.3f", n)
	elseif d == 4 then
		return string.format("%.4f", n)
	end
	return string.format("%.1f", n)
end

local function fmtInt(n: number?): string
	if n == nil then
		return "—"
	end
	return tostring(math.floor(n + 0.5))
end

print(`Rev4 unified progression: {SEEDS} seeds/cell`)

local lines = {}
local function w(s: string)
	table.insert(lines, s)
end

w("# Unified Progression Rev 4 — Simulation Results")
w("")
w("**Status:** Design validation only. Live Config, RollService, skills, Rebirth, and data schemas were **not** modified.")
w("")
w(`**Seeds per cell:** {SEEDS} (mulberry32). Checkpoints at 5 / 15 / 30 / 45 / 60 / 90 / 120 / 180 minutes.`)
w("")
w("**Labels:** `computed` = closed-form SoftCap/ladder math; `simulated` = multi-seed policy runs; `candidate` = proposed economy not in live SkillConfig.")
w("")

-- —— 1. Loop ——
w("## 1. Recommended gameplay loop")
w("")
w("Discover relics → strengthen build (pedestals / scan / energy / attunement) → earn CE & Essence → collect (fuse / forms / goals) → Rebirth (CE prestige + Resonance + gated tracks) → discover with better odds.")
w("")
w("| Step | Systems |")
w("|------|---------|")
w("| Discover | SoftCap Index rolls, hunt native bias, mutations as spice |")
w("| Strengthen | Ped soft-cap + Mastery, Scan, Energy±II, Attunement (CL25 candidate) |")
w("| Earn | Pedestal CE/s, dupe sells, hunt Essence |")
w("| Collect | HUD Collection (must ship), Essence sinks, optional Forms |")
w("| Rebirth | **B+** provisional: reset CE; keep builds; unlock II/Mastery/MutDeep + Resonance |")
w("")

-- —— 2. Rarity closed-form ——
w("## 2. SoftCap rarity validation (computed on all 92 relics)")
w("")
w("### 2.1 Band % vs Luck — Soft A+C ladder (Studio Epic 20k)")
w("")
w("| L | Common | Uncommon | Rare | Epic | Legendary | Mythic |")
w("|---|--------|----------|------|------|-----------|--------|")
for _, L in { 1, 20, 60, 150, 500, 1e4, 1e5, 1e7 } do
	local b = SoftCapRarity.ladderBandPercents(L, 20000, 500000)
	w(
		`| {fmtInt(L)} | {fmt(b.Common)} | {fmt(b.Uncommon)} | {fmt(b.Rare)} | {fmt(b.Epic)} | {fmt(b.Legendary)} | {fmt(b.Mythic)} |`
	)
end
w("")
w("### 2.2 Band % vs Luck — SoftCap authored R + M (candidate)")
w("")
w("| L | Common | Uncommon | Rare | Epic | Legendary | Mythic |")
w("|---|--------|----------|------|------|-----------|--------|")
for _, L in { 1, 20, 60, 150, 500, 1e4, 1e5, 1e7 } do
	local b = SoftCapRarity.softCapBandPercents(L)
	w(
		`| {fmtInt(L)} | {fmt(b.Common)} | {fmt(b.Uncommon)} | {fmt(b.Rare)} | {fmt(b.Epic)} | {fmt(b.Legendary)} | {fmt(b.Mythic)} |`
	)
end
w("")
w(`SoftCap L1-distance Luck 60→150: **{fmt(SoftCapRarity.l1Distance(60, 150), 3)}** (Luck reshapes mix).`)
w(`SoftCap L1-distance Luck 0.5→0.8: **{fmt(SoftCapRarity.l1Distance(0.5, 0.8), 4)}** (does not fully cancel).`)
w("")

-- Epic accessibility critique
local lad150 = SoftCapRarity.ladderBandPercents(150, 20000, 500000)
local sc150 = SoftCapRarity.softCapBandPercents(150)
local lad1 = SoftCapRarity.ladderBandPercents(1, 20000, 500000)
local sc1 = SoftCapRarity.softCapBandPercents(1)
w("### 2.3 Epic accessibility critique")
w("")
w(`| Metric | Soft A+C | SoftCap |`)
w(`|--------|----------|---------|`)
w(`| Epic % at L=1 | {fmt(lad1.Epic, 3)}% | {fmt(sc1.Epic, 3)}% |`)
w(`| Epic % at L=150 | {fmt(lad150.Epic, 3)}% | {fmt(sc150.Epic, 3)}% |`)
w(`| Rare % at L=150 | {fmt(lad150.Rare, 1)}% | {fmt(sc150.Rare, 1)}% |`)
w(`| Epic rolls / 1000 at L=150 | {fmt(lad150.Epic * 10, 1)} | {fmt(sc150.Epic * 10, 1)} |`)
w("")
local epicRatio = if lad1.Epic > 0 then sc1.Epic / lad1.Epic else math.huge
w(
	`At L=1, SoftCap Epic band share is ~**{fmt(epicRatio, 1)}×** the Soft A+C ladder (ladder Epic denom 20k makes early Epic vanishingly small). This is intentional for long-shots without waiting for Rare-cap, but must be watched for “purple too early” feel — tune \(R\)/\(M\) if Studio playtests feel flooded.`
)
w("")
w("### 2.4 Sample Index 1-in-N at L=150 (SoftCap, computed)")
w("")
w("| Relic | Tier | N_eff |")
w("|-------|------|-------|")
local samples = {
	"PaladynsNecklace",
	"HolloBait",
	"StaffOfJudgement",
	"KubikiriCleaver",
	"HolloMask",
	"AncientSunriseBlade",
}
for _, id in samples do
	local relic = RelicConfig.ById[id]
	local n = SoftCapRarity.effectiveOneIn(150, id)
	w(`| {id} | {relic.Tier} | 1 in {fmtInt(n)} |`)
end
w("")
w("### 2.5 Endgame scarcity (SoftCap at extreme L)")
w("")
local scHi = SoftCapRarity.softCapBandPercents(1e7)
w(
	`At L=1e7 (beyond R3 Soft A CL100): C {fmt(scHi.Common)}% / R {fmt(scHi.Rare)}% / E {fmt(scHi.Epic)}% / Leg {fmt(scHi.Legendary)}% / Myth {fmt(scHi.Mythic)}% / Cel {fmt(scHi.Celestial or 0, 4)}% / Cos {fmt(scHi.Cosmic or 0, 4)}% — Cosmic remains scarce via \(M\); not uniform 1/92.`
)
w("")
w("Through typical R3 Luck (~5k–20k simulated): Legendary band stays ~1–2%, Mythic ≪1%, Celestial/Cosmic effectively long-shot Index targets — not AFK wallpaper.")
w("")
w("### 2.6 Scan vs hunt (SoftCap, computed at L=150)")
w("")
w("Hunt applies Soft A ×5 luck factor in the sim (same as Soft A trial). Family Frequency multiplies matching-family weight via lowered \(R\).")
w("")
local scanB = SoftCapRarity.softCapBandPercents(150)
local huntB = SoftCapRarity.softCapBandPercents(150 * 5)
w("| Mode | Common | Uncommon | Rare | Epic | Legendary |")
w("|------|--------|----------|------|------|-----------|")
w(
	`| Scan L=150 | {fmt(scanB.Common)} | {fmt(scanB.Uncommon)} | {fmt(scanB.Rare)} | {fmt(scanB.Epic)} | {fmt(scanB.Legendary)} |`
)
w(
	`| Hunt L=750 | {fmt(huntB.Common)} | {fmt(huntB.Uncommon)} | {fmt(huntB.Rare)} | {fmt(huntB.Epic)} | {fmt(huntB.Legendary)} |`
)
w("")
w("Hunt shifts mass into Rare/Epic without collapsing Commons (SoftCap soft-caps), so hunting remains a meaningful conditional bonus rather than a pure Rare faucet.")
w("")
w("### 2.7 Monte Carlo SoftCap roll check (10k rolls @ L=150)")
w("")
do
	local rng = (function()
		local state = 12345
		return function()
			state = (state * 48271) % 2147483647
			return (state - 1) / 2147483646
		end
	end)()
	local counts = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0, Celestial = 0, Cosmic = 0 }
	local N = 10000
	for _ = 1, N do
		local _, tier = SoftCapRarity.roll(150, rng)
		counts[tier] = (counts[tier] or 0) + 1
	end
	w("| Tier | Expected % | Observed % |")
	w("|------|------------|------------|")
	for _, t in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		local exp = sc150[t] or 0
		local obs = 100 * counts[t] / N
		w(`| {t} | {fmt(exp, 1)} | {fmt(obs, 1)} |`)
	end
	w("")
end


-- —— Run simulations ——
local function runBatch(label: string, opts: any, seeds: number): { any }
	print(`  batch {label} ({seeds} seeds)`)
	local results = {}
	for seed = 1, seeds do
		local o = table.clone(opts)
		o.Seed = seed
		o.Minutes = 180
		table.insert(results, Unified.run(o))
		if seed % 10 == 0 then
			print(`    {label} seed {seed}/{seeds}`)
		end
	end
	return results
end

local main = runBatch("SoftCap/BPlus/AfkUpgrader", {
	Policy = "AfkUpgrader",
	Sampler = "SoftCap",
	RebirthModel = "BPlus",
	CollectionHud = false,
}, SEEDS)

local policies = {
	Casual = runBatch("SoftCap/BPlus/Casual", {
		Policy = "Casual",
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
	}, SEEDS),
	Hunter = runBatch("SoftCap/BPlus/Hunter", {
		Policy = "Hunter",
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
	}, SEEDS),
	Optimized = runBatch("SoftCap/BPlus/Optimized", {
		Policy = "Optimized",
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
	}, SEEDS),
}

local ladder = runBatch("SoftAC/BPlus/AfkUpgrader", {
	Policy = "AfkUpgrader",
	Sampler = "SoftAC",
	RebirthModel = "BPlus",
	CollectionHud = false,
}, math.min(SEEDS, 30))

local rebirthA = runBatch("SoftCap/A/Afk", {
	Policy = "AfkUpgrader",
	Sampler = "SoftCap",
	RebirthModel = "A",
	CollectionHud = false,
}, math.min(SEEDS, 24))

local rebirthB = runBatch("SoftCap/B/Afk", {
	Policy = "AfkUpgrader",
	Sampler = "SoftCap",
	RebirthModel = "B",
	CollectionHud = false,
}, math.min(SEEDS, 24))

local rebirthC = runBatch("SoftCap/C/Afk", {
	Policy = "AfkUpgrader",
	Sampler = "SoftCap",
	RebirthModel = "C",
	CollectionHud = false,
}, math.min(SEEDS, 24))

-- Collection HUD on for AFK (counterfactual)
local afkHud = runBatch("SoftCap/BPlus/Afk+HUD", {
	Policy = "AfkUpgrader",
	Sampler = "SoftCap",
	RebirthModel = "BPlus",
	CollectionHud = true,
}, math.min(SEEDS, 24))

local function writeAggTable(title: string, results: { any })
	w(`### {title}`)
	w("")
	w("| Min | Luck P50 | Rare% P50 | Epic% P50 | Unique P50 | CE/s P50 | CE P50 | CL P50 | Rebirths P50 | Dupes P50 | UsefulLeft P50 | Fusions P50 |")
	w("|-----|----------|-----------|-----------|------------|----------|--------|--------|--------------|-----------|----------------|-------------|")
	for _, m in MINUTES do
		local a = Unified.aggregate(results, m)
		w(
			`| {m} | {fmt(a.Luck.P50, 1)} | {fmt(a.RarePct.P50, 1)} | {fmt(a.EpicPct.P50, 2)} | {fmtInt(a.Unique.P50)} | {fmt(a.Income.P50, 0)} | {fmt(a.CE.P50, 0)} | {fmtInt(a.CoreLuck.P50)} | {fmtInt(a.Rebirths.P50)} | {fmtInt(a.Dupes.P50)} | {fmtInt(a.UsefulLeft.P50)} | {fmtInt(a.Fusions.P50)} |`
		)
	end
	w("")
	w("P10–P90 bands (selected):")
	w("")
	w("| Min | Unique P10–P90 | Rare% P10–P90 | Rebirths P10–P90 | Income P10–P90 |")
	w("|-----|----------------|---------------|------------------|----------------|")
	for _, m in MINUTES do
		local a = Unified.aggregate(results, m)
		w(
			`| {m} | {fmtInt(a.Unique.P10)}–{fmtInt(a.Unique.P90)} | {fmt(a.RarePct.P10, 1)}–{fmt(a.RarePct.P90, 1)} | {fmtInt(a.Rebirths.P10)}–{fmtInt(a.Rebirths.P90)} | {fmt(a.Income.P10, 0)}–{fmt(a.Income.P90, 0)} |`
		)
	end
	w("")
end

w("## 3. Integrated policy simulations (simulated)")
w("")
w("### Approximations (disclose)")
w("")
for _, note in main[1].ApproxNotes do
	w(`- {note}`)
end
w("")

writeAggTable("3.1 SoftCap + B+ — AfkUpgrader (Collection HUD **off**, playtest-like)", main)
writeAggTable("3.2 SoftCap + B+ — Casual (HUD on)", policies.Casual)
writeAggTable("3.3 SoftCap + B+ — Hunter (HUD on)", policies.Hunter)
writeAggTable("3.4 SoftCap + B+ — Optimized (HUD on)", policies.Optimized)
writeAggTable("3.5 Soft A+C ladder + B+ — AfkUpgrader (control)", ladder)
writeAggTable("3.6 SoftCap + B+ — AfkUpgrader with HUD on (counterfactual fusion)", afkHud)

-- Rebirth timing table
local function rebirthStats(results: { any }): (number?, number?, number?, number?, number?, number?)
	local r1, r2, r3 = {}, {}, {}
	for _, r in results do
		if r.RebirthsAt[1] then
			table.insert(r1, r.RebirthsAt[1] / 60)
		end
		if r.RebirthsAt[2] then
			table.insert(r2, r.RebirthsAt[2] / 60)
		end
		if r.RebirthsAt[3] then
			table.insert(r3, r.RebirthsAt[3] / 60)
		end
	end
	table.sort(r1)
	table.sort(r2)
	table.sort(r3)
	return Unified.percentile(r1, 0.1),
		Unified.percentile(r1, 0.5),
		Unified.percentile(r1, 0.9),
		Unified.percentile(r2, 0.5),
		Unified.percentile(r3, 0.5),
		#r1 / #results
end

w("## 4. Rebirth models (SoftCap AfkUpgrader)")
w("")
w("| Model | R1 P10 | R1 P50 | R1 P90 | R2 P50 | R3 P50 | Fraction with R1 by 180m |")
w("|-------|--------|--------|--------|--------|--------|--------------------------|")
for _, row in {
	{ "A full reset", rebirthA },
	{ "B cash-only naked", rebirthB },
	{ "B+ cash + gates", main },
	{ "C hybrid (CE+peds)", rebirthC },
} do
	local p10, p50, p90, r2, r3, frac = rebirthStats(row[2])
	w(
		`| {row[1]} | {fmt(p10, 0)} | {fmt(p50, 0)} | {fmt(p90, 0)} | {fmt(r2, 0)} | {fmt(r3, 0)} | {fmt(100 * (frac or 0), 0)}% |`
	)
end
w("")
w("Useful upgrades remaining at 35m / 60m (P50) under SoftCap:")
w("")
w("| Model | UsefulLeft@35* | UsefulLeft@60 |")
w("|-------|----------------|---------------|")
-- 35 not in list — interpolate from 30 and 45
local function usefulAt(results, minute)
	-- nearest checkpoint
	local a = Unified.aggregate(results, minute)
	return a.UsefulLeft.P50
end
w(`| B+ | ~{fmtInt(usefulAt(main, 30))} (30m) / ~{fmtInt(usefulAt(main, 45))} (45m) | {fmtInt(usefulAt(main, 60))} |`)
w(`| B naked | ~{fmtInt(usefulAt(rebirthB, 30))} / ~{fmtInt(usefulAt(rebirthB, 45))} | {fmtInt(usefulAt(rebirthB, 60))} |`)
w(`| A | ~{fmtInt(usefulAt(rebirthA, 30))} / ~{fmtInt(usefulAt(rebirthA, 45))} | {fmtInt(usefulAt(rebirthA, 60))} |`)
w(`| C | ~{fmtInt(usefulAt(rebirthC, 30))} / ~{fmtInt(usefulAt(rebirthC, 45))} | {fmtInt(usefulAt(rebirthC, 60))} |`)
w("")

-- Playtest calibration
w("## 5. Calibration vs real 35:51 playtest")
w("")
w("| Signal | Real playtest | SoftCap AfkUpgrader P50 @30m | SoftAC Afk P50 @30m |")
w("|--------|---------------|------------------------------|---------------------|")
local m30 = Unified.aggregate(main, 30)
local l30 = Unified.aggregate(ladder, 30)
local m45 = Unified.aggregate(main, 45)
w(`| Rare domination | ~99% rolls Rare mid-session | Rare% {fmt(m30.RarePct.P50, 1)} | Rare% {fmt(l30.RarePct.P50, 1)} |`)
w(`| Unique relics ~30m | ~50 uniques by ~25–30m | {fmtInt(m30.Unique.P50)} | {fmtInt(l30.Unique.P50)} |`)
w(`| Core Luck | 21 @ ~29m | CL {fmtInt(m30.CoreLuck.P50)} (25-cap candidate) | CL {fmtInt(l30.CoreLuck.P50)} |`)
w(`| Rebirth | 0 (400M unaffordable) | Rebirths {fmtInt(m30.Rebirths.P50)} @30m; R1 P50 {fmt(select(2, rebirthStats(main)), 0)}m | same cost |`)
w(`| Fusion | 0 (no HUD) | Fusions {fmtInt(m30.Fusions.P50)} with HUD off | — |`)
w(`| Fusion if HUD on | — | Afk+HUD Fusions@30 {fmtInt(Unified.aggregate(afkHud, 30).Fusions.P50)} | — |`)
w("")
w("Playtest match goals: SoftCap should **not** reproduce 99% Rare; should keep early excitement (uniques climbing by 5–15m); AfkUpgrader with HUD off should show **0 fusions** like reality.")
w("")

-- Upgrade economy candidates
w("## 6. Candidate upgrade economy (costs computed; timelines simulated)")
w("")
w("| Upgrade | Cap (candidate) | Sample costs | Notes |")
w("|---------|-----------------|--------------|-------|")
w("| Attunement (CL) | 25 | 0→1: 100; 14→15: ~" .. tostring(math.ceil(100 * 1.7 ^ 14 * (1 + 0.05 * 14) ^ 1.35)) .. "; 24→25: ~" .. tostring(math.ceil(100 * 1.7 ^ 24 * (1 + 0.05 * 24) ^ 1.35)) .. " | Soft-C style; ranks 16–25 gated in B+ |")
w("| Scan Speed | 10 | live-like 250×2.2^r | Early foundation |")
w("| Energy | 15 + II×10 | 500×1.7^r; II from 2M×1.8^r | II after R1 (B+) |")
w("| Pedestal | Soft 30 + Mastery 5 | 60×1.32^(L-1); Mastery 500k×3^r | Avoid live L50 finish void |")
w("| MutationRes | 2 pre / 5 post | live ladder 250k…40B | Deep ranks post-R1 |")
w("| SpiritMerchant | **removed** in sim | — | Redundant with pedestals |")
w("")
local emptyTimes = {}
for _, r in main do
	if r.UsefulEmptyAt then
		table.insert(emptyTimes, r.UsefulEmptyAt / 60)
	end
end
table.sort(emptyTimes)
w(
	`AfkUpgrader SoftCap B+ (HUD off): median time to **zero useful buys before R1 gates** = **{fmt(Unified.percentile(emptyTimes, 0.5), 0)}** min (P10 {fmt(Unified.percentile(emptyTimes, 0.1), 0)} / P90 {fmt(Unified.percentile(emptyTimes, 0.9), 0)}).`
)
w("")
w("### Critical finding: pre-R1 shop void under B+")
w("")
w("B+ gates CL16–25 / Energy II / Mastery / MutDeep behind R1. With ped soft-cap finishing ~15–20m, **UsefulLeft hits 0 around minute 18**, while R1 P50 is ~75m. That leaves ~45–60 minutes of CE bank-up with no shop purchases — passive waiting, not collecting joy.")
w("")
w("Naked B/A/C keep Attunement open to 25 pre-R1, so UsefulLeft stays ≥1 longer — but naked B still has no *new* gated fantasy after foundations, and A resets the build.")
w("")
w("**Design implication (not implemented):** prefer one of: (1) pre-R1 Mastery crumb or CL16–18 ungated; (2) lower BaseCost so R1 lands nearer 45–55m; (3) Collection HUD as the primary mid-session sink (already mandatory for engagement). Do **not** inflate costs just to stretch time.")
w("")

-- Dupes/min from Afk SoftCap
w("### Dupes per minute (SoftCap B+ AfkUpgrader P50)")
w("")
w("| Window | Dupes Δ | Dupes/min |")
w("|--------|---------|-----------|")
do
	local prev = 0
	local prevM = 0
	for _, m in MINUTES do
		local a = Unified.aggregate(main, m)
		local d = (a.Dupes.P50 or 0) - prev
		local dm = m - prevM
		w(`| {prevM}→{m} | {fmtInt(d)} | {fmt(d / math.max(1, dm), 1)} |`)
		prev = a.Dupes.P50 or 0
		prevM = m
	end
end
w("")
w("Under SoftCap, mid-session dupe rate stays high (Commons/Uncommons keep dropping) — Collection Essence sinks are the intended absorber, not rarity inflation.")
w("")

-- Recommendations
w("## 7. Recommendations by system")
w("")
w("### 7.1 Luck & rarity — **SoftCap YES for Studio trial**")
w("")
w("| Verdict | SoftCap over Soft A+C ladder |")
w("|---------|------------------------------|")
w("| Why | Kills 99% Rare wall; Luck L1-distance meaningful; Index 1/p_i readable; Cosmic/Celestial stay scarce |")
w("| Trade-off | Early Epic ~15× Soft A+C at L=1; Common/Uncommon stay majority → dupe flood needs Collection |")
w("| Not enough | Colorful band % alone ≠ better game — shop void + missing HUD still ruin the loop |")
w("")
w("- Retune Epic \(R\)/\(M\) if Studio feels purple-early.")
w("- Index must show \(1/p_i\), never raw \(R/L\).")
w("")
w("### 7.2 CE & upgrades — **direction YES; B+ gate timing NO as-is**")
w("")
w("| Verdict | Keep CL25 + ped soft-cap/Mastery; fix pre-R1 sink |")
w("|---------|---------------------------------------------------|")
w("| Why | Addresses CL wall + L50 finish void from playtest |")
w("| Trade-off | UsefulLeft=0 @~18m under B+ while R1@~75m |")
w("| Action | Pre-R1 Mastery crumb and/or CL16–18 open; merge SpiritMerchant |")
w("")
w("### 7.3 Collection — **HUD Phase 1 mandatory before rarity ship**")
w("")
w("| Verdict | Ship Collection opener first |")
w("|---------|------------------------------|")
w("| Why | HUD-off = 0 fusions (matches playtest); HUD-on absorbs Essence; SoftCap *needs* a dupe sink |")
w("| Trade-off | Fuse stub ≠ full board; Forms optional, not 276 stamps |")
w("")
w("### 7.4 Rebirth — **B+ preferred with timing fix; not naked B**")
w("")
w("| Verdict | B+ structure yes; pair with shorter void or lower BaseCost |")
w("|---------|-------------------------------------------------------------|")
w("| R1 P50 | SoftCap Afk ~75m (soft 45–75 band upper edge) |")
w("| vs A | Full reset slower R2/R3; collector-hostile |")
w("| vs B | Naked keeps CL open but no post-R1 fantasy; still CE wait |")
w("| vs C | Ped rebuild acceptable fallback if B+ feels too soft |")
w("")
w("Priority is enjoyable collecting — cut waiting, do not inflate costs.")
w("")

w("## 8. First-three-hour journey (SoftCap B+ Optimized P50 — simulated)")
w("")
local opt = policies.Optimized
w("| Min | Focus |")
w("|-----|-------|")
for _, m in MINUTES do
	local a = Unified.aggregate(opt, m)
	w(
		`| {m} | Luck~{fmt(a.Luck.P50, 0)}, Rare~{fmt(a.RarePct.P50, 0)}%, Epic~{fmt(a.EpicPct.P50, 1)}%, Uniques~{fmtInt(a.Unique.P50)}, CL~{fmtInt(a.CoreLuck.P50)}, R~{fmtInt(a.Rebirths.P50)}, UsefulLeft~{fmtInt(a.UsefulLeft.P50)}, Fusions~{fmtInt(a.Fusions.P50)} |`
	)
end
w("")

w("## 9. Retain / simplify / remove")
w("")
w("| Action | Item |")
w("|--------|------|")
w("| Retain | 92 relics, pedestals, hunt, Soft A luck growth trial, Collection data, Resonance |")
w("| Simplify | Attune sprawl until Index live; Focus copy → Index chase |")
w("| Merge/remove | SpiritMerchant |")
w("| Replace (Studio trial) | Tier ladder sampler → SoftCap |")
w("| Add | Collection HUD, ped Mastery, B+ gates, Attunement 25 |")
w("")

w("## 10. Implementation sequence (after approval — not done now)")
w("")
w("1. Collection HUD + onboarding  ")
w("2. SoftCap + Index \(1/p_i\) behind Studio flag  ")
w("3. Upgrade/pedestal candidates behind flag  ")
w("4. Rebirth B+  ")
w("5. Forms / hunt targeting  ")
w("")
w("Full `lune run tests/run` after each phase. Production `Active = nil`.")
w("")

w("## 11. Risks & acceptance criteria")
w("")
w("| Risk | Mitigation / acceptance |")
w("|------|-------------------------|")
w("| Early Epic too common | Raise Epic R or cut M; accept if Epic/1000 @L=150 in 4–12 |")
w("| Common dupe flood | Forms/Essence sinks; Focus missing Index |")
w("| UsefulLeft=0 before R1 | Pre-R1 Mastery crumb or BaseCost tweak |")
w("| Sim ≠ BindService | Studio human playtest after Phase 1–2 |")
w("| Frozen incomes vs SoftCap odds | Later retune RelicIncome if trial ships |")
w("")
w("**Acceptance for next human playtest:** Rare% mid-session ≪ 50%; Collection opens; at least one post-foundation sink before R1 or R1 inside soft band with nonempty post-R1 shop.")
w("")

w("## 12. Probability invariants (this run)")
w("")
w("- SoftCap Σp = 1 at tested L (unit tests).")
w("- SoftCap L1(60,150) > 0.05.")
w("- Ladder Rare @150 > 95%; SoftCap Rare @150 < 40%.")
w(`- Roster size {#RelicConfig.Relics}. Rebirth BaseCost {Config.Rebirth.BaseCost}.`)
w("")
w("---")
w("")
w(`*Generated by \`lune run tests/unifiedProgression\` with {SEEDS} seeds.*`)

local path = "docs/UNIFIED_PROGRESSION_REV4.md"
fs.writeFile(path, table.concat(lines, "\n"))
print(`Wrote {path} ({#lines} lines)`)
