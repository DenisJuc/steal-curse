-- Server-side relic rolls. Owns each player's RNG; clients never roll.
-- Luck = product of the "Luck" multiplier stack, then capped by Rarity Focus. Signal Frequency
-- reweights families inside a tier. Mutations roll after the relic (GDD 5, 8).
-- The context used here is built by RollMath.contextFor, the same function the UI uses for odds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local RollRules = require(ReplicatedStorage.Shared.RollRules)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)

local RollService = {}

export type RollResult = {
	Id: string,
	Mutation: string?,
}

local rngs: { [Player]: Random } = {}
local debugLuck: { [Player]: number } = {}

local function rngFor(player: Player): Random
	local rng = rngs[player]
	if not rng then
		rng = Random.new()
		rngs[player] = rng
	end
	return rng
end

local function numberSource(rng: Random): () -> number
	return function()
		return rng:NextNumber()
	end
end

function RollService.Init()
	local problems = RollMath.validate(RarityConfig.Tiers, RelicConfig.Relics)
	if #problems > 0 then
		error("[RollService] Invalid relic config:\n" .. table.concat(problems, "\n"))
	end

	MultiplierService.Register("Luck", "CoreLuck", function(player)
		local data = DataService.Get(player)
		return Formulas.coreLuck(if data then data.Skills.CoreLuck else 0)
	end)
	MultiplierService.Register("Luck", "Debug", function(player)
		return debugLuck[player] or 1
	end)

	GameEvents.On("MultipliersChanged", function(player: Player)
		RollService.RefreshAttributes(player)
	end)
	DataService.OnPlayerLoaded(function(player)
		MultiplierService.Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		rngs[player] = nil
		debugLuck[player] = nil
	end)
end

function RollService.GetFullLuck(player: Player): number
	return MultiplierService.Get(player, "Luck")
end

function RollService.BuildContext(player: Player): RollMath.Context
	local data = DataService.Get(player)
	return RollMath.contextFor(RollRules, {
		FullLuck = RollService.GetFullLuck(player),
		RarityFocus = if data then data.Settings.RarityFocus else Config.Focus.Default,
		Frequency = if data then data.Settings.Frequency else Config.Frequency.Default,
		FrequencyRank = if data then data.Skills.FrequencyFocus else 0,
		MutationRank = if data then data.Skills.MutationResonance else 0,
	})
end

-- Rolls `count` discoveries with one shared context (a capture batch can't change luck mid-way).
function RollService.RollMany(player: Player, count: number): { RollResult }
	local ctx = RollService.BuildContext(player)
	local nextNumber = numberSource(rngFor(player))
	local results = table.create(count)
	for index = 1, count do
		local relic, mutation = RollMath.roll(ctx, nextNumber)
		results[index] = { Id = relic.Id, Mutation = mutation }
	end
	return results
end

function RollService.Roll(player: Player): RollResult
	return RollService.RollMany(player, 1)[1]
end

-- Debug only: picks a relic of the given tier directly (normal frequency weights, no mutation).
function RollService.RollFromTier(player: Player, tierId: string): string?
	local list = RollRules.ByTier[tierId]
	if not list then
		return nil
	end
	local ctx = RollService.BuildContext(player)
	return RollMath.pickWeighted(list, function(relic)
		return RollMath.relicWeight(ctx, relic)
	end, numberSource(rngFor(player))).Id
end

-- Debug: extra luck multiplier on top of purchased luck (nil clears it).
function RollService.SetDebugLuck(player: Player, multiplier: number?)
	debugLuck[player] = multiplier
	MultiplierService.Refresh(player)
end

-- Mirrors everything the odds UI needs to rebuild the exact same context on the client.
function RollService.RefreshAttributes(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ctx = RollService.BuildContext(player)
	player:SetAttribute("FullLuck", RollService.GetFullLuck(player))
	player:SetAttribute("EffectiveLuck", ctx.Luck)
	player:SetAttribute("RarityFocus", data.Settings.RarityFocus)
	player:SetAttribute("Frequency", data.Settings.Frequency)
	player:SetAttribute("FrequencyRank", data.Skills.FrequencyFocus)
	player:SetAttribute("MutationRank", data.Skills.MutationResonance)
end

return RollService
