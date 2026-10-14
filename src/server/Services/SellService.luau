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
	for _, item in data.Inventory do
		if SellService.IsSellable(player, item) and shouldSell(item) then
			local value = SellService.SellValue(player, item)
			sold += 1
			earned += value
			values[item.Uid] = value
		else
			table.insert(kept, item)
		end
	end
	if sold == 0 then
		return 0, 0, values
	end
	data.Inventory = kept
	EconomyService.Add(player, earned)
	DataService.MirrorAttributes(player)
	return sold, earned, values
end

-- Sells up to `count` sellable copies of one relic + mutation. Returns (sold, CE earned).
function SellService.Sell(player: Player, relicId: string, mutationId: string?, count: number): (number, number)
	if count <= 0 then
		return 0, 0
	end
	local remaining = count
	local sold, earned = SellService.SellWhere(player, function(item)
		if remaining > 0 and item.Id == relicId and item.Mutation == mutationId then
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
