-- Small helpers for building the map from code (anchored, smooth parts).

local BuildUtil = {}

type Props = { [string]: any }

function BuildUtil.part(parent: Instance, props: Props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Upright cylinder centered at cframe. Cylinder parts lie along X, so rotate 90 degrees about Z.
function BuildUtil.cylinder(parent: Instance, cframe: CFrame, height: number, diameter: number, props: Props): Part
	local part = BuildUtil.part(parent, props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- Decorative/VFX parts never collide, cast shadows or get hit by queries.
function BuildUtil.decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	return part
end

function BuildUtil.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

-- Billboard sized in studs (BillboardGui scale units are studs).
function BuildUtil.billboard(part: BasePart, text: string, widthStuds: number, heightStuds: number, offsetY: number, color: Color3?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(widthStuds, heightStuds)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

function BuildUtil.light(part: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

function BuildUtil.sparkles(part: BasePart, color: Color3, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = part
	return emitter
end

return BuildUtil
