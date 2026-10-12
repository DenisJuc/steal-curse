-- Passive scanner behind the ROLL button (GDD 3.1, Slice 9): one loop for all players, one relic
-- per completed charge. Results are decided here before any client animation.
-- With Auto Roll on (the default, and always while the player is AFK) a full charge fires by
-- itself, exactly like the old automatic scanner. With it off the full charge waits ("RollCharged")
-- until the player presses ROLL; a held charge never stacks.
-- While the inventory is full (Config.Inventory.Capacity) scanning pauses (ScanPaused attribute,
-- red notice) and restarts from a fresh timer once there is room again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local RollNow = Remotes:WaitForChild("RollNow") :: RemoteEvent
local SetAutoRoll = Remotes:WaitForChild("SetAutoRoll") :: RemoteEvent

local ScanService = {}

ScanService.FullMessage = "[INVENTORY FULL] Scanning paused. Sell relics to make room."

type State = {
	NextAt: number,
	IntervalOverride: number?,
	Paused: boolean?,
	Charged: boolean?,
}

local states: { [Player]: State } = {}

-- Extra interval multipliers (e.g. a Haste potion): name -> function(player) -> multiplier.
local intervalHooks: { [string]: (Player) -> number } = {}

-- Free inventory slots (0 when full or not loaded).
function ScanService.Room(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return math.max(0, Config.Inventory.Capacity - #data.Inventory)
end

function ScanService.GetInterval(player: Player): number
	local state = states[player]
	if state and state.IntervalOverride then
		return state.IntervalOverride
	end
	local data = DataService.Get(player)
	local interval = SkillConfig.scanInterval(if data then data.Skills.ScanSpeed or 0 else 0)
	for _, hook in intervalHooks do
		interval *= hook(player)
	end
	return math.max(Config.Luck.FastestScanSeconds, interval)
end

-- Registers an interval multiplier; call ScanService.RefreshInterval when its value changes.
function ScanService.SetIntervalHook(name: string, hook: ((Player) -> number)?)
	intervalHooks[name] = hook
end

-- Auto Roll fires full charges by itself. AFK players always auto-roll so idling stays fair.
function ScanService.IsAutoRoll(player: Player): boolean
	if player:GetAttribute("Afk") == true then
		return true
	end
	local data = DataService.Get(player)
	return data == nil or data.Settings.AutoRoll ~= false
end

local function schedule(player: Player, state: State, from: number)
	local interval = ScanService.GetInterval(player)
	state.NextAt = from + interval
	player:SetAttribute("ScanInterval", interval)
	player:SetAttribute("NextScanAt", state.NextAt)
end

local function setCharged(player: Player, state: State, charged: boolean)
	if (state.Charged == true) == charged then
		return
	end
	state.Charged = charged
	player:SetAttribute("RollCharged", charged)
end

local function performScans(player: Player, count: number, source: string)
	local entries = {}
	for _, rolled in RollService.RollMany(player, count) do
		table.insert(entries, { Id = rolled.Id, Mutation = rolled.Mutation, Source = source })
	end
	DataService.Increment(player, "TotalScans", count)
	DiscoveryPipeline.GrantBatch(player, entries)
end

local function safeScans(player: Player, count: number)
	local ok, err = pcall(performScans, player, count, "Scan")
	if not ok then
		warn(`[ScanService] Scan failed for {player.Name}: {err}`)
	end
end

local function setPaused(player: Player, state: State, paused: boolean, now: number)
	if (state.Paused == true) == paused then
		return
	end
	state.Paused = paused
	player:SetAttribute("ScanPaused", paused)
	setCharged(player, state, false)
	if paused then
		Notify:FireClient(player, ScanService.FullMessage, "Error")
	else
		schedule(player, state, now)
	end
end

-- Fires the one held charge (manual press, or Auto Roll switched on while holding it).
local function fireCharge(player: Player, state: State, now: number)
	setCharged(player, state, false)
	safeScans(player, 1)
	schedule(player, state, now)
end

local function tick(now: number)
	for player, state in states do
		local room = ScanService.Room(player)
		setPaused(player, state, room <= 0, now)
		if state.Paused then
			continue
		end
		local auto = ScanService.IsAutoRoll(player)
		if state.Charged then
			if auto then
				fireCharge(player, state, now)
			end
			continue
		end
		if now < state.NextAt then
			continue
		end
		if not auto then
			setCharged(player, state, true)
			continue
		end
		local interval = ScanService.GetInterval(player)
		local due = 1 + math.floor((now - state.NextAt) / interval)
		local base = state.NextAt + (due - 1) * interval
		if due > Config.Scan.MaxCatchUpScans then
			due = Config.Scan.MaxCatchUpScans
			base = now
		end
		safeScans(player, math.min(due, room))
		schedule(player, state, base)
	end
end

local function mirrorAutoRoll(player: Player)
	local data = DataService.Get(player)
	player:SetAttribute("AutoRoll", data == nil or data.Settings.AutoRoll ~= false)
end

local function onRollNow(player: Player)
	local state = states[player]
	if not state or state.Paused or not state.Charged or ScanService.Room(player) <= 0 then
		return
	end
	fireCharge(player, state, workspace:GetServerTimeNow())
end

local function onSetAutoRoll(player: Player, on: any)
	local data = DataService.Get(player)
	if not data or type(on) ~= "boolean" then
		return
	end
	data.Settings.AutoRoll = on
	mirrorAutoRoll(player)
end

function ScanService.Init()
	DataService.OnPlayerLoaded(function(player)
		if states[player] or not player.Parent then
			return
		end
		local state = { NextAt = 0 }
		states[player] = state
		mirrorAutoRoll(player)
		player:SetAttribute("RollCharged", false)
		schedule(player, state, workspace:GetServerTimeNow())
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	GameEvents.On("DataReset", mirrorAutoRoll)
	RemoteGuard.Event(RollNow, onRollNow)
	RemoteGuard.Event(SetAutoRoll, onSetAutoRoll, "Settings")

	task.spawn(function()
		while true do
			task.wait(Config.Scan.TickSeconds)
			tick(workspace:GetServerTimeNow())
		end
	end)
end

-- Debug: immediately grant extra scans without changing the regular schedule.
-- Stops at the inventory limit like normal scans; returns how many scans ran.
function ScanService.ForceScans(player: Player, count: number, source: string): number
	if not states[player] then
		return 0
	end
	count = math.min(count, ScanService.Room(player))
	if count > 0 then
		performScans(player, count, source)
	end
	return count
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

-- Re-times the current charge after the interval changed (a Haste potion starting or ending),
-- keeping how far it had charged. A held charge stays held.
function ScanService.RefreshInterval(player: Player)
	local state = states[player]
	if not state or state.Charged then
		return
	end
	local now = workspace:GetServerTimeNow()
	local old = player:GetAttribute("ScanInterval")
	local left = if type(old) == "number" and old > 0 then math.clamp((state.NextAt - now) / old, 0, 1) else 1
	local interval = ScanService.GetInterval(player)
	state.NextAt = now + left * interval
	player:SetAttribute("ScanInterval", interval)
	player:SetAttribute("NextScanAt", state.NextAt)
end

-- Restart the timer from now (after wiping data or a Scan Speed rank change).
-- A held charge stays held.
function ScanService.Restart(player: Player)
	local state = states[player]
	if state and not state.Charged then
		schedule(player, state, workspace:GetServerTimeNow())
	end
end

return ScanService
