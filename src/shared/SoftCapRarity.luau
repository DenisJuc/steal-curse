-- SoftCap rarity (Rev 4 candidate). Studio trials only — live RollService stays on the tier ladder
-- unless BalanceTrials.raritySampler() == "SoftCap".
-- w_i = L / (R_i + L/M_i); p_i = w_i / Σw; Index N_eff = 1/p_i (never raw R/L).

local function shared(name: string)
	if script ~= nil then
		return require(script.Parent[name])
	end
	return require(`./{name}`)
end

local RelicConfig = shared("RelicConfig")

local SoftCapRarity = {}

export type RelicRow = {
	Id: string,
	Tier: string,
	Weight: number,
	Family: string,
	R: number,
	M: number,
}

local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }

-- Authored R bands (log-spaced by descending Weight within tier). Rev 4 / SoftCap_P4 baseline.
local BAND_R_DEFAULT = {
	Common = { 2.0, 18.0 },
	Uncommon = { 22.0, 90.0 },
	Rare = { 120.0, 900.0 },
	Epic = { 2500.0, 22000.0 },
	Legendary = { 8e4, 5e5 },
	Mythic = { 2e6, 1.2e7 },
	Celestial = { 5e9, 8e10 },
	Cosmic = { 2e13, 1.2e14 },
}

local BAND_M_DEFAULT = {
	Common = 1.0,
	Uncommon = 1.0,
	Rare = 0.85,
	Epic = 0.35,
	Legendary = 0.1,
	Mythic = 0.035,
	Celestial = 0.012,
	Cosmic = 0.005,
}

export type BandProfile = {
	M: { [string]: number },
	R: { [string]: { number } },
}

-- SoftCap_P5_Bands (SoftenD): Luck-forward Common cut, Rare mid-tier chase, Epic+ ~1% @ L80.
-- Chosen after candidate eval vs SoftenA–E (see tests/softCapBandCandidates.luau).
local BAND_M_SOFTEN_D = {
	Common = 0.85,
	Uncommon = 1.05,
	Rare = 1.35,
	Epic = 0.58,
	Legendary = 0.18,
	Mythic = 0.035,
	Celestial = 0.012,
	Cosmic = 0.005,
}

local BAND_R_SOFTEN_D = {
	Common = { 2.2, 20.0 },
	Uncommon = { 22.0, 90.0 },
	Rare = { 80.0, 650.0 },
	Epic = { 1600.0, 16000.0 },
	Legendary = { 8e4, 5e5 },
	Mythic = { 2e6, 1.2e7 },
	Celestial = { 5e9, 8e10 },
	Cosmic = { 2e13, 1.2e14 },
}

-- Named SoftCap band profiles. "Default" = SoftCap_P4 control. SoftenD = SoftCap_P5 experiment.
local PROFILES: { [string]: BandProfile } = {
	Default = { M = BAND_M_DEFAULT, R = BAND_R_DEFAULT },
	SoftenD = { M = BAND_M_SOFTEN_D, R = BAND_R_SOFTEN_D },
}

local activeProfileId = "Default"
local cachedRows: { RelicRow }? = nil
local cachedProfileId: string? = nil

-- Cached weight table for the current (Luck, family, familyMult). Rebuild only when inputs change.
export type WeightSampler = {
	Key: string,
	Weights: { number },
	Ids: { string },
	Tiers: { string },
	Total: number,
	P: { [string]: number },
	ByTier: { [string]: number },
}

local activeSampler: WeightSampler? = nil

function SoftCapRarity.invalidateSampler()
	activeSampler = nil
end

function SoftCapRarity.registerProfile(id: string, profile: BandProfile)
	PROFILES[id] = profile
end

function SoftCapRarity.setProfile(id: string)
	if not PROFILES[id] then
		id = "Default"
	end
	if activeProfileId ~= id then
		activeProfileId = id
		cachedRows = nil
		cachedProfileId = nil
		activeSampler = nil
	end
end

function SoftCapRarity.activeProfile(): string
	return activeProfileId
end

local trialsModule: any = nil
local lastTrialSyncKey = ""

-- Sync profile from BalanceTrials when available (SoftCap_P5_Bands → SoftenD, else Default).
function SoftCapRarity.syncFromTrials()
	if trialsModule == nil then
		local ok, mod = pcall(function()
			return shared("BalanceTrials")
		end)
		if ok then
			trialsModule = mod
		else
			trialsModule = false
		end
	end
	if trialsModule == false or type(trialsModule.softCapProfile) ~= "function" then
		return
	end
	local syncKey = `{tostring(trialsModule.Active)}|{tostring(trialsModule.AllowNonStudioActive)}|{tostring(trialsModule.StudioTrialId)}|{tostring(trialsModule.StudioAutoDisabled)}|{tostring(trialsModule.CollectionPrototype)}`
	if syncKey == lastTrialSyncKey then
		return
	end
	lastTrialSyncKey = syncKey
	local id = trialsModule.softCapProfile()
	if type(id) ~= "string" or id == "" then
		id = "Default"
	end
	SoftCapRarity.setProfile(id)
end

function SoftCapRarity.samplerFor(
	luck: number,
	family: string?,
	familyMult: number?,
	quarryId: string?,
	quarryMult: number?
): WeightSampler
	-- Refresh profile when trial changes; setProfile is a no-op if unchanged.
	SoftCapRarity.syncFromTrials()
	local fam = family or ""
	local mult = familyMult or 1
	local qId = quarryId or ""
	local qMult = quarryMult or 1
	local key = string.format("%s|%.12g|%s|%.12g|%s|%.12g", activeProfileId, luck, fam, mult, qId, qMult)
	if activeSampler and activeSampler.Key == key then
		return activeSampler
	end
	local rows = SoftCapRarity.rows()
	local n = #rows
	local weights = table.create(n)
	local ids = table.create(n)
	local tiers = table.create(n)
	local total = 0
	for i, row in rows do
		local w = SoftCapRarity.weight(row, luck, family, familyMult, quarryId, quarryMult)
		weights[i] = w
		ids[i] = row.Id
		tiers[i] = row.Tier
		total += w
	end
	local p: { [string]: number } = {}
	local byTier: { [string]: number } = {}
	for _, t in TIER_ORDER do
		byTier[t] = 0
	end
	if total > 0 then
		for i = 1, n do
			local pi = weights[i] / total
			p[ids[i]] = pi
			byTier[tiers[i]] += pi
		end
	end
	activeSampler = {
		Key = key,
		Weights = weights,
		Ids = ids,
		Tiers = tiers,
		Total = total,
		P = p,
		ByTier = byTier,
	}
	return activeSampler
end

function SoftCapRarity.bandM(): { [string]: number }
	local p = PROFILES[activeProfileId] or PROFILES.Default
	return p.M
end

function SoftCapRarity.bandR(): { [string]: { number } }
	local p = PROFILES[activeProfileId] or PROFILES.Default
	return p.R
end

function SoftCapRarity.rows(): { RelicRow }
	if cachedRows and cachedProfileId == activeProfileId then
		return cachedRows
	end
	local profile = PROFILES[activeProfileId] or PROFILES.Default
	local BAND_R = profile.R
	local BAND_M = profile.M
	local byTier: { [string]: { any } } = {}
	for _, relic in RelicConfig.Relics do
		local list = byTier[relic.Tier]
		if not list then
			list = {}
			byTier[relic.Tier] = list
		end
		table.insert(list, relic)
	end
	local rows = {}
	for _, tierId in TIER_ORDER do
		local list = byTier[tierId] or {}
		table.sort(list, function(a, b)
			return a.Weight > b.Weight
		end)
		local band = BAND_R[tierId]
		local lo, hi = band[1], band[2]
		local m = BAND_M[tierId]
		for i, relic in list do
			local u = if #list <= 1 then 0 else (i - 1) / (#list - 1)
			local r = lo * ((hi / lo) ^ u)
			table.insert(rows, {
				Id = relic.Id,
				Tier = relic.Tier,
				Weight = relic.Weight,
				Family = relic.Family,
				R = r,
				M = m,
			})
		end
	end
	cachedRows = rows
	cachedProfileId = activeProfileId
	return rows
end

function SoftCapRarity.rowById(relicId: string): RelicRow?
	for _, row in SoftCapRarity.rows() do
		if row.Id == relicId then
			return row
		end
	end
	return nil
end

function SoftCapRarity.weight(
	row: RelicRow,
	luck: number,
	family: string?,
	familyMult: number?,
	quarryId: string?,
	quarryMult: number?
): number
	local L = math.max(1e-12, luck)
	local r = row.R
	-- Frequency Focus / Hunt Charm: boost matching family by lowering effective R.
	if family and row.Family == family and (familyMult or 1) > 1 then
		r = r / (familyMult :: number)
	end
	local w = L / (r + L / row.M)
	-- Hunt Quarry (binds only): multiply weight so ×mult is a real share lift.
	-- (R-divisor barely moved Common SoftCap weights; weight×mult does.)
	if quarryId and row.Id == quarryId and (quarryMult or 1) > 1 then
		w = w * (quarryMult :: number)
	end
	return w
end

function SoftCapRarity.probabilities(
	luck: number,
	family: string?,
	familyMult: number?,
	quarryId: string?,
	quarryMult: number?
): ({ [string]: number }, { [string]: number }, number)
	local s = SoftCapRarity.samplerFor(luck, family, familyMult, quarryId, quarryMult)
	return s.P, s.ByTier, s.Total
end

function SoftCapRarity.effectiveOneIn(
	luck: number,
	relicId: string,
	family: string?,
	familyMult: number?,
	quarryId: string?,
	quarryMult: number?
): number
	local p = SoftCapRarity.probabilities(luck, family, familyMult, quarryId, quarryMult)
	local pi = p[relicId]
	if not pi or pi <= 0 then
		return math.huge
	end
	return 1 / pi
end

function SoftCapRarity.l1Distance(luckA: number, luckB: number): number
	local pa = SoftCapRarity.probabilities(luckA)
	local pb = SoftCapRarity.probabilities(luckB)
	local d = 0
	for id, a in pa do
		d += math.abs(a - (pb[id] or 0))
	end
	return d
end

function SoftCapRarity.roll(
	luck: number,
	nextNumber: () -> number,
	family: string?,
	familyMult: number?,
	quarryId: string?,
	quarryMult: number?
): (string, string)
	local s = SoftCapRarity.samplerFor(luck, family, familyMult, quarryId, quarryMult)
	local total = s.Total
	if total <= 0 then
		return s.Ids[1], s.Tiers[1]
	end
	local target = nextNumber() * total
	local weights = s.Weights
	for i = 1, #weights do
		target -= weights[i]
		if target < 0 then
			return s.Ids[i], s.Tiers[i]
		end
	end
	local last = #s.Ids
	return s.Ids[last], s.Tiers[last]
end

function SoftCapRarity.softCapBandPercents(luck: number): { [string]: number }
	local s = SoftCapRarity.samplerFor(luck)
	local out = {}
	for t, p in s.ByTier do
		out[t] = p * 100
	end
	return out
end

-- Soft A+C ladder band % for comparison (lazy require — avoids cycles with RollMath).
function SoftCapRarity.ladderBandPercents(luck: number, epicDenom: number, legendaryDenom: number): { [string]: number }
	local RollMath = shared("RollMath")
	local RarityConfig = shared("RarityConfig")
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = epicDenom
		elseif tier.Id == "Legendary" then
			denom = legendaryDenom
		end
		table.insert(tiers, { Id = tier.Id, Denominator = denom })
	end
	local masses = RollMath.tierMasses(tiers, luck)
	local out = {}
	for i, tier in tiers do
		out[tier.Id] = masses[i] * 100
	end
	return out
end

-- Lazy module handles (avoid require-per-roll in hot sim loops).
local MutationConfigRef: any = nil
local RollMathRef: any = nil
local unlockedByRank: { [number]: { any } } = {}

local function mutationModules()
	if not MutationConfigRef then
		MutationConfigRef = shared("MutationConfig")
		RollMathRef = shared("RollMath")
	end
	return MutationConfigRef, RollMathRef
end

local function unlockedMutations(rank: number): { any }
	local cached = unlockedByRank[rank]
	if cached then
		return cached
	end
	local MutationConfig = mutationModules()
	local unlocked = {}
	for _, mutation in MutationConfig.Mutations do
		if mutation.UnlockRank <= rank then
			table.insert(unlocked, mutation)
		end
	end
	unlockedByRank[rank] = unlocked
	return unlocked
end

-- Standalone mutation draw for sims (same ChanceByRank / unlocked weights as RollMath).
function SoftCapRarity.rollMutation(rank: number, nextNumber: () -> number): string?
	local MutationConfig = mutationModules()
	local chance = MutationConfig.ChanceByRank[rank] or 0
	if chance <= 0 or nextNumber() >= chance then
		return nil
	end
	local unlocked = unlockedMutations(rank)
	if #unlocked == 0 then
		return nil
	end
	-- Inline weighted pick (avoid closure alloc per roll).
	local total = 0
	for _, m in unlocked do
		total += m.Weight
	end
	local target = nextNumber() * total
	for _, m in unlocked do
		target -= m.Weight
		if target < 0 then
			return m.Id
		end
	end
	return unlocked[#unlocked].Id
end

return SoftCapRarity
