-- Targeted Size-variant economy / novelty eval (no full progression sweep).
-- Run: lune run tests/variantEconomyEval

local BalanceTrials = require("../src/shared/BalanceTrials")
local RelicConfig = require("../src/shared/RelicConfig")
local RelicIncome = require("./lib/relicIncome")
local SizeConfig = require("../src/shared/SizeConfig")
local SoftCapRarity = require("../src/shared/SoftCapRarity")
local MutationConfig = require("../src/shared/MutationConfig")
local RarityConfig = require("../src/shared/RarityConfig")

BalanceTrials.AllowNonStudioActive = true
BalanceTrials.Active = "SoftCap_P4"
BalanceTrials.CollectionPrototype = true
SoftCapRarity.invalidateSampler()

local RPM = 49 -- observed Studio playtest calibration
local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }

local function fmt(n: number): string
	if n ~= n or n == math.huge then
		return "∞"
	end
	if n >= 100 then
		return string.format("%.0f", n)
	elseif n >= 10 then
		return string.format("%.1f", n)
	end
	return string.format("%.2f", n)
end

local function meanWaitMin(pPerReward: number): number
	if pPerReward <= 0 then
		return math.huge
	end
	return (1 / pPerReward) / RPM
end

local function expectedCount(pPerReward: number, minutes: number): number
	return pPerReward * RPM * minutes
end

print("=== Size variant probability audit (SoftCap_P4 Studio) ===\n")
print(`Calibration: {RPM} rewards/min (playtest-observed)\n`)

print("Per-tier conditional P(size | tier) from SizeConfig:")
print(string.format("%-12s %12s %12s %14s %14s", "Tier", "Huge 1-in", "Titanic 1-in", "P(Huge)", "P(Titanic)"))
for _, tier in TIERS do
	local row = SizeConfig.ChanceByTier[tier]
	local pH, pT = row.Huge or 0, row.Titanic or 0
	print(string.format(
		"%-12s %12s %12s %14.6f %14.6f",
		tier,
		if pH > 0 then fmt(1 / pH) else "—",
		if pT > 0 then fmt(1 / pT) else "—",
		pH,
		pT
	))
end

local luckPoints = { 1, 10, 30, 50, 80, 150 }
print("\nSoftCap band mix (%) by Luck → absolute P(Huge)/P(Titanic) per reward:")
print(string.format(
	"%-6s %8s %8s %8s %8s %10s %10s %10s %12s %12s",
	"Luck",
	"C%",
	"U%",
	"R%",
	"E+%",
	"P(Huge)",
	"P(Tit)",
	"1-in H",
	"ETA Huge m",
	"ETA Tit m"
))

local bandAt: { [number]: any } = {}
for _, L in luckPoints do
	local bands = SoftCapRarity.softCapBandPercents(L)
	bandAt[L] = bands
	local pHuge, pTit = 0, 0
	local ePlus = 0
	for _, tier in TIERS do
		local share = (bands[tier] or 0) / 100
		local row = SizeConfig.ChanceByTier[tier]
		pHuge += share * (row.Huge or 0)
		pTit += share * (row.Titanic or 0)
		local idx = RarityConfig.IndexById[tier] or 0
		if idx >= (RarityConfig.IndexById.Epic or 4) then
			ePlus += bands[tier] or 0
		end
	end
	print(string.format(
		"%-6d %8.1f %8.1f %8.1f %8.1f %10.5f %10.6f %10s %12s %12s",
		L,
		bands.Common or 0,
		bands.Uncommon or 0,
		bands.Rare or 0,
		ePlus,
		pHuge,
		pTit,
		if pHuge > 0 then fmt(1 / pHuge) else "—",
		fmt(meanWaitMin(pHuge)),
		fmt(meanWaitMin(pTit))
	))
end

-- Representative mid-session luck from playtest (~L80 at 20m)
local L_REF = 80
local bands = SoftCapRarity.softCapBandPercents(L_REF)
local pHuge, pTit = 0, 0
local contribH: { [string]: number } = {}
local contribT: { [string]: number } = {}
for _, tier in TIERS do
	local share = (bands[tier] or 0) / 100
	local row = SizeConfig.ChanceByTier[tier]
	local h = share * (row.Huge or 0)
	local t = share * (row.Titanic or 0)
	pHuge += h
	pTit += t
	contribH[tier] = h
	contribT[tier] = t
end

print(`\n--- Expected counts @ Luck {L_REF} (playtest ~20m Luck) ---`)
print(string.format("%-8s %10s %10s %12s %12s", "Minutes", "E[Huge]", "E[Tit]", "P(≥1 Huge)", "P(≥1 Tit)"))
for _, minutes in { 20, 22.5, 60, 180, 360, 600 } do
	local n = RPM * minutes
	local eH, eT = pHuge * n, pTit * n
	local p1H = 1 - math.exp(-eH)
	local p1T = 1 - math.exp(-eT)
	print(string.format("%-8s %10.2f %10.3f %12.1f%% %12.1f%%", tostring(minutes), eH, eT, p1H * 100, p1T * 100))
end

print("\nHuge source mix @ L80 (share of all Huge rolls):")
for _, tier in TIERS do
	if (contribH[tier] or 0) > 0 then
		print(string.format("  %-12s %5.1f%% of Huge", tier, 100 * contribH[tier] / pHuge))
	end
end
print("Titanic source mix @ L80:")
for _, tier in TIERS do
	if (contribT[tier] or 0) > 0 then
		print(string.format("  %-12s %5.1f%% of Titanic", tier, 100 * contribT[tier] / pTit))
	end
end

-- Income risk: pick median-ish relics per tier
print("\n=== Income risk (×1.5 / ×2.5 vs proposed ×1.15 / ×1.40) ===\n")
local byTier: { [string]: { any } } = {}
for _, relic in RelicConfig.Relics do
	byTier[relic.Tier] = byTier[relic.Tier] or {}
	table.insert(byTier[relic.Tier], relic)
end
local function mid(tier: string): any?
	local list = byTier[tier]
	if not list or #list == 0 then
		return nil
	end
	table.sort(list, function(a, b)
		return RelicIncome.of(a.Id) < RelicIncome.of(b.Id)
	end)
	return list[math.ceil(#list / 2)]
end

print(string.format(
	"%-12s %10s %10s %10s %10s %10s %10s",
	"Tier",
	"Normal",
	"H×1.5",
	"H×1.15",
	"T×2.5",
	"T×1.40",
	"vs N Epic"
))
local epicMid = mid("Epic")
local epicInc = if epicMid then RelicIncome.of(epicMid.Id) else 0
for _, tier in { "Uncommon", "Rare", "Epic", "Legendary" } do
	local r = mid(tier)
	if r then
		local base = RelicIncome.of(r.Id)
		print(string.format(
			"%-12s %10.3f %10.3f %10.3f %10.3f %10.3f %10.2fx",
			tier,
			base,
			base * 1.5,
			base * 1.15,
			base * 2.5,
			base * 1.40,
			if epicInc > 0 then (base * 2.5) / epicInc else 0
		))
	end
end
print("(last col = mid-tier Titanic×2.5 / mid-Epic Normal — >1 means Titanic of that tier beats a Normal Epic)")

-- Novelty Monte Carlo: SoftCap rolls + size + mutation novelty (thin; not full economy)
print("\n=== Novelty MC (SoftCap rolls only; AFK vs Hunt-ish luck) ===")
print("Distinctive = First base OR new mutation OR new Huge/Titanic stamp (not ordinary C/U Normal dupe)\n")

print(`MutationChanceByRank: R1={MutationConfig.ChanceAt(1)} R2={MutationConfig.ChanceAt(2)}`)

local function rollMutation(rng: () -> number, rank: number): string?
	local chance = MutationConfig.ChanceAt(rank)
	if chance <= 0 or rng() >= chance then
		return nil
	end
	local unlocked = {}
	local weightSum = 0
	for _, m in MutationConfig.Mutations do
		if m.UnlockRank <= rank then
			table.insert(unlocked, m)
			weightSum += m.Weight
		end
	end
	if weightSum <= 0 then
		return nil
	end
	local r = rng() * weightSum
	for _, m in unlocked do
		r -= m.Weight
		if r < 0 then
			return m.Id
		end
	end
	return unlocked[#unlocked].Id
end

local function runPolicy(name: string, luck: number, minutes: number, seeds: number, mutRank: number)
	local rewards = math.floor(RPM * minutes)
	local agg = {
		baseDupes = 0,
		visualIdent = 0, -- same Id+Mut+Size Normal C/U after first
		newBase = 0,
		newMut = 0,
		newSize = 0,
		huge = 0,
		titanic = 0,
		distinctiveGaps = {} :: { number },
		lastDistinct = 0,
	}
	for seed = 1, seeds do
		local rngState = seed * 9973 + 13
		local function rng(): number
			rngState = (rngState * 1103515245 + 12345) % 2 ^ 31
			return rngState / 2 ^ 31
		end
		local discovered: { [string]: boolean } = {}
		local mutSeen: { [string]: boolean } = {} -- relic|mut
		local sizeSeen: { [string]: boolean } = {} -- relic|size
		local lastD = 0
		local gaps = {}
		local s = SoftCapRarity.samplerFor(luck)
		for i = 1, rewards do
			-- sample relic from SoftCap weights
			local target = rng() * s.Total
			local id, tier = s.Ids[#s.Ids], s.Tiers[#s.Tiers]
			local acc = 0
			for wi = 1, #s.Weights do
				acc += s.Weights[wi]
				if target < acc then
					id, tier = s.Ids[wi], s.Tiers[wi]
					break
				end
			end
			local mut = rollMutation(rng, mutRank)
			local size = SizeConfig.roll(tier, rng)
			local first = discovered[id] ~= true
			if first then
				discovered[id] = true
			end
			local newMut = false
			if mut then
				local mk = `{id}|{mut}`
				if not mutSeen[mk] then
					mutSeen[mk] = true
					newMut = true
				end
			end
			local newSize = false
			if size then
				local sk = `{id}|{size}`
				if not sizeSeen[sk] then
					sizeSeen[sk] = true
					newSize = true
				end
				if size == "Huge" then
					agg.huge += 1
				else
					agg.titanic += 1
				end
			end
			local ordinary = not first
				and not newMut
				and not newSize
				and mut == nil
				and size == nil
				and (tier == "Common" or tier == "Uncommon")
			local distinctive = first or newMut or newSize
			if first then
				agg.newBase += 1
			end
			if newMut then
				agg.newMut += 1
			end
			if newSize then
				agg.newSize += 1
			end
			if not first and not newMut and not newSize then
				agg.baseDupes += 1
			end
			if ordinary then
				agg.visualIdent += 1
			end
			if distinctive then
				if lastD > 0 then
					table.insert(gaps, i - lastD)
				end
				lastD = i
			end
		end
		for _, g in gaps do
			table.insert(agg.distinctiveGaps, g)
		end
	end
	local n = seeds * rewards
	local function avg(key: string): number
		return (agg :: any)[key] / seeds
	end
	local gapSum, gapN = 0, #agg.distinctiveGaps
	for _, g in agg.distinctiveGaps do
		gapSum += g
	end
	local meanGapRewards = if gapN > 0 then gapSum / gapN else math.huge
	local meanGapMin = meanGapRewards / RPM
	print(string.format(
		"%s L=%d %dm ×%d seeds | rewards/run=%d",
		name,
		luck,
		minutes,
		seeds,
		rewards
	))
	print(string.format(
		"  newBase=%.1f  newMut=%.1f  newSize=%.1f  Huge=%.2f  Tit=%.3f",
		avg("newBase"),
		avg("newMut"),
		avg("newSize"),
		avg("huge"),
		avg("titanic")
	))
	print(string.format(
		"  baseDupes=%.0f (%.1f%%)  visualIdent C/U Normal=%.0f (%.1f%%)",
		avg("baseDupes"),
		100 * avg("baseDupes") / rewards,
		avg("visualIdent"),
		100 * avg("visualIdent") / rewards
	))
	print(string.format(
		"  mean gap between distinctive rewards: %.1f rewards (%.2f min)",
		meanGapRewards,
		meanGapMin
	))
	-- Without size: distinctive = first or newMut only — recompute gap ratio
	return agg
end

-- Compare with size OFF for same seeds (novelty delta)
local function runCompare(luck: number, minutes: number, seeds: number, mutRank: number)
	local rewards = math.floor(RPM * minutes)
	local withSize, without = 0, 0
	local visWith, visWithout = 0, 0
	local sizeStamps = 0
	for seed = 1, seeds do
		local rngState = seed * 9973 + 13
		local function rng(): number
			rngState = (rngState * 1103515245 + 12345) % 2 ^ 31
			return rngState / 2 ^ 31
		end
		local discovered = {}
		local mutSeen = {}
		local sizeSeen = {}
		local s = SoftCapRarity.samplerFor(luck)
		for i = 1, rewards do
			local target = rng() * s.Total
			local id, tier = s.Ids[#s.Ids], s.Tiers[#s.Tiers]
			local acc = 0
			for wi = 1, #s.Weights do
				acc += s.Weights[wi]
				if target < acc then
					id, tier = s.Ids[wi], s.Tiers[wi]
					break
				end
			end
			local mut = rollMutation(rng, mutRank)
			local size = SizeConfig.roll(tier, rng)
			local first = discovered[id] ~= true
			if first then
				discovered[id] = true
			end
			local newMut = false
			if mut then
				local mk = `{id}|{mut}`
				if not mutSeen[mk] then
					mutSeen[mk] = true
					newMut = true
				end
			end
			local newSize = false
			if size then
				local sk = `{id}|{size}`
				if not sizeSeen[sk] then
					sizeSeen[sk] = true
					newSize = true
				end
				sizeStamps += 1
			end
			local ordinary = not first
				and not newMut
				and not newSize
				and mut == nil
				and size == nil
				and (tier == "Common" or tier == "Uncommon")
			local ordinaryNoSize = not first
				and not newMut
				and mut == nil
				and (tier == "Common" or tier == "Uncommon")
			if first or newMut or newSize then
				withSize += 1
			end
			if first or newMut then
				without += 1
			end
			if ordinary then
				visWith += 1
			end
			if ordinaryNoSize then
				visWithout += 1
			end
		end
	end
	local n = seeds * rewards
	print(string.format(
		"COMPARE L=%d %dm: distinctive/run WITH size=%.1f  WITHOUT=%.1f  (+%.1f from stamps)",
		luck,
		minutes,
		withSize / seeds,
		without / seeds,
		(withSize - without) / seeds
	))
	print(string.format(
		"  visualIdent C/U Normal/run: WITH=%.0f (%.1f%% of rewards)  WITHOUT=%.0f (%.1f%%)",
		visWith / seeds,
		100 * visWith / n,
		visWithout / seeds,
		100 * visWithout / n
	))
	print(string.format("  size stamp events/run (incl dupes)=%.2f", sizeStamps / seeds))
end

runPolicy("AFK-like", 10, 22.5, 40, 0)
runPolicy("AFK mid", 30, 22.5, 40, 1)
runPolicy("Hunter-ish", 80, 22.5, 40, 1)
runPolicy("AFK 60m", 30, 60, 24, 1)
runPolicy("Hunter 60m", 80, 60, 24, 1)
runPolicy("Hunter 180m", 100, 180, 12, 2)

runCompare(80, 22.5, 40, 1)
runCompare(80, 60, 24, 1)
runCompare(10, 22.5, 40, 0) -- playtest early AFK-ish, no mut rank

-- Long-term size completion projection (92 relics × 2 sizes = 184 stamps; Common never sizes)
local sizeEligible = 0
for _, relic in RelicConfig.Relics do
	if relic.Tier ~= "Common" then
		sizeEligible += 1
	end
end
print(`\n=== Long-term stamp collection (eligible relics={sizeEligible}, stamps={sizeEligible * 2}) ===`)
-- Rough: at L80, P(new size stamp) shrinks as collection fills — coupon collector approx using uniform over eligible
-- Better: MC coupon for Huge only on Uncommon+ at fixed luck
local function stampCoupon(luck: number, seeds: number, maxRewards: number)
	local s = SoftCapRarity.samplerFor(luck)
	local totals = {}
	for seed = 1, seeds do
		local rngState = seed * 4243 + 7
		local function rng(): number
			rngState = (rngState * 1103515245 + 12345) % 2 ^ 31
			return rngState / 2 ^ 31
		end
		local seenH: { [string]: boolean } = {}
		local seenT: { [string]: boolean } = {}
		local nH, nT = 0, 0
		local needH, needT = sizeEligible, sizeEligible -- Titanic never on Uncommon
		-- Titanic eligible = Rare+
		local titEligible = 0
		for _, relic in RelicConfig.Relics do
			if relic.Tier ~= "Common" and relic.Tier ~= "Uncommon" then
				titEligible += 1
			end
		end
		needT = titEligible
		local t50H, t90H, t50T, t90T = nil, nil, nil, nil
		for i = 1, maxRewards do
			local target = rng() * s.Total
			local id, tier = s.Ids[#s.Ids], s.Tiers[#s.Tiers]
			local acc = 0
			for wi = 1, #s.Weights do
				acc += s.Weights[wi]
				if target < acc then
					id, tier = s.Ids[wi], s.Tiers[wi]
					break
				end
			end
			local size = SizeConfig.roll(tier, rng)
			if size == "Huge" and not seenH[id] then
				seenH[id] = true
				nH += 1
				if not t50H and nH >= needH * 0.5 then
					t50H = i
				end
				if not t90H and nH >= needH * 0.9 then
					t90H = i
				end
			elseif size == "Titanic" and not seenT[id] then
				seenT[id] = true
				nT += 1
				if not t50T and nT >= needT * 0.5 then
					t50T = i
				end
				if not t90T and nT >= needT * 0.9 then
					t90T = i
				end
			end
			if nH >= needH and nT >= needT then
				break
			end
		end
		table.insert(totals, {
			h = nH,
			t = nT,
			t50H = t50H,
			t90H = t90H,
			t50T = t50T,
			t90T = t90T,
			needH = needH,
			needT = needT,
		})
	end
	local function avgField(field: string): number
		local sum, n = 0, 0
		for _, row in totals do
			local v = (row :: any)[field]
			if type(v) == "number" then
				sum += v
				n += 1
			end
		end
		return if n > 0 then sum / n else math.huge
	end
	print(string.format(
		"L=%d coupon (cap %d rewards ≈ %.0fh @%drpm): Huge 50%%≈%.0fm 90%%≈%.0fm | Tit 50%%≈%.0fm 90%%≈%.0fm",
		luck,
		maxRewards,
		maxRewards / RPM / 60,
		RPM,
		avgField("t50H") / RPM,
		avgField("t90H") / RPM,
		avgField("t50T") / RPM,
		avgField("t90T") / RPM
	))
	print(string.format(
		"  mean stamps found in cap: Huge %.1f/%d  Titanic %.1f/%d",
		avgField("h"),
		totals[1].needH,
		avgField("t"),
		totals[1].needT
	))
end

stampCoupon(80, 16, RPM * 60 * 20) -- 20h cap
stampCoupon(150, 12, RPM * 60 * 20)

print("\n=== Inventory risk (code audit) ===")
print("Huge/Titanic: hard unsellable (SellService + AutoSell Sized + Sellable=0).")
print("No keep-best / sell-extra path — duplicate sized copies permanently occupy backpack slots.")
print("CodexSizes persists independently of inventory (discovery stamp survives sells of Normal copies).")
print("BEST owned collectible is NOT auto-tracked beyond inventory grouping — extras accumulate.")

print("\nDone.")
