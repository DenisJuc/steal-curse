-- Daily bounties (Bounties module, Config.Bounties). Picks each player's dailies and weekly, counts
-- progress from game events (Captured, ShrineCleansed, OfferingOpened, LostOneCaught) and pays
-- claims, the free reroll and streak chests.
-- Remote: BountyAction ("Get" | "Claim" slot | "Reroll" slot) returns { View, Message };
-- BountiesUpdated pushes the view when progress changes. "BountiesReady" mirrors how many are
-- ready to claim (HUD badge).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bounties = require(ReplicatedStorage.Shared.Bounties)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local ItemService = require(script.Parent.ItemService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BountyAction = Remotes:WaitForChild("BountyAction") :: RemoteFunction
local BountiesUpdated = Remotes:WaitForChild("BountiesUpdated") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local BountyService = {}

local OPTIONS = Config.Bounties :: Bounties.Options
local rngs: { [Player]: Random } = {}

local function today(): number
	return Bounties.dayOf(os.time())
end

-- Bounties that can't be done any more (every shrine cleansed).
local function excluded(data: any): { [string]: boolean }
	for _, shrine in WildLayout.CursedShrines do
		if not data.Cleansed[shrine.Id] then
			return {}
		end
	end
	return { Shrine1 = true }
end

local function ceFor(player: Player, minutes: number): number
	return math.max(OPTIONS.MinCE, math.floor(minutes * 60 * EconomyService.GetIncomePerSec(player)))
end

-- Short text of a reward at the player's current income.
local function rewardText(player: Player, reward: Bounties.Reward): string
	local parts = {}
	if reward.CEMinutes then
		table.insert(parts, `{Format.ce(ceFor(player, reward.CEMinutes))} CE`)
	end
	if reward.Potion then
		table.insert(parts, "a potion")
	end
	if reward.Potions then
		local count = 0
		for _, amount in reward.Potions do
			count += amount
		end
		table.insert(parts, `{count} potion{if count == 1 then "" else "s"}`)
	end
	if reward.Rolls then
		table.insert(parts, `{reward.Rolls} discoveries`)
	end
	return table.concat(parts, " + ")
end

local function pay(player: Player, reward: Bounties.Reward, reason: string)
	if reward.CEMinutes then
		EconomyService.Add(player, ceFor(player, reward.CEMinutes))
	end
	local potions: { [string]: number } = if reward.Potions then table.clone(reward.Potions) else {}
	if reward.Potion then
		local rng = rngs[player] or Random.new()
		rngs[player] = rng
		local list = Config.Bounties.Potions
		local id = list[rng:NextInteger(1, #list)]
		potions[id] = (potions[id] or 0) + 1
	end
	if next(potions) then
		ItemService.Grant(player, potions, reason)
	end
	if reward.Rolls and reward.Rolls > 0 then
		local rolls = RollService.RollMany(player, reward.Rolls)
		local entries = table.create(#rolls)
		for index, roll in rolls do
			entries[index] = { Id = roll.Id, Mutation = roll.Mutation, Source = "Bounty" }
		end
		DiscoveryPipeline.GrantBatch(player, entries)
	end
end

local function entryView(player: Player, entry: { Id: string, Progress: number, Claimed: boolean }): { [string]: any }?
	local def = Bounties.byId(OPTIONS, entry.Id)
	if not def then
		return nil
	end
	return {
		Id = def.Id,
		Text = def.Text,
		Difficulty = def.Difficulty,
		Progress = math.min(entry.Progress, def.Goal),
		Goal = def.Goal,
		Claimed = entry.Claimed,
		Reward = rewardText(player, OPTIONS.Rewards[def.Difficulty]),
	}
end

function BountyService.View(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = data.Bounties
	local day = today()
	local slots = {}
	for _, slot in state.Slots do
		table.insert(slots, entryView(player, slot))
	end
	local streak = Bounties.streak(state, day)
	local chest = Bounties.nextChest(OPTIONS, streak)
	return {
		Slots = slots,
		Weekly = entryView(player, state.Weekly),
		Rerolled = state.Rerolled,
		Streak = streak,
		DoneToday = state.Streak.LastDay == day,
		NextChest = if chest then { Day = chest.Day, Reward = rewardText(player, chest) } else nil,
		ResetsIn = Bounties.secondsLeft(os.time()),
	}
end

local function mirror(player: Player)
	local data = DataService.Get(player)
	if data then
		player:SetAttribute("BountiesReady", Bounties.claimable(data.Bounties, OPTIONS))
	end
end

local function push(player: Player)
	mirror(player)
	BountiesUpdated:FireClient(player, BountyService.View(player))
end

local function refresh(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	return Bounties.refresh(data.Bounties, OPTIONS, player.UserId, today(), excluded(data))
end

-- Counts one game event for `player`'s bounties.
function BountyService.Record(player: Player, event: string, payload: { [string]: any })
	local data = DataService.Get(player)
	if not data then
		return
	end
	refresh(player)
	local before = Bounties.claimable(data.Bounties, OPTIONS)
	local completed = Bounties.record(data.Bounties, OPTIONS, event, payload)
	for _, def in completed do
		Notify:FireClient(player, `Bounty complete: {def.Text} - claim it at the Bounty Board in town`, "Item")
	end
	if #completed > 0 or Bounties.claimable(data.Bounties, OPTIONS) ~= before then
		DataService.RequestSave(player)
	end
	push(player)
end

local function claim(player: Player, data: any, which: any): string?
	if which ~= "Weekly" and type(which) ~= "number" then
		return nil
	end
	local day = today()
	local reward, chest = Bounties.claim(data.Bounties, OPTIONS, which, day)
	if not reward then
		return "Not ready yet."
	end
	local text = rewardText(player, reward)
	pay(player, reward, "Bounty")
	local message = `Bounty claimed: {text}`
	if chest then
		pay(player, chest, "Bounty streak")
		message = `{message}. Day {chest.Day} streak chest: {rewardText(player, chest)}!`
	end
	DataService.RequestSave(player)
	return message
end

local function onAction(player: Player, action: any, argument: any)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	refresh(player)
	local message = nil
	if action == "Claim" then
		message = claim(player, data, argument)
	elseif action == "Reroll" then
		if type(argument) == "number" and Bounties.reroll(data.Bounties, OPTIONS, player.UserId, argument, excluded(data)) then
			DataService.RequestSave(player)
			message = "Bounty rerolled."
		else
			message = "You can reroll one unfinished bounty a day."
		end
	elseif action ~= "Get" then
		return nil
	end
	mirror(player)
	return { View = BountyService.View(player), Message = message }
end

-- Debug: complete every bounty, or start a fresh day ("reset").
function BountyService.Debug(player: Player, what: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = data.Bounties
	if what == "reset" then
		state.Day = 0
		state.Weekly.Week = 0
		refresh(player)
	elseif what == "complete" then
		refresh(player)
		local entries = table.clone(state.Slots)
		table.insert(entries, state.Weekly)
		for _, entry in entries do
			local def = Bounties.byId(OPTIONS, entry.Id)
			if def then
				entry.Progress = def.Goal
			end
		end
	elseif what == "nextday" then
		-- Pretend yesterday was the last claim day, so the streak can be tested.
		state.Streak.LastDay = today() - 1
		state.Day = 0
		refresh(player)
	else
		return false
	end
	push(player)
	return true
end

function BountyService.Init()
	RemoteGuard.Function(BountyAction, onAction, "Shrine")
	DataService.OnPlayerLoaded(function(player)
		refresh(player)
		mirror(player)
	end)
	GameEvents.On("DataReset", function(player: Player)
		refresh(player)
		mirror(player)
	end)
	GameEvents.On("Captured", function(player: Player, info: any)
		if type(info) == "table" then
			BountyService.Record(player, "Captured", info)
		end
	end)
	GameEvents.On("ShrineCleansed", function(player: Player, _id: string, area: string)
		BountyService.Record(player, "ShrineCleansed", { Area = area })
	end)
	GameEvents.On("OfferingOpened", function(player: Player, tier: string)
		BountyService.Record(player, "OfferingOpened", { Tier = tier })
	end)
	GameEvents.On("LostOneCaught", function(player: Player)
		BountyService.Record(player, "LostOneCaught", {})
	end)
	Players.PlayerRemoving:Connect(function(player)
		rngs[player] = nil
	end)

	-- New day: fresh dailies for everyone online.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				if refresh(player) then
					push(player)
				end
			end
		end
	end)
end

return BountyService
