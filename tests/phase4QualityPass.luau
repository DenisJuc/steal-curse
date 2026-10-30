-- Phase 4 progression-quality pass (evidence only; no balance edits).
--   lune run tests/phase4QualityPass
-- Paired seeds: same Seed for each arm. RNG streams diverge when keep/sell or rebirth
-- model changes luck/CE paths — reported explicitly.

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local Rebirth = require("../src/shared/Rebirth")
local SkillConfig = require("../src/shared/SkillConfig")
local CollectionConfig = require("../src/shared/CollectionConfig")
local CollectionMath = require("../src/shared/CollectionMath")
local Formulas = require("../src/shared/Formulas")

local SEEDS = 40
local MINUTES = 180

local function fmt(n: number?, d: number?): string
	if n == nil then
		return "—"
	end
	return string.format(`%.{d or 1}f`, n)
end

local function pct(arr: { number }, p: number): number?
	if #arr == 0 then
		return nil
	end
	local copy = table.clone(arr)
	table.sort(copy)
	return Unified.percentile(copy, p)
end

local function mean(arr: { number }): number?
	if #arr == 0 then
		return nil
	end
	local s = 0
	for _, v in arr do
		s += v
	end
	return s / #arr
end

local function coreLuckCost(rank: number): number
	local flat = 100 * (1.7 ^ rank)
	return math.ceil(flat * ((1 + 0.05 * rank) ^ 1.35) - 1e-9)
end

local function masteryCost(rank: number): number
	local node = SkillConfig.ById.PedestalMastery
	return SkillConfig.cost(node, rank) or math.ceil(180000 * (2.8 ^ rank) - 1e-9)
end

local proposalP4 = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

local proposalP3 = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = false,
	FusionMeaningfulEvery = 8,
}

local proposalNoHud = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = false,
	BoardGlobalFusion = false,
	FusionMeaningfulEvery = 8,
}

local function runP4(seed: number, policy: string, hud: boolean): Unified.RunResult
	return Unified.run({
		Seed = seed,
		Minutes = MINUTES,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = hud,
		Proposal = if hud then proposalP4 else proposalNoHud,
		TickMode = "Event",
	})
end

local function runP3(seed: number, policy: string): Unified.RunResult
	return Unified.run({
		Seed = seed,
		Minutes = MINUTES,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "Live",
		CollectionHud = true,
		Proposal = proposalP3,
		TickMode = "Event",
	})
end

print("=== Phase 4 progression-quality pass ===")
print(
	string.format(
		"Rebirth: BaseCost=%.0e CostGrowth=%g IncomeGrowth=%g → R1/R2/R3 = %.0e / %.0e / %.0e",
		Config.Rebirth.BaseCost,
		Config.Rebirth.CostGrowth,
		Config.Rebirth.IncomeGrowth,
		Rebirth.cost(Config.Rebirth, 0),
		Rebirth.cost(Config.Rebirth, 1),
		Rebirth.cost(Config.Rebirth, 2)
	)
)
print(
	string.format(
		"SoftCap_P4 kept: B+ Rebirth, board-global Fusion, production isolation, BaseCost=%.0e",
		Config.Rebirth.BaseCost
	)
)
print(`Paired N={SEEDS} seeds; minutes={MINUTES}; Event tick`)
print("Source: Lune unifiedProgressionSim (not live Studio playtest).\n")

-- ---------------------------------------------------------------------------
-- 1) Analytic upgrade burn vs income
-- ---------------------------------------------------------------------------
print("--- Analytic: post-R1 CL 19–25 + Mastery 3–5 costs ---")
local clSum = 0
for r = 18, 24 do
	local c = coreLuckCost(r)
	clSum += c
	print(string.format("  CL %d→%d cost = %.3e", r, r + 1, c))
end
local mastSum = 0
for r = 2, 4 do
	local c = masteryCost(r)
	mastSum += c
	print(string.format("  Mastery %d→%d cost = %.3e", r, r + 1, c))
end
print(string.format("  SUM CL18→25 = %.3e   SUM Mastery2→5 = %.3e   TOTAL = %.3e", clSum, mastSum, clSum + mastSum))
print(
	string.format(
		"  Live Formulas.coreLuckCostSoft(18)=%.3e (sim uses same soft params Base100 G1.7 k0.05 p1.35)",
		Formulas.coreLuckCostSoft(18, 100, 1.7, 0.05, 1.35)
	)
)

-- ---------------------------------------------------------------------------
-- 2) Hunter deep traces (seeds 1–5) + aggregate 40
-- ---------------------------------------------------------------------------
print("\n--- Hunter SoftCap_P4 Combined: RebirthTrace (seeds 1–5) ---")
local hGap12, hGap23, hEtaR3, hIncAfterR1, hCl25After, hMast5After = {}, {}, {}, {}, {}, {}
local hGolden, hRank2, hBoard2, hDry, hUseful15, hUseful45 = {}, {}, {}, {}, {}, {}
local hR1, hR2, hR3 = {}, {}, {}

for seed = 1, SEEDS do
	local r = runP4(seed, "Hunter", true)
	if r.RebirthsAt[1] then
		table.insert(hR1, r.RebirthsAt[1] / 60)
	end
	if r.RebirthsAt[2] then
		table.insert(hR2, r.RebirthsAt[2] / 60)
	end
	if r.RebirthsAt[3] then
		table.insert(hR3, r.RebirthsAt[3] / 60)
		table.insert(hEtaR3, r.RebirthsAt[3] / 60)
	end
	if r.RebirthsAt[1] and r.RebirthsAt[2] then
		table.insert(hGap12, (r.RebirthsAt[2] - r.RebirthsAt[1]) / 60)
	end
	if r.RebirthsAt[2] and r.RebirthsAt[3] then
		table.insert(hGap23, (r.RebirthsAt[3] - r.RebirthsAt[2]) / 60)
	end
	if r.IncomeAfterR1 then
		table.insert(hIncAfterR1, r.IncomeAfterR1)
	end
	if r.FirstRebirthAt and r.Cl25At then
		table.insert(hCl25After, (r.Cl25At - r.FirstRebirthAt) / 60)
	end
	if r.FirstRebirthAt and r.Mastery5At then
		table.insert(hMast5After, (r.Mastery5At - r.FirstRebirthAt) / 60)
	end
	if r.FirstGoldenAt then
		table.insert(hGolden, r.FirstGoldenAt / 60)
	end
	if r.FirstRank2At then
		table.insert(hRank2, r.FirstRank2At / 60)
	end
	if r.Board2At then
		table.insert(hBoard2, r.Board2At / 60)
	end
	table.insert(hDry, r.Final.LongestDryMin)
	for _, cp in r.Checkpoints do
		if cp.Minute == 15 then
			table.insert(hUseful15, cp.UsefulBuysLeft)
		elseif cp.Minute == 45 then
			table.insert(hUseful45, cp.UsefulBuysLeft)
		end
	end

	if seed <= 5 then
		print(string.format("  seed %d:", seed))
		for _, tr in r.RebirthTrace do
			local eta = if tr.IncomeAfter > 0 then tr.Cost / tr.IncomeAfter else -1
			local nextCost = Rebirth.cost(Config.Rebirth, tr.Index) -- cost of NEXT rebirth after this one
			local etaNext = if tr.IncomeAfter > 0 then nextCost / tr.IncomeAfter else -1
			print(
				string.format(
					"    R%d @%.1fm cost=%.2e CE=%.2e IncBefore=%.2e IncAfter=%.2e | CL=%d Mast=%d PedMin=%d E=%d Mut=%d Useful=%d | Board=%d Lift=×%.2f MaxF=%d Golden=%s Ess=%.0f",
					tr.Index,
					tr.Sec / 60,
					tr.Cost,
					tr.CeBefore,
					tr.IncomeBefore,
					tr.IncomeAfter,
					tr.CL,
					tr.Mastery,
					tr.PedMin,
					tr.Energy,
					tr.MutRes,
					tr.UsefulLeft,
					tr.Board,
					tr.Lift,
					tr.MaxFusionRank,
					if tr.FirstGolden then "Y" else "N",
					tr.Essence
				)
			)
			if tr.Index < 3 then
				print(
					string.format(
						"      → theor. time to next cost %.2e @ IncAfter: %.1fm (actual gap uses spending)",
						nextCost,
						etaNext / 60
					)
				)
			end
		end
		local burnSec = if r.IncomeAfterR1 and r.IncomeAfterR1 > 0 then (clSum + mastSum) / r.IncomeAfterR1 else nil
		print(
			string.format(
				"    milestones: CL25@%sm (+%sm post-R1) Mast5@%sm (+%sm) Golden@%sm Rank2@%sm Board2@%sm Dry=%.1fm",
				fmt(r.Cl25At and r.Cl25At / 60, 1),
				fmt(if r.FirstRebirthAt and r.Cl25At then (r.Cl25At - r.FirstRebirthAt) / 60 else nil, 1),
				fmt(r.Mastery5At and r.Mastery5At / 60, 1),
				fmt(if r.FirstRebirthAt and r.Mastery5At then (r.Mastery5At - r.FirstRebirthAt) / 60 else nil, 1),
				fmt(r.FirstGoldenAt and r.FirstGoldenAt / 60, 1),
				fmt(r.FirstRank2At and r.FirstRank2At / 60, 1),
				fmt(r.Board2At and r.Board2At / 60, 1),
				r.Final.LongestDryMin
			)
		)
		print(
			string.format(
				"    post-R1 upgrade TOTAL / IncAfterR1 = %s sec (%sm) if spent only on CL+Mast",
				fmt(burnSec, 0),
				fmt(burnSec and burnSec / 60, 1)
			)
		)
	end
end

print("\n--- Hunter P4 Combined aggregate (N=40) ---")
print(
	string.format(
		"  R1 P10/50/90 = %s / %s / %s min  (n=%d)",
		fmt(pct(hR1, 0.1), 1),
		fmt(pct(hR1, 0.5), 1),
		fmt(pct(hR1, 0.9), 1),
		#hR1
	)
)
print(
	string.format(
		"  R2 P10/50/90 = %s / %s / %s min  (n=%d)",
		fmt(pct(hR2, 0.1), 1),
		fmt(pct(hR2, 0.5), 1),
		fmt(pct(hR2, 0.9), 1),
		#hR2
	)
)
print(
	string.format(
		"  R3 P10/50/90 = %s / %s / %s min  (n=%d)",
		fmt(pct(hR3, 0.1), 1),
		fmt(pct(hR3, 0.5), 1),
		fmt(pct(hR3, 0.9), 1),
		#hR3
	)
)
print(
	string.format(
		"  gap R1→R2 P10/50/90 = %s / %s / %s min",
		fmt(pct(hGap12, 0.1), 1),
		fmt(pct(hGap12, 0.5), 1),
		fmt(pct(hGap12, 0.9), 1)
	)
)
print(
	string.format(
		"  gap R2→R3 P10/50/90 = %s / %s / %s min   ← 4m band expected from Cost×4 / Income×2",
		fmt(pct(hGap23, 0.1), 1),
		fmt(pct(hGap23, 0.5), 1),
		fmt(pct(hGap23, 0.9), 1)
	)
)
print(
	string.format(
		"  IncAfterR1 P10/50/90 = %.2e / %.2e / %.2e",
		pct(hIncAfterR1, 0.1) or 0,
		pct(hIncAfterR1, 0.5) or 0,
		pct(hIncAfterR1, 0.9) or 0
	)
)
print(
	string.format(
		"  CL25 minutes-after-R1 P10/50/90 = %s / %s / %s   (n=%d/%d)",
		fmt(pct(hCl25After, 0.1), 1),
		fmt(pct(hCl25After, 0.5), 1),
		fmt(pct(hCl25After, 0.9), 1),
		#hCl25After,
		SEEDS
	)
)
print(
	string.format(
		"  Mast5 minutes-after-R1 P10/50/90 = %s / %s / %s   (n=%d/%d)",
		fmt(pct(hMast5After, 0.1), 1),
		fmt(pct(hMast5After, 0.5), 1),
		fmt(pct(hMast5After, 0.9), 1),
		#hMast5After,
		SEEDS
	)
)
print(
	string.format(
		"  FirstGolden / Rank2 / Board2 hit rates: %d/%d  %d/%d  %d/%d",
		#hGolden,
		SEEDS,
		#hRank2,
		SEEDS,
		#hBoard2,
		SEEDS
	)
)
print(
	string.format(
		"  FirstGolden P50=%sm  Rank2 P50=%sm  Board2 P50=%sm  (among hits)",
		fmt(pct(hGolden, 0.5), 1),
		fmt(pct(hRank2, 0.5), 1),
		fmt(pct(hBoard2, 0.5), 1)
	)
)
print(
	string.format(
		"  LongestDry P10/50/90 = %s / %s / %s min (meaningful≠ped+1)",
		fmt(pct(hDry, 0.1), 1),
		fmt(pct(hDry, 0.5), 1),
		fmt(pct(hDry, 0.9), 1)
	)
)

-- Explain R2→R3 mechanically from median income
local medInc = pct(hIncAfterR1, 0.5) or 0
local r2cost = Rebirth.cost(Config.Rebirth, 1)
local r3cost = Rebirth.cost(Config.Rebirth, 2)
local incAfterR2 = medInc * Config.Rebirth.IncomeGrowth -- B+ keeps ped/skills; only ×IncomeGrowth
print("\n--- Mechanic check: R2→R3 interval (median IncAfterR1) ---")
print(string.format("  Median IncAfterR1 = %.3e CE/s", medInc))
print(string.format("  After R2 income ≈ IncAfterR1 × IncomeGrowth = %.3e CE/s", incAfterR2))
print(string.format("  R3 cost = %.3e → pure accumulate ≈ %.1f min (no CE spending)", r3cost, (r3cost / math.max(incAfterR2, 1)) / 60))
print(string.format("  R2 cost / IncAfterR1 ≈ %.1f min pure; observed R1→R2 P50=%sm (spending + policy)", (r2cost / math.max(medInc, 1)) / 60, fmt(pct(hGap12, 0.5), 1)))
print("  Intended: B+ leaves pedDone=true, so post-R1 Rebirths are CE-gated only; CostGrowth=4 vs IncomeGrowth=2 ⇒ each successive gap halves if income only scales with Rebirth.")

-- ---------------------------------------------------------------------------
-- 3) Fusion requirements
-- ---------------------------------------------------------------------------
print("\n--- Fusion depth requirements (config) ---")
print(
	string.format(
		"  Rank1: CopiesForRank=%d consume=%d Essence Common=%d → Lift ×%.2f",
		CollectionConfig.CopiesForRank[1],
		CollectionConfig.FusionConsumeByRank[1],
		CollectionMath.fusionEssenceCost("Common", 1),
		CollectionConfig.FusionIncomeMultByRank[1]
	)
)
print(
	string.format(
		"  Rank2: CopiesForRank=%d consume=%d Essence Common=%d → Lift ×%.2f (same relic, targeted)",
		CollectionConfig.CopiesForRank[2],
		CollectionConfig.FusionConsumeByRank[2],
		CollectionMath.fusionEssenceCost("Common", 2),
		CollectionConfig.FusionIncomeMultByRank[2]
	)
)
print(
	string.format(
		"  FirstGolden: UniqueRequired=%d Golden mut; MutRes chance rank1=%.0f%% rank5=%.0f%%; SlotBonus=+1",
		1,
		10,
		50
	)
)
print("  Board starts at 1 slot; without First Golden, only one fused relic can sit — Rank2 on that relic is the only Lift path past ×1.12.")

-- ---------------------------------------------------------------------------
-- 4) Paired P4 Combined vs NoHUD (Afk) — 40 seeds
-- ---------------------------------------------------------------------------
print("\n--- Paired Afk SoftCap_P4: Combined vs NoHUD (N=40, same Seed) ---")
print("  Note: RNG diverges via dupe keep/sell + luck; not bit-identical streams.")
local cR1, nR1, cR3, nR3, cDry, nDry = {}, {}, {}, {}, {}, {}
local cLift30, nLift30, cBoard30, cGolden, nGolden = {}, {}, {}, {}, {}
local cInc30, nInc30, pairDeltaR3 = {}, {}, {}
local bothR3 = 0
for seed = 1, SEEDS do
	local c = runP4(seed, "AfkUpgrader", true)
	local n = runP4(seed, "AfkUpgrader", false)
	if c.FirstRebirthAt then
		table.insert(cR1, c.FirstRebirthAt / 60)
	end
	if n.FirstRebirthAt then
		table.insert(nR1, n.FirstRebirthAt / 60)
	end
	if c.RebirthsAt[3] then
		table.insert(cR3, c.RebirthsAt[3] / 60)
	end
	if n.RebirthsAt[3] then
		table.insert(nR3, n.RebirthsAt[3] / 60)
	end
	if c.RebirthsAt[3] and n.RebirthsAt[3] then
		bothR3 += 1
		table.insert(pairDeltaR3, (c.RebirthsAt[3] - n.RebirthsAt[3]) / 60)
	end
	table.insert(cDry, c.Final.LongestDryMin)
	table.insert(nDry, n.Final.LongestDryMin)
	if c.FirstGoldenAt then
		table.insert(cGolden, c.FirstGoldenAt / 60)
	end
	if n.FirstGoldenAt then
		table.insert(nGolden, n.FirstGoldenAt / 60)
	end
	for _, cp in c.Checkpoints do
		if cp.Minute == 30 then
			table.insert(cLift30, cp.FusionLift)
			table.insert(cBoard30, cp.ActiveBoard)
			table.insert(cInc30, cp.IncomePerSec)
		end
	end
	for _, cp in n.Checkpoints do
		if cp.Minute == 30 then
			table.insert(nLift30, cp.FusionLift)
			table.insert(nInc30, cp.IncomePerSec)
		end
	end
end
print(
	string.format(
		"  Comb R1 P50=%sm R3 P50=%sm Dry P50=%sm Lift30 P50=×%s Board30 P50=%s Golden hits=%d/%d P50=%sm",
		fmt(pct(cR1, 0.5), 1),
		fmt(pct(cR3, 0.5), 1),
		fmt(pct(cDry, 0.5), 1),
		fmt(pct(cLift30, 0.5), 2),
		fmt(pct(cBoard30, 0.5), 0),
		#cGolden,
		SEEDS,
		fmt(pct(cGolden, 0.5), 1)
	)
)
print(
	string.format(
		"  NoHUD R1 P50=%sm R3 P50=%sm Dry P50=%sm Lift30 P50=×%s Golden hits=%d (expect 0)",
		fmt(pct(nR1, 0.5), 1),
		fmt(pct(nR3, 0.5), 1),
		fmt(pct(nDry, 0.5), 1),
		fmt(pct(nLift30, 0.5), 2),
		#nGolden
	)
)
print(
	string.format(
		"  Paired ΔR3 (Comb−NoHUD) P10/50/90 = %s / %s / %s min  (n_both=%d)  mean=%s",
		fmt(pct(pairDeltaR3, 0.1), 1),
		fmt(pct(pairDeltaR3, 0.5), 1),
		fmt(pct(pairDeltaR3, 0.9), 1),
		bothR3,
		fmt(mean(pairDeltaR3), 1)
	)
)

-- ---------------------------------------------------------------------------
-- 5) Paired SoftCap_P3 vs SoftCap_P4 (Hunter + Afk)
-- ---------------------------------------------------------------------------
print("\n--- Paired SoftCap_P3 (Live) vs SoftCap_P4 (B+) same Seed ---")
print("  RNG diverges strongly after R1 (Live wipes skills/peds).")
for _, policy in { "AfkUpgrader", "Hunter" } do
	local p3r1, p4r1, p3r3, p4r3, p3dry, p4dry = {}, {}, {}, {}, {}, {}
	local p3g, p4g, p3r2f, p4r2f = {}, {}, {}, {}
	local dR3 = {}
	for seed = 1, SEEDS do
		local a = runP3(seed, policy)
		local b = runP4(seed, policy, true)
		if a.FirstRebirthAt then
			table.insert(p3r1, a.FirstRebirthAt / 60)
		end
		if b.FirstRebirthAt then
			table.insert(p4r1, b.FirstRebirthAt / 60)
		end
		if a.RebirthsAt[3] then
			table.insert(p3r3, a.RebirthsAt[3] / 60)
		end
		if b.RebirthsAt[3] then
			table.insert(p4r3, b.RebirthsAt[3] / 60)
		end
		if a.RebirthsAt[3] and b.RebirthsAt[3] then
			table.insert(dR3, (b.RebirthsAt[3] - a.RebirthsAt[3]) / 60)
		end
		table.insert(p3dry, a.Final.LongestDryMin)
		table.insert(p4dry, b.Final.LongestDryMin)
		if a.FirstGoldenAt then
			table.insert(p3g, a.FirstGoldenAt / 60)
		end
		if b.FirstGoldenAt then
			table.insert(p4g, b.FirstGoldenAt / 60)
		end
		if a.FirstRank2At then
			table.insert(p3r2f, a.FirstRank2At / 60)
		end
		if b.FirstRank2At then
			table.insert(p4r2f, b.FirstRank2At / 60)
		end
	end
	print(string.format("  [%s]", policy))
	print(
		string.format(
			"    P3 R1 P50=%sm R3 P50=%sm Dry P50=%sm Golden=%d/%d Rank2=%d/%d",
			fmt(pct(p3r1, 0.5), 1),
			fmt(pct(p3r3, 0.5), 1),
			fmt(pct(p3dry, 0.5), 1),
			#p3g,
			SEEDS,
			#p3r2f,
			SEEDS
		)
	)
	print(
		string.format(
			"    P4 R1 P50=%sm R3 P50=%sm Dry P50=%sm Golden=%d/%d Rank2=%d/%d",
			fmt(pct(p4r1, 0.5), 1),
			fmt(pct(p4r3, 0.5), 1),
			fmt(pct(p4dry, 0.5), 1),
			#p4g,
			SEEDS,
			#p4r2f,
			SEEDS
		)
	)
	print(
		string.format(
			"    Paired ΔR3 (P4−P3) P10/50/90 = %s / %s / %s min (n=%d)",
			fmt(pct(dR3, 0.1), 1),
			fmt(pct(dR3, 0.5), 1),
			fmt(pct(dR3, 0.9), 1),
			#dR3
		)
	)
end

-- Afk drought + useful buys detail
print("\n--- Afk P4 Combined drought / useful (N=40) ---")
local aDry, aU15, aU45, aU60, aCl25, aM5, aGold, aR2 = {}, {}, {}, {}, {}, {}, {}, {}
for seed = 1, SEEDS do
	local r = runP4(seed, "AfkUpgrader", true)
	table.insert(aDry, r.Final.LongestDryMin)
	if r.FirstRebirthAt and r.Cl25At then
		table.insert(aCl25, (r.Cl25At - r.FirstRebirthAt) / 60)
	end
	if r.FirstRebirthAt and r.Mastery5At then
		table.insert(aM5, (r.Mastery5At - r.FirstRebirthAt) / 60)
	end
	if r.FirstGoldenAt then
		table.insert(aGold, r.FirstGoldenAt / 60)
	end
	if r.FirstRank2At then
		table.insert(aR2, r.FirstRank2At / 60)
	end
	for _, cp in r.Checkpoints do
		if cp.Minute == 15 then
			table.insert(aU15, cp.UsefulBuysLeft)
		elseif cp.Minute == 45 then
			table.insert(aU45, cp.UsefulBuysLeft)
		elseif cp.Minute == 60 then
			table.insert(aU60, cp.UsefulBuysLeft)
		end
	end
end
print(
	string.format(
		"  Dry P10/50/90 = %s / %s / %s min",
		fmt(pct(aDry, 0.1), 1),
		fmt(pct(aDry, 0.5), 1),
		fmt(pct(aDry, 0.9), 1)
	)
)
print(
	string.format(
		"  UsefulLeft@15/45/60 P50 = %s / %s / %s",
		fmt(pct(aU15, 0.5), 0),
		fmt(pct(aU45, 0.5), 0),
		fmt(pct(aU60, 0.5), 0)
	)
)
print(
	string.format(
		"  CL25 after R1 P50=%sm (n=%d)  Mast5 after R1 P50=%sm (n=%d)",
		fmt(pct(aCl25, 0.5), 1),
		#aCl25,
		fmt(pct(aM5, 0.5), 1),
		#aM5
	)
)
print(
	string.format(
		"  FirstGolden hits=%d/%d P50=%sm   Rank2 hits=%d/%d P50=%sm",
		#aGold,
		SEEDS,
		fmt(pct(aGold, 0.5), 1),
		#aR2,
		SEEDS,
		fmt(pct(aR2, 0.5), 1)
	)
)

-- Rank2 timing / Lift / CE stockpile impact (Afk + Hunter P4 Combined)
print("\n--- Phase 4.1 Rank2 / Lift / drought / CE impact (P4 Combined, N=40) ---")
for _, policy in { "AfkUpgrader", "Hunter" } do
	local r2at, lift30, lift60, lift90, board30, board60, ess30, dup30 = {}, {}, {}, {}, {}, {}, {}, {}
	local dry, r1, r2, r3 = {}, {}, {}, {}
	local hit30, hit60, hit90 = 0, 0, 0
	for seed = 1, SEEDS do
		local r = runP4(seed, policy, true)
		table.insert(dry, r.Final.LongestDryMin)
		if r.FirstRebirthAt then
			table.insert(r1, r.FirstRebirthAt / 60)
		end
		if r.RebirthsAt[2] then
			table.insert(r2, r.RebirthsAt[2] / 60)
		end
		if r.RebirthsAt[3] then
			table.insert(r3, r.RebirthsAt[3] / 60)
		end
		if r.FirstRank2At then
			local m = r.FirstRank2At / 60
			table.insert(r2at, m)
			if r.FirstRank2At <= 30 * 60 then
				hit30 += 1
			end
			if r.FirstRank2At <= 60 * 60 then
				hit60 += 1
			end
			if r.FirstRank2At <= 90 * 60 then
				hit90 += 1
			end
		end
		for _, cp in r.Checkpoints do
			if cp.Minute == 30 then
				table.insert(lift30, cp.FusionLift)
				table.insert(board30, cp.ActiveBoard)
				table.insert(ess30, cp.Essence)
				table.insert(dup30, cp.Dupes)
			elseif cp.Minute == 60 then
				table.insert(lift60, cp.FusionLift)
				table.insert(board60, cp.ActiveBoard)
			elseif cp.Minute == 90 then
				table.insert(lift90, cp.FusionLift)
			end
		end
	end
	print(string.format("  [%s]", policy))
	print(
		string.format(
			"    Rank2 by 30/60/90: %.0f%% / %.0f%% / %.0f%%   Rank2 P50=%sm (n=%d)",
			100 * hit30 / SEEDS,
			100 * hit60 / SEEDS,
			100 * hit90 / SEEDS,
			fmt(pct(r2at, 0.5), 1),
			#r2at
		)
	)
	print(
		string.format(
			"    FusionLift P50 @30/60/90 = ×%s / ×%s / ×%s",
			fmt(pct(lift30, 0.5), 2),
			fmt(pct(lift60, 0.5), 2),
			fmt(pct(lift90, 0.5), 2)
		)
	)
	print(
		string.format(
			"    Board@30/60 P50 = %s / %s   Essence@30 P50=%s  Dupes@30 P50=%s",
			fmt(pct(board30, 0.5), 0),
			fmt(pct(board60, 0.5), 0),
			fmt(pct(ess30, 0.5), 0),
			fmt(pct(dup30, 0.5), 0)
		)
	)
	print(
		string.format(
			"    Dry P50/P90 = %s / %s min   R1/R2/R3 P50 = %s / %s / %s",
			fmt(pct(dry, 0.5), 1),
			fmt(pct(dry, 0.9), 1),
			fmt(pct(r1, 0.5), 1),
			fmt(pct(r2, 0.5), 1),
			fmt(pct(r3, 0.5), 1)
		)
	)
end

print("\n=== Done (sim only; verify key claims in Studio) ===")
