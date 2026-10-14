-- Every relic's base odds and CE/sec, computed once from the roll rules (luck 1, no focus) with
-- Economy.relicBaseIncome. Server income, selling, auto-sell and every menu read it from here.
-- tests/lib/relicIncome mirrors it for Lune (this module needs Roblox `script`).

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local MutationConfig = require(script.Parent.MutationConfig)
local RelicConfig = require(script.Parent.RelicConfig)
local RollMath = require(script.Parent.RollMath)
local RollRules = require(script.Parent.RollRules)

local RelicIncome = {}

local oneIn: { [string]: number } = {}
local base: { [string]: number } = {}
do
	local ctx = RollMath.contextFor(RollRules, { FullLuck = 1 })
	for _, relic in RelicConfig.Relics do
		local p = RollMath.itemProbability(ctx, relic.Id)
		oneIn[relic.Id] = if p > 0 then 1 / p else math.huge
		base[relic.Id] = Economy.relicBaseIncome(Config.Economy, oneIn[relic.Id], (relic :: any).IncomeBonus)
	end
end

-- 1-in-X base odds of a relic (math.huge if unknown).
function RelicIncome.oneIn(relicId: string): number
	return oneIn[relicId] or math.huge
end

-- Base CE/sec of a relic without a mutation (0 if unknown).
function RelicIncome.base(relicId: string): number
	return base[relicId] or 0
end

-- CE/sec of a relic with an optional mutation, before pedestal and global multipliers.
function RelicIncome.of(relicId: string, mutationId: string?): number
	local mutation = mutationId and MutationConfig.ById[mutationId]
	return Economy.relicIncome(RelicIncome.base(relicId), if mutation then mutation.IncomeMultiplier else 1)
end

return RelicIncome
