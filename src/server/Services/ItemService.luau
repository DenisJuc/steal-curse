-- Potions (Slice 12). Owns Items (counts) and Buffs (seconds left) in the saved data, applies the
-- buffs through MultiplierService (Luck "Potion" factor, Income "Potion" bonus) and the ScanService
-- interval hook (Haste), counts buffs down once per second while the player is online, and hands
-- out potions from the drop sources: hunt captures (a chance), claimed Codex milestones and the
-- first Legendary-or-rarer find. The client only asks to use a potion (ItemAction "Use").
-- Attributes for the UI: Item_<id> = count, BuffEnds_<id> = server time the buff ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local ScanService = require(script.Parent.ScanService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ItemAction = Remotes:WaitForChild("ItemAction") :: RemoteFunction
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local ItemService = {}

local FIRST_RARE_INDEX = RarityConfig.IndexById[ItemConfig.Drops.FirstRareTier]

local online: { [Player]: boolean } = {}
local rng = Random.new()

local function buffsOf(player: Player): { [string]: number }
	local data = DataService.Get(player)
	return if data and data.Buffs then data.Buffs else {}
end

local function mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = workspace:GetServerTimeNow()
	for _, item in ItemConfig.Items do
		player:SetAttribute(`Item_{item.Id}`, data.Items[item.Id] or 0)
		local left = data.Buffs[item.Id]
		player:SetAttribute(`BuffEnds_{item.Id}`, if left and left > 0 then now + left else nil)
	end
end

local function effectsChanged(player: Player)
	MultiplierService.Refresh(player)
	ScanService.RefreshInterval(player)
end

local function describe(rewards: { [string]: number }): string
	local parts = {}
	for _, item in ItemConfig.Items do
		local count = rewards[item.Id]
		if count and count > 0 then
			table.insert(parts, if count > 1 then `{count}x {item.Name}` else item.Name)
		end
	end
	return table.concat(parts, ", ")
end

-- Adds potions (capped at ItemConfig.MaxStack each) and tells the player why.
function ItemService.Grant(player: Player, rewards: { [string]: number }, reason: string?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local given: { [string]: number } = {}
	for id, count in rewards do
		if ItemConfig.ById[id] and count > 0 then
			local before = data.Items[id] or 0
			local after = math.min(ItemConfig.MaxStack, before + math.floor(count))
			data.Items[id] = after
			given[id] = after - before
		end
	end
	local text = describe(given)
	if text == "" then
		return
	end
	mirror(player)
	DataService.RequestSave(player)
	Notify:FireClient(player, `+ {text}{if reason then ` ({reason})` else ""}`, "Item")
end

local function use(player: Player, itemId: string): { Ok: boolean, Message: string }
	local data = DataService.Get(player)
	local item = ItemConfig.ById[itemId]
	if not data or not item then
		return { Ok = false, Message = "Unknown item." }
	end
	if (data.Items[itemId] or 0) <= 0 then
		return { Ok = false, Message = `You have no {item.Name}.` }
	end
	local left, usable = ItemConfig.addTime(data.Buffs[itemId] or 0, item.DurationSeconds, ItemConfig.MaxBuffSeconds)
	if not usable then
		return { Ok = false, Message = `{item.Name} is already at the {ItemConfig.MaxBuffSeconds // 60} minute limit.` }
	end
	data.Items[itemId] -= 1
	if data.Items[itemId] <= 0 then
		data.Items[itemId] = nil
	end
	data.Buffs[itemId] = left
	mirror(player)
	effectsChanged(player)
	DataService.RequestSave(player)
	return { Ok = true, Message = `{item.Name}: {ItemConfig.formatTime(left)} left.` }
end

local function onAction(player: Player, action: unknown, itemId: unknown)
	if action == "Use" and type(itemId) == "string" then
		return use(player, itemId)
	end
	return { Ok = false, Message = "Unknown action." }
end

local function tickAll(dt: number)
	for player in online do
		local data = DataService.Get(player)
		if not data or not data.Buffs or next(data.Buffs) == nil then
			continue
		end
		local expired = ItemConfig.tick(data.Buffs, dt)
		if #expired > 0 then
			mirror(player)
			effectsChanged(player)
			for _, id in expired do
				Notify:FireClient(player, `{ItemConfig.ById[id].Name} wore off.`, "Item")
			end
		end
	end
end

function ItemService.Init()
	MultiplierService.Register("Luck", "Potion", function(player)
		return ItemConfig.luckFactor(buffsOf(player), Config.Luck.MaxConsumable)
	end)
	MultiplierService.Register("Income", "Potion", function(player)
		return ItemConfig.incomeBonus(buffsOf(player))
	end)
	ScanService.SetIntervalHook("Haste", function(player)
		return ItemConfig.intervalFactor(buffsOf(player))
	end)
	RemoteGuard.Function(ItemAction, onAction, "Inventory")

	DataService.OnPlayerLoaded(function(player)
		online[player] = true
		mirror(player)
		effectsChanged(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		online[player] = nil
	end)
	GameEvents.On("DataReset", function(player: Player)
		mirror(player)
		effectsChanged(player)
	end)

	GameEvents.On("Captured", function(player: Player)
		if rng:NextNumber() < ItemConfig.Drops.CaptureChance then
			local id = ItemConfig.pickDrop(ItemConfig.Drops.Weights, rng:NextNumber())
			ItemService.Grant(player, { [id] = 1 }, "found while binding")
		end
	end)
	GameEvents.On("CodexClaimed", function(player: Player, claimed: { string })
		local rewards: { [string]: number } = {}
		for _, milestoneId in claimed do
			for id, count in ItemConfig.Drops.Milestones[milestoneId] or {} do
				rewards[id] = (rewards[id] or 0) + count
			end
		end
		if next(rewards) then
			ItemService.Grant(player, rewards, "Codex reward")
		end
	end)
	GameEvents.On("Discovery", function(player: Player, item: { Id: string })
		local data = DataService.Get(player)
		local relic = RelicConfig.ById[item.Id]
		if not data or not relic or data.ItemRewards.FirstRare then
			return
		end
		if (RarityConfig.IndexById[relic.Tier] or 0) >= FIRST_RARE_INDEX then
			data.ItemRewards.FirstRare = os.time()
			ItemService.Grant(player, ItemConfig.Drops.FirstRare, `first {ItemConfig.Drops.FirstRareTier} or rarer find`)
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			tickAll(now - last)
			last = now
		end
	end)
end

-- Debug: clear every active buff.
function ItemService.ClearBuffs(player: Player)
	local data = DataService.Get(player)
	if data then
		table.clear(data.Buffs)
		mirror(player)
		effectsChanged(player)
	end
end

return ItemService
