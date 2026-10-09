-- Roll math: tier masses, per-relic odds, ladder sampler and a Monte Carlo check at 1x luck.

local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local expect = require("../lib/expect")

local tiers = RarityConfig.Tiers
local relics = RelicConfig.Relics

local LUCK_GRID = { 1, 10, 316, 1e5, 3.16e7, 1e10, 1.65e10, 4.95e10 }

local function constant(value: number): () -> number
	return function()
		return value
	end
end

return {
	{
		Name = "tier masses are non-negative and sum to 1 across the luck grid",
		Run = function()
			for _, luck in LUCK_GRID do
				local sum = 0
				for index, mass in RollMath.tierMasses(tiers, luck) do
					expect.truthy(mass >= 0, `negative mass at tier {index}, luck {luck}`)
					sum += mass
				end
				expect.near(sum, 1, 1e-12, `tier sum at luck {luck}`)
			end
		end,
	},
	{
		Name = "base tier masses match GDD cumulative odds at 1x",
		Run = function()
			local masses = RollMath.tierMasses(tiers, 1)
			expect.near(masses[1], 0.75, 1e-15, "Common")
			expect.near(masses[2], 1 / 4 - 1 / 45, 1e-15, "Uncommon")
			expect.near(masses[8], 1 / 1.32e15, 1e-30, "Cosmic")
		end,
	},
	{
		Name = "per-relic probabilities sum to 1 and every relic has distinct base odds",
		Run = function()
			for _, luck in LUCK_GRID do
				local sum = 0
				for _, relic in relics do
					sum += RollMath.itemProbability(tiers, relics, relic.Id, luck)
				end
				expect.near(sum, 1, 1e-12, `relic sum at luck {luck}`)
			end
			local seen = {}
			for _, relic in relics do
				local probability = RollMath.itemProbability(tiers, relics, relic.Id, 1)
				expect.truthy(probability > 0, `{relic.Id} has positive base chance`)
				expect.truthy(not seen[probability], `{relic.Id} base odds are unique`)
				seen[probability] = true
			end
		end,
	},
	{
		Name = "ladder sampler reaches every tier at its boundaries",
		Run = function()
			expect.equal(RollMath.rollTierIndex(tiers, 1, constant(0)), #tiers, "u=0 climbs to Cosmic")
			expect.equal(RollMath.rollTierIndex(tiers, 1, constant(0.999999)), 1, "u~1 stays Common")
			-- Just below the first step ratio (1/4) climbs one tier, then stops.
			local draws = { 0.2499, 0.9 }
			local i = 0
			local index = RollMath.rollTierIndex(tiers, 1, function()
				i += 1
				return draws[i]
			end)
			expect.equal(index, 2, "stops at Uncommon")
		end,
	},
	{
		Name = "Monte Carlo at 1x matches tier masses (200k rolls)",
		Run = function()
			math.randomseed(12345)
			local byTier = RollMath.groupByTier(relics)
			local counts = {}
			local rolls = 200000
			for _ = 1, rolls do
				local relic = RollMath.roll(tiers, byTier, 1, math.random)
				counts[relic.Tier] = (counts[relic.Tier] or 0) + 1
			end
			local masses = RollMath.tierMasses(tiers, 1)
			for index = 1, 3 do
				local p = masses[index]
				local observed = (counts[tiers[index].Id] or 0) / rolls
				local sigma = math.sqrt(p * (1 - p) / rolls)
				expect.near(observed, p, 5 * sigma, `{tiers[index].Id} frequency`)
			end
		end,
	},
	{
		Name = "max-boost any-Cosmic mean is about 7.41 h at 1 scan/s (GDD 5.2 anchor)",
		Run = function()
			local luck = 1e10 * 1.5 * 1.1 * 2 * 1.5
			local masses = RollMath.tierMasses(tiers, luck)
			local hours = 1 / masses[#tiers] / 3600
			expect.near(hours, 7.407, 0.01, "Cosmic mean hours")
		end,
	},
}
