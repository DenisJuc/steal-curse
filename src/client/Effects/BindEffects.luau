-- Client-only Hold to Bind visuals for the local player: arm raised toward the signal, spectral
-- chains from the hand into the core (ChainRig), the core resisting, and camera framing.
-- The bind itself never hints at rarity; the relic's family animation plays only after the
-- validated capture (CaptureAnimation).

local Players = game:GetService("Players")

local ChainRig = require(script.Parent.ChainRig)

local BindEffects = {}

local CHAIN_COLOR = Color3.fromRGB(190, 150, 255)
local CHAIN_COUNT = 3

type Active = {
	Orb: Part,
	Base: CFrame,
	Root: BasePart,
	Rig: ChainRig.Rig,
	CameraType: Enum.CameraType,
	Clock: number,
}

local active: Active? = nil

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

	local rig = ChainRig.Attach(character, core, CHAIN_COLOR, CHAIN_COUNT)
	if not rig then
		return
	end
	orb:SetAttribute("Binding", true)
	local camera = workspace.CurrentCamera
	active = {
		Orb = orb,
		Base = orb.CFrame,
		Root = root,
		Rig = rig,
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
	local handPosition = state.Rig.Hand.WorldPosition
	local position = state.Base.Position:Lerp(handPosition, pull * 0.35) + jitter
	state.Orb.CFrame = CFrame.new(position)
	local size = 2.4 * (1 + progress * 0.3)
	state.Orb.Size = Vector3.new(size, size, size)
	ChainRig.Update(state.Rig, t, progress)

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
	state.Rig.Restore()
	if state.Orb.Parent then
		state.Orb:SetAttribute("Binding", nil)
		state.Orb.Size = Vector3.new(2.4, 2.4, 2.4)
	end
	workspace.CurrentCamera.CameraType = state.CameraType
end

function BindEffects.Seal(position: Vector3)
	ChainRig.SealFlash(position)
end

return BindEffects
