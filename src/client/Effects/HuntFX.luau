-- Small shared VFX pieces for the hunt: glowing decor parts, flat rune rings drawn with a
-- SurfaceGui (crisp at any size, no uploaded textures), expanding shockwaves, particle bursts,
-- camera shake and the spirit core used by signals. Client-only, never replicated.

local RunService = game:GetService("RunService")

local HuntModels = require(script.Parent.HuntModels)

local HuntFX = {}

HuntFX.SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
HuntFX.SMOKE = "rbxasset://textures/particles/smoke_main.dds"
HuntFX.FIRE = "rbxasset://textures/particles/fire_main.dds"

local RUNES = { "封", "霊", "縛", "禁", "呪", "印", "魂", "鎖" }
local SHAKE_STEP = "HuntCameraShake"

function HuntFX.part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function circle(gui: SurfaceGui, scale: number, thickness: number, color: Color3)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(scale, scale)
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.Parent = frame
	frame.Parent = gui
end

-- A flat ring drawn on an invisible part's top face; the part's X/Z size is the diameter. With
-- runes: an inner ring and seal characters between the two.
function HuntFX.ring(diameter: number, color: Color3, runes: boolean): Part
	local part = HuntFX.part({
		Name = "RuneRing",
		Size = Vector3.new(diameter, 0.05, diameter),
		Transparency = 1,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = part
	circle(gui, 0.94, 10, color)
	if runes then
		circle(gui, 0.64, 5, color)
		for index, rune in RUNES do
			local angle = (index - 1) / #RUNES * math.pi * 2
			local label = Instance.new("TextLabel")
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.395, 0.5 + math.sin(angle) * 0.395)
			label.Size = UDim2.fromOffset(56, 56)
			label.Rotation = math.deg(angle) + 90
			label.BackgroundTransparency = 1
			label.Text = rune
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = color
			label.Parent = gui
		end
	end
	return part
end

function HuntFX.tintRing(ring: Instance, color: Color3, transparency: number)
	local gui = ring:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return
	end
	for _, item in gui:GetDescendants() do
		if item:IsA("UIStroke") then
			item.Color = color
			item.Transparency = transparency
		elseif item:IsA("TextLabel") then
			item.TextColor3 = color
			item.TextTransparency = transparency
		end
	end
end

-- A ground ring that races outward from `at` and fades.
function HuntFX.shockwave(at: Vector3, color: Color3, diameter: number, seconds: number)
	local ring = HuntFX.ring(1, color, false)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0))
	ring.Parent = workspace
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / seconds)
		local size = 1 + (diameter - 1) * (1 - (1 - t) ^ 3)
		ring.Size = Vector3.new(size, 0.05, size)
		HuntFX.tintRing(ring, color, t)
		if t >= 1 then
			connection:Disconnect()
			ring:Destroy()
		end
	end)
end

-- One-off spray of `count` particles from `at`.
function HuntFX.burst(at: Vector3, color: Color3, count: number, speed: number, texture: string?)
	local holder = HuntFX.part({ Name = "Burst", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture or HuntFX.SPARKLES
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.9, 0)
	emitter.Drag = 3
	emitter.Enabled = false
	emitter.Parent = holder
	holder.Parent = workspace
	emitter:Emit(count)
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

type Shake = { Amount: number, Start: number, Seconds: number }
local shakes: { Shake } = {}
local shakeBound = false

-- Current combined shake as a camera offset. Scripted cameras (the bind view) apply it themselves.
function HuntFX.shakeOffset(): CFrame
	local now = os.clock()
	local amount = 0
	for index = #shakes, 1, -1 do
		local shake = shakes[index]
		local t = (now - shake.Start) / shake.Seconds
		if t >= 1 then
			table.remove(shakes, index)
		else
			amount += shake.Amount * (1 - t) ^ 2
		end
	end
	if amount <= 0 then
		return CFrame.identity
	end
	local x = math.noise(now * 22, 0.3)
	local y = math.noise(now * 22, 7.1)
	local roll = math.noise(now * 18, 13.7)
	return CFrame.new(x * amount, y * amount, 0) * CFrame.Angles(0, 0, roll * amount * 0.05)
end

-- Shakes the camera by up to `amount` studs, fading out over `seconds`.
function HuntFX.shake(amount: number, seconds: number)
	table.insert(shakes, { Amount = amount, Start = os.clock(), Seconds = seconds })
	if shakeBound then
		return
	end
	shakeBound = true
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local offset = HuntFX.shakeOffset()
		if #shakes == 0 then
			shakeBound = false
			RunService:UnbindFromRenderStep(SHAKE_STEP)
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CFrame *= offset
		end
	end)
end

export type Core = {
	Part: BasePart,
	-- Orientation applied on top of the core's frame (mesh alignment).
	Turn: CFrame,
	Size: Vector3,
}

-- The spirit at the heart of a signal: the SignalCore mesh (or a glowing ball), with a light, a
-- sparkle emitter and a "Core" attachment the chains aim at.
function HuntFX.core(size: number, color: Color3, low: boolean): Core
	local built = HuntModels.build("SignalCore", size)
	local part: BasePart
	local turn = CFrame.identity
	if built then
		part = built.Part
		turn = built.Turn
	else
		part = HuntFX.part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Color = color,
			Transparency = 0.15,
		})
	end
	part.Name = "Signal"

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = part

	if not low then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = HuntFX.SPARKLES
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Rate = 10
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.Parent = part
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Core"
	attachment.Parent = part
	return { Part = part, Turn = turn, Size = part.Size }
end

return HuntFX
