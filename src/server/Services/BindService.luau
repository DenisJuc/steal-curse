-- Hold to Bind (GDD 4.3), fully server-validated.
-- Begin: signal must be the player's own, within lock range, one bind at a time, off cooldown.
-- Complete: the server-measured hold must have lasted HoldSeconds while staying in range and alive.
-- Only then is the signal consumed and the relic rolled; cancelling grants nothing and keeps the signal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CaptureSummary = require(ReplicatedStorage.Shared.CaptureSummary)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local HuntStreak = require(ReplicatedStorage.Shared.HuntStreak)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local CurseService = require(script.Parent.CurseService)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local LightningService = require(script.Parent.LightningService)
local MasteryService = require(script.Parent.MasteryService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)
local ScanService = require(script.Parent.ScanService)
local SignalService = require(script.Parent.SignalService)
local StreakService = require(script.Parent.StreakService)
local ZoneEventService = require(script.Parent.ZoneEventService)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BeginBind = Remotes:WaitForChild("BeginBind") :: RemoteEvent
local CancelBind = Remotes:WaitForChild("CancelBind") :: RemoteEvent
local CompleteBind = Remotes:WaitForChild("CompleteBind") :: RemoteEvent
local BindResult = Remotes:WaitForChild("BindResult") :: RemoteEvent

local BindService = {}

type Bind = {
	SignalId: number,
	Position: Vector3,
	StartedClock: number,
	Hold: number,
}

-- What GameEvents "Captured" listeners (mastery, bounties, items) get about a capture.
export type CaptureInfo = {
	Area: string,
	Band: HuntStreak.Band,
	Position: Vector3,
	-- Hunt Streak multiplier after this capture, and every bonus factor combined (capped).
	Streak: number,
	Bonus: number,
	-- Short labels for what raised the bonus (shown on the capture card).
	Tags: { string },
	-- Zone event active where the capture happened.
	Event: string?,
	-- The signal was lightning-struck (rolled nothing, charged Lightning Luck instead).
	Struck: boolean,
}

type Stats = {
	Captures: number,
	Cancels: number,
	FirstCaptureAt: number?,
	LastCaptureAt: number?,
}

local binds: { [Player]: Bind } = {}
local cooldownUntil: { [Player]: number } = {}
local holdOverride: { [Player]: number } = {}
local stats: { [Player]: Stats } = {}

local function statsFor(player: Player): Stats
	local entry = stats[player]
	if not entry then
		entry = { Captures = 0, Cancels = 0 }
		stats[player] = entry
	end
	return entry
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function reply(player: Player, payload: { [string]: any })
	BindResult:FireClient(player, payload)
end

-- BindTarget lets other clients draw cosmetic chains to a neutral spirit (the signal itself and
-- any rarity stay private); SealAt/SealPosition/SealRelic replay the capture for onlookers.
local function setBindAttributes(player: Player, bind: Bind?, startedAt: number?)
	player:SetAttribute("BindSignalId", if bind then bind.SignalId else nil)
	player:SetAttribute("BindStartedAt", startedAt)
	player:SetAttribute("BindHoldSeconds", if bind then bind.Hold else nil)
	player:SetAttribute("BindTarget", if bind then bind.Position else nil)
end

local function cancel(player: Player, reason: string)
	if not binds[player] then
		return
	end
	binds[player] = nil
	setBindAttributes(player, nil, nil)
	cooldownUntil[player] = os.clock() + Config.Bind.CancelCooldownSeconds
	statsFor(player).Cancels += 1
	reply(player, { Ok = false, Reason = reason })
end

local function skillRank(player: Player, nodeId: string): number
	local data = DataService.Get(player)
	return if data then data.Skills[nodeId] or 0 else 0
end

-- Hold time for a bind in `area` (zone mastery shortens it there).
function BindService.GetHoldSeconds(player: Player, area: string?): number
	local base = SkillConfig.holdSeconds(skillRank(player, "BindingEfficiency"))
	return holdOverride[player] or base * MasteryService.HoldFactor(player, area)
end

-- Bonus discoveries for one capture (GDD 4.4), raised by Resonant Harvest.
function BindService.BonusCount(player: Player): number
	local base = Formulas.bonusRolls(ScanService.GetInterval(player), Config.Signals.RegenSeconds, Config.Hunt)
	return math.ceil(base * SkillConfig.harvestMultiplier(skillRank(player, "ResonantHarvest")) - 1e-9)
end

local function onBegin(player: Player, signalId: any)
	if type(signalId) ~= "number" then
		return
	end
	if binds[player] then
		reply(player, { Ok = false, Reason = "Busy" })
		return
	end
	if os.clock() < (cooldownUntil[player] or 0) then
		reply(player, { Ok = false, Reason = "Cooldown" })
		return
	end
	if player:GetAttribute("CleanseShrine") ~= nil then
		reply(player, { Ok = false, Reason = "Busy" })
		return
	end
	local signal = SignalService.Get(player, signalId)
	if not signal then
		reply(player, { Ok = false, Reason = "NoSignal" })
		return
	end
	local root = rootOf(player)
	if not root then
		reply(player, { Ok = false, Reason = "NotReady" })
		return
	end
	if (root.Position - signal.Position).Magnitude > Config.Bind.LockRange + Config.Bind.RangeSlack then
		reply(player, { Ok = false, Reason = "TooFar" })
		return
	end

	local area = WorldLayout.areaAt(Config.Areas, Config.World, signal.Position.X, signal.Position.Z)
	local bind = {
		SignalId = signal.Id,
		Position = signal.Position,
		StartedClock = os.clock(),
		Hold = BindService.GetHoldSeconds(player, area),
	}
	binds[player] = bind
	setBindAttributes(player, bind, workspace:GetServerTimeNow())
end

local function onCancel(player: Player, signalId: any)
	local bind = binds[player]
	if bind and bind.SignalId == signalId then
		cancel(player, "Released")
	end
end

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 0 else 0
end

local function bestRelic(relicIds: { string }): string?
	local best, bestIndex = nil, 0
	for _, relicId in relicIds do
		local index = tierIndex(relicId)
		if index > bestIndex then
			best, bestIndex = relicId, index
		end
	end
	return best
end

local function onComplete(player: Player, signalId: any)
	local bind = binds[player]
	if type(signalId) ~= "number" or not bind or bind.SignalId ~= signalId then
		reply(player, { Ok = false, Reason = "NotBinding" })
		return
	end
	if os.clock() - bind.StartedClock < bind.Hold - Config.Bind.CompleteTolerance then
		reply(player, { Ok = false, Reason = "TooEarly" })
		return
	end
	local root = rootOf(player)
	if not root then
		cancel(player, "Interrupted")
		return
	end
	if (root.Position - bind.Position).Magnitude > Config.Bind.BreakRange then
		cancel(player, "TooFar")
		return
	end
	local signal = SignalService.Get(player, signalId)
	local struckUntil = signal and signal.StruckUntil
	if not SignalService.Consume(player, signalId) then
		cancel(player, "NoSignal")
		return
	end

	-- From here everything is synchronous: the signal is gone and the reward is granted exactly once.
	binds[player] = nil
	setBindAttributes(player, nil, nil)

	local position = bind.Position
	local struck = struckUntil ~= nil and workspace:GetServerTimeNow() <= struckUntil
	local info: CaptureInfo = {
		Area = (WorldLayout.areaAt(Config.Areas, Config.World, position.X, position.Z)),
		Band = HuntStreak.band(position.X, position.Z, Config.HuntStreak),
		Position = position,
		Streak = 1,
		Bonus = 1,
		Tags = {},
		Struck = struck,
	}
	info.Streak = StreakService.Capture(player, info.Band, MasteryService.ExtraIdle(player, info.Area))
	local entry = statsFor(player)
	entry.Captures += 1
	local now = os.clock()
	entry.FirstCaptureAt = entry.FirstCaptureAt or now
	entry.LastCaptureAt = now
	DataService.Increment(player, "TotalCaptures", 1)

	if struck then
		-- Lightning rolls nothing: the whole reward is Lightning Luck on every roll for a while.
		local factor, untilTime = LightningService.Charge(player)
		GameEvents.Fire("Captured", player, info)
		reply(player, { Ok = true, Struck = true, LuckFactor = factor, LuckUntil = untilTime })
		return
	end

	local factors = { info.Streak }
	if info.Streak > 1 then
		table.insert(info.Tags, `Streak x{Format.multiplier(info.Streak)}`)
	end
	local event = ZoneEventService.Active()
	local eventFactors = ZoneEventService.Factors(info.Area)
	if event and event.Area == info.Area then
		info.Event = event.Id
		table.insert(info.Tags, event.Name)
	end
	table.insert(factors, eventFactors.Bonus)
	local purified = CurseService.ZoneFactor(player, info.Area)
	if purified > 1 then
		table.insert(factors, purified)
		table.insert(info.Tags, "Purified")
	end
	info.Bonus = HuntStreak.combine(factors, Config.Hunt.MaxBonusMultiplier)
	local bonusCount = math.ceil(BindService.BonusCount(player) * info.Bonus - 1e-9)
	local rolls = RollService.RollMany(player, 1 + bonusCount, {
		LuckFactor = eventFactors.Luck,
		MutationFactor = eventFactors.Mutation,
	})
	local captured = rolls[1]
	local entries = { { Id = captured.Id, Mutation = captured.Mutation, Source = "Capture" } }
	local bonusIds = table.create(bonusCount)
	for index = 2, #rolls do
		table.insert(bonusIds, rolls[index].Id)
		table.insert(entries, { Id = rolls[index].Id, Mutation = rolls[index].Mutation, Source = "Bonus" })
	end
	local results = DiscoveryPipeline.GrantBatch(player, entries)
	GameEvents.Fire("Captured", player, info)

	local summary = CaptureSummary.build(results, tierIndex, Config.Hunt.SummaryNotable)
	if summary then
		summary.BonusMultiplier = info.Bonus
		summary.Tags = info.Tags
	end

	player:SetAttribute("SealPosition", bind.Position)
	player:SetAttribute("SealRelic", `{captured.Id}|{captured.Mutation or ""}`)
	player:SetAttribute("SealAt", workspace:GetServerTimeNow())

	reply(player, {
		Ok = true,
		CapturedId = captured.Id,
		CapturedMutation = captured.Mutation,
		BonusCount = bonusCount,
		BestBonusId = bestRelic(bonusIds),
		Summary = summary,
	})
end

function BindService.Init()
	RemoteGuard.Event(BeginBind, onBegin, "Bind")
	RemoteGuard.Event(CancelBind, onCancel, "Bind")
	RemoteGuard.Event(CompleteBind, onComplete, "Bind")

	Players.PlayerRemoving:Connect(function(player)
		binds[player] = nil
		cooldownUntil[player] = nil
		holdOverride[player] = nil
		stats[player] = nil
	end)

	-- Watchdog: death, leaving range or never completing cancels the bind.
	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, bind in binds do
				local root = rootOf(player)
				if not root then
					cancel(player, "Interrupted")
				elseif (root.Position - bind.Position).Magnitude > Config.Bind.BreakRange then
					cancel(player, "TooFar")
				elseif os.clock() - bind.StartedClock > bind.Hold + Config.Bind.TimeoutGraceSeconds then
					cancel(player, "Timeout")
				end
			end
		end
	end)
end

-- Debug: override this player's hold time (nil restores the config value).
function BindService.SetHoldOverride(player: Player, seconds: number?)
	holdOverride[player] = if seconds then math.max(Config.Bind.DebugMinHoldSeconds, seconds) else nil
end

function BindService.GetStats(player: Player): Stats
	return statsFor(player)
end

return BindService
