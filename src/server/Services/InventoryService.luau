-- Backpack (GDD 9.2, 9.3): every relic is its own item with a unique Uid. The client sees the
-- backpack grouped by relic + mutation, which stays small however many copies are held. Relics on
-- pedestals are not in the backpack (and don't use its slots); they come back with E on the
-- pedestal (PedestalService "Grab") or from the Shrine menu.
--   Favorite (per relic + mutation): pinned to the top, never auto-sold or sold by Sell all.
--   Lock (per copy; the UI locks a whole group): the copies can't be sold at all.
--   Floating: the one copy hovering beside the player (CosmeticEquipService); never sold.
-- Remotes: GetInventory (snapshot) and InventoryAction (Favorite, Lock, Sell, SellAll,
-- SetAutoSell, Float), which returns the fresh snapshot so the menu redraws from server truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local AutoSellService = require(script.Parent.AutoSellService)
local CosmeticEquipService = require(script.Parent.CosmeticEquipService)
local DataService = require(script.Parent.DataService)
local PedestalService = require(script.Parent.PedestalService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local SellService = require(script.Parent.SellService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetInventory = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local InventoryAction = Remotes:WaitForChild("InventoryAction") :: RemoteFunction

local InventoryService = {}

export type Group = {
	Id: string,
	Mutation: string?,
	-- Copies in the backpack (pedestal copies are not listed).
	Count: number,
	Locked: number,
	-- Copies that can be sold right now (not locked, not floating).
	Sellable: number,
	Favorite: boolean,
	-- One of the copies floats beside the player.
	Floating: boolean,
	IncomePerSec: number,
	SellValue: number,
}

-- Uids the "Sell all" button would sell right now (AutoSell.sellAll).
local function sellAllUids(player: Player, data: any): { number }
	local copies = {}
	for _, item in data.Inventory do
		table.insert(copies, {
			Uid = item.Uid,
			Displayed = PedestalService.IsDisplayed(player, item.Uid),
			Locked = item.Locked == true,
			Favorite = data.Favorites[AutoSell.favoriteKey(item.Id, item.Mutation)] == true,
			Floating = CosmeticEquipService.IsFloating(player, item.Uid),
		})
	end
	return AutoSell.sellAll(copies)
end

-- Preview for the button: how many copies it sells and for how much CE.
local function sellAllPreview(player: Player, data: any): { Count: number, Value: number }
	local sell = {}
	for _, uid in sellAllUids(player, data) do
		sell[uid] = true
	end
	local count, value = 0, 0
	for _, item in data.Inventory do
		if sell[item.Uid] then
			count += 1
			value += SellService.SellValue(player, item)
		end
	end
	return { Count = count, Value = value }
end

function InventoryService.Groups(player: Player): { Group }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	local byKey: { [string]: Group } = {}
	local list = {}
	for _, item in data.Inventory do
		if PedestalService.IsDisplayed(player, item.Uid) then
			continue
		end
		local key = AutoSell.favoriteKey(item.Id, item.Mutation)
		local group = byKey[key]
		if not group then
			group = {
				Id = item.Id,
				Mutation = item.Mutation,
				Count = 0,
				Locked = 0,
				Sellable = 0,
				Favorite = data.Favorites[key] == true,
				Floating = false,
				IncomePerSec = PedestalService.RelicIncome(item),
				SellValue = SellService.SellValue(player, item),
			}
			byKey[key] = group
			table.insert(list, group)
		end
		group.Count += 1
		if item.Locked then
			group.Locked += 1
		end
		if CosmeticEquipService.IsFloating(player, item.Uid) then
			group.Floating = true
		elseif not item.Locked then
			group.Sellable += 1
		end
	end
	table.sort(list, function(a, b)
		if a.Floating ~= b.Floating then
			return a.Floating
		end
		if a.Favorite ~= b.Favorite then
			return a.Favorite
		end
		if a.IncomePerSec ~= b.IncomePerSec then
			return a.IncomePerSec > b.IncomePerSec
		end
		return AutoSell.favoriteKey(a.Id, a.Mutation) < AutoSell.favoriteKey(b.Id, b.Mutation)
	end)
	return list
end

function InventoryService.State(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return {
		Groups = InventoryService.Groups(player),
		Count = DataService.BackpackCount(data),
		Capacity = Config.Inventory.Capacity,
		AutoSell = AutoSellService.Rules(player),
		SellAll = sellAllPreview(player, data),
	}
end

local function validGroup(relicId: any, mutationId: any): boolean
	if type(relicId) ~= "string" or not RelicConfig.ById[relicId] then
		return false
	end
	return mutationId == nil or (type(mutationId) == "string" and MutationConfig.ById[mutationId] ~= nil)
end

local ACTIONS: { [string]: (Player, any, ...any) -> string? } = {
	Favorite = function(_player, data, relicId, mutationId, on)
		if not validGroup(relicId, mutationId) or type(on) ~= "boolean" then
			return nil
		end
		data.Favorites[AutoSell.favoriteKey(relicId, mutationId)] = if on then true else nil
		return nil
	end,

	Lock = function(_player, data, relicId, mutationId, on)
		if not validGroup(relicId, mutationId) or type(on) ~= "boolean" then
			return nil
		end
		for _, item in data.Inventory do
			if item.Id == relicId and item.Mutation == mutationId then
				item.Locked = if on then true else nil
			end
		end
		return nil
	end,

	Sell = function(player, _data, relicId, mutationId, amount)
		if not validGroup(relicId, mutationId) then
			return nil
		end
		local count
		if amount == "All" then
			count = math.huge
		elseif type(amount) == "number" and amount == math.floor(amount) and amount >= 1 then
			count = amount
		else
			return nil
		end
		local sold, earned = SellService.Sell(player, relicId, mutationId, count)
		if sold == 0 then
			return "Nothing to sell (locked and floating copies are kept)."
		end
		local relic = RelicConfig.ById[relicId]
		local name = if mutationId then `{mutationId} {relic.Name}` else relic.Name
		return `Sold {sold} x {name} for {Format.number(earned)} CE`
	end,

	SellAll = function(player, data)
		local sell = {}
		for _, uid in sellAllUids(player, data) do
			sell[uid] = true
		end
		local sold, earned = SellService.SellWhere(player, function(item)
			return sell[item.Uid] == true
		end)
		if sold == 0 then
			return "Nothing to sell (locked, favorite and floating relics are kept)."
		end
		return `Sold {sold} relic{if sold == 1 then "" else "s"} for {Format.number(earned)} CE`
	end,

	SetAutoSell = function(player, _data, rules)
		AutoSellService.SetRules(player, rules)
		return "Auto-sell rules saved."
	end,

	-- on: float a copy beside the player, or put it away (display only, GDD 9.1).
	Float = function(player, _data, relicId, mutationId, on)
		return CosmeticEquipService.FloatGroup(player, relicId, mutationId, on)
	end,
}

local function onAction(player: Player, action: any, ...: any)
	local data = DataService.Get(player)
	local handler = type(action) == "string" and ACTIONS[action]
	if not data or not handler then
		return nil
	end
	local message = handler(player, data, ...)
	return { State = InventoryService.State(player), Message = message }
end

function InventoryService.Init()
	RemoteGuard.Function(GetInventory, InventoryService.State, "Inventory")
	RemoteGuard.Function(InventoryAction, onAction, "Inventory")
end

return InventoryService
