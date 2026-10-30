-- Playtest-calibrated 35:51 session simulator (SoftCap vs Soft A+C).
-- ScanSpeed / CoreLuck / MutRes / Frequency timelines follow pt_153530464_36f8c545.
-- Does not retune SoftCap R/M, upgrade prices, or Rebirth rules.

local Config = require("../../src/shared/Config")
local Formulas = require("../../src/shared/Formulas")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local SkillConfig = require("../../src/shared/SkillConfig")
local SoftCapRarity = require("./softCapRarity")
local relicIncome = require("./relicIncome")

local Sim = {}

export type Sampler = "SoftCap" | "SoftAC"

export type RunResult = {
	Sampler: Sampler,
	Seed: number,
	DurationSec: number,
	TotalRolls: number,
	ScanRolls: number,
	HuntRolls: number,
	ByTier: { [string]: number },
	Unique: number,
	UniqueByTier: { [string]: number },
	Dupes: number,
	Mutations: number,
	-- Desirable: new Unique Rare+, new Unique Epic+, first-of-tier (not every mutation)
	DesirableEvents: number,
	AvgDesirableGapRolls: number,
	AvgDesirableGapSec: number,
	EpicExact: number,
	EpicPlus: number,
	UniqueEpic: number,
	Essence: number,
	IncomePerSecEnd: number,
	LuckEnd: number,
	ScanRankEnd: number,
	CoreLuckEnd: number,
	UniqueAt: { [number]: number }, -- minute -> unique
	RarePctEnd: number,
	CommonUncommonPct: number,
	-- Legacy-style "valuable" (new Rare+ unique OR any Epic+) for gap explanation
	LegacyValuableAvgGapRolls: number,
}

local DURATION = 2151 -- 35:51
local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }

-- From PLAYTEST_PURCHASES.csv (pt_153530464_36f8c545). Rank after each buy at elapsed sec.
local SCAN_PATH = {
	{ Sec = 0, Rank = 0 },
	{ Sec = 218, Rank = 1 },
	{ Sec = 219, Rank = 2 },
	{ Sec = 220, Rank = 6 },
	{ Sec = 435, Rank = 7 },
	{ Sec = 589, Rank = 8 },
	{ Sec = 590, Rank = 10 },
	{ Sec = 761, Rank = 11 },
	{ Sec = 989, Rank = 12 },
}

local CORE_PATH = {
	{ Sec = 0, Rank = 0 },
	{ Sec = 35, Rank = 1 },
	{ Sec = 36, Rank = 6 },
	{ Sec = 116, Rank = 12 },
	{ Sec = 332, Rank = 14 },
	{ Sec = 502, Rank = 15 },
	{ Sec = 698, Rank = 16 },
	{ Sec = 867, Rank = 17 },
	{ Sec = 1144, Rank = 18 },
	{ Sec = 1511, Rank = 20 },
	{ Sec = 1738, Rank = 21 },
}

local MUT_PATH = {
	{ Sec = 0, Rank = 0 },
	{ Sec = 733, Rank = 1 },
	{ Sec = 2047, Rank = 2 },
}

local FREQ_PATH = {
	{ Sec = 0, Rank = 0 },
	{ Sec = 1049, Rank = 1 },
	{ Sec = 1050, Rank = 2 },
	{ Sec = 1052, Rank = 3 },
	{ Sec = 1198, Rank = 4 },
	{ Sec = 2040, Rank = 5 },
}

local frozenBase: { [string]: number } = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local softACRules: RollMath.Rules = (function()
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = 20000
		elseif tier.Id == "Legendary" then
			denom = 500000
		end
		table.insert(tiers, { Id = tier.Id, Denominator = denom })
	end
	return {
		Tiers = tiers,
		ByTier = RollMath.groupByTier(RelicConfig.Relics),
		Mutations = MutationConfig.Mutations,
		MutationChanceByRank = MutationConfig.ChanceByRank,
		FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
		FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
	}
end)()

local function mulberry32(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function rankAt(path: { { Sec: number, Rank: number } }, sec: number): number
	local rank = path[1].Rank
	for _, row in path do
		if sec >= row.Sec then
			rank = row.Rank
		else
			break
		end
	end
	return rank
end

local function tierI(tierId: string): number
	return RarityConfig.IndexById[tierId] or 0
end

local function mean(arr: { number }): number
	if #arr == 0 then
		return 0
	end
	local s = 0
	for _, v in arr do
		s += v
	end
	return s / #arr
end

function Sim.percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	local idx = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[idx]
end

function Sim.run(options: { Seed: number, Sampler: Sampler, DurationSec: number? }): RunResult
	local duration = options.DurationSec or DURATION
	local sampler = options.Sampler
	local rng = mulberry32(options.Seed * 9973 + 41)

	local byTier: { [string]: number } = {}
	for _, t in TIER_ORDER do
		byTier[t] = 0
	end
	local uniqueByTier: { [string]: number } = {}
	local seen: { [string]: boolean } = {}
	local seenEpic: { [string]: boolean } = {}
	local firstTier: { [string]: boolean } = {}
	local uniqueCount = 0
	local dupes = 0
	local mutations = 0
	local epicExact = 0
	local epicPlus = 0
	local uniqueEpic = 0
	local essence = 0
	local totalRolls = 0
	local scanRolls = 0
	local huntRolls = 0
	local uniqueAt: { [number]: number } = {}
	local heldIncome = { 0, 0, 0, 0, 0, 0 } -- 6 pedestals, income rates
	local slots = 3

	local desirableGapsRolls: { number } = {}
	local desirableGapsSec: { number } = {}
	local lastDesirableRoll = 0
	local lastDesirableSec = 0
	local desirableEvents = 0

	local legacyGaps: { number } = {}
	local lastLegacyRoll = 0

	local function fullLuck(sec: number): number
		local cl = rankAt(CORE_PATH, sec)
		-- Soft A+C CoreLuck ÷12; extras ≈ Codex/Showcase so end Luck≈145 at CL21.
		local base = Formulas.coreLuck(cl, 12)
		local extras = 1.55 + 1.0 * math.min(1, uniqueCount / 52)
		return base * extras
	end

	-- Playtest ScanAgg shows a Common burst 15:51–16:30 (Rarity Focus Common while already at ~1s scan).
	local function rarityFocus(sec: number): string?
		if sec >= 951 and sec <= 990 then
			return "Common"
		end
		return nil
	end

	local function luck(sec: number): number
		local L = fullLuck(sec)
		local focus = rarityFocus(sec)
		if not focus then
			return L
		end
		local denom = nil
		for _, tier in softACRules.Tiers do
			if tier.Id == focus then
				denom = tier.Denominator
			end
		end
		return RollMath.effectiveLuck(L, denom, softACRules.FocusTierOrHigherChance)
	end

	local function incomePerSec(): number
		local sum = 0
		for i = 1, slots do
			sum += heldIncome[i] or 0
		end
		return sum * (1 + 0.02 * 12) -- ~Energy mid-session approx
	end

	local function noteDesirable(rollI: number, sec: number)
		desirableEvents += 1
		if lastDesirableRoll > 0 then
			table.insert(desirableGapsRolls, rollI - lastDesirableRoll)
			table.insert(desirableGapsSec, sec - lastDesirableSec)
		end
		lastDesirableRoll = rollI
		lastDesirableSec = sec
	end

	local function noteLegacy(rollI: number)
		if lastLegacyRoll > 0 then
			table.insert(legacyGaps, rollI - lastLegacyRoll)
		end
		lastLegacyRoll = rollI
	end

	local function rollOne(sec: number, hunt: boolean)
		local L = luck(sec)
		local freq = rankAt(FREQ_PATH, sec)
		local mutRank = rankAt(MUT_PATH, sec)
		local family = if hunt and freq > 0 then "Demonic" else nil
		local famMult = if family then (Config.Frequency.MultiplierByRank[freq] or 1.5) else nil
		if hunt then
			L *= 5
		end
		local relicId, tierId, mut
		if sampler == "SoftCap" then
			relicId, tierId = SoftCapRarity.roll(L, rng, family, famMult)
			mut = SoftCapRarity.rollMutation(mutRank, rng)
		else
			local ctx = RollMath.contextFor(softACRules, {
				FullLuck = L,
				Frequency = family,
				FrequencyRank = freq,
				MutationRank = mutRank,
				Sampler = "Ladder",
			})
			local relic, rolledMut = RollMath.roll(ctx, rng)
			relicId, tierId, mut = relic.Id, relic.Tier, rolledMut
		end
		totalRolls += 1
		if hunt then
			huntRolls += 1
		else
			scanRolls += 1
		end
		local rollI = totalRolls
		byTier[tierId] = (byTier[tierId] or 0) + 1
		local ti = tierI(tierId)
		local first = not seen[relicId]
		if first then
			seen[relicId] = true
			uniqueCount += 1
			uniqueByTier[tierId] = (uniqueByTier[tierId] or 0) + 1
		else
			dupes += 1
			if ti <= tierI("Rare") then
				essence += 1 + (if mut then 1 else 0)
			end
		end
		if mut then
			mutations += 1
		end
		if ti == tierI("Epic") then
			epicExact += 1
		end
		if ti >= tierI("Epic") then
			epicPlus += 1
			if not seenEpic[relicId] then
				seenEpic[relicId] = true
				uniqueEpic += 1
			end
		end

		-- Desirable: new Index Rare+, new Unique Epic+, or first-ever of a tier.
		-- Mutations alone do NOT count (spice, not milestones).
		local desirable = false
		if first and ti >= tierI("Rare") then
			desirable = true
		end
		if first and ti >= tierI("Epic") then
			desirable = true
		end
		if not firstTier[tierId] then
			firstTier[tierId] = true
			desirable = true
		end
		if desirable then
			noteDesirable(rollI, sec)
		end

		-- Legacy Phase-2-report metric (misleading): new Rare+ OR any Epic+ drop
		if (first and ti >= tierI("Rare")) or ti >= tierI("Epic") then
			noteLegacy(rollI)
		end

		local mult = if mut then 1.5 else 1
		local inc = (frozenBase[relicId] or 1) * mult
		local worstI, worstV = 1, heldIncome[1] or 0
		for i = 1, slots do
			local v = heldIncome[i] or 0
			if v < worstV then
				worstV, worstI = v, i
			end
		end
		if inc > worstV then
			heldIncome[worstI] = inc
		end
		-- Slot unlocks roughly like playtest (~2–8 min)
		if sec > 140 and slots < 4 then
			slots = 4
		end
		if sec > 400 and slots < 5 then
			slots = 5
		end
		if sec > 700 and slots < 6 then
			slots = 6
		end
	end

	local scanTimer = 0
	local huntTimer = 0
	-- 26 captures / 2151s ≈ every 82.7s
	local HUNT_EVERY = 83
	local lastMinute = -1

	for sec = 1, duration do
		local scanRank = rankAt(SCAN_PATH, sec)
		local interval = SkillConfig.scanInterval(scanRank)
		-- 1.074× matches playtest 1879 scans vs closed-form 1750 from the purchase timeline
		-- (discrete Studio tick / charge timing; not a SoftCap retune).
		scanTimer += 1.074
		while scanTimer + 1e-9 >= interval do
			scanTimer -= interval
			rollOne(sec, false)
		end
		huntTimer += 1
		if huntTimer >= HUNT_EVERY then
			huntTimer = 0
			-- Trial MaxBonusRolls=6 → up to 7 total; playtest-ish average ~4 bonus + capture
			local bonus = 1 + math.min(6, 2 + math.floor(4 * (1 - interval / 4)))
			for _ = 1, bonus do
				rollOne(sec, true)
			end
		end
		local minute = sec // 60
		if minute ~= lastMinute and minute > 0 then
			uniqueAt[minute] = uniqueCount
			lastMinute = minute
		end
	end
	uniqueAt[duration // 60] = uniqueCount

	local rarePct = if totalRolls > 0 then 100 * (byTier.Rare or 0) / totalRolls else 0
	local cuPct = if totalRolls > 0 then 100 * ((byTier.Common or 0) + (byTier.Uncommon or 0)) / totalRolls else 0

	return {
		Sampler = sampler,
		Seed = options.Seed,
		DurationSec = duration,
		TotalRolls = totalRolls,
		ScanRolls = scanRolls,
		HuntRolls = huntRolls,
		ByTier = byTier,
		Unique = uniqueCount,
		UniqueByTier = uniqueByTier,
		Dupes = dupes,
		Mutations = mutations,
		DesirableEvents = desirableEvents,
		AvgDesirableGapRolls = mean(desirableGapsRolls),
		AvgDesirableGapSec = mean(desirableGapsSec),
		EpicExact = epicExact,
		EpicPlus = epicPlus,
		UniqueEpic = uniqueEpic,
		Essence = essence,
		IncomePerSecEnd = incomePerSec(),
		LuckEnd = luck(duration),
		ScanRankEnd = rankAt(SCAN_PATH, duration),
		CoreLuckEnd = rankAt(CORE_PATH, duration),
		UniqueAt = uniqueAt,
		RarePctEnd = rarePct,
		CommonUncommonPct = cuPct,
		LegacyValuableAvgGapRolls = mean(legacyGaps),
	}
end

function Sim.aggregate(results: { RunResult }): { [string]: { P10: number, P50: number, P90: number, Mean: number } }
	local keys = {
		"TotalRolls",
		"ScanRolls",
		"HuntRolls",
		"Unique",
		"Dupes",
		"Mutations",
		"DesirableEvents",
		"AvgDesirableGapRolls",
		"AvgDesirableGapSec",
		"EpicExact",
		"EpicPlus",
		"UniqueEpic",
		"Essence",
		"IncomePerSecEnd",
		"LuckEnd",
		"RarePctEnd",
		"CommonUncommonPct",
		"LegacyValuableAvgGapRolls",
		"UniqueAt15",
		"UniqueAt30",
		"UniqueAt35",
		"Common",
		"Uncommon",
		"Rare",
		"Epic",
	}
	local buckets: { [string]: { number } } = {}
	for _, k in keys do
		buckets[k] = {}
	end
	for _, r in results do
		table.insert(buckets.TotalRolls, r.TotalRolls)
		table.insert(buckets.ScanRolls, r.ScanRolls)
		table.insert(buckets.HuntRolls, r.HuntRolls)
		table.insert(buckets.Unique, r.Unique)
		table.insert(buckets.Dupes, r.Dupes)
		table.insert(buckets.Mutations, r.Mutations)
		table.insert(buckets.DesirableEvents, r.DesirableEvents)
		table.insert(buckets.AvgDesirableGapRolls, r.AvgDesirableGapRolls)
		table.insert(buckets.AvgDesirableGapSec, r.AvgDesirableGapSec)
		table.insert(buckets.EpicExact, r.EpicExact)
		table.insert(buckets.EpicPlus, r.EpicPlus)
		table.insert(buckets.UniqueEpic, r.UniqueEpic)
		table.insert(buckets.Essence, r.Essence)
		table.insert(buckets.IncomePerSecEnd, r.IncomePerSecEnd)
		table.insert(buckets.LuckEnd, r.LuckEnd)
		table.insert(buckets.RarePctEnd, r.RarePctEnd)
		table.insert(buckets.CommonUncommonPct, r.CommonUncommonPct)
		table.insert(buckets.LegacyValuableAvgGapRolls, r.LegacyValuableAvgGapRolls)
		table.insert(buckets.UniqueAt15, r.UniqueAt[15] or r.Unique)
		table.insert(buckets.UniqueAt30, r.UniqueAt[30] or r.Unique)
		table.insert(buckets.UniqueAt35, r.UniqueAt[35] or r.Unique)
		table.insert(buckets.Common, r.ByTier.Common or 0)
		table.insert(buckets.Uncommon, r.ByTier.Uncommon or 0)
		table.insert(buckets.Rare, r.ByTier.Rare or 0)
		table.insert(buckets.Epic, r.ByTier.Epic or 0)
	end
	local out = {}
	for _, k in keys do
		local arr = buckets[k]
		table.sort(arr)
		local s = 0
		for _, v in arr do
			s += v
		end
		out[k] = {
			P10 = Sim.percentile(arr, 0.10),
			P50 = Sim.percentile(arr, 0.50),
			P90 = Sim.percentile(arr, 0.90),
			Mean = if #arr > 0 then s / #arr else 0,
		}
	end
	return out
end

return Sim
