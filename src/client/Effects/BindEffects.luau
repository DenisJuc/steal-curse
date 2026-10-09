-- Client-only Hold to Bind visuals: spectral chains from the hand into the signal core,
-- the core resisting, camera framing, and the seal impact. Greybox for Slice 1;
-- avatar gestures and per-object animation families arrive in Slice 6.

local Players = game:GetService("Players")

local BindEffects = {}

local CHAIN_COLOR = Color3.fromRGB(190, 150, 255)
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local CHAIN_COUNT = 3

type Active = {
	Orb: Part,
	Base: CFrame,
	Root: BasePart,
	Hand: Attachment,
	Beams: { Beam },
	CameraType: Enum.CameraType,
	Clock: number,
}

local active: Active? = nil

local function handOf(character: Model, root: BasePart): Attachment
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
	local attachment = Instance.new("Attachment")
	attachment.Name = "BindHand"
	attachment.Parent = hand
	return attachment
end

function BindEffects.Start(orb: Part)
	BindEffects.Stop()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local core = orb:FindFirstChild("Core")
	if not character or not root or not root:IsA("BasePart") or not core or not core:IsA("Attachment") then
		return
	end

	local target = Vector3.new(orb.Position.X, root.Position.Y, orb.Position.Z)
	if (target - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, target)
	end

	local hand = handOf(character, root)
	local beams = {}
	for index = 1, CHAIN_COUNT do
		local beam = Instance.new("Beam")
		beam.Attachment0 = hand
		beam.Attachment1 = core
		beam.Color = ColorSequence.new(CHAIN_COLOR)
		beam.LightEmission = 1
		beam.Width0 = 0.25
		beam.Width1 = 0.45
		beam.Texture = SPARKLES
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 1.5
		beam.TextureSpeed = -3
		beam.FaceCamera = true
		beam.Segments = 20
		beam:SetAttribute("Phase", index * 2.1)
		beam.Parent = hand
		table.insert(beams, beam)
	end

	orb:SetAttribute("Binding", true)
	local camera = workspace.CurrentCamera
	active = {
		Orb = orb,
		Base = orb.CFrame,
		Root = root,
		Hand = hand,
		Beams = beams,
		CameraType = camera.CameraType,
		Clock = 0,
	}
	camera.CameraType = Enum.CameraType.Scriptable
end

-- progress goes 0..1 over the hold.
function BindEffects.Update(dt: number, progress: number)
	local state = active
	if not state or not state.Orb.Parent then
		return
	end
	state.Clock += dt
	local t = state.Clock

	-- The core resists harder as the bind tightens, then is pulled toward the hand at the end.
	local shake = 0.15 + progress * 0.45
	local jitter = Vector3.new(math.sin(t * 37) * shake, math.sin(t * 29 + 1) * shake, math.cos(t * 41) * shake)
	local pull = math.max(0, progress - 0.8) / 0.2
	local handPosition = state.Hand.WorldPosition
	local position = state.Base.Position:Lerp(handPosition, pull * 0.35) + jitter
	state.Orb.CFrame = CFrame.new(position)
	local size = 2.4 * (1 + progress * 0.3)
	state.Orb.Size = Vector3.new(size, size, size)

	for _, beam in state.Beams do
		local phase = beam:GetAttribute("Phase") or 0
		beam.CurveSize0 = math.sin(t * 6 + phase) * (2 - progress * 1.5)
		beam.CurveSize1 = math.cos(t * 5 + phase) * (2 - progress * 1.5)
		beam.Width0 = 0.25 + progress * 0.2
	end

	local camera = workspace.CurrentCamera
	local root = state.Root.Position
	local away = root - state.Base.Position
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
	local side = away:Cross(Vector3.yAxis)
	local eye = root + away * 9 + side * 4 + Vector3.new(0, 5, 0)
	local focus = root:Lerp(state.Base.Position, 0.6)
	local goal = CFrame.lookAt(eye, focus)
	camera.CFrame = camera.CFrame:Lerp(goal, 1 - math.exp(-dt * 6))
end

function BindEffects.Stop()
	local state = active
	if not state then
		return
	end
	active = nil
	state.Hand:Destroy()
	if state.Orb.Parent then
		state.Orb:SetAttribute("Binding", nil)
		state.Orb.Size = Vector3.new(2.4, 2.4, 2.4)
	end
	workspace.CurrentCamera.CameraType = state.CameraType
end

-- Short impact flash where the relic was sealed.
function BindEffects.Seal(position: Vector3)
	local flash = Instance.new("Part")
	flash.Name = "SealFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(235, 220, 255)
	flash.Size = Vector3.new(2, 2, 2)
	flash.CFrame = CFrame.new(position)
	flash.Parent = workspace

	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.5 do
			local t = (os.clock() - start) / 0.5
			local size = 2 + t * 14
			flash.Size = Vector3.new(size, size, size)
			flash.Transparency = t
			task.wait()
		end
		flash:Destroy()
	end)
end

return BindEffects
