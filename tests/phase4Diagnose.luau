-- Phase 4 diagnostic: income units, afford vs rebirth gate, Combined vs NoHUD, drought.
--   lune run tests/phase4Diagnose

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local Rebirth = require("../src/shared/Rebirth")
local Economy = require("../src/shared/Economy")

local LIVE = Config.Rebirth.BaseCost
local SEEDS = 10

local function fmt(n: number?, d: number?): string
	if n == nil then
		return "—"
	end
	return string.format(`%.{d or 1}f`, n)
end

local function pct(arr: { number }, p: number): number?
	table.sort(arr)
	return Unified.percentile(arr, p)
end

local proposalP4 = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = LIVE,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

local proposalNoHud = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = LIVE,
	ScanMax = 12,
	FusionIncome = false,
	BoardGlobalFusion = false,
	FusionMeaningfulEvery = 8,
}

-- Patch-free: wrap run by monkey-instrumenting via a local fork of key metrics
-- using ApproxNotes + Final + custom probe by re-running with Event and reading checkpoints.

type Probe = {
	Seed: number,
	Label: string,
	FirstAffordMin: number?,
	R1Min: number?,
	R2Min: number?,
	R3Min: number?,
	CeAtAfford: number?,
	CeAtR1: number?,
	IncAtAfford: number?,
	IncAtR1: number?,
	IncAfterR1: number?,
	PedMinAtR1: number?,
	CLAtR1: number?,
	EnergyAtR1: number?,
	BoardAt30: number,
	LiftAt30: number,
	FusionsAt60: number,
	RetiresAt60: number,
	DryMin: number,
	UsefulAt15: number,
	UsefulAt45: number,
	UsefulAt60: number,
	CEAt30: number,
	IncAt30: number,
	DupesAt30: number,
	EssenceAt30: number,
}

-- Instrument by editing is heavy; instead run a thin inline sim probe for Afk seeds.
-- We require the library and use RunResult fields after adding afford tracking.
-- If FirstAffordR1At not yet on RunResult, compute from CE trajectory via PerSecond short run.

local function runOne(seed: number, hud: boolean, policy: string): Unified.RunResult
	return Unified.run({
		Seed = seed,
		Minutes = 180,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = hud,
		Proposal = if hud then proposalP4 else proposalNoHud,
		TickMode = "Event",
	})
end

print("=== Phase 4 diagnosis ===")
print(`BaseCost={LIVE} CostGrowth={Config.Rebirth.CostGrowth} IncomeGrowth={Config.Rebirth.IncomeGrowth}`)
print(
	string.format(
		"Ped L25 mult=%.2f  Ped L50 mult=%.2f  (live Economy)",
		Economy.pedestalMultiplier(Config.Economy, 25),
		Economy.pedestalMultiplier(Config.Economy, 50)
	)
)
print(
	string.format(
		"R1/R2/R3 costs: %.0f / %.0f / %.0f",
		Rebirth.cost(Config.Rebirth, 0),
		Rebirth.cost(Config.Rebirth, 1),
		Rebirth.cost(Config.Rebirth, 2)
	)
)

-- Representative single-seed deep dump (seed 1 Afk Combined)
print("\n--- Seed 1 Afk P4_Combined checkpoints ---")
local deep = runOne(1, true, "AfkUpgrader")
for _, cp in deep.Checkpoints do
	if cp.Minute <= 60 or cp.Minute == 90 or cp.Minute == 120 then
		print(
			string.format(
				"  t=%3dm CE=%.3e Inc/s=%.3e CL=%d PedMin=%d Mast=%d Board=%d Lift=×%.2f Useful=%d F=%d R=%d",
				cp.Minute,
				cp.CE,
				cp.IncomePerSec,
				cp.CoreLuck,
				math.min(table.unpack(cp.PedLevels)),
				cp.PedMastery,
				cp.ActiveBoard,
				cp.FusionLift,
				cp.UsefulBuysLeft,
				cp.Fusions,
				cp.Rebirths
			)
		)
	end
end
print(
	string.format(
		"  R1@%s R2@%s R3@%s IncBeforeR1=%s IncAfterR1=%s Dry=%.1fm",
		if deep.FirstRebirthAt then fmt(deep.FirstRebirthAt / 60, 1) else "—",
		if deep.RebirthsAt[2] then fmt(deep.RebirthsAt[2] / 60, 1) else "—",
		if deep.RebirthsAt[3] then fmt(deep.RebirthsAt[3] / 60, 1) else "—",
		fmt(deep.IncomeBeforeR1, 0),
		fmt(deep.IncomeAfterR1, 0),
		deep.Final.LongestDryMin
	)
)

-- Paired seeds Combined vs NoHUD Afk
print("\n--- Paired Afk seeds: Combined vs NoHUD ---")
local cR1, nR1, cR3, nR3, cInc30, nInc30, cCE30, nCE30, cDupes, nDupes = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local cBoard, nBoard, cLift, nLift = {}, {}, {}, {}
for seed = 1, SEEDS do
	local c = runOne(seed, true, "AfkUpgrader")
	local n = runOne(seed, false, "AfkUpgrader")
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
	local c30 = nil
	local n30 = nil
	for _, cp in c.Checkpoints do
		if cp.Minute == 30 then
			c30 = cp
		end
	end
	for _, cp in n.Checkpoints do
		if cp.Minute == 30 then
			n30 = cp
		end
	end
	if c30 then
		table.insert(cInc30, c30.IncomePerSec)
		table.insert(cCE30, c30.CE)
		table.insert(cDupes, c30.Dupes)
		table.insert(cBoard, c30.ActiveBoard)
		table.insert(cLift, c30.FusionLift)
	end
	if n30 then
		table.insert(nInc30, n30.IncomePerSec)
		table.insert(nCE30, n30.CE)
		table.insert(nDupes, n30.Dupes)
		table.insert(nBoard, n30.ActiveBoard)
		table.insert(nLift, n30.FusionLift)
	end
	print(
		string.format(
			"  seed %2d  Comb R1=%sm R3=%sm Inc30=%.2e CE30=%.2e Dupes=%d Board=%d  |  NoHUD R1=%sm R3=%sm Inc30=%.2e CE30=%.2e Dupes=%d",
			seed,
			fmt(if c.FirstRebirthAt then c.FirstRebirthAt / 60 else nil, 0),
			fmt(if c.RebirthsAt[3] then c.RebirthsAt[3] / 60 else nil, 0),
			c30 and c30.IncomePerSec or 0,
			c30 and c30.CE or 0,
			c30 and c30.Dupes or 0,
			c30 and c30.ActiveBoard or 0,
			fmt(if n.FirstRebirthAt then n.FirstRebirthAt / 60 else nil, 0),
			fmt(if n.RebirthsAt[3] then n.RebirthsAt[3] / 60 else nil, 0),
			n30 and n30.IncomePerSec or 0,
			n30 and n30.CE or 0,
			n30 and n30.Dupes or 0
		)
	)
end
print(
	string.format(
		"  P50 Comb R1=%s R3=%s Inc30=%s CE30=%s Board=%s Lift=×%s",
		fmt(pct(cR1, 0.5), 1),
		fmt(pct(cR3, 0.5), 1),
		fmt(pct(cInc30, 0.5), 0),
		fmt(pct(cCE30, 0.5), 0),
		fmt(pct(cBoard, 0.5), 0),
		fmt(pct(cLift, 0.5), 2)
	)
)
print(
	string.format(
		"  P50 NoHUD R1=%s R3=%s Inc30=%s CE30=%s Board=%s Lift=×%s",
		fmt(pct(nR1, 0.5), 1),
		fmt(pct(nR3, 0.5), 1),
		fmt(pct(nInc30, 0.5), 0),
		fmt(pct(nCE30, 0.5), 0),
		fmt(pct(nBoard, 0.5), 0),
		fmt(pct(nLift, 0.5), 2)
	)
)

-- Hunter post-R1 gaps
print("\n--- Hunter P4 post-R1 gaps (10 seeds) ---")
local gaps12, gaps23, buysPost = {}, {}, {}
for seed = 1, SEEDS do
	local r = runOne(seed, true, "Hunter")
	local t1, t2, t3 = r.RebirthsAt[1], r.RebirthsAt[2], r.RebirthsAt[3]
	if t1 and t2 then
		table.insert(gaps12, (t2 - t1) / 60)
	end
	if t2 and t3 then
		table.insert(gaps23, (t3 - t2) / 60)
	end
	-- CL / Mastery at 60m as proxy for post-R1 purchases
	for _, cp in r.Checkpoints do
		if cp.Minute == 60 then
			print(
				string.format(
					"  seed %2d R1=%sm R2=%sm R3=%sm gap12=%.1f gap23=%.1f CL@60=%d Mast@60=%d Useful@60=%d",
					seed,
					fmt(t1 and t1 / 60, 0),
					fmt(t2 and t2 / 60, 0),
					fmt(t3 and t3 / 60, 0),
					t1 and t2 and (t2 - t1) / 60 or -1,
					t2 and t3 and (t3 - t2) / 60 or -1,
					cp.CoreLuck,
					cp.PedMastery,
					cp.UsefulBuysLeft
				)
			)
		end
	end
end
print(string.format("  gap R1→R2 P50=%.1fm  R2→R3 P50=%.1fm", pct(gaps12, 0.5) or -1, pct(gaps23, 0.5) or -1))

-- Afford vs Rebirth gate across Afk Combined seeds
print("\n--- Afford vs Rebirth gate (Afk P4 Combined, 10 seeds) ---")
local afford, r1delta, ceAfford, ceR1, pedR1, clR1, enR1, incR1 = {}, {}, {}, {}, {}, {}, {}, {}
for seed = 1, SEEDS do
	local r = runOne(seed, true, "AfkUpgrader")
	if r.FirstAffordR1At and r.FirstRebirthAt then
		table.insert(afford, r.FirstAffordR1At / 60)
		table.insert(r1delta, (r.FirstRebirthAt - r.FirstAffordR1At) / 60)
		table.insert(ceAfford, r.CeAtFirstAfford or 0)
		table.insert(ceR1, r.CeAtR1 or 0)
		table.insert(pedR1, r.PedMinAtR1 or 0)
		table.insert(clR1, r.CoreLuckAtR1 or 0)
		table.insert(enR1, r.EnergyAtR1 or 0)
		table.insert(incR1, r.IncomeBeforeR1 or 0)
		print(
			string.format(
				"  seed %2d afford=%.1fm R1=%.1fm wait=%.1fm CE@afford=%.2e CE@R1=%.2e Inc/s@R1=%.2e pedMin=%d CL=%d Energy=%d",
				seed,
				r.FirstAffordR1At / 60,
				r.FirstRebirthAt / 60,
				(r.FirstRebirthAt - r.FirstAffordR1At) / 60,
				r.CeAtFirstAfford or 0,
				r.CeAtR1 or 0,
				r.IncomeBeforeR1 or 0,
				r.PedMinAtR1 or 0,
				r.CoreLuckAtR1 or 0,
				r.EnergyAtR1 or 0
			)
		)
	end
end
print(
	string.format(
		"  P50 afford=%sm  R1-wait-after-afford=%sm  CE@R1=%s  Inc/s@R1=%s  pedMin=%s CL=%s Energy=%s",
		fmt(pct(afford, 0.5), 1),
		fmt(pct(r1delta, 0.5), 1),
		fmt(pct(ceR1, 0.5), 0),
		fmt(pct(incR1, 0.5), 0),
		fmt(pct(pedR1, 0.5), 0),
		fmt(pct(clR1, 0.5), 0),
		fmt(pct(enR1, 0.5), 0)
	)
)

print("\nDone.")
