-- Player data. Slice 0: in-memory only (resets when you stop Play).
-- Slice 2 swaps storage to ProfileStore behind this same API.
-- Displayed stats are mirrored to player attributes so the UI never needs data tables.

local Players = game:GetService("Players")

local DataService = {}

export type Item = {
	Uid: number,
	Id: string,
	At: number,
	Source: string,
}

export type Data = {
	TotalScans: number,
	NextUid: number,
	Inventory: { Item },
}

local TEMPLATE: Data = {
	TotalScans = 0,
	NextUid = 1,
	Inventory = {},
}

local profiles: { [Player]: Data } = {}
local loadedCallbacks: { (Player) -> () } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = deepCopy(inner)
	end
	return copy :: any
end

local function load(player: Player)
	if profiles[player] then
		return
	end
	profiles[player] = deepCopy(TEMPLATE)
	DataService.MirrorAttributes(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

function DataService.Get(player: Player): Data?
	return profiles[player]
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.Increment(player: Player, key: string, amount: number)
	local data = profiles[player] :: any
	if not data then
		return
	end
	data[key] += amount
	DataService.MirrorAttributes(player)
end

function DataService.MirrorAttributes(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("TotalScans", data.TotalScans)
	player:SetAttribute("InventoryCount", #data.Inventory)
end

-- Runs for players already loaded, then for every future load.
function DataService.OnPlayerLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

function DataService.Wipe(player: Player)
	if not profiles[player] then
		return
	end
	profiles[player] = deepCopy(TEMPLATE)
	DataService.MirrorAttributes(player)
end

return DataService
