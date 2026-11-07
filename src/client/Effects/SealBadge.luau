-- Seal on every character's back (Config.SealLadder by the replicated "LastingLuck" attribute):
-- one thin disc welded behind the torso, its colour and glow growing by tier, plus one subtle
-- particle emitter from Spirit Seal up. Built on this client for every character (cosmetic only).
-- Your own rank-up shows one banner ("New Seal: Jade Seal"); joining never does.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SealLadder = require(ReplicatedStorage.Shared.SealLadder)
local Banner = require(script.Parent.Parent.UI.Banner)

local SealBadge = {}

local NAME = "SealBadge"
local DIAMETER = 1.5
local THICKNESS = 0.12

type Entry = { Part: BasePart, Tier: number, Torso: BasePart }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function lastingOf(player: Player): number?
	local value = player:GetAttribute("LastingLuck")
	return if type(value) == "number" and value == value then value else nil
end

local function style(part: BasePart, index: number)
	local tier = Config.SealLadder[index]
	local color = rgb(tier.Color)
	part.Color = color
	part.Material = if tier.Glow >= 0.35 then Enum.Material.Neon elseif tier.Glow > 0 then Enum.Material.Metal else Enum.Material.SmoothPlastic
	local light = part:FindFirstChildOfClass("PointLight")
	if tier.Glow > 0 then
		light = light or Instance.new("PointLight")
		assert(light, "light")
		light.Color = color
		light.Brightness = 0.4 + tier.Glow * 1.2
		light.Range = 3 + tier.Glow * 5
		light.Shadows = false
		light.Parent = part
	elseif light then
		light:Destroy()
	end
	local emitter = part:FindFirstChildOfClass("ParticleEmitter")
	if tier.Particle then
		emitter = emitter or Instance.new("ParticleEmitter")
		assert(emitter, "emitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Rate = 3 + tier.Glow * 4
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(0.3, 0.8)
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		emitter.Acceleration = Vector3.new(0, 1.5, 0)
		emitter.Parent = part
	elseif emitter then
		emitter:Destroy()
	end
end

local function make(torso: BasePart, index: number): BasePart
	local part = Instance.new("Part")
	part.Name = NAME
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(THICKNESS, DIAMETER, DIAMETER)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	-- Cylinder axis is X; turn it to face backwards (+Z is the character's back).
	part.CFrame = torso.CFrame * CFrame.new(0, 0.15, torso.Size.Z / 2 + THICKNESS / 2 + 0.02) * CFrame.Angles(0, math.rad(90), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part
	style(part, index)
	part.Parent = torso.Parent
	return part
end

function SealBadge.Start()
	local shown: { [Player]: Entry } = {}
	local ownTier: number? = nil
	-- Sources load one after another on join (Codex, Showcases...): rises in the first seconds
	-- after the first value are part of joining, not a rank-up.
	local quietUntil = 0
	Players.PlayerRemoving:Connect(function(player)
		local entry = shown[player]
		if entry then
			entry.Part:Destroy()
		end
		shown[player] = nil
	end)
	local check = 0
	RunService.Heartbeat:Connect(function(dt)
		check += dt
		if check < 0.5 then
			return
		end
		check = 0
		for _, player in Players:GetPlayers() do
			local lasting = lastingOf(player)
			local character = player.Character
			local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
			local entry = shown[player]
			if lasting and player == Players.LocalPlayer then
				local index = SealLadder.tierFor(Config.SealLadder, lasting)
				-- The first value after join is silent; only a real rank-up gets a banner.
				if not ownTier then
					quietUntil = os.clock() + 8
				elseif index > ownTier and os.clock() > quietUntil then
					local tier = Config.SealLadder[index]
					Banner.Show("NEW SEAL", tier.Name, rgb(tier.Color))
				end
				ownTier = index
			end
			if not lasting or not (torso and torso:IsA("BasePart")) then
				if entry then
					entry.Part:Destroy()
					shown[player] = nil
				end
				continue
			end
			assert(torso and torso:IsA("BasePart"), "torso")
			local index = SealLadder.tierFor(Config.SealLadder, lasting)
			if not entry or entry.Torso ~= torso or not entry.Part.Parent then
				if entry then
					entry.Part:Destroy()
				end
				shown[player] = { Part = make(torso, index), Tier = index, Torso = torso }
			elseif entry.Tier ~= index then
				style(entry.Part, index)
				entry.Tier = index
			end
		end
	end)
end

return SealBadge
