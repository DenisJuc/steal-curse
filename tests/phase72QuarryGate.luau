-- Hunt Quarry finalize gate: useful captures vs raw hits; AFK gap.
--   lune run tests/phase72QuarryGate

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

print("=== Hunt Quarry finalize gate (N=8, 180m) ===\n")
print("RawHits = any quarry SoftCap roll on hunt")
print("UsefulHits = mutation/catalyst/fuse/Ascend/Discover/MutCodex progress (not Essence dupes)")
print("Retargets = cooldown-gated useful quarry changes (not spam)\n")

for _, pol in { "AfkUpgrader", "Hunter", "Optimized" } do
	local raw90, raw180, use90, use180, ret180, dry180, pot180 = {}, {}, {}, {}, {}, {}, {}
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
		for _, cp in r.Checkpoints do
			if cp.Minute == 90 then
				table.insert(raw90, cp.HuntQuarryHits or 0)
				table.insert(use90, cp.HuntQuarryUsefulHits or 0)
			elseif cp.Minute == 180 then
				table.insert(raw180, cp.HuntQuarryHits or 0)
				table.insert(use180, cp.HuntQuarryUsefulHits or 0)
				table.insert(ret180, cp.HuntQuarryRetargets or 0)
				table.insert(dry180, cp.LongestDryMin or 0)
				table.insert(pot180, cp.BestCharmPotency or 1)
			end
		end
	end
	local r90, r180 = pct(raw90, 0.5) or 0, pct(raw180, 0.5) or 0
	local u90, u180 = pct(use90, 0.5) or 0, pct(use180, 0.5) or 0
	print(`[{pol}]`)
	print(
		string.format(
			"  RawHits P50 @90/180 = %.0f / %.0f   UsefulHits P50 @90/180 = %.0f / %.0f  (Δ useful 90→180 = %.0f)",
			r90,
			r180,
			u90,
			u180,
			u180 - u90
		)
	)
	print(
		string.format(
			"  Useful/Raw @180 ≈ %.0f%%   Retargets P50=%.1f   Dry=%.1fm   Pot=×%.2f",
			if r180 > 0 then (u180 / r180) * 100 else 0,
			pct(ret180, 0.5) or 0,
			pct(dry180, 0.5) or 0,
			pct(pot180, 0.5) or 1
		)
	)
end

print("\nPass bar: UsefulHits keep rising for Hunter/Optimized after 90m; AFK Useful≈flat; high Useful/Raw OK (auto useful chase).")
print("=== Done ===")
