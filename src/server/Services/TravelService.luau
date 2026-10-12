-- Home / Hub / Wild quick travel. The client only names a destination; the server picks the spot,
-- applies the cooldown and refuses while a bind is in progress (a capture must be walked to).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Teleport = Remotes:WaitForChild("Teleport") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local TravelService = {}

local lastTravel: { [Player]: number } = {}

local function groundAt(x: number, z: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local ray = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -500, 0), params)
	return if ray then ray.Position.Y else 0
end

local function destination(player: Player, character: Model, root: BasePart, where: string): (CFrame?, string?)
	if where == "Home" then
		local home = PlotService.HomeCFrame(player)
		return home, if home then nil else "You have no shrine yet."
	elseif where == "Hub" then
		local x, z = Config.Travel.HubSpot[1], Config.Travel.HubSpot[2]
		local position = Vector3.new(x, groundAt(x, z, { character }) + 4, z)
		return CFrame.lookAt(position, Vector3.new(0, position.Y, 0)), nil
	elseif where == "Wild" then
		local here = root.Position
		if WorldLayout.inWild(Config.World, here.X, here.Z) then
			return nil, "You are already in the wild."
		end
		local x, z = WorldLayout.wildEntry(Config.World, here.X, here.Z, Config.Travel.WildDepth)
		local position = Vector3.new(x, groundAt(x, z, { character }) + 4, z)
		local outward = Vector3.new(x * 2, position.Y, z * 2)
		return CFrame.lookAt(position, outward), nil
	end
	return nil, nil
end

local function onTeleport(player: Player, where: unknown)
	if where ~= "Home" and where ~= "Hub" and where ~= "Wild" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("BindSignalId") ~= nil then
		Notify:FireClient(player, "Finish or cancel the bind before traveling.", "Error")
		return
	end
	local now = os.clock()
	local last = lastTravel[player]
	if last and now - last < Config.Travel.CooldownSeconds then
		return
	end
	local target, reason = destination(player, character, root, where :: string)
	if not target then
		if reason then
			Notify:FireClient(player, reason, "Error")
		end
		return
	end
	lastTravel[player] = now
	player:SetAttribute("TravelReadyAt", workspace:GetServerTimeNow() + Config.Travel.CooldownSeconds)
	character:PivotTo(target)
end

function TravelService.Init()
	RemoteGuard.Event(Teleport, onTeleport, "Settings")
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
