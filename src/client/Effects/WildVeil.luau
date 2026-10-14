-- The veil around the town: rings of darkness just past the town edge so the wild is black when
-- you look out from town (the wild's own night lighting only applies once you stand in it). Each
-- ring is made of segments whose dark face (a SurfaceGui, one-sided) points at the hub, fully dark
-- low down and fading up into the sky, plus dark mist rolling along the edge. From inside the wild
-- you see through it; it also fades away as you step in (Ambience.WildWeight).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Settings = require(script.Parent.Parent.Settings)
local Ambience = require(script.Parent.Ambience)

local WildVeil = {}

type Layer = { Frame: Frame, Opacity: number }

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function holder(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function WildVeil.Start()
	local cfg = Config.Ambience.Veil
	local inner = Config.World.WildInner
	local folder = Instance.new("Folder")
	folder.Name = "WildVeil"
	folder.Parent = workspace

	local gradient = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1 - cfg.SolidUntil, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	local layers: { Layer } = {}
	for _, layer in cfg.Layers do
		local radius = inner + layer.Offset
		local width = 2 * math.pi * radius / cfg.Segments + 1
		for index = 0, cfg.Segments - 1 do
			local x, z = WorldLayout.polar(index * 360 / cfg.Segments, radius)
			local center = Vector3.new(x, cfg.Height / 2 - 6, z)
			local part = holder("Veil", Vector3.new(width, cfg.Height, 0.2), CFrame.lookAt(center, Vector3.new(0, center.Y, 0)), folder)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 2
			gui.MaxDistance = 5000
			gui.Parent = part
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromScale(1, 1)
			frame.BorderSizePixel = 0
			frame.BackgroundColor3 = rgb(cfg.Color)
			frame.BackgroundTransparency = 1 - layer.Opacity
			frame.Parent = gui
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = gradient
			fade.Parent = frame
			table.insert(layers, { Frame = frame, Opacity = layer.Opacity })
		end
	end

	-- The lid: a dark ring laid flat over the whole wild at the height where the rings stop being
	-- solid, facing up. A camera high enough to look over the rings looks down onto this instead
	-- of the map; from underneath it is invisible.
	local lidY = cfg.Height * cfg.SolidUntil - 6
	local lidInner = inner + cfg.Layers[1].Offset
	local lidOuter = Config.World.WildOuter + cfg.LidBeyond
	local lidWidth = 2 * math.pi * lidOuter / cfg.Segments + 1
	local lidLength = lidOuter - lidInner
	for index = 0, cfg.Segments - 1 do
		local x, z = WorldLayout.polar(index * 360 / cfg.Segments, lidInner + lidLength / 2)
		local center = Vector3.new(x, lidY, z)
		local part = holder("VeilLid", Vector3.new(lidWidth, 0.2, lidLength), CFrame.lookAt(center, Vector3.new(0, lidY, 0)), folder)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 0.5
		gui.MaxDistance = 5000
		gui.Parent = part
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = rgb(cfg.Color)
		frame.Parent = gui
		table.insert(layers, { Frame = frame, Opacity = 1 })
	end

	local mist = cfg.Mist
	local emitters: { ParticleEmitter } = {}
	local mistRadius = inner + mist.Offset
	local mistWidth = 2 * math.pi * mistRadius / mist.Emitters
	for index = 0, mist.Emitters - 1 do
		local x, z = WorldLayout.polar((index + 0.5) * 360 / mist.Emitters, mistRadius)
		local center = Vector3.new(x, 4, z)
		local part = holder("VeilMist", Vector3.new(mistWidth, 6, 10), CFrame.lookAt(center, Vector3.new(0, 4, 0)), folder)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SMOKE
		emitter.Color = ColorSequence.new(rgb(mist.Color))
		emitter.LightInfluence = 0
		emitter.LightEmission = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, mist.Size * 0.6),
			NumberSequenceKeypoint.new(1, mist.Size),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.3),
			NumberSequenceKeypoint.new(0.75, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(8, 12)
		emitter.Speed = NumberRange.new(0.4, 1.2)
		emitter.SpreadAngle = Vector2.new(180, 30)
		emitter.Acceleration = Vector3.new(0, 0.35, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-8, 8)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.Rate = 0
		emitter.Parent = part
		table.insert(emitters, emitter)
	end

	-- The camera can't swing out past the rings while you stand in town (it would look at the wild
	-- from behind the veil): it is pulled in along its view line, like hitting a wall.
	local wall = inner + cfg.Layers[1].Offset - 1
	RunService:BindToRenderStep("WildVeilCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (camera and root and root:IsA("BasePart")) or camera.CameraType ~= Enum.CameraType.Custom then
			return
		end
		if Vector2.new(root.Position.X, root.Position.Z).Magnitude >= inner then
			return
		end
		local eye = camera.CFrame.Position
		local focus = camera.Focus.Position
		local f = Vector2.new(focus.X, focus.Z)
		if Vector2.new(eye.X, eye.Z).Magnitude <= wall or f.Magnitude >= wall then
			return
		end
		local d = Vector2.new(eye.X - focus.X, eye.Z - focus.Z)
		local a, b, c = d:Dot(d), 2 * f:Dot(d), f:Dot(f) - wall * wall
		local t = (-b + math.sqrt(b * b - 4 * a * c)) / (2 * a)
		camera.CFrame = CFrame.new(focus + (eye - focus) * t) * camera.CFrame.Rotation
	end)

	local shown = -1
	local low: boolean? = nil
	RunService.Heartbeat:Connect(function()
		local visible = 1 - math.clamp(Ambience.WildWeight() * 1.4, 0, 1)
		local lowNow = Settings.LowEffects()
		if math.abs(visible - shown) < 0.01 and lowNow == low then
			return
		end
		shown, low = visible, lowNow
		for _, layer in layers do
			layer.Frame.BackgroundTransparency = 1 - layer.Opacity * visible
		end
		for _, emitter in emitters do
			emitter.Rate = if lowNow then 0 else mist.Rate * visible
		end
	end)
end

return WildVeil
