-- End-to-end Core Loop simulator: Seal → Index → Equip → Luck/Income → Rebirth.
-- SoftCap_P5_Size. No Fusion / Charms / Hunt Quarry. Calibrated to scan-heavy playtest behavior.
-- Uses shared SoftCap, Economy, SkillConfig, Rebirth, SizeConfig, MutationConfig.

local BalanceTrials = require("../../src/shared/BalanceTrials")
local CodexConfig = require("../../src/shared/CodexConfig")
local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local Formulas = require("../../src/shared/Formulas")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local ShowcaseConfig = require("../../src/shared/ShowcaseConfig")
local SizeConfig = require("../../src/shared/SizeConfig")
local SkillConfig = require("../../src/shared/SkillConfig")
local SoftCapRarity = require("./softCapRarity")
local relicIncome = require("./relicIncome")

local CoreLoop = {}

export type Result = {
	Minutes: number,
	Seed: number,
	Unique: number,
	UniqueByTier: { [string]: number },
	ValuableDiscoveries: number, -- new Rare+ unique, first-of-tier, Huge/Titanic, new mut on board
	AvgValuableGapMin: number,
	EquipUpgrades: number,
	AvgEquipGapMin: number,
	IncomeStart: number,
	IncomeEnd: number,
	LuckStart: number,
	LuckEnd: number,
	PRarePlusStart: number,
	PRarePlusEnd: number,
	CoreLuckEnd: number,
	ScanRankEnd: number,
	EnergyEnd: number,
	SlotsEnd: number,
	PedMinLevel: number,
	PedAvgLevel: number,
	CE: number,
	Rebirths: number,
	MinToFirstRebirth: number?,
	RebirthPathOk: boolean,
	DeadEnd: boolean, -- shop empty + CE << rebirth + income flat
	Huge: number,
	Titanic: number,
	Mutations: number,
	VariantUniques: number, -- unique id×mut×size keys beyond base id
	CodexFrac: number,
	GoalsLeft: string, -- human summary of remaining chase
	Evidence: "SIMULATION",
}

local TIER_I = RarityConfig.IndexById
local RARE_I = TIER_I.Rare or 3
local ECO = Config.Economy
local REBIRTH_SETTINGS = Config.Rebirth

local frozenBase: { [string]: number } = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local essentialPool = 0
for _, relic in RelicConfig.Relics do
	if (TIER_I[relic.Tier] or 0) <= (TIER_I[CodexConfig.EssentialMaxTier] or 2) then
		essentialPool += 1
	end
end

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

local function pickRelic(sampler, rng): (string, string)
	local target = rng() * sampler.Total
	local id, tier = sampler.Ids[#sampler.Ids], sampler.Tiers[#sampler.Tiers]
	local acc = 0
	for i = 1, #sampler.Weights do
		acc += sampler.Weights[i]
		if target < acc then
			return sampler.Ids[i], sampler.Tiers[i]
		end
	end
	return id, tier
end

local function pRarePlus(luck: number): number
	local _, byTier = SoftCapRarity.probabilities(luck)
	local p = 0
	for tier, share in byTier do
		if (TIER_I[tier] or 0) >= RARE_I then
			p += share
		end
	end
	return p
end

function CoreLoop.run(options: { Minutes: number, Seed: number }): Result
	BalanceTrials.AllowNonStudioActive = true
	BalanceTrials.Active = "SoftCap_P5_Size"
	BalanceTrials.CollectionPrototype = true
	BalanceTrials.StudioCoreLoopPresentation = true
	SoftCapRarity.syncFromTrials()
	SoftCapRarity.invalidateSampler()
	SizeConfig.syncFromTrials()
	relicIncome.syncFromTrials()

	local minutes = options.Minutes
	local duration = minutes * 60
	local rng = mulberry32(options.Seed * 7919 + minutes * 13 + 42)

	local skills = {
		CoreLuck = 0,
		ScanSpeed = 0,
		EnergyConduction = 0,
		PedestalMastery = 0,
		SpiritMerchant = 0,
		MutationResonance = 0,
	}
	local rebirths = 0
	local ce = 0.0
	local slots = Config.Plots.StartingPedestals
	local pedLevels = { 1, 1, 1, 1, 1, 1 }
	local pedRelic: { string? } = { nil, nil, nil, nil, nil, nil }
	local pedMut: { string? } = { nil, nil, nil, nil, nil, nil }
	local pedSize: { string? } = { nil, nil, nil, nil, nil, nil }

	local discovered: { [string]: boolean } = {}
	local uniqueByTier: { [string]: number } = {}
	local variantKeys: { [string]: boolean } = {}
	local unique = 0
	local essentialUnique = 0
	local valuable = 0
	local valuableGaps = 0
	local lastValuableSec = 0
	local equipUps = 0
	local equipGaps = 0
	local lastEquipSec = 0
	local hugeN, titanicN, mutN = 0, 0, 0
	local firstTier: { [string]: boolean } = {}
	local minToR1: number? = nil
	local saving = false

	local luckDiv = 12
	do
		local trial = BalanceTrials.current()
		if trial and trial.LuckDivisor then
			luckDiv = trial.LuckDivisor
		end
	end

	local function fullLuck(): number
		local core = Formulas.coreLuck(skills.CoreLuck, luckDiv)
		local reb = Rebirth.luckMultiplier(REBIRTH_SETTINGS, rebirths)
		local codex = 1 + codexLuck(essentialUnique)
		-- Light showcase proxy as index fills (not perfect knowledge).
		local show = 1 + math.min(ShowcaseConfig.Levels[#ShowcaseConfig.Levels].Luck or 0.1, unique / 80 * 0.1)
		return core * reb * codex * show
	end

	local function relicRate(id: string, mut: string?, size: string?): number
		return relicIncome.of(id, mut, size)
	end

	local function incomePerSec(): number
		local sum = 0
		local cond = 1 + SkillConfig.incomeBonus(skills.EnergyConduction)
		local mastery = BalanceTrials.pedestalMasteryIncomeMult(skills.PedestalMastery)
		local reb = Rebirth.incomeMultiplier(REBIRTH_SETTINGS, rebirths)
		for i = 1, slots do
			local id = pedRelic[i]
			if id then
				local base = relicRate(id, pedMut[i], pedSize[i])
				local ped = Economy.pedestalMultiplier(ECO, pedLevels[i])
				sum += base * ped
			end
		end
		return sum * cond * mastery * reb
	end

	local function tryEquip(id: string, tier: string, mut: string?, size: string?, sec: number)
		local rate = relicRate(id, mut, size)
		-- Prefer empty slot
		for i = 1, slots do
			if not pedRelic[i] then
				pedRelic[i] = id
				pedMut[i] = mut
				pedSize[i] = size
				equipUps += 1
				if lastEquipSec > 0 then
					equipGaps += (sec - lastEquipSec)
				end
				lastEquipSec = sec
				return
			end
		end
		-- Replace weakest if clearly better (~15% — imperfect player)
		local weakI, weakR = 1, math.huge
		for i = 1, slots do
			local r = relicRate(pedRelic[i] :: string, pedMut[i], pedSize[i])
				* Economy.pedestalMultiplier(ECO, pedLevels[i])
			if r < weakR then
				weakR = r
				weakI = i
			end
		end
		local newR = rate * Economy.pedestalMultiplier(ECO, pedLevels[weakI])
		if newR > weakR * 1.15 then
			pedRelic[weakI] = id
			pedMut[weakI] = mut
			pedSize[weakI] = size
			equipUps += 1
			if lastEquipSec > 0 then
				equipGaps += (sec - lastEquipSec)
			end
			lastEquipSec = sec
		end
	end

	local function skillCost(id: string, rank: number): number?
		local node = SkillConfig.ById[id]
		if not node then
			return nil
		end
		local maxR = BalanceTrials.skillMaxRank(id, rebirths)
		if rank >= maxR then
			return nil
		end
		local override = if id == "CoreLuck" then BalanceTrials.coreLuckCostOverride() else nil
		return SkillConfig.cost(node, rank, override)
	end

	local function buySkill(id: string, maxSpendFrac: number): boolean
		local rank = skills[id] or 0
		local cost = skillCost(id, rank)
		if not cost or cost > ce then
			return false
		end
		if cost > ce * maxSpendFrac and cost > incomePerSec() * 45 then
			return false
		end
		ce -= cost
		skills[id] = rank + 1
		return true
	end

	local function buyPedestalUpgrades(budgetFrac: number)
		local budget = ce * budgetFrac
		local spent = 0
		-- Greedy cheapest next level (playtest dumps into pedestals)
		for _ = 1, 40 do
			local bestI, bestCost = nil, math.huge
			for i = 1, slots do
				if pedLevels[i] < ECO.PedestalMaxLevel then
					local c = Economy.upgradeCost(ECO, pedLevels[i])
					if c < bestCost and spent + c <= budget and c <= ce then
						bestCost = c
						bestI = i
					end
				end
			end
			if not bestI then
				break
			end
			ce -= bestCost
			spent += bestCost
			pedLevels[bestI] += 1
		end
	end

	local function maybeBuySlot()
		local nextSlot = slots + 1
		local price = ECO.SlotPrices[nextSlot]
		if price and ce >= price and nextSlot <= 6 then
			-- Playtest bought slot 4 early; slot 5 mid
			if nextSlot == 4 or (nextSlot == 5 and incomePerSec() > 5000) or (nextSlot == 6 and incomePerSec() > 5e5) then
				ce -= price
				slots = nextSlot
			end
		end
	end

	local function shopTick(sec: number)
		local rate = incomePerSec()
		local rCost = Rebirth.cost(REBIRTH_SETTINGS, rebirths)
		-- Start saving when halfway to Rebirth and next CL is a big chunk of the cost
		local nextCL = skillCost("CoreLuck", skills.CoreLuck)
		if ce >= rCost * 0.45 and nextCL and nextCL > rCost * 0.2 then
			saving = true
		end
		if ce >= rCost then
			-- SoftCap B+: CE=0 only; skills / pedestals / Index kept (Rebirth.apply BPlus).
			rebirths += 1
			ce = 0
			saving = false
			if not minToR1 then
				minToR1 = sec / 60
			end
			return
		end
		if saving then
			-- Only cheap pedestal top-ups while saving
			buyPedestalUpgrades(0.05)
			return
		end
		-- Playtest-like priority: CL → Energy → pedestals → slots → ScanSpeed → Mastery
		for _ = 1, 8 do
			if not buySkill("CoreLuck", 0.55) then
				break
			end
		end
		for _ = 1, 4 do
			if not buySkill("EnergyConduction", 0.4) then
				break
			end
		end
		buyPedestalUpgrades(0.5)
		maybeBuySlot()
		buySkill("ScanSpeed", 0.35)
		if BalanceTrials.pedestalMasteryEnabled() then
			buySkill("PedestalMastery", 0.25)
		end
		-- Occasional merchant / mut res late
		if skills.CoreLuck >= 12 then
			buySkill("SpiritMerchant", 0.15)
		end
		if skills.CoreLuck >= 14 and rate > 1e4 then
			buySkill("MutationResonance", 0.1)
		end
	end

	local luckStart = fullLuck()
	local pStart = pRarePlus(luckStart)
	local incomeStart = 0

	local sec = 0.0
	local nextScan = 0.0
	local nextShop = 2.0
	local incomeAcc = 0.0

	while sec < duration do
		-- Advance to next event
		local scanIv = SkillConfig.scanInterval(skills.ScanSpeed)
		local nextEvent = math.min(duration, nextScan, nextShop)
		local dt = nextEvent - sec
		if dt > 0 then
			local inc = incomePerSec()
			ce += inc * dt
			incomeAcc += inc * dt
			sec = nextEvent
		end
		if sec >= duration then
			break
		end

		if sec + 1e-9 >= nextShop then
			shopTick(sec)
			nextShop = sec + 8 -- imperfect: opens shop every ~8s of play, not every frame
		end

		if sec + 1e-9 >= nextScan then
			local L = fullLuck()
			local sampler = SoftCapRarity.samplerFor(L)
			local id, tier = pickRelic(sampler, rng)
			local size = SizeConfig.roll(tier, rng)
			local mut: string? = nil
			local mutRank = skills.MutationResonance
			local mutChance = MutationConfig.ChanceAt(mutRank)
			if mutRank > 0 and mutChance > 0 and rng() < mutChance then
				local unlocked = {}
				for _, m in MutationConfig.Mutations do
					if m.UnlockRank <= mutRank then
						table.insert(unlocked, m)
					end
				end
				if #unlocked > 0 then
					mut = unlocked[math.clamp(math.floor(rng() * #unlocked) + 1, 1, #unlocked)].Id
					mutN += 1
				end
			end
			if size == "Huge" then
				hugeN += 1
			elseif size == "Titanic" then
				titanicN += 1
			end

			local isNew = not discovered[id]
			local tierIdx = TIER_I[tier] or 0
			local valuableHit = false
			if isNew then
				discovered[id] = true
				unique += 1
				uniqueByTier[tier] = (uniqueByTier[tier] or 0) + 1
				if tierIdx <= (TIER_I[CodexConfig.EssentialMaxTier] or 2) then
					essentialUnique += 1
				end
				if not firstTier[tier] then
					firstTier[tier] = true
					valuableHit = true
				end
				if tierIdx >= RARE_I then
					valuableHit = true
				end
			end
			if size == "Huge" or size == "Titanic" then
				valuableHit = true
			end
			local vkey = `{id}|{mut or "-"}|{size or "Normal"}`
			if not variantKeys[vkey] then
				variantKeys[vkey] = true
				if mut or (size and size ~= "Normal") then
					valuableHit = true
				end
			end
			if valuableHit then
				valuable += 1
				if lastValuableSec > 0 then
					valuableGaps += (sec - lastValuableSec)
				end
				lastValuableSec = sec
			end

			tryEquip(id, tier, mut, size, sec)
			-- Sell dupe proxy: small CE from autosell
			if not isNew then
				local sell = relicRate(id, mut, size) * (ECO.SellSeconds or 30)
				local merch = 1 + SkillConfig.sellBonus(skills.SpiritMerchant)
				ce += sell * merch
			end
			nextScan = sec + scanIv
		end
	end

	-- Flush remaining income to end
	if sec < duration then
		ce += incomePerSec() * (duration - sec)
	end

	local luckEnd = fullLuck()
	local incomeEnd = incomePerSec()
	if incomeStart <= 0 then
		incomeStart = math.max(incomeEnd * 0.01, 1e-6)
	end

	local pedMin, pedSum = 50, 0
	for i = 1, slots do
		pedMin = math.min(pedMin, pedLevels[i])
		pedSum += pedLevels[i]
	end

	local rCost = Rebirth.cost(REBIRTH_SETTINGS, rebirths)
	local shopLeft = false
	for _, id in { "CoreLuck", "EnergyConduction", "ScanSpeed", "PedestalMastery" } do
		local c = skillCost(id, skills[id] or 0)
		if c and c <= ce then
			shopLeft = true
			break
		end
	end
	local deadEnd = (not shopLeft)
		and ce < rCost * 0.05
		and incomeEnd > 0
		and (rCost / incomeEnd) > 20 * 3600 -- >20h to rebirth at current rate while broke

	local variantCount = 0
	for _ in variantKeys do
		variantCount += 1
	end

	local goals = {}
	if rebirths < 1 then
		table.insert(goals, "first Rebirth")
	else
		table.insert(goals, `Rebirth {rebirths + 1}`)
	end
	local missingRare = 0
	for _, relic in RelicConfig.Relics do
		if (TIER_I[relic.Tier] or 0) >= RARE_I and not discovered[relic.Id] then
			missingRare += 1
		end
	end
	if missingRare > 0 then
		table.insert(goals, `{missingRare} Rare+ Index`)
	end
	if unique < #RelicConfig.Relics then
		table.insert(goals, `{#RelicConfig.Relics - unique} Index left`)
	end

	return {
		Minutes = minutes,
		Seed = options.Seed,
		Unique = unique,
		UniqueByTier = uniqueByTier,
		ValuableDiscoveries = valuable,
		AvgValuableGapMin = if valuable > 1 then (valuableGaps / (valuable - 1)) / 60 else minutes,
		EquipUpgrades = equipUps,
		AvgEquipGapMin = if equipUps > 1 then (equipGaps / (equipUps - 1)) / 60 else minutes,
		IncomeStart = incomeStart,
		IncomeEnd = incomeEnd,
		LuckStart = luckStart,
		LuckEnd = luckEnd,
		PRarePlusStart = pStart,
		PRarePlusEnd = pRarePlus(luckEnd),
		CoreLuckEnd = skills.CoreLuck,
		ScanRankEnd = skills.ScanSpeed,
		EnergyEnd = skills.EnergyConduction,
		SlotsEnd = slots,
		PedMinLevel = pedMin,
		PedAvgLevel = pedSum / math.max(1, slots),
		CE = ce,
		Rebirths = rebirths,
		MinToFirstRebirth = minToR1,
		RebirthPathOk = minToR1 ~= nil or (incomeEnd > 0 and (rCost / incomeEnd) < 12 * 3600),
		DeadEnd = deadEnd,
		Huge = hugeN,
		Titanic = titanicN,
		Mutations = mutN,
		VariantUniques = variantCount,
		CodexFrac = unique / math.max(1, #RelicConfig.Relics),
		GoalsLeft = table.concat(goals, "; "),
		Evidence = "SIMULATION",
	}
end

function CoreLoop.aggregate(results: { Result }): Result
	local n = #results
	local function avg(key: string): number
		local s = 0
		for _, r in results do
			s += (r :: any)[key] or 0
		end
		return s / n
	end
	local r1Count = 0
	local r1Sum = 0
	local dead = 0
	local pathOk = 0
	for _, r in results do
		if r.MinToFirstRebirth then
			r1Count += 1
			r1Sum += r.MinToFirstRebirth
		end
		if r.DeadEnd then
			dead += 1
		end
		if r.RebirthPathOk then
			pathOk += 1
		end
	end
	local sample = results[1]
	return {
		Minutes = sample.Minutes,
		Seed = 0,
		Unique = avg("Unique"),
		UniqueByTier = sample.UniqueByTier,
		ValuableDiscoveries = avg("ValuableDiscoveries"),
		AvgValuableGapMin = avg("AvgValuableGapMin"),
		EquipUpgrades = avg("EquipUpgrades"),
		AvgEquipGapMin = avg("AvgEquipGapMin"),
		IncomeStart = avg("IncomeStart"),
		IncomeEnd = avg("IncomeEnd"),
		LuckStart = avg("LuckStart"),
		LuckEnd = avg("LuckEnd"),
		PRarePlusStart = avg("PRarePlusStart"),
		PRarePlusEnd = avg("PRarePlusEnd"),
		CoreLuckEnd = avg("CoreLuckEnd"),
		ScanRankEnd = avg("ScanRankEnd"),
		EnergyEnd = avg("EnergyEnd"),
		SlotsEnd = avg("SlotsEnd"),
		PedMinLevel = avg("PedMinLevel"),
		PedAvgLevel = avg("PedAvgLevel"),
		CE = avg("CE"),
		Rebirths = avg("Rebirths"),
		MinToFirstRebirth = if r1Count > 0 then r1Sum / r1Count else nil,
		RebirthPathOk = pathOk / n >= 0.5,
		DeadEnd = dead / n >= 0.5,
		Huge = avg("Huge"),
		Titanic = avg("Titanic"),
		Mutations = avg("Mutations"),
		VariantUniques = avg("VariantUniques"),
		CodexFrac = avg("CodexFrac"),
		GoalsLeft = sample.GoalsLeft,
		Evidence = "SIMULATION",
	}
end

return CoreLoop
