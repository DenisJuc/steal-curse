-- Mirror of src/shared/RelicIncome for Lune (that module needs Roblox `script`).

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local MutationConfig = require("../../src/shared/MutationConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local rules = require("./rules")

local RelicIncome = {}

local oneIn: { [string]: number } = {}
local base: { [string]: number } = {}
do
	local ctx = RollMath.contextFor(rules, { FullLuck = 1 })
	for _, relic in RelicConfig.Relics do
		local p = RollMath.itemProbability(ctx, relic.Id)
		oneIn[relic.Id] = if p > 0 then 1 / p else math.huge
		base[relic.Id] = Economy.relicBaseIncome(Config.Economy, oneIn[relic.Id], (relic :: any).IncomeBonus)
	end
end

function RelicIncome.oneIn(relicId: string): number
	return oneIn[relicId] or math.huge
end

function RelicIncome.base(relicId: string): number
	return base[relicId] or 0
end

function RelicIncome.of(relicId: string, mutationId: string?): number
	local mutation = mutationId and MutationConfig.ById[mutationId]
	return Economy.relicIncome(RelicIncome.base(relicId), if mutation then mutation.IncomeMultiplier else 1)
end

return RelicIncome
