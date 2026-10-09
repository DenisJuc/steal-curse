-- Second-by-second AFK shrine simulation at base luck, using the real roll math, income bands,
-- prices, and a player who keeps their best relics equipped (as if pressing Equip Best after
-- every better find). A pacing check for GDD 6.8, not a balance verdict: skill tree
-- upgrades (scan speed, Core Luck) arrive later and will speed this up.
-- Spending policy: buy the next pedestal when affordable; otherwise buy the cheapest pedestal
-- level only if it costs at most UpgradeBudgetShare of the next pedestal price.

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local RollMath = require("../../src/shared/RollMath")
local rules = require("./rules")

local EconomySim = {}

export type Options = {
	Seed: number,
	ScanSeconds: number,
	Hours: number,
	UpgradeBudgetShare: number?,
}

export type Result = {
	SlotBoughtAt: { [number]: number },
	FinalIncomePerMin: number,
	LifetimeCE: number,
}

function EconomySim.run(options: Options): Result
	local settings = Config.Economy
	math.randomseed(options.Seed)
	local nextNumber = math.random
	local ctx = RollMath.contextFor(rules, { FullLuck = 1 })
	local share = options.UpgradeBudgetShare or 0.1

	local slots = {}
	for _ = 1, Config.Plots.StartingPedestals do
		table.insert(slots, { Locked = false, Income = 0, Level = 1, Multiplier = 1 })
	end
	local spare: { number } = {}
	local ce, lifetime = 0, 0
	local boughtAt = {}

	local function place(income: number)
		local candidate = income
		local filled = {}
		for _ = 1, #slots do
			local views = {}
			for index, slot in slots do
				views[index] = { Locked = filled[index] == true, Income = slot.Income, Multiplier = slot.Multiplier }
			end
			local index = Economy.bestDisplaySlot(views, candidate)
			if not index then
				table.insert(spare, candidate)
				return
			end
			local displaced = slots[index].Income
			slots[index].Income = candidate
			filled[index] = true
			if displaced <= 0 then
				return
			end
			candidate = displaced
		end
		table.insert(spare, candidate)
	end

	local function incomePerMin(): number
		local contributions = {}
		for _, slot in slots do
			table.insert(contributions, slot.Income * slot.Multiplier)
		end
		return Economy.totalIncome(contributions, 1)
	end

	local totalSeconds = math.floor(options.Hours * 3600)
	for second = 1, totalSeconds do
		if second % options.ScanSeconds == 0 then
			local relic = RollMath.roll(ctx, nextNumber)
			place(Economy.relicIncome(settings, relic.Tier, 1))
		end
		local earned = incomePerMin() / 60
		ce += earned
		lifetime += earned

		local nextSlot = #slots + 1
		local price = settings.SlotPrices[nextSlot]
		if price and ce >= price then
			ce -= price
			boughtAt[nextSlot] = second
			table.insert(slots, { Locked = false, Income = 0, Level = 1, Multiplier = 1 })
			table.sort(spare, function(a, b)
				return a > b
			end)
			local best = table.remove(spare, 1)
			if best then
				place(best)
			end
		else
			local cheapest, cheapestCost = nil, math.huge
			for _, slot in slots do
				if slot.Level < settings.PedestalMaxLevel and slot.Income > 0 then
					local cost = Economy.upgradeCost(settings, slot.Level)
					if cost < cheapestCost then
						cheapest, cheapestCost = slot, cost
					end
				end
			end
			local limit = if price then price * share else math.huge
			if cheapest and cheapestCost <= ce and cheapestCost <= limit then
				ce -= cheapestCost
				cheapest.Level += 1
				cheapest.Multiplier = Economy.pedestalMultiplier(settings, cheapest.Level)
			end
		end
	end

	return { SlotBoughtAt = boughtAt, FinalIncomePerMin = incomePerMin(), LifetimeCE = lifetime }
end

return EconomySim
