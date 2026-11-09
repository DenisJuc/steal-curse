-- Rebirth pacing sweep (SIMULATION). For each candidate Rebirth curve, runs the core-loop sim for
-- a few hours and prints when each Rebirth lands (median over seeds) and the gaps between them.
-- Goal (Rosselle, 2026-11-08): several Rebirths early, then more and more spaced out.
-- Run: lune run tests/rebirthPacing
-- "Additive" rewards: income x(1 + IncomeStep * n) and luck x(1 + LuckStep * n) instead of
-- IncomeGrowth ^ n / LuckGrowth ^ n, so each Rebirth gives a little less than the one before.

local Config = require("../src/shared/Config")
local Rebirth = require("../src/shared/Rebirth")
local CoreLoop = require("./lib/coreLoopSim")

local MINUTES = 480
local SEEDS = 6

local originalIncome = Rebirth.incomeMultiplier
local originalLuck = Rebirth.luckMultiplier
local originalCost = Rebirth.cost

type Curve = {
	Name: string,
	BaseCost: number,
	CostGrowth: number,
	IncomeGrowth: number?,
	LuckGrowth: number?,
	IncomeStep: number?,
	LuckStep: number?,
	-- Growth rises by this much after each Rebirth (cost_n = Base * prod of (G + step * i)).
	CostGrowthStep: number?,
}

local CURVES: { Curve } = {
	{ Name = "Today: 400M x4, income x2, luck x1.25", BaseCost = 4e8, CostGrowth = 4, IncomeGrowth = 2, LuckGrowth = 1.25 },
	{ Name = "Nov 8 proposal: 500K x10, x2 / x1.25", BaseCost = 5e5, CostGrowth = 10, IncomeGrowth = 2, LuckGrowth = 1.25 },
	{ Name = "F: 500K x6, income +50%/R, luck +10%/R", BaseCost = 5e5, CostGrowth = 6, IncomeStep = 0.5, LuckStep = 0.1 },
	{ Name = "G: 500K x8, income +50%/R, luck +10%/R", BaseCost = 5e5, CostGrowth = 8, IncomeStep = 0.5, LuckStep = 0.1 },
	{ Name = "H: 500K x10, income +50%/R, luck +10%/R", BaseCost = 5e5, CostGrowth = 10, IncomeStep = 0.5, LuckStep = 0.1 },
	{ Name = "I: 500K x10, income x1.5, luck x1.1", BaseCost = 5e5, CostGrowth = 10, IncomeGrowth = 1.5, LuckGrowth = 1.1 },
	{ Name = "K: 500K, growth 4 then +2 each R, +50%/R, +10%/R", BaseCost = 5e5, CostGrowth = 4, CostGrowthStep = 2, IncomeStep = 0.5, LuckStep = 0.1 },
	{ Name = "L: 300K, growth 3 then +2.5 each R, +50%/R, +10%/R", BaseCost = 3e5, CostGrowth = 3, CostGrowthStep = 2.5, IncomeStep = 0.5, LuckStep = 0.1 },
	{ Name = "M: 500K, growth 5 then +3 each R, +50%/R, +10%/R", BaseCost = 5e5, CostGrowth = 5, CostGrowthStep = 3, IncomeStep = 0.5, LuckStep = 0.1 },
}

local function median(list: { number }): number?
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.ceil(#sorted / 2)]
end

local function fmt(minutes: number?): string
	if not minutes then
		return "  -  "
	end
	if minutes >= 60 then
		return string.format("%4.1fh", minutes / 60)
	end
	return string.format("%4.0fm", minutes)
end

print(`=== REBIRTH PACING (SIMULATION, {MINUTES} min x {SEEDS} seeds, medians) ===\n`)
for _, curve in CURVES do
	Config.Rebirth.BaseCost = curve.BaseCost
	Config.Rebirth.CostGrowth = curve.CostGrowth
	Config.Rebirth.IncomeGrowth = curve.IncomeGrowth or 2
	Config.Rebirth.LuckGrowth = curve.LuckGrowth or 1.25
	if curve.CostGrowthStep then
		local base, growth, step = curve.BaseCost, curve.CostGrowth, curve.CostGrowthStep :: number
		Rebirth.cost = function(_, n)
			local cost = base
			for i = 0, n - 1 do
				cost *= growth + step * i
			end
			return cost
		end
	else
		Rebirth.cost = originalCost
	end
	if curve.IncomeStep then
		local incomeStep, luckStep = curve.IncomeStep :: number, curve.LuckStep or 0
		Rebirth.incomeMultiplier = function(_, n)
			return 1 + incomeStep * n
		end
		Rebirth.luckMultiplier = function(_, n)
			return 1 + luckStep * n
		end
	else
		Rebirth.incomeMultiplier = originalIncome
		Rebirth.luckMultiplier = originalLuck
	end

	local byIndex: { { number } } = {}
	local counts = {}
	local lucks = {}
	for s = 1, SEEDS do
		local result = CoreLoop.run({ Minutes = MINUTES, Seed = 4000 + s * 31 })
		table.insert(counts, result.Rebirths)
		table.insert(lucks, result.LuckEnd)
		for index, minute in result.RebirthTimes do
			byIndex[index] = byIndex[index] or {}
			table.insert(byIndex[index], minute)
		end
	end
	local times = {}
	for index = 1, 8 do
		-- Only report a Rebirth most seeds reached.
		local list = byIndex[index]
		times[index] = if list and #list * 2 >= SEEDS then median(list) else nil
	end
	local row, gaps = {}, {}
	for index = 1, 8 do
		table.insert(row, `R{index} {fmt(times[index])}`)
		if times[index] then
			table.insert(gaps, fmt(times[index] - (times[index - 1] or 0)))
		end
	end
	print(curve.Name)
	print("  " .. table.concat(row, "  "))
	print(`  gaps: {table.concat(gaps, " ")}   rebirths by 8h: {median(counts)}   luck at 8h: x{string.format("%.0f", median(lucks) or 0)}`)
	print("")
end

Rebirth.incomeMultiplier = originalIncome
Rebirth.luckMultiplier = originalLuck
Rebirth.cost = originalCost
