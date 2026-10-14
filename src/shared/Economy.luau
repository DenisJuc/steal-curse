-- Pure shrine economy formulas (GDD 6). Settings are passed in (Config.Economy / Config.Offline),
-- so Lune tests and simulations use exactly the same math as the server. Income is per second.

local Economy = {}

export type EconomySettings = {
	IncomeScale: number,
	IncomeExponent: number,
	SlotPrices: { [number]: number },
	PedestalMaxLevel: number,
	LevelGrowth: number,
	FirstUpgradeCost: number,
	UpgradeCostGrowth: number,
	SellSeconds: number,
}

export type OfflineSettings = {
	Rate: number,
	CapSeconds: number,
	MinSeconds: number,
}

-- Rounds to 2 significant figures below 10 and 3 from 10 up (5.1, 13.7, 42.6, 167, 1.67K...), so
-- incomes read cleanly while neighbours in a tier stay different.
local function roundIncome(value: number): number
	if value <= 0 then
		return 0
	end
	local digits = if value < 10 then 2 else 3
	local scale = 10 ^ (math.floor(math.log10(value)) - digits + 1)
	return math.floor(value / scale + 0.5) * scale
end

-- Base CE/sec of a relic from its base odds (1 in `oneIn` at luck 1): rarer relics earn more, also
-- inside a tier. `bonus` is an optional per-relic factor (RelicConfig IncomeBonus).
function Economy.relicBaseIncome(settings: EconomySettings, oneIn: number, bonus: number?): number
	if oneIn ~= oneIn or oneIn <= 0 or oneIn == math.huge then
		return 0
	end
	return roundIncome(settings.IncomeScale * oneIn ^ settings.IncomeExponent * (bonus or 1))
end

-- CE/sec of one relic before its pedestal and global multipliers.
function Economy.relicIncome(baseIncome: number, mutationMultiplier: number): number
	return baseIncome * mutationMultiplier
end

-- Level 1 -> x1; every level multiplies by LevelGrowth.
function Economy.pedestalMultiplier(settings: EconomySettings, level: number): number
	return settings.LevelGrowth ^ (level - 1)
end

-- CE to go from `level` to `level + 1`.
function Economy.upgradeCost(settings: EconomySettings, level: number): number
	return math.ceil(settings.FirstUpgradeCost * settings.UpgradeCostGrowth ^ (level - 1) - 1e-9)
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

-- contributions = relic income x pedestal multiplier for each displayed relic.
function Economy.totalIncome(contributions: { number }, incomeMultiplier: number): number
	local sum = 0
	for _, value in contributions do
		sum += value
	end
	return sum * incomeMultiplier
end

-- Selling pays SellSeconds of the relic's own income (mutation included, pedestals not).
function Economy.sellValue(settings: EconomySettings, relicIncome: number, merchantBonus: number): number
	return settings.SellSeconds * relicIncome * (1 + merchantBonus)
end

function Economy.offlineEarnings(settings: OfflineSettings, incomePerSec: number, elapsedSeconds: number): number
	if elapsedSeconds < settings.MinSeconds or incomePerSec <= 0 then
		return 0
	end
	local paidSeconds = math.min(elapsedSeconds, settings.CapSeconds)
	return settings.Rate * incomePerSec * paidSeconds
end

export type SlotView = {
	Locked: boolean,
	-- Relic income of the currently displayed relic (0 when empty).
	Income: number,
	Multiplier: number,
}

-- The slot where `newIncome` raises CE/sec the most (the Relics menu's Equip button). Locked slots
-- are never touched. Returns nil unless the improvement is strictly positive.
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

export type EquipSlot = { Locked: boolean, Multiplier: number }
-- Key identifies the relic (its Uid); Shown = currently on a pedestal (kept first on ties).
export type EquipCandidate = { Key: number, Income: number, Shown: boolean? }

-- Equip Best: the highest-income candidates go on the unlocked slots, the best relic on the
-- highest pedestal multiplier, which gives the largest total CE/sec. Locked slots are skipped
-- (their relics must not be in `candidates`). Returns [slot] = candidate Key for every unlocked
-- slot that gets a relic; unlocked slots missing from the result stay empty.
function Economy.equipBest(slots: { EquipSlot }, candidates: { EquipCandidate }): { [number]: number }
	local open = {}
	for index, slot in slots do
		if not slot.Locked then
			table.insert(open, index)
		end
	end
	table.sort(open, function(a, b)
		if slots[a].Multiplier ~= slots[b].Multiplier then
			return slots[a].Multiplier > slots[b].Multiplier
		end
		return a < b
	end)
	local sorted = table.clone(candidates)
	table.sort(sorted, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		if (a.Shown == true) ~= (b.Shown == true) then
			return a.Shown == true
		end
		return a.Key < b.Key
	end)
	local plan = {}
	for rank, slot in open do
		local candidate = sorted[rank]
		if candidate then
			plan[slot] = candidate.Key
		end
	end
	return plan
end

return Economy
