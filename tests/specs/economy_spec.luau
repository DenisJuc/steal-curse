-- Shrine economy formulas (GDD 6): pedestal costs and multipliers, income, selling, offline pay,
-- the Equip Best assignment, and the pacing targets of the progression sim (tests/lib/economySim).

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local expect = require("../lib/expect")
local EconomySim = require("../lib/economySim")

local settings = Config.Economy

-- The sim is deterministic per seed; three seeds cover a lucky, a typical and a slow start.
local SEEDS = { 1, 2, 3 }
local simResults: { [number]: EconomySim.Result } = {}
local function sim(seed: number): EconomySim.Result
	if not simResults[seed] then
		simResults[seed] = EconomySim.run({ Seed = seed, Hours = 2 })
	end
	return simResults[seed]
end

local function snapshotAt(result: EconomySim.Result, minute: number): EconomySim.Snapshot
	for _, snapshot in result.Snapshots do
		if snapshot.Minute == minute then
			return snapshot
		end
	end
	error(`no snapshot at {minute} min`)
end

return {
	{
		Name = "pedestal upgrades: 50 levels, whole-CE costs growing by UpgradeCostGrowth",
		Run = function()
			expect.equal(settings.PedestalMaxLevel, 50, "max level")
			expect.equal(Economy.upgradeCost(settings, 1), settings.FirstUpgradeCost, "level 1 -> 2")
			for level = 2, settings.PedestalMaxLevel - 1 do
				local cost = Economy.upgradeCost(settings, level)
				local previous = Economy.upgradeCost(settings, level - 1)
				expect.equal(cost, math.floor(cost), `level {level} cost is whole`)
				expect.truthy(cost > previous, `level {level} costs more`)
				expect.near(cost / previous, settings.UpgradeCostGrowth, 0.05, `level {level} growth`)
			end
			local total = Economy.upgradeCostRange(settings, 1, settings.PedestalMaxLevel)
			expect.truthy(total > 1e6 and total < 1e9, `full pedestal costs {total}`)
		end,
	},
	{
		Name = "pedestal multiplier is x1 at level 1 and multiplies by LevelGrowth every level",
		Run = function()
			expect.equal(Economy.pedestalMultiplier(settings, 1), 1, "level 1")
			for level = 2, settings.PedestalMaxLevel do
				expect.near(
					Economy.pedestalMultiplier(settings, level) / Economy.pedestalMultiplier(settings, level - 1),
					settings.LevelGrowth,
					1e-9,
					`level {level}`
				)
			end
			local top = Economy.pedestalMultiplier(settings, settings.PedestalMaxLevel)
			expect.truthy(top > 50 and top < 200, `level 50 is about x100 (got x{top})`)
		end,
	},
	{
		Name = "max-buy checks every intermediate cost",
		Run = function()
			local first, second = Economy.upgradeCost(settings, 1), Economy.upgradeCost(settings, 2)
			local levels, cost = Economy.maxAffordableUpgrades(settings, 1, first + second - 1)
			expect.equal(levels, 1, "one CE short of two levels")
			expect.equal(cost, first, "one level cost")
			levels, cost = Economy.maxAffordableUpgrades(settings, 1, first + second)
			expect.equal(levels, 2, "exact budget buys two")
			expect.equal(cost, first + second, "two levels cost")
			levels, cost = Economy.maxAffordableUpgrades(settings, 1, 1e30)
			expect.equal(levels, settings.PedestalMaxLevel - 1, "huge budget stops at max level")
			expect.equal(cost, Economy.upgradeCostRange(settings, 1, settings.PedestalMaxLevel), "full cost")
			levels = Economy.maxAffordableUpgrades(settings, settings.PedestalMaxLevel, 1e30)
			expect.equal(levels, 0, "already max")
			levels = Economy.maxAffordableUpgrades(settings, 3, 0)
			expect.equal(levels, 0, "no CE")
		end,
	},
	{
		Name = "only slots 4-6 cost anything, each much more than the last",
		Run = function()
			for slot = 1, Config.Plots.StartingPedestals do
				expect.equal(settings.SlotPrices[slot], nil, `slot {slot} is free`)
			end
			expect.equal(Config.Plots.MaxPedestals, 6, "six pedestals max")
			for slot = Config.Plots.StartingPedestals + 2, Config.Plots.MaxPedestals do
				expect.truthy(settings.SlotPrices[slot] >= 10 * settings.SlotPrices[slot - 1], `slot {slot} price jump`)
			end
		end,
	},
	{
		Name = "income: relic x mutation x pedestal, summed, then one global multiplier",
		Run = function()
			expect.equal(Economy.relicIncome(42, 1), 42, "plain")
			expect.equal(Economy.relicIncome(42, 3), 126, "mutated")
			local contributions = {
				Economy.relicIncome(100, 2) * Economy.pedestalMultiplier(settings, 1),
				Economy.relicIncome(5, 1) * Economy.pedestalMultiplier(settings, 1),
			}
			expect.near(Economy.totalIncome(contributions, 1), 205, 1e-9, "no global bonus")
			expect.near(Economy.totalIncome(contributions, 1.2), 246, 1e-9, "+20% global")
			expect.equal(Economy.totalIncome({}, 2), 0, "nothing displayed")
		end,
	},
	{
		Name = "selling pays SellSeconds of the relic's income and keeps fractions",
		Run = function()
			expect.equal(settings.SellSeconds, 30, "30 seconds")
			expect.near(Economy.sellValue(settings, 5.1, 0), 153, 1e-9, "Common at 5.1/s")
			expect.near(Economy.sellValue(settings, 0.05, 0), 1.5, 1e-12, "fractions kept")
			expect.near(Economy.sellValue(settings, 100, 0.5), 4500, 1e-9, "+50% merchant")
		end,
	},
	{
		Name = "offline pays 25% of the per-second snapshot, capped at 2 hours, nothing under a minute",
		Run = function()
			local offline = Config.Offline
			expect.near(Economy.offlineEarnings(offline, 30, 3600), 0.25 * 30 * 3600, 1e-9, "1 hour")
			expect.near(Economy.offlineEarnings(offline, 30, 36000), 0.25 * 30 * 7200, 1e-9, "10 hours capped")
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
			expect.equal(slot, 2, "prefers the higher-level pedestal when that raises CE/sec more")

			local allLocked = { { Locked = true, Income = 0, Multiplier = 1 } }
			expect.equal(Economy.bestDisplaySlot(allLocked, 1e9), nil, "locked slots are never replaced")
		end,
	},
	{
		Name = "pacing: luck stays modest early and pedestal 4 comes within a few minutes",
		Run = function()
			expect.truthy(EconomySim.allPriced(), "every relic has an income")
			for _, seed in SEEDS do
				local result = sim(seed)
				local five = snapshotAt(result, 5)
				expect.truthy(five.Luck <= 20, `seed {seed}: luck x{five.Luck} at 5 min`)
				local slot4 = result.SlotBoughtAt[4]
				expect.truthy(slot4 ~= nil and slot4 <= 10 * 60, `seed {seed}: pedestal 4 at {(slot4 or 0) / 60} min`)
			end
		end,
	},
	{
		Name = "pacing: millions by 20 min, first Rebirth in 20-45 min, billions by 1 h, 100B+ by 2 h",
		Run = function()
			for _, seed in SEEDS do
				local result = sim(seed)
				local twenty = snapshotAt(result, 20)
				expect.truthy(twenty.LifetimeCE >= 1e6, `seed {seed}: {twenty.LifetimeCE} CE by 20 min`)
				local first = result.FirstRebirthAt
				expect.truthy(first ~= nil, `seed {seed}: no Rebirth in 2 hours`)
				expect.truthy(
					(first :: number) >= 20 * 60 and (first :: number) <= 45 * 60,
					`seed {seed}: first Rebirth at {(first :: number) / 60} min`
				)
				expect.truthy(snapshotAt(result, 60).LifetimeCE >= 1e9, `seed {seed}: billions by 1 h`)
				expect.truthy(snapshotAt(result, 120).LifetimeCE >= 1e11, `seed {seed}: 100B+ by 2 h`)
			end
		end,
	},
	{
		Name = "pacing: selling is a drip, far below pedestal income",
		Run = function()
			for _, seed in SEEDS do
				local result = sim(seed)
				expect.truthy(result.SoldCE < 0.05 * result.PedestalCE, `seed {seed}: sold {result.SoldCE}`)
			end
		end,
	},
}
