-- Phase 0 progression sweep simulator. Does NOT mutate live Config defaults.
-- Frozen baseline incomes: each relic keeps its current CE/sec (from live odds at luck 1)
-- even when a candidate changes rarity denominators.
--
-- Behaviours:
--   passive  — auto-scan only; no CE spending
--   upgrader — auto-scan + buy cheapest upgrades + rebirth (playtest-like)
--   hunter   — upgrader + bind captures on a simplified signal schedule

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local Formulas = require("../../src/shared/Formulas")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local SkillConfig = require("../../src/shared/SkillConfig")
local relicIncome = require("./relicIncome")
local liveRules = require("./rules")

local ProgressionSweep = {}

export type HuntTune = {
	BonusFloor: number,
	BonusFactor: number,
	ReferenceScanSeconds: number?,
	HuntLuckFactor: number,
	MaxBonusRolls: number?,
	CaptureCycleSeconds: number,
}

export type Candidate = {
	Id: string,
	Label: string,
	EpicDenom: number,
	LegendaryDenom: number,
	LuckDivisor: number,
	LuckCostGrowth: number,
	LuckCostBase: number,
	Hunt: HuntTune,
}

export type Behaviour = "passive" | "upgrader" | "hunter"

export type Saturation = {
	Minute: number,
	EpicTotal: number,
	EpicUnique: number,
	LegendaryTotal: number,
	LegendaryUnique: number,
	UniqueRelics: number,
	DuplicatesKeptOrSold: number,
	BestTier: string,
	Luck: number,
	IncomePerSec: number,
	Rebirths: number,
	CoreLuckRank: number,
	ScanSeconds: number,
	Slots: number,
	LifetimeCE: number,
}

export type RunResult = {
	FirstRareAt: number?,
	FirstEpicAt: number?,
	FirstLegendaryAt: number?,
	FirstMythicAt: number?,
	FirstRebirthAt: number?,
	RebirthsAt: { number },
	Saturations: { Saturation },
	SignificantGaps: { number },
	RoutinePurchaseCount: number,
	SignificantEventCount: number,
	LifetimeCE: number,
	SoldCE: number,
	FinalLuck: number,
	FinalIncome: number,
	FinalRebirths: number,
	FinalUnique: number,
	FinalBestTier: string,
}

local frozenBase: { [string]: number } = {}
do
	for _, relic in RelicConfig.Relics do
		frozenBase[relic.Id] = relicIncome.base(relic.Id)
	end
end

function ProgressionSweep.frozenBase(relicId: string): number
	return frozenBase[relicId] or 0
end

function ProgressionSweep.baselineCandidate(): Candidate
	return {
		Id = "baseline",
		Label = "Live baseline (unchanged)",
		EpicDenom = 500,
		LegendaryDenom = 25000,
		LuckDivisor = 10,
		LuckCostGrowth = 1.6,
		LuckCostBase = 100,
		Hunt = {
			BonusFloor = Config.Hunt.BonusFloor,
			BonusFactor = Config.Hunt.BonusFactor,
			ReferenceScanSeconds = nil,
			HuntLuckFactor = 1,
			MaxBonusRolls = nil,
			CaptureCycleSeconds = 12,
		},
	}
end

local function makeTiers(epicDenom: number, legendaryDenom: number): { RollMath.Tier }
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = epicDenom
		elseif tier.Id == "Legendary" then
			denom = legendaryDenom
		end
		table.insert(tiers, { Id = tier.Id, Denominator = denom })
	end
	return tiers
end

local function makeRules(candidate: Candidate): RollMath.Rules
	return {
		Tiers = makeTiers(candidate.EpicDenom, candidate.LegendaryDenom),
		ByTier = RollMath.groupByTier(RelicConfig.Relics),
		Mutations = MutationConfig.Mutations,
		MutationChanceByRank = MutationConfig.ChanceByRank,
		FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
		FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
	}
end

local function coreLuck(rank: number, divisor: number): number
	return 10 ^ (rank / divisor)
end

local function coreLuckCost(rank: number, base: number, growth: number): number
	return math.ceil(base * growth ^ rank - 1e-9)
end

local function bonusRolls(scanForBonus: number, hunt: HuntTune): number
	local b = Formulas.bonusRolls(scanForBonus, Config.Signals.RegenSeconds, {
		BonusFloor = hunt.BonusFloor,
		BonusFactor = hunt.BonusFactor,
	})
	if hunt.MaxBonusRolls then
		b = math.min(b, hunt.MaxBonusRolls)
	end
	return b
end

local SELL_MAX_TIER = RarityConfig.IndexById.Rare
local EPIC_I = RarityConfig.IndexById.Epic
local LEG_I = RarityConfig.IndexById.Legendary
local MYTHIC_I = RarityConfig.IndexById.Mythic
local RARE_I = RarityConfig.IndexById.Rare

function ProgressionSweep.run(options: {
	Seed: number,
	Hours: number,
	Behaviour: Behaviour,
	Candidate: Candidate,
	Checkpoints: { number }?,
	SaveSeconds: number?,
}): RunResult
	local settings = Config.Economy
	local rebirthSettings = Config.Rebirth
	local candidate = options.Candidate
	local rules = makeRules(candidate)
	local hunt = candidate.Hunt
	local behaviour = options.Behaviour
	local buy = behaviour ~= "passive"
	local hunting = behaviour == "hunter"
	local doRebirth = buy
	local saveSeconds = options.SaveSeconds or 600
	local checkpoints = options.Checkpoints or { 15, 30, 60, 120 }
	local nodes = SkillConfig.ById

	local rngState = (options.Seed * 7919 + 12345) % 2147483647
	local function nextNumber(): number
		rngState = (rngState * 48271) % 2147483647
		return rngState / 2147483647
	end

	local ce, lifetime, soldCE = 0, 0, 0
	local rebirths = 0
	local skills = { CoreLuck = 0, ScanSpeed = 0, EnergyConduction = 0 }
	local levels: { number } = {}
	for _ = 1, Config.Plots.StartingPedestals do
		table.insert(levels, 1)
	end
	local held: { number } = {}
	local seen: { [string]: boolean } = {}
	local epicUnique: { [string]: boolean } = {}
	local legUnique: { [string]: boolean } = {}
	local epicTotal, legTotal = 0, 0
	local duplicates = 0
	local bestTier = 1
	local uniqueCount = 0

	local firstRare: number? = nil
	local firstEpic: number? = nil
	local firstLegendary: number? = nil
	local firstMythic: number? = nil
	local firstRebirth: number? = nil
	local rebirthsAt: { number } = {}
	local significantGaps: { number } = {}
	local lastSignificant = 0
	local routinePurchases = 0
	local significantEvents = 0

	local function noteSignificant(at: number)
		if lastSignificant > 0 then
			table.insert(significantGaps, at - lastSignificant)
		end
		lastSignificant = at
		significantEvents += 1
	end

	local ctx: RollMath.Context? = nil
	local ctxLuck = -1
	local function luckMult(): number
		return coreLuck(skills.CoreLuck, candidate.LuckDivisor) * Rebirth.luckMultiplier(rebirthSettings, rebirths)
	end
	local function context(extraLuck: number?): RollMath.Context
		local current = luckMult() * (extraLuck or 1)
		if current ~= ctxLuck or not ctx then
			ctx = RollMath.contextFor(rules, { FullLuck = current })
			ctxLuck = current
		end
		return ctx :: RollMath.Context
	end

	local function multipliers(): { number }
		local list = {}
		for index, level in levels do
			list[index] = Economy.pedestalMultiplier(settings, level)
		end
		table.sort(list, function(a, b)
			return a > b
		end)
		return list
	end
	local function incomePerSec(): number
		local mults = multipliers()
		local contributions = {}
		for index, mult in mults do
			table.insert(contributions, (held[index] or 0) * mult)
		end
		local global = (1 + SkillConfig.incomeBonus(skills.EnergyConduction))
			* Rebirth.incomeMultiplier(rebirthSettings, rebirths)
		return Economy.totalIncome(contributions, global)
	end

	local function insertHeld(income: number)
		local index = #held + 1
		for i, value in held do
			if income > value then
				index = i
				break
			end
		end
		table.insert(held, index, income)
		while #held > Config.Plots.MaxPedestals do
			table.remove(held)
		end
	end

	local function grant(relicId: string, tierIndex: number, at: number)
		local income = frozenBase[relicId] or 0
		bestTier = math.max(bestTier, tierIndex)
		if tierIndex >= RARE_I and not firstRare then
			firstRare = at
			noteSignificant(at)
		end
		if tierIndex >= EPIC_I then
			epicTotal += 1
			if not epicUnique[relicId] then
				epicUnique[relicId] = true
				if not firstEpic then
					firstEpic = at
					noteSignificant(at)
				end
			end
		end
		if tierIndex >= LEG_I then
			legTotal += 1
			if not legUnique[relicId] then
				legUnique[relicId] = true
				if not firstLegendary then
					firstLegendary = at
					noteSignificant(at)
				end
			end
		end
		if tierIndex >= MYTHIC_I and not firstMythic then
			firstMythic = at
			noteSignificant(at)
		end

		local displayedFloor = if #held >= #levels then held[#levels] else -1
		local wasSeen = seen[relicId] == true
		if wasSeen then
			duplicates += 1
		end
		if wasSeen and tierIndex <= SELL_MAX_TIER and income <= displayedFloor then
			local value = Economy.sellValue(settings, income, 0)
			ce += value
			lifetime += value
			soldCE += value
		else
			if not wasSeen then
				seen[relicId] = true
				uniqueCount += 1
			end
			insertHeld(income)
		end
	end

	local function rollOnce(extraLuck: number?, at: number)
		local relic = RollMath.roll(context(extraLuck), nextNumber)
		local tierIndex = RarityConfig.IndexById[relic.Tier] or 1
		grant(relic.Id, tierIndex, at)
	end

	type Option = { Cost: number, Kind: string, Buy: () -> () }
	local function buyOptions(): { Option }
		local list: { Option } = {}
		local nextSlot = #levels + 1
		local price = settings.SlotPrices[nextSlot]
		if price and nextSlot <= Config.Plots.MaxPedestals then
			table.insert(list, {
				Cost = price,
				Kind = "significant",
				Buy = function()
					table.insert(levels, 1)
				end,
			})
		end
		local lowest, lowestIndex = math.huge, nil
		for index, level in levels do
			if level < settings.PedestalMaxLevel and level < lowest then
				lowest, lowestIndex = level, index
			end
		end
		if lowestIndex and #held >= 1 then
			local idx = lowestIndex
			local lvl = lowest
			table.insert(list, {
				Cost = Economy.upgradeCost(settings, lvl),
				Kind = "routine",
				Buy = function()
					levels[idx] += 1
				end,
			})
		end
		if skills.CoreLuck < nodes.CoreLuck.MaxRank then
			table.insert(list, {
				Cost = coreLuckCost(skills.CoreLuck, candidate.LuckCostBase, candidate.LuckCostGrowth),
				Kind = if (skills.CoreLuck + 1) % 5 == 0 then "significant" else "routine",
				Buy = function()
					skills.CoreLuck += 1
				end,
			})
		end
		for _, id in { "ScanSpeed", "EnergyConduction" } do
			local cost = SkillConfig.cost(nodes[id], skills[id])
			if cost then
				table.insert(list, {
					Cost = cost,
					Kind = if id == "ScanSpeed" then "significant" else "routine",
					Buy = function()
						skills[id] += 1
					end,
				})
			end
		end
		return list
	end

	local saturations: { Saturation } = {}
	local nextCheckpoint = 1
	local scanTimer = 0
	local signals = Config.Signals.StartCount
	local regenTimer = 0
	local captureTimer = 0

	local totalSeconds = math.floor(options.Hours * 3600)
	for second = 1, totalSeconds do
		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			rollOnce(nil, second)
		end

		if hunting then
			regenTimer += 1
			if regenTimer >= Config.Signals.RegenSeconds then
				regenTimer = 0
				if signals < Config.Signals.MaxCount then
					signals += 1
				end
			end
			if signals > 0 then
				captureTimer += 1
				if captureTimer >= hunt.CaptureCycleSeconds then
					captureTimer = 0
					signals -= 1
					local scanForBonus = hunt.ReferenceScanSeconds or interval
					local bonus = bonusRolls(scanForBonus, hunt)
					for _ = 1, 1 + bonus do
						rollOnce(hunt.HuntLuckFactor, second)
					end
				end
			end
		end

		local income = incomePerSec()
		ce += income
		lifetime += income

		if doRebirth then
			local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
			if ce >= rebirthCost then
				rebirths += 1
				table.insert(rebirthsAt, second)
				firstRebirth = firstRebirth or second
				noteSignificant(second)
				ce = 0
				for index in levels do
					levels[index] = 1
				end
				for id in skills do
					skills[id] = 0
				end
				ctxLuck = -1
			end
		end

		if buy then
			local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
			local saving = doRebirth and rebirthCost - ce <= incomePerSec() * saveSeconds
			if not saving then
				for _ = 1, 500 do
					local cheapest: Option? = nil
					for _, option in buyOptions() do
						if option.Cost <= ce and (not cheapest or option.Cost < cheapest.Cost) then
							cheapest = option
						end
					end
					if not cheapest then
						break
					end
					ce -= cheapest.Cost
					local prevLuck = skills.CoreLuck
					local prevScan = skills.ScanSpeed
					cheapest.Buy()
					if cheapest.Kind == "routine" then
						routinePurchases += 1
					else
						noteSignificant(second)
					end
					if skills.CoreLuck ~= prevLuck or skills.ScanSpeed ~= prevScan then
						ctxLuck = -1
					end
				end
			end
		end

		local minute = checkpoints[nextCheckpoint]
		if minute and second == minute * 60 then
			nextCheckpoint += 1
			local epicU, legU = 0, 0
			for _ in epicUnique do
				epicU += 1
			end
			for _ in legUnique do
				legU += 1
			end
			table.insert(saturations, {
				Minute = minute,
				EpicTotal = epicTotal,
				EpicUnique = epicU,
				LegendaryTotal = legTotal,
				LegendaryUnique = legU,
				UniqueRelics = uniqueCount,
				DuplicatesKeptOrSold = duplicates,
				BestTier = RarityConfig.Tiers[bestTier].Id,
				Luck = luckMult(),
				IncomePerSec = incomePerSec(),
				Rebirths = rebirths,
				CoreLuckRank = skills.CoreLuck,
				ScanSeconds = SkillConfig.scanInterval(skills.ScanSpeed),
				Slots = #levels,
				LifetimeCE = lifetime,
			})
		end
	end

	return {
		FirstRareAt = firstRare,
		FirstEpicAt = firstEpic,
		FirstLegendaryAt = firstLegendary,
		FirstMythicAt = firstMythic,
		FirstRebirthAt = firstRebirth,
		RebirthsAt = rebirthsAt,
		Saturations = saturations,
		SignificantGaps = significantGaps,
		RoutinePurchaseCount = routinePurchases,
		SignificantEventCount = significantEvents,
		LifetimeCE = lifetime,
		SoldCE = soldCE,
		FinalLuck = luckMult(),
		FinalIncome = incomePerSec(),
		FinalRebirths = rebirths,
		FinalUnique = uniqueCount,
		FinalBestTier = RarityConfig.Tiers[bestTier].Id,
	}
end

function ProgressionSweep.percentile(sorted: { number }, p: number): number?
	if #sorted == 0 then
		return nil
	end
	local idx = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[idx]
end

function ProgressionSweep.times(results: { RunResult }, field: string): { number }
	local list = {}
	for _, r in results do
		local v = (r :: any)[field]
		if type(v) == "number" then
			table.insert(list, v)
		end
	end
	table.sort(list)
	return list
end

function ProgressionSweep.mean(values: { number }): number?
	if #values == 0 then
		return nil
	end
	local sum = 0
	for _, v in values do
		sum += v
	end
	return sum / #values
end

-- Confirm frozen incomes match live RelicIncome (extensibility guard).
function ProgressionSweep.incomesFrozen(): boolean
	for _, relic in RelicConfig.Relics do
		if frozenBase[relic.Id] ~= relicIncome.base(relic.Id) then
			return false
		end
		if frozenBase[relic.Id] <= 0 then
			return false
		end
	end
	return true
end

return ProgressionSweep
