-- Config sanity: tiers, relic roster and placeholder rules.

local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local expect = require("../lib/expect")

return {
	{
		Name = "config has no validation problems",
		Run = function()
			local problems = RollMath.validate(RarityConfig.Tiers, RelicConfig.Relics)
			expect.equal(#problems, 0, table.concat(problems, "; "))
		end,
	},
	{
		Name = "eight tiers in GDD order",
		Run = function()
			local expected = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }
			expect.equal(#RarityConfig.Tiers, #expected, "tier count")
			for index, id in expected do
				expect.equal(RarityConfig.Tiers[index].Id, id, `tier {index}`)
			end
		end,
	},
	{
		Name = "slice 0 has exactly 10 placeholder relics covering every tier",
		Run = function()
			expect.equal(#RelicConfig.Relics, 10, "relic count")
			local byTier = RollMath.groupByTier(RelicConfig.Relics)
			for _, tier in RarityConfig.Tiers do
				expect.truthy(byTier[tier.Id], `tier {tier.Id} has a relic`)
			end
		end,
	},
	{
		Name = "every relic uses a known family and object type",
		Run = function()
			local families = {}
			for _, family in RelicConfig.Families do
				families[family] = true
			end
			local objectTypes = {}
			for _, objectType in RelicConfig.ObjectTypes do
				objectTypes[objectType] = true
			end
			for _, relic in RelicConfig.Relics do
				expect.truthy(families[relic.Family], `{relic.Id} family {relic.Family}`)
				expect.truthy(objectTypes[relic.ObjectType], `{relic.Id} object type {relic.ObjectType}`)
				expect.truthy(RelicConfig.ById[relic.Id] == relic, `{relic.Id} lookup`)
			end
		end,
	},
}
