-- Auto-sell pipeline stage (GDD 9.2, 9.3). Runs on the new finds of a batch (and skips any that
-- are already on a pedestal). The rule order lives in the pure AutoSell.decide (unit-tested).
-- Then the capacity check: scans pause at the limit (ScanService), so this only catches other
-- sources (signal captures, debug grants). If the inventory is full, a kept find is sold too,
-- unless it is a first discovery or rare (Config.Inventory overflow rules), kept over the limit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicIncome = require(ReplicatedStorage.Shared.RelicIncome)
local DataService = require(script.Parent.DataService)
local PedestalService = require(script.Parent.PedestalService)
local SellService = require(script.Parent.SellService)

local AutoSellService = {}

export type Sale = { Earned: number, Reason: string }

local TIER_IDS = {}
for _, tier in RarityConfig.Tiers do
	table.insert(TIER_IDS, tier.Id)
end
local DEFAULTS = AutoSell.defaults(TIER_IDS)

local KEEP_TIER = RarityConfig.IndexById[Config.Inventory.OverflowKeepTier]
local KEEP_MUTATED_TIER = RarityConfig.IndexById[Config.Inventory.OverflowKeepMutatedTier]

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
end

-- Finds that may go over the inventory limit instead of being sold.
function AutoSellService.KeepsOnOverflow(item: any, first: boolean): boolean
	local index = tierIndex(item.Id)
	return first or index >= KEEP_TIER or (item.Mutation ~= nil and index >= KEEP_MUTATED_TIER)
end

function AutoSellService.Rules(player: Player): AutoSell.Rules
	local data = DataService.Get(player)
	return AutoSell.sanitize(if data then data.Settings.AutoSell else nil, TIER_IDS, DEFAULTS)
end

function AutoSellService.SetRules(player: Player, raw: any): boolean
	local data = DataService.Get(player)
	if not data or type(raw) ~= "table" then
		return false
	end
	data.Settings.AutoSell = AutoSell.sanitize(raw, TIER_IDS, AutoSellService.Rules(player)) :: any
	return true
end

function AutoSellService.BaseOneIn(relicId: string): number
	return RelicIncome.oneIn(relicId)
end

-- Pipeline stage. `items` are the batch's new items (already in the inventory, in grant order),
-- `firsts[uid]` marks first Codex discoveries, `shown[uid]` marks items now on a pedestal.
-- Returns the auto-sold items: [uid] = { Earned, Reason }.
function AutoSellService.Apply(
	player: Player,
	items: { any },
	firsts: { [number]: boolean },
	shown: { [number]: boolean }
): { [number]: Sale }
	local sales: { [number]: Sale } = {}
	local data = DataService.Get(player)
	if not data or #items == 0 then
		return sales
	end
	local rules = AutoSellService.Rules(player)

	local inBatch = {}
	for _, item in items do
		inBatch[item.Uid] = true
	end
	-- Best income already held per base relic (items held before this batch, plus displayed ones).
	-- `held` counts backpack slots only: relics on pedestals don't use them.
	local bestHeld: { [string]: number } = {}
	local held = 0
	for _, item in data.Inventory do
		if not inBatch[item.Uid] or shown[item.Uid] then
			if not PedestalService.IsDisplayed(player, item.Uid) then
				held += 1
			end
			local income = PedestalService.RelicIncome(item)
			bestHeld[item.Id] = math.max(bestHeld[item.Id] or -1, income)
		end
	end

	local reasons: { [number]: string } = {}
	for _, item in items do
		if shown[item.Uid] then
			continue
		end
		local relic = RelicConfig.ById[item.Id]
		local income = PedestalService.RelicIncome(item)
		local first = firsts[item.Uid] == true
		local sell, reason = AutoSell.decide(rules, {
			Tier = if relic then relic.Tier else "Common",
			BaseOneIn = AutoSellService.BaseOneIn(item.Id),
			First = first,
			Mutated = item.Mutation ~= nil,
			Duplicate = (bestHeld[item.Id] or -1) >= income,
			Favorite = data.Favorites[AutoSell.favoriteKey(item.Id, item.Mutation)] == true,
		})
		local finalReason: string = reason
		if not sell and held + 1 > Config.Inventory.Capacity and not AutoSellService.KeepsOnOverflow(item, first) then
			sell, finalReason = true, "InventoryFull"
		end
		if sell then
			reasons[item.Uid] = finalReason
		else
			held += 1
			bestHeld[item.Id] = math.max(bestHeld[item.Id] or -1, income)
		end
	end

	if next(reasons) == nil then
		return sales
	end
	local _, _, values = SellService.SellWhere(player, function(item)
		return reasons[item.Uid] ~= nil
	end)
	for uid, value in values do
		sales[uid] = { Earned = value, Reason = reasons[uid] }
	end
	return sales
end

return AutoSellService
