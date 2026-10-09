-- Shrine pedestals (GDD 6.3, 6.4): buy slots 4-6 with CE, per-slot levels 1-10, manual display,
-- slot locks and Equip Best. New finds are never placed automatically: pedestals only change
-- when the player picks a relic or presses Equip Best. A displayed relic stays in the inventory;
-- the pedestal only points at it by Uid, so swapping never loses an item.
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

-- Equip Best (GDD 6.4): fills every unlocked pedestal with the best relics the player holds,
-- best relic on the highest-level pedestal. Locked pedestals and their relics are never touched.
-- Returns the CE/min gained.
function PedestalService.EquipBest(player: Player): number
	local data = DataService.Get(player)
	local cache = displayed[player]
	if not data or not cache then
		return 0
	end
	local before = EconomyService.GetIncomePerMin(player)
	local views, lockedUids = {}, {}
	for slot, pedestal in data.Pedestals do
		views[slot] = { Locked = pedestal.Locked, Multiplier = multiplier(pedestal) }
		if pedestal.Locked and cache[slot] then
			lockedUids[cache[slot].Uid] = true
		end
	end
	local candidates, byUid = {}, {}
	for _, item in data.Inventory do
		if not lockedUids[item.Uid] then
			byUid[item.Uid] = item
			table.insert(candidates, {
				Key = item.Uid,
				Income = relicIncome(item),
				Shown = PedestalService.IsDisplayed(player, item.Uid),
			})
		end
	end
	local plan = Economy.equipBest(views, candidates)
	for slot, pedestal in data.Pedestals do
		if not pedestal.Locked then
			local uid = plan[slot]
			setDisplay(player, slot, if uid then byUid[uid] else nil)
		end
	end
	return EconomyService.GetIncomePerMin(player) - before
end

local function validSlot(data: any, slot: any): number?
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > #data.Pedestals then
		return nil
	end
	return slot
end

local function validGroup(relicId: any, mutationId: any): boolean
	if type(relicId) ~= "string" or not RelicConfig.ById[relicId] then
		return false
	end
	return mutationId == nil or (type(mutationId) == "string" and MutationConfig.ById[mutationId] ~= nil)
end

local function spareCopy(player: Player, data: any, relicId: string, mutationId: string?): any?
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation == mutationId and not PedestalService.IsDisplayed(player, item.Uid) then
			return item
		end
	end
	return nil
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
		if not slot or not validGroup(relicId, mutationId) then
			return
		end
		local item = spareCopy(player, data, relicId, mutationId)
		if item then
			setDisplay(player, slot, item)
		else
			fail(player, "You have no spare copy of that relic.")
		end
	end,

	-- From the Relics menu: one spare copy goes on the unlocked pedestal where it adds the most CE/min.
	EquipGroup = function(player, data, relicId, mutationId)
		if not validGroup(relicId, mutationId) then
			return
		end
		local item = spareCopy(player, data, relicId, mutationId)
		if not item then
			fail(player, "Every copy of that relic is already on a pedestal.")
			return
		end
		local cache = displayed[player]
		local views = {}
		for slot, pedestal in data.Pedestals do
			local current = cache[slot]
			views[slot] = {
				Locked = pedestal.Locked,
				Income = if current then relicIncome(current) else 0,
				Multiplier = multiplier(pedestal),
			}
		end
		local slot, gain = Economy.bestDisplaySlot(views, relicIncome(item))
		if not slot then
			fail(player, "Your unlocked pedestals already hold better relics. Use Choose in the Shrine to place it anyway.")
			return
		end
		setDisplay(player, slot, item)
		Notify:FireClient(player, `Placed on pedestal {slot}: +{Format.number(gain)} CE/min`)
	end,

	UnequipGroup = function(player, data, relicId, mutationId)
		if not validGroup(relicId, mutationId) then
			return
		end
		local cache = displayed[player]
		local lockedLeft = 0
		for slot, pedestal in data.Pedestals do
			local item = cache[slot]
			if item and item.Id == relicId and item.Mutation == mutationId then
				if pedestal.Locked then
					lockedLeft += 1
				else
					setDisplay(player, slot, nil)
				end
			end
		end
		if lockedLeft > 0 then
			fail(player, `{lockedLeft} cop{if lockedLeft == 1 then "y is" else "ies are"} on a locked pedestal. Unlock it in the Shrine first.`)
		end
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

	EquipBest = function(player, _data)
		local gained = PedestalService.EquipBest(player)
		if gained > 1e-9 then
			Notify:FireClient(player, `Equipped your best relics: +{Format.number(gained)} CE/min`)
		else
			Notify:FireClient(player, "Your best relics are already equipped.")
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
