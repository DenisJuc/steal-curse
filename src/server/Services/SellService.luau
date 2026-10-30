-- Selling (GDD 6.5): a small CE drip, never the main income.
--   sale = SellSeconds x relic CE/sec (mutation included) x (1 + sell bonus)
-- The "Sell" additive multiplier is where Spirit Merchant plugs in later. Displayed, locked and
-- floating copies are never sold, whichever path asks (manual sell, auto-sell, full inventory).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local CosmeticEquipService = require(script.Parent.CosmeticEquipService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MultiplierService = require(script.Parent.MultiplierService)
local PedestalService = require(script.Parent.PedestalService)

local SellService = {}

function SellService.SellValue(player: Player, item: any): number
	local bonus = MultiplierService.Get(player, "Sell") - 1
	return Economy.sellValue(Config.Economy, PedestalService.RelicIncome(item), bonus)
end

function SellService.IsSellable(player: Player, item: any): boolean
	return item.Locked ~= true
		and not PedestalService.IsDisplayed(player, item.Uid)
		and not CosmeticEquipService.IsFloating(player, item.Uid)
end

-- Sells every sellable item the predicate accepts, in inventory order, as one CE payment.
-- Returns (count sold, CE earned, [uid] = CE for each sold item).
function SellService.SellWhere(player: Player, shouldSell: (any) -> boolean): (number, number, { [number]: number })
	local data = DataService.Get(player)
	local values: { [number]: number } = {}
	if not data then
		return 0, 0, values
	end
	local kept = table.create(#data.Inventory)
	local sold, earned = 0, 0
	local soldIds = {}
	for _, item in data.Inventory do
		if SellService.IsSellable(player, item) and shouldSell(item) then
			local value = SellService.SellValue(player, item)
			sold += 1
			earned += value
			values[item.Uid] = value
			table.insert(soldIds, item.Id)
		else
			table.insert(kept, item)
		end
	end
	if sold == 0 then
		return 0, 0, values
	end
	data.Inventory = kept
	EconomyService.Add(player, earned)
	local CollectionService = require(script.Parent.CollectionService)
	for _, relicId in soldIds do
		CollectionService.GrantEssenceFromSale(player, relicId)
	end
	DataService.MirrorAttributes(player)
	return sold, earned, values
end

-- Sells up to `count` sellable copies of one relic + mutation. Returns (sold, CE earned).
local function sizeMatch(itemSize: any, want: any): boolean
	local a = if itemSize == "Huge" or itemSize == "Titanic" then itemSize else nil
	local b = if want == "Huge" or want == "Titanic" then want else nil
	return a == b
end

function SellService.Sell(
	player: Player,
	relicId: string,
	mutationId: string?,
	count: number,
	sizeId: string?
): (number, number)
	if count <= 0 then
		return 0, 0
	end
	local data = DataService.Get(player)
	if not data then
		return 0, 0
	end
	local sized = sizeId == "Huge" or sizeId == "Titanic"
	-- Keep at least one owned copy of each sized identity (backpack + pedestal).
	local owned = 0
	if sized then
		for _, item in data.Inventory do
			if item.Id == relicId and item.Mutation == mutationId and sizeMatch(item.Size, sizeId) then
				owned += 1
			end
		end
	end
	local remaining = count
	local sold, earned = SellService.SellWhere(player, function(item)
		if
			remaining > 0
			and item.Id == relicId
			and item.Mutation == mutationId
			and sizeMatch(item.Size, sizeId)
		then
			if sized then
				if owned <= 1 then
					return false
				end
				owned -= 1
			end
			remaining -= 1
			return true
		end
		return false
	end)
	return sold, earned
end

function SellService.Init()
	MultiplierService.DefineKind("Sell", "Additive")
end

return SellService
