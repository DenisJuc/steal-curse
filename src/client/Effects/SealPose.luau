-- Procedural seal pose for R15 and R6 characters: a braced, crouched stance (R15) with the right
-- palm thrust at the target and the left hand across gripping the right wrist. The lock jolts the
-- body forward, then a tug of war (SealPose.Tug): the player hauls back, leaning on their heels
-- with arms pulled in, and the spirit drags them forward again, harder and faster as the bind
-- tightens. Every chain beat yanks the body forward for a moment, and the pull ends in a
-- two-handed yank back with the right foot stepping back. Offsets each joint on top of whatever animation plays; Restore puts them back.
-- Works with classic Motor6D joints (offsets C0) and the newer AnimationConstraint joints
-- (offsets the parent-side attachment, which plays the same role). Client-only: these changes
-- never replicate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SealPose = {}

export type Pose = {
	-- `clock`: seconds since the bind locked on. `target`: world point the palm aims at.
	-- `kick`: 1 right after a chain beat, fading to 0 (the spirit yanks the body forward).
	Update: (clock: number, progress: number, target: Vector3, kick: number?) -> (),
	Restore: () -> (),
}

type Joint = {
	Kind: string,
	Get: () -> CFrame,
	Set: (CFrame) -> (),
	Alive: () -> boolean,
}

-- Rig-independent motion for one frame (angles in radians, 0..1 weights).
type Drive = {
	Thrust: number,
	Stance: number,
	Pull: number,
	Yank: number,
	Jolt: number,
	Struggle: number,
	ShakeA: number,
	ShakeB: number,
	Elevation: number,
	-- Tug of war: Heave 0..1 while the player hauls back, Resist 0..1 while the spirit drags
	-- them forward.
	Heave: number,
	Resist: number,
	-- Whole-body lean pivoting on the feet, and the extra bend at the waist; positive is back.
	BodyLean: number,
	WaistLean: number,
	-- BodyLean + WaistLean.
	Lean: number,
	Twist: number,
}

local LOCK_SECONDS = 0.25

-- Pose joint name -> the body part that joint moves.
local R15_PARTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
}

local R6_PARTS = {
	Root = "Torso",
	Neck = "Head",
	RightShoulder = "Right Arm",
	LeftShoulder = "Left Arm",
	RightHip = "Right Leg",
	LeftHip = "Left Leg",
}

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function motorJoint(motor: Motor6D): Joint
	return {
		Kind = "Motor6D",
		Get = function()
			return motor.C0
		end,
		Set = function(value)
			motor.C0 = value
		end,
		Alive = function()
			return motor.Parent ~= nil
		end,
	}
end

local function constraintJoint(constraint: AnimationConstraint, attachment: Attachment): Joint
	return {
		Kind = "AnimationConstraint",
		Get = function()
			return attachment.CFrame
		end,
		Set = function(value)
			attachment.CFrame = value
		end,
		Alive = function()
			return constraint.Parent ~= nil and attachment.Parent ~= nil
		end,
	}
end

-- Every joint that moves a body part, keyed by that part's name. An enabled AnimationConstraint
-- wins over a Motor6D for the same part.
local function findJoints(character: Model): { [string]: Joint }
	local found: { [string]: Joint } = {}
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 and item.Enabled then
			local name = item.Part1.Name
			if not found[name] then
				found[name] = motorJoint(item)
			end
		elseif item:IsA("AnimationConstraint") and item.Enabled then
			local child, parentSide = item.Attachment1, item.Attachment0
			if child and parentSide and child.Parent then
				found[child.Parent.Name] = constraintJoint(item, parentSide)
			end
		end
	end
	return found
end

local function tremble(clock: number, progress: number, rate: number, phase: number): number
	return math.sin(clock * rate + phase) * (0.015 + progress * 0.06)
end

-- Tug-of-war rhythm shared with the spirit and chains: positive while the player hauls back,
-- negative while the spirit drags them forward. Faster and stronger as the bind tightens; gone
-- once the final pull starts.
function SealPose.Tug(clock: number, progress: number): number
	local wave = math.sin(clock * (4 + progress * 2.5))
	local pull = math.clamp((progress - Config.Bind.PullAt) / (1 - Config.Bind.PullAt), 0, 1)
	local stance = 1 - (1 - math.min(1, clock / LOCK_SECONDS)) ^ 2
	return math.sign(wave) * math.abs(wave) ^ 1.5 * (0.5 + 0.5 * progress) * (1 - pull) * stance
end

local function drive(clock: number, progress: number, kick: number?, aimFrom: Vector3, target: Vector3): Drive
	local yank = kick or 0
	local lock = math.min(1, clock / LOCK_SECONDS)
	local stance = 1 - (1 - lock) ^ 2
	local pull = math.clamp((progress - Config.Bind.PullAt) / (1 - Config.Bind.PullAt), 0, 1)
	pull = 1 - (1 - pull) ^ 3
	local tug = SealPose.Tug(clock, progress)
	local heave, resist = math.max(0, tug), math.max(0, -tug)
	-- Side-to-side struggle that grows as the spirit fights harder.
	local struggle = math.sin(clock * 2.6) * (0.06 + progress * 0.15)
	-- The lock jolts the body forward before it braces back.
	local jolt = math.max(0, 1 - clock / 0.35) * stance
	local delta = target - aimFrom
	local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local bodyLean = math.max(
		-math.rad(10),
		(math.rad(8) + math.rad(10) * progress) * stance
			+ math.rad(12) * heave
			- math.rad(12) * resist
			- math.rad(14) * yank
			- math.rad(12) * jolt
			+ math.rad(14) * pull
	)
	local waistLean = math.rad(6) * stance
		+ math.rad(10) * heave
		- math.rad(8) * resist
		- math.rad(8) * yank
		+ math.rad(12) * pull
	return {
		Thrust = easeOutBack(lock),
		Stance = stance,
		Pull = pull,
		Yank = yank,
		Jolt = jolt,
		Struggle = struggle,
		ShakeA = tremble(clock, progress, 41, 0),
		ShakeB = tremble(clock, progress, 33, 1.3),
		Elevation = math.clamp(math.atan2(delta.Y, math.max(flat, 0.1)), -0.6, 0.9),
		Heave = heave,
		Resist = resist,
		BodyLean = bodyLean,
		WaistLean = waistLean,
		Lean = bodyLean + waistLean,
		Twist = math.rad(25) * pull + math.rad(12) * heave + struggle * 0.6,
	}
end

type Set = (name: string, offset: CFrame) -> ()

-- R15 joints all rotate about their own X for "forward" (identity-oriented C0s).
-- `pivot`: studs from the root joint down to the soles, where the whole-body lean turns.
local function applyR15(set: Set, d: Drive, progress: number, legLength: number, pivot: number)
	-- Legs bend at hip, knee and ankle; the root drops by what the bend shortens them, so the feet
	-- stay planted. Heaving sits deeper; a beat (yank) pulls the body down for a moment.
	local crouch = (math.rad(24) + math.rad(8) * progress + math.rad(8) * d.Heave + math.rad(10) * d.Yank) * d.Stance
	local splay = math.rad(12) * d.Stance
	-- Tug of war: the whole body leans back (or is dragged forward) pivoting on the feet.
	local lean = CFrame.new(0, -pivot, 0) * CFrame.Angles(d.BodyLean, 0, d.Struggle * 0.4) * CFrame.new(0, pivot, 0)
	set("Root", CFrame.new(0, -legLength * (1 - math.cos(crouch)), 0) * lean)
	-- Dragged forward, the left foot braces ahead; the final yank steps the right foot back. The
	-- ankles take the body lean back out so the soles stay flat.
	local brace = math.rad(14) * d.Resist
	set("RightHip", CFrame.Angles(crouch - math.rad(30) * d.Pull, 0, splay))
	set("LeftHip", CFrame.Angles(crouch + brace + math.rad(8) * d.Pull, 0, -splay))
	set("RightKnee", CFrame.Angles(-crouch * 2 + math.rad(15) * d.Pull, 0, 0))
	set("LeftKnee", CFrame.Angles(-crouch * 2 - brace, 0, 0))
	set("RightAnkle", CFrame.Angles(crouch - d.BodyLean + math.rad(15) * d.Pull, 0, 0))
	set("LeftAnkle", CFrame.Angles(crouch - d.BodyLean, 0, 0))
	set("Waist", CFrame.Angles(d.WaistLean, d.Twist, -d.Struggle))
	-- Head stays on the target, thrown back when heaving, shaking with effort.
	set(
		"Neck",
		CFrame.Angles(
			-d.Lean * 0.7 + d.Elevation * 0.5 + math.rad(10) * d.Heave - math.rad(8) * d.Resist + d.ShakeB * 0.5,
			-d.Twist * 0.7,
			d.Struggle * 0.6 + d.ShakeA
		)
	)

	-- Right palm pushed at the target (the lean is taken back out) with the hand bent back, left
	-- hand across the body gripping the right wrist. Heaving hauls both arms in toward the chest,
	-- the spirit's drag straightens them out, the final pull yanks them all the way in.
	local reach = math.rad(90) + d.Elevation - d.Lean
	local haul = math.rad(28) * d.Heave
	local rightPitch = reach * d.Thrust
		- haul
		+ math.rad(10) * d.Resist
		+ math.rad(10) * d.Yank
		- math.rad(60) * d.Pull
		+ d.ShakeA
	set("RightShoulder", CFrame.Angles(0, math.rad(8) * d.Thrust + d.ShakeB, 0) * CFrame.Angles(rightPitch, 0, 0))
	set("RightElbow", CFrame.Angles(math.rad(5) + math.rad(50) * d.Heave + math.rad(85) * d.Pull, 0, 0))
	set("RightWrist", CFrame.Angles(math.rad(60) * d.Thrust * (1 - d.Pull) * (1 - d.Heave * 0.5), 0, 0))
	local leftPitch = (reach - math.rad(10)) * d.Stance
		- haul
		+ math.rad(8) * d.Resist
		+ math.rad(8) * d.Yank
		- math.rad(50) * d.Pull
		+ d.ShakeB
	set("LeftShoulder", CFrame.Angles(0, -math.rad(48) * d.Stance, 0) * CFrame.Angles(leftPitch, 0, 0))
	set("LeftElbow", CFrame.Angles(math.rad(55) * d.Stance + math.rad(35) * d.Heave + math.rad(30) * d.Pull + d.ShakeA, 0, 0))
	set("LeftWrist", CFrame.Angles(math.rad(20) * d.Stance, 0, 0))
end

-- R6 joints are turned: shoulders and hips swing forward about Z (right +, left -), the root and
-- neck lean forward about X and twist about Z. No knees, so no crouch.
local function applyR6(set: Set, d: Drive)
	local splay = math.rad(10) * d.Stance
	set("Root", CFrame.Angles(-d.Lean, d.Struggle * 0.5, d.Twist))
	set("Neck", CFrame.Angles(d.Lean * 0.8 - d.Elevation * 0.5 + d.ShakeB * 0.5, d.ShakeA, -d.Twist * 0.7))
	-- Legs counter the torso lean so the feet stay under the body; the right foot steps back.
	set("RightHip", CFrame.Angles(-splay, 0, -d.Lean - math.rad(25) * d.Pull))
	set("LeftHip", CFrame.Angles(-splay, 0, d.Lean - math.rad(8) * d.Pull))

	local reach = math.rad(90) + d.Elevation - d.Lean
	local rightPitch = reach * d.Thrust - math.rad(50) * d.Pull + math.rad(10) * d.Yank + d.ShakeA
	set("RightShoulder", CFrame.Angles(0, math.rad(8) * d.Thrust + d.ShakeB, 0) * CFrame.Angles(0, 0, rightPitch))
	local leftPitch = (reach - math.rad(10)) * d.Stance - math.rad(45) * d.Pull + math.rad(8) * d.Yank + d.ShakeB
	set("LeftShoulder", CFrame.Angles(0, -math.rad(40) * d.Stance, 0) * CFrame.Angles(0, 0, -leftPitch))
end

-- Joint types found on a character, for /sealpose.
function SealPose.Describe(character: Model): string
	local counts: { [string]: number } = {}
	for _, joint in findJoints(character) do
		counts[joint.Kind] = (counts[joint.Kind] or 0) + 1
	end
	local parts = {}
	for kind, count in counts do
		table.insert(parts, `{count} {kind}`)
	end
	local rig = if character:FindFirstChild("RightUpperArm")
		then "R15"
		elseif character:FindFirstChild("Torso") then "R6"
		else "unknown rig"
	return `{rig}, joints: {if #parts > 0 then table.concat(parts, ", ") else "none"}`
end

type Rig = {
	IsR15: boolean,
	AimPart: BasePart,
	LegLength: number,
	Pivot: number,
	Set: Set,
	Restore: () -> (),
}

-- The character's posable joints with their resting offsets, or nil (with a warning) if it has no
-- arm joint to pose.
local function rigFor(character: Model): Rig?
	local all = findJoints(character)
	local isR15 = all.RightUpperArm ~= nil
	local map = if isR15 then R15_PARTS else R6_PARTS
	local aimPart = character:FindFirstChild(if isR15 then "RightUpperArm" else "Right Arm")
	if not aimPart or not aimPart:IsA("BasePart") or not all[aimPart.Name] then
		warn(`[SealPose] no arm joint found ({SealPose.Describe(character)}); the seal pose is skipped`)
		return nil
	end
	local joints: { [string]: Joint } = {}
	local originals: { [string]: CFrame } = {}
	for name, partName in map do
		local joint = all[partName]
		if joint then
			joints[name] = joint
			originals[name] = joint.Get()
		end
	end
	local legLength = 2
	local upperLeg = character:FindFirstChild("RightUpperLeg")
	local lowerLeg = character:FindFirstChild("RightLowerLeg")
	if upperLeg and lowerLeg and upperLeg:IsA("BasePart") and lowerLeg:IsA("BasePart") then
		legLength = upperLeg.Size.Y + lowerLeg.Size.Y
	end
	-- Root joint (about the lower torso's center) down to the soles, measured standing.
	local pivot = legLength + 1
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local foot = character:FindFirstChild("RightFoot")
	if lowerTorso and foot and lowerTorso:IsA("BasePart") and foot:IsA("BasePart") then
		pivot = math.max(1, lowerTorso.Position.Y - (foot.Position.Y - foot.Size.Y / 2))
	end

	return {
		IsR15 = isR15,
		AimPart = aimPart,
		LegLength = legLength,
		Pivot = pivot,
		Set = function(name, offset)
			local joint = joints[name]
			if joint and joint.Alive() then
				joint.Set(originals[name] * offset)
			end
		end,
		Restore = function()
			for name, joint in joints do
				if joint.Alive() then
					joint.Set(originals[name])
				end
			end
		end,
	}
end

function SealPose.Start(character: Model): Pose?
	local rig = rigFor(character)
	if not rig then
		return nil
	end
	return {
		Update = function(clock, progress, target, kick)
			local d = drive(clock, progress, kick, rig.AimPart.Position, target)
			if rig.IsR15 then
				applyR15(rig.Set, d, progress, rig.LegLength, rig.Pivot)
			else
				applyR6(rig.Set, d)
			end
		end,
		Restore = rig.Restore,
	}
end

-- Finale after a capture, as keyframes: a body shape (degrees; arm yaw positive turns the arm in
-- across the chest) at a time. Times are fractions of the way to the jar slam (Before) or
-- seconds after it (After); poses blend between keyframes with the next keyframe's easing.
type Body = {
	Lean: number,
	Crouch: number,
	Neck: number,
	RPitch: number,
	RYaw: number,
	RElbow: number,
	LPitch: number,
	LYaw: number,
	LElbow: number,
	-- Tremble strength 0..1.
	Shake: number,
}

type Key = { Before: number?, After: number?, Ease: string, Body: Body }

local function body(
	lean: number,
	crouch: number,
	neck: number,
	rPitch: number,
	rYaw: number,
	rElbow: number,
	lPitch: number,
	lYaw: number,
	lElbow: number,
	shake: number
): Body
	return {
		Lean = lean,
		Crouch = crouch,
		Neck = neck,
		RPitch = rPitch,
		RYaw = rYaw,
		RElbow = rElbow,
		LPitch = lPitch,
		LYaw = lYaw,
		LElbow = lElbow,
		Shake = shake,
	}
end

local FINALE: { Key } = {
	-- Arms still in from the final yank.
	{ Before = 0, Ease = "Out", Body = body(10, 15, 0, 40, 10, 70, 35, 10, 70, 0) },
	-- Two-handed mudra at the chest while the jar rises.
	{ Before = 0.25, Ease = "Out", Body = body(0, 12, -10, 55, 40, 75, 55, 40, 75, 0.3) },
	-- Pushing the seal at the jar while it swallows the spirit, straining harder.
	{ Before = 0.75, Ease = "InOut", Body = body(-6, 20, -15, 75, 22, 25, 75, 22, 25, 1) },
	-- Wind-up: both hands raised high.
	{ Before = 0.93, Ease = "Out", Body = body(8, 10, 5, 150, 15, 30, 150, 15, 30, 0.4) },
	-- Slam down with the jar.
	{ After = 0.03, Ease = "In", Body = body(-22, 32, -20, 50, 20, 5, 50, 20, 5, 0) },
	{ After = 0.35, Ease = "InOut", Body = body(-18, 28, -15, 45, 18, 10, 45, 18, 10, 0) },
	-- Rise and hold a hand out to the relic as it comes up.
	{ After = 0.6, Ease = "InOut", Body = body(4, 6, 15, 70, 10, 20, 10, 0, 20, 0) },
	{ After = 0.85, Ease = "InOut", Body = body(0, 0, 0, 0, 0, 0, 0, 0, 0, 0) },
}

local EASES: { [string]: (number) -> number } = {
	In = function(t)
		return t * t * t
	end,
	Out = function(t)
		return 1 - (1 - t) ^ 3
	end,
	InOut = function(t)
		return t * t * (3 - 2 * t)
	end,
}

local function keyTime(key: Key, slamAt: number): number
	return if key.Before then key.Before * slamAt else slamAt + (key.After :: number)
end

local function blend(a: Body, b: Body, t: number): Body
	local mixed = {}
	for field, value in a :: any do
		mixed[field] = value + ((b :: any)[field] - value) * t
	end
	return (mixed :: any) :: Body
end

local function sampleFinale(clock: number, slamAt: number): Body
	local previous = FINALE[1]
	for index = 2, #FINALE do
		local key = FINALE[index]
		local from, to = keyTime(previous, slamAt), keyTime(key, slamAt)
		if clock < to then
			local t = math.clamp((clock - from) / math.max(1e-3, to - from), 0, 1)
			return blend(previous.Body, key.Body, EASES[key.Ease](t))
		end
		previous = key
	end
	return previous.Body
end

local function applyBody(rig: Rig, b: Body, clock: number)
	local set = rig.Set
	local shake = math.sin(clock * 43) * math.rad(3) * b.Shake
	local lean, crouch, neck = math.rad(b.Lean), math.rad(b.Crouch), math.rad(b.Neck)
	local rPitch, rYaw = math.rad(b.RPitch) + shake, math.rad(b.RYaw)
	local lPitch, lYaw = math.rad(b.LPitch) - shake, math.rad(b.LYaw)
	if rig.IsR15 then
		set("Root", CFrame.new(0, -rig.LegLength * (1 - math.cos(crouch)), 0))
		set("RightHip", CFrame.Angles(crouch, 0, math.rad(10)))
		set("LeftHip", CFrame.Angles(crouch, 0, -math.rad(10)))
		set("RightKnee", CFrame.Angles(-crouch * 2, 0, 0))
		set("LeftKnee", CFrame.Angles(-crouch * 2, 0, 0))
		set("RightAnkle", CFrame.Angles(crouch, 0, 0))
		set("LeftAnkle", CFrame.Angles(crouch, 0, 0))
		set("Waist", CFrame.Angles(lean, 0, 0))
		set("Neck", CFrame.Angles(-lean * 0.7 + neck, 0, 0))
		set("RightShoulder", CFrame.Angles(0, rYaw, 0) * CFrame.Angles(rPitch, 0, 0))
		set("RightElbow", CFrame.Angles(math.rad(b.RElbow), 0, 0))
		set("RightWrist", CFrame.identity)
		set("LeftShoulder", CFrame.Angles(0, -lYaw, 0) * CFrame.Angles(lPitch, 0, 0))
		set("LeftElbow", CFrame.Angles(math.rad(b.LElbow), 0, 0))
		set("LeftWrist", CFrame.identity)
	else
		set("Root", CFrame.Angles(-lean, 0, 0))
		set("Neck", CFrame.Angles(lean * 0.7 - neck, 0, 0))
		set("RightHip", CFrame.Angles(0, 0, -lean))
		set("LeftHip", CFrame.Angles(0, 0, lean))
		set("RightShoulder", CFrame.Angles(0, rYaw, 0) * CFrame.Angles(0, 0, rPitch))
		set("LeftShoulder", CFrame.Angles(0, -lYaw, 0) * CFrame.Angles(0, 0, -lPitch))
	end
end

-- The post-capture finale (see FINALE), timed so the slam lands at `slamAt` seconds. Update takes
-- seconds since the capture; the other arguments are ignored.
function SealPose.Finale(character: Model, slamAt: number): Pose?
	local rig = rigFor(character)
	if not rig then
		return nil
	end
	return {
		Update = function(clock, _progress, _target, _kick)
			applyBody(rig, sampleFinale(clock, slamAt), clock)
		end,
		Restore = rig.Restore,
	}
end

-- Seconds from the capture until the finale is back at rest.
function SealPose.FinaleSeconds(slamAt: number): number
	return keyTime(FINALE[#FINALE], slamAt)
end

return SealPose
