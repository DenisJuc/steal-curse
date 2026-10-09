-- Studio-only chat commands for fast testing. Nothing here is created outside Studio.
--   /roll [count]      instant extra scans (max Config.Debug.MaxRollsPerCommand)
--   /roll <tier>       instant relic of that tier, e.g. /roll cosmic
--   /scanspeed <sec>   change your scan interval; /scanspeed reset restores it
--   /wipedata          reset your data to a fresh profile
--   /hunt              teleport to the hunting ground entrance
--   /spawnsignal       spawn one of your signals right in front of you (ignores the cap)
--   /regen             refill your signals to the maximum
--   /bindtime <sec>    change your hold-to-bind time; /bindtime reset restores it
--   /huntstats         captures, cancels and average time between captures this session

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local BindService = require(script.Parent.Services.BindService)
local DataService = require(script.Parent.Services.DataService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local SignalService = require(script.Parent.Services.SignalService)
local DiscoveryPipeline = require(script.Parent.DiscoveryPipeline)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local DebugCommands = {}

type Map = { HuntArea: { Entrance: CFrame } }

local function reply(player: Player, text: string)
	Notify:FireClient(player, text, "Debug")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
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

local function buildHandlers(map: Map): { [string]: (Player, { string }) -> () }
	return {
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

		hunt = function(player)
			local character = player.Character
			if character then
				character:PivotTo(map.HuntArea.Entrance)
				reply(player, `Teleported to the {Config.HuntArea.Name}.`)
			end
		end,

		spawnsignal = function(player)
			local root = rootOf(player)
			if not root then
				return
			end
			local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if forward.Magnitude < 0.01 then
				forward = Vector3.zAxis
			end
			local position = root.Position + forward.Unit * 8
			SignalService.SpawnAt(player, position)
			reply(player, "Spawned a signal in front of you.")
		end,

		regen = function(player)
			SignalService.FillToMax(player)
			reply(player, "Signals refilled.")
		end,

		bindtime = function(player, args)
			local argument = args[1]
			if argument == "reset" then
				BindService.SetHoldOverride(player, nil)
			else
				local seconds = tonumber(argument)
				if not seconds then
					reply(player, "Usage: /bindtime <seconds> or /bindtime reset")
					return
				end
				BindService.SetHoldOverride(player, seconds)
			end
			reply(player, `Hold to Bind now takes {Format.seconds(BindService.GetHoldSeconds(player))}.`)
		end,

		huntstats = function(player)
			local stats = BindService.GetStats(player)
			local average = "n/a"
			if stats.Captures >= 2 and stats.FirstCaptureAt and stats.LastCaptureAt then
				average = Format.seconds((stats.LastCaptureAt - stats.FirstCaptureAt) / (stats.Captures - 1))
			end
			local text = `Captures {stats.Captures} | Cancels {stats.Cancels} | Avg between captures {average}`
			reply(player, text)
			print(`[HuntStats] {player.Name}: {text}`)
		end,
	}
end

function DebugCommands.Init(map: Map)
	if not RunService:IsStudio() then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "RelicDebugCommands"
	folder.Parent = TextChatService

	for name, handler in buildHandlers(map) do
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
	print("[DebugCommands] Studio commands ready (type /help in chat for the list)")
end

return DebugCommands
