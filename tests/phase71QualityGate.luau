-- Phase 7.1 integrated gameplay quality gate (N=8 per policy, 180m).
--   lune run tests/phase71QualityGate

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")

local SEEDS = 8
local proposal = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

local function pct(arr, p)
	if #arr == 0 then
		return nil
	end
	local c = table.clone(arr)
	table.sort(c)
	return Unified.percentile(c, p)
end

local function fmt(n: number?): string
	if n == nil then
		return "-"
	end
	return string.format("%.1f", n)
end

print("=== Phase 7.1 Quality Gate (N=8, 180m, SoftCap B+) ===\n")

local policies = { "AfkUpgrader", "Casual", "Hunter", "Optimized" }
local epicAtMin: { [string]: { [number]: number } } = {}

for _, pol in policies do
	local buckets: { [number]: {
		pot: { number },
		cats: { number },
		asc: { number },
		unique: { number },
		dupes: { number },
		r: { number },
		dry: { number },
		useful: { number },
		ess: { number },
	} } = {}
	for _, m in { 60, 90, 120, 180 } do
		buckets[m] = { pot = {}, cats = {}, asc = {}, unique = {}, dupes = {}, r = {}, dry = {}, useful = {}, ess = {} }
	end
	local pursuits = {}
	local epicFirstMin = {}
	local r1s = {}
	epicAtMin[pol] = { [60] = 0, [90] = 0, [120] = 0, [180] = 0 }

	for seed = 1, SEEDS do
		local r = Unified.run({
			Seed = seed,
			Minutes = 180,
			Policy = pol :: any,
			Sampler = "SoftCap",
			RebirthModel = "BPlus",
			CollectionHud = true,
			Proposal = proposal,
			TickMode = "Event",
		})
		if r.FirstRebirthAt then
			table.insert(r1s, r.FirstRebirthAt / 60)
		end
		local firstEpicPot = nil
		for _, cp in r.Checkpoints do
			local m = cp.Minute
			if buckets[m] then
				table.insert(buckets[m].pot, cp.BestCharmPotency or 1)
				table.insert(buckets[m].cats, cp.EpicCatalysts or 0)
				table.insert(buckets[m].asc, cp.CharmAscensions or 0)
				table.insert(buckets[m].unique, cp.Unique or 0)
				table.insert(buckets[m].dupes, if (cp.TotalFinds or 0) > 0 then (cp.Dupes or 0) / cp.TotalFinds else 0)
				table.insert(buckets[m].r, cp.Rebirths or 0)
				table.insert(buckets[m].dry, cp.LongestDryMin or 0)
				table.insert(buckets[m].useful, cp.UsefulBuysLeft or 0)
				table.insert(buckets[m].ess, cp.Essence or 0)
				if (cp.BestCharmPotency or 1) >= 2.05 then
					epicAtMin[pol][m] = (epicAtMin[pol][m] or 0) + 1
					if not firstEpicPot then
						firstEpicPot = m
					end
				end
			end
			if m == 180 and cp.ActivePursuit then
				pursuits[cp.ActivePursuit] = (pursuits[cp.ActivePursuit] or 0) + 1
			end
		end
		if firstEpicPot then
			table.insert(epicFirstMin, firstEpicPot)
		end
	end

	print(`[{pol}]  R1 P50={fmt(pct(r1s, 0.5))}m`)
	local bits = {}
	for id, n in pursuits do
		table.insert(bits, `{id}={n}`)
	end
	table.sort(bits)
	print("  Pursuit@180: " .. table.concat(bits, " "))
	print(
		string.format(
			"  EpicAsc hit by 60/90/120/180: %d/%d/%d/%d of %d  | first EpicAsc minute P50=%s",
			epicAtMin[pol][60] or 0,
			epicAtMin[pol][90] or 0,
			epicAtMin[pol][120] or 0,
			epicAtMin[pol][180] or 0,
			SEEDS,
			fmt(pct(epicFirstMin, 0.5))
		)
	)
	for _, m in { 60, 90, 120, 180 } do
		local b = buckets[m]
		print(
			string.format(
				"  @%3dm  pot×%.2f  cats%.1f  asc%.1f  R%.1f  unique%.0f  dupe%%%.0f  dry%.1fm  usefulLeft%.0f  ess%.0f",
				m,
				pct(b.pot, 0.5) or 1,
				pct(b.cats, 0.5) or 0,
				pct(b.asc, 0.5) or 0,
				pct(b.r, 0.5) or 0,
				pct(b.unique, 0.5) or 0,
				(pct(b.dupes, 0.5) or 0) * 100,
				pct(b.dry, 0.5) or 0,
				pct(b.useful, 0.5) or 0,
				pct(b.ess, 0.5) or 0
			)
		)
	end
	print("")
end

print("-- Design challenge summary --")
print("Epic Ascension early? Compare EpicAsc@60 vs @180 hit rates above.")
print("AFK vs active: AfkUpgrader should lag EpicAsc; Hunter/Optimized should lead.")
print("Post-Epic activities: cats rising after pot×2.10, usefulLeft≈0, unique still climbing.")
print("\n=== Done ===")
