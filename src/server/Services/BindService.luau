-- Hold to Bind (GDD 4.3), fully server-validated.
-- Begin: signal must be the player's own, within lock range, one bind at a time, off cooldown.
-- Complete: the server-measured hold must have lasted HoldSeconds while staying in range and alive.
-- Only then is the signal consumed and the relic rolled; cancelling grants nothing and keeps the signal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local CaptureSummary = require(ReplicatedStorage.Shared.CaptureSummary)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local HuntStreak = require(ReplicatedStorage.Shared.HuntStreak)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local SpiritTypes = require(ReplicatedStorage.Shared.SpiritTypes)
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
	SpiritType: string?,
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
	-- Spirit type of the captured signal (Config.Spirits), nil with spirit types off.
	SpiritType: string?,
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

-- Spirit type settings (Config.Spirits) when spirit types are on, else nil.
local function spiritOf(spiritType: string?): any
	if not Config.Spirits.Enabled or spiritType == nil then
		return nil
	end
	return SpiritTypes.get(spiritType, Config.Spirits :: any)
end

-- Hold time for a bind in `area` (zone mastery shortens it there) on a `spiritType` signal.
function BindService.GetHoldSeconds(player: Player, area: string?, spiritType: string?): number
	local base = SkillConfig.holdSeconds(skillRank(player, "BindingEfficiency"))
	local spirit = spiritOf(spiritType)
	if spirit then
		-- The type sets the hold; Binding Efficiency still shortens it by the same share.
		base *= spirit.Hold / SkillConfig.Effects.HoldBaseSeconds
	end
	local CollectionService = require(script.Parent.CollectionService)
	local resonance = CollectionService.BinderHoldBonus(player)
	local quick = CollectionService.QuickBindHoldFactor(player)
	local hold = (holdOverride[player] or base * MasteryService.HoldFactor(player, area)) + resonance
	hold *= quick
	return math.max(0.5, hold)
end

export type BonusBreakdown = {
	TrialId: string?,
	BonusFloor: number,
	BonusFactor: number,
	ReferenceScanSeconds: number,
	LiveScanSeconds: number,
	RegenSeconds: number,
	FormulaBase: number,
	HarvestRank: number,
	HarvestMult: number,
	AfterHarvest: number,
	StreakZoneMult: number,
	BeforeCap: number,
	MaxBonusRolls: number?,
	FinalBonus: number,
	TotalRolls: number,
	HuntLuck: number,
}

-- Formula base + Resonant Harvest (streak/zone applied in FinalizeBonus).
-- Trial MaxBonusRolls MUST be applied to the FINAL bonus — not here — or streak/zone bypass it.
function BindService.ComputeBonusBase(player: Player, spiritType: string?): BonusBreakdown
	local trial = BalanceTrials.current()
	local liveScan = ScanService.GetInterval(player)
	local hunt = {
		BonusFloor = Config.Hunt.BonusFloor,
		BonusFactor = Config.Hunt.BonusFactor,
	}
	local scanSeconds = liveScan
	local maxBonusRolls: number? = nil
	local huntLuck = 1
	if trial then
		hunt.BonusFloor = trial.Hunt.BonusFloor
		hunt.BonusFactor = trial.Hunt.BonusFactor
		scanSeconds = trial.Hunt.ReferenceScanSeconds or liveScan
		maxBonusRolls = trial.Hunt.MaxBonusRolls
		huntLuck = trial.Hunt.HuntLuckFactor
	end
	local formulaBase = Formulas.bonusRolls(scanSeconds, Config.Signals.RegenSeconds, hunt)
	local spirit = spiritOf(spiritType)
	if spirit then
		formulaBase = spirit.Bonus
		maxBonusRolls = Config.Spirits.MaxBonusRolls
	end
	local harvestRank = skillRank(player, "ResonantHarvest")
	local harvestMult = SkillConfig.harvestMultiplier(harvestRank)
	local afterHarvest = math.ceil(formulaBase * harvestMult - 1e-9)
	return {
		TrialId = if trial then trial.Id else nil,
		BonusFloor = hunt.BonusFloor,
		BonusFactor = hunt.BonusFactor,
		ReferenceScanSeconds = scanSeconds,
		LiveScanSeconds = liveScan,
		RegenSeconds = Config.Signals.RegenSeconds,
		FormulaBase = formulaBase,
		HarvestRank = harvestRank,
		HarvestMult = harvestMult,
		AfterHarvest = afterHarvest,
		StreakZoneMult = 1,
		BeforeCap = afterHarvest,
		MaxBonusRolls = maxBonusRolls,
		FinalBonus = afterHarvest,
		TotalRolls = 1 + afterHarvest,
		HuntLuck = huntLuck,
	}
end

function BindService.BonusCount(player: Player): number
	return BindService.ComputeBonusBase(player).AfterHarvest
end

-- streakZoneMult = HuntStreak.combine(streak, zone, purified) already capped by MaxBonusMultiplier.
function BindService.FinalizeBonus(player: Player, streakZoneMult: number, spiritType: string?): BonusBreakdown
	local b = BindService.ComputeBonusBase(player, spiritType)
	b.StreakZoneMult = streakZoneMult
	b.BeforeCap = math.ceil(b.AfterHarvest * streakZoneMult - 1e-9)
	b.FinalBonus = b.BeforeCap
	if b.MaxBonusRolls then
		b.FinalBonus = math.min(b.BeforeCap, b.MaxBonusRolls)
	end
	b.TotalRolls = 1 + b.FinalBonus
	return b
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
		SpiritType = signal.Type,
		Hold = BindService.GetHoldSeconds(player, area, signal.Type),
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

-- Every bonus factor for a capture in `area` at `streak` (streak, zone event, purified), with the
-- capture card's labels added to `tags`. Also returns the active event's id when it is in `area`.
local function bonusFactors(player: Player, area: string, streak: number, tags: { string }): ({ number }, string?)
	local factors = { streak }
	if streak > 1 then
		table.insert(tags, `Streak x{Format.multiplier(streak)}`)
	end
	local eventId = nil
	local event = ZoneEventService.Active()
	if event and event.Area == area then
		eventId = event.Id
		table.insert(tags, event.Name)
	end
	table.insert(factors, ZoneEventService.Factors(area).Bonus)
	local purified = CurseService.ZoneFactor(player, area)
	if purified > 1 then
		table.insert(factors, purified)
		table.insert(tags, "Purified")
	end
	return factors, eventId
end

local function captureBand(position: Vector3, spiritType: string?): HuntStreak.Band
	local spirit = spiritOf(spiritType)
	return if spirit then spirit.Band else HuntStreak.band(position.X, position.Z, Config.HuntStreak)
end

-- Total rolls (captured relic + bonus) a capture of `signal` would give right now, or nil for a
-- lightning-struck signal (it pays Lightning Luck instead). Mirrors onComplete; changes nothing.
function BindService.PreviewTotalRolls(player: Player, signal: SignalService.Signal): number?
	if signal.StruckUntil and workspace:GetServerTimeNow() <= signal.StruckUntil then
		return nil
	end
	local position = signal.Position
	local area = (WorldLayout.areaAt(Config.Areas, Config.World, position.X, position.Z))
	local streak = StreakService.Preview(player, captureBand(position, signal.Type))
	local factors = bonusFactors(player, area, streak, {})
	local combined = HuntStreak.combine(factors, Config.Hunt.MaxBonusMultiplier)
	return BindService.FinalizeBonus(player, combined, signal.Type).TotalRolls
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
		Band = captureBand(position, bind.SpiritType),
		SpiritType = bind.SpiritType,
		Position = position,
		Streak = 1,
		Bonus = 1,
		Tags = {},
		Struck = struck,
	}
	info.Streak = StreakService.Capture(player, info.Band, MasteryService.ExtraIdle(player, info.Area))
	-- The streak just grew: the remaining spirits' roll tags change.
	SignalService.Refresh(player)
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

	local factors, eventId = bonusFactors(player, info.Area, info.Streak, info.Tags)
	info.Event = eventId
	local eventFactors = ZoneEventService.Factors(info.Area)
	info.Bonus = HuntStreak.combine(factors, Config.Hunt.MaxBonusMultiplier)
	local breakdown = BindService.FinalizeBonus(player, info.Bonus, bind.SpiritType)
	local bonusCount = breakdown.FinalBonus
	local CollectionMath = require(ReplicatedStorage.Shared.CollectionMath)
	local CollectionService = require(script.Parent.CollectionService)
	local huntFamily, huntBonus = CollectionService.HuntFamilyBonus(player)
	local huntQuarryId, huntQuarryMult = CollectionService.HuntQuarry(player)
	print(
		string.format(
			"[BindService] capture %s | trial=%s floor=%.2f factor=%.2f refScan=%.2f (liveScan=%.2f) regen=%d formulaBase=%d harvest=r%d x%.2f → %d | streakZone=x%.2f beforeCap=%d MaxBonusRolls=%s finalBonus=%d totalRolls=%d huntLuck=x%.2f tags=%s",
			player.Name,
			breakdown.TrialId or "LIVE",
			breakdown.BonusFloor,
			breakdown.BonusFactor,
			breakdown.ReferenceScanSeconds,
			breakdown.LiveScanSeconds,
			breakdown.RegenSeconds,
			breakdown.FormulaBase,
			breakdown.HarvestRank,
			breakdown.HarvestMult,
			breakdown.AfterHarvest,
			breakdown.StreakZoneMult,
			breakdown.BeforeCap,
			tostring(breakdown.MaxBonusRolls),
			breakdown.FinalBonus,
			breakdown.TotalRolls,
			breakdown.HuntLuck,
			table.concat(info.Tags, ",")
		)
	)
	if breakdown.MaxBonusRolls and breakdown.BeforeCap > breakdown.MaxBonusRolls then
		print(
			string.format(
				"[BindService] capped bonus %d → %d (streak/zone/harvest would have exceeded MaxBonusRolls)",
				breakdown.BeforeCap,
				breakdown.FinalBonus
			)
		)
	end
	local rolls = RollService.RollMany(player, breakdown.TotalRolls, {
		LuckFactor = eventFactors.Luck * breakdown.HuntLuck,
		MutationFactor = eventFactors.Mutation,
		HuntFamily = huntFamily,
		HuntFamilyBonus = huntBonus,
		HuntQuarryId = huntQuarryId,
		HuntQuarryMult = huntQuarryMult,
	})
	if #rolls ~= breakdown.TotalRolls then
		warn(`[BindService] RollMany returned {#rolls} rolls, expected {breakdown.TotalRolls}`)
	end
	local captured = rolls[1]
	local entries = {
		{ Id = captured.Id, Mutation = captured.Mutation, Size = captured.Size, Source = "Capture" },
	}
	local bonusIds = table.create(bonusCount)
	for index = 2, #rolls do
		table.insert(bonusIds, rolls[index].Id)
		table.insert(
			entries,
			{ Id = rolls[index].Id, Mutation = rolls[index].Mutation, Size = rolls[index].Size, Source = "Bonus" }
		)
	end
	-- Pre-grant: whether a Quarry hit advances Board/catalyst/Ascend (not mere Essence dupes).
	local quarryNeed = if huntQuarryId then CollectionService.QuarryNeedFor(player, huntQuarryId) else nil
	local quarryHits = 0
	local quarryMutHits = 0
	if huntQuarryId then
		for _, entry in entries do
			if entry.Id == huntQuarryId then
				quarryHits += 1
				if entry.Mutation then
					quarryMutHits += 1
				end
			end
		end
	end
	local quarryUseful = false
	if quarryNeed and quarryHits > 0 then
		quarryUseful = CollectionMath.quarryCaptureAdvances(quarryNeed, quarryMutHits > 0)
	end
	local results = DiscoveryPipeline.GrantBatch(player, entries)
	local essenceBefore = player:GetAttribute("Essence")
	local familyMatches = 0
	if huntFamily then
		for _, entry in entries do
			local relic = RelicConfig.ById[entry.Id]
			if relic and relic.Family == huntFamily then
				familyMatches += 1
			end
		end
	end
	CollectionService.GrantHuntEssence(player, familyMatches)
	GameEvents.Fire("Captured", player, info)

	local summary = CaptureSummary.build(results, tierIndex, Config.Hunt.SummaryNotable)
	if summary then
		summary.BonusMultiplier = info.Bonus
		summary.Tags = info.Tags
		if huntQuarryId then
			if quarryHits > 0 then
				summary.Tags = summary.Tags or {}
				local qRelic = RelicConfig.ById[huntQuarryId]
				local qName = if qRelic then qRelic.Name else huntQuarryId
				local tag = if quarryUseful
					then (if quarryHits == 1 then `Quarry ✓ {qName}` else `Quarry ✓ {qName} ×{quarryHits}`)
					else (if quarryHits == 1 then `Quarry dupe {qName}` else `Quarry dupe {qName} ×{quarryHits}`)
				table.insert(summary.Tags, tag)
			end
			summary.HuntQuarryId = huntQuarryId
			summary.HuntQuarryHits = quarryHits
			summary.HuntQuarryUseful = quarryUseful
			summary.HuntQuarryNeed = if quarryNeed then quarryNeed.Detail else nil
		end
		local essenceAfter = player:GetAttribute("Essence")
		if type(essenceBefore) == "number" and type(essenceAfter) == "number" and essenceAfter > essenceBefore then
			summary.CollectionEssence = essenceAfter - essenceBefore
		elseif type(essenceAfter) == "number" and type(essenceBefore) ~= "number" then
			-- First Collection mirror this session.
			summary.CollectionEssence = essenceAfter
		end
	end

	player:SetAttribute("SealPosition", bind.Position)
	player:SetAttribute("SealRelic", `{captured.Id}|{captured.Mutation or ""}`)
	player:SetAttribute("SealAt", workspace:GetServerTimeNow())
	player:SetAttribute("LastHuntTotalRolls", breakdown.TotalRolls)
	player:SetAttribute("LastHuntTrial", breakdown.TrialId or "LIVE")

	local Analytics = require(script.Parent.PlaytestAnalyticsService)
	Analytics.RecordCapture(player, bonusCount, breakdown.TotalRolls)

	reply(player, {
		Ok = true,
		CapturedId = captured.Id,
		CapturedMutation = captured.Mutation,
		BonusCount = bonusCount,
		SpiritType = bind.SpiritType,
		BestBonusId = bestRelic(bonusIds),
		Summary = summary,
	})
end

function BindService.Init()
	RemoteGuard.Event(BeginBind, onBegin, "Bind")
	RemoteGuard.Event(CancelBind, onCancel, "Bind")
	RemoteGuard.Event(CompleteBind, onComplete, "Bind")
	SignalService.SetRollPreview(BindService.PreviewTotalRolls)

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
