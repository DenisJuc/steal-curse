-- Client-only Spirit Sight visuals: the owner's signal orbs, pulse trails and the screen tint.
-- Every orb looks identical on purpose: nothing here may hint at a relic's rarity.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)

local SpiritSight = {}

local SIGNAL_COLOR = Color3.fromRGB(140, 220, 255)
local TRAIL_COLOR = Color3.fromRGB(180, 140, 255)
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

type Orb = {
	Part: Part,
	Base: Vector3,
	Phase: number,
}

local folder = Instance.new("Folder")
folder.Name = "SpiritSignals"

local orbs: { [number]: Orb } = {}
local enabled = false
local clock = 0

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "SpiritSightTint"
tint.Saturation = -0.35
tint.Contrast = 0.1
tint.TintColor = Color3.fromRGB(205, 190, 255)
tint.Enabled = false
tint.Parent = Lighting

local function makeOrb(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "Signal"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.4, 2.4, 2.4)
	part.Material = Enum.Material.Neon
	part.Color = SIGNAL_COLOR
	part.Transparency = 0.15
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position)

	local light = Instance.new("PointLight")
	light.Color = SIGNAL_COLOR
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLES
	emitter.Color = ColorSequence.new(SIGNAL_COLOR)
	emitter.LightEmission = 1
	emitter.Rate = 8
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Parent = part

	local attachment = Instance.new("Attachment")
	attachment.Name = "Core"
	attachment.Parent = part

	part.Parent = folder
	return part
end

function SpiritSight.SetSignals(signals: { [number]: Vector3 })
	for id, orb in orbs do
		if not signals[id] then
			orb.Part:Destroy()
			orbs[id] = nil
		end
	end
	for id, position in signals do
		local orb = orbs[id]
		if not orb then
			orbs[id] = { Part = makeOrb(position), Base = position, Phase = id * 1.7 }
		elseif (orb.Base - position).Magnitude > 0.1 then
			-- Signals follow the player into another district, keeping their ids.
			orb.Base = position
			orb.Part.CFrame = CFrame.new(position)
		end
	end
end

function SpiritSight.SetEnabled(on: boolean)
	enabled = on
	folder.Parent = if on then workspace else nil
	tint.Enabled = on
end

function SpiritSight.IsEnabled(): boolean
	return enabled
end

function SpiritSight.GetOrb(id: number): Part?
	local orb = orbs[id]
	return if orb then orb.Part else nil
end

-- Bobs every orb that is not being bound and hides orbs beyond reveal range.
function SpiritSight.Update(dt: number, viewer: Vector3?)
	clock += dt
	local rank = Players.LocalPlayer:GetAttribute("Skill_SpiritSight")
	local revealRange = SkillConfig.sightRange(if type(rank) == "number" then rank else 0)
	for _, orb in orbs do
		local part = orb.Part
		if part:GetAttribute("Binding") then
			continue
		end
		local offset = math.sin(clock * 2 + orb.Phase) * 0.4
		part.CFrame = CFrame.new(orb.Base + Vector3.new(0, offset, 0))
		local visible = viewer ~= nil and (orb.Base - viewer).Magnitude <= revealRange
		part.Transparency = if visible then 0.15 else 1
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = visible
		end
		local emitter = part:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Enabled = visible
		end
	end
end

-- Draws a flowing trail from the player to every signal for a few seconds, plus a ground ripple.
function SpiritSight.Pulse(root: BasePart)
	local duration = Config.SpiritSight.PulseSeconds
	local origin = Instance.new("Attachment")
	origin.Name = "PulseOrigin"
	origin.Parent = root

	local beams = {}
	for _, orb in orbs do
		local core = orb.Part:FindFirstChild("Core")
		if not core then
			continue
		end
		local beam = Instance.new("Beam")
		beam.Attachment0 = origin
		beam.Attachment1 = core :: Attachment
		beam.Color = ColorSequence.new(TRAIL_COLOR, SIGNAL_COLOR)
		beam.LightEmission = 1
		beam.Width0 = 0.6
		beam.Width1 = 1.2
		beam.Texture = SPARKLES
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 3
		beam.TextureSpeed = 2
		beam.FaceCamera = true
		beam.Transparency = NumberSequence.new(0.2, 0.6)
		beam.Parent = origin
		table.insert(beams, beam)
	end

	local ripple = Instance.new("Part")
	ripple.Name = "PulseRipple"
	ripple.Shape = Enum.PartType.Cylinder
	ripple.Anchored = true
	ripple.CanCollide = false
	ripple.CanTouch = false
	ripple.CanQuery = false
	ripple.CastShadow = false
	ripple.Material = Enum.Material.Neon
	ripple.Color = TRAIL_COLOR
	ripple.Transparency = 0.3
	ripple.Size = Vector3.new(0.2, 4, 4)
	ripple.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ripple.Parent = workspace

	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration do
			local t = (os.clock() - start) / duration
			local rippleT = math.min(1, t * 3)
			ripple.Size = Vector3.new(0.2, 4 + rippleT * 60, 4 + rippleT * 60)
			ripple.Transparency = 0.3 + rippleT * 0.7
			for _, beam in beams do
				beam.Transparency = NumberSequence.new(0.2 + t * 0.8, 0.6 + t * 0.4)
			end
			task.wait()
		end
		ripple:Destroy()
		origin:Destroy()
	end)
end

return SpiritSight
