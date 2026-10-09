-- Studio-only chat commands for fast testing. Nothing here is created outside Studio.
--   /roll [count]      instant extra scans (max Config.Debug.MaxRollsPerCommand)
--   /roll <tier>       instant relic of that tier, e.g. /roll cosmic
--   /scanspeed <sec>   change your scan interval; /scanspeed reset restores it
--   /wipedata          reset your data to a fresh profile

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.Services.DataService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local DiscoveryPipeline = require(script.Parent.DiscoveryPipeline)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local DebugCommands = {}

local function reply(player: Player, text: string)
	Notify:FireClient(player, text, "Debug")
end

local function findTier(text: string): string?
	local lowered = string.lower(text)
	for _, tier in RarityConfig.Tiers do
		if string.lower(tier.Id) == lowered then
			return tier.Id
		end
	end
	return nil
end

local handlers: { [string]: (Player, { string }) -> () } = {
	roll = function(player, args)
		local argument = args[1]
		local tierId = argument and findTier(argument)
		if tierId then
			local relicId = RollService.RollFromTier(player, tierId)
			if relicId then
				DataService.Increment(player, "TotalScans", 1)
				DiscoveryPipeline.Grant(player, { relicId }, "Debug")
				reply(player, `Granted a {tierId} relic.`)
			end
			return
		end
		local count = math.clamp(math.floor(tonumber(argument) or 1), 1, Config.Debug.MaxRollsPerCommand)
		ScanService.ForceScans(player, count, "Debug")
		reply(player, `Ran {count} instant scan(s).`)
	end,

	scanspeed = function(player, args)
		local argument = args[1]
		if argument == "reset" then
			ScanService.SetIntervalOverride(player, nil)
			reply(player, "Scan interval restored.")
			return
		end
		local seconds = tonumber(argument)
		if not seconds then
			reply(player, "Usage: /scanspeed <seconds> or /scanspeed reset")
			return
		end
		ScanService.SetIntervalOverride(player, seconds)
		reply(player, `Scan interval set to {Format.seconds(ScanService.GetInterval(player))}.`)
	end,

	wipedata = function(player)
		DataService.Wipe(player)
		ScanService.Restart(player)
		reply(player, "Your data was wiped.")
	end,
}

function DebugCommands.Init()
	if not RunService:IsStudio() then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "RelicDebugCommands"
	folder.Parent = TextChatService

	for name, handler in handlers do
		local command = Instance.new("TextChatCommand")
		command.Name = "Debug_" .. name
		command.PrimaryAlias = "/" .. name
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if not player or not DataService.IsLoaded(player) then
				return
			end
			local args = string.split(text, " ")
			table.remove(args, 1)
			local ok, err = pcall(handler, player, args)
			if not ok then
				warn(`[DebugCommands] /{name} failed: {err}`)
			end
		end)
		command.Parent = folder
	end
	print("[DebugCommands] Studio commands ready: /roll, /scanspeed, /wipedata (type /help for details)")
end

return DebugCommands
