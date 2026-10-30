-- Phase 7 Charm Lineage Ascension diagnose (post Board Lift ×1.50).
--   lune run tests/phase7AscendDiagnose

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")

local SEEDS = 10
local POLICIES = { "AfkUpgrader", "Casual", "Hunter", "Optimized" }
local CUTS = { 30, 45, 60, 90, 120, 180 }

local proposal = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

local function pct(arr: { number }, p: number): number?
	if #arr == 0 then
		return nil
	end
	local c = table.clone(arr)
	table.sort(c)
	return Unified.percentile(c, p)
end

local function fmt(n: number?, d: number?): string
	if n == nil then
		return "—"
	end
	return string.format(`%.{d or 1}f`, n)
end

print("=== Phase 7 Charm Ascension diagnose (N=10, SoftCap_P4) ===\n")

for _, pol in POLICIES do
	local ascendAt, ascendN, pot60, pot90, pot180, lift60, retires60 = {}, {}, {}, {}, {}, {}, {}
	local dry = {}
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
		if r.FirstCharmAscendAt then
			table.insert(ascendAt, r.FirstCharmAscendAt / 60)
		end
		table.insert(ascendN, r.CharmAscensions or 0)
		table.insert(dry, r.Final.LongestDryMin)
		for _, cp in r.Checkpoints do
			if cp.Minute == 60 then
				table.insert(pot60, cp.BestCharmPotency or 1)
				table.insert(lift60, cp.FusionLift or 1)
				table.insert(retires60, cp.BoardRetires or 0)
			elseif cp.Minute == 90 then
				table.insert(pot90, cp.BestCharmPotency or 1)
			elseif cp.Minute == 180 then
				table.insert(pot180, cp.BestCharmPotency or 1)
			end
		end
	end
	local hit = #ascendAt
	print(`[{pol}]`)
	print(
		string.format(
			"  Ascend hit=%d/%d  FirstAscend P50=%sm  Ascensions@180 P50=%.1f",
			hit,
			SEEDS,
			fmt(pct(ascendAt, 0.5), 1),
			pct(ascendN, 0.5) or 0
		)
	)
	print(
		string.format(
			"  BestCharmPotency P50 @60/90/180 = ×%.2f / ×%.2f / ×%.2f  Lift@60=×%.2f  Retires@60 P50=%.0f  Dry180=%sm",
			pct(pot60, 0.5) or 1,
			pct(pot90, 0.5) or 1,
			pct(pot180, 0.5) or 1,
			pct(lift60, 0.5) or 1,
			pct(retires60, 0.5) or 0,
			fmt(pct(dry, 0.5), 1)
		)
	)
	-- Seed 1 timeline
	local s1 = Unified.run({
		Seed = 1,
		Minutes = 180,
		Policy = pol :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposal,
		TickMode = "Event",
	})
	local parts = {}
	for _, m in CUTS do
		for _, cp in s1.Checkpoints do
			if cp.Minute == m then
				table.insert(
					parts,
					string.format(
						"%dm:pot×%.2f asc=%d R=%d",
						m,
						cp.BestCharmPotency or 1,
						cp.CharmAscensions or 0,
						cp.Rebirths
					)
				)
			end
		end
	end
	print(`  seed1: {table.concat(parts, " · ")}`)
	print(
		string.format(
			"  seed1 FirstAscend=%s Ascensions=%d",
			if s1.FirstCharmAscendAt then fmt(s1.FirstCharmAscendAt / 60, 1) .. "m" else "—",
			s1.CharmAscensions or 0
		)
	)
	print("")
end

print("=== Done ===")
