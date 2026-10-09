-- Player data on ProfileStore (session-locked, autosaves every 5 minutes, saves on leave and on
-- server shutdown). Rare finds call RequestSave, which merges requests into at most one save
-- per Config.Save.MinSecondsBetweenSaves.
--
-- Crash window: a find made after the last completed save can be lost if the Roblox server
-- crashes hard (no leave/shutdown callback). Priority saves shrink that window for rare finds
-- to roughly MinSecondsBetweenSaves; nothing can close it completely.
--
-- Displayed stats are mirrored to player attributes so the UI never needs data tables.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileStore = require(ServerStorage:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))
local DataTemplate = require(script.Parent.Parent.Data.DataTemplate)
local Migrations = require(script.Parent.Parent.Data.Migrations)

local DataService = {}

export type Item = DataTemplate.Item
export type Data = DataTemplate.Data

type SaveState = {
	LastRequestedAt: number,
	Pending: boolean,
}

local store = ProfileStore.New(Config.Save.StoreName, DataTemplate.Template)
local profiles: { [Player]: any } = {}
local saveStates: { [Player]: SaveState } = {}
local loadedCallbacks: { (Player) -> () } = {}

local function profileKey(player: Player): string
	return `Player_{player.UserId}`
end

local function runLoadedCallbacks(player: Player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

-- Migrate, then fill missing fields. Newer data is left untouched (never downgraded).
function DataService.PrepareProfile(profile: any): Migrations.Outcome
	local outcome = Migrations.run(profile.Data, DataTemplate.Version)
	if outcome ~= "Newer" then
		profile:Reconcile()
	end
	return outcome
end

local function load(player: Player)
	if profiles[player] then
		return
	end
	local profile = store:StartSessionAsync(profileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		-- Another server kept the lock, the player left, or Roblox services are down.
		if player.Parent == Players then
			player:Kick("Your relic data could not be loaded. Please rejoin.")
		end
		return
	end

	if DataService.PrepareProfile(profile) == "Newer" then
		profile:EndSession()
		player:Kick("This server is running an older version of the game. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)

	profile.OnSessionEnd:Connect(function()
		if profiles[player] == profile then
			profiles[player] = nil
			saveStates[player] = nil
			player:Kick("Your relic data was opened on another server. Please rejoin.")
		end
	end)
	profile.OnAfterSave:Connect(function()
		if player.Parent == Players then
			player:SetAttribute("LastSavedAt", workspace:GetServerTimeNow())
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	saveStates[player] = { LastRequestedAt = -math.huge, Pending = false }
	DataService.MirrorAttributes(player)
	runLoadedCallbacks(player)
end

local function release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	saveStates[player] = nil
	if profile then
		profile:EndSession()
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

function DataService.Get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.Increment(player: Player, key: string, amount: number)
	local data = DataService.Get(player) :: any
	if not data then
		return
	end
	data[key] += amount
	DataService.MirrorAttributes(player)
end

function DataService.MirrorAttributes(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local discovered = 0
	for _ in data.Discovered do
		discovered += 1
	end
	player:SetAttribute("TotalScans", data.TotalScans)
	player:SetAttribute("TotalCaptures", data.TotalCaptures)
	player:SetAttribute("InventoryCount", #data.Inventory)
	player:SetAttribute("DiscoveredCount", discovered)
end

-- Runs for players already loaded, then for every future load.
function DataService.OnPlayerLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

-- Asks for a save soon. Requests inside the throttle window merge into one save at its end.
function DataService.RequestSave(player: Player)
	local profile = profiles[player]
	local state = saveStates[player]
	if not profile or not state or state.Pending then
		return
	end
	local delaySeconds = state.LastRequestedAt + Config.Save.MinSecondsBetweenSaves - os.clock()
	state.Pending = true
	task.delay(math.max(0, delaySeconds), function()
		state.Pending = false
		if profiles[player] ~= profile or not profile:IsActive() then
			return
		end
		state.LastRequestedAt = os.clock()
		profile:Save()
	end)
end

function DataService.IsSavePending(player: Player): boolean
	local state = saveStates[player]
	return state ~= nil and state.Pending
end

-- "Access" = real DataStores. Anything else = ProfileStore mock (nothing persists after Stop).
function DataService.GetStoreState(): string
	return ProfileStore.DataStoreState
end

-- Exposes the store for Studio persistence tests (store.Mock never touches real data).
function DataService.GetStore(): any
	return store
end

function DataService.Wipe(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data = DataTemplate.fresh()
	DataService.MirrorAttributes(player)
	DataService.RequestSave(player)
end

return DataService
