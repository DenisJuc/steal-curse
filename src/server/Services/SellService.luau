-- Manual selling (GDD 6.5): a small CE drip, never the main income.
--   sale = SellFraction x relic income (mutation included) x (1 + sell bonus)
-- The "Sell" additive multiplier is where Spirit Merchant plugs in later. Displayed relics can't
-- be sold. Inventory is shown to the client as groups (relic + mutation), which stays small no
-- matter how many copies are held. Auto-sell rules arrive with the inventory slice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MultiplierService = require(script.Parent.MultiplierService)
local PedestalService = require(script.Parent.PedestalService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetRelicGroups = Remotes:WaitForChild("GetRelicGroups") :: RemoteFunction
local SellRelics = Remotes:WaitForChild("SellRelics") :: RemoteFunction

local SellService = {}

export type Group = {
	Id: string,
	Mutation: string?,
	Count: number,
	Displayed: number,
	IncomePerMin: number,
	SellValue: number,
}

function SellService.SellValue(player: Player, item: any): number
	local bonus = MultiplierService.Get(player, "Sell") - 1
	return Economy.sellValue(Config.Economy, PedestalService.RelicIncome(item), bonus)
end

function SellService.Groups(player: Player): { Group }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	local byKey: { [string]: Group } = {}
	local list = {}
	for _, item in data.Inventory do
		local key = `{item.Id}|{item.Mutation or ""}`
		local group = byKey[key]
		if not group then
			group = {
				Id = item.Id,
				Mutation = item.Mutation,
				Count = 0,
				Displayed = 0,
				IncomePerMin = PedestalService.RelicIncome(item),
				SellValue = SellService.SellValue(player, item),
			}
			byKey[key] = group
			table.insert(list, group)
		end
		group.Count += 1
		if PedestalService.IsDisplayed(player, item.Uid) then
			group.Displayed += 1
		end
	end
	table.sort(list, function(a, b)
		if a.IncomePerMin ~= b.IncomePerMin then
			return a.IncomePerMin > b.IncomePerMin
		end
		return a.Id < b.Id
	end)
	return list
end

-- Sells up to `count` undisplayed copies of one relic + mutation. Returns (sold, CE earned).
function SellService.Sell(player: Player, relicId: string, mutationId: string?, count: number): (number, number)
	local data = DataService.Get(player)
	if not data or count <= 0 then
		return 0, 0
	end
	local kept = table.create(#data.Inventory)
	local sold, earned = 0, 0
	for _, item in data.Inventory do
		if
			sold < count
			and item.Id == relicId
			and item.Mutation == mutationId
			and not PedestalService.IsDisplayed(player, item.Uid)
		then
			sold += 1
			earned += SellService.SellValue(player, item)
		else
			table.insert(kept, item)
		end
	end
	if sold == 0 then
		return 0, 0
	end
	data.Inventory = kept
	EconomyService.Add(player, earned)
	DataService.MirrorAttributes(player)
	return sold, earned
end

local function onSell(player: Player, relicId: any, mutationId: any, amount: any)
	if type(relicId) ~= "string" or not RelicConfig.ById[relicId] then
		return nil
	end
	if mutationId ~= nil and (type(mutationId) ~= "string" or not MutationConfig.ById[mutationId]) then
		return nil
	end
	local count
	if amount == "Spare" then
		count = math.huge
	elseif type(amount) == "number" and amount == math.floor(amount) and amount >= 1 then
		count = amount
	else
		return nil
	end
	local sold, earned = SellService.Sell(player, relicId, mutationId, count)
	return { Sold = sold, Earned = earned, Groups = SellService.Groups(player) }
end

function SellService.Init()
	MultiplierService.DefineKind("Sell", "Additive")
	RemoteGuard.Function(GetRelicGroups, SellService.Groups, "Shrine")
	RemoteGuard.Function(SellRelics, onSell, "Shrine")
end
return SellService
