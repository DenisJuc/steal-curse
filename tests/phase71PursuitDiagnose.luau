-- Phase 7.1 Rebirth Pursuit diagnose.
--   lune run tests/phase71PursuitDiagnose

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")

local SEEDS = 10
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

print("=== Phase 7.1 Rebirth Pursuit diagnose (N=10) ===\n")

for _, pol in { "AfkUpgrader", "Hunter", "Optimized" } do
	local pot60, pot90, pot120, pot180 = {}, {}, {}, {}
	local asc180, cats60, cats180, r1, dry, rCount = {}, {}, {}, {}, {}, {}
	local epicAsc = 0
	local pursuits = {}
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
			table.insert(r1, r.FirstRebirthAt / 60)
		end
		table.insert(asc180, r.CharmAscensions or 0)
		table.insert(dry, r.Final.LongestDryMin)
		table.insert(rCount, r.Final.Rebirths or 0)
		for _, cp in r.Checkpoints do
			if cp.Minute == 60 then
				table.insert(pot60, cp.BestCharmPotency or 1)
				table.insert(cats60, cp.EpicCatalysts or 0)
			elseif cp.Minute == 90 then
				table.insert(pot90, cp.BestCharmPotency or 1)
			elseif cp.Minute == 120 then
				table.insert(pot120, cp.BestCharmPotency or 1)
			elseif cp.Minute == 180 then
				table.insert(pot180, cp.BestCharmPotency or 1)
				table.insert(cats180, cp.EpicCatalysts or 0)
				if (cp.BestCharmPotency or 1) >= 2.05 then
					epicAsc += 1
				end
				if cp.ActivePursuit then
					pursuits[cp.ActivePursuit] = (pursuits[cp.ActivePursuit] or 0) + 1
				end
			end
		end
	end
	print(`[{pol}]`)
	print(
		string.format(
			"  R1 P50=%.1fm  R@180 P50=%.1f  Asc@180 P50=%.1f  Cats@60/180 P50=%.1f/%.1f",
			pct(r1, 0.5) or -1,
			pct(rCount, 0.5) or 0,
			pct(asc180, 0.5) or 0,
			pct(cats60, 0.5) or 0,
			pct(cats180, 0.5) or 0
		)
	)
	print(
		string.format(
			"  Pot@60/90/120/180 P50=×%.2f/×%.2f/×%.2f/×%.2f  EpicPot@180=%d/%d  Dry=%.1fm",
			pct(pot60, 0.5) or 1,
			pct(pot90, 0.5) or 1,
			pct(pot120, 0.5) or 1,
			pct(pot180, 0.5) or 1,
			epicAsc,
			SEEDS,
			pct(dry, 0.5) or 0
		)
	)
	local pursBits = {}
	for id, n in pursuits do
		table.insert(pursBits, `{id}={n}`)
	end
	table.sort(pursBits)
	print("  Pursuit@180: " .. table.concat(pursBits, " "))
end

print("\n=== Done ===")
