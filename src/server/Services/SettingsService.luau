-- Saved player choices that change rolls: Rarity Focus (GDD 5.2) and Signal Frequency (GDD 3.3).
-- The client only sends the chosen id; the server validates it against config.
-- A family frequency must first be unlocked by its themed Codex milestone (GDD 7.1); "All" never is.
-- Also the presentation settings (ClientSettings, GDD 12.1): validated, saved, and mirrored to
-- "Setting_<Key>" attributes for the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local CodexService = require(script.Parent.CodexService)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetRarityFocus = Remotes:WaitForChild("SetRarityFocus") :: RemoteEvent
local SetFrequency = Remotes:WaitForChild("SetFrequency") :: RemoteEvent
local SetClientSetting = Remotes:WaitForChild("SetClientSetting") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

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
	if not CodexService.IsFrequencyUnlocked(player, frequency) then
		local text = if data.CodexReady[`Frequency_{frequency}`]
			then `{frequency} is ready: claim it in the Codex to unlock it.`
			else `{frequency} is locked. {CodexService.FrequencyGoal(frequency) or ""} to unlock it.`
		Notify:FireClient(player, text, "Error")
		return false
	end
	data.Settings.Frequency = frequency
	RollService.RefreshAttributes(player)
	return true
end

function SettingsService.MirrorClient(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Settings.Client = ClientSettings.sanitizeAll(data.Settings.Client)
	for key, value in data.Settings.Client do
		player:SetAttribute(`Setting_{key}`, value)
	end
end

function SettingsService.SetClient(player: Player, key: any, value: any): boolean
	local data = DataService.Get(player)
	local clean = ClientSettings.sanitize(key, value)
	if not data or clean == nil then
		return false
	end
	data.Settings.Client[key] = clean
	player:SetAttribute(`Setting_{key}`, clean)
	return true
end

function SettingsService.Init()
	RemoteGuard.Event(SetRarityFocus, SettingsService.SetFocus, "Settings")
	RemoteGuard.Event(SetFrequency, SettingsService.SetFrequency, "Settings")
	RemoteGuard.Event(SetClientSetting, SettingsService.SetClient, "Settings")
	DataService.OnPlayerLoaded(SettingsService.MirrorClient)
	GameEvents.On("DataReset", SettingsService.MirrorClient)
end

return SettingsService
