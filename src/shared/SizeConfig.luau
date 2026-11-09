-- SoftCap Studio collectible sizes: Normal (default) / Huge / Titanic.
-- Production Ladder path never rolls sizes. Nil Size on items = Normal (save-compatible).
-- Visual scale reuses the same RelicModels mesh; no new assets.
--
-- Size probability profiles (Studio trials via BalanceTrials.SizeProfile):
--   Baseline         — original SoftCap_P4/P5 rates (Commons never size; no Unc Tit)
--   Balanced_Studio  — SoftCap_P5_Size experiment (Common Huge + Unc Tit; income unchanged)

local BalanceTrials = if script ~= nil then require(script.Parent.BalanceTrials) else require("./BalanceTrials")

local SizeConfig = {}

export type SizeId = "Huge" | "Titanic"

export type ChanceRow = { Huge: number, Titanic: number }

SizeConfig.Ids = { "Huge", "Titanic" } :: { SizeId }

-- World / viewport scale relative to Normal (1). Raised 2026-11-09 (was 1.4 / 1.9) so a Huge or
-- Titanic relic on a pedestal reads as clearly bigger at a glance.
SizeConfig.Scale = {
	Huge = 1.6,
	Titanic = 2.2,
}

-- Pedestal income multiplier for that instance. Bounded prestige — not a Common→Cosmic ladder.
-- Power is shared across size profiles (availability experiment does not retune income).
SizeConfig.IncomeMult = {
	Huge = 1.5,
	Titanic = 2.5,
}

-- Original SoftCap Studio rates (size control).
local BASELINE_CHANCE: { [string]: ChanceRow } = {
	Common = { Huge = 0, Titanic = 0 },
	Uncommon = { Huge = 1 / 450, Titanic = 0 },
	Rare = { Huge = 1 / 160, Titanic = 1 / 2200 },
	Epic = { Huge = 1 / 90, Titanic = 1 / 700 },
	Legendary = { Huge = 1 / 70, Titanic = 1 / 450 },
	Mythic = { Huge = 1 / 55, Titanic = 1 / 320 },
	Celestial = { Huge = 1 / 45, Titanic = 1 / 220 },
	Cosmic = { Huge = 1 / 40, Titanic = 1 / 180 },
}

-- Balanced_Studio availability (eval recommendation). Mythic+ rates unchanged from Baseline.
-- IncomeMult stays ×1.5 / ×2.5.
local BALANCED_STUDIO_CHANCE: { [string]: ChanceRow } = {
	Common = { Huge = 1 / 1000, Titanic = 0 },
	Uncommon = { Huge = 1 / 420, Titanic = 1 / 4000 },
	Rare = { Huge = 1 / 170, Titanic = 1 / 2400 },
	Epic = { Huge = 1 / 95, Titanic = 1 / 800 },
	Legendary = { Huge = 1 / 75, Titanic = 1 / 520 },
	Mythic = { Huge = 1 / 55, Titanic = 1 / 320 },
	Celestial = { Huge = 1 / 45, Titanic = 1 / 220 },
	Cosmic = { Huge = 1 / 40, Titanic = 1 / 180 },
}

SizeConfig.Profiles = {
	Baseline = BASELINE_CHANCE,
	Balanced_Studio = BALANCED_STUDIO_CHANCE,
}

local activeProfileId = "Baseline"
-- Public table always mirrors the active profile (callers read SizeConfig.ChanceByTier).
SizeConfig.ChanceByTier = BASELINE_CHANCE

SizeConfig.Label = {
	Huge = "Huge",
	Titanic = "Titanic",
}

function SizeConfig.activeProfile(): string
	return activeProfileId
end

function SizeConfig.setProfile(id: string)
	local profile = SizeConfig.Profiles[id]
	if not profile then
		id = "Baseline"
		profile = SizeConfig.Profiles.Baseline
	end
	activeProfileId = id
	SizeConfig.ChanceByTier = profile
end

function SizeConfig.syncFromTrials()
	local id = "Baseline"
	if type(BalanceTrials.sizeProfile) == "function" then
		local ok, resolved = pcall(BalanceTrials.sizeProfile)
		if ok and type(resolved) == "string" and resolved ~= "" then
			id = resolved
		end
	end
	if id ~= activeProfileId or SizeConfig.ChanceByTier ~= SizeConfig.Profiles[id] then
		SizeConfig.setProfile(id)
	end
end

function SizeConfig.enabled(): boolean
	SizeConfig.syncFromTrials()
	return BalanceTrials.raritySampler() == "SoftCap" and BalanceTrials.collectionEnabled()
end

function SizeConfig.normalize(raw: any): SizeId?
	if raw == "Huge" or raw == "Titanic" then
		return raw
	end
	return nil
end

function SizeConfig.scaleOf(size: string?): number
	local id = SizeConfig.normalize(size)
	if not id then
		return 1
	end
	return SizeConfig.Scale[id] or 1
end

function SizeConfig.incomeMult(size: string?): number
	local id = SizeConfig.normalize(size)
	if not id then
		return 1
	end
	return SizeConfig.IncomeMult[id] or 1
end

-- Prefer Titanic > Huge > Normal for "best stamp" comparisons.
function SizeConfig.rank(size: string?): number
	local id = SizeConfig.normalize(size)
	if id == "Titanic" then
		return 2
	elseif id == "Huge" then
		return 1
	end
	return 0
end

-- rng(): number in [0, 1). Returns nil for Normal. hugeMult / titanicMult scale the chances
-- (skill tree Huge / Titanic Attunement); nil = 1.
function SizeConfig.roll(tierId: string, rng: () -> number, hugeMult: number?, titanicMult: number?): SizeId?
	if not SizeConfig.enabled() then
		return nil
	end
	local row = SizeConfig.ChanceByTier[tierId]
	if not row then
		return nil
	end
	local r = rng()
	local pT = (row.Titanic or 0) * (titanicMult or 1)
	if pT > 0 and r < pT then
		return "Titanic"
	end
	r -= pT
	local pH = (row.Huge or 0) * (hugeMult or 1)
	if pH > 0 and r < pH then
		return "Huge"
	end
	return nil
end

return SizeConfig
