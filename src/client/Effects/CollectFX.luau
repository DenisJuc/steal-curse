-- Collect pad feedback (PedestalService.Collect -> IncomeCollected): when the owner steps on a
-- pedestal's pad, the pad flashes, a warm ring sweeps out, gold motes and a few spirit wisps rise,
-- a "+amount" floats up and the HUD coins fly from the pad to the CE counter. Bigger hauls (more
-- seconds of income) throw more motes. Visual and sound only.
-- 2026-11-08: the pad is a pressure plate: it sinks under your feet and springs back, and pads
-- collected in a quick run ring higher each time (a walk down a lane plays a rising scale).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(script.Parent.Parent.Sounds)
local Motion = require(script.Parent.Parent.UI.Motion)

local CollectFX = {}

local GOLD = Color3.fromRGB(255, 205, 110)
local WARM = Color3.fromRGB(255, 170, 70)
local SPIRIT = Color3.fromRGB(170, 110, 255)
local INK = Color3.fromRGB(17, 13, 24)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local player = Players.LocalPlayer
-- Pads collected within COMBO_SECONDS of each other count as one run.
local COMBO_SECONDS = 3
local comboCount = 0
local lastCollectAt = -math.huge
local pressing: { [BasePart]: boolean } = {}

-- Sinks the pad (and its rim, plate and rune) a little and springs it back. Local only.
local function press(pad: BasePart)
	if pressing[pad] then
		return
	end
	local pedestal = pad.Parent
	if not pedestal then
		return
	end
	local parts = {}
	for _, name in { "CollectPad", "CollectTrim", "CollectBase", "CollectGlow" } do
		local part = pedestal:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	pressing[pad] = true
	local value = Instance.new("NumberValue")
	local homes = {}
	for index, part in parts do
		homes[index] = part.CFrame
	end
	value.Changed:Connect(function(depth)
		for index, part in parts do
			part.CFrame = homes[index] - Vector3.new(0, depth, 0)
		end
	end)
	local down = TweenService:Create(value, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0.22 })
	down.Completed:Once(function()
		local up = TweenService:Create(value, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 })
		up.Completed:Once(function()
			for index, part in parts do
				part.CFrame = homes[index]
			end
			value:Destroy()
			pressing[pad] = nil
		end)
		up:Play()
	end)
	down:Play()
	-- The rune core flares and fades back.
	local glow = pedestal:FindFirstChild("CollectGlow")
	if glow and glow:IsA("BasePart") then
		local rest = glow.Transparency
		glow.Transparency = 0
		TweenService:Create(glow, TweenInfo.new(0.5), { Transparency = rest }):Play()
	end
end

local function myPad(slot: number): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local pedestals = plot:FindFirstChild("Pedestals")
			local pedestal = pedestals and pedestals:FindFirstChild("Pedestal" .. slot)
			local pad = pedestal and pedestal:FindFirstChild("CollectPad")
			return if pad and pad:IsA("BasePart") then pad else nil
		end
	end
	return nil
end

local function emitter(parent: Attachment, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = SPARK
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function burst(pad: BasePart, haul: number)
	local holder = Instance.new("Attachment")
	holder.Name = "CollectBurst"
	holder.Position = Vector3.new(0, 0.3, 0)
	holder.Parent = pad

	-- Gold motes thrown up and falling back.
	local motes = emitter(holder, {
		Color = ColorSequence.new(GOLD, WARM),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(9, 16),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -24, 0),
		Drag = 1,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
	})
	-- Spirit wisps drifting up slowly: the dark-shrine half of the moment.
	local wisps = emitter(holder, {
		Color = ColorSequence.new(SPIRIT),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.3, 1.1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.9, 1.4),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 2,
	})
	motes:Emit(haul)
	wisps:Emit(math.max(4, math.floor(haul / 4)))

	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 14
	light.Brightness = 6
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()

	-- A thin warm ring sweeping out from the pad along the floor.
	local ring = Instance.new("Part")
	ring.Name = "CollectRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Transparency = 0.2
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.05, 5, 5)
	ring.CFrame = CFrame.new(pad.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 16, 16),
		Transparency = 1,
	}):Play()

	task.delay(1.6, function()
		holder:Destroy()
		ring:Destroy()
	end)
end

local function floatingAmount(pad: BasePart, amount: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CollectAmount"
	gui.Size = UDim2.new(4, 60, 1.2, 20)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = `+{Format.number(amount)} CE`
	label.TextColor3 = GOLD
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	gui.Adornee = pad
	gui.Parent = pad

	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(gui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 7, 0),
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.3, function()
		gui:Destroy()
	end)
end

function CollectFX.Play(slot: number, amount: number)
	local pad = myPad(slot)
	if not pad then
		return
	end
	-- How many seconds of income this was: a few seconds is a tap, a minute or more a proper haul.
	local perSec = player:GetAttribute("IncomePerSec") or 0
	local seconds = if perSec > 0 then amount / perSec else 10
	local haul = math.clamp(math.floor(10 + seconds * 0.6), 10, 60)

	local camera = Workspace.CurrentCamera
	if camera then
		local point, onScreen = camera:WorldToScreenPoint(pad.Position + Vector3.new(0, 2, 0))
		if onScreen then
			Motion.markCoinSourceAt(Vector2.new(point.X, point.Y))
		end
	end
	local now = os.clock()
	comboCount = if now - lastCollectAt <= COMBO_SECONDS then math.min(comboCount + 1, 6) else 0
	lastCollectAt = now
	press(pad)
	burst(pad, haul)
	floatingAmount(pad, amount)
	-- One sound only: the coin (Rosselle: two sounds per collect was too much), a step higher
	-- for each pad in a run (whole-tone steps from 0.9).
	Sounds.Play("Coin", pad, 0.9 * 2 ^ (comboCount * 2 / 12))
end

function CollectFX.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local event = remotes:WaitForChild("IncomeCollected") :: RemoteEvent
	event.OnClientEvent:Connect(function(slot: any, amount: any)
		if type(slot) == "number" and type(amount) == "number" then
			CollectFX.Play(slot, amount)
		end
	end)
end

return CollectFX
