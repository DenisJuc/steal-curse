-- Saved player choices that change rolls: Rarity Focus (GDD 5.2) and Signal Frequency (GDD 3.3).
-- The client only sends the chosen id; the server validates it against config.
-- Every frequency is selectable until the Codex unlock rules arrive in Slice 4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetRarityFocus = Remotes:WaitForChild("SetRarityFocus") :: RemoteEvent
local SetFrequency = Remotes:WaitForChild("SetFrequency") :: RemoteEvent

local SettingsService = {}

local VALID_FOCUS: { [string]: boolean } = { MaxLuck = true }
for _, tier in RarityConfig.Tiers do
	VALID_FOCUS[tier.Id] = true
end

local VALID_FREQUENCY: { [string]: boolean } = { All = true }
for _, family in RelicConfig.Families do
	VALID_FREQUENCY[family] = true
end

function SettingsService.SetFocus(player: Player, focus: any): boolean
	local data = DataService.Get(player)
	if not data or type(focus) ~= "string" or not VALID_FOCUS[focus] then
		return false
	end
	data.Settings.RarityFocus = focus
	RollService.RefreshAttributes(player)
	return true
end

function SettingsService.SetFrequency(player: Player, frequency: any): boolean
	local data = DataService.Get(player)
	if not data or type(frequency) ~= "string" or not VALID_FREQUENCY[frequency] then
		return false
	end
	data.Settings.Frequency = frequency
	RollService.RefreshAttributes(player)
	return true
end

function SettingsService.Init()
	RemoteGuard.Event(SetRarityFocus, SettingsService.SetFocus, "Settings")
	RemoteGuard.Event(SetFrequency, SettingsService.SetFrequency, "Settings")
end

return SettingsService
