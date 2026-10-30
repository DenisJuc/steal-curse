-- Post-Rebirth ablation: run full-stack upgrader to Rebirth 1 (and optionally 2/3),
-- snapshot state, then simulate a 30-minute window under controlled ablations.
-- Frozen relic incomes. Candidate passed in (E20k provisional).

local Config = require("../../src/shared/Config")
local CodexConfig = require("../../src/shared/CodexConfig")
local Economy = require("../../src/shared/Economy")
local Formulas = require("../../src/shared/Formulas")
local ItemConfig = require("../../src/shared/ItemConfig")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local ShowcaseConfig = require("../../src/shared/ShowcaseConfig")
local SkillConfig = require("../../src/shared/SkillConfig")
local relicIncome = require("./relicIncome")
local ProgressionSweep = require("./progressionSweep")

-- Re-export for cost path clarity in window buys.
local function luckCost(rank: number, base: number, growth: number, softK: number?, softPower: number?): number
	if softK then
		return Formulas.coreLuckCostSoft(rank, base, growth, softK, softPower)
	end
	return Formulas.coreLuckCost(rank, base, growth)
end

local RebirthAblation = {}

export type Ablation = {
	Id: string,
	Label: string,
	-- Keep pedestal held incomes from pre-rebirth (else wipe to empty).
	KeepRelics: boolean,
	AllowCoreLuckBuy: boolean,
	AllowScanBuy: boolean,
	-- If false, treat Rebirth luck/income mult as 1 for this window.
	RebirthLuckMult: boolean,
	RebirthIncomeMult: boolean,
	CodexShowcasePotion: boolean,
	-- Optional fix probes (nil = live Config / normal post-R reset).
	LuckGrowthOverride: number?,
	LuckCostGrowthOverride: number?,
	-- Soft diminishing-return Core Luck cost (Formulas.coreLuckCostSoft). nil = flat growth.
	SoftCostK: number?,
	SoftCostPower: number?,
	-- If true, start ScanSpeed at Snapshot.ScanRankAtRebirth (persist Scan across R).
	PersistScan: boolean?,
	-- Soft cap on Core Luck ranks purchasable in the window.
	CoreLuckCap: number?,
}

export type WindowStats = {
	Epic: number,
	Legendary: number,
	UniqueEpic: number,
	UniqueLegendary: number,
	Mutations: number,
	LuckStart: number,
	LuckEnd: number,
	IncomeStart: number,
	IncomeEnd: number,
	CoreLuckEnd: number,
	ScanEnd: number,
	SignificantBuys: number,
	RoutineBuys: number,
	MeanGapSec: number?,
}

local SELL_MAX = RarityConfig.IndexById.Rare
local EPIC_I = RarityConfig.IndexById.Epic
local LEG_I = RarityConfig.IndexById.Legendary
local ESSENTIAL_MAX = RarityConfig.IndexById[CodexConfig.EssentialMaxTier]

local essentialPool = 0
for _, relic in RelicConfig.Relics do
	if (RarityConfig.IndexById[relic.Tier] or 0) <= ESSENTIAL_MAX then
		essentialPool += 1
	end
end

local frozenBase: { [string]: number } = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local function makeRules(candidate: ProgressionSweep.Candidate): RollMath.Rules
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = candidate.EpicDenom
		elseif tier.Id == "Legendary" then
			denom = candidate.LegendaryDenom
		end
		table.insert(tiers, { Id = tier.Id, Denominator = denom })
	end
	return {
		Tiers = tiers,
		ByTier = RollMath.groupByTier(RelicConfig.Relics),
		Mutations = MutationConfig.Mutations,
		MutationChanceByRank = MutationConfig.ChanceByRank,
		FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
		FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
	}
end

local function coreLuck(rank: number, divisor: number): number
	return 10 ^ (rank / divisor)
end

local function codexLuck(essentialUnique: number): number
	local frac = essentialUnique / math.max(1, essentialPool)
	local luck = 0
	for _, entry in CodexConfig.Essential do
		if frac + 1e-12 >= entry.Fraction then
			luck += entry.Luck
		end
	end
	return math.min(luck, Config.Luck.CodexMaxBonus)
end

local function showcaseLuck(level: number): number
	if level <= 0 then
		return 0
	end
	local row = ShowcaseConfig.Levels[math.min(level, ShowcaseConfig.MaxLevel)]
	return row and row.Luck or 0
end

export type Snapshot = {
	Held: { number },
	EssentialUnique: number,
	ShowcaseLevel: number,
	PotionLeft: number,
	Rebirths: number,
	Seen: { [string]: boolean },
	UniqueCount: number,
	AtSecond: number,
	-- ScanSpeed rank immediately before the Rebirth reset (for PersistScan probes).
	ScanRankAtRebirth: number,
}

local function bonusRolls(scanForBonus: number, hunt: ProgressionSweep.HuntTune): number
	local b = Formulas.bonusRolls(scanForBonus, Config.Signals.RegenSeconds, {
		BonusFloor = hunt.BonusFloor,
		BonusFactor = hunt.BonusFactor,
	})
	if hunt.MaxBonusRolls then
		b = math.min(b, hunt.MaxBonusRolls)
	end
	return b
end

-- Drive upgrader full-stack until `targetRebirth` completes; return snapshot + pre stats.
function RebirthAblation.runToRebirth(options: {
	Seed: number,
	Candidate: ProgressionSweep.Candidate,
	TargetRebirth: number,
	MaxHours: number,
}): (Snapshot?, { Epic: number, Legendary: number, At: number }?)
	local candidate = options.Candidate
	local rules = makeRules(candidate)
	local settings = Config.Economy
	local rebirthSettings = Config.Rebirth
	local nodes = SkillConfig.ById

	local rngState = (options.Seed * 7919 + 12345) % 2147483647
	local function nextNumber(): number
		rngState = (rngState * 48271) % 2147483647
		return rngState / 2147483647
	end

	local ce = 0
	local rebirths = 0
	local skills = { CoreLuck = 0, ScanSpeed = 0, EnergyConduction = 0 }
	local levels = {}
	for _ = 1, Config.Plots.StartingPedestals do
		table.insert(levels, 1)
	end
	local held: { number } = {}
	local seen: { [string]: boolean } = {}
	local essentialSeen: { [string]: boolean } = {}
	local essentialUnique = 0
	local uniqueCount = 0
	local showcaseLevel = 0
	local potionLeft = 0
	local epicTotal, legTotal = 0, 0
	local ctxKey = ""
	local ctx: RollMath.Context? = nil
	local offeringTimer = 0
	local scanTimer = 0

	local function luckMult(): number
		local core = coreLuck(skills.CoreLuck, candidate.LuckDivisor)
		local reb = Rebirth.luckMultiplier(rebirthSettings, rebirths)
		return core * reb * (1 + codexLuck(essentialUnique)) * (1 + showcaseLuck(showcaseLevel)) * (if potionLeft > 0 then Config.Luck.MaxConsumable else 1)
	end
	local function context(): RollMath.Context
		local key = tostring(luckMult())
		if key ~= ctxKey or not ctx then
			ctx = RollMath.contextFor(rules, { FullLuck = luckMult() })
			ctxKey = key
		end
		return ctx :: RollMath.Context
	end
	local function incomePerSec(): number
		local mults = {}
		for index, level in levels do
			mults[index] = Economy.pedestalMultiplier(settings, level)
		end
		table.sort(mults, function(a, b)
			return a > b
		end)
		local contributions = {}
		for index, mult in mults do
			table.insert(contributions, (held[index] or 0) * mult)
		end
		local showIncome = 0
		if showcaseLevel > 0 then
			local row = ShowcaseConfig.Levels[math.min(showcaseLevel, ShowcaseConfig.MaxLevel)]
			showIncome = row and row.Income or 0
		end
		return Economy.totalIncome(
			contributions,
			(1 + SkillConfig.incomeBonus(skills.EnergyConduction) + showIncome) * Rebirth.incomeMultiplier(rebirthSettings, rebirths)
		)
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
		while #held > Config.Plots.MaxPedestals do
			table.remove(held)
		end
	end
	local function grant(relicId: string, tierIndex: number)
		local income = frozenBase[relicId] or 0
		if tierIndex >= EPIC_I then
			epicTotal += 1
		end
		if tierIndex >= LEG_I then
			legTotal += 1
		end
		local displayedFloor = if #held >= #levels then held[#levels] else -1
		local wasSeen = seen[relicId] == true
		if wasSeen and tierIndex <= SELL_MAX and income <= displayedFloor then
			local value = Economy.sellValue(settings, income, 0)
			ce += value
		else
			if not wasSeen then
				seen[relicId] = true
				uniqueCount += 1
				if tierIndex <= ESSENTIAL_MAX and not essentialSeen[relicId] then
					essentialSeen[relicId] = true
					essentialUnique += 1
					ctxKey = ""
				end
			end
			insertHeld(income)
		end
	end

	local maxSec = math.floor(options.MaxHours * 3600)
	for second = 1, maxSec do
		if potionLeft > 0 then
			potionLeft -= 1
			if potionLeft <= 0 then
				ctxKey = ""
			end
		end
		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			local relic = RollMath.roll(context(), nextNumber)
			grant(relic.Id, RarityConfig.IndexById[relic.Tier] or 1)
		end
		offeringTimer += 1
		if offeringTimer >= 600 then
			offeringTimer = 0
			if nextNumber() < 0.35 then
				potionLeft = math.min(ItemConfig.MaxBuffSeconds, potionLeft + 600)
				ctxKey = ""
			end
		end
		ce += incomePerSec()

		local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
		if ce >= rebirthCost then
			local scanAtRebirth = skills.ScanSpeed
			rebirths += 1
			ce = 0
			for index in levels do
				levels[index] = 1
			end
			for id in skills do
				skills[id] = 0
			end
			ctxKey = ""
			if rebirths >= options.TargetRebirth then
				return {
					Held = table.clone(held),
					EssentialUnique = essentialUnique,
					ShowcaseLevel = showcaseLevel,
					PotionLeft = potionLeft,
					Rebirths = rebirths,
					Seen = seen,
					UniqueCount = uniqueCount,
					AtSecond = second,
					ScanRankAtRebirth = scanAtRebirth,
				}, { Epic = epicTotal, Legendary = legTotal, At = second }
			end
		end

		local saving = rebirthCost - ce <= incomePerSec() * 600
		if not saving then
			for _ = 1, 400 do
				local optionsBuy = {}
				local nextSlot = #levels + 1
				local price = settings.SlotPrices[nextSlot]
				if price and nextSlot <= Config.Plots.MaxPedestals then
					table.insert(optionsBuy, {
						Cost = price,
						Buy = function()
							table.insert(levels, 1)
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
					local idx = lowestIndex
					table.insert(optionsBuy, {
						Cost = Economy.upgradeCost(settings, lowest),
						Buy = function()
							levels[idx] += 1
						end,
					})
				end
				if skills.CoreLuck < nodes.CoreLuck.MaxRank then
					table.insert(optionsBuy, {
						Cost = luckCost(skills.CoreLuck, candidate.LuckCostBase, candidate.LuckCostGrowth),
						Buy = function()
							skills.CoreLuck += 1
							ctxKey = ""
						end,
					})
				end
				for _, id in { "ScanSpeed", "EnergyConduction" } do
					local cost = SkillConfig.cost(nodes[id], skills[id])
					if cost then
						local skillId = id
						table.insert(optionsBuy, {
							Cost = cost,
							Buy = function()
								skills[skillId] += 1
								ctxKey = ""
							end,
						})
					end
				end
				if showcaseLevel == 0 then
					local unlock = ShowcaseConfig.Showcases[1]
					if unlock and unlock.Unlock.Price then
						table.insert(optionsBuy, {
							Cost = unlock.Unlock.Price :: number,
							Buy = function()
								showcaseLevel = 1
								ctxKey = ""
							end,
						})
					end
				elseif showcaseLevel < ShowcaseConfig.MaxLevel then
					local nextLevel = ShowcaseConfig.Levels[showcaseLevel + 1]
					if nextLevel and nextLevel.Cost then
						table.insert(optionsBuy, {
							Cost = nextLevel.Cost,
							Buy = function()
								showcaseLevel += 1
								ctxKey = ""
							end,
						})
					end
				end
				local cheapest = nil
				for _, opt in optionsBuy do
					if opt.Cost <= ce and (not cheapest or opt.Cost < cheapest.Cost) then
						cheapest = opt
					end
				end
				if not cheapest then
					break
				end
				ce -= cheapest.Cost
				cheapest.Buy()
			end
		end
	end
	return nil, nil
end

function RebirthAblation.runWindow(options: {
	Seed: number,
	Candidate: ProgressionSweep.Candidate,
	Snapshot: Snapshot,
	Ablation: Ablation,
	WindowSeconds: number,
}): WindowStats
	local candidate = options.Candidate
	local abl = options.Ablation
	local snap = options.Snapshot
	local rules = makeRules(candidate)
	local settings = Config.Economy
	local rebirthSettings = Config.Rebirth
	local nodes = SkillConfig.ById

	-- Deterministic continuation RNG from seed + ablation id hash
	local hash = 0
	for i = 1, #abl.Id do
		hash = (hash + string.byte(abl.Id, i) * i) % 2147483647
	end
	local rngState = (options.Seed * 7919 + 12345 + hash + snap.AtSecond) % 2147483647
	local function nextNumber(): number
		rngState = (rngState * 48271) % 2147483647
		return rngState / 2147483647
	end

	local ce = 0
	local rebirths = snap.Rebirths
	local startScan = if abl.PersistScan then (snap.ScanRankAtRebirth or 0) else 0
	local skills = { CoreLuck = 0, ScanSpeed = startScan, EnergyConduction = 0 }
	local levels = {}
	for _ = 1, math.max(Config.Plots.StartingPedestals, math.min(#snap.Held, Config.Plots.MaxPedestals)) do
		table.insert(levels, 1)
	end
	-- Ensure at least starting pedestals
	while #levels < Config.Plots.StartingPedestals do
		table.insert(levels, 1)
	end
	local held: { number } = if abl.KeepRelics then table.clone(snap.Held) else {}
	local seen = {}
	for k, v in snap.Seen do
		seen[k] = v
	end
	local essentialUnique = snap.EssentialUnique
	local uniqueCount = snap.UniqueCount
	local showcaseLevel = if abl.CodexShowcasePotion then snap.ShowcaseLevel else 0
	local potionLeft = if abl.CodexShowcasePotion then snap.PotionLeft else 0
	local epic, leg = 0, 0
	local uniqueEpic: { [string]: boolean } = {}
	local uniqueLeg: { [string]: boolean } = {}
	local mutations = 0
	local ctxKey = ""
	local ctx: RollMath.Context? = nil
	local offeringTimer = 0
	local scanTimer = 0
	local significant, routine = 0, 0
	local lastSig = 0
	local gaps = {}
	local luckGrowth = abl.LuckGrowthOverride or rebirthSettings.LuckGrowth
	local luckCostGrowth = abl.LuckCostGrowthOverride or candidate.LuckCostGrowth
	local softK = abl.SoftCostK
	local softPower = abl.SoftCostPower
	local coreCap = abl.CoreLuckCap

	local function noteSig(t: number)
		if lastSig > 0 then
			table.insert(gaps, t - lastSig)
		end
		lastSig = t
		significant += 1
	end

	local function rebLuck(): number
		if abl.RebirthLuckMult then
			return luckGrowth ^ rebirths
		end
		return 1
	end
	local function rebIncome(): number
		if abl.RebirthIncomeMult then
			return Rebirth.incomeMultiplier(rebirthSettings, rebirths)
		end
		return 1
	end
	local function luckMult(): number
		local core = coreLuck(skills.CoreLuck, candidate.LuckDivisor)
		local codex = if abl.CodexShowcasePotion then (1 + codexLuck(essentialUnique)) else 1
		local show = if abl.CodexShowcasePotion then (1 + showcaseLuck(showcaseLevel)) else 1
		local potion = if abl.CodexShowcasePotion and potionLeft > 0 then Config.Luck.MaxConsumable else 1
		return core * rebLuck() * codex * show * potion
	end
	local function context(): RollMath.Context
		local key = tostring(luckMult())
		if key ~= ctxKey or not ctx then
			ctx = RollMath.contextFor(rules, { FullLuck = luckMult() })
			ctxKey = key
		end
		return ctx :: RollMath.Context
	end
	local function incomePerSec(): number
		local mults = {}
		for index, level in levels do
			mults[index] = Economy.pedestalMultiplier(settings, level)
		end
		table.sort(mults, function(a, b)
			return a > b
		end)
		local contributions = {}
		for index, mult in mults do
			table.insert(contributions, (held[index] or 0) * mult)
		end
		local showIncome = 0
		if abl.CodexShowcasePotion and showcaseLevel > 0 then
			local row = ShowcaseConfig.Levels[math.min(showcaseLevel, ShowcaseConfig.MaxLevel)]
			showIncome = row and row.Income or 0
		end
		return Economy.totalIncome(
			contributions,
			(1 + SkillConfig.incomeBonus(skills.EnergyConduction) + showIncome) * rebIncome()
		)
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
		while #held > Config.Plots.MaxPedestals do
			table.remove(held)
		end
	end
	local function grant(relicId: string, tierIndex: number, mutated: boolean)
		local income = frozenBase[relicId] or 0
		if tierIndex >= EPIC_I then
			epic += 1
			uniqueEpic[relicId] = true
		end
		if tierIndex >= LEG_I then
			leg += 1
			uniqueLeg[relicId] = true
		end
		if mutated then
			mutations += 1
		end
		local displayedFloor = if #held >= #levels then held[#levels] else -1
		local wasSeen = seen[relicId] == true
		if wasSeen and tierIndex <= SELL_MAX and income <= displayedFloor then
			ce += Economy.sellValue(settings, income, 0)
		else
			if not wasSeen then
				seen[relicId] = true
				uniqueCount += 1
				if tierIndex <= ESSENTIAL_MAX then
					essentialUnique += 1
					ctxKey = ""
				end
			end
			insertHeld(income)
		end
	end

	local luckStart = luckMult()
	local incomeStart = incomePerSec()

	for second = 1, options.WindowSeconds do
		if potionLeft > 0 then
			potionLeft -= 1
			if potionLeft <= 0 then
				ctxKey = ""
			end
		end
		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			local relic, mutationId = RollMath.roll(context(), nextNumber)
			grant(relic.Id, RarityConfig.IndexById[relic.Tier] or 1, mutationId ~= nil)
		end
		if abl.CodexShowcasePotion then
			offeringTimer += 1
			if offeringTimer >= 600 then
				offeringTimer = 0
				if nextNumber() < 0.35 then
					potionLeft = math.min(ItemConfig.MaxBuffSeconds, potionLeft + 600)
					ctxKey = ""
				end
			end
		end
		ce += incomePerSec()

		for _ = 1, 400 do
			local optionsBuy = {}
			local nextSlot = #levels + 1
			local price = settings.SlotPrices[nextSlot]
			if price and nextSlot <= Config.Plots.MaxPedestals then
				table.insert(optionsBuy, {
					Cost = price,
					Kind = "sig",
					Buy = function()
						table.insert(levels, 1)
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
				local idx = lowestIndex
				table.insert(optionsBuy, {
					Cost = Economy.upgradeCost(settings, lowest),
					Kind = "routine",
					Buy = function()
						levels[idx] += 1
					end,
				})
			end
			local coreMax = nodes.CoreLuck.MaxRank
			if coreCap then
				coreMax = math.min(coreMax, coreCap)
			end
			if abl.AllowCoreLuckBuy and skills.CoreLuck < coreMax then
				table.insert(optionsBuy, {
					Cost = luckCost(skills.CoreLuck, candidate.LuckCostBase, luckCostGrowth, softK, softPower),
					Kind = if (skills.CoreLuck + 1) % 5 == 0 then "sig" else "routine",
					Buy = function()
						skills.CoreLuck += 1
						ctxKey = ""
					end,
				})
			end
			if abl.AllowScanBuy then
				local cost = SkillConfig.cost(nodes.ScanSpeed, skills.ScanSpeed)
				if cost then
					table.insert(optionsBuy, {
						Cost = cost,
						Kind = "sig",
						Buy = function()
							skills.ScanSpeed += 1
							ctxKey = ""
						end,
					})
				end
			end
			local ecost = SkillConfig.cost(nodes.EnergyConduction, skills.EnergyConduction)
			if ecost then
				table.insert(optionsBuy, {
					Cost = ecost,
					Kind = "routine",
					Buy = function()
						skills.EnergyConduction += 1
					end,
				})
			end
			local cheapest = nil
			for _, opt in optionsBuy do
				if opt.Cost <= ce and (not cheapest or opt.Cost < cheapest.Cost) then
					cheapest = opt
				end
			end
			if not cheapest then
				break
			end
			ce -= cheapest.Cost
			cheapest.Buy()
			if cheapest.Kind == "sig" then
				noteSig(second)
			else
				routine += 1
			end
		end
	end

	local meanGap = nil
	if #gaps > 0 then
		local s = 0
		for _, g in gaps do
			s += g
		end
		meanGap = s / #gaps
	end

	local function countKeys(map: { [string]: boolean }): number
		local n = 0
		for _ in map do
			n += 1
		end
		return n
	end

	return {
		Epic = epic,
		Legendary = leg,
		UniqueEpic = countKeys(uniqueEpic),
		UniqueLegendary = countKeys(uniqueLeg),
		Mutations = mutations,
		LuckStart = luckStart,
		LuckEnd = luckMult(),
		IncomeStart = incomeStart,
		IncomeEnd = incomePerSec(),
		CoreLuckEnd = skills.CoreLuck,
		ScanEnd = SkillConfig.scanInterval(skills.ScanSpeed),
		SignificantBuys = significant,
		RoutineBuys = routine,
		MeanGapSec = meanGap,
	}
end

local function baseFull(): Ablation
	return {
		Id = "full",
		Label = "Full post-R stack (control)",
		KeepRelics = true,
		AllowCoreLuckBuy = true,
		AllowScanBuy = true,
		RebirthLuckMult = true,
		RebirthIncomeMult = true,
		CodexShowcasePotion = true,
	}
end

function RebirthAblation.defaultAblations(): { Ablation }
	local full = baseFull()
	return {
		full,
		{
			Id = "noKeptRelics",
			Label = "Wipe kept relics (empty pedestals)",
			KeepRelics = false,
			AllowCoreLuckBuy = true,
			AllowScanBuy = true,
			RebirthLuckMult = true,
			RebirthIncomeMult = true,
			CodexShowcasePotion = true,
		},
		{
			Id = "noCoreLuckBuy",
			Label = "Cannot rebuy Core Luck",
			KeepRelics = true,
			AllowCoreLuckBuy = false,
			AllowScanBuy = true,
			RebirthLuckMult = true,
			RebirthIncomeMult = true,
			CodexShowcasePotion = true,
		},
		{
			Id = "noScanBuy",
			Label = "Scan stuck at 4s (no Scan Speed buys)",
			KeepRelics = true,
			AllowCoreLuckBuy = true,
			AllowScanBuy = false,
			RebirthLuckMult = true,
			RebirthIncomeMult = true,
			CodexShowcasePotion = true,
		},
		{
			Id = "noRebirthMult",
			Label = "Rebirth luck/income mults = ×1",
			KeepRelics = true,
			AllowCoreLuckBuy = true,
			AllowScanBuy = true,
			RebirthLuckMult = false,
			RebirthIncomeMult = false,
			CodexShowcasePotion = true,
		},
		{
			Id = "noCodexShowPotion",
			Label = "No Codex/Showcase/potion luck",
			KeepRelics = true,
			AllowCoreLuckBuy = true,
			AllowScanBuy = true,
			RebirthLuckMult = true,
			RebirthIncomeMult = true,
			CodexShowcasePotion = false,
		},
		{
			Id = "relicsIncomeOnly",
			Label = "Kept relics + income mults; luck buys off; no codex/potions; rebirth luck off",
			KeepRelics = true,
			AllowCoreLuckBuy = false,
			AllowScanBuy = false,
			RebirthLuckMult = false,
			RebirthIncomeMult = true,
			CodexShowcasePotion = false,
		},
		{
			Id = "luckStackOnly",
			Label = "No kept relics; full luck repurchase + rebirth luck + codex/potions",
			KeepRelics = false,
			AllowCoreLuckBuy = true,
			AllowScanBuy = true,
			RebirthLuckMult = true,
			RebirthIncomeMult = false,
			CodexShowcasePotion = true,
		},
	}
end

-- Non-punishing fix candidates (still keep relics; no forced Focus).
function RebirthAblation.fixProbes(): { Ablation }
	local function clone(id: string, label: string, patch: { [string]: any }): Ablation
		local a = baseFull()
		a.Id = id
		a.Label = label
		for k, v in patch do
			(a :: any)[k] = v
		end
		return a
	end
	return {
		baseFull(),
		clone("fixSoftLuck125", "LuckGrowth 1.25 (keep income ×2)", { LuckGrowthOverride = 1.25 }),
		clone("fixIncomeOnlyLuck", "Rebirth luck ×1 (income mult kept)", { RebirthLuckMult = false }),
		clone("fixCostGrowth185", "CoreLuck cost growth 1.85 post-R", { LuckCostGrowthOverride = 1.85 }),
		clone("fixCoreCap20", "CoreLuck capped at rank 20 in window", { CoreLuckCap = 20 }),
		clone("fixPersistScan", "Scan Speed persists across Rebirth", { PersistScan = true }),
		clone(
			"fixSoftLuck125_Cost185",
			"Combo: LuckGrowth 1.25 + CoreLuck cost 1.85",
			{ LuckGrowthOverride = 1.25, LuckCostGrowthOverride = 1.85 }
		),
	}
end

-- A+C matrix for Astra: flat post-R cost growth vs soft diminishing returns, across R1–R3.
function RebirthAblation.acMatrix(): { Ablation }
	local function clone(id: string, label: string, patch: { [string]: any }): Ablation
		local a = baseFull()
		a.Id = id
		a.Label = label
		for k, v in patch do
			(a :: any)[k] = v
		end
		return a
	end
	return {
		baseFull(),
		clone("ac_lg125_g175", "LuckGrowth 1.25 + cost growth 1.75", {
			LuckGrowthOverride = 1.25,
			LuckCostGrowthOverride = 1.75,
		}),
		clone("ac_lg125_g180", "LuckGrowth 1.25 + cost growth 1.80", {
			LuckGrowthOverride = 1.25,
			LuckCostGrowthOverride = 1.80,
		}),
		clone("ac_lg125_g185", "LuckGrowth 1.25 + cost growth 1.85", {
			LuckGrowthOverride = 1.25,
			LuckCostGrowthOverride = 1.85,
		}),
		clone("ac_lg125_soft05", "LuckGrowth 1.25 + soft cost k=0.05 (base growth 1.7)", {
			LuckGrowthOverride = 1.25,
			LuckCostGrowthOverride = 1.7,
			SoftCostK = 0.05,
			SoftCostPower = 1.35,
		}),
		clone("ac_lg125_soft04", "LuckGrowth 1.25 + soft cost k=0.04 (base growth 1.7)", {
			LuckGrowthOverride = 1.25,
			LuckCostGrowthOverride = 1.7,
			SoftCostK = 0.04,
			SoftCostPower = 1.35,
		}),
		clone("ac_lg125_soft06", "LuckGrowth 1.25 + soft cost k=0.06 (base growth 1.7)", {
			LuckGrowthOverride = 1.25,
			LuckCostGrowthOverride = 1.7,
			SoftCostK = 0.06,
			SoftCostPower = 1.35,
		}),
	}
end

return RebirthAblation
