-- Midgame Board / empty-shop diagnose (SoftCap_P4).
--   lune run tests/midgameBoardDiagnose

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")

local SEEDS = 20
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

local function run(seed: number, policy: string)
	return Unified.run({
		Seed = seed,
		Minutes = 90,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposal,
		TickMode = "Event",
	})
end

print("=== Midgame Board / shop diagnose (N=20, seeds 1..20) ===\n")

for _, pol in { "AfkUpgrader", "Hunter" } do
	local golden, board2 = {}, {}
	local slots15, slots30, slots45, slots60 = {}, {}, {}, {}
	local occ15, occ30, occ45, occ60 = {}, {}, {}, {}
	local useful15, useful30, useful45, useful60 = {}, {}, {}, {}
	local gap15_30, gap30_45, gap45_60 = {}, {}, {}
	local underfill = 0 -- slots>=2 but occ<2 at 30
	local goldenHit = 0

	for seed = 1, SEEDS do
		local r = run(seed, pol)
		if r.FirstGoldenAt then
			goldenHit += 1
			table.insert(golden, r.FirstGoldenAt / 60)
		end
		if r.Board2At then
			table.insert(board2, r.Board2At / 60)
		end
		local lastMeaningful = 0
		-- Reconstruct gaps from checkpoints only (proxy): use LongestDry at each cut — insufficient.
		-- Use UsefulLeft + Board from checkpoints.
		for _, cp in r.Checkpoints do
			if cp.Minute == 15 then
				table.insert(slots15, cp.BoardSlots or 0)
				table.insert(occ15, cp.ActiveBoard or 0)
				table.insert(useful15, cp.UsefulBuysLeft or 0)
			elseif cp.Minute == 30 then
				table.insert(slots30, cp.BoardSlots or 0)
				table.insert(occ30, cp.ActiveBoard or 0)
				table.insert(useful30, cp.UsefulBuysLeft or 0)
				if (cp.BoardSlots or 0) >= 2 and (cp.ActiveBoard or 0) < 2 then
					underfill += 1
				end
			elseif cp.Minute == 45 then
				table.insert(slots45, cp.BoardSlots or 0)
				table.insert(occ45, cp.ActiveBoard or 0)
				table.insert(useful45, cp.UsefulBuysLeft or 0)
			elseif cp.Minute == 60 then
				table.insert(slots60, cp.BoardSlots or 0)
				table.insert(occ60, cp.ActiveBoard or 0)
				table.insert(useful60, cp.UsefulBuysLeft or 0)
			end
		end
	end

	print(string.format("[%s]", pol))
	print(
		string.format(
			"  FirstGolden hit=%d/%d P50=%sm   Board2At P50=%sm",
			goldenHit,
			SEEDS,
			fmt(pct(golden, 0.5)),
			fmt(pct(board2, 0.5))
		)
	)
	print(
		string.format(
			"  BoardSlots P50 @15/30/45/60 = %s / %s / %s / %s",
			fmt(pct(slots15, 0.5), 0),
			fmt(pct(slots30, 0.5), 0),
			fmt(pct(slots45, 0.5), 0),
			fmt(pct(slots60, 0.5), 0)
		)
	)
	print(
		string.format(
			"  ActiveBoard P50 @15/30/45/60 = %s / %s / %s / %s",
			fmt(pct(occ15, 0.5), 0),
			fmt(pct(occ30, 0.5), 0),
			fmt(pct(occ45, 0.5), 0),
			fmt(pct(occ60, 0.5), 0)
		)
	)
	print(
		string.format(
			"  UsefulLeft P50 @15/30/45/60 = %s / %s / %s / %s",
			fmt(pct(useful15, 0.5), 0),
			fmt(pct(useful30, 0.5), 0),
			fmt(pct(useful45, 0.5), 0),
			fmt(pct(useful60, 0.5), 0)
		)
	)
	print(string.format("  Underfill (slots≥2, occ<2 @30): %d/%d", underfill, SEEDS))
	print()
end

print("Hypothesis: pickFuseTarget boardTight blocks 2nd slot unless relic is on pedestal.")
print("=== Done ===")
