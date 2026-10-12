-- Client-only Hold to Bind presentation for the local player. On lock: chains shoot from the palm
-- into the spirit (ChainRig), the body snaps into the seal pose (SealPose) and the camera punches
-- in. Through the hold: the talismans ignite one by one (SpiritSight), the chains jerk tight with
-- a clink and a camera kick at each beat, the view darkens and closes in, the shake grows. At
-- PullAt: the suck sound and a two-handed yank. Nothing here hints at rarity; the relic's own
-- presentation plays only after the validated capture (SealBurst, CaptureAnimation).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local ChainRig = require(script.Parent.ChainRig)
local HuntFX = require(script.Parent.HuntFX)
local SealBurst = require(script.Parent.SealBurst)
local SealPose = require(script.Parent.SealPose)
local SpiritSight = require(script.Parent.SpiritSight)

local BindEffects = {}

local CHAIN_COLOR = Color3.fromRGB(190, 150, 255)
local CHAIN_COUNT = 3
-- Seconds the chains take to reach the spirit after the lock.
local REACH_SECONDS = 0.2
-- Field of view lost by the end of the hold, and the quick punch-in at the lock.
local FOV_CLOSE_IN = 12
local FOV_PUNCH = 6

type Active = {
	Core: BasePart,
	Target: Attachment,
	Base: Vector3,
	Root: BasePart,
	Rig: ChainRig.Rig,
	Pose: SealPose.Pose?,
	CameraType: Enum.CameraType,
	FieldOfView: number,
	View: CFrame,
	Grade: ColorCorrectionEffect,
	Clock: number,
	-- Sounds stopped with the bind, and how many progress beats already played.
	Sounds: { Sound },
	Beats: number,
	-- 1 right after a beat, fading: extra camera kick.
	Kick: number,
}

local active: Active? = nil
-- Hands the camera back early when a seal view is still holding it.
local heldRelease: (() -> ())? = nil

local function releaseHeldCamera()
	local release = heldRelease
	heldRelease = nil
	if release then
		release()
	end
end

local function flatUnit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
end

function BindEffects.Start(id: number)
	BindEffects.Stop()
	releaseHeldCamera()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local core = SpiritSight.Bind(id, root.Position)
	local target = core and core:FindFirstChild("Core")
	if not core or not target or not target:IsA("Attachment") then
		SpiritSight.Unbind()
		return
	end

	local facing = Vector3.new(core.Position.X, root.Position.Y, core.Position.Z)
	if (facing - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, facing)
	end

	local low = Settings.LowEffects()
	local rig = ChainRig.Attach(character, target, { Color = CHAIN_COLOR, Count = CHAIN_COUNT, Low = low })
	if not rig then
		SpiritSight.Unbind()
		return
	end
	local sounds: { Sound } = {}
	Sounds.Play("Lock")
	local rattle = Sounds.Loop("ChainRattle")
	if rattle then
		table.insert(sounds, rattle)
	end
	local riser = Sounds.Play("BindRiser")
	if riser then
		table.insert(sounds, riser)
	end
	if not low then
		HuntFX.burst(target.WorldPosition, CHAIN_COLOR, 18, 10)
	end

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "BindGrade"
	grade.Parent = Lighting
	local camera = workspace.CurrentCamera
	active = {
		Core = core,
		Target = target,
		Base = core.Position,
		Root = root,
		Rig = rig,
		Pose = SealPose.Start(character),
		CameraType = camera.CameraType,
		FieldOfView = camera.FieldOfView,
		View = camera.CFrame,
		Grade = grade,
		Clock = 0,
		Sounds = sounds,
		Beats = 0,
		Kick = 1,
	}
	camera.CameraType = Enum.CameraType.Scriptable
end

-- progress goes 0..1 over the hold.
function BindEffects.Update(dt: number, progress: number)
	local state = active
	if not state or not state.Core.Parent then
		return
	end
	state.Clock += dt
	local t = state.Clock
	local beat = Config.Bind.TightenAt[state.Beats + 1]
	if beat and progress >= beat then
		state.Beats += 1
		Sounds.Play("ChainTighten")
		ChainRig.Snap(state.Rig)
		state.Kick = 1
	elseif not beat and state.Beats == #Config.Bind.TightenAt and progress >= Config.Bind.PullAt then
		state.Beats += 1
		Sounds.Play("SealSuck")
		ChainRig.Snap(state.Rig)
		state.Kick = 1
	end
	state.Kick = math.max(0, state.Kick - dt * 4)

	local tug = SealPose.Tug(t, progress)
	SpiritSight.BindStep(dt, progress, state.Rig.Hand.WorldPosition, tug)
	if state.Pose then
		state.Pose.Update(t, progress, state.Target.WorldPosition, state.Kick)
	end
	ChainRig.Update(state.Rig, t, progress, math.min(1, t / REACH_SECONDS), math.abs(tug))

	state.Grade.Contrast = 0.1 + progress * 0.25
	state.Grade.Saturation = -0.1 - progress * 0.4
	state.Grade.Brightness = -progress * 0.05

	-- Three-quarter view from behind the chain (right) hand: the player on the left of the
	-- screen, the spirit on the right, the chains between. Widens with the distance so both fit,
	-- dollies in as the bind tightens, with a growing rumble.
	local camera = workspace.CurrentCamera
	local root = state.Root.Position
	local forward = flatUnit(state.Base - root)
	local right = forward:Cross(Vector3.yAxis)
	local gap = Vector3.new(state.Base.X - root.X, 0, state.Base.Z - root.Z).Magnitude
	local close = 1 - progress * 0.2
	local eye = root
		- forward * (4 * close)
		+ right * ((5 + gap * 0.4) * close)
		+ Vector3.new(0, 2.5 + progress * 0.5, 0)
	local focus = root:Lerp(state.Base, 0.5) + Vector3.new(0, 0.5, 0)
	local goal = CFrame.lookAt(eye, focus)
	state.View = state.View:Lerp(goal, 1 - math.exp(-dt * 6))
	local rumble = 0.02 + progress * 0.08 + state.Kick * 0.25 + math.abs(tug) * 0.06
	local noise = CFrame.new(math.noise(t * 20, 1.7) * rumble, math.noise(t * 20, 4.2) * rumble, 0)
	camera.CFrame = state.View * noise * HuntFX.shakeOffset()
	local punch = math.sin(math.min(1, t / 0.3) * math.pi) * FOV_PUNCH
	camera.FieldOfView = state.FieldOfView - progress * FOV_CLOSE_IN - punch - state.Kick * 3
end

-- Ends the bind look. `holdSeconds`: keep the bind camera that long, turning to watch the seal
-- where the spirit was, before handing the camera back.
function BindEffects.Stop(holdSeconds: number?)
	local state = active
	if not state then
		return
	end
	active = nil
	for _, sound in state.Sounds do
		sound:Destroy()
	end
	state.Rig.Restore()
	if state.Pose then
		state.Pose.Restore()
	end
	SpiritSight.Unbind()
	state.Grade:Destroy()

	local camera = workspace.CurrentCamera
	local cameraType, fieldOfView = state.CameraType, state.FieldOfView
	local function restore()
		camera.CameraType = cameraType
		camera.FieldOfView = fieldOfView
	end
	if not holdSeconds or holdSeconds <= 0 then
		restore()
		return
	end
	-- The player acts out the seal (SealPose.Finale) with the jar in the same shot.
	local character = state.Root.Parent
	local finale = if character and character:IsA("Model") then SealPose.Finale(character, SealBurst.SlamAt) else nil
	local view = state.View
	local focus = state.Root.Position:Lerp(state.Base, 0.6)
	local start = os.clock()
	local connection = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - start
		if elapsed >= holdSeconds then
			releaseHeldCamera()
			return
		end
		if finale then
			finale.Update(elapsed, 0, focus, 0)
		end
		view = view:Lerp(CFrame.lookAt(view.Position, focus), 1 - math.exp(-dt * 3))
		camera.CFrame = view * HuntFX.shakeOffset()
		camera.FieldOfView += (fieldOfView - camera.FieldOfView) * (1 - math.exp(-dt * 4))
	end)
	heldRelease = function()
		connection:Disconnect()
		if finale then
			finale.Restore()
		end
		restore()
	end
end

return BindEffects
