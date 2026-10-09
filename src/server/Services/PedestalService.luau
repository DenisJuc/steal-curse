-- Shrine pedestals (GDD 6.3, 6.4): buy slots 4-6 with CE, per-slot levels 1-10, manual display,
-- slot locks and Auto-Display. A displayed relic stays in the inventory; the pedestal only points
-- at it by Uid, so swapping never loses an item.
--
-- Client intents arrive on ShrineAction (action name + arguments); every argument is validated and
-- every handler is synchronous, so rapid clicks are processed one at a time against current CE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local PedestalVisuals = require(script.Parent.Parent.World.PedestalVisuals)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineState = Remotes:WaitForChild("ShrineState") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local PedestalService = {}

local settings = Config.Economy

-- slot -> displayed inventory item (same table as in data.Inventory).
local displayed: { [Player]: { [number]: any } } = {}

local function relicIncome(item: any): number
	local relic = RelicConfig.ById[item.Id]
	if not relic then
		return 0
	end
	local mutation = item.Mutation and MutationConfig.ById[item.Mutation]
	return Economy.relicIncome(settings, relic.Tier, if mutation then mutation.IncomeMultiplier else 1)
end
PedestalService.RelicIncome = relicIncome

local function multiplier(pedestal: any): number
	return Economy.pedestalMultiplier(settings, pedestal.Level)
end

local function fail(player: Player, text: string)
	Notify:FireClient(player, text, "Error")
end

-- Repairs saved pedestal data and resolves displayed Uids (after load or a data reset).
local function rebuild(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	while #data.Pedestals < Config.Plots.StartingPedestals do
		table.insert(data.Pedestals, { Level = 1, Locked = false })
	end
	while #data.Pedestals > Config.Plots.MaxPedestals do
		table.remove(data.Pedestals)
	end

	local byUid = {}
	for _, item in data.Inventory do
		byUid[item.Uid] = item
	end
	local cache = {}
	local used = {}
	for slot, pedestal in data.Pedestals do
		pedestal.Level = math.clamp(math.floor(tonumber(pedestal.Level) or 1), 1, settings.PedestalMaxLevel)
		pedestal.Locked = pedestal.Locked == true
		local item = pedestal.Uid and byUid[pedestal.Uid]
		if item and not used[item.Uid] then
			cache[slot] = item
			used[item.Uid] = true
		else
			pedestal.Uid = nil
		end
	end
	displayed[player] = cache
end

function PedestalService.Contributions(player: Player): { number }
	local data = DataService.Get(player)
	local cache = displayed[player]
	local list = {}
	if not data or not cache then
		return list
	end
	for slot, pedestal in data.Pedestals do
		local item = cache[slot]
		if item then
			table.insert(list, relicIncome(item) * multiplier(pedestal))
		end
	end
	return list
end

function PedestalService.IsDisplayed(player: Player, uid: number): boolean
	for _, item in displayed[player] or {} do
		if item.Uid == uid then
			return true
		end
	end
	return false
end

function PedestalService.Snapshot(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	local cache = displayed[player]
	if not data or not cache then
		return nil
	end
	local slots = {}
	for slot = 1, Config.Plots.MaxPedestals do
		local pedestal = data.Pedestals[slot]
		if pedestal then
			local item = cache[slot]
			local mult = multiplier(pedestal)
			table.insert(slots, {
				Slot = slot,
				Owned = true,
				Level = pedestal.Level,
				Locked = pedestal.Locked,
				Multiplier = mult,
				Id = item and item.Id,
				Mutation = item and item.Mutation,
				IncomePerMin = if item then relicIncome(item) * mult else 0,
				UpgradeCost = if pedestal.Level < settings.PedestalMaxLevel
					then Economy.upgradeCost(settings, pedestal.Level)
					else nil,
			})
		else
			table.insert(slots, {
				Slot = slot,
				Owned = false,
				Price = settings.SlotPrices[slot],
				IsNext = slot == #data.Pedestals + 1,
			})
		end
	end
	return {
		Slots = slots,
		AutoDisplay = data.Settings.AutoDisplay,
		IncomePerMin = EconomyService.GetIncomePerMin(player),
		IncomeMultiplier = MultiplierService.Get(player, "Income"),
	}
end

-- Sends the new state to the owner, updates the physical shrine and the income attribute.
function PedestalService.Refresh(player: Player)
	local snapshot = PedestalService.Snapshot(player)
	if not snapshot then
		return
	end
	ShrineState:FireClient(player, snapshot)
	PedestalVisuals.Apply(PlotService.GetPlot(player), snapshot.Slots)
	EconomyService.Mirror(player)
end

local function setDisplay(player: Player, slot: number, item: any?)
	local data = DataService.Get(player) :: any
	data.Pedestals[slot].Uid = if item then item.Uid else nil
	displayed[player][slot] = item
end

-- Auto-Display (GDD 6.4, 9.3): put each item where it raises CE/min the most. A displaced relic
-- goes back to the inventory and is itself re-checked against the remaining slots. Locked slots
-- are never touched. Returns true if anything moved.
local function autoPlace(player: Player, items: { any }): boolean
	local data = DataService.Get(player)
	local cache = displayed[player]
	if not data or not cache then
		return false
	end
	local changed = false
	for _, newItem in items do
		local candidate = newItem
		local filled = {}
		for _ = 1, #data.Pedestals do
			local views = {}
			for slot, pedestal in data.Pedestals do
				local current = cache[slot]
				views[slot] = {
					Locked = pedestal.Locked or filled[slot] == true,
					Income = if current then relicIncome(current) else 0,
					Multiplier = multiplier(pedestal),
				}
			end
			local slot = Economy.bestDisplaySlot(views, relicIncome(candidate))
			if not slot then
				break
			end
			local displaced = cache[slot]
			setDisplay(player, slot, candidate)
			filled[slot] = true
			changed = true
			if not displaced then
				break
			end
			candidate = displaced
		end
	end
	return changed
end

-- Pipeline stage: considers freshly granted items. Returns the set of their Uids now displayed.
function PedestalService.AutoDisplayNew(player: Player, items: { any }): { [number]: boolean }
	local data = DataService.Get(player)
	local shown = {}
	if not data or not data.Settings.AutoDisplay then
		return shown
	end
	if autoPlace(player, items) then
		PedestalService.Refresh(player)
	end
	for _, item in displayed[player] or {} do
		shown[item.Uid] = true
	end
	return shown
end

-- Best undisplayed inventory items first (used when a slot is bought or Auto-Display is turned on).
local function autoFillFromInventory(player: Player)
	local data = DataService.Get(player)
	if not data or not data.Settings.AutoDisplay then
		return
	end
	local candidates = {}
	for _, item in data.Inventory do
		if not PedestalService.IsDisplayed(player, item.Uid) then
			table.insert(candidates, item)
		end
	end
	table.sort(candidates, function(a, b)
		return relicIncome(a) > relicIncome(b)
	end)
	local top = {}
	for index = 1, math.min(#candidates, #data.Pedestals) do
		top[index] = candidates[index]
	end
	autoPlace(player, top)
end

local function validSlot(data: any, slot: any): number?
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > #data.Pedestals then
		return nil
	end
	return slot
end

local ACTIONS: { [string]: (Player, any, ...any) -> () } = {
	BuyPedestal = function(player, data)
		local slot = #data.Pedestals + 1
		local price = settings.SlotPrices[slot]
		if slot > Config.Plots.MaxPedestals or not price then
			fail(player, "All pedestal slots are already unlocked.")
			return
		end
		if not EconomyService.TrySpend(player, price) then
			fail(player, `Pedestal {slot} costs {Format.number(price)} CE.`)
			return
		end
		table.insert(data.Pedestals, { Level = 1, Locked = false })
		autoFillFromInventory(player)
		DataService.RequestSave(player)
	end,

	Upgrade = function(player, data, slotArg, mode)
		local slot = validSlot(data, slotArg)
		if not slot or (mode ~= "One" and mode ~= "Max") then
			return
		end
		local pedestal = data.Pedestals[slot]
		if pedestal.Level >= settings.PedestalMaxLevel then
			fail(player, "This pedestal is already at max level.")
			return
		end
		local levels, cost
		if mode == "One" then
			levels, cost = 1, Economy.upgradeCost(settings, pedestal.Level)
		else
			levels, cost = Economy.maxAffordableUpgrades(settings, pedestal.Level, data.CE)
		end
		if levels <= 0 or not EconomyService.TrySpend(player, cost) then
			fail(player, `Next level costs {Format.number(Economy.upgradeCost(settings, pedestal.Level))} CE.`)
			return
		end
		pedestal.Level += levels
	end,

	DisplayGroup = function(player, data, slotArg, relicId, mutationId)
		local slot = validSlot(data, slotArg)
		if not slot or type(relicId) ~= "string" or not RelicConfig.ById[relicId] then
			return
		end
		if mutationId ~= nil and (type(mutationId) ~= "string" or not MutationConfig.ById[mutationId]) then
			return
		end
		for _, item in data.Inventory do
			if item.Id == relicId and item.Mutation == mutationId and not PedestalService.IsDisplayed(player, item.Uid) then
				setDisplay(player, slot, item)
				return
			end
		end
		fail(player, "You have no spare copy of that relic.")
	end,

	Clear = function(player, data, slotArg)
		local slot = validSlot(data, slotArg)
		if slot then
			setDisplay(player, slot, nil)
		end
	end,

	Lock = function(_player, data, slotArg, locked)
		local slot = validSlot(data, slotArg)
		if slot and type(locked) == "boolean" then
			data.Pedestals[slot].Locked = locked
		end
	end,

	AutoDisplay = function(player, data, enabled)
		if type(enabled) ~= "boolean" then
			return
		end
		data.Settings.AutoDisplay = enabled
		if enabled then
			autoFillFromInventory(player)
		end
	end,
}

local function onAction(player: Player, action: any, ...: any)
	local data = DataService.Get(player)
	local handler = type(action) == "string" and ACTIONS[action]
	if not data or not displayed[player] or not handler then
		return
	end
	handler(player, data, ...)
	PedestalService.Refresh(player)
end

function PedestalService.Init()
	EconomyService.SetIncomeProvider(PedestalService.Contributions)
	RemoteGuard.Event(ShrineAction, onAction, "Shrine")

	DataService.OnPlayerLoaded(function(player)
		rebuild(player)
		PedestalService.Refresh(player)
	end)
	GameEvents.On("DataReset", function(player: Player)
		rebuild(player)
		PedestalService.Refresh(player)
	end)
	GameEvents.On("PlotAssigned", function(player: Player)
		PedestalService.Refresh(player)
	end)
	GameEvents.On("MultipliersChanged", function(player: Player)
		PedestalService.Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		displayed[player] = nil
	end)
end

-- Debug: set a pedestal's level directly.
function PedestalService.SetLevel(player: Player, slot: number, level: number): boolean
	local data = DataService.Get(player)
	if not data or not validSlot(data, slot) then
		return false
	end
	data.Pedestals[slot].Level = math.clamp(math.floor(level), 1, settings.PedestalMaxLevel)
	PedestalService.Refresh(player)
	return true
end

return PedestalService
