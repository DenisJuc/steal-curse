-- Client side of the personal wild finds (WildFindsService). The server decides everything and
-- sends it through the WildFind remote; this draws it:
--   Strike: a bolt from the sky, a flash and close thunder (Ambience), a scorch glow and a column
--   of embers where it landed, and a yellow crackling aura on every struck signal until it fades.
--   Offering: a small box that chimes every few seconds (found by ear; pulses don't show it),
--   opened with a prompt; bursts in its tier's colour.
--   Lost One: a tall dark figure that blinks away as you come close, then kneels and leaves a
--   Spirit Gift - or turns out to be the False Watcher (its eyes flicker red on its last hops), which
--   cuts the lights and lunges into your face. A pulse scares either off.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Offerings = require(ReplicatedStorage.Shared.Offerings)
local Ambience = require(script.Parent.Ambience)
local HuntFX = require(script.Parent.HuntFX)
local SpiritSight = require(script.Parent.SpiritSight)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local HuntModels = require(script.Parent.HuntModels)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WildFind = Remotes:WaitForChild("WildFind") :: RemoteEvent
local WildFindAction = Remotes:WaitForChild("WildFindAction") :: RemoteEvent
local SignalsUpdated = Remotes:WaitForChild("SignalsUpdated") :: RemoteEvent

local WildFinds = {}

local BOLT_COLOR = Color3.fromRGB(210, 225, 255)
local STRUCK_COLOR = Color3.fromRGB(255, 225, 90)
local EMBER = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local folder = Instance.new("Folder")
folder.Name = "WildFinds"

local function part(props: { [string]: any }): Part
	local made = Instance.new("Part")
	made.Anchored = true
	made.CanCollide = false
	made.CanTouch = false
	made.CanQuery = false
	made.CastShadow = false
	for key, value in props do
		(made :: any)[key] = value
	end
	made.Parent = folder
	return made
end

local function fadeOut(instance: BasePart, seconds: number)
	TweenService:Create(instance, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	task.delay(seconds + 0.05, function()
		instance:Destroy()
	end)
end

-- A jagged bolt of neon segments from high above down to `ground`.
local function bolt(ground: Vector3)
	local top = ground + Vector3.new((math.random() - 0.5) * 30, 220, (math.random() - 0.5) * 30)
	local points = { top }
	local steps = 9
	for index = 1, steps - 1 do
		local t = index / steps
		local along = top:Lerp(ground, t)
		local wobble = (1 - t) * 10 + 2
		table.insert(points, along + Vector3.new((math.random() - 0.5) * wobble, 0, (math.random() - 0.5) * wobble))
	end
	table.insert(points, ground)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		local segment = part({
			Name = "Bolt",
			Size = Vector3.new(0.7, 0.7, length),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Material = Enum.Material.Neon,
			Color = BOLT_COLOR,
			Transparency = 0,
		})
		fadeOut(segment, 0.45)
	end
end

local function scorch(ground: Vector3, untilTime: number, low: boolean)
	local glow = part({
		Name = "Scorch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Neon,
		Color = STRUCK_COLOR,
		Transparency = 0.2,
	})
	local light = Instance.new("PointLight")
	light.Color = STRUCK_COLOR
	light.Range = 40
	light.Brightness = 6
	light.Parent = glow
	TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 1.2, Range = 18 }):Play()
	TweenService:Create(glow, TweenInfo.new(2), { Transparency = 0.7 }):Play()
	if not low then
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = EMBER
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 90, 40))
		embers.LightEmission = 1
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		embers.Transparency = NumberSequence.new(0.2, 1)
		embers.Lifetime = NumberRange.new(2, 3.5)
		embers.Speed = NumberRange.new(4, 9)
		embers.SpreadAngle = Vector2.new(12, 12)
		embers.EmissionDirection = Enum.NormalId.Right
		embers.Rate = 18
		embers.Parent = glow
	end
	task.delay(math.max(2, untilTime - workspace:GetServerTimeNow()), function()
		fadeOut(glow, 1)
	end)
end

-- Yellow crackling aura on struck signals, keyed by signal id. Glow highlights the signal's orb
-- once Spirit Sight has one to show.
type Struck = { Holder: Part, Until: number, Glow: Highlight, NextArc: number }
local struck: { [number]: Struck } = {}

-- A short jagged arc of electricity out of `center`.
local function arc(center: Vector3, reach: number)
	local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	if direction.Magnitude < 0.05 then
		return
	end
	local last = center
	local steps = 3
	for index = 1, steps do
		local nextPoint = center + direction.Unit * reach * index / steps
			+ Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9
		local length = (nextPoint - last).Magnitude
		local segment = part({
			Name = "Arc",
			Size = Vector3.new(0.12, 0.12, length),
			CFrame = CFrame.lookAt((last + nextPoint) / 2, nextPoint),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 250, 210),
		})
		fadeOut(segment, 0.18)
		last = nextPoint
	end
end

local function setStruck(id: number, position: Vector3, untilTime: number)
	local entry = struck[id]
	if entry then
		entry.Until = untilTime
		entry.Holder.Position = position
		local aura = entry.Holder:FindFirstChild("Aura") :: BasePart?
		if aura then
			aura.Position = position
		end
		return
	end
	local holder = part({ Name = "Struck", Size = Vector3.new(4, 4, 4), Position = position, Transparency = 1 })
	local aura = part({
		Name = "Aura",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		Position = position,
		Material = Enum.Material.Neon,
		Color = STRUCK_COLOR,
		Transparency = 0.82,
	})
	aura.Parent = holder
	TweenService:Create(aura, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = Vector3.one * 6.5,
		Transparency = 0.9,
	}):Play()
	local glow = Instance.new("Highlight")
	glow.FillColor = STRUCK_COLOR
	glow.FillTransparency = 0.35
	glow.OutlineColor = Color3.fromRGB(255, 250, 210)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = holder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new(STRUCK_COLOR)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = if Settings.LowEffects() then 6 else 30
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = STRUCK_COLOR
	light.Range = 18
	light.Brightness = 3
	light.Parent = holder
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(130, 30)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 160
	tag.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = STRUCK_COLOR
	label.TextStrokeTransparency = 0.3
	label.Text = "LIGHTNING LUCK"
	label.Parent = tag
	struck[id] = { Holder = holder, Until = untilTime, Glow = glow, NextArc = 0 }
end

local function clearStruck(id: number)
	local entry = struck[id]
	if entry then
		entry.Holder:Destroy()
		struck[id] = nil
	end
end

local function onStrike(payload: { [string]: any })
	local ground = payload.Position
	if typeof(ground) ~= "Vector3" then
		return
	end
	local low = Settings.LowEffects()
	bolt(ground)
	scorch(ground, if type(payload.Until) == "number" then payload.Until else 0, low)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local distance = if root and root:IsA("BasePart") then (root.Position - ground).Magnitude else nil
	Ambience.Lightning(distance)
end

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function tierColor(tierId: string): Color3
	local tier = Offerings.tierOf(Config.Offerings :: any, tierId)
	return if tier then rgb(tier.Color) else STRUCK_COLOR
end

local function tierName(tierId: string): string
	local tier = Offerings.tierOf(Config.Offerings :: any, tierId)
	return if tier then tier.Name else "Offering"
end

---------------------------------------------------------------------------------------------------
-- Offering boxes

local CHIME_EVERY = 2.4
local WOOD = Color3.fromRGB(70, 45, 30)
local TRIM = Color3.fromRGB(200, 160, 80)

type Box = { Id: number, Model: Model, Lid: Part, ExpiresAt: number, NextChime: number }
local box: Box? = nil

local function removeBox(fade: boolean)
	local current = box
	if not current then
		return
	end
	box = nil
	if fade then
		for _, item in current.Model:GetDescendants() do
			if item:IsA("BasePart") and item.Transparency < 1 then
				fadeOut(item, 0.6)
			end
		end
		task.delay(0.7, function()
			current.Model:Destroy()
		end)
	else
		current.Model:Destroy()
	end
end

local function spawnBox(id: number, ground: Vector3, expiresAt: number)
	removeBox(false)
	local model = Instance.new("Model")
	model.Name = "Offering"
	local base = CFrame.new(ground) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local body = part({ Name = "Body", Size = Vector3.new(2.4, 1.4, 1.6), CFrame = base * CFrame.new(0, 0.7, 0), Color = WOOD, Material = Enum.Material.Wood })
	body.Parent = model
	local lid = part({ Name = "Lid", Size = Vector3.new(2.6, 0.35, 1.8), CFrame = base * CFrame.new(0, 1.58, 0), Color = WOOD, Material = Enum.Material.Wood })
	lid.Parent = model
	for _, x in { -1.05, 1.05 } do
		local band = part({ Name = "Trim", Size = Vector3.new(0.18, 1.5, 1.7), CFrame = base * CFrame.new(x, 0.75, 0), Color = TRIM, Material = Enum.Material.Metal })
		band.Parent = model
	end
	local charm = part({
		Name = "Charm",
		Size = Vector3.new(0.5, 0.7, 0.05),
		CFrame = base * CFrame.new(0, 0.9, -0.83),
		Color = Color3.fromRGB(240, 230, 200),
		Material = Enum.Material.Neon,
	})
	charm.Parent = model
	local light = Instance.new("PointLight")
	light.Color = TRIM
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = charm
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Lost Offering"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = Config.WildFinds.Offering.ClaimRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		WildFindAction:FireServer("Claim", id)
		task.delay(2, function()
			if prompt.Parent then
				prompt.Enabled = true
			end
		end)
	end)
	model.PrimaryPart = body
	model.Parent = folder
	box = { Id = id, Model = model, Lid = lid, ExpiresAt = expiresAt, NextChime = 0 }
end

local function openBox(id: number, tierId: string, text: string)
	local current = box
	local color = tierColor(tierId)
	if current and current.Id == id then
		local at = current.Lid.Position
		TweenService:Create(current.Lid, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = current.Lid.CFrame * CFrame.new(0, 1.2, 0.6) * CFrame.Angles(-1.1, 0, 0),
		}):Play()
		HuntFX.burst(at + Vector3.new(0, 1, 0), color, if Settings.LowEffects() then 12 else 40, 14)
		HuntFX.shockwave(at - Vector3.new(0, 1.5, 0), color, 14, 0.6)
		if not Sounds.Play("OfferingOpen", current.Lid) then
			Sounds.Play("Collect", current.Lid)
		end
		if tierId ~= "Common" then
			Sounds.Play("Shine", nil, if tierId == "Rare" then 0.8 else 1)
		end
		task.delay(1.2, removeBox, true)
	end
	Toasts.Show(`{tierName(tierId)}: {text}`, "Item")
end

---------------------------------------------------------------------------------------------------
-- The Lost One

local FIGURE_COLOR = Color3.fromRGB(5, 5, 8)
local EYE_LOST = Color3.fromRGB(170, 225, 255)
local EYE_FALSE = Color3.fromRGB(255, 40, 40)
-- Height of the block figure's head above its feet.
local FACE_HEIGHT = 7.4
-- The imported figure (HuntModels "LostOne") is scaled so its longest side is this many studs. Its
-- eyes go where the EyeL / EyeR attachments inside the mesh say; without them the mask is found by
-- scanning across the head EYE_LEVEL of the way up.
local IMPORTED_SIZE = 9
local EYE_LEVEL = 0.9

-- Wrong: it is the False Watcher and far enough along to show it (eyes flicker red at NextTell).
-- TwitchUntil / TwitchRoll: an imported figure's tell tilts the whole figure about its face.
type Lost = {
	Id: number,
	Model: Model,
	Root: Part,
	Wrong: boolean,
	NextTell: number,
	TwitchUntil: number,
	TwitchRoll: number,
}
local lost: Lost? = nil

-- Figure model attributes: EyeSize (resting eye size in studs), Face (Vector3 in root space, the
-- point the jumpscare holds in front of the camera), Imported (the mesh figure).
local function setEyes(model: Model, color: Color3, grow: number)
	local base = model:GetAttribute("EyeSize")
	local size = (if type(base) == "number" then base else 0.2) * grow
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name == "Eye" then
			item.Color = color
			item.Size = Vector3.one * size
			local light = item:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = color
			end
		end
	end
end

local function faceOffset(model: Model): Vector3
	local face = model:GetAttribute("Face")
	return if typeof(face) == "Vector3" then face else Vector3.new(0, FACE_HEIGHT, -0.35)
end

-- How the imported figure sits in root space (feet at the origin, facing -Z): the mesh's frame,
-- its eyes and its face. Pitch: radians the mask looks down (the jumpscare tips the figure back
-- by it). Mesh and Pitch are filled in by measureImported.
type Layout = { Mesh: CFrame, Eyes: { Vector3 }, EyeSize: number, Face: Vector3, Pitch: number }
local importedLayout: Layout? = nil

-- Half the size of a box turned by `turn`, measured along the unturned axes.
local function halfExtents(size: Vector3, turn: CFrame): Vector3
	local x, y, z = turn.XVector, turn.YVector, turn.ZVector
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	return Vector3.new(
		math.abs(x.X) * hx + math.abs(y.X) * hy + math.abs(z.X) * hz,
		math.abs(x.Y) * hx + math.abs(y.Y) * hy + math.abs(z.Y) * hz,
		math.abs(x.Z) * hx + math.abs(y.Z) * hy + math.abs(z.Z) * hz
	)
end

local function layoutFromEyes(a: Vector3, b: Vector3): Layout
	local gap = (a - b).Magnitude
	local mid = (a + b) / 2
	return {
		Mesh = CFrame.identity,
		Pitch = 0,
		Eyes = { a, b },
		EyeSize = math.clamp(gap * 0.3, 0.08, 0.6),
		Face = mid + Vector3.new(0, 0, 0.4),
	}
end

-- The EyeL / EyeR attachments placed in the mask's eye holes, in root space (their positions are
-- for the unscaled mesh).
local function attachmentEyes(mesh: BasePart, meshLocal: CFrame): (Vector3?, Vector3?)
	local left = mesh:FindFirstChild("EyeL", true)
	local right = mesh:FindFirstChild("EyeR", true)
	if not (left and left:IsA("Attachment") and right and right:IsA("Attachment")) then
		return nil, nil
	end
	local source = HuntModels.sourceSize("LostOne") or mesh.Size
	local scale = mesh.Size / source
	return meshLocal * (left.Position * scale), meshLocal * (right.Position * scale)
end

-- Which way the face looks, in root space: square to the line between the eyes, on the side where
-- the mask's surface is right at the eyes (behind them is the rest of the head and the hair).
local function faceDirection(mesh: BasePart, base: CFrame, a: Vector3, b: Vector3): Vector3?
	local across = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if across.Magnitude < 1e-3 then
		return nil
	end
	local unit = across.Unit
	local forward = Vector3.new(unit.Z, 0, -unit.X)
	local mid = (a + b) / 2
	local reach = mesh.Size.Magnitude
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mesh }
	mesh.CanQuery = true
	local function gap(direction: Vector3): number?
		local hit = workspace:Raycast(base * (mid + direction * reach), base:VectorToWorldSpace(-direction * reach * 2), params)
		return if hit then (base:PointToObjectSpace(hit.Position) - mid).Magnitude else nil
	end
	local ahead, behind = gap(forward), gap(-forward)
	mesh.CanQuery = false
	if ahead and behind then
		return if behind < ahead then -forward else forward
	elseif behind then
		return -forward
	elseif ahead then
		return forward
	end
	-- No hits: the face is the side of the head away from the body's middle.
	return if Vector3.new(mid.X, 0, mid.Z):Dot(forward) < 0 then -forward else forward
end

-- Casts rays at the front of the head across its width: the frontmost hits are the mask.
local function scanLayout(mesh: BasePart, base: CFrame, half: Vector3): Layout
	local y = half.Y * 2 * EYE_LEVEL
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mesh }
	mesh.CanQuery = true
	local hits = {}
	local columns = 61
	for index = 0, columns - 1 do
		local x = -half.X + 2 * half.X * index / (columns - 1)
		local origin = base * Vector3.new(x, y, -half.Z - 2)
		local hit = workspace:Raycast(origin, base:VectorToWorldSpace(Vector3.new(0, 0, half.Z * 2 + 4)), params)
		if hit then
			table.insert(hits, base:PointToObjectSpace(hit.Position))
		end
	end
	mesh.CanQuery = false
	if #hits == 0 then
		local gap = half.Y * 2 * 0.035
		return layoutFromEyes(Vector3.new(-gap / 2, y, -half.Z), Vector3.new(gap / 2, y, -half.Z))
	end
	local front = math.huge
	for _, point in hits do
		front = math.min(front, point.Z)
	end
	-- The mask: hits close to the frontmost one (hair beside the face sits farther back).
	local depth = half.Y * 2 * 0.04
	local minX, maxX = math.huge, -math.huge
	for _, point in hits do
		if point.Z <= front + depth then
			minX = math.min(minX, point.X)
			maxX = math.max(maxX, point.X)
		end
	end
	local center = (minX + maxX) / 2
	local gap = math.clamp((maxX - minX) * 0.38, half.Y * 2 * 0.025, half.Y * 2 * 0.06)
	local z = front + 0.05
	return layoutFromEyes(Vector3.new(center - gap / 2, y, z), Vector3.new(center + gap / 2, y, z))
end

-- How far the mask looks down (radians): from where rays from the front hit the forehead and the
-- chin. A bowed head has its forehead farther forward than its chin.
local function maskPitch(mesh: BasePart, base: CFrame, layout: Layout): number
	local a, b = layout.Eyes[1], layout.Eyes[2]
	local mid = (a + b) / 2
	local gap = (a - b).Magnitude
	local reach = mesh.Size.Magnitude
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mesh }
	mesh.CanQuery = true
	local function frontAt(height: number): Vector3?
		local start = Vector3.new(mid.X, mid.Y + height, mid.Z - reach)
		local hit = workspace:Raycast(base * start, base:VectorToWorldSpace(Vector3.new(0, 0, reach * 2)), params)
		return if hit then base:PointToObjectSpace(hit.Position) else nil
	end
	local forehead, chin = frontAt(gap * 0.9), frontAt(-gap * 1.6)
	mesh.CanQuery = false
	if not (forehead and chin) then
		return 0
	end
	local rise = forehead.Y - chin.Y
	if rise <= 0 then
		return 0
	end
	-- Forehead ahead of the chin (more negative Z) = looking down.
	return math.clamp(math.atan2(chin.Z - forehead.Z, rise), -0.35, 1.1)
end

-- Works out once how the imported mesh stands: its saved rotation (plus DisplayRotation), feet on
-- the ground, turned so the face looks along -Z, and where the eyes are.
local function measureImported(mesh: BasePart, turn: CFrame, base: CFrame): Layout
	local rotation = turn * (HuntModels.sourceRotation("LostOne") or CFrame.identity)
	local half = halfExtents(mesh.Size, rotation)
	local meshLocal = CFrame.new(0, half.Y, 0) * rotation
	mesh.CFrame = base * meshLocal
	local a, b = attachmentEyes(mesh, meshLocal)
	if not (a and b) then
		local layout = scanLayout(mesh, base, half)
		layout.Mesh = meshLocal
		return layout
	end
	local forward = faceDirection(mesh, base, a, b)
	local yaw = if forward then CFrame.lookAt(Vector3.zero, forward):Inverse() else CFrame.identity
	local layout = layoutFromEyes(yaw * a, yaw * b)
	layout.Mesh = yaw * meshLocal
	mesh.CFrame = base * layout.Mesh
	local pitch = HuntModels.attribute("LostOne", "FacePitch")
	layout.Pitch = if type(pitch) == "number" then math.rad(pitch) else maskPitch(mesh, base, layout)
	if RunService:IsStudio() then
		print(`[WildFinds] Lost One mask tilt: {math.floor(math.deg(layout.Pitch) + 0.5)} degrees (tune with /facepitch)`)
	end
	return layout
end

-- Dresses `model` with the imported mesh, its glowing eyes and an invisible Head at the face.
-- Returns false when there is no imported model.
local function dressImported(model: Model, base: CFrame): boolean
	local built = HuntModels.build("LostOne", IMPORTED_SIZE)
	if not built then
		return false
	end
	local mesh = built.Part
	mesh.Name = "Body"
	mesh.Parent = model
	local layout = importedLayout or measureImported(mesh, built.Turn, base)
	importedLayout = layout
	mesh.CFrame = base * layout.Mesh

	local head = part({ Name = "Head", Size = Vector3.one, CFrame = base * CFrame.new(layout.Face), Transparency = 1 })
	head.Parent = model
	for _, at in layout.Eyes do
		local eye = part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * layout.EyeSize,
			CFrame = base * CFrame.new(at),
			Material = Enum.Material.Neon,
			Color = EYE_LOST,
		})
		local light = Instance.new("PointLight")
		light.Color = EYE_LOST
		light.Range = 3
		light.Brightness = 0.8
		light.Parent = eye
		eye.Parent = model
	end
	model:SetAttribute("EyeSize", layout.EyeSize)
	model:SetAttribute("Face", layout.Face)
	model:SetAttribute("FacePitch", layout.Pitch)
	model:SetAttribute("Imported", true)
	return true
end

local function dressBlocks(model: Model, base: CFrame)
	local function piece(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?, color: Color3?, neon: boolean?)
		local made = part({
			Name = name,
			Size = size,
			CFrame = base * offset,
			Color = color or FIGURE_COLOR,
			Shape = shape or Enum.PartType.Block,
			Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
		made.Parent = model
	end
	piece("LegL", Vector3.new(0.8, 3.6, 0.8), CFrame.new(-0.55, 1.8, 0))
	piece("LegR", Vector3.new(0.8, 3.6, 0.8), CFrame.new(0.55, 1.8, 0))
	piece("Torso", Vector3.new(2, 3.4, 1), CFrame.new(0, 5.2, 0.2) * CFrame.Angles(-0.18, 0, 0))
	piece("ArmL", Vector3.new(0.55, 4.4, 0.55), CFrame.new(-1.35, 4.6, 0.1) * CFrame.Angles(0, 0, 0.05))
	piece("ArmR", Vector3.new(0.55, 4.4, 0.55), CFrame.new(1.35, 4.6, 0.1) * CFrame.Angles(0, 0, -0.05))
	piece("Head", Vector3.one * 1.3, CFrame.new(0, FACE_HEIGHT, -0.35), Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		piece("Eye", Vector3.one * 0.2, CFrame.new(side * 0.25, 7.5, -0.95), Enum.PartType.Ball, EYE_LOST, true)
	end
	model:SetAttribute("EyeSize", 0.2)
	model:SetAttribute("Face", Vector3.new(0, FACE_HEIGHT, -0.35))
end

local function makeFigure(at: Vector3, facing: Vector3): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "LostOne"
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local base = CFrame.lookAt(at, at + (if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis))
	local root = part({ Name = "Root", Size = Vector3.one, CFrame = base, Transparency = 1 })
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = folder
	if not dressImported(model, base) then
		dressBlocks(model, base)
	end
	return model, root
end

local function vanishFigure(model: Model)
	local center = model:GetPivot().Position
	Sounds.Play("FigureVanish", model:FindFirstChild("Head") :: BasePart?, 0.9 + math.random() * 0.2)
	if not Settings.LowEffects() then
		HuntFX.burst(center + Vector3.new(0, 4, 0), FIGURE_COLOR, 18, 5, HuntFX.SMOKE)
	end
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "Root" then
			fadeOut(item, 0.3)
		end
	end
	task.delay(0.4, function()
		model:Destroy()
	end)
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function showLost(id: number, at: Vector3, wrong: boolean)
	local here = rootPosition() or at
	local current = lost
	if current then
		lost = nil
		vanishFigure(current.Model)
	end
	local model, root = makeFigure(at, here - at)
	lost = {
		Id = id,
		Model = model,
		Root = root,
		Wrong = wrong,
		NextTell = os.clock() + 1 + math.random() * 2,
		TwitchUntil = 0,
		TwitchRoll = 0,
	}
	if current and current.Id == id and not Settings.LowEffects() then
		HuntFX.burst(at + Vector3.new(0, 4, 0), FIGURE_COLOR, 12, 4, HuntFX.SMOKE)
	end
	if wrong then
		Sounds.Play("WatcherBreath", model:FindFirstChild("Head") :: BasePart?)
	end
end

-- A brief red flicker of the eyes and a twitch of the head: the False Watcher's only tell.
local function tell(figure: Lost)
	local model = figure.Model
	local seconds = 0.12 + math.random() * 0.1
	local side = if math.random() < 0.5 then -1 else 1
	setEyes(model, EYE_FALSE, 1.3)
	if model:GetAttribute("Imported") then
		figure.TwitchUntil = os.clock() + seconds
		figure.TwitchRoll = side * 0.14
		task.delay(seconds, function()
			if model.Parent and lost == figure then
				setEyes(model, EYE_LOST, 1)
			end
		end)
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local rest = head and figure.Root.CFrame:ToObjectSpace(head.CFrame)
	if head then
		head.CFrame *= CFrame.Angles(0, 0, side * 0.5)
	end
	task.delay(seconds, function()
		if model.Parent and lost == figure then
			setEyes(model, EYE_LOST, 1)
			if head and rest then
				head.CFrame = figure.Root.CFrame * rest
			end
		end
	end)
end

local darkness: ColorCorrectionEffect? = nil

local function grade(): ColorCorrectionEffect
	local effect = darkness or Instance.new("ColorCorrectionEffect")
	effect.Name = "FalseWatcher"
	effect.Parent = Lighting
	darkness = effect
	return effect
end

local blackFrame: Frame? = nil

-- A full-screen black cut (above every other UI).
local function blackout(): Frame
	local existing = blackFrame
	if existing then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FalseWatcherCut"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	blackFrame = frame
	return frame
end

-- Keeps the figure's face a couple of studs in front of the camera, looking into it.
local function inYourFace(model: Model)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local view = camera.CFrame
	local face = view.Position + view.LookVector * 2.4 - view.UpVector * 0.25
	-- Faces straight into the lens, tilted with the camera and tipped back by how far its mask looks
	-- down, so the mask is square to you (the body leans in at you).
	-- DebugFacePitch (degrees, set by /facepitch) overrides it while tuning a model.
	local tuned = Players.LocalPlayer:GetAttribute("DebugFacePitch")
	local pitch = if type(tuned) == "number" then math.rad(tuned) else model:GetAttribute("FacePitch")
	local turn = view.Rotation * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(if type(pitch) == "number" then pitch else 0, 0, 0)
	local jitter = view:VectorToWorldSpace(Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.08)
	model:PivotTo(CFrame.new(face - turn:VectorToWorldSpace(faceOffset(model)) + jitter) * turn)
end

-- Hides every UI (ours, Roblox's, chat and the interaction prompts) except the black cut, and
-- keeps it hidden every frame: other code (the seal view, new toasts) may switch one back on
-- mid-scare. The HideInterface attribute tells per-frame UI (the stamina bar) to stay off.
-- Returns a function that puts back exactly what was showing.
local function hideInterface(): () -> ()
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hidden: { [LayerCollector]: boolean } = {}
	localPlayer:SetAttribute("HideInterface", true)
	local function sweep()
		if not playerGui then
			return
		end
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("LayerCollector") and gui.Enabled and gui.Name ~= "FalseWatcherCut" then
				gui.Enabled = false
				hidden[gui] = true
			end
		end
	end
	sweep()
	local keep = RunService.RenderStepped:Connect(sweep)

	local core: { [Enum.CoreGuiType]: boolean } = {}
	for _, kind in Enum.CoreGuiType:GetEnumItems() do
		if kind ~= Enum.CoreGuiType.All then
			local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
			if ok then
				core[kind] = enabled
			end
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	local chatWindow = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	local chatWindowOn = chatWindow and chatWindow.Enabled
	local chatInputOn = chatInput and chatInput.Enabled
	if chatWindow then
		chatWindow.Enabled = false
	end
	if chatInput then
		chatInput.Enabled = false
	end
	local prompts = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false

	return function()
		keep:Disconnect()
		localPlayer:SetAttribute("HideInterface", nil)
		for gui in hidden do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		for kind, enabled in core do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, enabled)
		end
		if chatWindow and chatWindowOn ~= nil then
			chatWindow.Enabled = chatWindowOn
		end
		if chatInput and chatInputOn ~= nil then
			chatInput.Enabled = chatInputOn
		end
		ProximityPromptService.Enabled = prompts
	end
end

local scaring = false

-- The False Watcher springs: it stares, the world drains of colour, the lights cut out, and its
-- face is in yours. Then it is gone and the colour seeps back.
local function scare(figure: Lost)
	local model = figure.Model
	local head = model:FindFirstChild("Head") :: BasePart?
	local effect = grade()
	effect.Brightness = 0
	effect.Saturation = 0
	effect.Contrast = 0
	effect.TintColor = Color3.new(1, 1, 1)

	setEyes(model, EYE_FALSE, 1.7)
	TweenService:Create(effect, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = -0.45,
		Saturation = -0.85,
		Contrast = 0.25,
		TintColor = Color3.fromRGB(255, 175, 175),
	}):Play()
	if not Sounds.Play("WatcherBreath", head) then
		Sounds.Play("DistantWhisper", head, 0.6)
	end
	task.wait(0.8)

	local black = blackout()
	black.BackgroundTransparency = 0
	task.wait(0.4)

	if model.Parent then
		inYourFace(model)
		local root = figure.Root
		if not model:GetAttribute("Imported") then
			local mouth = part({
				Name = "Mouth",
				Size = Vector3.new(0.55, 0.5, 0.05),
				CFrame = root.CFrame * CFrame.new(0, FACE_HEIGHT - 0.45, -1.0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(70, 0, 0),
			})
			mouth.Parent = model
		end
		if head then
			-- Lights the face from the front (a light behind the mask would leave it dark).
			local front = Instance.new("Attachment")
			front.Position = Vector3.new(0, 0, -1.6)
			front.Parent = head
			local glow = Instance.new("PointLight")
			glow.Color = EYE_FALSE
			glow.Range = 9
			glow.Brightness = 4
			glow.Parent = front
		end
	end
	local follow = RunService.RenderStepped:Connect(function()
		if model.Parent then
			inYourFace(model)
		end
	end)
	black.BackgroundTransparency = 1
	effect.Brightness = -0.15
	effect.Saturation = -0.5
	effect.Contrast = 0.6
	effect.TintColor = Color3.fromRGB(255, 80, 80)
	if not Sounds.Play("WatcherStinger") then
		Sounds.Play("FalseWatcher", nil, 0.9)
	end
	HuntFX.shake(1.4, 0.8)
	task.wait(0.85)

	black.BackgroundTransparency = 0
	follow:Disconnect()
	model:Destroy()
	effect.TintColor = Color3.fromRGB(255, 175, 175)
	effect.Contrast = 0.2
	effect.Brightness = -0.45
	task.wait(0.15)
	TweenService:Create(black, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(effect, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 0,
		Saturation = 0,
		Contrast = 0,
		TintColor = Color3.new(1, 1, 1),
	}):Play()
	task.wait(1.2)
end

local function jumpscare(figure: Lost, drained: number)
	if scaring then
		vanishFigure(figure.Model)
		return
	end
	scaring = true
	local showInterface = hideInterface()
	local ok, problem = pcall(scare, figure)
	showInterface()
	if not ok then
		figure.Model:Destroy()
		if blackFrame then
			blackFrame.BackgroundTransparency = 1
		end
		warn("[WildFinds] False Watcher scare failed:", problem)
	end
	if drained > 0 then
		Toasts.Show(`The False Watcher fed on your Hunt Streak (-x{Format.multiplier(drained)}).`, "Error")
	else
		Toasts.Show("It was the False Watcher... it leaves nothing behind.", "Error")
	end
	scaring = false
end

local function endLost(id: number, result: string, tierId: string?, text: string?, drained: number)
	local current = lost
	if not current or current.Id ~= id then
		if result == "Gift" and tierId then
			Toasts.Show(`Spirit Gift - {tierName(tierId)}: {text or ""}`, "Item")
		end
		return
	end
	lost = nil
	local model = current.Model
	local head = model:FindFirstChild("Head") :: BasePart?
	if result == "Gift" and tierId then
		local color = tierColor(tierId)
		-- Kneel, glow, then fade, leaving the gift's burst behind.
		TweenService:Create(current.Root, TweenInfo.new(0.5), { CFrame = current.Root.CFrame * CFrame.new(0, -2, 0) }):Play()
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item ~= current.Root then
				TweenService:Create(item, TweenInfo.new(0.5), { CFrame = item.CFrame * CFrame.new(0, -2, 0) }):Play()
			end
		end
		local at = current.Root.Position
		HuntFX.burst(at + Vector3.new(0, 1.5, 0), color, if Settings.LowEffects() then 12 else 40, 12)
		HuntFX.shockwave(at, color, 16, 0.7)
		if not Sounds.Play("SpiritGift", head) then
			Sounds.Play("Shine", nil, 0.85)
		end
		Toasts.Show(`Spirit Gift - {tierName(tierId)}: {text or ""}`, "Item")
		task.delay(0.9, vanishFigure, model)
	elseif result == "False" then
		task.spawn(jumpscare, current, drained)
	elseif result == "Scared" then
		Toasts.Show("Your pulse scared the Lost One away.")
		-- Let the fog lift first so it can be glimpsed.
		task.delay(0.35, vanishFigure, model)
	else
		vanishFigure(model)
	end
end

local function onPayload(payload: { [string]: any })
	local kind = payload.Kind
	if kind == "Strike" then
		onStrike(payload)
	elseif kind == "Offering" then
		if type(payload.Id) == "number" and typeof(payload.Position) == "Vector3" then
			spawnBox(payload.Id, payload.Position, tonumber(payload.ExpiresAt) or 0)
		end
	elseif kind == "OfferingGone" then
		local current = box
		if current and current.Id == payload.Id then
			removeBox(true)
		end
	elseif kind == "OfferingOpened" then
		if type(payload.Id) == "number" and type(payload.Tier) == "string" then
			openBox(payload.Id, payload.Tier, tostring(payload.Text or ""))
		end
	elseif kind == "LostOne" then
		if type(payload.Id) == "number" and typeof(payload.Position) == "Vector3" then
			showLost(payload.Id, payload.Position, payload.Wrong == true)
		end
	elseif kind == "LostOneEnd" then
		if type(payload.Id) == "number" and type(payload.Result) == "string" then
			local drained = if type(payload.Drained) == "number" then payload.Drained else 0
			endLost(payload.Id, payload.Result, payload.Tier, payload.Text, drained)
		end
	end
end

function WildFinds.Start()
	folder.Parent = workspace
	WildFind.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			onPayload(payload)
		end
	end)
	SpiritSight.Pulsed:Connect(function()
		if lost then
			WildFindAction:FireServer("Pulse")
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local current = box
		if current then
			if workspace:GetServerTimeNow() > current.ExpiresAt + 2 then
				removeBox(true)
			elseif now >= current.NextChime then
				current.NextChime = now + CHIME_EVERY
				Sounds.Play("OfferingChime", current.Lid, 0.95 + math.random() * 0.1)
			end
		end
		local figure = lost
		local here = rootPosition()
		if figure and here then
			local at = figure.Root.Position
			local gap = Vector3.new(here.X - at.X, 0, here.Z - at.Z)
			if gap.Magnitude > 0.1 then
				local pivot = CFrame.lookAt(at, at + gap.Unit)
				if now < figure.TwitchUntil then
					local face = faceOffset(figure.Model)
					pivot *= CFrame.new(face) * CFrame.Angles(0, 0, figure.TwitchRoll) * CFrame.new(-face)
				end
				figure.Model:PivotTo(pivot)
			end
			if figure.Wrong and now >= figure.NextTell then
				figure.NextTell = now + 2 + math.random() * 3
				tell(figure)
			end
		end
	end)
	SignalsUpdated.OnClientEvent:Connect(function(list)
		if type(list) ~= "table" then
			return
		end
		local seen = {}
		for _, signal in list do
			if type(signal) == "table" and type(signal.Id) == "number" and typeof(signal.Position) == "Vector3" then
				local untilTime = signal.StruckUntil
				if type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow() then
					seen[signal.Id] = true
					setStruck(signal.Id, signal.Position, untilTime)
				end
			end
		end
		for id in struck do
			if not seen[id] then
				clearStruck(id)
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local clock = os.clock()
		local low = Settings.LowEffects()
		for id, entry in struck do
			if now > entry.Until then
				clearStruck(id)
				continue
			end
			local orb = SpiritSight.GetOrb(id)
			if entry.Glow.Adornee ~= orb then
				entry.Glow.Adornee = orb
			end
			if not low and clock >= entry.NextArc then
				entry.NextArc = clock + 0.25 + math.random() * 0.6
				arc(if orb then orb.Position else entry.Holder.Position, 2.5 + math.random() * 1.5)
			end
		end
	end)
end

return WildFinds
