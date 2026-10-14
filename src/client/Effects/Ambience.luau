-- Client ambience for the open world (Slice 11): the fog (Atmosphere), the light (time of day,
-- brightness, ambient, exposure: the wild is a foggy night), a soft tint, particles
-- around the camera (fireflies, embers, glyphs, mist) and optional looping sounds follow the area
-- you stand in. Inside a blend zone the two neighbouring areas mix by WorldLayout.areaAt weight;
-- leaving the town fades from the Town preset over TownFadeStuds. Low effects: no particles.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local Ambience = {}

local CHECK_SECONDS = 0.25

type Preset = typeof(Config.Ambience.Town)
type Look = {
	Density: number,
	Offset: number,
	Haze: number,
	Color: Color3,
	Decay: Color3,
	Tint: Color3,
	Saturation: number,
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Exposure: number,
	-- 0 in town, 1 deep in the wild (drives the lantern and how much a pulse reveals).
	Wild: number,
}
type Emitter = { Emitter: ParticleEmitter, Rate: number, Low: boolean }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lookOf(preset: Preset, wild: number): Look
	local atmosphere = preset.Atmosphere
	local light = preset.Lighting
	return {
		Density = atmosphere.Density,
		Offset = atmosphere.Offset,
		Haze = atmosphere.Haze,
		Color = rgb(atmosphere.Color),
		Decay = rgb(atmosphere.Decay),
		Tint = rgb(preset.Tint),
		Saturation = preset.Saturation,
		ClockTime = light.ClockTime,
		Brightness = light.Brightness,
		Ambient = rgb(light.Ambient),
		OutdoorAmbient = rgb(light.OutdoorAmbient),
		Exposure = light.Exposure,
		Wild = wild,
	}
end

local function lerpLook(a: Look, b: Look, t: number): Look
	return {
		Density = lerp(a.Density, b.Density, t),
		Offset = lerp(a.Offset, b.Offset, t),
		Haze = lerp(a.Haze, b.Haze, t),
		Color = a.Color:Lerp(b.Color, t),
		Decay = a.Decay:Lerp(b.Decay, t),
		Tint = a.Tint:Lerp(b.Tint, t),
		Saturation = lerp(a.Saturation, b.Saturation, t),
		ClockTime = lerp(a.ClockTime, b.ClockTime, t),
		Brightness = lerp(a.Brightness, b.Brightness, t),
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, t),
		Exposure = lerp(a.Exposure, b.Exposure, t),
		Wild = lerp(a.Wild, b.Wild, t),
	}
end

-- A zone event's partial look (Config.ZoneEvents Overlay) mixed over `look` by `t`.
local function overlay(look: Look, values: { [string]: any }, t: number): Look
	local result = table.clone(look)
	if values.Color then
		result.Color = look.Color:Lerp(rgb(values.Color), t)
	end
	if values.Decay then
		result.Decay = look.Decay:Lerp(rgb(values.Decay), t)
	end
	if values.Tint then
		result.Tint = look.Tint:Lerp(rgb(values.Tint), t)
	end
	if values.Density then
		result.Density = lerp(look.Density, values.Density, t)
	end
	return result
end

local current: Look? = nil
local revealAt = -math.huge
local revealSeconds = Config.Ambience.Reveal.Seconds

-- 0..1: rises over RiseSeconds after a pulse, then eases back to 0 over the reveal seconds.
local function revealAmount(now: number): number
	local reveal = Config.Ambience.Reveal
	local since = now - revealAt
	if since < 0 or since >= reveal.RiseSeconds + revealSeconds then
		return 0
	elseif since < reveal.RiseSeconds then
		return since / reveal.RiseSeconds
	end
	local fade = (since - reveal.RiseSeconds) / revealSeconds
	return 1 - fade * fade * (3 - 2 * fade)
end

local strikeAt = -math.huge

-- Lightning flicker 0..1 `since` seconds after a strike: a bright flash, a dip, a second flash,
-- then a fade.
local function lightningAmount(since: number): number
	if since < 0 then
		return 0
	elseif since < 0.06 then
		return 1
	elseif since < 0.13 then
		return 0.15
	elseif since < 0.2 then
		return 0.8
	end
	return math.max(0, 0.8 * (1 - (since - 0.2) / 0.7))
end

-- A lightning flash (the server picks strikes: WildFinds). Thunder follows, sooner the closer
-- `distance` is (studs; unknown = somewhere out in the fog).
function Ambience.Lightning(distance: number?)
	strikeAt = os.clock()
	local delay = if distance then math.clamp(distance / 340, 0.05, 2.5) else 1 + math.random() * 2
	task.delay(delay, function()
		Sounds.Play("Thunder", nil, 0.85 + math.random() * 0.3)
	end)
end

-- Lifts the wild fog for a moment (Spirit Sight pulse).
function Ambience.Reveal(seconds: number?)
	revealAt = os.clock()
	revealSeconds = seconds or Config.Ambience.Reveal.Seconds
end

-- 0 in town, 1 in the wild (smoothed with the rest of the ambience).
function Ambience.WildWeight(): number
	return if current then current.Wild else 0
end

-- Weight of every preset ("Town" or an area id) at a position; weights sum to 1.
local function weightsAt(position: Vector3): { [string]: number }
	local world = Config.World
	local r = math.sqrt(position.X * position.X + position.Z * position.Z)
	local wild = math.clamp((r - (world.WildInner - Config.Ambience.TownFadeStuds)) / Config.Ambience.TownFadeStuds, 0, 1)
	local weights: { [string]: number } = { Town = 1 - wild }
	if wild > 0 then
		local id, weight, other = WorldLayout.areaAt(Config.Areas, world, position.X, position.Z)
		weights[id] = wild * weight
		if other then
			weights[other] = wild * (1 - weight)
		end
	end
	return weights
end

local function presetOf(id: string): Preset
	return if id == "Town" then Config.Ambience.Town else (Config.Ambience.Areas :: any)[id]
end

local function makeEmitterPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function Ambience.Start()
	local box = Config.Ambience.ParticleBox
	local folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = workspace
	local airPart = makeEmitterPart("AirParticles", Vector3.new(box[1], box[2], box[3]), folder)
	local groundPart = makeEmitterPart("GroundParticles", Vector3.new(box[1], 3, box[3]), folder)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AreaTint"
	tint.Parent = Lighting

	-- One emitter per preset particle entry, one looping sound per preset with a SoundId. Zone
	-- events add their own emitters under "Event_<id>".
	local emitters: { [string]: { Emitter } } = {}
	local sounds: { [string]: Sound } = {}
	local function addEmitters(id: string, particles: { any })
		emitters[id] = {}
		for _, entry in particles do
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = `{id}_{entry.Name}`
			emitter.Texture = entry.Texture
			emitter.Color = ColorSequence.new(rgb(entry.Color))
			emitter.Size = NumberSequence.new(entry.Size)
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, entry.Transparency or 0.1),
				NumberSequenceKeypoint.new(0.8, entry.Transparency or 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = NumberRange.new(entry.Lifetime * 0.7, entry.Lifetime)
			emitter.Speed = NumberRange.new(entry.Speed * 0.5, entry.Speed)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.LightEmission = entry.LightEmission
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-20, 20)
			if entry.Fall then
				-- Rain: thin streaks falling straight down.
				emitter.EmissionDirection = Enum.NormalId.Bottom
				emitter.SpreadAngle = Vector2.new(4, 4)
				emitter.Speed = NumberRange.new(entry.Speed * 0.85, entry.Speed)
				emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
				emitter.Squash = NumberSequence.new(entry.Squash or 2.5)
				emitter.Rotation = NumberRange.new(0, 0)
				emitter.RotSpeed = NumberRange.new(0, 0)
			end
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			if entry.Drift then
				emitter.Acceleration = Vector3.new(entry.Drift[1], entry.Drift[2], entry.Drift[3])
			end
			emitter.Rate = 0
			emitter.Parent = if entry.Low then groundPart else airPart
			table.insert(emitters[id], { Emitter = emitter, Rate = entry.Rate, Low = entry.Low == true })
		end
	end
	local ids = { "Town" }
	for id in Config.Ambience.Areas do
		table.insert(ids, id)
	end
	for _, id in ids do
		local preset = presetOf(id)
		addEmitters(id, preset.Particles :: { any })
		if preset.SoundId ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = `Ambience_{id}`
			sound.SoundId = preset.SoundId
			sound.Looped = true
			sound.Volume = 0
			sound.Parent = SoundService
			sound:Play()
			sounds[id] = sound
		end
	end
	for _, event in Config.ZoneEvents.Events do
		addEmitters(`Event_{event.Id}`, event.Particles)
	end

	local look: Look = lookOf(Config.Ambience.Town, 0)
	current = look
	local target: Look = look
	local weights: { [string]: number } = { Town = 1 }
	local elapsed = CHECK_SECONDS
	local storm = Config.Ambience.Lightning

	local function retarget(position: Vector3)
		weights = weightsAt(position)
		local mixed: Look? = nil
		local total = 0
		for id, weight in weights do
			if weight <= 0 then
				continue
			end
			local preset = lookOf(presetOf(id), if id == "Town" then 0 else 1)
			total += weight
			mixed = if mixed then lerpLook(mixed, preset, weight / total) else preset
		end
		target = mixed or target

		-- An active zone event recolours its area (by how much you stand in it).
		local eventId = workspace:GetAttribute("ZoneEvent")
		local eventArea = workspace:GetAttribute("ZoneEventArea")
		local eventWeight = if type(eventArea) == "string" then weights[eventArea] or 0 else 0
		for _, event in Config.ZoneEvents.Events do
			if event.Id == eventId and eventWeight > 0 then
				target = overlay(target, event.Overlay, eventWeight)
			end
		end

		-- Cleansed shrines lift their zone's curse for this player: thinner, warmer fog.
		local curse = Config.Curse
		for id, weight in weights do
			local lifted = Players.LocalPlayer:GetAttribute(`CurseLifted_{id}`)
			if type(lifted) == "number" and lifted > 0 and weight > 0 then
				local t = math.clamp(lifted, 0, 1) * weight
				target = overlay(target, {
					Density = target.Density * (1 - curse.FogLift),
					Tint = curse.WarmTint,
				}, t)
			end
		end

		local low = Settings.LowEffects()
		for id, list in emitters do
			local weight = weights[id] or 0
			if string.sub(id, 1, 6) == "Event_" then
				weight = if string.sub(id, 7) == eventId then eventWeight else 0
			end
			for _, entry in list do
				entry.Emitter.Enabled = not low and weight > 0.01
				entry.Emitter.Rate = entry.Rate * weight
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local focus = camera.CFrame.Position
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local ground = if root and root:IsA("BasePart") then root.Position else focus

		elapsed += dt
		if elapsed >= CHECK_SECONDS then
			elapsed = 0
			retarget(ground)
		end

		airPart.CFrame = CFrame.new(focus)
		groundPart.CFrame = CFrame.new(focus.X, ground.Y - 1.5, focus.Z)

		local t = 1 - math.exp(-Config.Ambience.BlendSpeed * dt)
		look = lerpLook(look, target, t)
		current = look
		local now = os.clock()
		local reveal = Config.Ambience.Reveal
		local lift = revealAmount(now) * look.Wild
		local flash = lightningAmount(now - strikeAt) * look.Wild
		if atmosphere and atmosphere.Parent then
			local density = lerp(look.Density, reveal.Density, lift)
			atmosphere.Density = lerp(density, storm.Density, flash * 0.5)
			atmosphere.Offset = look.Offset
			atmosphere.Haze = lerp(look.Haze, 1, lift)
			atmosphere.Color = look.Color:Lerp(rgb(storm.Ambient), flash * 0.5)
			atmosphere.Decay = look.Decay
		else
			atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		end
		Lighting.ClockTime = look.ClockTime
		local brightness = lerp(look.Brightness, math.max(look.Brightness, reveal.Brightness), lift)
		Lighting.Brightness = lerp(brightness, math.max(brightness, storm.Brightness), flash)
		Lighting.Ambient = look.Ambient
		Lighting.OutdoorAmbient = look.OutdoorAmbient:Lerp(rgb(storm.Ambient), flash)
		Lighting.ExposureCompensation = lerp(look.Exposure, math.max(look.Exposure, reveal.Exposure), math.max(lift, flash))
		tint.TintColor = look.Tint
		tint.Saturation = look.Saturation

		local volume = Settings.Volume() * Config.Ambience.SoundVolume
		for id, sound in sounds do
			local goal = volume * (weights[id] or 0)
			sound.Volume += (goal - sound.Volume) * t
		end
	end)
end

return Ambience
