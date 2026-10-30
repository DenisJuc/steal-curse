-- Studio-only playtest session analytics. Never runs in production.
-- Auto-starts when RunService:IsStudio() and BalanceTrials.collectionEnabled().
-- Export: HttpService → localhost receiver + ServerStorage StringValues + client panel.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local CollectionMath = require(ReplicatedStorage.Shared.CollectionMath)
local Config = require(ReplicatedStorage.Shared.Config)
local PlaytestAnalyticsExport = require(ReplicatedStorage.Shared.PlaytestAnalyticsExport)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)
local ScanService = require(script.Parent.ScanService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AnalyticsAction = Remotes:FindFirstChild("AnalyticsAction") :: RemoteFunction?
if not AnalyticsAction then
	AnalyticsAction = Instance.new("RemoteFunction")
	AnalyticsAction.Name = "AnalyticsAction"
	AnalyticsAction.Parent = Remotes
end
local AnalyticsStatus = Remotes:FindFirstChild("AnalyticsStatus") :: RemoteEvent?
if not AnalyticsStatus then
	AnalyticsStatus = Instance.new("RemoteEvent")
	AnalyticsStatus.Name = "AnalyticsStatus"
	AnalyticsStatus.Parent = Remotes
end

local EXPORT_URL = "http://127.0.0.1:19283/export"
local SNAPSHOT_EVERY = 60
local SCAN_FLUSH_EVERY = 10
local RARITY_WINDOW_SEC = 300 -- 5-minute rarity / unique vs dupe windows
local MINUTE_MARKS = { 5, 10, 15, 20, 25, 30 }
local MAX_EVENTS = 40000

local PlaytestAnalyticsService = {}

type SessionState = {
	SessionId: string,
	PlayerUserId: number,
	StartedClock: number,
	Recording: boolean,
	Events: { any },
	Purchases: { any },
	Milestones: { any },
	Snapshots: { any },
	MinuteMarks: { any },
	MinuteMarkSet: { [number]: boolean },
	Activity: { [string]: number },
	LastActivity: string,
	LastActivityAt: number,
	LastPurchaseAt: number?,
	LastMeaningfulAt: number?,
	LastEssenceEarnAt: number?,
	MaxEssenceIdle: number,
	ScanBucket: { [string]: number },
	ScanBuckets: { any },
	-- Rolling 5-min window: ByTier, UniqueNew, Dupes, BySource, Mutations, EpicPlus
	WindowBucket: {
		ByTier: { [string]: number },
		BySource: { [string]: number },
		UniqueNew: number,
		Dupes: number,
		Mutations: number,
		EpicPlus: number,
		Total: number,
	},
	RarityWindows: { any },
	LastWindowFlushAt: number,
	SeenRelics: { [string]: boolean },
	FirstTier: { [string]: boolean },
	EpicExact: number,
	UniqueEpic: { [string]: boolean },
	EpicPlus: number,
	UniqueEpicPlus: { [string]: boolean },
	UniqueCount: number,
	HuntCaptures: number,
	ScanBatches: number,
	DuplicateSells: number,
	MutationsFound: number,
	UnlocksSeen: { [string]: boolean },
	UnlocksUsed: { [string]: boolean },
	RoutinePurchases: number,
	FailedPurchases: number,
	MeaningfulCount: number,
	LongestGap: number,
	EventIds: { [string]: boolean },
	CollectionPanelOpenedAt: number?,
	CollectionPanelVisits: number,
	CollectionFailedAttempts: number,
}

local sessions: { [Player]: SessionState } = {}
local autoStarted: { [Player]: boolean } = {}

local function studioOk(): boolean
	return RunService:IsStudio() == true
end

local function enabled(): boolean
	return studioOk() and BalanceTrials.collectionEnabled()
end

local function nowClock(): number
	return os.clock()
end

local function elapsed(session: SessionState): number
	return nowClock() - session.StartedClock
end

local function economySnapshot(player: Player): any
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = CollectionMath.sanitize(data.Collection)
	local luck = RollService.GetFullLuck(player)
	local effLuck = player:GetAttribute("EffectiveLuck")
	if type(effLuck) ~= "number" then
		effLuck = luck
	end
	local income = EconomyService.GetIncomePerSec(player)
	local inv = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0, Celestial = 0, Cosmic = 0, Other = 0 }
	for _, item in data.Inventory do
		local relic = RelicConfig.ById[item.Id]
		local tier = if relic then relic.Tier else "Other"
		inv[tier] = (inv[tier] or 0) + 1
	end
	local pedestals = {}
	for i, ped in data.Pedestals do
		local relicId = nil
		if ped.Uid then
			for _, item in data.Inventory do
				if item.Uid == ped.Uid then
					relicId = item.Id
					break
				end
			end
		end
		table.insert(pedestals, { Slot = i, Level = ped.Level, RelicId = relicId })
	end
	local fuseRanks, fuseCount = 0, 0
	for _, entry in state.Fusion do
		fuseCount += 1
		fuseRanks += entry.Rank or 0
	end
	local goals = 0
	for _ in state.MutationGoalsClaimed do
		goals += 1
	end
	local affordable = {}
	local coreRank = data.Skills.CoreLuck or 0
	local coreCost = BalanceTrials.coreLuckCost(coreRank)
	if type(coreCost) == "number" then
		table.insert(affordable, {
			Id = "CoreLuck",
			Cost = coreCost,
			Affordable = data.CE >= coreCost,
		})
	end
	local nextSlot = #data.Pedestals + 1
	local slotPrice = Config.Economy.SlotPrices[nextSlot]
	if slotPrice then
		table.insert(affordable, { Id = "PedestalSlot", Cost = slotPrice, Affordable = data.CE >= slotPrice })
	end
	return {
		CE = data.CE,
		Essence = state.Essence,
		Luck = luck,
		EffectiveLuck = effLuck,
		RaritySampler = BalanceTrials.raritySampler(),
		IncomePerSec = income,
		CoreLuck = coreRank,
		ScanInterval = ScanService.GetInterval(player),
		Rebirths = data.Rebirths or 0,
		Pedestals = pedestals,
		InventoryByTier = inv,
		FusionCount = fuseCount,
		FusionRanks = fuseRanks,
		FusionSlots = CollectionMath.fusionSlots(state, data.Rebirths or 0),
		MutationGoals = goals,
		AttuneCharges = state.AttuneCharges,
		ResonanceStacks = table.clone(state.ResonanceStacks),
		Available = affordable,
	}
end

local function pushEvent(session: SessionState, kind: string, payload: any)
	if #session.Events >= MAX_EVENTS then
		return
	end
	local id = payload.Id or HttpService:GenerateGUID(false)
	if session.EventIds[id] then
		return
	end
	session.EventIds[id] = true
	local e = elapsed(session)
	payload.Id = id
	payload.Kind = kind
	payload.ElapsedSec = e
	payload.Elapsed = PlaytestAnalyticsExport.formatElapsed(e)
	table.insert(session.Events, payload)
end

local function noteMeaningful(session: SessionState, label: string, detail: string?)
	local e = elapsed(session)
	if session.LastMeaningfulAt then
		local gap = (e - session.LastMeaningfulAt) / 60
		if gap > session.LongestGap then
			session.LongestGap = gap
		end
	end
	session.LastMeaningfulAt = e
	session.MeaningfulCount += 1
	table.insert(session.Milestones, {
		Elapsed = PlaytestAnalyticsExport.formatElapsed(e),
		ElapsedSec = e,
		Label = label,
		Detail = detail,
	})
	pushEvent(session, "Milestone", { Label = label, Detail = detail })
end

local function setActivity(session: SessionState, category: string)
	local t = nowClock()
	local dt = t - session.LastActivityAt
	if dt > 0 and dt < 120 then
		session.Activity[session.LastActivity] = (session.Activity[session.LastActivity] or 0) + dt
	end
	session.LastActivity = category
	session.LastActivityAt = t
end

local function takeSnapshot(player: Player, session: SessionState, reason: string): any?
	local eco = economySnapshot(player)
	if not eco then
		return nil
	end
	local e = elapsed(session)
	local snap = {
		Reason = reason,
		ElapsedSec = e,
		Elapsed = PlaytestAnalyticsExport.formatElapsed(e),
		UniqueDiscoveries = session.UniqueCount,
		EpicExact = session.EpicExact,
		UniqueEpicExact = 0,
		EpicPlus = session.EpicPlus,
		UniqueEpicPlus = 0,
		SecSinceMeaningful = if session.LastMeaningfulAt then e - session.LastMeaningfulAt else e,
	}
	for _ in session.UniqueEpic do
		snap.UniqueEpicExact += 1
	end
	for _ in session.UniqueEpicPlus do
		snap.UniqueEpicPlus += 1
	end
	for k, v in eco do
		snap[k] = v
	end
	table.insert(session.Snapshots, snap)
	pushEvent(session, "Snapshot", { Reason = reason, Snapshot = snap })
	return snap
end

function PlaytestAnalyticsService.IsEnabled(): boolean
	return enabled()
end

function PlaytestAnalyticsService.IsRecording(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and s.Recording
end

function PlaytestAnalyticsService.GetStatus(player: Player): any
	local s = sessions[player]
	return {
		Studio = studioOk(),
		CollectionEnabled = BalanceTrials.collectionEnabled(),
		TrackingAllowed = enabled(),
		Recording = s ~= nil and s.Recording,
		SessionId = if s then s.SessionId else nil,
		Elapsed = if s then PlaytestAnalyticsExport.formatElapsed(elapsed(s)) else "00:00",
		ElapsedSec = if s then elapsed(s) else 0,
		EventCount = if s then #s.Events else 0,
		PurchaseCount = if s then #s.Purchases else 0,
		MilestoneCount = if s then #s.Milestones else 0,
	}
end

local function broadcast(player: Player)
	AnalyticsStatus:FireClient(player, PlaytestAnalyticsService.GetStatus(player))
end

function PlaytestAnalyticsService.Start(player: Player): (boolean, string)
	if not studioOk() then
		return false, "Analytics only run in Studio."
	end
	if not BalanceTrials.collectionEnabled() then
		return false, "Collection prototype must be on (Studio auto-trial)."
	end
	local existing = sessions[player]
	if existing and existing.Recording then
		return true, "Already recording."
	end
	local session: SessionState = {
		SessionId = string.format("pt_%d_%s", player.UserId, string.sub(HttpService:GenerateGUID(false), 1, 8)),
		PlayerUserId = player.UserId,
		StartedClock = nowClock(),
		Recording = true,
		Events = {},
		Purchases = {},
		Milestones = {},
		Snapshots = {},
		MinuteMarks = {},
		MinuteMarkSet = {},
		Activity = {
			Scan = 0,
			Hunt = 0,
			Travel = 0,
			UpgradeUI = 0,
			CollectionUI = 0,
			Pedestal = 0,
			Idle = 0,
			Other = 0,
		},
		LastActivity = "Other",
		LastActivityAt = nowClock(),
		LastPurchaseAt = nil,
		LastMeaningfulAt = nil,
		LastEssenceEarnAt = nil,
		MaxEssenceIdle = 0,
		ScanBucket = {},
		ScanBuckets = {},
		WindowBucket = {
			ByTier = {},
			BySource = {},
			UniqueNew = 0,
			Dupes = 0,
			Mutations = 0,
			EpicPlus = 0,
			Total = 0,
		},
		RarityWindows = {},
		LastWindowFlushAt = 0,
		SeenRelics = {},
		FirstTier = {},
		EpicExact = 0,
		UniqueEpic = {},
		EpicPlus = 0,
		UniqueEpicPlus = {},
		UniqueCount = 0,
		HuntCaptures = 0,
		ScanBatches = 0,
		DuplicateSells = 0,
		MutationsFound = 0,
		UnlocksSeen = {},
		UnlocksUsed = {},
		RoutinePurchases = 0,
		FailedPurchases = 0,
		MeaningfulCount = 0,
		LongestGap = 0,
		EventIds = {},
		CollectionPanelOpenedAt = nil,
		CollectionPanelVisits = 0,
		CollectionFailedAttempts = 0,
	}
	sessions[player] = session
	noteMeaningful(session, "Recording started", session.SessionId)
	takeSnapshot(player, session, "Start")
	broadcast(player)
	print(`[PlaytestAnalytics] START {session.SessionId} for {player.Name}`)
	return true, `Recording {session.SessionId}`
end

local function flushScanBucket(session: SessionState)
	local total = 0
	for _, n in session.ScanBucket do
		total += n
	end
	if total <= 0 then
		return
	end
	local e = elapsed(session)
	local row = {
		Elapsed = PlaytestAnalyticsExport.formatElapsed(e),
		ElapsedSec = e,
		Total = total,
		ByTier = session.ScanBucket,
	}
	table.insert(session.ScanBuckets, row)
	pushEvent(session, "ScanAgg", row)
	session.ScanBucket = {}
	session.ScanBatches += 1
end

local function flushRarityWindow(session: SessionState, force: boolean?)
	local w = session.WindowBucket
	if w.Total <= 0 and not force then
		session.LastWindowFlushAt = elapsed(session)
		return
	end
	if w.Total <= 0 then
		return
	end
	local e = elapsed(session)
	local row = {
		Elapsed = PlaytestAnalyticsExport.formatElapsed(e),
		ElapsedSec = e,
		WindowSec = RARITY_WINDOW_SEC,
		Total = w.Total,
		ByTier = w.ByTier,
		BySource = w.BySource,
		UniqueNew = w.UniqueNew,
		Dupes = w.Dupes,
		Mutations = w.Mutations,
		EpicPlus = w.EpicPlus,
	}
	table.insert(session.RarityWindows, row)
	pushEvent(session, "RarityWindow", row)
	session.WindowBucket = {
		ByTier = {},
		BySource = {},
		UniqueNew = 0,
		Dupes = 0,
		Mutations = 0,
		EpicPlus = 0,
		Total = 0,
	}
	session.LastWindowFlushAt = e
end

local function buildFriction(session: SessionState): any
	local unused = {}
	for id in session.UnlocksSeen do
		if not session.UnlocksUsed[id] then
			table.insert(unused, id)
		end
	end
	table.sort(unused)
	local inferences = {}
	local findings = {}
	local hunt = session.HuntCaptures
	local scans = session.ScanBatches
	if hunt + scans > 0 and hunt / math.max(1, hunt + scans) < 0.15 then
		table.insert(inferences, "Session appears scan-heavy relative to spirit captures (inferred).")
	end
	if session.LongestGap >= 5 then
		table.insert(findings, string.format("Observed ≥5 min without a meaningful unlock (longest %.1f min).", session.LongestGap))
	end
	if session.FailedPurchases >= 5 then
		table.insert(findings, "Multiple failed purchases — check unaffordable upgrade pressure.")
	end
	if session.CollectionPanelVisits == 0 and BalanceTrials.collectionEnabled() then
		table.insert(findings, "Collection panel never opened this session.")
	end
	if session.CollectionFailedAttempts >= 3 then
		table.insert(findings, string.format("Collection had %d failed fuse/charm attempts.", session.CollectionFailedAttempts))
	end
	local uniqueEpic = 0
	for _ in session.UniqueEpic do
		uniqueEpic += 1
	end
	return {
		LongestGapMin = session.LongestGap,
		MeaningfulCount = session.MeaningfulCount,
		RoutinePurchases = session.RoutinePurchases,
		FailedPurchases = session.FailedPurchases,
		EpicExact = session.EpicExact,
		UniqueEpicExact = uniqueEpic,
		DuplicateSells = session.DuplicateSells,
		UnusedUnlocks = unused,
		HuntCaptures = session.HuntCaptures,
		ScanBatches = session.ScanBatches,
		MaxEssenceIdleMin = session.MaxEssenceIdle / 60,
		CollectionPanelVisits = session.CollectionPanelVisits,
		CollectionUISec = session.Activity.CollectionUI or 0,
		CollectionFailedAttempts = session.CollectionFailedAttempts,
		Inferences = inferences,
		Findings = findings,
	}
end

function PlaytestAnalyticsService.BuildSession(player: Player): PlaytestAnalyticsExport.Session?
	local session = sessions[player]
	if not session then
		return nil
	end
	flushScanBucket(session)
	flushRarityWindow(session, true)
	setActivity(session, session.LastActivity)
	local duration = elapsed(session)
	return {
		SessionId = session.SessionId,
		StartedAtUnix = os.time() - math.floor(duration),
		EndedAtUnix = os.time(),
		DurationSec = duration,
		Events = session.Events,
		Purchases = session.Purchases,
		Milestones = session.Milestones,
		Snapshots = session.Snapshots,
		MinuteMarks = session.MinuteMarks,
		Activity = session.Activity,
		ScanAgg = session.ScanBuckets,
		Friction = buildFriction(session),
		Meta = {
			Studio = true,
			Balance = if BalanceTrials.current() then BalanceTrials.current().Id else "LIVE",
			RaritySampler = BalanceTrials.raritySampler(),
			Collection = BalanceTrials.collectionEnabled(),
			AnonymousPlayerKey = `P{session.PlayerUserId % 100000}`,
			RarityWindows = session.RarityWindows,
			MutationsFound = session.MutationsFound,
			EpicPlus = session.EpicPlus,
			UniqueCount = session.UniqueCount,
			LongestGapMin = session.LongestGap,
		},
	}
end

local function writeServerStorage(files: { [string]: string }, sessionId: string)
	local folder = ServerStorage:FindFirstChild("PlaytestExport")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlaytestExport"
		folder.Parent = ServerStorage
	end
	local prior = folder:FindFirstChild(sessionId)
	if prior then
		prior:Destroy()
	end
	local bag = Instance.new("Folder")
	bag.Name = sessionId
	bag.Parent = folder
	for name, body in files do
		local sv = Instance.new("StringValue")
		sv.Name = name
		-- StringValue max ~200k; chunk if needed
		if #body > 180000 then
			sv.Value = string.sub(body, 1, 180000)
			local i = 2
			local offset = 180001
			while offset <= #body do
				local chunk = Instance.new("StringValue")
				chunk.Name = `{name}.part{i}`
				chunk.Value = string.sub(body, offset, offset + 179999)
				chunk.Parent = bag
				offset += 180000
				i += 1
			end
		else
			sv.Value = body
		end
		sv.Parent = bag
	end
end

function PlaytestAnalyticsService.Export(player: Player): (boolean, string, any?)
	if not studioOk() then
		return false, "Export only in Studio.", nil
	end
	local session = sessions[player]
	if not session then
		return false, "No session. Start recording first.", nil
	end
	takeSnapshot(player, session, "Export")
	local built = PlaytestAnalyticsService.BuildSession(player)
	if not built then
		return false, "Build failed.", nil
	end
	local files = {
		["PLAYTEST_SESSION.json"] = PlaytestAnalyticsExport.sessionJson(built),
		["PLAYTEST_SUMMARY.md"] = PlaytestAnalyticsExport.summaryMarkdown(built),
		["PLAYTEST_PURCHASES.csv"] = PlaytestAnalyticsExport.purchasesCsv(built),
	}
	writeServerStorage(files, built.SessionId)
	-- Studio-only, export-time only — never at boot, never touches place settings / gameplay.
	if studioOk() and not HttpService.HttpEnabled then
		pcall(function()
			HttpService.HttpEnabled = true
		end)
	end
	local httpOk, httpErr = false, "HttpService post skipped"
	local okPost, errPost = pcall(function()
		if not HttpService.HttpEnabled then
			error("HttpService.HttpEnabled is false — Game Settings → Security → Allow HTTP requests")
		end
		HttpService:PostAsync(
			EXPORT_URL,
			PlaytestAnalyticsExport.toJson({
				SessionId = built.SessionId,
				Files = files,
			}),
			Enum.HttpContentType.ApplicationJson,
			false
		)
	end)
	if okPost then
		httpOk = true
		httpErr = "Posted to localhost:19283"
	else
		httpErr = tostring(errPost)
	end
	print(`[PlaytestAnalytics] EXPORT {built.SessionId} events={#built.Events} purchases={#built.Purchases} http={httpOk} ({httpErr})`)
	print(`[PlaytestAnalytics] ServerStorage.PlaytestExport.{built.SessionId} ready`)
	return true, if httpOk then "Exported to docs/playtest via localhost + ServerStorage." else `Saved to ServerStorage.PlaytestExport.{built.SessionId}. Start tools/playtest_export_server then /analytics export again. ({httpErr})`, {
		SessionId = built.SessionId,
		Files = files,
		HttpOk = httpOk,
		HttpError = httpErr,
		Status = PlaytestAnalyticsService.GetStatus(player),
	}
end

function PlaytestAnalyticsService.Stop(player: Player): (boolean, string, any?)
	local session = sessions[player]
	if not session or not session.Recording then
		return false, "Not recording.", nil
	end
	session.Recording = false
	local ok, msg, payload = PlaytestAnalyticsService.Export(player)
	broadcast(player)
	print(`[PlaytestAnalytics] STOP {session.SessionId}`)
	return ok, msg, payload
end

-- —— Recording APIs (no-ops when not recording) ——

function PlaytestAnalyticsService.RecordPurchase(player: Player, info: {
	System: string,
	Item: string,
	RankBefore: number?,
	RankAfter: number?,
	Price: number?,
	Currency: string?,
	Ok: boolean,
	Reason: string?,
	Kind: string?,
})
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	local eco = economySnapshot(player)
	if not eco then
		return
	end
	local e = elapsed(session)
	local since = if session.LastPurchaseAt then e - session.LastPurchaseAt else 0
	session.LastPurchaseAt = e
	local kind = info.Kind
		or (if not info.Ok then "Failed" elseif info.RankBefore == 0 or info.RankBefore == nil then "Unlock" else "Routine")
	if info.Ok and kind == "Routine" then
		session.RoutinePurchases += 1
	elseif not info.Ok then
		session.FailedPurchases += 1
	end
	if info.Ok and (kind == "Unlock" or kind == "Specialization") then
		noteMeaningful(session, `{info.System}:{info.Item}`, kind)
		session.UnlocksSeen[`{info.System}:{info.Item}`] = true
	end
	if info.Currency == "Essence" and info.Ok and (info.Price or 0) > 0 and session.LastEssenceEarnAt then
		local idle = e - session.LastEssenceEarnAt
		if idle > session.MaxEssenceIdle then
			session.MaxEssenceIdle = idle
		end
	end
	local row = {
		Elapsed = PlaytestAnalyticsExport.formatElapsed(e),
		ElapsedSec = e,
		System = info.System,
		Item = info.Item,
		RankBefore = info.RankBefore,
		RankAfter = info.RankAfter,
		Price = info.Price or 0,
		Currency = info.Currency or "CE",
		CEBefore = eco.CE + (if (info.Ok and (info.Currency or "CE") == "CE") then (info.Price or 0) else 0),
		CEAfter = eco.CE,
		EssenceBefore = eco.Essence + (if (info.Ok and info.Currency == "Essence") then (info.Price or 0) else 0),
		EssenceAfter = eco.Essence,
		Luck = eco.Luck,
		EffectiveLuck = eco.EffectiveLuck,
		RaritySampler = eco.RaritySampler,
		IncomePerSec = eco.IncomePerSec,
		Rebirths = eco.Rebirths,
		SecSincePrev = since,
		Kind = kind,
		Ok = info.Ok,
		Reason = info.Reason,
	}
	-- CEBefore reconstruction: after spend eco already deducted — add price back for CE spends.
	table.insert(session.Purchases, row)
	pushEvent(session, "Purchase", row)
	setActivity(session, "UpgradeUI")
end

function PlaytestAnalyticsService.RecordUnlock(player: Player, unlockId: string, label: string?)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	if session.UnlocksSeen[unlockId] then
		return
	end
	session.UnlocksSeen[unlockId] = true
	noteMeaningful(session, label or unlockId, "Unlock")
end

function PlaytestAnalyticsService.RecordUnlockUsed(player: Player, unlockId: string)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	session.UnlocksUsed[unlockId] = true
end

function PlaytestAnalyticsService.RecordDiscovery(player: Player, relicId: string, tierId: string, mutationId: string?, first: boolean, source: string?)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	local tierI = RarityConfig.IndexById[tierId] or 0
	local epicI = RarityConfig.IndexById.Epic or 4
	local isNewUnique = first and not session.SeenRelics[relicId]
	if isNewUnique then
		session.SeenRelics[relicId] = true
		session.UniqueCount += 1
		noteMeaningful(session, `Unique relic {relicId}`, tierId)
	end
	if not session.FirstTier[tierId] then
		session.FirstTier[tierId] = true
		noteMeaningful(session, `First {tierId}`, relicId)
	end
	if tierI == epicI then
		session.EpicExact += 1
		session.UniqueEpic[relicId] = true
	end
	if tierI >= epicI then
		session.EpicPlus += 1
		session.UniqueEpicPlus[relicId] = true
		pushEvent(session, "EpicPlus", {
			RelicId = relicId,
			Tier = tierId,
			Source = source or "Unknown",
			Mutation = mutationId,
			First = isNewUnique,
		})
	end
	if mutationId then
		session.MutationsFound += 1
		noteMeaningful(session, `Mutation {mutationId}`, relicId)
	end
	-- 5-minute rarity window (all sources)
	local w = session.WindowBucket
	w.Total += 1
	w.ByTier[tierId] = (w.ByTier[tierId] or 0) + 1
	local src = source or "Unknown"
	w.BySource[src] = (w.BySource[src] or 0) + 1
	if isNewUnique then
		w.UniqueNew += 1
	else
		w.Dupes += 1
	end
	if mutationId then
		w.Mutations += 1
	end
	if tierI >= epicI then
		w.EpicPlus += 1
	end
	if source == "Scan" or source == "Bonus" or source == "Capture" then
		-- high-frequency: bucket scans; captures already milestone via Bind
		if source == "Scan" then
			session.ScanBucket[tierId] = (session.ScanBucket[tierId] or 0) + 1
			setActivity(session, "Scan")
		elseif source == "Capture" or source == "Bonus" then
			setActivity(session, "Hunt")
		end
	end
end

function PlaytestAnalyticsService.RecordCapture(player: Player, bonusCount: number, totalRolls: number)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	session.HuntCaptures += 1
	setActivity(session, "Hunt")
	pushEvent(session, "Capture", {
		BonusCount = bonusCount,
		TotalRolls = totalRolls,
	})
end

function PlaytestAnalyticsService.RecordEssenceEarn(player: Player, amount: number)
	local session = sessions[player]
	if not session or not session.Recording or amount <= 0 then
		return
	end
	session.LastEssenceEarnAt = elapsed(session)
end

function PlaytestAnalyticsService.RecordDuplicateSell(player: Player)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	session.DuplicateSells += 1
end

function PlaytestAnalyticsService.RecordClientActivity(player: Player, category: string)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	if session.Activity[category] == nil then
		category = "Other"
	end
	setActivity(session, category)
end

-- Collection HUD funnel (Studio playtests). Deduped meaningful milestones for open/fuse/charm.
local FUNNEL_EVENTS = {
	CollectionOpen = true,
	CollectionClose = true,
	RecipeInspect = true,
	FuseAttempt = true,
	FuseComplete = true,
	FuseFailed = true,
	CharmEquip = true,
	CharmFailed = true,
	FusionReady = true,
}

function PlaytestAnalyticsService.RecordCollectionFunnel(player: Player, eventName: string, detail: string?)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	if not FUNNEL_EVENTS[eventName] then
		return
	end
	local e = elapsed(session)
	local eventDetail = detail
	if eventName == "CollectionOpen" then
		session.CollectionPanelOpenedAt = e
		session.CollectionPanelVisits += 1
		setActivity(session, "CollectionUI")
	elseif eventName == "CollectionClose" then
		local opened = session.CollectionPanelOpenedAt
		local dwell = if opened then math.max(0, e - opened) else 0
		session.CollectionPanelOpenedAt = nil
		eventDetail = string.format("%.1fs", dwell) .. if detail and detail ~= "" then `|{detail}` else ""
		-- Flush CollectionUI dwell into Activity, then leave the category.
		setActivity(session, "CollectionUI")
		setActivity(session, "Other")
	elseif eventName == "FuseFailed" or eventName == "CharmFailed" then
		session.CollectionFailedAttempts += 1
		setActivity(session, "CollectionUI")
	else
		setActivity(session, "CollectionUI")
	end
	pushEvent(session, "CollectionFunnel", {
		Id = `cf_{eventName}_{#session.Events + 1}_{tostring(eventDetail or "")}`,
		Event = eventName,
		Detail = eventDetail,
		CollectionUISec = session.Activity.CollectionUI or 0,
	})
	-- Milestone once per session for the big beats (not every close/refresh).
	if eventName == "CollectionOpen" or eventName == "FuseComplete" or eventName == "CharmEquip" or eventName == "FusionReady" then
		local key = `funnel_{eventName}`
		if eventName == "FuseComplete" or eventName == "CharmEquip" then
			key = `funnel_{eventName}_{tostring(detail or "")}`
		end
		if not session.EventIds[key] then
			session.EventIds[key] = true
			noteMeaningful(session, eventName, detail)
		end
	end
end

function PlaytestAnalyticsService.RecordRebirth(player: Player, rebirths: number)
	local session = sessions[player]
	if not session or not session.Recording then
		return
	end
	noteMeaningful(session, `Rebirth → {rebirths}`, "Rebirth")
	takeSnapshot(player, session, "Rebirth")
end

local function tickPlayer(player: Player, session: SessionState)
	local e = elapsed(session)
	-- minute marks
	for _, m in MINUTE_MARKS do
		if e >= m * 60 and not session.MinuteMarkSet[m] then
			session.MinuteMarkSet[m] = true
			local snap = takeSnapshot(player, session, `Minute{m}`)
			if snap then
				table.insert(session.MinuteMarks, { Minute = m, Snapshot = snap })
			end
		end
	end
	if math.floor(e) % SNAPSHOT_EVERY == 0 then
		-- debounce via last snapshot elapsed
		local last = session.Snapshots[#session.Snapshots]
		if not last or (e - (last.ElapsedSec or 0)) >= SNAPSHOT_EVERY - 0.5 then
			takeSnapshot(player, session, "Periodic")
		end
	end
	if math.floor(e) % SCAN_FLUSH_EVERY == 0 then
		flushScanBucket(session)
	end
	if (e - session.LastWindowFlushAt) >= RARITY_WINDOW_SEC then
		flushRarityWindow(session)
	end
	-- soft idle detect: no event activity
	if session.LastMeaningfulAt and (e - session.LastMeaningfulAt) > 90 then
		if session.LastActivity ~= "Idle" and session.LastActivity ~= "Scan" and session.LastActivity ~= "Hunt" then
			setActivity(session, "Idle")
		end
	end
	-- travel heuristic: in wild and not hunting recently
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local area = WorldLayout.areaAt(Config.Areas, Config.World, root.Position.X, root.Position.Z)
		if area and area ~= "Town" and session.LastActivity ~= "Hunt" then
			-- don't override hunt/scan aggressively
			if session.LastActivity == "Other" or session.LastActivity == "Idle" then
				setActivity(session, "Travel")
			end
		end
	end
end

function PlaytestAnalyticsService.Init()
	if not studioOk() then
		print("[PlaytestAnalytics] Disabled (not Studio).")
		return
	end
	print("[PlaytestAnalytics] Studio module loaded. Auto-start when collection trial is on.")

	RemoteGuard.Function(AnalyticsAction :: RemoteFunction, function(player: Player, action: any, a: any)
		if not studioOk() then
			return { Ok = false, Message = "Studio only." }
		end
		if action == "Status" then
			return PlaytestAnalyticsService.GetStatus(player)
		elseif action == "Start" then
			local ok, msg = PlaytestAnalyticsService.Start(player)
			return { Ok = ok, Message = msg, Status = PlaytestAnalyticsService.GetStatus(player) }
		elseif action == "Stop" then
			local ok, msg, payload = PlaytestAnalyticsService.Stop(player)
			return { Ok = ok, Message = msg, Export = payload, Status = PlaytestAnalyticsService.GetStatus(player) }
		elseif action == "Export" then
			local ok, msg, payload = PlaytestAnalyticsService.Export(player)
			return { Ok = ok, Message = msg, Export = payload, Status = PlaytestAnalyticsService.GetStatus(player) }
		elseif action == "Activity" then
			PlaytestAnalyticsService.RecordClientActivity(player, tostring(a or "Other"))
			return { Ok = true }
		elseif action == "CollectionFunnel" then
			PlaytestAnalyticsService.RecordCollectionFunnel(player, tostring(a or ""), nil)
			return { Ok = true }
		end
		return { Ok = false, Message = "Unknown action." }
	end, "Analytics")

	DataService.OnPlayerLoaded(function(player)
		if enabled() and not autoStarted[player] then
			autoStarted[player] = true
			PlaytestAnalyticsService.Start(player)
		end
		broadcast(player)
	end)

	GameEvents.On("Discovery", function(player: Player, item: any, first: boolean)
		if not item then
			return
		end
		local relic = RelicConfig.ById[item.Id]
		PlaytestAnalyticsService.RecordDiscovery(
			player,
			item.Id,
			if relic then relic.Tier else "Other",
			item.Mutation,
			first == true,
			item.Source
		)
	end)

	GameEvents.On("Rebirthed", function(player: Player)
		local data = DataService.Get(player)
		PlaytestAnalyticsService.RecordRebirth(player, if data then data.Rebirths else 0)
	end)

	GameEvents.On("Captured", function(player: Player, _info: any)
		-- BindService logs roll counts via RecordCapture when wired.
		PlaytestAnalyticsService.RecordClientActivity(player, "Hunt")
	end)

	GameEvents.On("CollectionChanged", function(player: Player)
		local data = DataService.Get(player)
		if not data then
			return
		end
		local state = CollectionMath.sanitize(data.Collection)
		for _, goal in require(ReplicatedStorage.Shared.CollectionConfig).MutationGoals do
			if state.MutationGoalsClaimed[goal.Id] then
				PlaytestAnalyticsService.RecordUnlock(player, `Goal:{goal.Id}`, goal.Name)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if not studioOk() then
				continue
			end
			for player, session in sessions do
				if session.Recording and player.Parent then
					tickPlayer(player, session)
					if math.floor(elapsed(session)) % 15 == 0 then
						broadcast(player)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session and session.Recording then
			PlaytestAnalyticsService.Export(player)
		end
		sessions[player] = nil
		autoStarted[player] = nil
	end)
end

return PlaytestAnalyticsService
