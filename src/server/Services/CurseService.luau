-- Lift the Curse (Config.Curse, Curse module): cleanse each Cursed Shrine once by holding
-- HoldSeconds next to it. The server times the hold itself (ShrineAction "Begin" / "Cancel" /
-- "Complete"), cancels it when you walk off or start binding, then pays CE, a potion and the
-- shrine's lore page (ShrineResult). Purifying every shrine of a zone gives its title, lantern and
-- bonus. Mirrored on the player:
--   Cleansed             cleansed shrine ids joined with ","
--   CurseLifted_<area>   0..1 share of that zone's shrines cleansed (client fog)
--   CleanseShrine        shrine being cleansed (nil when none), CleanseStartedAt its server start

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Curse = require(ReplicatedStorage.Shared.Curse)
local Format = require(ReplicatedStorage.Shared.Format)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local ItemService = require(script.Parent.ItemService)
local LanternService = require(script.Parent.LanternService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local TitleService = require(script.Parent.TitleService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineResult = Remotes:WaitForChild("ShrineResult") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local CurseService = {}

local OPTIONS = Config.Curse :: Curse.Options
local SHRINES = WildLayout.CursedShrines
-- Seconds early a Complete may arrive (network jitter) and studs of range slack.
local TOLERANCE = 0.4
local RANGE_SLACK = 4

type Hold = { Id: string, Started: number }
local holds: { [Player]: Hold } = {}
local rngs: { [Player]: Random } = {}

local areaNames: { [string]: string } = {}
for _, area in Config.Areas do
	areaNames[area.Id] = area.Name
end

local function shrinePosition(id: string): Vector3?
	local shrine = WildLayout.ShrineById[id]
	if not shrine then
		return nil
	end
	local x, z = WildLayout.shrinePosition(shrine)
	return Vector3.new(x, 0, z)
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return nil
	end
	return root.Position
end

local function inRange(player: Player, id: string): boolean
	local position = rootPosition(player)
	local shrine = shrinePosition(id)
	if not position or not shrine then
		return false
	end
	local flat = Vector2.new(position.X - shrine.X, position.Z - shrine.Z)
	return flat.Magnitude <= Config.Curse.Range + RANGE_SLACK
end

local function reply(player: Player, payload: { [string]: any })
	ShrineResult:FireClient(player, payload)
end

local function setHold(player: Player, hold: Hold?)
	holds[player] = hold
	player:SetAttribute("CleanseShrine", if hold then hold.Id else nil)
	player:SetAttribute("CleanseStartedAt", if hold then workspace:GetServerTimeNow() else nil)
end

function CurseService.Mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ids = {}
	for _, shrine in SHRINES do
		if data.Cleansed[shrine.Id] then
			table.insert(ids, shrine.Id)
		end
	end
	player:SetAttribute("Cleansed", table.concat(ids, ","))
	for _, area in Config.Areas do
		local lifted = Curse.lifted(data.Cleansed, SHRINES, area.Id)
		player:SetAttribute(`CurseLifted_{area.Id}`, if lifted > 0 then lifted else nil)
	end
end

function CurseService.IsCleansed(player: Player, id: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Cleansed[id] ~= nil
end

-- Bonus-roll factor for captures in `area` (purified zones).
function CurseService.ZoneFactor(player: Player, area: string): number
	local data = DataService.Get(player)
	return if data then Curse.bonus(data.Cleansed, SHRINES, area, OPTIONS) else 1
end

-- Marks a shrine cleansed and pays it out. Returns the reward text, or nil if it was already done.
function CurseService.Cleanse(player: Player, id: string): string?
	local data = DataService.Get(player)
	local shrine = WildLayout.ShrineById[id]
	if not data or not shrine or data.Cleansed[id] then
		return nil
	end
	local rng = rngs[player] or Random.new()
	rngs[player] = rng
	data.Cleansed[id] = os.time()
	local amount = Curse.ceReward(EconomyService.GetIncomePerSec(player), OPTIONS)
	EconomyService.Add(player, amount)
	local potions = Config.Curse.Potions
	local potion = potions[rng:NextInteger(1, #potions)]
	ItemService.Grant(player, { [potion] = 1 }, "Cursed Shrine")
	local done, total = Curse.progress(data.Cleansed, SHRINES, shrine.Area)
	local text = `+{Format.ce(amount)} CE, a potion and a lore page. {areaNames[shrine.Area]} curse lifted {done}/{total}.`
	if done == total then
		local zone = Config.Curse.Zones[shrine.Area]
		Notify:FireClient(player, `{areaNames[shrine.Area]} is purified! New title: {zone.Title}`, "Item")
		LanternService.Grant(player, zone.Lantern, `{areaNames[shrine.Area]} purified`)
		TitleService.Refresh(player)
	end
	CurseService.Mirror(player)
	DataService.RequestSave(player)
	GameEvents.Fire("ShrineCleansed", player, id, shrine.Area)
	return text
end

-- Debug: forget cleansed shrines (all, or one area's).
function CurseService.Reset(player: Player, area: string?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for _, shrine in SHRINES do
		if not area or shrine.Area == area then
			data.Cleansed[shrine.Id] = nil
		end
	end
	CurseService.Mirror(player)
	TitleService.Refresh(player)
	DataService.RequestSave(player)
end

local function onAction(player: Player, action: any, id: any)
	if type(id) ~= "string" or not WildLayout.ShrineById[id] then
		return
	end
	if action == "Begin" then
		if holds[player] or player:GetAttribute("BindSignalId") ~= nil then
			reply(player, { Ok = false, Id = id, Reason = "Busy" })
		elseif CurseService.IsCleansed(player, id) then
			reply(player, { Ok = false, Id = id, Reason = "Done" })
		elseif not inRange(player, id) then
			reply(player, { Ok = false, Id = id, Reason = "TooFar" })
		else
			setHold(player, { Id = id, Started = os.clock() })
		end
	elseif action == "Cancel" then
		local hold = holds[player]
		if hold and hold.Id == id then
			setHold(player, nil)
			reply(player, { Ok = false, Id = id, Reason = "Released" })
		end
	elseif action == "Complete" then
		local hold = holds[player]
		if not hold or hold.Id ~= id then
			reply(player, { Ok = false, Id = id, Reason = "NotHolding" })
			return
		end
		if os.clock() - hold.Started < Config.Curse.HoldSeconds - TOLERANCE then
			reply(player, { Ok = false, Id = id, Reason = "TooEarly" })
			return
		end
		setHold(player, nil)
		if not inRange(player, id) then
			reply(player, { Ok = false, Id = id, Reason = "TooFar" })
			return
		end
		local text = CurseService.Cleanse(player, id)
		if text then
			reply(player, { Ok = true, Id = id, Text = text, Lore = Config.Curse.Lore[id] })
		else
			reply(player, { Ok = false, Id = id, Reason = "Done" })
		end
	end
end

function CurseService.Init()
	RemoteGuard.Event(ShrineAction, onAction, "Cleanse")
	DataService.OnPlayerLoaded(CurseService.Mirror)
	GameEvents.On("DataReset", CurseService.Mirror)
	Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
		rngs[player] = nil
	end)

	-- Walking off, dying, starting a bind or never finishing cancels the hold.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, hold in holds do
				local reason = nil
				if not inRange(player, hold.Id) then
					reason = "TooFar"
				elseif player:GetAttribute("BindSignalId") ~= nil then
					reason = "Interrupted"
				elseif os.clock() - hold.Started > Config.Curse.HoldSeconds + 3 then
					reason = "Timeout"
				end
				if reason then
					setHold(player, nil)
					reply(player, { Ok = false, Id = hold.Id, Reason = reason })
				end
			end
		end
	end)
end

return CurseService
