-- Post-Epic 90–180 gate: useful quarry chase across policies (Discover/MutCodex/Ascend).
--   lune run tests/phase8PostEpicGate

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

local function delta(a, b)
	return (b or 0) - (a or 0)
end

print("=== Post-Epic 90–180 gate (N=8) ===\n")
print("Checkpoints: useful quarry Δ, unique finds Δ, muts, rebirths, dry spell, charm potency\n")

for _, pol in { "AfkUpgrader", "Casual", "Hunter", "Optimized" } do
	local u90, u120, u150, u180 = {}, {}, {}, {}
	local uniq90, uniq180 = {}, {}
	local mut90, mut180 = {}, {}
	local reb90, reb180 = {}, {}
	local dry180, pot180, ret180 = {}, {}, {}
	local raw180 = {}
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
		local byMin = {}
		for _, cp in r.Checkpoints do
			byMin[cp.Minute] = cp
		end
		local function grab(bucket, min, field)
			local cp = byMin[min]
			table.insert(bucket, if cp then (cp[field] or 0) else 0)
		end
		grab(u90, 90, "HuntQuarryUsefulHits")
		grab(u120, 120, "HuntQuarryUsefulHits")
		grab(u150, 150, "HuntQuarryUsefulHits")
		grab(u180, 180, "HuntQuarryUsefulHits")
		grab(uniq90, 90, "Unique")
		grab(uniq180, 180, "Unique")
		grab(mut90, 90, "Mutations")
		grab(mut180, 180, "Mutations")
		grab(reb90, 90, "Rebirths")
		grab(reb180, 180, "Rebirths")
		grab(dry180, 180, "LongestDryMin")
		grab(pot180, 180, "BestCharmPotency")
		grab(ret180, 180, "HuntQuarryRetargets")
		grab(raw180, 180, "HuntQuarryHits")
	end
	local function p50(a)
		return pct(a, 0.5) or 0
	end
	local U90, U120, U150, U180 = p50(u90), p50(u120), p50(u150), p50(u180)
	local R180 = p50(raw180)
	print(`[{pol}]`)
	print(
		string.format(
			"  UsefulHits P50 @90/120/150/180 = %.0f / %.0f / %.0f / %.0f  (Δ90→180 = %.0f)",
			U90,
			U120,
			U150,
			U180,
			delta(U90, U180)
		)
	)
	print(
		string.format(
			"  Useful/Raw @180 ≈ %.0f%%   Retargets=%.1f   Unique Δ90→180=%.0f   Mut Δ=%.0f",
			if R180 > 0 then (U180 / R180) * 100 else 0,
			p50(ret180),
			delta(p50(uniq90), p50(uniq180)),
			delta(p50(mut90), p50(mut180))
		)
	)
	print(
		string.format(
			"  Rebirths @90→180 = %.1f → %.1f   Dry=%.1fm   Pot=×%.2f",
			p50(reb90),
			p50(reb180),
			p50(dry180),
			p50(pot180)
		)
	)
end

print("\nPass bar: Hunter/Optimized UsefulHits keep rising after 90m; AFK Useful≈flat; Unique/Mut still move for hunters.")
print("=== Done ===")
