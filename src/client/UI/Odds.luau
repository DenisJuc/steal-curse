-- Odds shown to the player, computed by RollMath from the same rules the server rolls with.
-- "Base" = 1x luck, no focus, no frequency (same Sampler as the active trial).
-- "Current" = rebuilt from mirrored attributes so it equals the server's roll context.
-- SoftCap Index: display 1/p_i (effective), never raw R_i/L.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local RollRules = require(ReplicatedStorage.Shared.RollRules)

local Odds = {}

local function attributeSampler(): RollMath.Sampler
	local player = Players.LocalPlayer
	local value = player:GetAttribute("RaritySampler")
	if value == "SoftCap" then
		return "SoftCap"
	end
	return "Ladder"
end

local function makeContext(fullLuck: number, focus: string?, frequency: string?, frequencyRank: number?, mutationRank: number?): RollMath.Context
	return RollMath.contextFor(RollRules, {
		FullLuck = fullLuck,
		RarityFocus = focus or "MaxLuck",
		Frequency = frequency or "All",
		FrequencyRank = frequencyRank or 0,
		MutationRank = mutationRank or 0,
		Sampler = attributeSampler(),
	})
end

function Odds.baseContext(): RollMath.Context
	return makeContext(1)
end

-- Lazy: SoftCap base odds depend on Sampler attribute (set after server RefreshAttributes).
Odds.Base = makeContext(1)

local function refreshBaseCache()
	Odds.Base = makeContext(1)
end

function Odds.current(): RollMath.Context
	local player = Players.LocalPlayer
	local function attribute<T>(name: string, fallback: T): T
		local value = player:GetAttribute(name)
		return if value ~= nil then value :: any else fallback
	end
	return makeContext(
		attribute("FullLuck", 1),
		attribute("RarityFocus", "MaxLuck"),
		attribute("Frequency", "All"),
		attribute("FrequencyRank", 0),
		attribute("MutationRank", 0)
	)
end

function Odds.baseItem(relicId: string): number
	refreshBaseCache()
	return RollMath.itemProbability(Odds.Base, relicId)
end

-- Effective probability under the player's current luck / focus / frequency / sampler.
function Odds.item(relicId: string): number
	return RollMath.itemProbability(Odds.current(), relicId)
end

function Odds.effectiveOneIn(relicId: string): number
	local p = Odds.item(relicId)
	if p <= 0 then
		return math.huge
	end
	return 1 / p
end

-- Codex / Index line: tier (base rarity) + effective 1-in-N at current luck.
function Odds.indexLine(relicId: string): string
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return ""
	end
	local tier = RarityConfig.Get(relic.Tier)
	local tierName = if tier then tier.Name else relic.Tier
	local yours = Odds.item(relicId)
	local base = Odds.baseItem(relicId)
	return `{tierName}  {Format.odds(yours)}  (base {Format.odds(base)})`
end

-- "Legendary  |  1 in 25K" (+ "  |  Abyssal" for mutated finds).
-- Uses effective (current) odds so SoftCap Index matches the roll the player just got.
function Odds.describe(relicId: string, mutation: string?): string
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return ""
	end
	local tier = RarityConfig.Get(relic.Tier)
	local text = `{if tier then tier.Name else relic.Tier}  |  {Format.odds(Odds.item(relicId))}`
	if mutation then
		text ..= `  |  {mutation}`
	end
	return text
end

-- Display name including mutation / size prefixes, e.g. "Huge Abyssal Red Stone of Aia".
function Odds.displayName(relicId: string, mutation: string?, sizeId: string?): string
	local relic = RelicConfig.ById[relicId]
	local name = if relic then relic.Name else relicId
	if mutation then
		name = `{mutation} {name}`
	end
	if sizeId == "Huge" or sizeId == "Titanic" then
		name = `{sizeId} {name}`
	end
	return name
end

return Odds
