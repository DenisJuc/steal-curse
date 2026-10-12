-- ROLL reel strips (Slice 9): always land on the server result, tease rare tiers, sane timing.

local Config = require("../../src/shared/Config")
local RarityConfig = require("../../src/shared/RarityConfig")
local ReelStrip = require("../../src/shared/ReelStrip")
local RelicConfig = require("../../src/shared/RelicConfig")
local expect = require("../lib/expect")

local roster = {}
for _, relic in RelicConfig.Relics do
	table.insert(roster, { Id = relic.Id, Tier = relic.Tier })
end

local options = {
	Length = Config.Roll.StripLength,
	LandIndex = Config.Roll.LandIndex,
	TierWeights = Config.Roll.TeaserTierWeights,
}

return {
	{
		Name = "every strip stops on the server result",
		Run = function()
			math.randomseed(9)
			for _, relic in RelicConfig.Relics do
				local cards = ReelStrip.strip(relic.Id, math.random, roster, options)
				expect.equal(#cards, Config.Roll.StripLength, "strip length")
				expect.equal(cards[Config.Roll.LandIndex], relic.Id, "landing card")
				for index = 2, #cards do
					expect.truthy(cards[index] ~= cards[index - 1], `no repeated neighbour at {index}`)
				end
			end
		end,
	},
	{
		Name = "teasers over-sample rare tiers but stay mostly common",
		Run = function()
			math.randomseed(20261009)
			local rareIndex = RarityConfig.IndexById.Legendary
			local commonIndex = RarityConfig.IndexById.Rare
			local rare, common, total = 0, 0, 0
			for _ = 1, 400 do
				local cards = ReelStrip.strip("SenzoBean", math.random, roster, options)
				for index, id in cards do
					if index == Config.Roll.LandIndex then
						continue
					end
					local tier = RarityConfig.IndexById[RelicConfig.ById[id].Tier]
					total += 1
					if tier >= rareIndex then
						rare += 1
					elseif tier <= commonIndex then
						common += 1
					end
				end
			end
			expect.truthy(rare / total > 0.15, `Legendary+ teasers are visible ({rare / total})`)
			expect.truthy(common / total > 0.55, `most teasers are Rare or below ({common / total})`)
		end,
	},
	{
		Name = "every tier has a teaser weight",
		Run = function()
			for _, tier in RarityConfig.Tiers do
				expect.truthy((Config.Roll.TeaserTierWeights[tier.Id] or 0) > 0, tier.Id)
			end
		end,
	},
	{
		Name = "reel time follows the scan interval within its limits",
		Run = function()
			expect.near(ReelStrip.duration("Full", 1.5, Config.Roll), 0.9, 1e-9, "60% of 1.5 s")
			expect.equal(ReelStrip.duration("Full", 4, Config.Roll), Config.Roll.ReelMaxSeconds, "capped")
			expect.equal(ReelStrip.duration("Full", 0.2, Config.Roll), Config.Roll.ReelMinSeconds, "floor")
			expect.equal(ReelStrip.duration("Fast", 4, Config.Roll), Config.Roll.FastSeconds, "fast")
			expect.equal(ReelStrip.duration("Off", 4, Config.Roll), 0, "off")
		end,
	},
	{
		Name = "roll steps start at once, slow down and land on time",
		Run = function()
			local count, seconds = 12, 1.6
			expect.equal(ReelStrip.stepTime(1, count, seconds), 0, "first step right away")
			expect.near(ReelStrip.stepTime(count, count, seconds), seconds, 1e-9, "last step lands on time")
			expect.equal(ReelStrip.stepTime(1, 1, seconds), seconds, "a single step lands on time")
			local previousGap = 0
			for index = 2, count do
				local gap = ReelStrip.stepTime(index, count, seconds) - ReelStrip.stepTime(index - 1, count, seconds)
				expect.truthy(gap > previousGap, `gap {index} is longer than the one before`)
				previousGap = gap
			end
		end,
	},
}
