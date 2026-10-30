-- Finalize 0–180 SoftCap_P4 integrated playtest (all four policies).
--   lune run tests/phase180FinalizeGate

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local BalanceTrials = require("../src/shared/BalanceTrials")

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

print("=== SoftCap_P4 0–180 finalize gate (N=8) ===\n")
print(
	string.format(
		"Isolation check: BaseCost=%.0f (live 400M) | StudioTrial=%s | AllowNonStudio=%s",
		Config.Rebirth.BaseCost,
		BalanceTrials.StudioTrialId,
		tostring(BalanceTrials.AllowNonStudioActive)
	)
)
assert(Config.Rebirth.BaseCost == 4e8, "BaseCost must stay 400M")
assert(BalanceTrials.StudioTrialId == "SoftCap_P4", "Studio trial SoftCap_P4")
assert(BalanceTrials.AllowNonStudioActive == false, "production isolation: AllowNonStudioActive off")
print("")

for _, pol in { "AfkUpgrader", "Casual", "Hunter", "Optimized" } do
	local by = {
		[30] = { U = {}, R = {}, Uniq = {}, Reb = {} },
		[60] = { U = {}, R = {}, Uniq = {}, Reb = {} },
		[90] = { U = {}, R = {}, Uniq = {}, Reb = {} },
		[120] = { U = {}, R = {}, Uniq = {}, Reb = {} },
		[150] = { U = {}, R = {}, Uniq = {}, Reb = {} },
		[180] = { U = {}, R = {}, Uniq = {}, Reb = {}, Dry = {}, Pot = {}, Ret = {} },
	}
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
		local map = {}
		for _, cp in r.Checkpoints do
			map[cp.Minute] = cp
		end
		for _, m in { 30, 60, 90, 120, 150, 180 } do
			local cp = map[m]
			if cp and by[m] then
				table.insert(by[m].U, cp.HuntQuarryUsefulHits or 0)
				table.insert(by[m].R, cp.HuntQuarryHits or 0)
				table.insert(by[m].Uniq, cp.Unique or 0)
				table.insert(by[m].Reb, cp.Rebirths or 0)
				if m == 180 then
					table.insert(by[m].Dry, cp.LongestDryMin or 0)
					table.insert(by[m].Pot, cp.BestCharmPotency or 1)
					table.insert(by[m].Ret, cp.HuntQuarryRetargets or 0)
				end
			end
		end
	end
	local function p50(a)
		return pct(a, 0.5) or 0
	end
	print(`[{pol}]`)
	print(
		string.format(
			"  UsefulHits @30/60/90/120/150/180 = %.0f / %.0f / %.0f / %.0f / %.0f / %.0f",
			p50(by[30].U),
			p50(by[60].U),
			p50(by[90].U),
			p50(by[120].U),
			p50(by[150].U),
			p50(by[180].U)
		)
	)
	print(
		string.format(
			"  Unique @60/90/180 = %.0f / %.0f / %.0f   Rebirths @90→180 = %.1f → %.1f",
			p50(by[60].Uniq),
			p50(by[90].Uniq),
			p50(by[180].Uniq),
			p50(by[90].Reb),
			p50(by[180].Reb)
		)
	)
	local u180, r180 = p50(by[180].U), p50(by[180].R)
	print(
		string.format(
			"  Useful/Raw @180 ≈ %.0f%%   Retargets=%.1f   Dry=%.1fm   Pot=×%.2f",
			if r180 > 0 then (u180 / r180) * 100 else 0,
			p50(by[180].Ret),
			p50(by[180].Dry),
			p50(by[180].Pot)
		)
	)
end

print("\nUsefulHits = quarryCaptureAdvances only (Discover / mut hit / stockpile Missing>0).")
print("=== Done ===")
