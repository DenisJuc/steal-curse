-- Shrine economy formulas (GDD 6): pedestal costs and multipliers, income, selling, offline pay,
-- and the Equip Best assignment.

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local expect = require("../lib/expect")
local EconomySim = require("../lib/economySim")

local settings = Config.Economy

return {
	{
		Name = "pedestal upgrades cost 500 doubling to 128K, 255,500 CE per max pedestal",
		Run = function()
			local expected = { 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 128000 }
			for level, cost in expected do
				expect.equal(Economy.upgradeCost(settings, level), cost, `level {level} -> {level + 1}`)
			end
			expect.equal(Economy.upgradeCostRange(settings, 1, settings.PedestalMaxLevel), 255500, "total")
		end,
	},
	{
		Name = "pedestal multiplier is x1 at level 1, x2 at level 10, rising every level",
		Run = function()
			expect.equal(Economy.pedestalMultiplier(settings, 1), 1, "level 1")
			expect.near(Economy.pedestalMultiplier(settings, 10), 2, 1e-12, "level 10")
			for level = 2, 10 do
				expect.truthy(
					Economy.pedestalMultiplier(settings, level) > Economy.pedestalMultiplier(settings, level - 1),
					`level {level} rises`
				)
			end
		end,
	},
	{
		Name = "max-buy checks every intermediate cost",
		Run = function()
			local levels, cost = Economy.maxAffordableUpgrades(settings, 1, 1499)
			expect.equal(levels, 1, "1499 buys one level")
			expect.equal(cost, 500, "1499 cost")
			levels, cost = Economy.maxAffordableUpgrades(settings, 1, 1500)
			expect.equal(levels, 2, "1500 buys two levels")
			expect.equal(cost, 1500, "1500 cost")
			levels, cost = Economy.maxAffordableUpgrades(settings, 1, 1e12)
			expect.equal(levels, 9, "huge budget stops at max level")
			expect.equal(cost, 255500, "full cost")
			levels = Economy.maxAffordableUpgrades(settings, 10, 1e12)
			expect.equal(levels, 0, "already max")
			levels = Economy.maxAffordableUpgrades(settings, 3, 0)
			expect.equal(levels, 0, "no CE")
		end,
	},
	{
		Name = "slot prices are 500 / 15K / 250K and only slots 4-6 cost anything",
		Run = function()
			expect.equal(settings.SlotPrices[4], 500, "slot 4")
			expect.equal(settings.SlotPrices[5], 15000, "slot 5")
			expect.equal(settings.SlotPrices[6], 250000, "slot 6")
			for slot = 1, Config.Plots.StartingPedestals do
				expect.equal(settings.SlotPrices[slot], nil, `slot {slot} is free`)
			end
			expect.equal(Config.Plots.MaxPedestals, 6, "six pedestals max")
		end,
	},
	{
		Name = "income uses tier band x mutation x pedestal, then one global multiplier",
		Run = function()
			for index = 2, #RarityConfig.Tiers do
				local tier, lower = RarityConfig.Tiers[index], RarityConfig.Tiers[index - 1]
				expect.truthy(
					settings.TierIncomePerMin[tier.Id] > settings.TierIncomePerMin[lower.Id],
					`{tier.Id} earns more than {lower.Id}`
				)
			end
			local abyssal = MutationConfig.ById.Abyssal.IncomeMultiplier
			local cosmic = Economy.relicIncome(settings, "Cosmic", abyssal)
			expect.equal(cosmic, 80000, "Abyssal Cosmic base")
			local contributions = {
				cosmic * Economy.pedestalMultiplier(settings, 10),
				Economy.relicIncome(settings, "Common", 1) * Economy.pedestalMultiplier(settings, 1),
			}
			expect.near(Economy.totalIncome(contributions, 1), 160010, 1e-9, "no global bonus")
			expect.near(Economy.totalIncome(contributions, 1.25), 200012.5, 1e-9, "+25% global")
			expect.equal(Economy.totalIncome({}, 2), 0, "nothing displayed")
		end,
	},
	{
		Name = "selling pays 1% of a minute of income and keeps fractions",
		Run = function()
			local common = Economy.sellValue(settings, Economy.relicIncome(settings, "Common", 1), 0)
			expect.near(common, 0.1, 1e-12, "Common sells for 0.1")
			local total = 0
			for _ = 1, 10 do
				total += common
			end
			expect.near(total, 1, 1e-9, "ten Commons add up to 1 CE")
			expect.near(Economy.sellValue(settings, 600, 0.5), 9, 1e-12, "Legendary with +50% merchant")
		end,
	},
	{
		Name = "offline pays 25% of the snapshot, capped at 2 hours, nothing under a minute",
		Run = function()
			local offline = Config.Offline
			expect.near(Economy.offlineEarnings(offline, 30, 3600), 0.25 * 30 * 60, 1e-9, "1 hour")
			expect.near(Economy.offlineEarnings(offline, 30, 36000), 0.25 * 30 * 120, 1e-9, "10 hours capped")
			expect.equal(Economy.offlineEarnings(offline, 30, 59), 0, "under a minute")
			expect.equal(Economy.offlineEarnings(offline, 30, -500), 0, "clock went backwards")
			expect.equal(Economy.offlineEarnings(offline, 0, 3600), 0, "nothing displayed")
		end,
	},
	{
		Name = "Equip Best puts the best relics on the highest pedestals and skips locked ones",
		Run = function()
			local slots = {
				{ Locked = false, Multiplier = 1 },
				{ Locked = true, Multiplier = 2 },
				{ Locked = false, Multiplier = 1.5 },
				{ Locked = false, Multiplier = 1 },
			}
			local candidates = {
				{ Key = 1, Income = 10 },
				{ Key = 2, Income = 600 },
				{ Key = 3, Income = 75 },
				{ Key = 4, Income = 200 },
			}
			local plan = Economy.equipBest(slots, candidates)
			expect.equal(plan[2], nil, "locked slot untouched")
			expect.equal(plan[3], 2, "best relic on the highest unlocked multiplier")
			expect.equal(plan[1], 4, "second best on the next slot (lower index wins ties)")
			expect.equal(plan[4], 3, "third best on the last slot")

			local few = Economy.equipBest(slots, { { Key = 9, Income = 5 } })
			expect.equal(few[3], 9, "a single relic goes on the best slot")
			expect.equal(few[1], nil, "other unlocked slots stay empty")

			local tie = Economy.equipBest({ { Locked = false, Multiplier = 1 } }, {
				{ Key = 1, Income = 10 },
				{ Key = 2, Income = 10, Shown = true },
			})
			expect.equal(tie[1], 2, "on equal income the already-equipped copy stays")
		end,
	},
	{
		Name = "pacing helper only makes strictly positive swaps and never touches locked slots",
		Run = function()
			local slots = {
				{ Locked = false, Income = 75, Multiplier = 1 },
				{ Locked = true, Income = 0, Multiplier = 2 },
				{ Locked = false, Income = 0, Multiplier = 1 },
			}
			local slot, gain = Economy.bestDisplaySlot(slots, 25)
			expect.equal(slot, 3, "fills the empty unlocked slot, not the locked one")
			expect.equal(gain, 25, "gain")

			slots[3].Income = 25
			expect.equal(Economy.bestDisplaySlot(slots, 25), nil, "equal income is not an improvement")
			expect.equal(Economy.bestDisplaySlot(slots, 10), nil, "worse relic is never displayed")

			local upgraded = {
				{ Locked = false, Income = 0, Multiplier = 1 },
				{ Locked = false, Income = 10, Multiplier = 2 },
			}
			slot = Economy.bestDisplaySlot(upgraded, 200)
			expect.equal(slot, 2, "prefers the higher-level pedestal when that raises CE/min more")

			local allLocked = { { Locked = true, Income = 0, Multiplier = 1 } }
			expect.equal(Economy.bestDisplaySlot(allLocked, 1e9), nil, "locked slots are never replaced")
		end,
	},
	{
		Name = "base pacing: pedestal 4 is reachable early (GDD 6.8: about 10-15 min)",
		Run = function()
			local result = EconomySim.run({ Seed = 7, ScanSeconds = Config.Scan.BaseIntervalSeconds, Hours = 1 })
			local slot4 = result.SlotBoughtAt[4]
			expect.truthy(slot4 ~= nil, "pedestal 4 bought within the first hour")
			expect.truthy(slot4 <= 20 * 60, `pedestal 4 took {slot4 / 60} min`)
		end,
	},
}
