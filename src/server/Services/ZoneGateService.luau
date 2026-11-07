-- Zone luck gates (Config.ZoneGates, ZoneGates). Server-authoritative: every CheckSeconds each
-- character standing in a locked (area, band) cell is moved to the nearest open spot (no damage;
-- the Forest Edge entrance only when it is far inside, e.g. spawned or teleported there) and gets a
-- "Needs xN LUCK" message. Gate luck = max(Lasting Luck, saved PeakLastingLuck), mirrored as the
-- "GateLuck" attribute; the peak never falls, so a Rebirth never locks a zone again. A Studio
-- /setlastingluck override replaces gate luck and is never written to the peak.
-- Spawners (signals, wild finds, free signals) ask Allowed() so nothing appears where the player
-- may not go. Bounties ask Reachable().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local ZoneGates = require(ReplicatedStorage.Shared.ZoneGates)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)

-- Declared in default.project.json; created here too when a live Rojo session predates it.
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function blockedRemote(): RemoteEvent
	local existing = remotes:FindFirstChild("ZoneGateBlocked")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "ZoneGateBlocked"
	created.Parent = remotes
	return created
end
local Blocked = blockedRemote()

local ZoneGateService = {}

local GATES = Config.ZoneGates
local CONTEXT: ZoneGates.Context = {
	Areas = Config.Areas,
	World = Config.World,
	Bands = Config.HuntStreak,
	Gates = GATES,
}
ZoneGateService.Context = CONTEXT

local areaNames: { [string]: string } = {}
for _, area in Config.Areas do
	areaNames[area.Id] = area.Name
end

local lastMessage: { [Player]: number } = {}

-- Luck the gates check for this player.
function ZoneGateService.Luck(player: Player): number
	local value = player:GetAttribute("GateLuck")
	if type(value) == "number" then
		return value
	end
	return MultiplierService.GetLasting(player)
end

function ZoneGateService.Allowed(player: Player, x: number, z: number): boolean
	return ZoneGates.allowedAt(CONTEXT, ZoneGateService.Luck(player), x, z)
end

-- Nearest open spot in the wild (not the town) to (x, z), for spawners anchoring near a player.
function ZoneGateService.OpenWildNear(player: Player, x: number, z: number): (number, number)
	if ZoneGateService.Allowed(player, x, z) and WorldLayout.inWild(Config.World, x, z) then
		return x, z
	end
	return ZoneGates.nearestAllowed(CONTEXT, ZoneGateService.Luck(player), x, z, 8, true)
end

-- Whether a bounty filter ({ Area = id } / { MinBand = band }) can be done with this player's luck.
function ZoneGateService.Reachable(player: Player, filter: { [string]: any }?): (boolean, number?)
	return ZoneGates.filterReachable(CONTEXT, ZoneGateService.Luck(player), filter)
end

local function refresh(player: Player)
	local lasting = MultiplierService.GetLasting(player)
	local gateLuck = lasting
	if not MultiplierService.HasLastingOverride(player) then
		local data = DataService.Get(player)
		if data then
			data.PeakLastingLuck = ZoneGates.updatePeak(data.PeakLastingLuck, lasting)
			gateLuck = ZoneGates.gateLuck(lasting, data.PeakLastingLuck)
		end
	end
	if player:GetAttribute("GateLuck") ~= gateLuck then
		player:SetAttribute("GateLuck", gateLuck)
	end
end

-- Ground height under (x, z) near `y`, ignoring characters.
local function groundAt(x: number, y: number, z: number, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, y + 60, z), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else nil
end

local function check(player: Player)
	if not GATES.Enabled then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local position = root.Position
	local luck = ZoneGateService.Luck(player)
	if ZoneGates.allowedAt(CONTEXT, luck, position.X, position.Z) then
		return
	end
	local area, band = ZoneGates.cellAt(CONTEXT, position.X, position.Z)
	local x, z = ZoneGates.nearestAllowed(CONTEXT, luck, position.X, position.Z, GATES.PushInside)
	if math.sqrt((x - position.X) ^ 2 + (z - position.Z) ^ 2) > GATES.StuckDistance then
		-- Far inside a locked cell: the Forest Edge entrance.
		x, z = ZoneGateService.OpenWildNear(player, WorldLayout.polar(Config.Areas[1].AngleDegrees, Config.World.WildInner + 20))
	end
	local players = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(players, other.Character)
		end
	end
	local ground = groundAt(x, position.Y, z, players)
	local groundHere = groundAt(position.X, position.Y, position.Z, players)
	local lift = if groundHere then math.max(position.Y - groundHere, 2.5) else 3
	local y = if ground then ground + lift else position.Y
	local look = root.CFrame.LookVector
	local target = Vector3.new(x, y, z)
	assert(character, "character")
	character:PivotTo(CFrame.lookAt(target, target + Vector3.new(look.X, 0, look.Z + 1e-6)))
	root.AssemblyLinearVelocity = Vector3.zero
	local now = os.clock()
	if area and band and now - (lastMessage[player] or 0) >= GATES.MessageGap then
		lastMessage[player] = now
		local required = ZoneGates.required(CONTEXT, area, band)
		Blocked:FireClient(player, {
			Required = required,
			Luck = luck,
			Area = areaNames[area] or area,
			Band = band,
			Text = `needs x{Format.number(required)} LUCK (you: x{Format.number(luck)})`,
		})
	end
end

function ZoneGateService.Init()
	DataService.OnPlayerLoaded(refresh)
	GameEvents.On("MultipliersChanged", refresh)
	Players.PlayerRemoving:Connect(function(player)
		lastMessage[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(GATES.CheckSeconds)
			for _, player in Players:GetPlayers() do
				if DataService.Get(player) then
					check(player)
				end
			end
		end
	end)
end

return ZoneGateService
