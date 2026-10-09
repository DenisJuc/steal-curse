-- Other players' hunts, drawn cosmetically on this client (GDD 4.2: others may see the chains,
-- never your signals). Driven by replicated attributes from BindService: BindTarget (a neutral
-- spirit with chains and the raised arm while they bind) and SealAt/SealPosition/SealRelic (the
-- seal flash and the captured relic's family animation flying into them). Within range only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CaptureAnimation = require(script.Parent.CaptureAnimation)
local ChainRig = require(script.Parent.ChainRig)
local Settings = require(script.Parent.Parent.Settings)

local OtherBinds = {}

local SPIRIT_COLOR = Color3.fromRGB(200, 190, 230)
local CHAIN_COLOR = Color3.fromRGB(190, 150, 255)
-- Seals older than this (e.g. set before we joined) are not replayed.
local SEAL_MAX_AGE = 3

type Watched = {
	Orb: Part?,
	Rig: ChainRig.Rig?,
	Connections: { RBXScriptConnection },
}

local watched: { [Player]: Watched } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inRange(position: Vector3): boolean
	local mine = rootOf(Players.LocalPlayer)
	return mine ~= nil and (mine.Position - position).Magnitude <= Config.Hunt.OthersVisibleRange
end

local function clearBind(entry: Watched)
	if entry.Rig then
		entry.Rig.Restore()
		entry.Rig = nil
	end
	if entry.Orb then
		entry.Orb:Destroy()
		entry.Orb = nil
	end
end

local function makeSpirit(position: Vector3): Part
	local orb = Instance.new("Part")
	orb.Name = "OtherBindSpirit"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.2, 2.2, 2.2)
	orb.Material = Enum.Material.Neon
	orb.Color = SPIRIT_COLOR
	orb.Transparency = 0.35
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.CastShadow = false
	orb.CFrame = CFrame.new(position)
	local core = Instance.new("Attachment")
	core.Name = "Core"
	core.Parent = orb
	orb.Parent = workspace
	return orb
end

local function onBindTarget(player: Player, entry: Watched)
	clearBind(entry)
	local target = player:GetAttribute("BindTarget")
	local character = player.Character
	if typeof(target) ~= "Vector3" or not character or not inRange(target) then
		return
	end
	local orb = makeSpirit(target)
	entry.Orb = orb
	entry.Rig = ChainRig.Attach(character, orb:FindFirstChild("Core") :: Attachment, CHAIN_COLOR, 2)
end

local function onSeal(player: Player)
	local at = player:GetAttribute("SealAt")
	local position = player:GetAttribute("SealPosition")
	local relic = player:GetAttribute("SealRelic")
	local root = rootOf(player)
	if type(at) ~= "number" or typeof(position) ~= "Vector3" or type(relic) ~= "string" or not root then
		return
	end
	if workspace:GetServerTimeNow() - at > SEAL_MAX_AGE or not inRange(position) then
		return
	end
	local relicId, mutation = string.match(relic, "^([^|]+)|(.*)$")
	if not relicId then
		return
	end
	local low = Settings.LowEffects()
	if not low then
		ChainRig.SealFlash(position)
	end
	CaptureAnimation.Play(relicId, if mutation ~= "" then mutation else nil, position, root, { Low = low, Sound = false })
end

local function watch(player: Player)
	if player == Players.LocalPlayer or watched[player] then
		return
	end
	local entry: Watched = { Orb = nil, Rig = nil, Connections = {} }
	watched[player] = entry
	table.insert(entry.Connections, player:GetAttributeChangedSignal("BindTarget"):Connect(function()
		onBindTarget(player, entry)
	end))
	table.insert(entry.Connections, player:GetAttributeChangedSignal("SealAt"):Connect(function()
		onSeal(player)
	end))
	table.insert(entry.Connections, player.CharacterRemoving:Connect(function()
		clearBind(entry)
	end))
end

local function unwatch(player: Player)
	local entry = watched[player]
	if not entry then
		return
	end
	watched[player] = nil
	clearBind(entry)
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
end

function OtherBinds.Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(unwatch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	-- The spirit resists like the owner's view does, and chains writhe.
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		for player, entry in watched do
			local orb = entry.Orb
			local target = player:GetAttribute("BindTarget")
			if orb and typeof(target) == "Vector3" then
				local shake = 0.25
				orb.CFrame = CFrame.new(target + Vector3.new(math.sin(clock * 31) * shake, math.sin(clock * 23) * shake, 0))
			end
			if entry.Rig then
				ChainRig.Update(entry.Rig, clock, 0.4)
			end
		end
	end)
end

return OtherBinds
