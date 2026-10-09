-- Odds shown to the player, computed by RollMath from the same rules the server rolls with.
-- "Base" = 1x luck, no focus, no frequency. "Current" = rebuilt from the attributes the server
-- mirrors (FullLuck, RarityFocus, Frequency, FrequencyRank, MutationRank), so it equals the
-- server's roll context exactly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local RollRules = require(ReplicatedStorage.Shared.RollRules)

local Odds = {}

Odds.Base = RollMath.contextFor(RollRules, { FullLuck = 1 })

local baseItem: { [string]: number } = {}
for _, relic in RelicConfig.Relics do
	baseItem[relic.Id] = RollMath.itemProbability(Odds.Base, relic.Id)
end

function Odds.current(): RollMath.Context
	local player = Players.LocalPlayer
	local function attribute<T>(name: string, fallback: T): T
		local value = player:GetAttribute(name)
		return if value ~= nil then value :: any else fallback
	end
	return RollMath.contextFor(RollRules, {
		FullLuck = attribute("FullLuck", 1),
		RarityFocus = attribute("RarityFocus", "MaxLuck"),
		Frequency = attribute("Frequency", "All"),
		FrequencyRank = attribute("FrequencyRank", 0),
		MutationRank = attribute("MutationRank", 0),
	})
end

function Odds.baseItem(relicId: string): number
	return baseItem[relicId] or 0
end

-- "Legendary  |  1 in 25K" (+ "  |  Abyssal" for mutated finds).
function Odds.describe(relicId: string, mutation: string?): string
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return ""
	end
	local tier = RarityConfig.Get(relic.Tier)
	local text = `{if tier then tier.Name else relic.Tier}  |  {Format.odds(Odds.baseItem(relicId))}`
	if mutation then
		text ..= `  |  {mutation}`
	end
	return text
end

-- Display name including the mutation prefix, e.g. "Abyssal Red Stone of Aia".
function Odds.displayName(relicId: string, mutation: string?): string
	local relic = RelicConfig.ById[relicId]
	local name = if relic then relic.Name else relicId
	return if mutation then `{mutation} {name}` else name
end

return Odds
