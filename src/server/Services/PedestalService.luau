-- Shrine pedestals (GDD 6.3, 6.4): buy slots 4-6 with CE, per-slot levels, manual display,
-- slot locks and Equip Best (a free button). Auto-equip is the "AutoEquip" game pass: with the pass
-- and the toggle on (Settings.AutoEquip, off by default, switched on when the pass is bought) Equip
-- Best also runs after new finds (DiscoveryPipeline), slot purchases and upgrades; locked pedestals
-- keep their relic, which is how a player keeps a hand-placed one. A displayed relic stays in the
-- inventory; the pedestal only points at it by Uid, so swapping never loses an item. It is not in
-- the backpack, though (InventoryService hides it, and it uses no backpack slot).
-- "Grab" (hold E on a pedestal) takes its relic off: it floats beside the player and goes back to
-- the backpack (CosmeticEquipService). On an empty pedestal it places the floating relic; on a full
-- one while something floats, it swaps them. Floating relics are skipped by Equip Best.
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
local RelicIncome = require(ReplicatedStorage.Shared.RelicIncome)
local CosmeticEquipService = require(script.Parent.CosmeticEquipService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local GamePassService = require(script.Parent.GamePassService)
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
	return RelicIncome.of(item.Id, item.Mutation)
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
				IncomePerSec = if item then relicIncome(item) * mult else 0,
				MaxLevel = settings.PedestalMaxLevel,
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
		IncomePerSec = EconomyService.GetIncomePerSec(player),
		IncomeMultiplier = EconomyService.GetIncomeMultiplier(player),
		AutoEquip = PedestalService.AutoEquipOn(player),
		AutoEquipOwned = GamePassService.Owns(player, "AutoEquip"),
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
	DataService.MirrorAttributes(player)
end

-- Placing the floating copy on a pedestal ends its float.
local function setDisplay(player: Player, slot: number, item: any?)
	local data = DataService.Get(player) :: any
	data.Pedestals[slot].Uid = if item then item.Uid else nil
	displayed[player][slot] = item
	if item and CosmeticEquipService.IsFloating(player, item.Uid) then
		CosmeticEquipService.Stop(player)
	end
end

-- Equip Best (GDD 6.4): fills every unlocked pedestal with the best relics the player holds,
-- best relic on the highest-level pedestal. Locked pedestals and their relics are never touched.
-- Returns the CE/sec gained.
function PedestalService.EquipBest(player: Player): number
	local data = DataService.Get(player)
	local cache = displayed[player]
	if not data or not cache then
		return 0
	end
	local before = EconomyService.GetIncomePerSec(player)
	local views, lockedUids = {}, {}
	for slot, pedestal in data.Pedestals do
		views[slot] = { Locked = pedestal.Locked, Multiplier = multiplier(pedestal) }
		if pedestal.Locked and cache[slot] then
			lockedUids[cache[slot].Uid] = true
		end
	end
	local candidates, byUid = {}, {}
	for _, item in data.Inventory do
		if not lockedUids[item.Uid] and not CosmeticEquipService.IsFloating(player, item.Uid) then
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
	return EconomyService.GetIncomePerSec(player) - before
end

function PedestalService.AutoEquipOn(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Settings.AutoEquip == true and GamePassService.Owns(player, "AutoEquip")
end

-- Equip Best when Auto-equip is on. Returns the CE/sec gained (0 when off).
function PedestalService.AutoEquip(player: Player): number
	if not PedestalService.AutoEquipOn(player) then
		return 0
	end
	return PedestalService.EquipBest(player)
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

-- A backpack copy of a relic + mutation, preferring one that isn't floating.
local function spareCopy(player: Player, data: any, relicId: string, mutationId: string?): any?
	local floating = nil
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation == mutationId and not PedestalService.IsDisplayed(player, item.Uid) then
			if not CosmeticEquipService.IsFloating(player, item.Uid) then
				return item
			end
			floating = item
		end
	end
	return floating
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
		PedestalService.AutoEquip(player)
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
		PedestalService.AutoEquip(player)
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

	-- From the Relics menu: one spare copy goes on the unlocked pedestal where it adds the most CE/sec.
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
		Notify:FireClient(player, `Placed on pedestal {slot}: +{Format.number(gain)} CE/sec`)
	end,

	-- Hold E on a pedestal: take its relic (it floats and goes back to the backpack), place the
	-- floating relic on an empty pedestal, or swap the two.
	Grab = function(player, data, slotArg)
		local slot = validSlot(data, slotArg)
		if not slot then
			return
		end
		local pedestal = data.Pedestals[slot]
		local current = displayed[player][slot]
		local floating = CosmeticEquipService.FloatingItem(player)
		if not current and not floating then
			fail(player, "Nothing to place. Float a relic from your Backpack first.")
			return
		end
		local before = if current then relicIncome(current) * multiplier(pedestal) else 0
		setDisplay(player, slot, floating)
		if current then
			CosmeticEquipService.Float(player, current.Uid)
		end
		local after = if floating then relicIncome(floating) * multiplier(pedestal) else 0
		local change = after - before
		local rate = `{if change >= 0 then "+" else "-"}{Format.number(math.abs(change))} CE/sec`
		if current and floating then
			Notify:FireClient(player, `Swapped in {CosmeticEquipService.DisplayName(floating)}: {rate}`)
		elseif current then
			Notify:FireClient(
				player,
				`Took {CosmeticEquipService.DisplayName(current)} ({rate}). Hold E on an empty pedestal to place it.`
			)
		elseif floating then
			Notify:FireClient(player, `Placed {CosmeticEquipService.DisplayName(floating)}: {rate}`)
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
			Notify:FireClient(player, `Equipped your best relics: +{Format.number(gained)} CE/sec`)
		else
			Notify:FireClient(player, "Your best relics are already equipped.")
		end
	end,

	SetAutoEquip = function(player, data, on)
		if type(on) ~= "boolean" then
			return
		end
		if on and not GamePassService.Owns(player, "AutoEquip") then
			fail(player, "Auto-equip is part of the Auto-equip game pass. Equip Best is free.")
			return
		end
		data.Settings.AutoEquip = on
		if on then
			PedestalService.EquipBest(player)
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
		PedestalService.AutoEquip(player)
		PedestalService.Refresh(player)
	end)
	GameEvents.On("DataReset", function(player: Player)
		rebuild(player)
		PedestalService.Refresh(player)
	end)
	GameEvents.On("Rebirthed", function(player: Player)
		PedestalService.AutoEquip(player)
		PedestalService.Refresh(player)
	end)
	GameEvents.On("PlotAssigned", function(player: Player)
		PedestalService.Refresh(player)
	end)
	-- Buying the pass switches Auto-equip on straight away.
	GameEvents.On("GamePassChanged", function(player: Player, name: string, on: boolean)
		local data = DataService.Get(player)
		if name ~= "AutoEquip" or not data or not displayed[player] then
			return
		end
		if on then
			data.Settings.AutoEquip = true
			PedestalService.AutoEquip(player)
		end
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
