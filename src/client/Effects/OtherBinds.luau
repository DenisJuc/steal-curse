-- Other players' hunts, drawn cosmetically on this client (GDD 4.2: others may see the chains,
-- never your signals). Driven by replicated attributes from BindService: BindTarget (a neutral
-- spirit with chains and the seal pose while they bind) and SealAt/SealPosition/SealRelic (the
-- jar seal and the captured relic's family animation flying into them). Within range only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CaptureAnimation = require(script.Parent.CaptureAnimation)
local ChainRig = require(script.Parent.ChainRig)
local HuntFX = require(script.Parent.HuntFX)
local SealBurst = require(script.Parent.SealBurst)
local SealPose = require(script.Parent.SealPose)
local Settings = require(script.Parent.Parent.Settings)

local OtherBinds = {}

local SPIRIT_COLOR = Color3.fromRGB(200, 190, 230)
local CHAIN_COLOR = Color3.fromRGB(190, 150, 255)
-- Seals older than this (e.g. set before we joined) are not replayed.
local SEAL_MAX_AGE = 3
-- Others' binds show a steady mid-bind look (their progress is not replicated).
local SHOWN_PROGRESS = 0.4
local REACH_SECONDS = 0.2

type Watched = {
	Spirit: HuntFX.Core?,
	Rig: ChainRig.Rig?,
	Pose: SealPose.Pose?,
	Clock: number,
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
	if entry.Pose then
		entry.Pose.Restore()
		entry.Pose = nil
	end
	if entry.Spirit then
		entry.Spirit.Part:Destroy()
		entry.Spirit = nil
	end
end

local function onBindTarget(player: Player, entry: Watched)
	clearBind(entry)
	local target = player:GetAttribute("BindTarget")
	local character = player.Character
	if typeof(target) ~= "Vector3" or not character or not inRange(target) then
		return
	end
	local low = Settings.LowEffects()
	local spirit = HuntFX.core(2.2, SPIRIT_COLOR, low)
	spirit.Part.Name = "OtherBindSpirit"
	spirit.Part.CFrame = CFrame.new(target) * spirit.Turn
	spirit.Part.Parent = workspace
	entry.Spirit = spirit
	entry.Clock = 0
	local core = spirit.Part:FindFirstChild("Core") :: Attachment
	entry.Rig = ChainRig.Attach(character, core, { Color = CHAIN_COLOR, Count = 2, Low = low })
	entry.Pose = SealPose.Start(character)
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
	SealBurst.Play(position, relicId, { Low = low, Personal = false })
	task.delay(SealBurst.RevealAt, function()
		if root.Parent then
			CaptureAnimation.Play(
				relicId,
				if mutation ~= "" then mutation else nil,
				position,
				root,
				{ Low = low, Sound = false }
			)
		end
	end)
end

local function watch(player: Player)
	if player == Players.LocalPlayer or watched[player] then
		return
	end
	local entry: Watched = { Spirit = nil, Rig = nil, Pose = nil, Clock = 0, Connections = {} }
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

	-- The spirit resists like the owner's view does, chains writhe and the pose trembles.
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		for player, entry in watched do
			local spirit = entry.Spirit
			local target = player:GetAttribute("BindTarget")
			if not spirit or typeof(target) ~= "Vector3" then
				continue
			end
			entry.Clock += dt
			local shake = 0.25
			local jitter = Vector3.new(math.sin(clock * 31) * shake, math.sin(clock * 23) * shake, 0)
			spirit.Part.CFrame = CFrame.new(target + jitter) * CFrame.Angles(0, clock * 3, 0) * spirit.Turn
			if entry.Rig then
				ChainRig.Update(entry.Rig, entry.Clock, SHOWN_PROGRESS, math.min(1, entry.Clock / REACH_SECONDS))
			end
			if entry.Pose then
				entry.Pose.Update(entry.Clock, SHOWN_PROGRESS, target)
			end
		end
	end)
end

return OtherBinds
