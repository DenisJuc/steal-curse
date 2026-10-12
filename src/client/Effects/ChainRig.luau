-- Shared bind chains for any character (GDD 4.3 "reuse avatar gesture/chain systems"): chains
-- from the hand into the target, built from ChainLink meshes laid along a writhing curve that
-- pulls straighter as the bind tightens, each with a faint spectral glow. Without the mesh (or on
-- Low effects) the chains are glowing beams. The arm pose lives in SealPose. Used for the local
-- player's bind and, cosmetically, for other players' binds. Client-only, never replicated.

local HuntModels = require(script.Parent.HuntModels)

local ChainRig = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local LINK_SIZE = 1
-- Links overlap so they read as interlocked.
local LINK_SPACING = 0.72
local MAX_LINKS = 40

export type Options = {
	Color: Color3,
	Count: number,
	Low: boolean,
}

type Chain = {
	Phase: number,
	-- World-space beam ends (Terrain attachments), re-aimed every frame to follow the curve.
	Start: Attachment,
	Finish: Attachment,
	Beam: Beam,
	Links: { BasePart },
	Shown: number,
}

export type Rig = {
	Hand: Attachment,
	Target: Attachment,
	Chains: { Chain },
	Turn: CFrame,
	Snap: number,
	Clock: number,
	Restore: () -> (),
}

local function frameWithX(position: Vector3, axis: Vector3): CFrame
	local up = if math.abs(axis.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local z = axis:Cross(up).Unit
	return CFrame.fromMatrix(position, axis, z:Cross(axis), z)
end

local function terrainAttachment(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "BindChainEnd"
	attachment.Parent = workspace.Terrain
	return attachment
end

local function makeBeam(start: Attachment, finish: Attachment, color: Color3, meshes: boolean): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = start
	beam.Attachment1 = finish
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.Texture = SPARKLES
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 1.5
	beam.TextureSpeed = -3
	beam.FaceCamera = true
	beam.Segments = 20
	if meshes then
		-- A soft glow around the iron links.
		beam.Width0 = 0.7
		beam.Width1 = 0.7
		beam.Transparency = NumberSequence.new(0.75)
	else
		beam.Width0 = 0.25
		beam.Width1 = 0.45
	end
	beam.Parent = start
	return beam
end

function ChainRig.Attach(character: Model, target: Attachment, options: Options): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
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

	local meshes = not options.Low and HuntModels.has("ChainLink")
	local distance = (target.WorldPosition - root.Position).Magnitude
	local linkCount = math.clamp(math.ceil(distance * 1.15 / LINK_SPACING), 4, MAX_LINKS)
	local turn = CFrame.identity
	local holder = Instance.new("Folder")
	holder.Name = "BindChains"
	holder.Parent = workspace

	local chains = {}
	for index = 1, options.Count do
		local start, finish = terrainAttachment(), terrainAttachment()
		local links = {}
		if meshes then
			for _ = 1, linkCount do
				local built = HuntModels.build("ChainLink", LINK_SIZE, true)
				if not built then
					break
				end
				turn = built.Turn
				built.Part.Name = "ChainLink"
				built.Part.Transparency = 1
				built.Part.Parent = holder
				table.insert(links, built.Part)
			end
		end
		table.insert(chains, {
			Phase = index * 2.1,
			Start = start,
			Finish = finish,
			Beam = makeBeam(start, finish, options.Color, #links > 0),
			Links = links,
			Shown = 0,
		})
	end

	return {
		Hand = hand,
		Target = target,
		Chains = chains,
		Turn = turn,
		Snap = 0,
		Clock = 0,
		Restore = function()
			hand:Destroy()
			holder:Destroy()
			for _, chain in chains do
				chain.Start:Destroy()
				chain.Finish:Destroy()
			end
		end,
	}
end

-- Jerks every chain straight for a moment (a chain beat).
function ChainRig.Snap(rig: Rig)
	rig.Snap = 1
end

-- Chains writhe less as the bind tightens (progress 0..1). `reach` 0..1 draws them out from the
-- hand when the bind locks on. `tension` 0..1 pulls them taut (a tug of war).
function ChainRig.Update(rig: Rig, clock: number, progress: number, reach: number?, tension: number?)
	local dt = math.max(0, clock - rig.Clock)
	rig.Clock = clock
	rig.Snap = math.max(0, rig.Snap - dt * 4)
	local extend = reach or 1
	local p0 = rig.Hand.WorldPosition
	local p3 = rig.Target.WorldPosition
	local offset = p3 - p0
	local length = offset.Magnitude
	if length < 0.05 then
		return
	end
	local direction = offset / length
	local right = direction:Cross(Vector3.yAxis)
	right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis
	local up = right:Cross(direction)
	local slack = (1 - progress * 0.8) * (1 - rig.Snap) * (1 - (tension or 0) * 0.6)
	local sag = Vector3.new(0, -length * 0.06 * slack, 0)

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, chain in rig.Chains do
		local angle = chain.Phase + clock * 1.3
		local side = right * math.cos(angle) + up * math.sin(angle)
		local amplitude = length * 0.22 * slack * (0.6 + 0.4 * math.sin(clock * 5 + chain.Phase))
		local p1 = p0 + offset / 3 + side * amplitude + sag
		local p2 = p0 + offset * 2 / 3 - side * amplitude * 0.6 + sag

		-- The beam's own curve uses the same control points, so the glow hugs the links.
		local out, into = p1 - p0, p3 - p2
		chain.Start.WorldCFrame = frameWithX(p0, if out.Magnitude > 1e-3 then out.Unit else direction)
		chain.Finish.WorldCFrame = frameWithX(p3, if into.Magnitude > 1e-3 then into.Unit else direction)
		chain.Beam.CurveSize0 = out.Magnitude
		chain.Beam.CurveSize1 = into.Magnitude
		chain.Beam.Enabled = extend >= 1

		local count = #chain.Links
		local shown = math.floor(count * extend + 0.5)
		if shown ~= chain.Shown then
			for index, link in chain.Links do
				link.Transparency = if index <= shown then 0 else 1
			end
			chain.Shown = shown
		end
		for index, link in chain.Links do
			if index > shown then
				break
			end
			local t = (index - 0.5) / count
			local u = 1 - t
			local position = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
			local tangent = (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
			tangent = if tangent.Magnitude > 1e-3 then tangent.Unit else direction
			local roll = if index % 2 == 0 then math.pi / 2 else 0
			table.insert(parts, link)
			table.insert(frames, CFrame.lookAt(position, position + tangent, up) * CFrame.Angles(0, 0, roll) * rig.Turn)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
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
