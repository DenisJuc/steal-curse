-- Showcase poses: while a character carries the "ShowcasePose" attribute (a Showcase id, set by
-- the server's ShowcaseService), every client bends that character's R15 joints into the
-- Showcase's own pose each frame, with a slow breath. Joints are Motor6Ds on classic rigs and
-- AnimationConstraints on rigs with the avatar joint upgrade; both take a Transform, written
-- after the Animator has run (PreSimulation), so it replaces walk/idle/sit for posed joints.
-- Joint angles are degrees {x, y, z} on the joint's rest frame: +x swings a limb forward, a
-- negative knee x folds the shin back, +z moves a right limb outward (left limbs mirror),
-- a negative Waist/Neck x leans forward. Root {x, y, z} moves the whole body in studs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ShowcasePose = {}

type Joints = { [string]: { number } }
export type Pose = { Joints: Joints, Root: { number }?, Breath: number?, Float: number? }

local function sides(joints: Joints, name: string, angles: { number }, mirrorY: boolean?)
	joints["Right" .. name] = angles
	joints["Left" .. name] = { angles[1], if mirrorY then -angles[2] else angles[2], -angles[3] }
end

local function pose(build: (Joints) -> (), root: { number }?, breath: number?, float: number?): Pose
	local joints = {}
	build(joints)
	return { Joints = joints, Root = root, Breath = breath, Float = float }
end

-- Kneeling with hands pressed together in prayer, head bowed (gassho / seiza).
local function kneelPray(joints: Joints)
	sides(joints, "Hip", { 90, 0, 6 })
	sides(joints, "Knee", { -165, 0, 0 })
	sides(joints, "Ankle", { 60, 0, 0 })
	sides(joints, "Shoulder", { 55, 0, -32 })
	sides(joints, "Elbow", { 95, 0, 0 })
	sides(joints, "Wrist", { -20, 0, 0 })
	joints.Waist = { -8, 0, 0 }
	joints.Neck = { -22, 0, 0 }
end

ShowcasePose.Poses = {
	-- Binding Circle: cross-legged meditation floating about a body height up, hands on the knees.
	SimpleStance = pose(function(joints)
		sides(joints, "Hip", { 85, 0, 38 })
		sides(joints, "Knee", { -120, 0, 0 })
		sides(joints, "Shoulder", { 28, 0, 8 })
		sides(joints, "Elbow", { 40, 0, 0 })
		joints.Neck = { -6, 0, 0 }
	end, { 0, 4.4, 0 }, 3, 0.35),
	-- Forest Grove: standing tree pose, palms joined overhead.
	ForestGrove = pose(function(joints)
		joints.RightHip = { 25, 0, 65 }
		joints.RightKnee = { -125, 0, 0 }
		sides(joints, "Shoulder", { 10, 0, 168 })
		sides(joints, "Elbow", { 12, 0, 0 })
		joints.Neck = { 8, 0, 0 }
	end, nil, 2),
	-- Crimson Throne: the cursed king slouches, knees wide, cheek on his right fist and the
	-- left arm draped over the armrest.
	CrimsonThrone = pose(function(joints)
		joints.RightHip = { 85, -10, 22 }
		joints.LeftHip = { 85, 10, -26 }
		sides(joints, "Knee", { -85, 0, 0 })
		joints.RightShoulder = { 70, 0, 28 }
		joints.RightElbow = { 135, 0, 0 }
		joints.RightWrist = { -30, 0, 0 }
		joints.LeftShoulder = { 18, 0, -18 }
		joints.LeftElbow = { 55, 0, 0 }
		joints.Waist = { 14, 0, -6 }
		joints.Neck = { -12, 10, 16 }
	end, { 0, 0, 0.2 }, 1.5),
	-- Bell Watch: upright formal sitting, hands on the knees, watching the gate.
	BellWatch = pose(function(joints)
		sides(joints, "Hip", { 90, 0, 6 })
		sides(joints, "Knee", { -90, 0, 0 })
		sides(joints, "Shoulder", { 40, 0, 6 })
		sides(joints, "Elbow", { 35, 0, 0 })
		joints.Neck = { 4, 0, 0 }
	end, nil, 1.5),
	-- Golden Guardian: kneel before the statue and pray to it.
	GoldenGuardian = pose(kneelPray, { 0, -1.55, 0 }, 2),
	-- Star Circle: stand before the statue, arms raised to the sky in invocation.
	StarCircle = pose(function(joints)
		sides(joints, "Shoulder", { 25, 0, 145 })
		sides(joints, "Elbow", { 15, 0, 0 })
		joints.Waist = { 8, 0, 0 }
		joints.Neck = { 22, 0, 0 }
	end, nil, 3),
}

local function rotation(angles: { number }): CFrame
	return CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
end

type Joint = Motor6D | AnimationConstraint

-- Joint name -> joint, for one character (R15 only; other rigs are left alone).
local function motorsOf(character: Model): { [string]: Joint }
	local motors = {}
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
			motors[item.Name] = item :: Joint
		end
	end
	return motors
end

-- Writes `poseData` into `motors` at time `t` (seconds). Exposed for Studio previews.
function ShowcasePose.Apply(motors: { [string]: Joint }, poseData: Pose, t: number)
	local breath = math.sin(t * 1.4) * (poseData.Breath or 0)
	for name, angles in poseData.Joints do
		local motor = motors[name]
		if motor then
			local swayed = angles
			if name == "Waist" or name == "Neck" then
				swayed = { angles[1] + breath, angles[2], angles[3] }
			end
			local joint: any = motor
			joint.Transform = rotation(swayed)
		end
	end
	local root = motors.Root
	if root then
		local offset = poseData.Root or { 0, 0, 0 }
		local float = math.sin(t * 1.1) * (poseData.Float or 0)
		local joint: any = root
		joint.Transform = CFrame.new(offset[1], offset[2] + float, offset[3])
	end
end

function ShowcasePose.Start()
	local cache: { [Model]: { [string]: Joint } } = {}
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local id = character and character:GetAttribute("ShowcasePose")
			if not character or type(id) ~= "string" then
				if character then
					cache[character] = nil
				end
				continue
			end
			local poseData = ShowcasePose.Poses[id]
			if not poseData then
				continue
			end
			local motors = cache[character]
			if not motors or not motors.Root then
				motors = motorsOf(character)
				cache[character] = motors
			end
			ShowcasePose.Apply(motors, poseData, now)
		end
	end)
end

return ShowcasePose
