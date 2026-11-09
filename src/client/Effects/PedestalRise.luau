-- A pedestal stand rising out of the floor when its slot is bought (2026-11-08). Unbought slots
-- show only the dais and its ring (PedestalVisuals); when a pedestal's "Owned" attribute turns on,
-- this client sinks the stand under the floor and lifts it back with a slight overshoot, with a
-- dust ring, a flash of light and the Upgrade sound. Purely local CFrame changes: the parts end
-- exactly where the server put them, so nothing drifts.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local PedestalRise = {}

local DEPTH = 4.6
local SECONDS = 0.85
local MAX_DISTANCE = 160
local STAND_PARTS = { "Base", "Top", "Glow" }
local DUST = Color3.fromRGB(205, 190, 170)
local GOLD = Color3.fromRGB(255, 205, 110)

local function easeOutBack(t: number): number
	local c1, c3 = 1.4, 2.4
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function standParts(pedestal: Model): { BasePart }
	local parts = {}
	for _, name in STAND_PARTS do
		local part = pedestal:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	local look = pedestal:FindFirstChild("Look")
	if look then
		for _, part in look:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	return parts
end

local function dustRing(at: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "RiseRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Transparency = 0.25
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.05, 4, 4)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 14, 14),
		Transparency = 1,
	}):Play()

	local holder = Instance.new("Attachment")
	holder.Name = "RiseDust"
	holder.WorldPosition = at + Vector3.new(0, 0.4, 0)
	holder.Parent = Workspace.Terrain
	local dust = Instance.new("ParticleEmitter")
	dust.Enabled = false
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(DUST)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.7, 1.1)
	dust.Speed = NumberRange.new(6, 10)
	dust.SpreadAngle = Vector2.new(80, 10)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 4
	dust.Parent = holder
	dust:Emit(if Settings.LowEffects() then 6 else 18)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 16
	light.Brightness = 5
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.9), { Brightness = 0 }):Play()
	task.delay(1.6, function()
		ring:Destroy()
		holder:Destroy()
	end)
end

local function rise(pedestal: Model)
	local parts = standParts(pedestal)
	if #parts == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local base = pedestal:FindFirstChild("Base")
	local at = if base and base:IsA("BasePart") then base.Position else parts[1].Position
	if camera and (camera.CFrame.Position - at).Magnitude > MAX_DISTANCE then
		return
	end
	local homes = {}
	for index, part in parts do
		homes[index] = part.CFrame
		part.CFrame = part.CFrame - Vector3.new(0, DEPTH, 0)
	end
	dustRing(Vector3.new(at.X, at.Y - (base and (base :: BasePart).Size.X / 2 or 2), at.Z))
	Sounds.Play("Upgrade", base or parts[1], 0.9)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - started) / SECONDS)
		local drop = DEPTH * (1 - easeOutBack(t))
		for index, part in parts do
			if part.Parent then
				part.CFrame = homes[index] - Vector3.new(0, drop, 0)
			end
		end
		if t >= 1 then
			connection:Disconnect()
			for index, part in parts do
				if part.Parent then
					part.CFrame = homes[index]
				end
			end
		end
	end)
end

local function watchPedestal(pedestal: Instance)
	if not pedestal:IsA("Model") then
		return
	end
	local owned = pedestal:GetAttribute("Owned") == true
	pedestal:GetAttributeChangedSignal("Owned"):Connect(function()
		local now = pedestal:GetAttribute("Owned") == true
		if now and not owned then
			rise(pedestal)
		end
		owned = now
	end)
end

local function watchPlot(plot: Instance)
	local folder = plot:WaitForChild("Pedestals", 30)
	if not folder then
		return
	end
	for _, pedestal in folder:GetChildren() do
		watchPedestal(pedestal)
	end
	folder.ChildAdded:Connect(watchPedestal)
end

function PedestalRise.Start()
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 60)
		local plots = map and map:WaitForChild("Plots", 60)
		if not plots then
			return
		end
		for _, plot in plots:GetChildren() do
			task.spawn(watchPlot, plot)
		end
		plots.ChildAdded:Connect(function(plot)
			task.spawn(watchPlot, plot)
		end)
	end)
end

return PedestalRise
