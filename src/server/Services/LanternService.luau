-- Spirit lantern colours (Config.Lanterns). Other services Grant them (zone mastery, purified
-- zones, Sacred Offerings); the player picks one at the Spirit Wardrobe (SetLantern remote).
-- Mirrored as:
--   Lantern          the active lantern id (on the player, so every client colours it)
--   LanternsOwned    owned ids joined with "," (for the Wardrobe picker)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetLantern = Remotes:WaitForChild("SetLantern") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local LanternService = {}

local byId: { [string]: { Id: string, Name: string, Color: { number } } } = {}
for _, lantern in Config.Lanterns.List do
	byId[lantern.Id] = lantern
end

function LanternService.NameOf(id: string): string
	local lantern = byId[id]
	return if lantern then lantern.Name else id
end

function LanternService.Mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local owned = { Config.Lanterns.Default }
	for _, lantern in Config.Lanterns.List do
		if data.Lanterns.Owned[lantern.Id] and lantern.Id ~= Config.Lanterns.Default then
			table.insert(owned, lantern.Id)
		end
	end
	local active = data.Lanterns.Active
	player:SetAttribute("Lantern", if byId[active] then active else Config.Lanterns.Default)
	player:SetAttribute("LanternsOwned", table.concat(owned, ","))
end

function LanternService.Owns(player: Player, id: string): boolean
	local data = DataService.Get(player)
	return id == Config.Lanterns.Default or (data ~= nil and data.Lanterns.Owned[id] ~= nil)
end

-- Unlocks a lantern colour. Returns true if it was new.
function LanternService.Grant(player: Player, id: string, reason: string?): boolean
	local data = DataService.Get(player)
	if not data or not byId[id] or LanternService.Owns(player, id) then
		return false
	end
	data.Lanterns.Owned[id] = os.time()
	LanternService.Mirror(player)
	DataService.RequestSave(player)
	Notify:FireClient(
		player,
		`New lantern colour: {byId[id].Name}{if reason then ` ({reason})` else ""} - pick it at the Spirit Wardrobe in town`,
		"Item"
	)
	return true
end

local function onSet(player: Player, id: any)
	local data = DataService.Get(player)
	if not data or type(id) ~= "string" or not byId[id] or not LanternService.Owns(player, id) then
		return
	end
	data.Lanterns.Active = id
	LanternService.Mirror(player)
	DataService.RequestSave(player)
end

function LanternService.Init()
	RemoteGuard.Event(SetLantern, onSet, "Settings")
	DataService.OnPlayerLoaded(LanternService.Mirror)
	GameEvents.On("DataReset", LanternService.Mirror)
end

return LanternService
