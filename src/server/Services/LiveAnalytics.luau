-- Live player analytics (Roblox AnalyticsService -> Creator Dashboard). Logging only: it reads
-- saved data and listens to GameEvents, and never changes either.
--   Onboarding funnel  new players only (TotalScans 0 when the profile loads), each step once:
--                      Joined, First Scan, First Rare+, First Display, First Upgrade, Played 5 Min,
--                      First Wild Capture, First Rebirth.
--   Progression        Rebirth completes, with the new rebirth count as the level.
--   Custom             RareFind (Epic+ discoveries) with the tier as a custom field.
--   Economy            CE gained (LifetimeCE delta) and spent, summed every FLUSH_SECONDS and on leave,
--                      so the event budget stays tiny however fast players scan.
-- Nothing is sent from Studio.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)

local LiveAnalytics = {}

local FLUSH_SECONDS = 300
local PLAYED_STEP_SECONDS = 300
local RARE_INDEX = RarityConfig.IndexById.Rare
local EPIC_INDEX = RarityConfig.IndexById.Epic

-- Funnel order as shown on the dashboard.
local STEPS = {
	Joined = { 1, "Joined" },
	FirstScan = { 2, "First Scan" },
	FirstRare = { 3, "First Rare+" },
	FirstDisplay = { 4, "First Display" },
	FirstUpgrade = { 5, "First Upgrade" },
	Played5Min = { 6, "Played 5 Min" },
	FirstCapture = { 7, "First Wild Capture" },
	FirstRebirth = { 8, "First Rebirth" },
}

type Session = {
	New: boolean,
	Logged: { [string]: boolean },
	LastLifetime: number,
	Spent: number,
}

local sessions: { [Player]: Session } = {}
local enabled = not RunService:IsStudio()

local function call(name: string, fn: () -> ())
	if not enabled then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn(`[LiveAnalytics] {name} failed: {err}`)
	end
end

local function step(player: Player, key: string)
	local session = sessions[player]
	if not session or not session.New or session.Logged[key] then
		return
	end
	session.Logged[key] = true
	local info = STEPS[key]
	call("funnel", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, info[1], info[2])
	end)
end

local function flushEconomy(player: Player)
	local session = sessions[player]
	local data = DataService.Get(player)
	if not session or not data then
		return
	end
	local gained = data.LifetimeCE - session.LastLifetime
	session.LastLifetime = data.LifetimeCE
	local spent = session.Spent
	session.Spent = 0
	local balance = data.CE
	if gained > 0 and gained < math.huge then
		call("economy source", function()
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				"CE",
				gained,
				balance,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				"Earned"
			)
		end)
	end
	if spent > 0 and spent < math.huge then
		call("economy sink", function()
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Sink,
				"CE",
				spent,
				balance,
				Enum.AnalyticsEconomyTransactionType.Shop.Name,
				"Upgrades"
			)
		end)
	end
end

local function hasDisplay(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	for _, pedestal in data.Pedestals do
		if pedestal.Uid ~= nil then
			return true
		end
	end
	return false
end

function LiveAnalytics.Init()
	DataService.OnPlayerLoaded(function(player: Player)
		local data = DataService.Get(player)
		if not data or sessions[player] then
			return
		end
		sessions[player] = {
			New = (data.TotalScans or 0) == 0,
			Logged = {},
			LastLifetime = data.LifetimeCE or 0,
			Spent = 0,
		}
		step(player, "Joined")
		task.delay(PLAYED_STEP_SECONDS, function()
			if sessions[player] then
				step(player, "Played5Min")
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		flushEconomy(player)
		sessions[player] = nil
	end)

	GameEvents.On("Discovery", function(player: Player, item: any)
		step(player, "FirstScan")
		local relic = item and RelicConfig.ById[item.Id]
		local index = relic and RarityConfig.IndexById[relic.Tier]
		if not index then
			return
		end
		if index >= RARE_INDEX then
			step(player, "FirstRare")
		end
		if index >= EPIC_INDEX then
			call("rare find", function()
				AnalyticsService:LogCustomEvent(player, "RareFind", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = relic.Tier,
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = item.Size or "Normal",
				})
			end)
		end
	end)

	GameEvents.On("CollectionChanged", function(player: Player)
		local session = sessions[player]
		if session and session.New and not session.Logged.FirstDisplay and hasDisplay(player) then
			step(player, "FirstDisplay")
		end
	end)

	GameEvents.On("Spent", function(player: Player, amount: number)
		local session = sessions[player]
		if session then
			session.Spent += amount
			step(player, "FirstUpgrade")
		end
	end)

	GameEvents.On("Captured", function(player: Player)
		step(player, "FirstCapture")
	end)

	GameEvents.On("Rebirthed", function(player: Player)
		step(player, "FirstRebirth")
		local data = DataService.Get(player)
		local level = if data then data.Rebirths else 0
		call("progression", function()
			AnalyticsService:LogProgressionCompleteEvent(player, "Rebirth", level)
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for player in sessions do
				flushEconomy(player)
			end
		end
	end)
end

return LiveAnalytics
