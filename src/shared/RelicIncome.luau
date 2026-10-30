-- Every relic's base odds and CE/sec for pedestal income / selling.
-- Ladder (live): LIVE rarity denominators at luck 1.
-- SoftCap Studio: SoftCap p_i at luck 1 so drop frequency and income stay consistent
-- (Ladder-priced SoftCap drops caused runaway pedestal income).

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local MutationConfig = require(script.Parent.MutationConfig)
local RarityConfig = require(script.Parent.RarityConfig)
local RelicConfig = require(script.Parent.RelicConfig)
local RollMath = require(script.Parent.RollMath)
local SizeConfig = require(script.Parent.SizeConfig)

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
	local SoftCapRarity = require(script.Parent.SoftCapRarity)
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
	local BalanceTrials = require(script.Parent.BalanceTrials)
	if BalanceTrials.raritySampler() == "SoftCap" then
		rebuildSoftCap()
	else
		rebuildLadder()
	end
end

-- Default: live ladder until Studio/Main syncs SoftCap.
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
