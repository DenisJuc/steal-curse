-- AFK log, anti-AFK server hops and the Welcome Back screen (GDD 2.2, 9.4).
-- The client reports when its player goes idle (SetAfk true) and comes back (SetAfk false). While
-- the log is active, the discovery pipeline and the economy tick add to it; it is saved, so it
-- survives leaving and anti-AFK hops. Welcome Back is pushed:
--   * on join (unless arriving from an anti-AFK hop): offline CE plus the AFK stretch left running;
--   * when the player comes back after one or more anti-AFK hops: the AFK summary.
-- Coming back in the same server without a hop shows nothing: the game just kept playing.
-- Anti-AFK: Roblox disconnects players idle for 20 minutes, so the client asks for a hop before
-- that and the server teleports the player to a fresh server of this place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local AfkSummary = require(ReplicatedStorage.Shared.AfkSummary)
local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataTemplate = require(script.Parent.Parent.Data.DataTemplate)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetAfk = Remotes:WaitForChild("SetAfk") :: RemoteEvent
local AfkHop = Remotes:WaitForChild("AfkHop") :: RemoteEvent
local WelcomeBack = Remotes:WaitForChild("WelcomeBack") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local AfkService = {}

-- When this server last saw the player go idle (hop requests must come a full idle period later).
local markedAt: { [Player]: number } = {}
local hopping: { [Player]: boolean } = {}

-- Slack for the client's timers and network delay when validating a hop request.
local HOP_SLACK_SECONDS = 30
-- After a failed hop the client may retry this soon.
local HOP_RETRY_SECONDS = 60

local function tierOf(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
end

local function mirror(player: Player)
	local data = DataService.Get(player)
	player:SetAttribute("Afk", data ~= nil and data.AfkLog.Active)
end

local function clearLog(player: Player)
	local data = DataService.Get(player)
	if data then
		data.AfkLog = DataTemplate.deepCopy(DataTemplate.Template.AfkLog)
	end
	markedAt[player] = nil
	mirror(player)
end

-- Starts an AFK stretch (keeps the running one, e.g. after a hop).
function AfkService.Start(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not data.AfkLog.Active then
		local log = DataTemplate.deepCopy(DataTemplate.Template.AfkLog)
		log.Active = true
		log.StartedAt = os.time()
		log.ScansAtStart = data.TotalScans
		data.AfkLog = log
	end
	markedAt[player] = os.clock()
	mirror(player)
end

-- The AFK part of Welcome Back, or nil if there is nothing worth showing.
function AfkService.BuildSummary(player: Player): any?
	local data = DataService.Get(player)
	if not data or not AfkSummary.qualifies(data.AfkLog, Config.Afk.MinReportSeconds) then
		return nil
	end
	local log = data.AfkLog
	local unlocks, more = AfkSummary.unlocks(data, log.StartedAt, tierOf, Config.Afk.MaxUnlocks)
	return {
		Seconds = log.Seconds,
		Scans = math.max(0, data.TotalScans - log.ScansAtStart),
		Discoveries = log.Discoveries,
		CE = log.CE,
		Sold = log.Sold,
		SoldCE = log.SoldCE,
		Hops = log.Hops,
		Unlocks = unlocks,
		MoreUnlocks = more,
	}
end

-- Pushes Welcome Back if there is anything to show. includeAfk also ends the AFK stretch.
function AfkService.Welcome(player: Player, offline: EconomyService.OfflinePayout?, includeAfk: boolean)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local afk = nil
	if includeAfk then
		if data.Settings.Client.AfkReports ~= "Off" then
			afk = AfkService.BuildSummary(player)
		end
		clearLog(player)
	end
	if offline or afk then
		WelcomeBack:FireClient(player, { Offline = offline, Afk = afk })
	end
end

local function onSetAfk(player: Player, away: any)
	if type(away) ~= "boolean" then
		return
	end
	if away then
		AfkService.Start(player)
		return
	end
	local data = DataService.Get(player)
	if not data or not data.AfkLog.Active then
		return
	end
	if data.AfkLog.Hops > 0 then
		AfkService.Welcome(player, nil, true)
	else
		clearLog(player)
	end
end

-- Anti-AFK: moves an idle player to a fresh server of this place. Studio can't teleport, so there
-- it only counts the hop and says what would happen.
function AfkService.Hop(player: Player)
	local data = DataService.Get(player)
	if not data or hopping[player] then
		return
	end
	if not RunService:IsStudio() then
		local since = markedAt[player]
		local needed = Config.Afk.HopAfterSeconds - Config.Afk.MarkAfterSeconds - HOP_SLACK_SECONDS
		if not data.AfkLog.Active or not since or os.clock() - since < needed then
			return
		end
	end
	if not data.AfkLog.Active then
		AfkService.Start(player)
	end
	data.AfkLog.Hops += 1

	if RunService:IsStudio() then
		markedAt[player] = os.clock()
		Notify:FireClient(
			player,
			`[Studio] Anti-AFK would move you to a new server now (hop {data.AfkLog.Hops}). Teleports don't work in Studio.`,
			"Debug"
		)
		return
	end

	hopping[player] = true
	DataService.RequestSave(player)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ AfkHop = true })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		AfkService.HopFailed(player, tostring(err))
	end
end

function AfkService.HopFailed(player: Player, reason: string)
	if not hopping[player] then
		return
	end
	hopping[player] = nil
	local data = DataService.Get(player)
	if data and data.AfkLog.Hops > 0 then
		data.AfkLog.Hops -= 1
	end
	-- Allow a retry soon: the 20-minute idle kick is close.
	markedAt[player] = os.clock()
		- (Config.Afk.HopAfterSeconds - Config.Afk.MarkAfterSeconds - HOP_SLACK_SECONDS)
		+ HOP_RETRY_SECONDS
	warn(`[AfkService] Anti-AFK hop failed for {player.Name}: {reason}`)
	Notify:FireClient(player, "Anti-AFK server hop failed; trying again in a minute.", "Error")
end

local function onLoaded(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local offline = EconomyService.TakeOfflinePayout(player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	local hopArrival = type(teleportData) == "table" and teleportData.AfkHop == true
	if hopArrival and data.AfkLog.Active then
		-- Still AFK: keep the stretch running; the summary shows when the player comes back.
		if offline then
			data.AfkLog.CE += offline.Amount
		end
		mirror(player)
		return
	end
	AfkService.Welcome(player, offline, true)
end

function AfkService.Init()
	RemoteGuard.Event(SetAfk, onSetAfk, "Afk")
	RemoteGuard.Event(AfkHop, AfkService.Hop, "Afk")
	-- Registered after EconomyService, so the offline payout is already paid when this runs.
	DataService.OnPlayerLoaded(onLoaded)
	GameEvents.On("DataReset", function(player: Player)
		markedAt[player] = nil
		mirror(player)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		AfkService.HopFailed(player, message)
	end)
	Players.PlayerRemoving:Connect(function(player)
		markedAt[player] = nil
		hopping[player] = nil
	end)
end

return AfkService
