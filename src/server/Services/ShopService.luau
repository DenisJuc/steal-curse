-- Shop (Config.GamePasses, Config.DevProducts, Config.Shop).
--   Pass effects: DoubleLuck (Luck x2), FasterSeal (scan interval x0.75), MoreIncome (+50% income).
--   AutoEquip is handled by PedestalService.
--   Developer products go through one ProcessReceipt. Each grant records its PurchaseId in
--   data.PurchaseIdCache and the receipt is only confirmed once that id is in the SAVED data
--   (ProfileStore's dev-product pattern), so a purchase is never lost or paid twice.
--   Server Luck: workspace attribute ServerLuckEndsAt (server time); everyone's Luck x2 until then.
--   Event products (Config.Shop.Events): start that zone event for everyone now.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GamePassService = require(script.Parent.GamePassService)
local GameEvents = require(script.Parent.GameEvents)
local ItemService = require(script.Parent.ItemService)
local MultiplierService = require(script.Parent.MultiplierService)
local ScanService = require(script.Parent.ScanService)

local ShopService = {}

local PURCHASE_ID_CACHE_SIZE = 100
local SHOP = Config.Shop

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerLuckBought = Remotes:WaitForChild("ServerLuckBought") :: RemoteEvent
local EventSummoned = Remotes:WaitForChild("EventSummoned") :: RemoteEvent

local function serverLuckActive(): boolean
	local ends = workspace:GetAttribute("ServerLuckEndsAt")
	return type(ends) == "number" and ends > workspace:GetServerTimeNow()
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		MultiplierService.Refresh(player)
	end
end

-- Product name -> grant(player). A grant that errors leaves the receipt unprocessed (retried).
local grants: { [string]: (Player) -> () } = {
	LuckPotion = function(player)
		ItemService.Grant(player, { LuckPotion = 1 }, "purchase")
	end,
	PotionBundle = function(player)
		ItemService.Grant(player, SHOP.PotionBundle, "purchase")
	end,
	ServerLuck = function(player)
		local now = workspace:GetServerTimeNow()
		local ends = workspace:GetAttribute("ServerLuckEndsAt")
		local from = if type(ends) == "number" and ends > now then ends else now
		workspace:SetAttribute("ServerLuckEndsAt", from + SHOP.ServerLuckSeconds)
		refreshAll()
		ServerLuckBought:FireAllClients(player.DisplayName, SHOP.ServerLuckSeconds)
		-- Luck falls back when it ends.
		task.delay(from + SHOP.ServerLuckSeconds - now + 0.5, refreshAll)
	end,
}

-- Event products: start that zone event for the whole server now (a running event is replaced).
for _, entry in SHOP.Events do
	grants[entry.Name] = function(player)
		local ZoneEventService = require(script.Parent.ZoneEventService)
		if not ZoneEventService.Force(entry.Event) then
			error(`unknown zone event {entry.Event}`)
		end
		EventSummoned:FireAllClients(player.DisplayName, entry.Event)
	end
end

local function productName(productId: number): string?
	for name, id in Config.DevProducts do
		if id > 0 and id == productId then
			return name
		end
	end
	return nil
end

local function purchaseIdCheck(profile: any, purchaseId: string, grant: () -> ()): Enum.ProductPurchaseDecision
	if not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local cache = profile.Data.PurchaseIdCache
	if table.find(cache, purchaseId) == nil then
		local ok, err = pcall(grant)
		if not ok then
			warn(`[ShopService] Grant failed for {purchaseId}: {err}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #cache >= PURCHASE_ID_CACHE_SIZE do
			table.remove(cache, 1)
		end
		table.insert(cache, purchaseId)
	end
	local function saved(): boolean
		local last = profile.LastSavedData
		local savedCache = last and last.PurchaseIdCache
		return savedCache ~= nil and table.find(savedCache, purchaseId) ~= nil
	end
	while profile:IsActive() do
		if saved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local last = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == last then
			profile.OnAfterSave:Wait()
		end
		if saved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if profile:IsActive() then
			task.wait(10)
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local name = productName(receipt.ProductId)
	local grant = name and grants[name]
	if not player or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return purchaseIdCheck(profile, receipt.PurchaseId, function()
		grant(player)
	end)
end

-- Studio /buy command: runs a product's grant without Roblox (no receipt).
function ShopService.DebugGrant(player: Player, name: string): boolean
	local grant = grants[name]
	if not grant then
		return false
	end
	grant(player)
	return true
end

function ShopService.Init()
	MultiplierService.Register("Luck", "Pass", function(player)
		return if GamePassService.Owns(player, "DoubleLuck") then SHOP.DoubleLuckFactor else 1
	end)
	MultiplierService.Register("Luck", "ServerLuck", function()
		return if serverLuckActive() then SHOP.ServerLuckFactor else 1
	end)
	MultiplierService.Register("Income", "Pass", function(player)
		return if GamePassService.Owns(player, "MoreIncome") then SHOP.MoreIncomeBonus else 0
	end)
	ScanService.SetIntervalHook("FasterSeal", function(player)
		return if GamePassService.Owns(player, "FasterSeal") then SHOP.FasterSealFactor else 1
	end)
	GameEvents.On("GamePassChanged", function(player: Player, name: string)
		if name == "FasterSeal" then
			ScanService.RefreshInterval(player)
		else
			MultiplierService.Refresh(player)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopService
