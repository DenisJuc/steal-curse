-- Pure shrine economy formulas (GDD 6). Settings are passed in (Config.Economy / Config.Offline),
-- so Lune tests and simulations use exactly the same math as the server.

local Economy = {}

export type EconomySettings = {
	TierIncomePerMin: { [string]: number },
	SlotPrices: { [number]: number },
	PedestalMaxLevel: number,
	FirstUpgradeCost: number,
	UpgradeCostGrowth: number,
	SellFraction: number,
}

export type OfflineSettings = {
	Rate: number,
	CapSeconds: number,
	MinSeconds: number,
}

-- Level 1 -> x1, max level -> x2, linear in between.
function Economy.pedestalMultiplier(settings: EconomySettings, level: number): number
	return 1 + (level - 1) / (settings.PedestalMaxLevel - 1)
end

-- CE to go from `level` to `level + 1`.
function Economy.upgradeCost(settings: EconomySettings, level: number): number
	return settings.FirstUpgradeCost * settings.UpgradeCostGrowth ^ (level - 1)
end

-- Total CE to go from `fromLevel` up to `toLevel`.
function Economy.upgradeCostRange(settings: EconomySettings, fromLevel: number, toLevel: number): number
	local total = 0
	for level = fromLevel, toLevel - 1 do
		total += Economy.upgradeCost(settings, level)
	end
	return total
end

-- How many levels `budget` buys from `level` (each intermediate cost is checked), and the total cost.
function Economy.maxAffordableUpgrades(settings: EconomySettings, level: number, budget: number): (number, number)
	local levels, cost = 0, 0
	while level + levels < settings.PedestalMaxLevel do
		local nextCost = Economy.upgradeCost(settings, level + levels)
		if cost + nextCost > budget then
			break
		end
		cost += nextCost
		levels += 1
	end
	return levels, cost
end

-- Base CE/min of one relic before its pedestal and global multipliers.
function Economy.relicIncome(settings: EconomySettings, tierId: string, mutationMultiplier: number): number
	return (settings.TierIncomePerMin[tierId] or 0) * mutationMultiplier
end

-- contributions = relic income x pedestal multiplier for each displayed relic.
function Economy.totalIncome(contributions: { number }, incomeMultiplier: number): number
	local sum = 0
	for _, value in contributions do
		sum += value
	end
	return sum * incomeMultiplier
end

function Economy.sellValue(settings: EconomySettings, relicIncome: number, merchantBonus: number): number
	return settings.SellFraction * relicIncome * (1 + merchantBonus)
end

function Economy.offlineEarnings(settings: OfflineSettings, incomePerMin: number, elapsedSeconds: number): number
	if elapsedSeconds < settings.MinSeconds or incomePerMin <= 0 then
		return 0
	end
	local paidSeconds = math.min(elapsedSeconds, settings.CapSeconds)
	return settings.Rate * incomePerMin * paidSeconds / 60
end

export type SlotView = {
	Locked: boolean,
	-- Relic income of the currently displayed relic (0 when empty).
	Income: number,
	Multiplier: number,
}

-- Auto-display: the slot where `newIncome` raises CE/min the most. Locked slots are never touched.
-- Returns nil unless the improvement is strictly positive.
function Economy.bestDisplaySlot(slots: { SlotView }, newIncome: number): (number?, number)
	local bestSlot, bestGain = nil, 0
	for index, slot in slots do
		if not slot.Locked then
			local gain = (newIncome - slot.Income) * slot.Multiplier
			if gain > bestGain then
				bestSlot, bestGain = index, gain
			end
		end
	end
	return bestSlot, bestGain
end

return Economy
