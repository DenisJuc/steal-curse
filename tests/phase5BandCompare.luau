-- SoftCap_P4 vs SoftCap_P5_Bands rolling novelty compare (focused, not full economy sweep).
-- Luck path approximates playtest pt_153530464_559fa945 minute marks.
-- Run: lune run tests/phase5BandCompare

local BalanceTrials = require("../src/shared/BalanceTrials")
local MutationConfig = require("../src/shared/MutationConfig")
local RarityConfig = require("../src/shared/RarityConfig")
local SizeConfig = require("../src/shared/SizeConfig")
local SoftCapRarity = require("../src/shared/SoftCapRarity")

local RPM = 49
local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }

-- Piecewise Luck from playtest minute marks (extrapolated gently after 20m).
local function luckAtMinute(m: number): number
	if m <= 5 then
		return 1 + (6.47 - 1) * (m / 5)
	elseif m <= 10 then
		return 6.47 + (27.87 - 6.47) * ((m - 5) / 5)
	elseif m <= 15 then
		return 27.87 + (67.21 - 27.87) * ((m - 10) / 5)
	elseif m <= 20 then
		return 67.21 + (81.43 - 67.21) * ((m - 15) / 5)
	elseif m <= 60 then
		return 81.43 + (100 - 81.43) * ((m - 20) / 40)
	elseif m <= 180 then
		return 100 + (130 - 100) * ((m - 60) / 120)
	else
		return 130 + (150 - 130) * math.min(1, (m - 180) / 420)
	end
end

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

local function mutRankAtMinute(m: number): number
	-- Playtest bought MutationResonance ~8:27 → treat as 0 until 8.5m, then 1.
	if m < 8.5 then
		return 0
	elseif m < 90 then
		return 1
	else
		return 2
	end
end

local function ePlusShare(b: { [string]: number }): number
	local s = 0
	for _, t in TIERS do
		if (RarityConfig.IndexById[t] or 0) >= (RarityConfig.IndexById.Epic or 4) then
			s += b[t] or 0
		end
	end
	return s
end

local function runTrial(trialId: string, minutes: number, seeds: number, policy: string)
	BalanceTrials.AllowNonStudioActive = true
	BalanceTrials.Active = trialId
	BalanceTrials.CollectionPrototype = true
	SoftCapRarity.invalidateSampler()
	SoftCapRarity.syncFromTrials()

	local rewards = math.floor(RPM * minutes)
	local agg = {
		newBase = 0,
		newMut = 0,
		newSize = 0,
		huge = 0,
		tit = 0,
		visual = 0,
		epicPlus = 0,
		c = 0,
		u = 0,
		r = 0,
		gaps = {} :: { number },
		uniqueEnd = 0,
		sizeStamps = 0,
	}

	for seed = 1, seeds do
		local rngState = seed * 7919 + (if trialId == "SoftCap_P5_Bands" then 100 else 0)
		local function rng(): number
			rngState = (rngState * 1103515245 + 12345) % 2 ^ 31
			return rngState / 2 ^ 31
		end
		local discovered = {}
		local mutSeen = {}
		local sizeSeen = {}
		local lastD = 0
		local unique = 0
		for i = 1, rewards do
			local minute = (i / RPM)
			local luck = luckAtMinute(minute)
			if policy == "Hunter" then
				luck = luck * 1.15 -- hunt luck factor partial
			end
			local mutRank = mutRankAtMinute(minute)
			local id, tier = SoftCapRarity.roll(luck, rng)
			local mut = rollMutation(rng, mutRank)
			local size = SizeConfig.roll(tier, rng)
			local first = discovered[id] ~= true
			if first then
				discovered[id] = true
				unique += 1
				agg.newBase += 1
			end
			local newMut = false
			if mut then
				local mk = `{id}|{mut}`
				if not mutSeen[mk] then
					mutSeen[mk] = true
					newMut = true
					agg.newMut += 1
				end
			end
			local newSize = false
			if size then
				agg.sizeStamps += 1
				if size == "Huge" then
					agg.huge += 1
				else
					agg.tit += 1
				end
				local sk = `{id}|{size}`
				if not sizeSeen[sk] then
					sizeSeen[sk] = true
					newSize = true
					agg.newSize += 1
				end
			end
			if tier == "Common" then
				agg.c += 1
			elseif tier == "Uncommon" then
				agg.u += 1
			elseif tier == "Rare" then
				agg.r += 1
			else
				agg.epicPlus += 1
			end
			local ordinary = not first
				and not newMut
				and not newSize
				and mut == nil
				and size == nil
				and (tier == "Common" or tier == "Uncommon")
			if ordinary then
				agg.visual += 1
			end
			local distinctive = first or newMut or newSize
			if distinctive then
				if lastD > 0 then
					table.insert(agg.gaps, i - lastD)
				end
				lastD = i
			end
		end
		agg.uniqueEnd += unique
	end

	local function avg(n: number): number
		return n / seeds
	end
	local gapSum = 0
	for _, g in agg.gaps do
		gapSum += g
	end
	local meanGap = if #agg.gaps > 0 then gapSum / #agg.gaps else math.huge

	-- Snapshot band % at key lucks
	local snaps = {}
	for _, L in { 1, 30, 80, 150 } do
		local b = SoftCapRarity.softCapBandPercents(L)
		snaps[L] = {
			C = b.Common,
			U = b.Uncommon,
			R = b.Rare,
			E = ePlusShare(b),
		}
	end

	return {
		Trial = trialId,
		Policy = policy,
		Minutes = minutes,
		Profile = SoftCapRarity.activeProfile(),
		Rewards = rewards,
		NewBase = avg(agg.newBase),
		NewMut = avg(agg.newMut),
		NewSize = avg(agg.newSize),
		Huge = avg(agg.huge),
		Tit = avg(agg.tit),
		VisualPct = 100 * avg(agg.visual) / rewards,
		CPct = 100 * avg(agg.c) / rewards,
		UPct = 100 * avg(agg.u) / rewards,
		RPct = 100 * avg(agg.r) / rewards,
		EPct = 100 * avg(agg.epicPlus) / rewards,
		EpicPlus = avg(agg.epicPlus),
		UniqueEnd = avg(agg.uniqueEnd),
		MeanGapMin = meanGap / RPM,
		Snaps = snaps,
	}
end

local function printResult(r)
	print(string.format(
		"[%s %s %dm] profile=%s  C/U/R/E+=%.1f/%.1f/%.1f/%.2f%%",
		r.Trial,
		r.Policy,
		r.Minutes,
		r.Profile,
		r.CPct,
		r.UPct,
		r.RPct,
		r.EPct
	))
	print(string.format(
		"  newBase=%.1f  newMut=%.1f  newSize=%.1f  Huge=%.2f  Tit=%.3f  unique=%.1f",
		r.NewBase,
		r.NewMut,
		r.NewSize,
		r.Huge,
		r.Tit,
		r.UniqueEnd
	))
	print(string.format(
		"  visualIdent=%.1f%%  Epic+=%.1f  mean distinctive gap=%.2fm",
		r.VisualPct,
		r.EpicPlus,
		r.MeanGapMin
	))
end

print("=== SoftCap_P4 vs SoftCap_P5_Bands (playtest luck path, SizeConfig unchanged) ===\n")
print("Playtest baseline (22:30 human): unique@20m≈50, Epic IDs=7, auto-sold dupes=780\n")

local configs = {
	{ "SoftCap_P4", "AFK", 22.5, 24 },
	{ "SoftCap_P5_Bands", "AFK", 22.5, 24 },
	{ "SoftCap_P4", "Hunter", 22.5, 24 },
	{ "SoftCap_P5_Bands", "Hunter", 22.5, 24 },
	{ "SoftCap_P4", "AFK", 60, 12 },
	{ "SoftCap_P5_Bands", "AFK", 60, 12 },
	{ "SoftCap_P4", "Hunter", 60, 12 },
	{ "SoftCap_P5_Bands", "Hunter", 60, 12 },
	{ "SoftCap_P4", "Hunter", 180, 6 },
	{ "SoftCap_P5_Bands", "Hunter", 180, 6 },
}

local results = {}
for _, c in configs do
	local r = runTrial(c[1], c[3], c[4], c[2])
	table.insert(results, r)
	printResult(r)
	print("")
end

print("--- Band snapshots (closed-form SoftCap) ---")
for _, trial in { "SoftCap_P4", "SoftCap_P5_Bands" } do
	BalanceTrials.Active = trial
	SoftCapRarity.invalidateSampler()
	SoftCapRarity.syncFromTrials()
	print(trial .. " profile=" .. SoftCapRarity.activeProfile())
	for _, L in { 1, 30, 80, 150 } do
		local b = SoftCapRarity.softCapBandPercents(L)
		print(string.format(
			"  L%-3d  C=%5.1f  U=%5.1f  R=%5.1f  E+=%4.2f",
			L,
			b.Common,
			b.Uncommon,
			b.Rare,
			ePlusShare(b)
		))
	end
end

-- Long-term: expected sized events (closed-form at representative Luck) + short coupon.
print("\n--- Long-term size / base projections (P5 SoftenD) ---")
BalanceTrials.Active = "SoftCap_P5_Bands"
SoftCapRarity.invalidateSampler()
SoftCapRarity.syncFromTrials()
local RelicConfig = require("../src/shared/RelicConfig")
local sizeEligible, titEligible = 0, 0
for _, relic in RelicConfig.Relics do
	if relic.Tier ~= "Common" then
		sizeEligible += 1
	end
	if relic.Tier ~= "Common" and relic.Tier ~= "Uncommon" then
		titEligible += 1
	end
end

local function expectedSized(luck: number, hours: number)
	local b = SoftCapRarity.softCapBandPercents(luck)
	local pH, pT = 0, 0
	for _, tier in TIERS do
		local share = (b[tier] or 0) / 100
		local row = SizeConfig.ChanceByTier[tier]
		pH += share * (row.Huge or 0)
		pT += share * (row.Titanic or 0)
	end
	local n = RPM * 60 * hours
	print(string.format(
		"  @L%-3d %2dh: E[Huge]=%.1f  E[Tit]=%.2f  (events, not unique stamps)",
		luck,
		hours,
		pH * n,
		pT * n
	))
end

for _, h in { 1, 3, 10 } do
	expectedSized(80, h)
end
print(string.format("  Unique stamp album: %d Huge-eligible · %d Titanic-eligible relics", sizeEligible, titEligible))

-- 1h unique-stamp coupon only (cheap)
local maxR = RPM * 60
local sumH, sumT, seeds = 0, 0, 12
for seed = 1, seeds do
	local rngState = seed * 4243 + 11
	local function rng(): number
		rngState = (rngState * 1103515245 + 12345) % 2 ^ 31
		return rngState / 2 ^ 31
	end
	local seenH, seenT = {}, {}
	local nH, nT = 0, 0
	for i = 1, maxR do
		local luck = luckAtMinute(i / RPM)
		local id, tier = SoftCapRarity.roll(luck, rng)
		local size = SizeConfig.roll(tier, rng)
		if size == "Huge" and not seenH[id] then
			seenH[id] = true
			nH += 1
		elseif size == "Titanic" and not seenT[id] then
			seenT[id] = true
			nT += 1
		end
	end
	sumH += nH
	sumT += nT
end
print(string.format(
	"  1h coupon unique stamps: Huge %.1f/%d  Titanic %.2f/%d",
	sumH / seeds,
	sizeEligible,
	sumT / seeds,
	titEligible
))

BalanceTrials.AllowNonStudioActive = false
BalanceTrials.Active = nil
SoftCapRarity.setProfile("Default")
print("\nDone.")
