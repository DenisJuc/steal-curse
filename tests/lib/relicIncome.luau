-- Mirror of src/shared/RelicIncome for Lune (that module needs Roblox `script`).

local BalanceTrials = require("../../src/shared/BalanceTrials")
local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local SizeConfig = require("../../src/shared/SizeConfig")
local SoftCapRarity = require("./softCapRarity")

local RelicIncome = {}

local oneIn: { [string]: number } = {}
local base: { [string]: number } = {}
local source = "Ladder"

local function rebuildLadder()
	local liveRules: RollMath.Rules = {
		Tiers = RarityConfig.Tiers,
		ByTier = RollMath.groupByTier(RelicConfig.Relics),
		Mutations = MutationConfig.Mutations,
		MutationChanceByRank = MutationConfig.ChanceByRank,
		FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
		FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
	}
	local ctx = RollMath.contextFor(liveRules, { FullLuck = 1 })
	oneIn = {}
	base = {}
	for _, relic in RelicConfig.Relics do
		local p = RollMath.itemProbability(ctx, relic.Id)
		oneIn[relic.Id] = if p > 0 then 1 / p else math.huge
		base[relic.Id] = Economy.relicBaseIncome(Config.Economy, oneIn[relic.Id], (relic :: any).IncomeBonus)
	end
	source = "Ladder"
end

local function rebuildSoftCap()
	SoftCapRarity.syncFromTrials()
	SoftCapRarity.invalidateSampler()
	local pMap = SoftCapRarity.probabilities(1)
	oneIn = {}
	base = {}
	for _, relic in RelicConfig.Relics do
		local p = pMap[relic.Id]
		oneIn[relic.Id] = if type(p) == "number" and p > 0 then 1 / p else math.huge
		base[relic.Id] = Economy.relicBaseIncome(Config.Economy, oneIn[relic.Id], (relic :: any).IncomeBonus)
	end
	source = "SoftCap"
end

function RelicIncome.syncFromTrials()
	if BalanceTrials.raritySampler() == "SoftCap" then
		rebuildSoftCap()
	else
		rebuildLadder()
	end
end

rebuildLadder()

function RelicIncome.incomeSource(): string
	return source
end

function RelicIncome.oneIn(relicId: string): number
	return oneIn[relicId] or math.huge
end

function RelicIncome.base(relicId: string): number
	return base[relicId] or 0
end

function RelicIncome.of(relicId: string, mutationId: string?, sizeId: string?): number
	local mutation = mutationId and MutationConfig.ById[mutationId]
	local mutMult = if mutation then mutation.IncomeMultiplier else 1
	local sizeMult = SizeConfig.incomeMult(sizeId)
	return Economy.relicIncome(RelicIncome.base(relicId), mutMult * sizeMult)
end

return RelicIncome
