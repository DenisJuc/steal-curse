-- Phase 6 final quality pass — identical seeds/windows to Phase 4.1.
--   lune run tests/phase6QualityPass
-- Seeds 1..40 (not the earlier 6000+i*17 set). Dry@90 vs Dry@180 reported separately.

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local MutationConfig = require("../src/shared/MutationConfig")
local SoftCapRarity = require("./lib/softCapRarity")
local RelicConfig = require("../src/shared/RelicConfig")

local SEEDS = 40
local MINUTES = 180 -- match Phase 4.1 window for DryFinal; Rank2@60 still reported

local proposalP4 = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

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

local function run(seed: number, policy: string)
	return Unified.run({
		Seed = seed,
		Minutes = MINUTES,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposalP4,
		TickMode = "Event",
	})
end

local function commonCount(): number
	local n = 0
	for _, r in RelicConfig.Relics do
		if r.Tier == "Common" then
			n += 1
		end
	end
	return math.max(1, n)
end

print("=== Phase 6 final quality pass ===")
print("Seeds 1..40 (Phase 4.1 set); SoftCap_P4; B+; no odds buffs")
print(`N={SEEDS}; minutes={MINUTES}; Dry@90 vs DryFinal@{MINUTES} reported separately\n`)

print("--- Mutation accessibility (exact Board Common id) ---")
local commons = commonCount()
local mutP1 = MutationConfig.ChanceAt(1)
local bandAfk = SoftCapRarity.softCapBandPercents(10)
local bandHunt = SoftCapRarity.softCapBandPercents(50)
local pCommonAfk = (bandAfk.Common or 0) / 100
local pCommonHunt = (bandHunt.Common or 0) / 100
print(string.format("  Commons=%d  P(mut|Mut1)=%.2f", commons, mutP1))
print(
	string.format(
		"  Common%% AFK≈%.1f  Hunt×5proxy≈%.1f  → E[exact mut rolls] AFK≈%.0f Hunt≈%.0f",
		pCommonAfk * 100,
		pCommonHunt * 100,
		1 / math.max(1e-12, pCommonAfk / commons * mutP1),
		1 / math.max(1e-12, pCommonHunt / commons * mutP1)
	)
)
print("  Hunt Charm: family bias only when Charm=Hunt AND fused relic on pedestal (no same-id guarantee).\n")

print("--- Paired Afk vs Hunter (seeds 1..40) ---")
local policies = { "AfkUpgrader", "Hunter" }
local stats: { [string]: any } = {}
for _, pol in policies do
	stats[pol] = {
		R2 = {},
		R3 = {},
		R3at30 = 0,
		R3at60 = 0,
		R3at90 = 0,
		R2at30 = 0,
		R2at60 = 0,
		R2at90 = 0,
		Lift60 = {},
		Lift90 = {},
		Dry90 = {},
		DryFinal = {},
		BlockMut = 0,
		BlockCopy = 0,
		BlockEss = 0,
		BlockOther = 0,
	}
end

for seed = 1, SEEDS do
	for _, pol in policies do
		local r = run(seed, pol)
		local s = stats[pol]
		if r.FirstRank2At then
			table.insert(s.R2, r.FirstRank2At / 60)
			if r.FirstRank2At <= 30 * 60 then
				s.R2at30 += 1
			end
			if r.FirstRank2At <= 60 * 60 then
				s.R2at60 += 1
			end
			if r.FirstRank2At <= 90 * 60 then
				s.R2at90 += 1
			end
		end
		if r.FirstRank3At then
			table.insert(s.R3, r.FirstRank3At / 60)
			if r.FirstRank3At <= 30 * 60 then
				s.R3at30 += 1
			end
			if r.FirstRank3At <= 60 * 60 then
				s.R3at60 += 1
			end
			if r.FirstRank3At <= 90 * 60 then
				s.R3at90 += 1
			end
		end
		for _, cp in r.Checkpoints do
			if cp.Minute == 60 then
				table.insert(s.Lift60, cp.FusionLift or 1)
			elseif cp.Minute == 90 then
				table.insert(s.Lift90, cp.FusionLift or 1)
				table.insert(s.Dry90, cp.LongestDryMin or 0)
			end
		end
		table.insert(s.DryFinal, r.Final.LongestDryMin or 0)
		if r.Rank3Blockers then
			s.BlockMut += r.Rank3Blockers.Mutation or 0
			s.BlockCopy += r.Rank3Blockers.Copies or 0
			s.BlockEss += r.Rank3Blockers.Essence or 0
			s.BlockOther += r.Rank3Blockers.Other or 0
		end
	end
	if seed % 10 == 0 then
		print(string.format("  … %d/%d seeds", seed, SEEDS))
	end
end

for _, pol in policies do
	local s = stats[pol]
	local blockSum = s.BlockMut + s.BlockCopy + s.BlockEss + s.BlockOther
	print(string.format("\n[%s]", pol))
	print(
		string.format(
			"  Rank2 by 30/60/90: %.0f%% / %.0f%% / %.0f%%   P50=%sm",
			100 * s.R2at30 / SEEDS,
			100 * s.R2at60 / SEEDS,
			100 * s.R2at90 / SEEDS,
			fmt(pct(s.R2, 0.5))
		)
	)
	print(
		string.format(
			"  Rank3 by 30/60/90: %.0f%% / %.0f%% / %.0f%%   P50=%sm mean=%sm",
			100 * s.R3at30 / SEEDS,
			100 * s.R3at60 / SEEDS,
			100 * s.R3at90 / SEEDS,
			fmt(pct(s.R3, 0.5)),
			fmt(mean(s.R3))
		)
	)
	print(
		string.format(
			"  Lift@60/90 P50 = ×%s / ×%s",
			fmt(pct(s.Lift60, 0.5), 2),
			fmt(pct(s.Lift90, 0.5), 2)
		)
	)
	print(
		string.format(
			"  Dry@90 P50/P90 = %s / %s min   DryFinal@%dm P50/P90 = %s / %s min",
			fmt(pct(s.Dry90, 0.5)),
			fmt(pct(s.Dry90, 0.9)),
			MINUTES,
			fmt(pct(s.DryFinal, 0.5)),
			fmt(pct(s.DryFinal, 0.9))
		)
	)
	if blockSum > 0 then
		print(
			string.format(
				"  Rank3 blockers: Mutation=%.0f%% Copies=%.0f%% Essence=%.0f%% Other=%.0f%% (n=%d)",
				100 * s.BlockMut / blockSum,
				100 * s.BlockCopy / blockSum,
				100 * s.BlockEss / blockSum,
				100 * s.BlockOther / blockSum,
				blockSum
			)
		)
	end
end

print("\n=== Done (Phase 6 finalized; Studio /p6smoke still manual) ===")
