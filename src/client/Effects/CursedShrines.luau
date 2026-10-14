-- Client side of Lift the Curse (CurseService). Every Cursed Shrine (tag "CursedShrine") gets a
-- local hold prompt; holding it sends ShrineAction Begin / Cancel / Complete (the server times the
-- hold) while chains of light pull at the shrine. A cleansed shrine (the "Cleansed" attribute)
-- loses its dark aura and chains and glows warm for this player only.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HuntFX = require(script.Parent.HuntFX)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local Banner = require(script.Parent.Parent.UI.Banner)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineResult = Remotes:WaitForChild("ShrineResult") :: RemoteEvent

local CursedShrines = {}

local TAG = "CursedShrine"
local CURSE_COLOR = Color3.fromRGB(150, 80, 220)
local PURE_COLOR = Color3.fromRGB(255, 225, 160)
local CHAINS = 3
local RETRIES = 6
-- Seconds of slack around HoldSeconds when deciding a hold has finished.
local END_SLACK = 0.25

local REASON_TEXT: { [string]: string } = {
	TooFar = "Stay close to the shrine.",
	Busy = "Finish what you are doing first.",
	Interrupted = "The cleansing was interrupted.",
	Timeout = "The cleansing faded.",
	Done = "This shrine is already cleansed.",
}

local player = Players.LocalPlayer

type Shrine = { Id: string, Model: Model, Prompt: ProximityPrompt, Charm: BasePart? }
local shrines: { [string]: Shrine } = {}

type Hold = {
	Id: string,
	Started: number,
	Beams: { Beam },
	Attachments: { Attachment },
	Loop: Sound?,
	Completed: boolean,
	Retries: number,
}
local hold: Hold? = nil
local promptsShown = 0

-- True while a shrine's cleanse prompt is on screen (E cleanses instead of binding a signal).
function CursedShrines.PromptShown(): boolean
	return promptsShown > 0 or hold ~= nil
end

local function cleansedSet(): { [string]: boolean }
	local set = {}
	local text = player:GetAttribute("Cleansed")
	if type(text) == "string" and text ~= "" then
		for _, id in string.split(text, ",") do
			set[id] = true
		end
	end
	return set
end

local function applyLook(shrine: Shrine, cleansed: boolean)
	shrine.Prompt.Enabled = not cleansed
	for _, item in shrine.Model:GetDescendants() do
		if item:IsA("ParticleEmitter") and item.Name == "CurseAura" then
			item.Enabled = not cleansed
		elseif item:IsA("PointLight") and item.Name == "CurseLight" then
			item.Color = if cleansed then PURE_COLOR else CURSE_COLOR
			item.Range = if cleansed then 18 else 14
			item.Brightness = if cleansed then 1.4 else 0.8
		elseif item:IsA("BasePart") and item.Name == "Chain" then
			item.Transparency = if cleansed then 1 else 0
		end
	end
	local charm = shrine.Charm
	if charm then
		charm.Material = if cleansed then Enum.Material.Neon else Enum.Material.Fabric
		charm.Color = if cleansed then PURE_COLOR else Color3.fromRGB(232, 222, 196)
	end
end

local function refreshLooks()
	local set = cleansedSet()
	for id, shrine in shrines do
		applyLook(shrine, set[id] == true)
	end
end

local function stopHold()
	local current = hold
	if not current then
		return
	end
	hold = nil
	for _, beam in current.Beams do
		beam:Destroy()
	end
	for _, attachment in current.Attachments do
		attachment:Destroy()
	end
	if current.Loop then
		current.Loop:Destroy()
	end
end

-- The curse breaks: the chains burst off, a pillar of light rises out of the shrine.
local function celebrate(shrine: Shrine)
	local low = Settings.LowEffects()
	local center = shrine.Model:GetPivot().Position
	local at = center + Vector3.new(0, 3, 0)
	HuntFX.burst(at, PURE_COLOR, if low then 15 else 60, 18)
	HuntFX.shockwave(center + Vector3.new(0, 0.5, 0), PURE_COLOR, 30, 0.9)
	HuntFX.shake(0.5, 0.5)
	Sounds.Play("ChainTighten")
	Sounds.Play("Seal")
	Sounds.Play("Shine", nil, 0.9)
	for _, item in shrine.Model:GetDescendants() do
		if item:IsA("BasePart") and item.Name == "Chain" then
			local shard = item:Clone()
			shard:ClearAllChildren()
			shard.Anchored = true
			shard.CanCollide = false
			shard.Material = Enum.Material.Neon
			shard.Color = PURE_COLOR
			shard.Parent = workspace
			local away = (item.Position - center) * Vector3.new(1, 0, 1)
			local push = (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 6 + Vector3.new(0, 4, 0)
			TweenService:Create(shard, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = item.CFrame + push,
				Transparency = 1,
			}):Play()
			Debris:AddItem(shard, 0.9)
		end
	end
	local pillar = HuntFX.part({
		Name = "PurifyPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 5, 5),
		CFrame = CFrame.new(center + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Neon,
		Color = PURE_COLOR,
		Transparency = 0.2,
	})
	pillar.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = PURE_COLOR
	light.Range = 40
	light.Brightness = 5
	light.Parent = pillar
	TweenService:Create(pillar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(160, 3, 3),
		CFrame = CFrame.new(center + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(pillar, TweenInfo.new(2.2), { Transparency = 1, Size = Vector3.new(160, 0.5, 0.5) }):Play()
		TweenService:Create(light, TweenInfo.new(2.2), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(pillar, 3)
end

-- Sends Complete once per hold: whichever comes first of the prompt's Triggered, the hold
-- ending at full time, or the hold timer running out.
local function complete(current: Hold)
	if current.Completed then
		return
	end
	current.Completed = true
	ShrineAction:FireServer("Complete", current.Id)
end

local function startHold(shrine: Shrine)
	stopHold()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = shrine.Charm or shrine.Model.PrimaryPart
	if not (root and root:IsA("BasePart") and target) then
		return
	end
	local from = Instance.new("Attachment")
	from.Name = "CleanseFrom"
	from.Position = Vector3.new(0, 0.5, -0.6)
	from.Parent = root
	local to = Instance.new("Attachment")
	to.Name = "CleanseTo"
	to.Parent = target
	local beams = {}
	for index = 1, CHAINS do
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Width0 = 0.3
		beam.Width1 = 0.15
		beam.Segments = 12
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.CurveSize0 = (index - 2) * 2.5
		beam.CurveSize1 = -(index - 2) * 2
		beam.Color = ColorSequence.new(CURSE_COLOR)
		beam.Transparency = NumberSequence.new(0.3)
		beam.Parent = root
		table.insert(beams, beam)
	end
	Sounds.Play("ChainRattle", target)
	hold = {
		Id = shrine.Id,
		Started = os.clock(),
		Beams = beams,
		Attachments = { from, to },
		Loop = Sounds.Loop("BindRiser", target),
		Completed = false,
		Retries = 0,
	}
	ShrineAction:FireServer("Begin", shrine.Id)
end

local pending: { [Instance]: boolean } = {}

local function addShrine(model: Instance)
	if not model:IsA("Model") or pending[model] then
		return
	end
	local id = model:GetAttribute("ShrineId")
	if type(id) ~= "string" or shrines[id] then
		return
	end
	-- The model can replicate before its parts do: wait for them instead of skipping the shrine.
	pending[model] = true
	local body = model:WaitForChild("Body", 60)
	local charm = model:WaitForChild("Charm", 10)
	pending[model] = nil
	if not (body and body:IsA("BasePart")) or shrines[id] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleansePrompt"
	prompt.ActionText = "Cleanse (hold)"
	prompt.ObjectText = "Cursed Shrine"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Curse.HoldSeconds
	prompt.MaxActivationDistance = Config.Curse.Range
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Parent = body
	prompt.PromptShown:Connect(function()
		promptsShown += 1
	end)
	prompt.PromptHidden:Connect(function()
		promptsShown = math.max(0, promptsShown - 1)
	end)
	local shrine: Shrine = {
		Id = id,
		Model = model,
		Prompt = prompt,
		Charm = if charm and charm:IsA("BasePart") then charm else nil,
	}
	shrines[id] = shrine
	prompt.PromptButtonHoldBegan:Connect(function()
		startHold(shrine)
	end)
	-- When a hold finishes, HoldEnded can fire before Triggered: a full-length hold counts as
	-- complete, and a short one only cancels if Triggered doesn't follow right after.
	prompt.PromptButtonHoldEnded:Connect(function()
		local current = hold
		if not current or current.Id ~= id or current.Completed then
			return
		end
		if os.clock() - current.Started >= Config.Curse.HoldSeconds - END_SLACK then
			complete(current)
			return
		end
		task.delay(0.15, function()
			if hold == current and not current.Completed then
				ShrineAction:FireServer("Cancel", id)
				stopHold()
			end
		end)
	end)
	prompt.Triggered:Connect(function()
		local current = hold
		if current and current.Id == id then
			complete(current)
		end
	end)
	applyLook(shrine, cleansedSet()[id] == true)
end

local function onResult(result: { [string]: any })
	local current = hold
	if type(result) ~= "table" then
		return
	end
	if result.Ok then
		stopHold()
		local shrine = shrines[result.Id]
		if shrine then
			celebrate(shrine)
		end
		refreshLooks()
		Banner.Show("SHRINE CLEANSED", tostring(result.Lore or ""), PURE_COLOR)
		Toasts.Show(tostring(result.Text or ""), "Item")
		return
	end
	if not current or current.Id ~= result.Id then
		return
	end
	if result.Reason == "TooEarly" and current.Retries < RETRIES then
		current.Retries += 1
		task.delay(0.3, function()
			if hold == current then
				ShrineAction:FireServer("Complete", current.Id)
			end
		end)
		return
	end
	stopHold()
	if result.Reason ~= "Released" then
		Sounds.Play("Cancel")
		Toasts.Show(REASON_TEXT[result.Reason] or "The cleansing failed.", "Error")
	end
end

function CursedShrines.Start()
	for _, model in CollectionService:GetTagged(TAG) do
		task.spawn(addShrine, model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		task.spawn(addShrine, model)
	end)
	player:GetAttributeChangedSignal("Cleansed"):Connect(refreshLooks)
	ShrineResult.OnClientEvent:Connect(onResult)
	player.CharacterAdded:Connect(function()
		stopHold()
	end)
	RunService.Heartbeat:Connect(function()
		local current = hold
		if not current then
			return
		end
		local elapsed = os.clock() - current.Started
		if elapsed >= Config.Curse.HoldSeconds + END_SLACK then
			complete(current)
		end
		local t = math.clamp(elapsed / Config.Curse.HoldSeconds, 0, 1)
		local color = CURSE_COLOR:Lerp(PURE_COLOR, t)
		local wobble = 0.15 * math.sin(os.clock() * 18)
		for index, beam in current.Beams do
			beam.Color = ColorSequence.new(color)
			beam.Width0 = 0.3 + t * 0.35 + wobble
			beam.CurveSize0 = (index - 2) * 2.5 * (1 - t) + wobble * 4
		end
	end)
end

return CursedShrines
