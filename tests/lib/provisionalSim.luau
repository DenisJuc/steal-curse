-- Provisional candidate deep-dive sim (Phase 0.5). Frozen relic incomes. Full luck stack.
-- Does not mutate live Config; candidates are passed in.

local Config = require("../../src/shared/Config")
local CodexConfig = require("../../src/shared/CodexConfig")
local Economy = require("../../src/shared/Economy")
local Formulas = require("../../src/shared/Formulas")
local ItemConfig = require("../../src/shared/ItemConfig")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local ShowcaseConfig = require("../../src/shared/ShowcaseConfig")
local SkillConfig = require("../../src/shared/SkillConfig")
local relicIncome = require("./relicIncome")
local ProgressionSweep = require("./progressionSweep")

local ProvisionalSim = {}

local SELL_MAX_TIER = RarityConfig.IndexById.Rare
local EPIC_I = RarityConfig.IndexById.Epic
local LEG_I = RarityConfig.IndexById.Legendary
local MYTHIC_I = RarityConfig.IndexById.Mythic
local RARE_I = RarityConfig.IndexById.Rare
local ESSENTIAL_MAX = RarityConfig.IndexById[CodexConfig.EssentialMaxTier]

local essentialPool = 0
for _, relic in RelicConfig.Relics do
	if (RarityConfig.IndexById[relic.Tier] or 0) <= ESSENTIAL_MAX then
		essentialPool += 1
	end
end

local frozenBase: { [string]: number } = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local function makeRules(candidate: ProgressionSweep.Candidate): RollMath.Rules
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = candidate.EpicDenom
		elseif tier.Id == "Legendary" then
			denom = candidate.LegendaryDenom
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
end

local function coreLuck(rank: number, divisor: number): number
	return 10 ^ (rank / divisor)
end

local function coreLuckCost(rank: number, base: number, growth: number): number
	return math.ceil(base * growth ^ rank - 1e-9)
end

local function bonusRolls(scanForBonus: number, hunt: ProgressionSweep.HuntTune): number
	local b = Formulas.bonusRolls(scanForBonus, Config.Signals.RegenSeconds, {
		BonusFloor = hunt.BonusFloor,
		BonusFactor = hunt.BonusFactor,
	})
	if hunt.MaxBonusRolls then
		b = math.min(b, hunt.MaxBonusRolls)
	end
	return b
end

local function codexLuck(essentialUnique: number): number
	local frac = essentialUnique / math.max(1, essentialPool)
	local luck = 0
	for _, entry in CodexConfig.Essential do
		if frac + 1e-12 >= entry.Fraction then
			luck += entry.Luck
		end
	end
	return math.min(luck, Config.Luck.CodexMaxBonus)
end

local function showcaseLuck(level: number): number
	if level <= 0 then
		return 0
	end
	local row = ShowcaseConfig.Levels[math.min(level, ShowcaseConfig.MaxLevel)]
	return row and row.Luck or 0
end

export type DeepResult = {
	FirstRareAt: number?,
	FirstEpicAt: number?,
	FirstLegendaryAt: number?,
	FirstMythicAt: number?,
	FirstRebirthAt: number?,
	SecondRebirthAt: number?,
	ThirdRebirthAt: number?,
	RebirthsAt: { number },
	Captures: number,
	-- Mean Common+Uncommon tier mass at 60/120 under MaxLuck (soft-lock detector).
	LowTierMass60: number,
	LowTierMass120: number,
	LowTierMass60Focused: number,
	Saturations: { any },
	PostRebirth: { { RebirthIndex: number, AtMin: number, EpicNext30: number, LuckAfter: number, IncomeAfter: number } },
	LifetimeCE: number,
	FinalLuck: number,
	FinalIncome: number,
	FinalRebirths: number,
	FinalUnique: number,
	FinalEssentialUnique: number,
	FinalBestTier: string,
	PotionUptime: number,
}

function ProvisionalSim.run(options: {
	Seed: number,
	Hours: number,
	Behaviour: ProgressionSweep.Behaviour,
	Candidate: ProgressionSweep.Candidate,
	FullStack: boolean?,
}): DeepResult
	local settings = Config.Economy
	local rebirthSettings = Config.Rebirth
	local candidate = options.Candidate
	local rules = makeRules(candidate)
	local hunt = candidate.Hunt
	local behaviour = options.Behaviour
	local buy = behaviour ~= "passive"
	local hunting = behaviour == "hunter"
	local fullStack = options.FullStack ~= false
	local doRebirth = buy
	local nodes = SkillConfig.ById
	-- Hold (6s) + travel/approach (~14s). Signal-limited: burst then wait on regen.
	local captureCycle = Config.Bind.HoldSeconds + 14

	local rngState = (options.Seed * 7919 + 12345) % 2147483647
	local function nextNumber(): number
		rngState = (rngState * 48271) % 2147483647
		return rngState / 2147483647
	end

	local ce, lifetime = 0, 0
	local rebirths = 0
	local skills = { CoreLuck = 0, ScanSpeed = 0, EnergyConduction = 0 }
	local levels: { number } = {}
	for _ = 1, Config.Plots.StartingPedestals do
		table.insert(levels, 1)
	end
	local held: { number } = {}
	local seen: { [string]: boolean } = {}
	local essentialSeen: { [string]: boolean } = {}
	local essentialUnique = 0
	local uniqueCount = 0
	local bestTier = 1
	local epicTotal, legTotal = 0, 0
	local showcaseLevel = 0
	local potionLeft = 0
	local potionActiveSeconds = 0
	local captures = 0

	local firstRare: number? = nil
	local firstEpic: number? = nil
	local firstLegendary: number? = nil
	local firstMythic: number? = nil
	local rebirthsAt: { number } = {}
	local postRebirth = {}
	local epicAtRebirth: { [number]: number } = {}

	local ctx: RollMath.Context? = nil
	local ctxKey = ""

	local function luckMult(): number
		local core = coreLuck(skills.CoreLuck, candidate.LuckDivisor)
		local reb = Rebirth.luckMultiplier(rebirthSettings, rebirths)
		if not fullStack then
			return core * reb
		end
		local codex = 1 + codexLuck(essentialUnique)
		local show = 1 + showcaseLuck(showcaseLevel)
		local potion = if potionLeft > 0 then Config.Luck.MaxConsumable else 1
		return core * reb * codex * show * potion
	end

	local function context(extraLuck: number?): RollMath.Context
		local current = luckMult() * (extraLuck or 1)
		local key = tostring(current)
		if key ~= ctxKey or not ctx then
			ctx = RollMath.contextFor(rules, { FullLuck = current })
			ctxKey = key
		end
		return ctx :: RollMath.Context
	end

	local function lowTierMass(extraLuck: number?, focus: string?): number
		local state = {
			FullLuck = luckMult() * (extraLuck or 1),
			RarityFocus = focus or "MaxLuck",
		}
		local c = RollMath.contextFor(rules, state)
		local masses = RollMath.tierMasses(c.Tiers, c.Luck)
		local common = masses[1] or 0
		local uncommon = masses[2] or 0
		return common + uncommon
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
		local showIncome = 0
		if fullStack and showcaseLevel > 0 then
			local row = ShowcaseConfig.Levels[math.min(showcaseLevel, ShowcaseConfig.MaxLevel)]
			showIncome = row and row.Income or 0
		end
		local global = (1 + SkillConfig.incomeBonus(skills.EnergyConduction) + showIncome)
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
		end
		if tierIndex >= EPIC_I then
			epicTotal += 1
			if not firstEpic then
				firstEpic = at
			end
		end
		if tierIndex >= LEG_I then
			legTotal += 1
			if not firstLegendary then
				firstLegendary = at
			end
		end
		if tierIndex >= MYTHIC_I and not firstMythic then
			firstMythic = at
		end

		local displayedFloor = if #held >= #levels then held[#levels] else -1
		local wasSeen = seen[relicId] == true
		if wasSeen and tierIndex <= SELL_MAX_TIER and income <= displayedFloor then
			local value = Economy.sellValue(settings, income, 0)
			ce += value
			lifetime += value
		else
			if not wasSeen then
				seen[relicId] = true
				uniqueCount += 1
				if tierIndex <= ESSENTIAL_MAX and not essentialSeen[relicId] then
					essentialSeen[relicId] = true
					essentialUnique += 1
					ctxKey = ""
				end
			end
			insertHeld(income)
		end
	end

	local function rollOnce(extraLuck: number?, at: number)
		local relic = RollMath.roll(context(extraLuck), nextNumber)
		grant(relic.Id, RarityConfig.IndexById[relic.Tier] or 1, at)
	end

	type Option = { Cost: number, Buy: () -> () }
	local function buyOptions(): { Option }
		local list: { Option } = {}
		local nextSlot = #levels + 1
		local price = settings.SlotPrices[nextSlot]
		if price and nextSlot <= Config.Plots.MaxPedestals then
			table.insert(list, {
				Cost = price,
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
			table.insert(list, {
				Cost = Economy.upgradeCost(settings, lowest),
				Buy = function()
					levels[idx] += 1
				end,
			})
		end
		if skills.CoreLuck < nodes.CoreLuck.MaxRank then
			table.insert(list, {
				Cost = coreLuckCost(skills.CoreLuck, candidate.LuckCostBase, candidate.LuckCostGrowth),
				Buy = function()
					skills.CoreLuck += 1
					ctxKey = ""
				end,
			})
		end
		for _, id in { "ScanSpeed", "EnergyConduction" } do
			local cost = SkillConfig.cost(nodes[id], skills[id])
			if cost then
				local skillId = id
				table.insert(list, {
					Cost = cost,
					Buy = function()
						skills[skillId] += 1
						ctxKey = ""
					end,
				})
			end
		end
		if fullStack then
			if showcaseLevel == 0 then
				local unlock = ShowcaseConfig.Showcases[1]
				if unlock and unlock.Unlock.Price then
					table.insert(list, {
						Cost = unlock.Unlock.Price :: number,
						Buy = function()
							showcaseLevel = 1
							ctxKey = ""
						end,
					})
				end
			elseif showcaseLevel < ShowcaseConfig.MaxLevel then
				local nextLevel = ShowcaseConfig.Levels[showcaseLevel + 1]
				if nextLevel and nextLevel.Cost then
					table.insert(list, {
						Cost = nextLevel.Cost,
						Buy = function()
							showcaseLevel += 1
							ctxKey = ""
						end,
					})
				end
			end
		end
		return list
	end

	local saturations = {}
	local checkpoints = { 15, 30, 60, 90, 120, 180, 240 }
	local nextCheckpoint = 1
	local scanTimer = 0
	local signals = Config.Signals.StartCount
	local regenTimer = 0
	local captureTimer = 0
	local low60, low120, low60Focus = 0, 0, 0
	local offeringTimer = 0
	local epicMarker = 0
	local pendingPost: { RebirthIndex: number, At: number, EpicBase: number }? = nil

	local totalSeconds = math.floor(options.Hours * 3600)
	for second = 1, totalSeconds do
		if potionLeft > 0 then
			potionLeft -= 1
			potionActiveSeconds += 1
			if potionLeft <= 0 then
				ctxKey = ""
			end
		end

		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			rollOnce(nil, second)
		end

		-- Occasional offering-like potion for upgrader full-stack (wild finds approx).
		if fullStack and buy and not hunting then
			offeringTimer += 1
			if offeringTimer >= 600 then
				offeringTimer = 0
				if nextNumber() < 0.35 then
					potionLeft = math.min(ItemConfig.MaxBuffSeconds, potionLeft + 600)
					ctxKey = ""
				end
			end
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
				if captureTimer >= captureCycle then
					captureTimer = 0
					signals -= 1
					captures += 1
					local scanForBonus = hunt.ReferenceScanSeconds or interval
					local bonus = bonusRolls(scanForBonus, hunt)
					for _ = 1, 1 + bonus do
						rollOnce(hunt.HuntLuckFactor, second)
					end
					if fullStack and nextNumber() < ItemConfig.Drops.CaptureChance then
						local w = ItemConfig.Drops.Weights
						-- Luck potion only for stack test
						if nextNumber() < (w.LuckPotion / (w.LuckPotion + w.HastePotion + w.FortunePotion)) then
							potionLeft = math.min(ItemConfig.MaxBuffSeconds, potionLeft + 600)
							ctxKey = ""
						end
					end
				end
			end
		end

		local income = incomePerSec()
		ce += income
		lifetime += income

		if pendingPost and second >= pendingPost.At + 1800 then
			table.insert(postRebirth, {
				RebirthIndex = pendingPost.RebirthIndex,
				AtMin = pendingPost.At / 60,
				EpicNext30 = epicTotal - pendingPost.EpicBase,
				LuckAfter = luckMult(),
				IncomeAfter = incomePerSec(),
			})
			pendingPost = nil
		end

		if doRebirth then
			local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
			if ce >= rebirthCost then
				rebirths += 1
				table.insert(rebirthsAt, second)
				epicAtRebirth[rebirths] = epicTotal
				pendingPost = { RebirthIndex = rebirths, At = second, EpicBase = epicTotal }
				ce = 0
				for index in levels do
					levels[index] = 1
				end
				for id in skills do
					skills[id] = 0
				end
				-- Showcase / Codex / relics kept (match Rebirth.apply)
				ctxKey = ""
			end
		end

		if buy then
			local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
			local saving = doRebirth and rebirthCost - ce <= incomePerSec() * 600
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
					cheapest.Buy()
				end
			end
		end

		local minute = checkpoints[nextCheckpoint]
		if minute and second == minute * 60 then
			nextCheckpoint += 1
			local mass = lowTierMass(nil, "MaxLuck")
			local massFocus = lowTierMass(nil, "Common")
			if minute == 60 then
				low60 = mass
				low60Focus = massFocus
			elseif minute == 120 then
				low120 = mass
			end
			table.insert(saturations, {
				Minute = minute,
				EpicTotal = epicTotal,
				LegendaryTotal = legTotal,
				UniqueRelics = uniqueCount,
				EssentialUnique = essentialUnique,
				Luck = luckMult(),
				IncomePerSec = incomePerSec(),
				Rebirths = rebirths,
				CoreLuckRank = skills.CoreLuck,
				ScanSeconds = interval,
				ShowcaseLevel = showcaseLevel,
				PotionUp = potionLeft > 0,
				LowTierMass = mass,
				LowTierMassFocused = massFocus,
				Captures = captures,
				BestTier = RarityConfig.Tiers[bestTier].Id,
			})
		end
	end

	return {
		FirstRareAt = firstRare,
		FirstEpicAt = firstEpic,
		FirstLegendaryAt = firstLegendary,
		FirstMythicAt = firstMythic,
		FirstRebirthAt = rebirthsAt[1],
		SecondRebirthAt = rebirthsAt[2],
		ThirdRebirthAt = rebirthsAt[3],
		RebirthsAt = rebirthsAt,
		Captures = captures,
		LowTierMass60 = low60,
		LowTierMass120 = low120,
		LowTierMass60Focused = low60Focus,
		Saturations = saturations,
		PostRebirth = postRebirth,
		LifetimeCE = lifetime,
		FinalLuck = luckMult(),
		FinalIncome = incomePerSec(),
		FinalRebirths = rebirths,
		FinalUnique = uniqueCount,
		FinalEssentialUnique = essentialUnique,
		FinalBestTier = RarityConfig.Tiers[bestTier].Id,
		PotionUptime = potionActiveSeconds / math.max(1, totalSeconds),
	}
end

function ProvisionalSim.candidateE20k(): ProgressionSweep.Candidate
	return {
		Id = "E20k_L12_C17_HR",
		Label = "Epic 20k, luck/12, cost 1.7, hunt reform 4+×5",
		EpicDenom = 20000,
		LegendaryDenom = 500000,
		LuckDivisor = 12,
		LuckCostGrowth = 1.7,
		LuckCostBase = 100,
		Hunt = {
			BonusFloor = 2,
			BonusFactor = 0.08,
			ReferenceScanSeconds = 4,
			HuntLuckFactor = 5,
			MaxBonusRolls = 6,
			CaptureCycleSeconds = Config.Bind.HoldSeconds + 14,
		},
	}
end

function ProvisionalSim.essentialPoolSize(): number
	return essentialPool
end

return ProvisionalSim
