-- Automatic passive scanner (GDD 3.1): one loop for all players, one relic per completed scan.
-- Never paused by menus, hunting or reveals. Results are decided here before any client animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local RollService = require(script.Parent.RollService)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local ScanService = {}

type State = {
	NextAt: number,
	IntervalOverride: number?,
}

local states: { [Player]: State } = {}

function ScanService.GetInterval(player: Player): number
	local state = states[player]
	if state and state.IntervalOverride then
		return state.IntervalOverride
	end
	return Config.Scan.BaseIntervalSeconds
end

local function schedule(player: Player, state: State, from: number)
	local interval = ScanService.GetInterval(player)
	state.NextAt = from + interval
	player:SetAttribute("ScanInterval", interval)
	player:SetAttribute("NextScanAt", state.NextAt)
end

local function performScans(player: Player, count: number, source: string)
	local entries = {}
	for _, rolled in RollService.RollMany(player, count) do
		table.insert(entries, { Id = rolled.Id, Mutation = rolled.Mutation, Source = source })
	end
	DataService.Increment(player, "TotalScans", count)
	DiscoveryPipeline.GrantBatch(player, entries)
end

local function tick(now: number)
	for player, state in states do
		if now < state.NextAt then
			continue
		end
		local interval = ScanService.GetInterval(player)
		local due = 1 + math.floor((now - state.NextAt) / interval)
		local base = state.NextAt + (due - 1) * interval
		if due > Config.Scan.MaxCatchUpScans then
			due = Config.Scan.MaxCatchUpScans
			base = now
		end
		local ok, err = pcall(performScans, player, due, "Scan")
		if not ok then
			warn(`[ScanService] Scan failed for {player.Name}: {err}`)
		end
		schedule(player, state, base)
	end
end

function ScanService.Init()
	DataService.OnPlayerLoaded(function(player)
		if states[player] or not player.Parent then
			return
		end
		local state = { NextAt = 0 }
		states[player] = state
		schedule(player, state, workspace:GetServerTimeNow())
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Scan.TickSeconds)
			tick(workspace:GetServerTimeNow())
		end
	end)
end

-- Debug: immediately grant extra scans without changing the regular schedule.
function ScanService.ForceScans(player: Player, count: number, source: string)
	if not states[player] then
		return
	end
	performScans(player, count, source)
end

-- Debug: override this player's interval (nil restores the normal value).
function ScanService.SetIntervalOverride(player: Player, seconds: number?)
	local state = states[player]
	if not state then
		return
	end
	state.IntervalOverride = if seconds then math.max(Config.Scan.DebugMinIntervalSeconds, seconds) else nil
	schedule(player, state, workspace:GetServerTimeNow())
end

-- Restart the timer from now (used after wiping data).
function ScanService.Restart(player: Player)
	local state = states[player]
	if state then
		schedule(player, state, workspace:GetServerTimeNow())
	end
end

return ScanService
