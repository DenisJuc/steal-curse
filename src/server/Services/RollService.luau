-- Server-side relic rolls. Owns each player's RNG; clients never roll.
-- Slice 0 luck is always 1x; Slice 2 adds the luck stack, focus, frequency and mutations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)

local RollService = {}

local byTier = RollMath.groupByTier(RelicConfig.Relics)
local rngs: { [Player]: Random } = {}

local function rngFor(player: Player): Random
	local rng = rngs[player]
	if not rng then
		rng = Random.new()
		rngs[player] = rng
	end
	return rng
end

function RollService.Init()
	local problems = RollMath.validate(RarityConfig.Tiers, RelicConfig.Relics)
	if #problems > 0 then
		error("[RollService] Invalid relic config:\n" .. table.concat(problems, "\n"))
	end
	Players.PlayerRemoving:Connect(function(player)
		rngs[player] = nil
	end)
end

function RollService.GetLuck(_player: Player): number
	return 1
end

function RollService.RollRelic(player: Player): string
	local rng = rngFor(player)
	local relic = RollMath.roll(RarityConfig.Tiers, byTier, RollService.GetLuck(player), function()
		return rng:NextNumber()
	end)
	return relic.Id
end

-- Debug only: picks a relic of the given tier directly.
function RollService.RollFromTier(player: Player, tierId: string): string?
	local list = byTier[tierId]
	if not list then
		return nil
	end
	local rng = rngFor(player)
	return RollMath.pickWeighted(list, function()
		return rng:NextNumber()
	end).Id
end

return RollService
