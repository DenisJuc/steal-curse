-- Per-relic income (Economy.relicBaseIncome via RelicIncome): every relic earns from its own odds,
-- so relics in a tier differ, rarer relics earn more, and the tiers never overlap.

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local expect = require("../lib/expect")
local RelicIncome = require("../lib/relicIncome")

local function relicsOf(tierId: string): { RelicConfig.Relic }
	local list = {}
	for _, relic in RelicConfig.Relics do
		if relic.Tier == tierId then
			table.insert(list, relic)
		end
	end
	return list
end

return {
	{
		Name = "every relic has a positive income, distinct inside its tier",
		Run = function()
			for _, tier in RarityConfig.Tiers do
				local seen = {}
				local relics = relicsOf(tier.Id)
				for _, relic in relics do
					local income = RelicIncome.base(relic.Id)
					expect.truthy(income > 0, `{relic.Id} earns nothing`)
					seen[income] = seen[income] or {}
					table.insert(seen[income], relic.Id)
				end
				local distinct = 0
				for _ in seen do
					distinct += 1
				end
				-- Relics with exactly the same odds may share an income; others must not.
				expect.truthy(distinct >= math.ceil(#relics * 0.75), `{tier.Id}: only {distinct} incomes for {#relics} relics`)
			end
		end,
	},
	{
		Name = "rarer relics never earn less",
		Run = function()
			local relics = table.clone(RelicConfig.Relics)
			table.sort(relics, function(a, b)
				return RelicIncome.oneIn(a.Id) < RelicIncome.oneIn(b.Id)
			end)
			for index = 2, #relics do
				local rarer, common = relics[index], relics[index - 1]
				expect.truthy(
					RelicIncome.base(rarer.Id) >= RelicIncome.base(common.Id),
					`{rarer.Id} (1 in {RelicIncome.oneIn(rarer.Id)}) earns less than {common.Id}`
				)
			end
		end,
	},
	{
		Name = "tiers never overlap: the worst relic of a tier beats the best of the tier below",
		Run = function()
			for index = 2, #RarityConfig.Tiers do
				local tier, lower = RarityConfig.Tiers[index], RarityConfig.Tiers[index - 1]
				local lowest, highest = math.huge, 0
				for _, relic in relicsOf(tier.Id) do
					lowest = math.min(lowest, RelicIncome.base(relic.Id))
				end
				for _, relic in relicsOf(lower.Id) do
					highest = math.max(highest, RelicIncome.base(relic.Id))
				end
				expect.truthy(lowest > highest, `{tier.Id} min {lowest} <= {lower.Id} max {highest}`)
			end
		end,
	},
	{
		Name = "mutations multiply the income",
		Run = function()
			local relic = RelicConfig.Relics[1]
			for _, mutation in MutationConfig.Mutations do
				expect.near(
					RelicIncome.of(relic.Id, mutation.Id),
					RelicIncome.base(relic.Id) * mutation.IncomeMultiplier,
					1e-9,
					mutation.Id
				)
			end
			expect.equal(RelicIncome.of(relic.Id), RelicIncome.base(relic.Id), "no mutation")
		end,
	},
	{
		Name = "incomes read cleanly: 2 significant figures under 10, 3 from 10 up",
		Run = function()
			expect.equal(Economy.relicBaseIncome(Config.Economy, 1, nil), 1, "1 in 1")
			expect.equal(Economy.relicBaseIncome(Config.Economy, 0, nil), 0, "impossible")
			expect.equal(Economy.relicBaseIncome(Config.Economy, math.huge, nil), 0, "never")
			for _, relic in RelicConfig.Relics do
				local income = RelicIncome.base(relic.Id)
				local digits = if income < 10 then 2 else 3
				local scale = 10 ^ (math.floor(math.log10(income)) - digits + 1)
				expect.near(income / scale, math.floor(income / scale + 0.5), 1e-6, `{relic.Id} = {income}`)
			end
		end,
	},
}
