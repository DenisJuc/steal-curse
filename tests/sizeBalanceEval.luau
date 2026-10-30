-- Size balance evaluation across probability × power models (no production changes).
-- SoftCap_P5_Bands / SoftenD. Analytical rare-event math + thin MC for album fill.
-- Run: lune run tests/sizeBalanceEval

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local BalanceTrials = require("../src/shared/BalanceTrials")
local Config = require("../src/shared/Config")
local MutationConfig = require("../src/shared/MutationConfig")
local RarityConfig = require("../src/shared/RarityConfig")
local RelicConfig = require("../src/shared/RelicConfig")
local SoftCapRarity = require("../src/shared/SoftCapRarity")
local RelicIncome = require("./lib/relicIncome")
local SimRuntime = require("./lib/simRuntime")

BalanceTrials.AllowNonStudioActive = true
BalanceTrials.Active = "SoftCap_P5_Bands"
BalanceTrials.CollectionPrototype = true
SoftCapRarity.syncFromTrials()
SoftCapRarity.invalidateSampler()

local RPM = 49 -- playtest-calibrated SoftCap Studio
local REBIRTH_COST = 400_000_000
local SEED0 = 20261018
local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }
local HORIZONS_H = { 20 / 60, 1, 3, 10, 30, 100 } -- hours
local LUCK_POINTS = { 1, 10, 30, 50, 80, 120, 150, 200 }

-- Approximate SoftCap Studio luck schedule (CoreLuck + Codex/Showcase extras).
-- Anchors: ~L10 early, ~L80 @20m playtest, ~L150 midgame softcap, asymptotic ~220.
local function luckAtHours(h: number): number
	local minutes = h * 60
	if minutes <= 0 then
		return 1
	end
	-- piecewise-log: matches playtest L≈80 @20m and L≈150 @~3–6h climbing slowly
	local L = 1 + 55 * math.log(1 + minutes / 12) / math.log(10)
	return math.clamp(L, 1, 220)
end

-- Pedestal income proxy: top-K owned stamps × soft global mult growth (not full economy).
local function globalIncomeMultAtHours(h: number): number
	-- Rebirth B+ path: skills/pedestals persist; rough CE/s scale before first Rebirth.
	return 1 + 8 * math.log(1 + h * 60 / 30) / math.log(10)
end

type ChanceRow = { Huge: number, Titanic: number }
type Model = {
	Id: string,
	Label: string,
	HugeMult: number,
	TitMult: number,
	Chance: { [string]: ChanceRow },
	Notes: string,
}

local function row(h: number, t: number): ChanceRow
	return { Huge = h, Titanic = t }
end

-- Current shipping SizeConfig (Commons never size; Uncommon Titanic off).
local BASELINE_CHANCE = {
	Common = row(0, 0),
	Uncommon = row(1 / 450, 0),
	Rare = row(1 / 160, 1 / 2200),
	Epic = row(1 / 90, 1 / 700),
	Legendary = row(1 / 70, 1 / 450),
	Mythic = row(1 / 55, 1 / 320),
	Celestial = row(1 / 45, 1 / 220),
	Cosmic = row(1 / 40, 1 / 180),
}

local function cloneChance(src: { [string]: ChanceRow }): { [string]: ChanceRow }
	local out = {}
	for k, v in src do
		out[k] = { Huge = v.Huge, Titanic = v.Titanic }
	end
	return out
end

local MODELS: { Model } = {
	{
		Id = "Baseline_P5",
		Label = "Baseline (current SoftCap_P5 SizeConfig)",
		HugeMult = 1.5,
		TitMult = 2.5,
		Chance = cloneChance(BASELINE_CHANCE),
		Notes = "No Common size; Uncommon Titanic=0; power ×1.5/×2.5",
	},
	{
		Id = "SafePower",
		Label = "Safe power (rates unchanged)",
		HugeMult = 1.25,
		TitMult = 1.85,
		Chance = cloneChance(BASELINE_CHANCE),
		Notes = "Same rates; lower income so low-tier sizes rarely beat Epic Normal",
	},
	{
		Id = "CompeteLow_A",
		Label = "Compete-low A: Common Huge + Unc Titanic, mid power",
		HugeMult = 1.4,
		TitMult = 2.2,
		Chance = (function()
			local c = cloneChance(BASELINE_CHANCE)
			c.Common = row(1 / 900, 0)
			c.Uncommon = row(1 / 450, 1 / 4500)
			return c
		end)(),
		Notes = "Hypothetical Common Huge; Uncommon Titanic; Tit power 2.2",
	},
	{
		Id = "CompeteLow_B",
		Label = "Compete-low B: Common Huge/Tit + Unc Tit, softer power",
		HugeMult = 1.35,
		TitMult = 2.0,
		Chance = (function()
			local c = cloneChance(BASELINE_CHANCE)
			c.Common = row(1 / 700, 1 / 14000)
			c.Uncommon = row(1 / 400, 1 / 3200)
			-- Slightly rarer high-tier Titanic to keep Epic+ exceptional
			c.Epic = row(1 / 100, 1 / 900)
			c.Legendary = row(1 / 80, 1 / 600)
			c.Mythic = row(1 / 60, 1 / 400)
			c.Celestial = row(1 / 50, 1 / 280)
			c.Cosmic = row(1 / 45, 1 / 220)
			return c
		end)(),
		Notes = "Full low-tier album; softer Tit power; Epic+ Tit slightly rarer",
	},
	{
		Id = "AlbumDepth",
		Label = "Album depth: Common sizes rare, power mid-low",
		HugeMult = 1.3,
		TitMult = 1.95,
		Chance = (function()
			local c = cloneChance(BASELINE_CHANCE)
			c.Common = row(1 / 1100, 1 / 18000)
			c.Uncommon = row(1 / 500, 1 / 5000)
			c.Rare = row(1 / 180, 1 / 2400)
			return c
		end)(),
		Notes = "Maximizes long-term stamps; keeps Rare Tit scarce; power restrained",
	},
	{
		Id = "PrestigeSpike",
		Label = "Prestige spike: rare Tit, high Tit power",
		HugeMult = 1.45,
		TitMult = 2.8,
		Chance = (function()
			local c = cloneChance(BASELINE_CHANCE)
			c.Common = row(1 / 1500, 0)
			c.Uncommon = row(1 / 500, 1 / 8000)
			c.Rare = row(1 / 200, 1 / 3500)
			c.Epic = row(1 / 110, 1 / 1100)
			c.Legendary = row(1 / 85, 1 / 700)
			return c
		end)(),
		Notes = "Titanic rarer but stronger — economy risk if Common Tit added later",
	},
	{
		Id = "Balanced_Studio",
		Label = "Balanced Studio candidate",
		HugeMult = 1.35,
		TitMult = 2.15,
		Chance = (function()
			local c = cloneChance(BASELINE_CHANCE)
			c.Common = row(1 / 1000, 0) -- Common Huge only (no Common Tit yet)
			c.Uncommon = row(1 / 420, 1 / 4000)
			c.Rare = row(1 / 170, 1 / 2400)
			c.Epic = row(1 / 95, 1 / 800)
			c.Legendary = row(1 / 75, 1 / 520)
			c.Mythic = row(1 / 58, 1 / 360)
			c.Celestial = row(1 / 48, 1 / 250)
			c.Cosmic = row(1 / 42, 1 / 200)
			return c
		end)(),
		Notes = "Common Huge + Unc Tit; no Common Tit; mid power; Rare Tit stays meaningful",
	},
	{
		Id = "Balanced_Album",
		Label = "Balanced album candidate (incl Common Tit)",
		HugeMult = 1.32,
		TitMult = 2.05,
		Chance = (function()
			local c = cloneChance(BASELINE_CHANCE)
			c.Common = row(1 / 850, 1 / 16000)
			c.Uncommon = row(1 / 430, 1 / 3800)
			c.Rare = row(1 / 175, 1 / 2500)
			c.Epic = row(1 / 100, 1 / 850)
			c.Legendary = row(1 / 78, 1 / 550)
			c.Mythic = row(1 / 60, 1 / 380)
			c.Celestial = row(1 / 50, 1 / 260)
			c.Cosmic = row(1 / 44, 1 / 210)
			return c
		end)(),
		Notes = "Full rarity×size matrix; Tit power capped so Common Tit ≈ Unc/Rare Normal",
	},
}

local function fmt(n: number): string
	if n ~= n or n == math.huge then
		return "inf"
	end
	if math.abs(n) >= 1000 then
		return string.format("%.0f", n)
	elseif math.abs(n) >= 100 then
		return string.format("%.1f", n)
	elseif math.abs(n) >= 10 then
		return string.format("%.2f", n)
	end
	return string.format("%.3f", n)
end

local function meanWaitMin(p: number): number
	if p <= 0 then
		return math.huge
	end
	return (1 / p) / RPM
end

local function pAtLeastOne(lambda: number): number
	if lambda <= 0 then
		return 0
	end
	return 1 - math.exp(-lambda)
end

-- Mid relic income per tier (Normal).
local midIncome: { [string]: number } = {}
local minIncome: { [string]: number } = {}
local maxIncome: { [string]: number } = {}
local countByTier: { [string]: number } = {}
do
	local bags: { [string]: { number } } = {}
	for _, relic in RelicConfig.Relics do
		bags[relic.Tier] = bags[relic.Tier] or {}
		table.insert(bags[relic.Tier], RelicIncome.of(relic.Id))
	end
	for _, tier in TIERS do
		local a = bags[tier] or {}
		table.sort(a)
		countByTier[tier] = #a
		if #a > 0 then
			minIncome[tier] = a[1]
			maxIncome[tier] = a[#a]
			midIncome[tier] = a[math.ceil(#a / 2)]
		else
			minIncome[tier], maxIncome[tier], midIncome[tier] = 0, 0, 0
		end
	end
end

local function sizeIncome(tier: string, size: string?, model: Model): number
	local base = midIncome[tier] or 0
	if size == "Huge" then
		return base * model.HugeMult
	elseif size == "Titanic" then
		return base * model.TitMult
	end
	return base
end

-- Absolute P(size) per reward at fixed Luck for a model.
local function absSizeP(model: Model, luck: number): (number, number, { [string]: number }, { [string]: number })
	local bands = SoftCapRarity.softCapBandPercents(luck)
	local pH, pT = 0, 0
	local cH: { [string]: number } = {}
	local cT: { [string]: number } = {}
	for _, tier in TIERS do
		local share = (bands[tier] or 0) / 100
		local rowC = model.Chance[tier]
		local h = share * (rowC and rowC.Huge or 0)
		local t = share * (rowC and rowC.Titanic or 0)
		pH += h
		pT += t
		cH[tier] = h
		cT[tier] = t
	end
	return pH, pT, cH, cT
end

-- Integrate expected size counts over a luck schedule (piecewise constant hours).
local function expectedCountsOverHours(model: Model, hours: number, steps: number?): (number, number)
	local nSteps = steps or math.max(24, math.floor(hours * 12))
	local dtH = hours / nSteps
	local eH, eT = 0, 0
	for i = 1, nSteps do
		local tMid = (i - 0.5) * dtH
		local L = luckAtHours(tMid)
		local pH, pT = absSizeP(model, L)
		local rewards = RPM * dtH * 60
		eH += pH * rewards
		eT += pT * rewards
	end
	return eH, eT
end

-- Per rarity×size expected time (hours) at reference luck and schedule-integrated.
local function comboEtaHours(model: Model, tier: string, size: string, luck: number): number
	local bands = SoftCapRarity.softCapBandPercents(luck)
	local share = (bands[tier] or 0) / 100
	local rowC = model.Chance[tier]
	local pCond = if size == "Huge" then (rowC and rowC.Huge or 0) else (rowC and rowC.Titanic or 0)
	local p = share * pCond
	if p <= 0 then
		return math.huge
	end
	return meanWaitMin(p) / 60
end

-- Which sized mid-tier beats which Normal mid-tier?
local function incomeDominance(model: Model): {
	{
		From: string,
		Size: string,
		Income: number,
		Beats: { string }, -- Normal tiers beaten
		BeatsEpic: boolean,
		BeatsLegendary: boolean,
	}
}
	local out = {}
	for _, tier in TIERS do
		for _, size in { "Huge", "Titanic" } do
			local rowC = model.Chance[tier]
			local p = if size == "Huge" then (rowC and rowC.Huge or 0) else (rowC and rowC.Titanic or 0)
			if p <= 0 then
				continue
			end
			local inc = sizeIncome(tier, size, model)
			local beats = {}
			for _, other in TIERS do
				if (midIncome[other] or 0) > 0 and inc + 1e-12 >= (midIncome[other] or 0) then
					-- "beats" means >= mid Normal of that tier
					if RarityConfig.IndexById[other] > RarityConfig.IndexById[tier] then
						table.insert(beats, other)
					end
				end
			end
			table.insert(out, {
				From = tier,
				Size = size,
				Income = inc,
				Beats = beats,
				BeatsEpic = inc + 1e-12 >= (midIncome.Epic or 0),
				BeatsLegendary = inc + 1e-12 >= (midIncome.Legendary or 0),
			})
		end
	end
	return out
end

-- Thin MC: album fill + first Huge/Tit + unique combos (relic×mut×size) at fixed luck slices.
local function mcHorizon(model: Model, hours: number, luck: number, seeds: number, mutRank: number)
	local rewards = math.floor(RPM * hours * 60)
	local firstH = {}
	local firstT = {}
	local uniqueCombos = {}
	local uniqueSizeStamps = {}
	local baseDupes = {}
	local newBases = {}
	local bestPedIncome = {}
	local pedSlots = 5

	-- Build weight sampler once
	local sampler = SoftCapRarity.samplerFor(luck)

	local function rollSize(tier: string, rng: () -> number): string?
		local rowC = model.Chance[tier]
		if not rowC then
			return nil
		end
		local r = rng()
		local pT = rowC.Titanic or 0
		if pT > 0 and r < pT then
			return "Titanic"
		end
		r -= pT
		local pH = rowC.Huge or 0
		if pH > 0 and r < pH then
			return "Huge"
		end
		return nil
	end

	local function rollMut(rng: () -> number): string?
		local chance = MutationConfig.ChanceAt(mutRank)
		if chance <= 0 or rng() >= chance then
			return nil
		end
		local unlocked = {}
		local wSum = 0
		for _, m in MutationConfig.Mutations do
			if m.UnlockRank <= mutRank then
				table.insert(unlocked, m)
				wSum += m.Weight
			end
		end
		if wSum <= 0 then
			return nil
		end
		local r = rng() * wSum
		for _, m in unlocked do
			r -= m.Weight
			if r < 0 then
				return m.Id
			end
		end
		return unlocked[#unlocked].Id
	end

	for seed = 1, seeds do
		local state = SEED0 + seed * 9973 + math.floor(hours * 1000)
		local function rng(): number
			state = (state * 1103515245 + 12345) % 2 ^ 31
			return state / 2 ^ 31
		end
		local discovered: { [string]: boolean } = {}
		local stamps: { [string]: boolean } = {} -- id|size
		local combos: { [string]: boolean } = {} -- id|mut|size
		local firstHugeI, firstTitI = nil, nil
		local dupe = 0
		local newB = 0
		local top = table.create(pedSlots, 0)

		for i = 1, rewards do
			local target = rng() * sampler.Total
			local id, tier = sampler.Ids[#sampler.Ids], sampler.Tiers[#sampler.Tiers]
			local acc = 0
			for wi = 1, #sampler.Weights do
				acc += sampler.Weights[wi]
				if target < acc then
					id, tier = sampler.Ids[wi], sampler.Tiers[wi]
					break
				end
			end
			local mut = rollMut(rng)
			local size = rollSize(tier, rng)
			local first = discovered[id] ~= true
			if first then
				discovered[id] = true
				newB += 1
			else
				dupe += 1
			end
			if size == "Huge" and not firstHugeI then
				firstHugeI = i
			end
			if size == "Titanic" and not firstTitI then
				firstTitI = i
			end
			if size then
				stamps[`{id}|{size}`] = true
			end
			combos[`{id}|{mut or "-"}|{size or "N"}`] = true
			local inc = RelicIncome.of(id, mut, nil) -- base+mut
			local sm = if size == "Huge" then model.HugeMult elseif size == "Titanic" then model.TitMult else 1
			inc *= sm
			-- keep-best on pedestals
			local worstI, worstV = 1, top[1]
			for s = 2, pedSlots do
				if top[s] < worstV then
					worstI, worstV = s, top[s]
				end
			end
			if inc > worstV then
				top[worstI] = inc
			end
		end
		local stampN = 0
		for _ in stamps do
			stampN += 1
		end
		local comboN = 0
		for _ in combos do
			comboN += 1
		end
		local ped = 0
		for s = 1, pedSlots do
			ped += top[s]
		end
		table.insert(firstH, if firstHugeI then firstHugeI / RPM / 60 else math.huge)
		table.insert(firstT, if firstTitI then firstTitI / RPM / 60 else math.huge)
		table.insert(uniqueSizeStamps, stampN)
		table.insert(uniqueCombos, comboN)
		table.insert(baseDupes, dupe)
		table.insert(newBases, newB)
		table.insert(bestPedIncome, ped * globalIncomeMultAtHours(hours))
	end

	local function avg(arr: { number }, ignoreInf: boolean?): number
		local s, n = 0, 0
		for _, v in arr do
			if ignoreInf and (v == math.huge or v ~= v) then
				continue
			end
			s += v
			n += 1
		end
		return if n > 0 then s / n else math.huge
	end
	local function median(arr: { number }): number
		local copy = table.clone(arr)
		table.sort(copy)
		local finite = {}
		for _, v in copy do
			if v == math.huge or v ~= v then
				continue
			end
			table.insert(finite, v)
		end
		if #finite == 0 then
			return math.huge
		end
		return finite[math.ceil(#finite / 2)]
	end
	local hitH, hitT = 0, 0
	for _, v in firstH do
		if v < math.huge then
			hitH += 1
		end
	end
	for _, v in firstT do
		if v < math.huge then
			hitT += 1
		end
	end
	return {
		Hours = hours,
		Luck = luck,
		Seeds = seeds,
		Rewards = rewards,
		PFirstHuge = hitH / seeds,
		PFirstTit = hitT / seeds,
		MeanFirstHugeH = avg(firstH, true),
		MedFirstHugeH = median(firstH),
		MeanFirstTitH = avg(firstT, true),
		MedFirstTitH = median(firstT),
		MeanSizeStamps = avg(uniqueSizeStamps),
		MeanUniqueCombos = avg(uniqueCombos),
		MeanNewBases = avg(newBases),
		MeanBaseDupes = avg(baseDupes),
		MeanBestPedCE = avg(bestPedIncome),
	}
end

-- Eligible stamps under a model.
local function eligibleCounts(model: Model): (number, number, number)
	local hugeE, titE, totalCombos = 0, 0, 0
	for _, relic in RelicConfig.Relics do
		local rowC = model.Chance[relic.Tier]
		if rowC and (rowC.Huge or 0) > 0 then
			hugeE += 1
		end
		if rowC and (rowC.Titanic or 0) > 0 then
			titE += 1
		end
		-- Normal always; + mut variants not counted here
		totalCombos += 1 -- Normal
		if rowC and (rowC.Huge or 0) > 0 then
			totalCombos += 1
		end
		if rowC and (rowC.Titanic or 0) > 0 then
			totalCombos += 1
		end
	end
	return hugeE, titE, totalCombos
end

-- Coupon-collector approx: E[time] to collect fraction f of stamps using integrated rate.
local function stampFillProjection(model: Model, hoursCap: number, fraction: number): (number?, number?)
	-- Use MC short seeds at high luck for fill curve; here analytical: treat as
	-- time-varying rate λ(t) for new stamps ≈ p_size(t) * (remaining/eligible).
	local hugeE, titE = eligibleCounts(model)
	local steps = math.max(40, math.floor(hoursCap * 8))
	local dt = hoursCap / steps
	local gotH, gotT = 0.0, 0.0
	local t50H, t50T = nil, nil
	local targetH, targetT = hugeE * fraction, titE * fraction
	for i = 1, steps do
		local tMid = (i - 0.5) * dt
		local L = luckAtHours(tMid)
		local pH, pT = absSizeP(model, L)
		local rewards = RPM * dt * 60
		local remH = math.max(0, hugeE - gotH)
		local remT = math.max(0, titE - gotT)
		-- Probability a size roll is new ≈ remaining/eligible (uniform approx over eligible relics)
		local newH = if hugeE > 0 then pH * rewards * (remH / hugeE) else 0
		local newT = if titE > 0 then pT * rewards * (remT / titE) else 0
		gotH = math.min(hugeE, gotH + newH)
		gotT = math.min(titE, gotT + newT)
		if not t50H and gotH >= targetH then
			t50H = i * dt
		end
		if not t50T and gotT >= targetT then
			t50T = i * dt
		end
	end
	return t50H, t50T
end

-- Experienced player + roster update: add N new Commons/Rares; measure new stamp ETA.
local function rosterUpdateShock(model: Model, newCommons: number, newRares: number, luck: number): {
	NewHugeEligible: number,
	EtaFirstNewHugeH: number,
	EtaFirstNewTitH: number,
}
	-- Approximate: new relics share tier band mass; ETA ≈ 1/(share_per_relic * p_size)
	local bands = SoftCapRarity.softCapBandPercents(luck)
	local nC = countByTier.Common or 1
	local nR = countByTier.Rare or 1
	local pHugeNew = 0
	local pTitNew = 0
	if newCommons > 0 and (model.Chance.Common.Huge or 0) > 0 then
		-- each new Common gets ~1/(nC+new) of Common mass
		pHugeNew += (bands.Common / 100) * (newCommons / (nC + newCommons)) * model.Chance.Common.Huge
	end
	if newRares > 0 then
		local share = newRares / (nR + newRares)
		pHugeNew += (bands.Rare / 100) * share * (model.Chance.Rare.Huge or 0)
		pTitNew += (bands.Rare / 100) * share * (model.Chance.Rare.Titanic or 0)
	end
	return {
		NewHugeEligible = newCommons * (if (model.Chance.Common.Huge or 0) > 0 then 1 else 0)
			+ newRares * (if (model.Chance.Rare.Huge or 0) > 0 then 1 else 0),
		EtaFirstNewHugeH = if pHugeNew > 0 then meanWaitMin(pHugeNew) / 60 else math.huge,
		EtaFirstNewTitH = if pTitNew > 0 then meanWaitMin(pTitNew) / 60 else math.huge,
	}
end

-- Score models against design goals (higher better).
local function scoreModel(model: Model, pack: any): number
	local score = 0
	local dom = pack.Dominance
	-- Low-rarity Tit sometimes competes with higher Normal
	local uncTitBeatsRare = false
	local commonTitBeatsUnc = false
	local rareTitBeatsEpic = false
	local epicTitBeatsLeg = false
	local commonHugeBeatsUnc = false
	for _, d in dom do
		if d.From == "Uncommon" and d.Size == "Titanic" then
			for _, b in d.Beats do
				if b == "Rare" then
					uncTitBeatsRare = true
				end
			end
		end
		if d.From == "Common" and d.Size == "Titanic" then
			for _, b in d.Beats do
				if b == "Uncommon" then
					commonTitBeatsUnc = true
				end
			end
		end
		if d.From == "Common" and d.Size == "Huge" then
			for _, b in d.Beats do
				if b == "Uncommon" then
					commonHugeBeatsUnc = true
				end
			end
		end
		if d.From == "Rare" and d.Size == "Titanic" and d.BeatsEpic then
			rareTitBeatsEpic = true
		end
		if d.From == "Epic" and d.Size == "Titanic" and d.BeatsLegendary then
			epicTitBeatsLeg = true
		end
	end
	if uncTitBeatsRare then
		score += 12
	elseif (model.Chance.Uncommon.Titanic or 0) > 0 then
		score += 4 -- present but soft
	end
	if commonHugeBeatsUnc then
		score += 6
	elseif (model.Chance.Common.Huge or 0) > 0 then
		score += 3
	end
	if commonTitBeatsUnc then
		score += 5
	end
	-- Rare retains value: Rare Tit should compete with Epic, Rare Huge should not obliterate Epic
	if rareTitBeatsEpic then
		score += 10
	end
	local rareHugeBeatsEpic = false
	for _, d in dom do
		if d.From == "Rare" and d.Size == "Huge" and d.BeatsEpic then
			rareHugeBeatsEpic = true
		end
	end
	if not rareHugeBeatsEpic then
		score += 8 -- Rare Huge shouldn't trivialize Epic Normal
	else
		score -= 10
	end
	-- Epic+ Tit exceptional: should beat Legendary, but Legendary Tit shouldn't be common
	if epicTitBeatsLeg then
		score += 6
	end
	local etaTit1h = pack.Schedule["1h"]
	if etaTit1h then
		local pTit = etaTit1h.PAtLeastTit or 0
		if pTit < 0.15 then
			score += 10 -- still rare in first hour
		elseif pTit < 0.35 then
			score += 5
		else
			score -= 8 -- Tit too common early
		end
	end
	local etaTit20m = pack.Schedule["0.333h"] or pack.Schedule["20m"]
	-- Luck matters: pHuge(L200)/pHuge(L10) ratio
	local pH10 = pack.AbsP[10] and pack.AbsP[10].Huge or 0
	local pH150 = pack.AbsP[150] and pack.AbsP[150].Huge or 0
	if pH10 > 0 and pH150 / pH10 >= 1.8 then
		score += 10
	elseif pH10 > 0 and pH150 / pH10 >= 1.3 then
		score += 5
	else
		score -= 4
	end
	-- Long-term goals: 50% Huge stamps not trivial before 10h, achievable by 100h
	local fill = pack.Fill50
	if fill and fill.HugeH then
		if fill.HugeH >= 8 and fill.HugeH <= 80 then
			score += 10
		elseif fill.HugeH >= 3 then
			score += 4
		else
			score -= 6
		end
	end
	if fill and fill.TitH then
		if fill.TitH >= 15 and fill.TitH <= 200 then
			score += 10
		elseif fill.TitH >= 8 then
			score += 4
		else
			score -= 6
		end
	end
	-- Economy not trivial: Common Tit must not beat Epic Normal
	for _, d in dom do
		if d.From == "Common" and d.Size == "Titanic" and d.BeatsEpic then
			score -= 25
		end
		if d.From == "Uncommon" and d.Size == "Titanic" and d.BeatsLegendary then
			score -= 20
		end
		if d.From == "Common" and d.Size == "Huge" and d.BeatsEpic then
			score -= 20
		end
	end
	-- Album breadth bonus for hypothetical low-tier coverage
	local hugeE, titE = eligibleCounts(model)
	score += math.min(8, (hugeE - 60) / 5) -- prefer covering more of roster
	score += math.min(6, (titE - 40) / 8)
	return score
end

------------------------------------------------------------------------
-- Run evaluation
------------------------------------------------------------------------
local timer = SimRuntime.start("sizeBalanceEval")
print("=== Size Balance Evaluation (SoftCap_P5_Bands / SoftenD) ===")
print(`RPM={RPM}  RebirthCost={REBIRTH_COST}  relics={#RelicConfig.Relics}  seed0={SEED0}`)
print(`Luck schedule: 20m→{fmt(luckAtHours(20 / 60))}  1h→{fmt(luckAtHours(1))}  3h→{fmt(luckAtHours(3))}  10h→{fmt(luckAtHours(10))}  30h→{fmt(luckAtHours(30))}  100h→{fmt(luckAtHours(100))}`)
print("\nMid-tier Normal incomes (CE/s base):")
for _, tier in TIERS do
	print(string.format(
		"  %-12s n=%2d  min=%s mid=%s max=%s",
		tier,
		countByTier[tier] or 0,
		fmt(minIncome[tier] or 0),
		fmt(midIncome[tier] or 0),
		fmt(maxIncome[tier] or 0)
	))
end

local report: any = {
	Meta = {
		Trial = "SoftCap_P5_Bands",
		Profile = SoftCapRarity.activeProfile(),
		RPM = RPM,
		RebirthCost = REBIRTH_COST,
		Seed0 = SEED0,
		RelicCount = #RelicConfig.Relics,
		LuckSchedule = {},
		MidIncome = midIncome,
		CountByTier = countByTier,
	},
	Models = {},
}

for _, h in HORIZONS_H do
	report.Meta.LuckSchedule[tostring(h) .. "h"] = luckAtHours(h)
end

for _, model in MODELS do
	print(`\n######## {model.Id}: {model.Label}`)
	print(`  power Huge×{model.HugeMult} Titanic×{model.TitMult} | {model.Notes}`)
	local hugeE, titE, comboN = eligibleCounts(model)
	print(`  eligible Huge stamps={hugeE}  Tit stamps={titE}  base size-combos={comboN}`)

	print(string.format("  %-12s %10s %10s %12s %12s", "Tier", "Huge 1-in", "Tit 1-in", "P(H|tier)", "P(T|tier)"))
	for _, tier in TIERS do
		local r = model.Chance[tier]
		local pH, pT = r.Huge or 0, r.Titanic or 0
		print(string.format(
			"  %-12s %10s %10s %12.6f %12.6f",
			tier,
			if pH > 0 then fmt(1 / pH) else "—",
			if pT > 0 then fmt(1 / pT) else "—",
			pH,
			pT
		))
	end

	local absP = {}
	print(string.format(
		"  %-6s %8s %8s %10s %10s %10s %10s",
		"Luck",
		"C%",
		"E+%",
		"P(Huge)",
		"P(Tit)",
		"ETA H m",
		"ETA T m"
	))
	for _, L in LUCK_POINTS do
		local bands = SoftCapRarity.softCapBandPercents(L)
		local pH, pT = absSizeP(model, L)
		local ePlus = 0
		for _, tier in { "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" } do
			ePlus += bands[tier] or 0
		end
		absP[L] = { Huge = pH, Tit = pT, CommonPct = bands.Common, EpicPlusPct = ePlus }
		print(string.format(
			"  %-6d %8.1f %8.1f %10.5f %10.6f %10s %10s",
			L,
			bands.Common or 0,
			ePlus,
			pH,
			pT,
			fmt(meanWaitMin(pH)),
			fmt(meanWaitMin(pT))
		))
	end

	-- Schedule-integrated expectations
	local schedule = {}
	print(string.format(
		"  %-8s %8s %8s %10s %10s %10s %10s",
		"Horizon",
		"E[H]",
		"E[T]",
		"P(≥1H)",
		"P(≥1T)",
		"Luck",
		""
	))
	for _, h in HORIZONS_H do
		local eH, eT = expectedCountsOverHours(model, h)
		local key = if h < 1 then "20m" else `{h}h`
		schedule[key] = {
			Hours = h,
			EHuge = eH,
			ETit = eT,
			PAtLeastHuge = pAtLeastOne(eH),
			PAtLeastTit = pAtLeastOne(eT),
			LuckEnd = luckAtHours(h),
		}
		-- also index by "0.333h" for scorer
		if h < 1 then
			schedule["0.333h"] = schedule[key]
		end
		print(string.format(
			"  %-8s %8.2f %8.3f %9.1f%% %9.1f%% %10s",
			key,
			eH,
			eT,
			pAtLeastOne(eH) * 100,
			pAtLeastOne(eT) * 100,
			fmt(luckAtHours(h))
		))
	end

	-- Rarity×size ETA at L80 and L150
	print("  Combo ETA hours @ L80 / L150 (geometric):")
	local comboEta = {}
	for _, tier in TIERS do
		for _, size in { "Huge", "Titanic" } do
			local e80 = comboEtaHours(model, tier, size, 80)
			local e150 = comboEtaHours(model, tier, size, 150)
			if e80 < math.huge or e150 < math.huge then
				comboEta[`{tier}_{size}`] = { L80 = e80, L150 = e150 }
				print(string.format("    %-18s  L80=%sh  L150=%sh", `{tier} {size}`, fmt(e80), fmt(e150)))
			end
		end
	end

	local dom = incomeDominance(model)
	print("  Income dominance (mid relic × size vs higher-tier mid Normal):")
	for _, d in dom do
		if #d.Beats > 0 or d.BeatsEpic then
			print(string.format(
				"    %s %s income=%s  beats Normal: %s%s%s",
				d.From,
				d.Size,
				fmt(d.Income),
				table.concat(d.Beats, ","),
				if d.BeatsEpic then " [≥Epic]" else "",
				if d.BeatsLegendary then " [≥Leg]" else ""
			))
		end
	end
	-- Always print key comparisons
	print(string.format(
		"  Key: mid Common N=%s H=%s T=%s | Unc N=%s H=%s T=%s | Rare N=%s H=%s T=%s | Epic N=%s | Leg N=%s",
		fmt(midIncome.Common),
		fmt(sizeIncome("Common", "Huge", model)),
		fmt(sizeIncome("Common", "Titanic", model)),
		fmt(midIncome.Uncommon),
		fmt(sizeIncome("Uncommon", "Huge", model)),
		fmt(sizeIncome("Uncommon", "Titanic", model)),
		fmt(midIncome.Rare),
		fmt(sizeIncome("Rare", "Huge", model)),
		fmt(sizeIncome("Rare", "Titanic", model)),
		fmt(midIncome.Epic),
		fmt(midIncome.Legendary)
	))

	local t50H, t50T = stampFillProjection(model, 100, 0.5)
	local t90H, t90T = stampFillProjection(model, 200, 0.9)
	print(string.format(
		"  Stamp fill (analytical coupon): 50%% Huge≈%sh  50%% Tit≈%sh | 90%% Huge≈%sh  90%% Tit≈%sh",
		fmt(t50H or math.huge),
		fmt(t50T or math.huge),
		fmt(t90H or math.huge),
		fmt(t90T or math.huge)
	))

	local shock = rosterUpdateShock(model, 4, 2, 150)
	print(string.format(
		"  Roster +4 Common +2 Rare @L150: new Huge-eligible≈%d  ETA first new Huge=%sh  new Tit=%sh",
		shock.NewHugeEligible,
		fmt(shock.EtaFirstNewHugeH),
		fmt(shock.EtaFirstNewTitH)
	))

	-- Thin MC at selected horizons (fixed luck = schedule end luck)
	local mc = {}
	local mcPlan = {
		{ h = 20 / 60, seeds = 48, mut = 0 },
		{ h = 1, seeds = 32, mut = 1 },
		{ h = 3, seeds = 24, mut = 1 },
		{ h = 10, seeds = 16, mut = 2 },
		-- 30h/100h: fewer seeds, analytical already covers E[count]
		{ h = 30, seeds = 6, mut = 2 },
		{ h = 100, seeds = 3, mut = 3 },
	}
	print("  MC (keep-best 5 pedestals, unique combos):")
	for _, plan in mcPlan do
		local row = mcHorizon(model, plan.h, luckAtHours(plan.h), plan.seeds, plan.mut)
		local key = if plan.h < 1 then "20m" else `{plan.h}h`
		mc[key] = row
		print(string.format(
			"    %s: P(H)=%.0f%% P(T)=%.0f%% medFirstH=%sh medFirstT=%sh stamps=%.1f combos=%.0f newBase=%.0f pedCE≈%s",
			key,
			row.PFirstHuge * 100,
			row.PFirstTit * 100,
			fmt(row.MedFirstHugeH),
			fmt(row.MedFirstTitH),
			row.MeanSizeStamps,
			row.MeanUniqueCombos,
			row.MeanNewBases,
			fmt(row.MeanBestPedCE)
		))
	end

	-- Rebirth projection proxy: CE from pedestal income integrate (very rough)
	local ce = 0
	local rebirthH = nil
	local dt = 0.05
	for t = 0, 40, dt do
		local L = luckAtHours(t)
		-- assume ped CE/s grows with global mult × mid rare-ish board
		local ped = (midIncome.Rare or 1) * 3 * globalIncomeMultAtHours(t) * (0.5 + L / 200)
		ce += ped * dt * 3600
		if not rebirthH and ce >= REBIRTH_COST then
			rebirthH = t
		end
	end
	print(string.format(
		"  Rough CE integrate → first Rebirth ≈ %sh (cost unchanged; size model affects ped mix only via MC pedCE)",
		fmt(rebirthH or math.huge)
	))

	local pack = {
		Id = model.Id,
		Label = model.Label,
		Notes = model.Notes,
		HugeMult = model.HugeMult,
		TitMult = model.TitMult,
		Chance = model.Chance,
		EligibleHuge = hugeE,
		EligibleTit = titE,
		SizeCombos = comboN,
		AbsP = absP,
		Schedule = schedule,
		ComboEta = comboEta,
		Dominance = dom,
		Fill50 = { HugeH = t50H, TitH = t50T },
		Fill90 = { HugeH = t90H, TitH = t90T },
		RosterShock = shock,
		MC = mc,
		RebirthHoursProxy = rebirthH,
		KeyIncomes = {
			CommonN = midIncome.Common,
			CommonH = sizeIncome("Common", "Huge", model),
			CommonT = sizeIncome("Common", "Titanic", model),
			UncommonN = midIncome.Uncommon,
			UncommonH = sizeIncome("Uncommon", "Huge", model),
			UncommonT = sizeIncome("Uncommon", "Titanic", model),
			RareN = midIncome.Rare,
			RareH = sizeIncome("Rare", "Huge", model),
			RareT = sizeIncome("Rare", "Titanic", model),
			EpicN = midIncome.Epic,
			LegendaryN = midIncome.Legendary,
		},
	}
	pack.Score = scoreModel(model, pack)
	print(`  SCORE={fmt(pack.Score)}`)
	table.insert(report.Models, pack)
end

table.sort(report.Models, function(a, b)
	return (a.Score or 0) > (b.Score or 0)
end)

print("\n======== RANKING ========")
for i, m in report.Models do
	print(string.format("%d. %s  score=%s  H×%.2f T×%.2f  %s", i, m.Id, fmt(m.Score), m.HugeMult, m.TitMult, m.Notes))
end

local top2 = { report.Models[1], report.Models[2] }
report.Top2 = { top2[1].Id, top2[2].Id }
-- Prefer Balanced_Studio for Studio if in top 3, else top1
local studioRec = top2[1].Id
for i = 1, math.min(3, #report.Models) do
	if report.Models[i].Id == "Balanced_Studio" or report.Models[i].Id == "Balanced_Album" then
		studioRec = report.Models[i].Id
		break
	end
end
report.StudioRecommendation = studioRec

print(`\nTOP2: {top2[1].Id}, {top2[2].Id}`)
print(`STUDIO REC: {studioRec}`)

SimRuntime.mark(timer, "done")
print(SimRuntime.report(timer))

-- Write machine-readable report for canvas
local outPath = "docs/SIZE_BALANCE_EVAL.json"
fs.writeFile(outPath, serde.encode("json", report))
print(`Wrote {outPath}`)
