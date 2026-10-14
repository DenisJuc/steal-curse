-- Hunt Streak per player (HuntStreak module). BindService adds captures; this service counts the
-- idle timer (paused while the player has no signals or is binding), ends the streak in town and
-- mirrors it for the HUD:
--   HuntStreak        current multiplier (nil = no streak)
--   HuntStreakEndsAt  server time the streak ends (nil while paused)
--   HuntStreakIdle    full idle window in seconds (for the HUD timer bar)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HuntStreak = require(ReplicatedStorage.Shared.HuntStreak)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)

local StreakService = {}

local TICK_SECONDS = 0.5

type Entry = { State: HuntStreak.State, Paused: boolean, Idle: number }

local entries: { [Player]: Entry } = {}

local function entryFor(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { State = HuntStreak.new(), Paused = false, Idle = Config.HuntStreak.IdleSeconds }
		entries[player] = entry
	end
	return entry
end

local function mirror(player: Player, entry: Entry)
	local state = entry.State
	if not HuntStreak.active(state) then
		player:SetAttribute("HuntStreak", nil)
		player:SetAttribute("HuntStreakEndsAt", nil)
		player:SetAttribute("HuntStreakIdle", nil)
		return
	end
	player:SetAttribute("HuntStreak", state.Value)
	player:SetAttribute("HuntStreakIdle", entry.Idle)
	player:SetAttribute(
		"HuntStreakEndsAt",
		if entry.Paused then nil else workspace:GetServerTimeNow() + state.IdleLeft
	)
end

local function inWild(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	return WorldLayout.inWild(Config.World, root.Position.X, root.Position.Z)
end

-- Adds a capture in `band` and returns the multiplier for it.
function StreakService.Capture(player: Player, band: HuntStreak.Band, extraIdle: number?): number
	local entry = entryFor(player)
	entry.Idle = Config.HuntStreak.IdleSeconds + (extraIdle or 0)
	entry.Paused = false
	local value = HuntStreak.capture(entry.State, band, Config.HuntStreak, extraIdle)
	mirror(player, entry)
	return value
end

function StreakService.Get(player: Player): number
	local entry = entries[player]
	return if entry then entry.State.Value else 1
end

function StreakService.Reset(player: Player)
	local entry = entries[player]
	if entry then
		HuntStreak.reset(entry.State)
		mirror(player, entry)
	end
end

-- Takes `share` (0..1) of the streak's gain above x1 away. Returns the multiplier lost.
function StreakService.Drain(player: Player, share: number): number
	local entry = entries[player]
	if not entry or entry.State.Value <= 1 then
		return 0
	end
	local before = entry.State.Value
	entry.State.Value = 1 + (before - 1) * (1 - math.clamp(share, 0, 1))
	mirror(player, entry)
	return before - entry.State.Value
end

-- Debug: set the multiplier directly (starts a streak).
function StreakService.Set(player: Player, value: number)
	local entry = entryFor(player)
	local state = entry.State
	state.Value = math.clamp(value, 1, Config.HuntStreak.Max)
	state.Captures = math.max(state.Captures, 1)
	state.IdleLeft = entry.Idle
	mirror(player, entry)
end

function StreakService.Init()
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for player, entry in entries do
				if not HuntStreak.active(entry.State) then
					continue
				end
				if not inWild(player) then
					HuntStreak.reset(entry.State)
					mirror(player, entry)
					continue
				end
				local paused = (player:GetAttribute("SignalCount") or 0) == 0
					or player:GetAttribute("BindSignalId") ~= nil
				local ended = HuntStreak.step(entry.State, TICK_SECONDS, paused)
				if ended or paused ~= entry.Paused then
					entry.Paused = paused
					mirror(player, entry)
				end
			end
		end
	end)
end

return StreakService
