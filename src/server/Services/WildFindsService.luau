-- Personal happenings in the wild (Config.WildFinds), timed per player while they are in the wild.
-- Everything goes to the owner only, through the WildFind remote:
--   Strike    lightning lands near you and strikes your signals there (SignalService.Strike);
--             capturing one rolls nothing but gives Lightning Luck (BindService, LightningService).
--             { Kind = "Strike", Position, Until }
--   Offering  a lost offering box, found by ear. Opened with WildFindAction("Claim", id) in range.
--             { Kind = "Offering", Id, Position, ExpiresAt } / { Kind = "OfferingGone", Id }
--             / { Kind = "OfferingOpened", Id, Tier, Text }
--   LostOne   the Watcher: come close and it blinks farther, Hops times, then leaves a Spirit Gift
--             (or turns out False). WildFindAction("Pulse") scares it off for good.
--             The False Watcher lunges and drains part of the Hunt Streak instead.
--             { Kind = "LostOne", Id, Position, Hop, Hops, ExpiresAt, Wrong? } / { Kind = "LostOneEnd",
--             Id, Result = "Gift" | "False" | "Scared" | "Left", Tier?, Text?, Drained? }
-- Offering boxes and Spirit Gifts pay out through the Offerings module (one shared pity counter).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Offerings = require(ReplicatedStorage.Shared.Offerings)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local ItemService = require(script.Parent.ItemService)
local LanternService = require(script.Parent.LanternService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)
local SignalService = require(script.Parent.SignalService)
local StreakService = require(script.Parent.StreakService)
local ZoneEventService = require(script.Parent.ZoneEventService)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WildFind = Remotes:WaitForChild("WildFind") :: RemoteEvent
local WildFindAction = Remotes:WaitForChild("WildFindAction") :: RemoteEvent

local WildFindsService = {}

local TICK_SECONDS = 0.5
-- Studs of network slack allowed when opening a box.
local CLAIM_SLACK = 4
-- Seconds a step back into the wild waits before anything happens.
local TOWN_GRACE = 15

type Offering = { Id: number, Position: Vector3, ExpiresAt: number }
type LostOne = { Id: number, Position: Vector3, Blinks: number, False: boolean, ExpiresAt: number }

type State = {
	Rng: Random,
	NextId: number,
	NextStrike: number,
	NextOffering: number,
	NextLostOne: number,
	Offering: Offering?,
	LostOne: LostOne?,
}

local states: { [Player]: State } = {}

local function between(rng: Random, range: { number }): number
	return range[1] + rng:NextNumber() * (range[2] - range[1])
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return nil
	end
	return root.Position
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Voxel terrain can sit a few studs above the height the spot was planned at; snap to its surface
-- so boxes and figures never end up buried.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function onGround(point: Vector3): Vector3
	local hit = workspace:Raycast(point + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), groundParams)
	return if hit then hit.Position else point
end

local function send(player: Player, payload: { [string]: any })
	WildFind:FireClient(player, payload)
end

-- Opens one gift (offering box or Spirit Gift): rolls the tier with pity, pays it out and returns
-- the tier id and a short description.
local function payGift(player: Player, state: State, reason: string): (string, string)
	local data = DataService.Get(player)
	if not data then
		return "Common", ""
	end
	local options = Config.Offerings :: any
	local tierId, misses = Offerings.rollTier(options, data.OfferingPity, state.Rng:NextNumber())
	data.OfferingPity = misses
	local owned = {}
	for id in data.Lanterns.Owned do
		owned[id] = true
	end
	local reward = Offerings.rollReward(options, tierId, function()
		return state.Rng:NextNumber()
	end, owned)
	local lines = {}
	if reward.CEMinutes then
		local amount = Offerings.ceAmount(reward.CEMinutes, EconomyService.GetIncomePerSec(player), options)
		EconomyService.Add(player, amount)
		table.insert(lines, `+{Format.ce(amount)} CE`)
	end
	if reward.Rolls and reward.Rolls > 0 then
		local rolls = RollService.RollMany(player, reward.Rolls)
		local entries = table.create(#rolls)
		for index, roll in rolls do
			entries[index] = { Id = roll.Id, Mutation = roll.Mutation, Source = "Offering" }
		end
		DiscoveryPipeline.GrantBatch(player, entries)
		table.insert(lines, `+{reward.Rolls} discoveries`)
	end
	local tier = Offerings.tierOf(options, tierId)
	if next(reward.Potions) then
		ItemService.Grant(player, reward.Potions, if tier then tier.Name else reason)
		table.insert(lines, "potions")
	end
	if reward.Lantern then
		LanternService.Grant(player, reward.Lantern, if tier then tier.Name else reason)
		table.insert(lines, `{LanternService.NameOf(reward.Lantern)} lantern`)
	end
	DataService.RequestSave(player)
	return tierId, table.concat(lines, ", ")
end

-- Lightning --------------------------------------------------------------------------------------

local function strikeGap(state: State, position: Vector3): number
	local cfg = Config.WildFinds.Strike
	local area = WorldLayout.areaAt(Config.Areas, Config.World, position.X, position.Z)
	local event = ZoneEventService.Active()
	local every = if event and event.Area == area and event.StrikeEvery then event.StrikeEvery else cfg.Every
	return between(state.Rng, every)
end

-- Lightning near the player (or exactly at `at`). Returns the strike point, or nil.
function WildFindsService.Strike(player: Player, at: Vector3?): Vector3?
	local state = states[player]
	local position = rootPosition(player)
	if not state or not position then
		return nil
	end
	local cfg = Config.WildFinds.Strike
	local ground = at
	if not ground then
		local point = SignalService.RandomPoint(position, cfg.Distance[1], cfg.Distance[2], state.Rng)
		ground = point and point.Position
	end
	if not ground then
		return nil
	end
	ground = onGround(ground)
	local untilTime = workspace:GetServerTimeNow() + cfg.Seconds
	SignalService.Strike(player, ground, cfg.Radius, untilTime)
	send(player, { Kind = "Strike", Position = ground, Until = untilTime })
	return ground
end

-- Offerings --------------------------------------------------------------------------------------

local function nextOffering(state: State)
	state.NextOffering = os.clock() + between(state.Rng, Config.WildFinds.Offering.Every)
end

-- Hides an offering box near the player (or at `at`). Returns its position, or nil.
function WildFindsService.SpawnOffering(player: Player, at: Vector3?): Vector3?
	local state = states[player]
	local position = rootPosition(player)
	if not state or not position then
		return nil
	end
	local cfg = Config.WildFinds.Offering
	local ground = at
	if not ground then
		local point = SignalService.RandomPoint(position, cfg.Distance[1], cfg.Distance[2], state.Rng)
		ground = point and point.Position
	end
	if not ground then
		return nil
	end
	ground = onGround(ground)
	if state.Offering then
		send(player, { Kind = "OfferingGone", Id = state.Offering.Id })
	end
	local offering = { Id = state.NextId, Position = ground, ExpiresAt = workspace:GetServerTimeNow() + cfg.Seconds }
	state.NextId += 1
	state.Offering = offering
	send(player, { Kind = "Offering", Id = offering.Id, Position = ground, ExpiresAt = offering.ExpiresAt })
	return ground
end

local function claimOffering(player: Player, state: State, id: number)
	local offering = state.Offering
	local position = rootPosition(player)
	if not offering or offering.Id ~= id or not position then
		return
	end
	if (position - offering.Position).Magnitude > Config.WildFinds.Offering.ClaimRange + CLAIM_SLACK then
		return
	end
	state.Offering = nil
	nextOffering(state)
	local tierId, text = payGift(player, state, "Offering")
	send(player, { Kind = "OfferingOpened", Id = id, Tier = tierId, Text = text })
	GameEvents.Fire("OfferingOpened", player, tierId)
end

-- The Lost One -----------------------------------------------------------------------------------

local function nextLostOne(state: State)
	state.NextLostOne = os.clock() + between(state.Rng, Config.WildFinds.LostOne.Every)
end

local function endLostOne(player: Player, state: State, result: string, tierId: string?, text: string?, drained: number?)
	local lost = state.LostOne
	if not lost then
		return
	end
	state.LostOne = nil
	nextLostOne(state)
	send(player, { Kind = "LostOneEnd", Id = lost.Id, Result = result, Tier = tierId, Text = text, Drained = drained })
end

-- The False Watcher lunges: it drains part of the Hunt Streak.
local function falseWatcher(player: Player, state: State)
	local drained = StreakService.Drain(player, Config.WildFinds.LostOne.FalseDrain)
	endLostOne(player, state, "False", nil, nil, drained)
end

local function showLostOne(player: Player, lost: LostOne)
	local cfg = Config.WildFinds.LostOne
	send(player, {
		Kind = "LostOne",
		Id = lost.Id,
		Position = lost.Position,
		Hop = lost.Blinks,
		Hops = cfg.Hops,
		ExpiresAt = lost.ExpiresAt,
		-- Its eyes flicker red now and then (the only tell).
		Wrong = if lost.False and lost.Blinks >= cfg.FalseTellsFrom then true else nil,
	})
end

-- A spot `range` studs from `from`, preferring ones farther from the player (it leads you on).
local function leadOn(state: State, from: Vector3, player: Vector3, range: { number }): Vector3?
	local best, bestDistance = nil, -1
	for _ = 1, 6 do
		local point = SignalService.RandomPoint(from, range[1], range[2], state.Rng)
		if point then
			local distance = flatDistance(point.Position, player)
			if distance > bestDistance then
				best, bestDistance = point.Position, distance
			end
		end
	end
	return if best then onGround(best) else nil
end

-- Debug overrides: False forces (or rules out) the False Watcher, Blinks starts it partway
-- through its hops, Now ends it at once (the False Watcher lunges right away).
export type LostOneOptions = { False: boolean?, Blinks: number?, Now: boolean? }

function WildFindsService.SpawnLostOne(player: Player, options: LostOneOptions?): Vector3?
	local state = states[player]
	local position = rootPosition(player)
	if not state or not position then
		return nil
	end
	local cfg = Config.WildFinds.LostOne
	local point = SignalService.RandomPoint(position, cfg.StartDistance[1], cfg.StartDistance[2], state.Rng)
	if not point then
		return nil
	end
	if state.LostOne then
		endLostOne(player, state, "Left")
	end
	local isFalse = state.Rng:NextNumber() < cfg.FalseChance
	if options and options.False ~= nil then
		isFalse = options.False
	end
	local lost = {
		Id = state.NextId,
		Position = onGround(point.Position),
		Blinks = math.clamp(if options and options.Blinks then options.Blinks else 0, 0, cfg.Hops),
		False = isFalse,
		ExpiresAt = workspace:GetServerTimeNow() + cfg.Seconds,
	}
	state.NextId += 1
	state.LostOne = lost
	showLostOne(player, lost)
	if options and options.Now and lost.False then
		falseWatcher(player, state)
	end
	return lost.Position
end

local function stepLostOne(player: Player, state: State, position: Vector3)
	local lost = state.LostOne
	if not lost then
		return
	end
	local cfg = Config.WildFinds.LostOne
	if workspace:GetServerTimeNow() > lost.ExpiresAt then
		endLostOne(player, state, "Left")
		return
	end
	if flatDistance(position, lost.Position) > cfg.Trigger then
		return
	end
	if lost.Blinks < cfg.Hops then
		local spot = leadOn(state, lost.Position, position, cfg.HopDistance)
		if not spot then
			endLostOne(player, state, "Left")
			return
		end
		lost.Blinks += 1
		lost.Position = spot
		lost.ExpiresAt = workspace:GetServerTimeNow() + cfg.Seconds
		showLostOne(player, lost)
		return
	end
	if lost.False then
		falseWatcher(player, state)
		return
	end
	local tierId, text = payGift(player, state, "Spirit Gift")
	endLostOne(player, state, "Gift", tierId, text)
	GameEvents.Fire("LostOneCaught", player, tierId)
end

-- Remote -----------------------------------------------------------------------------------------

local function onAction(player: Player, action: any, id: any)
	local state = states[player]
	if not state then
		return
	end
	if action == "Claim" and type(id) == "number" then
		claimOffering(player, state, id)
	elseif action == "Pulse" and state.LostOne then
		endLostOne(player, state, "Scared")
	end
end

function WildFindsService.Init()
	RemoteGuard.Event(WildFindAction, onAction, "WildFind")
	DataService.OnPlayerLoaded(function(player)
		local now = os.clock()
		local rng = Random.new()
		local finds = Config.WildFinds
		states[player] = {
			Rng = rng,
			NextId = 1,
			NextStrike = now + between(rng, finds.Strike.Every),
			NextOffering = now + finds.Offering.FirstAfter,
			NextLostOne = now + finds.LostOne.FirstAfter,
			Offering = nil,
			LostOne = nil,
		}
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local now = os.clock()
			local serverNow = workspace:GetServerTimeNow()
			for player, state in states do
				local offering = state.Offering
				if offering and serverNow > offering.ExpiresAt then
					state.Offering = nil
					nextOffering(state)
					send(player, { Kind = "OfferingGone", Id = offering.Id })
				end
				local position = rootPosition(player)
				if not position or not WorldLayout.inWild(Config.World, position.X, position.Z) then
					-- Timers wait in town, with a short grace after stepping back out.
					state.NextStrike = math.max(state.NextStrike, now + TOWN_GRACE)
					state.NextOffering = math.max(state.NextOffering, now + TOWN_GRACE)
					state.NextLostOne = math.max(state.NextLostOne, now + TOWN_GRACE)
					if state.LostOne then
						endLostOne(player, state, "Left")
					end
					continue
				end
				if now >= state.NextStrike then
					state.NextStrike = now + strikeGap(state, position)
					WildFindsService.Strike(player)
				end
				if not state.Offering and now >= state.NextOffering then
					if not WildFindsService.SpawnOffering(player) then
						nextOffering(state)
					end
				end
				if state.LostOne then
					stepLostOne(player, state, position)
				elseif now >= state.NextLostOne then
					if not WildFindsService.SpawnLostOne(player) then
						nextLostOne(state)
					end
				end
			end
		end
	end)
end

return WildFindsService
