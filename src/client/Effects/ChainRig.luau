-- Shared bind visuals for any character (GDD 4.3 "reuse avatar gesture/chain systems"): the arm
-- raised toward the target and spectral chains from the hand into it. Used for the local
-- player's own bind and, cosmetically, for other players' binds. Client-only, never replicated.

local ChainRig = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

export type Rig = {
	Hand: Attachment,
	Beams: { Beam },
	Restore: () -> (),
}

-- Raises the right arm forward. Returns a function that puts the shoulder back.
local function raiseArm(character: Model): () -> ()
	local upperArm = character:FindFirstChild("RightUpperArm")
	local torso = character:FindFirstChild("Torso")
	local joint: Motor6D? = nil
	local turn = CFrame.identity
	if upperArm then
		local shoulder = upperArm:FindFirstChild("RightShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			joint, turn = shoulder, CFrame.Angles(math.rad(90), 0, 0)
		end
	elseif torso then
		local shoulder = torso:FindFirstChild("Right Shoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			joint, turn = shoulder, CFrame.Angles(0, 0, math.pi / 2)
		end
	end
	if not joint then
		return function() end
	end
	local motor = joint :: Motor6D
	local original = motor.C0
	motor.C0 = original * turn
	return function()
		if motor.Parent then
			motor.C0 = original
		end
	end
end

function ChainRig.Attach(character: Model, target: Attachment, color: Color3, count: number): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local handPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
	local hand = Instance.new("Attachment")
	hand.Name = "BindHand"
	-- Bottom of the hand, where the chains leave the palm.
	if handPart:IsA("BasePart") and handPart ~= root then
		hand.Position = Vector3.new(0, -handPart.Size.Y / 2, 0)
	end
	hand.Parent = handPart

	local beams = {}
	for index = 1, count do
		local beam = Instance.new("Beam")
		beam.Attachment0 = hand
		beam.Attachment1 = target
		beam.Color = ColorSequence.new(color)
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

	local lower = raiseArm(character)
	return {
		Hand = hand,
		Beams = beams,
		Restore = function()
			lower()
			hand:Destroy()
		end,
	}
end

-- Chains writhe less and thicken as the bind tightens (progress 0..1).
function ChainRig.Update(rig: Rig, clock: number, progress: number)
	for _, beam in rig.Beams do
		local phase = beam:GetAttribute("Phase") or 0
		beam.CurveSize0 = math.sin(clock * 6 + phase) * (2 - progress * 1.5)
		beam.CurveSize1 = math.cos(clock * 5 + phase) * (2 - progress * 1.5)
		beam.Width0 = 0.25 + progress * 0.2
	end
end

-- Short impact flash where a relic was sealed.
function ChainRig.SealFlash(position: Vector3, size: number?)
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

	local grow = size or 14
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.5 do
			local t = (os.clock() - start) / 0.5
			local diameter = 2 + t * grow
			flash.Size = Vector3.new(diameter, diameter, diameter)
			flash.Transparency = t
			task.wait()
		end
		flash:Destroy()
	end)
end

return ChainRig
