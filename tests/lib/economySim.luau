-- Second-by-second AFK progression simulation with the real roll math, relic incomes, prices,
-- skills and Rebirth. The simulated player auto-rolls, keeps their best relics on the pedestals
-- (Auto-equip), auto-sells duplicate Common-Rare finds (the default rules) and spends CE on the
-- cheapest thing they can afford: the next pedestal, a pedestal level, Core Luck, Scan Speed or
-- Energy Conduction (the eager player who bought x800 luck in 5 minutes). They stop spending to
-- save for a Rebirth once it is within SaveSeconds of income, and rebirth as soon as they can.
-- Hunting is ignored (an active player gets there faster). Report: lune run tests/economyReport

local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local Formulas = require("../../src/shared/Formulas")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local SkillConfig = require("../../src/shared/SkillConfig")
local relicIncome = require("./relicIncome")
local rules = require("./rules")

local EconomySim = {}

export type Options = {
	Seed: number,
	Hours: number,
	-- Minutes at which to record a snapshot.
	Checkpoints: { number }?,
	-- Save for a Rebirth when it is this many seconds of income away (default 600).
	SaveSeconds: number?,
	Rebirth: boolean?,
}

export type Snapshot = {
	Minute: number,
	CE: number,
	LifetimeCE: number,
	IncomePerSec: number,
	Luck: number,
	Rebirths: number,
	CoreLuckRank: number,
	ScanSeconds: number,
	Slots: number,
	BestTier: string,
	SoldCE: number,
}

export type Result = {
	Snapshots: { Snapshot },
	SlotBoughtAt: { [number]: number },
	FirstRebirthAt: number?,
	RebirthsAt: { number },
	LifetimeCE: number,
	SoldCE: number,
	PedestalCE: number,
}

local SELL_MAX_TIER = RarityConfig.IndexById.Rare

function EconomySim.run(options: Options): Result
	local settings = Config.Economy
	local rebirthSettings = Config.Rebirth
	-- Park-Miller generator: reproducible per seed (math.random after a small seed starts badly).
	local state = (options.Seed * 7919 + 12345) % 2147483647
	local function nextNumber(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local saveSeconds = options.SaveSeconds or 600
	local doRebirth = options.Rebirth ~= false
	local checkpoints = options.Checkpoints or { 5, 10, 20, 30, 40, 60, 90, 120 }
	local nodes = SkillConfig.ById

	local ce, lifetime, soldCE, pedestalCE = 0, 0, 0, 0
	local rebirths = 0
	local skills = { CoreLuck = 0, ScanSpeed = 0, EnergyConduction = 0 }
	local levels: { number } = {}
	for _ = 1, Config.Plots.StartingPedestals do
		table.insert(levels, 1)
	end
	-- Every relic income held (displayed or not, best first); only the top #levels earn.
	local held: { number } = {}
	local seen: { [string]: boolean } = {}
	local bestTier = 1
	local boughtAt: { [number]: number } = {}
	local rebirthsAt: { number } = {}
	local now = 0

	local ctx, ctxLuck = nil, -1
	local function luck(): number
		return Formulas.coreLuck(skills.CoreLuck) * Rebirth.luckMultiplier(rebirthSettings, rebirths)
	end
	local function context()
		local current = luck()
		if current ~= ctxLuck then
			ctx = RollMath.contextFor(rules, { FullLuck = current })
			ctxLuck = current
		end
		return ctx
	end

	local function multipliers(): { number }
		local list = {}
		for index, level in levels do
			list[index] = Economy.pedestalMultiplier(settings, level)
		end
		table.sort(list, function(a, b)
			return a > b
		end)
		return list
	end
	local function incomePerSec(): number
		local mults = multipliers()
		local contributions = {}
		for index, mult in mults do
			table.insert(contributions, (held[index] or 0) * mult)
		end
		local global = (1 + SkillConfig.incomeBonus(skills.EnergyConduction))
			* Rebirth.incomeMultiplier(rebirthSettings, rebirths)
		return Economy.totalIncome(contributions, global)
	end

	local function insertHeld(income: number)
		local index = #held + 1
		for i, value in held do
			if income > value then
				index = i
				break
			end
		end
		table.insert(held, index, income)
		-- Only the earning top matters; drop the long tail to keep the sim fast.
		while #held > Config.Plots.MaxPedestals do
			table.remove(held)
		end
	end

	local function roll()
		local relic = RollMath.roll(context(), nextNumber)
		local income = relicIncome.base(relic.Id)
		local tier = RarityConfig.IndexById[relic.Tier]
		bestTier = math.max(bestTier, tier)
		local displayedFloor = if #held >= #levels then held[#levels] else -1
		if seen[relic.Id] and tier <= SELL_MAX_TIER and income <= displayedFloor then
			local value = Economy.sellValue(settings, income, 0)
			ce += value
			lifetime += value
			soldCE += value
		else
			seen[relic.Id] = true
			insertHeld(income)
		end
	end

	type Option = { Cost: number, Buy: () -> () }
	local function options_(): { Option }
		local list: { Option } = {}
		local nextSlot = #levels + 1
		local price = settings.SlotPrices[nextSlot]
		if price and nextSlot <= Config.Plots.MaxPedestals then
			table.insert(list, {
				Cost = price,
				Buy = function()
					table.insert(levels, 1)
					boughtAt[nextSlot] = boughtAt[nextSlot] or now
				end,
			})
		end
		local lowest, lowestIndex = math.huge, nil
		for index, level in levels do
			if level < settings.PedestalMaxLevel and level < lowest then
				lowest, lowestIndex = level, index
			end
		end
		if lowestIndex and #held >= 1 then
			table.insert(list, {
				Cost = Economy.upgradeCost(settings, lowest),
				Buy = function()
					levels[lowestIndex] += 1
				end,
			})
		end
		for id in skills do
			local cost = SkillConfig.cost(nodes[id], skills[id])
			if cost then
				table.insert(list, {
					Cost = cost,
					Buy = function()
						skills[id] += 1
					end,
				})
			end
		end
		return list
	end

	local snapshots: { Snapshot } = {}
	local nextCheckpoint = 1
	local scanTimer = 0
	local firstRebirth: number? = nil
	local totalSeconds = math.floor(options.Hours * 3600)
	for second = 1, totalSeconds do
		now = second
		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			roll()
		end
		local income = incomePerSec()
		ce += income
		lifetime += income
		pedestalCE += income

		local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
		if doRebirth and ce >= rebirthCost then
			rebirths += 1
			table.insert(rebirthsAt, second)
			firstRebirth = firstRebirth or second
			ce = 0
			for index in levels do
				levels[index] = 1
			end
			for id in skills do
				skills[id] = 0
			end
		end
		local saving = doRebirth and rebirthCost - ce <= incomePerSec() * saveSeconds
		if not saving then
			for _ = 1, 500 do
				local cheapest: Option? = nil
				for _, option in options_() do
					if option.Cost <= ce and (not cheapest or option.Cost < cheapest.Cost) then
						cheapest = option
					end
				end
				if not cheapest then
					break
				end
				ce -= cheapest.Cost
				cheapest.Buy()
			end
		end

		local minute = checkpoints[nextCheckpoint]
		if minute and second == minute * 60 then
			nextCheckpoint += 1
			table.insert(snapshots, {
				Minute = minute,
				CE = ce,
				LifetimeCE = lifetime,
				IncomePerSec = incomePerSec(),
				Luck = luck(),
				Rebirths = rebirths,
				CoreLuckRank = skills.CoreLuck,
				ScanSeconds = SkillConfig.scanInterval(skills.ScanSpeed),
				Slots = #levels,
				BestTier = RarityConfig.Tiers[bestTier].Id,
				SoldCE = soldCE,
			})
		end
	end

	return {
		Snapshots = snapshots,
		SlotBoughtAt = boughtAt,
		FirstRebirthAt = firstRebirth,
		RebirthsAt = rebirthsAt,
		LifetimeCE = lifetime,
		SoldCE = soldCE,
		PedestalCE = pedestalCE,
	}
end

-- Unused-relic guard: every relic has an income (keeps the sim honest if the roster changes).
function EconomySim.allPriced(): boolean
	for _, relic in RelicConfig.Relics do
		if relicIncome.base(relic.Id) <= 0 then
			return false
		end
	end
	return true
end

return EconomySim
