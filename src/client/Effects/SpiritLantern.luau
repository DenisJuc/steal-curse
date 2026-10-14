-- The spirit lantern: in the dark wild every character carries a small cold glow (a PointLight
-- above the HumanoidRootPart), so you see a few studs around you and other players' lights in the
-- fog. Made on this client for every character; it fades in with Ambience.WildWeight. Only the
-- local lantern casts shadows (cheap on phones). Stays on with Low effects: it is how you see.
-- Its colour is the player's chosen lantern (the "Lantern" attribute, Config.Lanterns).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ambience = require(script.Parent.Ambience)
local Settings = require(script.Parent.Parent.Settings)

local SpiritLantern = {}

local NAME = "SpiritLantern"
local OFFSET = Vector3.new(0, 1.6, 0)

type Lantern = { Attachment: Attachment, Light: PointLight, Wisps: ParticleEmitter?, Id: string? }

local colors: { [string]: Color3 } = {}
for _, lantern in Config.Lanterns.List do
	colors[lantern.Id] = Color3.fromRGB(lantern.Color[1], lantern.Color[2], lantern.Color[3])
end

-- Colour of lantern `id` (the default lantern uses the ambience colour).
function SpiritLantern.Color(id: string?): Color3
	if id and id ~= Config.Lanterns.Default and colors[id] then
		return colors[id]
	end
	local values = Config.Ambience.Lantern.Color
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function make(root: BasePart, mine: boolean): Lantern
	local attachment = Instance.new("Attachment")
	attachment.Name = NAME
	attachment.Position = OFFSET
	local light = Instance.new("PointLight")
	light.Range = Config.Ambience.Lantern.Range
	light.Brightness = 0
	light.Shadows = mine and Config.Ambience.Lantern.Shadows
	light.Parent = attachment
	local wisps: ParticleEmitter? = nil
	if mine then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.25)
		emitter.Lifetime = NumberRange.new(1.2, 2)
		emitter.Speed = NumberRange.new(0.3, 0.8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 0.6, 0)
		emitter.Rate = 0
		emitter.Parent = attachment
		wisps = emitter
	end
	attachment.Parent = root
	return { Attachment = attachment, Light = light, Wisps = wisps, Id = nil }
end

function SpiritLantern.Start()
	local lanterns: { [Player]: Lantern } = {}
	local world = Config.World
	local fadeStart = world.WildInner - Config.Ambience.TownFadeStuds

	Players.PlayerRemoving:Connect(function(player)
		lanterns[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		local focus = if camera then camera.CFrame.Position else Vector3.zero
		local flicker = 1 + 0.07 * math.noise(os.clock() * 2.3, 0.5)
		local me = Players.LocalPlayer
		local cfg = Config.Ambience.Lantern
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local lantern = lanterns[player]
			if not lantern or lantern.Attachment.Parent ~= root then
				lantern = make(root, player == me)
				lanterns[player] = lantern
			end
			local id = player:GetAttribute("Lantern")
			local chosen = if type(id) == "string" then id else Config.Lanterns.Default
			if lantern.Id ~= chosen then
				lantern.Id = chosen
				local color = SpiritLantern.Color(chosen)
				lantern.Light.Color = color
				if lantern.Wisps then
					lantern.Wisps.Color = ColorSequence.new(color)
				end
			end
			local weight
			if player == me then
				weight = Ambience.WildWeight()
			else
				local position = root.Position
				local r = math.sqrt(position.X * position.X + position.Z * position.Z)
				local near = (position - focus).Magnitude <= Config.Ambience.LightRange
				weight = if near then math.clamp((r - fadeStart) / Config.Ambience.TownFadeStuds, 0, 1) else 0
			end
			lantern.Light.Enabled = weight > 0.02
			lantern.Light.Brightness = cfg.Brightness * weight * flicker
			if lantern.Wisps then
				lantern.Wisps.Rate = if Settings.LowEffects() then 0 else 3 * weight
			end
		end
	end)
end

return SpiritLantern
