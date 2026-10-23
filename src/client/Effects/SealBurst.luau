-- The seal moment after a validated capture / scan.
--
-- Premade Studio VFX (default):
--   Player: MeteorSpawn circle
--   Sealed curse: PurpleSpikeBurst → DarkOrbSkill (curse becomes energy, then vanishes)
-- Burst / orb gated by PREMADE.ENABLE_*. Driven via ParticleEmitter:Emit.
-- Legacy jar: SealJar + spirit swallow (USE_PREMADE_VFX = false).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local ChainRig = require(script.Parent.ChainRig)
local HuntFX = require(script.Parent.HuntFX)
local HuntModels = require(script.Parent.HuntModels)
local Sounds = require(script.Parent.Parent.Sounds)

local SealBurst = {}

-- true = premade feet VFX (assets/VFX). false = legacy jar at capture position.
local USE_PREMADE_VFX = true

---------------------------------------------------------------------------
-- Premade VFX tuning (tweak here — no other edits needed)
---------------------------------------------------------------------------
local PREMADE = {
	-- Studio-only slow-mo. Production / live clients always use 1.
	TIME_SCALE = 1,
	-- false = only Hunt bind seals play world VFX (AFK roll stays UI-only).
	PLAY_ON_SCAN = false,

	-- Player gets circle + orb; burst plays on the sealed curse.
	ENABLE_BURST = true,
	ENABLE_ORB = true,

	-- Stage windows (seconds at TIME_SCALE = 1).
	CIRCLE_START = 0.00,
	CIRCLE_GROW = 0.20,
	CIRCLE_EMIT_AT = 0.14, -- emit after grow so particles aren't scaled to ~5%
	CIRCLE_END = 0.85,
	-- Burst: short punch on the curse, then clear so the orb has room to play.
	BURST_AT = 0.08,
	BURST_END = 0.32,
	-- Orb starts once the spike burst is done — long enough to rotate + animate.
	ORB_AT = 0.38,
	ORB_END = 0.38 + 1.8, -- = ORB_AT + ORB_PLAY_SECONDS
	-- Hold at full radius a bit past the seal beat, then fade out.
	FADE_START = 0.80,
	FADE_END = 1.25,
	-- Destroy after longest emitted Lifetime (~1s waves / flare) + pad.
	CLEANUP_AFTER_FADE = 1.05,
	MAX_CLEANUP = 4.20,

	-- Circle: around the ankles, not under the floor / not giant.
	GROUND_OFFSET = 0.75,
	CIRCLE_SCALE_START = 0.08,
	CIRCLE_SCALE_END = 0.68, -- wider ring so it clears the character
	CIRCLE_SPIN = 2.2,
	CIRCLE_BEAM_WIDTH_MULT = 0.32, -- MeteorSpawn beams are Width 20 authored — shrink hard
	CIRCLE_SIZE_MULT = 0.85, -- wave particles slightly under authored size

	-- Burst sits on the sealed curse (capture position), scaled to ~spirit size.
	BURST_CURSE_LIFT = 0.4, -- slightly above the signal pivot
	BURST_SCALE = 0.28, -- Model:ScaleTo — envelope ≈ sealed curse (~2–3 studs)
	BURST_SIZE_MULT = 0.65, -- particle Size vs authored (keep tight to the curse)
	-- Orb replaces the sealed curse after the spike burst (cursed object → energy ball).
	-- DarkOrbSkill is authored enormous — ScaleTo only; leave colors/meshes alone.
	ORB_LIFT = 3.2, -- studs above terrain (raycast), not raw seal Y
	ORB_SCALE = 0.12, -- ≈ sealed-curse size
	ORB_SPIN = 2.8, -- rad/s while it swirls, then vanishes
	ORB_PLAY_SECONDS = 1.8, -- 75% of prior 2.4s
	-- Authored extras to strip on clone (DarkShadowParticle removed on purpose).
	ORB_STRIP_NAMES = { "Dust", "OnFinishRing", "DarkShadowParticle" },
	ORB_DEBUG_DUMP = false,

	-- Force readability in dark wild / Hunt (applied to clones only).
	GLOW_LIGHT_EMISSION = 1,
	GLOW_LIGHT_INFLUENCE = 0,
	GLOW_BRIGHTNESS = 5,
	SIZE_MULT = 1.0, -- orb: leave 1 so ScaleTo keeps particles/beams matched
	BEAM_WIDTH_MULT = 1.0, -- orb beams (not circle)
	BEAM_BRIGHTNESS = 5,

	CIRCLE_EMIT = { Smoke = 8, Wave0 = 6, Wave1 = 6, Wave2 = 5, Wave3 = 5 },
	BURST_EMIT = { Main = 18, Flare = 12, Spikes = 22 },
	ORB_EMIT = {
		Center = 40,
		Shine = 32,
		Start2 = 28,
	},
	DEFAULT_EMIT = 20,
	SPIKES_CAP = 24,

	BURST_LIGHT_RANGE = 8,
	BURST_LIGHT_BRIGHTNESS = 2.8,
	POP_LIGHT_RANGE = 18,
	POP_LIGHT_BRIGHTNESS = 5,
	POP_LIGHT_FADE = 0.9,

	---------------------------------------------------------------------------
	-- Light / post pulse (dark wild readability). Visual only; single owner.
	-- Dedicated SealPulseCC stacks with AreaTint / SpiritSightTint / MapBuilder CC.
	-- Bloom: offset on the existing BloomEffect (MapBuilder) — never snapshot/restore.
	-- Duration covers circle → curse burst → orb so VFX stay lit in the wild.
	---------------------------------------------------------------------------
	ENABLE_LIGHT_PULSE = true,
	PULSE_DURATION = 3.0, -- covers burst + orb play-out
	PULSE_HOLD = 0.55, -- fraction of duration at full brightness before ease-out
	PULSE_MIN_INTERVAL = 1.5, -- skip new pulses this soon after a start (unless extending active)
	PULSE_LIGHT_FADE_IN = 0.1,
	PULSE_LIGHT_RANGE = 28,
	PULSE_LIGHT_BRIGHTNESS = 5.5,
	PULSE_LIGHT_COLOR = Color3.fromRGB(170, 90, 255),
	PULSE_CC_CONTRAST = 0.15,
	PULSE_CC_BRIGHTNESS = 0.04,
	PULSE_CC_SATURATION = 0.06,
	PULSE_CC_TINT = Color3.fromRGB(220, 190, 255),
	PULSE_BLOOM_OFFSET = 0.35, -- added to current Bloom.Intensity, removed by end
}

---------------------------------------------------------------------------
-- Timeline exports (HuntController: CaptureAnimation / seal camera)
-- Premade: white relic flies in only after the energy orb finishes vanishing.
---------------------------------------------------------------------------
local APPEAR_END = 0.35
local SWALLOW_START, SWALLOW_END = 0.45, 1.05
local SLAM_AT = 1.4
local SINK_START = 1.9
if USE_PREMADE_VFX then
	local orbDone = PREMADE.ORB_AT + PREMADE.ORB_PLAY_SECONDS
	SealBurst.SlamAt = orbDone
	SealBurst.RevealAt = orbDone
	SealBurst.Seconds = PREMADE.ORB_END + PREMADE.CLEANUP_AFTER_FADE
else
	SealBurst.SlamAt = SLAM_AT
	SealBurst.RevealAt = SLAM_AT + 0.1
	SealBurst.Seconds = 2.4
end

export type Options = {
	Low: boolean,
	Personal: boolean,
}

local SPIRIT_COLOR = Color3.fromRGB(140, 220, 255)
local JAR_SIZE = 3
local SPIRIT_SIZE = 2.4
local PURPLE = Color3.fromRGB(170, 90, 255)

local CIRCLE_NAME = "MeteorSpawn"
local BURST_NAME = "PurpleSpikeBurst"
local ORB_NAME = "DarkOrbSkill"

local activeFolder: Folder? = nil
local activeToken = 0
local started = false

-- Single light-pulse owner (never one tween/stack per seal).
local pulseGen = 0
local pulseConn: RBXScriptConnection? = nil
local pulseActive = false
local pulseLastStart = -math.huge
local pulseBloom: BloomEffect? = nil
local pulseBloomApplied = 0
local pulseCC: ColorCorrectionEffect? = nil
local pulseLight: PointLight? = nil

local function timeScale(): number
	if not RunService:IsStudio() then
		return 1
	end
	return math.max(0.05, PREMADE.TIME_SCALE)
end

local function T(seconds: number): number
	return seconds * timeScale()
end

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function span(t: number, from: number, to: number): number
	return math.clamp((t - from) / (to - from), 0, 1)
end

local function tierLook(relicId: string): (Color3, number)
	local relic = RelicConfig.ById[relicId]
	local tier = relic and RarityConfig.Get(relic.Tier)
	if not relic or not tier then
		return SPIRIT_COLOR, 0
	end
	local index = RarityConfig.IndexById[relic.Tier]
	return Color3.fromHex(tier.Color), (index - 1) / math.max(1, #RarityConfig.Tiers - 1)
end

local function groundBelow(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	if activeFolder then
		table.insert(exclude, activeFolder)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	-- Cast from well above the seal so both ground-level and hover seals hit terrain.
	local origin = Vector3.new(position.X, position.Y + 12, position.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -50, 0), params)
	return if hit then hit.Position.Y else position.Y - Config.Signals.HoverHeight
end

-- Always float ORB_LIFT above terrain at the seal's XZ (ignores inconsistent seal Y).
local function orbHoverAt(sealPos: Vector3): Vector3
	local ground = groundBelow(sealPos)
	return Vector3.new(sealPos.X, ground + PREMADE.ORB_LIFT, sealPos.Z)
end

-- PivotTo so the model's bounding-box center sits on `at` (authored pivots vary).
local function placeOrbCentered(orb: Instance, at: Vector3, yaw: number)
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	if orb:IsA("Model") then
		orb:PivotTo(cf)
		local bbCf = orb:GetBoundingBox()
		local delta = at - bbCf.Position
		if delta.Magnitude > 1e-3 then
			orb:PivotTo(orb:GetPivot() + delta)
		end
	elseif orb:IsA("BasePart") then
		orb.CFrame = cf
	end
end

local function dumpOrbTree(orb: Instance)
	if not PREMADE.ORB_DEBUG_DUMP or not RunService:IsStudio() then
		return
	end
	warn("[SealBurst] Orb clone tree — find the green blob, tell me its Name / Class:")
	for _, item in orb:GetDescendants() do
		local extra = ""
		if item:IsA("BasePart") then
			local c = item.Color
			extra = string.format(
				" Part Color=%.2f,%.2f,%.2f Size=%.1f,%.1f,%.1f",
				c.R,
				c.G,
				c.B,
				item.Size.X,
				item.Size.Y,
				item.Size.Z
			)
		elseif item:IsA("ParticleEmitter") then
			local c = item.Color.Keypoints[1].Value
			extra = string.format(" Emitter Color=%.2f,%.2f,%.2f", c.R, c.G, c.B)
		elseif item:IsA("Beam") then
			extra = " Beam"
		elseif item:IsA("PointLight") then
			extra = " PointLight"
		end
		if extra ~= "" or item:IsA("Model") or item:IsA("Folder") or item:IsA("Attachment") then
			warn(string.format("  %s [%s]%s", item:GetFullName(), item.ClassName, extra))
		end
	end
end

local function makeJar(): (BasePart, CFrame, number)
	local built = HuntModels.build("SealJar", JAR_SIZE)
	if built then
		return built.Part, built.Turn, built.Part.Size.Y
	end
	local jar = HuntFX.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(JAR_SIZE, JAR_SIZE * 0.7, JAR_SIZE * 0.7),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Slate,
	})
	return jar, CFrame.Angles(0, 0, math.pi / 2), JAR_SIZE
end

local function vfxFolder(): Folder?
	local folder = ReplicatedStorage:FindFirstChild("VFX")
	return if folder and folder:IsA("Folder") then folder else nil
end

local TEMPLATE_ALIASES: { [string]: { string } } = {
	MeteorSpawn = { "MeteorSpawn", "Meteor Spawn" },
	PurpleSpikeBurst = { "PurpleSpikeBurst", "Purple" },
	DarkOrbSkill = { "DarkOrbSkill", "Dark Orb Skill" },
}

local function template(name: string): Instance?
	local folder = vfxFolder()
	if not folder then
		return nil
	end
	local aliases = TEMPLATE_ALIASES[name] or { name }
	for _, alias in aliases do
		local found = folder:FindFirstChild(alias)
		if found then
			return found
		end
	end
	local want = string.lower(name)
	for _, child in folder:GetChildren() do
		local childName = string.lower(child.Name)
		if childName == want or string.find(childName, want, 1, true) then
			return child
		end
	end
	return nil
end

local function clearActive()
	activeToken += 1
	if activeFolder and activeFolder.Parent then
		activeFolder:Destroy()
	end
	activeFolder = nil
end

local function scaleNumberSequence(seq: NumberSequence, mult: number): NumberSequence
	local keys = {}
	for _, key in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * mult, key.Envelope * mult))
	end
	return NumberSequence.new(keys)
end

---------------------------------------------------------------------------
-- Seal light pulse: PointLight on HRP + stacked SealPulseCC + Bloom Intensity offset
---------------------------------------------------------------------------
local function pulseEnvelope(elapsed: number, duration: number, fadeIn: number): number
	if elapsed <= 0 then
		return 0
	end
	if elapsed >= duration then
		return 0
	end
	if elapsed < fadeIn then
		return elapsed / math.max(1e-3, fadeIn)
	end
	local holdUntil = duration * math.clamp(PREMADE.PULSE_HOLD, 0.05, 0.9)
	if elapsed < holdUntil then
		return 1
	end
	local u = (elapsed - holdUntil) / math.max(1e-3, duration - holdUntil)
	-- Ease back to neutral (smoothstep).
	return 1 - u * u * (3 - 2 * u)
end

local function applyBloomOffset(targetOffset: number)
	local bloom = pulseBloom
	if not bloom or not bloom.Parent then
		pulseBloomApplied = 0
		return
	end
	bloom.Intensity = bloom.Intensity - pulseBloomApplied + targetOffset
	pulseBloomApplied = targetOffset
end

local function ensurePulseBloom(): BloomEffect
	if pulseBloom and pulseBloom.Parent then
		return pulseBloom
	end
	local existing = Lighting:FindFirstChildOfClass("BloomEffect")
	if existing then
		pulseBloom = existing
		return existing
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SealPulseBloom"
	bloom.Intensity = 0
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting
	pulseBloom = bloom
	return bloom
end

local function ensurePulseCC(): ColorCorrectionEffect
	if pulseCC and pulseCC.Parent then
		return pulseCC
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SealPulseCC"
	cc.Brightness = 0
	cc.Contrast = 0
	cc.Saturation = 0
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Parent = Lighting
	pulseCC = cc
	return cc
end

local function ensurePulseLight(): PointLight?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	if pulseLight and pulseLight.Parent == root then
		return pulseLight
	end
	if pulseLight then
		pulseLight:Destroy()
		pulseLight = nil
	end
	local existing = root:FindFirstChild("SealPulseLight")
	if existing and existing:IsA("PointLight") then
		pulseLight = existing
		return existing
	end
	local light = Instance.new("PointLight")
	light.Name = "SealPulseLight"
	light.Color = PREMADE.PULSE_LIGHT_COLOR
	light.Range = PREMADE.PULSE_LIGHT_RANGE
	light.Brightness = 0
	light.Shadows = false
	light.Parent = root
	pulseLight = light
	return light
end

local function endLightPulse()
	pulseActive = false
	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end
	applyBloomOffset(0)
	if pulseCC and pulseCC.Parent then
		pulseCC.Brightness = 0
		pulseCC.Contrast = 0
		pulseCC.Saturation = 0
		pulseCC.TintColor = Color3.new(1, 1, 1)
	end
	if pulseLight and pulseLight.Parent then
		pulseLight.Brightness = 0
	end
end

local function startLightPulse()
	if not PREMADE.ENABLE_LIGHT_PULSE then
		return
	end
	local now = os.clock()
	if pulseActive then
		-- Restart / extend the single active pulse (no stacking).
	elseif now - pulseLastStart < PREMADE.PULSE_MIN_INTERVAL then
		return
	end

	pulseLastStart = now
	pulseGen += 1
	local gen = pulseGen
	pulseActive = true

	ensurePulseBloom()
	ensurePulseCC()
	local light = ensurePulseLight()

	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end

	local t0 = now
	pulseConn = RunService.RenderStepped:Connect(function()
		if gen ~= pulseGen then
			return
		end
		local elapsed = os.clock() - t0
		local duration = PREMADE.PULSE_DURATION
		if elapsed >= duration then
			endLightPulse()
			return
		end
		local env = pulseEnvelope(elapsed, duration, PREMADE.PULSE_LIGHT_FADE_IN)
		applyBloomOffset(PREMADE.PULSE_BLOOM_OFFSET * env)

		local cc = pulseCC
		if cc and cc.Parent then
			cc.Contrast = PREMADE.PULSE_CC_CONTRAST * env
			cc.Brightness = PREMADE.PULSE_CC_BRIGHTNESS * env
			cc.Saturation = PREMADE.PULSE_CC_SATURATION * env
			cc.TintColor = Color3.new(1, 1, 1):Lerp(PREMADE.PULSE_CC_TINT, env)
		end

		if not light or not light.Parent then
			light = ensurePulseLight()
		end
		if light and light.Parent then
			light.Color = PREMADE.PULSE_LIGHT_COLOR
			light.Range = PREMADE.PULSE_LIGHT_RANGE
			light.Shadows = false
			light.Brightness = PREMADE.PULSE_LIGHT_BRIGHTNESS * env
		end
	end)
end

-- Always leave pulse neutral if the character goes away mid-seal.
Players.LocalPlayer.CharacterRemoving:Connect(function()
	endLightPulse()
	if pulseLight then
		pulseLight:Destroy()
		pulseLight = nil
	end
end)

-- Dark ring look for MeteorSpawn (never wash to white).
local CIRCLE_DARK = Color3.fromRGB(18, 10, 28)
local CIRCLE_DARK_MID = Color3.fromRGB(45, 25, 70)

-- Clone setup.
-- orb: leave authored look alone — only strip scripts + harden parts (ScaleTo handles size).
-- circle / burst: shrink + dark readability tweaks.
local function armClone(root: Instance, kind: string)
	local function stripScripts(item: Instance)
		if item:IsA("Script") or item:IsA("LocalScript") then
			item.Enabled = false
			item:Destroy()
		end
	end

	stripScripts(root)
	for _, item in root:GetDescendants() do
		stripScripts(item)
	end

	local function harden(part: BasePart)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
	end
	if root:IsA("BasePart") then
		harden(root)
	end
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			harden(item)
		end
	end

	-- Orb stays 1:1 authored (colors, meshes, beams). ScaleTo + place later.
	-- Strip Dust / OnFinishRing and any lime-green props (second "green orb" blob).
	if kind == "orb" then
		local strip: { Instance } = {}
		local function isGreen(color: Color3): boolean
			return color.G > 0.45 and color.G > color.R + 0.12 and color.G > color.B + 0.08
		end
		local function shouldStrip(item: Instance): boolean
			for _, name in PREMADE.ORB_STRIP_NAMES do
				if item.Name == name or string.find(item.Name, name, 1, true) then
					return true
				end
			end
			if item:IsA("BasePart") and isGreen(item.Color) then
				return true
			end
			if item:IsA("ParticleEmitter") then
				local c0 = item.Color.Keypoints[1].Value
				if isGreen(c0) then
					return true
				end
			end
			return false
		end
		for _, item in root:GetDescendants() do
			if shouldStrip(item) then
				table.insert(strip, item)
			elseif item:IsA("ParticleEmitter") then
				item.Enabled = false
			elseif item:IsA("Beam") or item:IsA("PointLight") then
				item.Enabled = false
			end
		end
		for _, item in strip do
			item:Destroy()
		end
		return
	end

	local sizeMult = if kind == "circle" then PREMADE.CIRCLE_SIZE_MULT else PREMADE.BURST_SIZE_MULT
	local beamMult = if kind == "circle" then PREMADE.CIRCLE_BEAM_WIDTH_MULT else PREMADE.BEAM_WIDTH_MULT

	local function armVisual(item: Instance)
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
			item.LightEmission = PREMADE.GLOW_LIGHT_EMISSION
			item.LightInfluence = PREMADE.GLOW_LIGHT_INFLUENCE
			item.Brightness = math.max(item.Brightness, PREMADE.GLOW_BRIGHTNESS)
			item.Size = scaleNumberSequence(item.Size, sizeMult)
			if kind == "circle" then
				item.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, CIRCLE_DARK),
					ColorSequenceKeypoint.new(0.55, CIRCLE_DARK_MID),
					ColorSequenceKeypoint.new(1, CIRCLE_DARK),
				})
			else
				item.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, PURPLE),
					ColorSequenceKeypoint.new(0.55, Color3.fromRGB(160, 80, 220)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 90)),
				})
			end
		elseif item:IsA("Beam") then
			item.Enabled = false
			item.LightEmission = PREMADE.GLOW_LIGHT_EMISSION
			item.LightInfluence = PREMADE.GLOW_LIGHT_INFLUENCE
			item.Brightness = PREMADE.BEAM_BRIGHTNESS
			item.Width0 = math.max(0.5, item.Width0 * beamMult)
			item.Width1 = math.max(0.5, item.Width1 * beamMult)
			if kind == "circle" then
				item.Color = ColorSequence.new(CIRCLE_DARK, CIRCLE_DARK_MID)
			else
				item.Color = ColorSequence.new(PURPLE, Color3.fromRGB(100, 40, 150))
			end
		elseif item:IsA("PointLight") then
			item.Enabled = false
			item.Brightness = math.max(item.Brightness, PREMADE.GLOW_BRIGHTNESS)
			item.Color = if kind == "circle" then CIRCLE_DARK_MID else PURPLE
		end
	end

	armVisual(root)
	for _, item in root:GetDescendants() do
		armVisual(item)
	end
end

local function setParticles(root: Instance, on: boolean)
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item.Enabled = on
		end
	end
end

local function attachGlowLight(parent: Instance, at: Vector3, range: number, brightness: number, fadeIn: number?): PointLight
	local holder = Instance.new("Part")
	holder.Name = "SealGlowLight"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(at)
	holder.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = range
	light.Brightness = 0
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(fadeIn or 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = brightness,
	}):Play()
	return light
end

local function emitAll(root: Instance, countByName: { [string]: number }?, defaultCount: number)
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local n = defaultCount
			if countByName and countByName[item.Name] ~= nil then
				n = countByName[item.Name]
			end
			if item.Name == "Spikes" then
				n = math.min(n, PREMADE.SPIKES_CAP)
			end
			item:Emit(n)
		end
	end
end

local function setBeams(root: Instance, on: boolean)
	for _, item in root:GetDescendants() do
		if item:IsA("Beam") then
			item.Enabled = on
		elseif item:IsA("PointLight") then
			item.Enabled = on
		end
	end
end

local function feetPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local ground = groundBelow(root.Position)
	return Vector3.new(root.Position.X, ground + PREMADE.GROUND_OFFSET, root.Position.Z)
end

local function placeAt(root: Instance, at: Vector3, yaw: number?)
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw or 0, 0)
	if root:IsA("Model") then
		root:PivotTo(cf)
	elseif root:IsA("BasePart") then
		root.CFrame = cf
	end
end

local function scaleModel(model: Model, scale: number)
	local ok, err = pcall(function()
		model:ScaleTo(scale)
	end)
	if not ok then
		warn("[SealBurst] ScaleTo failed:", err)
	end
end

local function popLight(parent: Instance, at: Vector3, token: number)
	local holder = Instance.new("Part")
	holder.Name = "SealPopLight"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(at)
	holder.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = PREMADE.POP_LIGHT_RANGE
	light.Brightness = PREMADE.POP_LIGHT_BRIGHTNESS
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(T(PREMADE.POP_LIGHT_FADE), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()
	task.delay(T(PREMADE.POP_LIGHT_FADE) + 0.05, function()
		if token == activeToken and holder.Parent then
			holder:Destroy()
		end
	end)
end

local function playPremade(relicId: string, options: Options, sealPosition: Vector3?)
	if options.Low then
		return
	end
	local at = feetPosition()
	if not at then
		return
	end

	-- Fire-and-forget light pulse; never blocks VFX, rewards, or auto-scan.
	if options.Personal then
		startLightPulse()
	end

	clearActive()
	local token = activeToken
	local folder = Instance.new("Folder")
	folder.Name = "SealBurstPremade"
	folder.Parent = workspace
	activeFolder = folder

	local circleSrc = template(CIRCLE_NAME)
	local burstSrc = if PREMADE.ENABLE_BURST then template(BURST_NAME) else nil
	local orbSrc = if PREMADE.ENABLE_ORB then template(ORB_NAME) else nil
	if not circleSrc then
		warn("[SealBurst] ReplicatedStorage.VFX MeteorSpawn missing — premade seal skipped")
		folder:Destroy()
		if activeFolder == folder then
			activeFolder = nil
		end
		return
	end

	-- Sealed curse world point (signal / bind position). Burst goes here, not on the player.
	local curseAt: Vector3? = nil
	if sealPosition then
		curseAt = sealPosition + Vector3.new(0, PREMADE.BURST_CURSE_LIFT, 0)
	end

	local connections: { RBXScriptConnection } = {}
	local function track(conn: RBXScriptConnection)
		table.insert(connections, conn)
	end
	local function disconnectAll()
		for _, conn in connections do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		table.clear(connections)
	end

	-- —— Stage 1: circle (Beams + wave particles; flat ring at feet) ——
	-- Method: MeteorSpawn's Beams laid as a ring (LightEmission forced to 1) + Emit waves.
	-- Not SurfaceGui — purchased asset already uses Beams on an invisible Part.
	if circleSrc then
		local circle = circleSrc:Clone()
		armClone(circle, "circle")
		placeAt(circle, at)
		if circle:IsA("Model") then
			scaleModel(circle, PREMADE.CIRCLE_SCALE_START)
		elseif circle:IsA("BasePart") then
			circle.Size = circle.Size * PREMADE.CIRCLE_SCALE_START
		end
		circle.Parent = folder
		setBeams(circle, true)

		local t0 = os.clock()
		local growDur = T(PREMADE.CIRCLE_GROW)
		local circleEnd = T(PREMADE.CIRCLE_END)
		local fadeStart = T(PREMADE.FADE_START)
		local fadeEnd = T(PREMADE.FADE_END)
		local emitted = false

		if circle:IsA("Model") then
			local model = circle
			track(RunService.RenderStepped:Connect(function()
				if token ~= activeToken or not model.Parent then
					return
				end
				local elapsed = os.clock() - t0
				local growU = math.clamp(elapsed / growDur, 0, 1)
				local scale = PREMADE.CIRCLE_SCALE_START
					+ (PREMADE.CIRCLE_SCALE_END - PREMADE.CIRCLE_SCALE_START) * easeOutBack(growU)
				if elapsed >= fadeStart then
					local f = math.clamp((elapsed - fadeStart) / math.max(1e-3, fadeEnd - fadeStart), 0, 1)
					scale = PREMADE.CIRCLE_SCALE_END * (1 - f)
					if f > 0.5 then
						setBeams(model, false)
					end
				end
				scaleModel(model, math.max(0.05, scale))
				model:PivotTo(CFrame.new(at) * CFrame.Angles(0, elapsed * PREMADE.CIRCLE_SPIN, 0))
				if not emitted and elapsed >= T(PREMADE.CIRCLE_EMIT_AT) then
					emitted = true
					emitAll(model, PREMADE.CIRCLE_EMIT, PREMADE.DEFAULT_EMIT)
				end
			end))
		elseif circle:IsA("BasePart") then
			local part = circle
			local full = part.Size / PREMADE.CIRCLE_SCALE_START
			TweenService:Create(part, TweenInfo.new(growDur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = full * PREMADE.CIRCLE_SCALE_END,
			}):Play()
			track(RunService.RenderStepped:Connect(function()
				if token ~= activeToken or not part.Parent then
					return
				end
				local elapsed = os.clock() - t0
				part.CFrame = CFrame.new(at) * CFrame.Angles(0, elapsed * PREMADE.CIRCLE_SPIN, 0)
				if not emitted and elapsed >= T(PREMADE.CIRCLE_EMIT_AT) then
					emitted = true
					emitAll(part, PREMADE.CIRCLE_EMIT, PREMADE.DEFAULT_EMIT)
				end
				if elapsed >= circleEnd then
					setBeams(part, false)
				end
			end))
		end
	end

	-- —— Stage 2: PurpleSpikeBurst on the sealed curse (not the player) ——
	if PREMADE.ENABLE_BURST and curseAt and burstSrc then
		local burstAt = curseAt
		task.delay(T(PREMADE.BURST_AT), function()
			if token ~= activeToken or not folder.Parent or not burstSrc then
				return
			end
			local burst = burstSrc:Clone()
			armClone(burst, "burst")
			if burst:IsA("Model") then
				scaleModel(burst, PREMADE.BURST_SCALE)
			end
			placeAt(burst, burstAt)
			burst.Parent = folder
			local burstLight = attachGlowLight(folder, burstAt, PREMADE.BURST_LIGHT_RANGE, PREMADE.BURST_LIGHT_BRIGHTNESS)
			emitAll(burst, PREMADE.BURST_EMIT, 10)
			setBeams(burst, true)
			if options.Personal then
				Sounds.Play("Seal")
			end
			task.delay(T(PREMADE.BURST_END - PREMADE.BURST_AT), function()
				if token ~= activeToken then
					return
				end
				if burst.Parent then
					setBeams(burst, false)
					burst:Destroy()
				end
				if burstLight.Parent then
					TweenService:Create(burstLight, TweenInfo.new(T(0.12)), { Brightness = 0 }):Play()
				end
			end)
		end)
	elseif options.Personal then
		task.delay(T(PREMADE.CIRCLE_EMIT_AT), function()
			if token == activeToken then
				Sounds.Play("Seal")
			end
		end)
	end

	-- —— Stage 3: DarkOrbSkill on the curse — spike ends → object becomes energy → vanishes ——
	-- White CaptureAnimation relic only starts after this (SealBurst.RevealAt = orb done).
	if PREMADE.ENABLE_ORB and sealPosition then
		task.delay(T(PREMADE.ORB_AT), function()
			if token ~= activeToken or not folder.Parent then
				return
			end
			local orbAt = orbHoverAt(sealPosition)
			popLight(folder, orbAt, token)
			if orbSrc then
				local orb = orbSrc:Clone()
				armClone(orb, "orb")
				if orb:IsA("Model") then
					scaleModel(orb, PREMADE.ORB_SCALE)
				end
				orb.Parent = folder
				placeOrbCentered(orb, orbAt, 0)
				dumpOrbTree(orb)
				-- Authored orb as-is at the curse: swirl, then fade out.
				setBeams(orb, true)
				setParticles(orb, true)
				local orbT0 = os.clock()
				track(RunService.RenderStepped:Connect(function()
					if token ~= activeToken or not orb.Parent then
						return
					end
					-- Re-raycast lightly in case terrain differs; keep XZ on the seal.
					local hover = orbHoverAt(sealPosition)
					local yaw = (os.clock() - orbT0) * PREMADE.ORB_SPIN
					placeOrbCentered(orb, hover, yaw)
				end))
				local playFor = T(PREMADE.ORB_PLAY_SECONDS)
				task.delay(playFor, function()
					if token ~= activeToken or not orb.Parent then
						return
					end
					setParticles(orb, false)
					setBeams(orb, false)
				end)
			end
			if options.Personal then
				HuntFX.shake(0.28, 0.3)
			end
			local color = tierLook(relicId)
			ChainRig.SealFlash(orbAt, 8)
			HuntFX.shockwave(Vector3.new(orbAt.X, at.Y, orbAt.Z), color, 14, 0.45)
		end)
	end

	local cleanupAt = math.min(
		T(math.max(PREMADE.FADE_END, PREMADE.ORB_END) + PREMADE.CLEANUP_AFTER_FADE),
		T(PREMADE.MAX_CLEANUP)
	)
	task.delay(cleanupAt, function()
		disconnectAll()
		if token == activeToken and activeFolder == folder then
			activeFolder = nil
			if folder.Parent then
				folder:Destroy()
			end
		end
	end)
end

local function playLegacy(position: Vector3, relicId: string, options: Options)
	local color, strength = tierLook(relicId)
	local folder = Instance.new("Folder")
	folder.Name = "SealBurst"
	folder.Parent = workspace

	local jar, jarTurn, height = makeJar()
	jar.Name = "SealJar"
	local jarSize = jar.Size
	jar.Size = jarSize * 0.05
	jar.Parent = folder
	local glow = Instance.new("PointLight")
	glow.Color = SPIRIT_COLOR
	glow.Range = 10
	glow.Brightness = 0
	glow.Parent = jar
	local ground = groundBelow(position)
	local jarAt = Vector3.new(position.X, ground + height / 2 + 0.05, position.Z)
	local mouth = jarAt + Vector3.new(0, height * 0.45, 0)

	local spirit = HuntFX.core(SPIRIT_SIZE, SPIRIT_COLOR, options.Low)
	spirit.Part.Parent = folder
	local spiritFrom = mouth + Vector3.new(0, 2.6, 0)

	local slammed = false
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start

		local scale = easeOutBack(span(t, 0, APPEAR_END))
		local spin = (1 - span(t, 0, APPEAR_END)) * math.pi * 2
		local wobble = CFrame.identity
		local rattle = span(t, SWALLOW_END, SLAM_AT)
		if rattle > 0 and t < SLAM_AT then
			local amount = 0.08 + rattle * 0.22
			wobble = CFrame.Angles(math.sin(t * 70) * amount, 0, math.cos(t * 63) * amount)
		elseif t >= SLAM_AT then
			local squash = span(t, SLAM_AT, SLAM_AT + 0.25)
			scale = 1 + 0.2 * math.sin(squash * math.pi)
		end
		local sink = span(t, SINK_START, SealBurst.Seconds)
		scale *= 1 - sink
		jar.Size = jarSize * math.max(0.05, scale)
		jar.CFrame = CFrame.new(jarAt - Vector3.new(0, sink * height, 0)) * CFrame.Angles(0, spin, 0) * wobble * jarTurn
		glow.Brightness = (span(t, SWALLOW_START, SWALLOW_END) * 3 + (if t >= SLAM_AT then 2 else 0)) * (1 - sink)
		glow.Color = if t >= SLAM_AT then color else SPIRIT_COLOR

		if spirit.Part.Parent then
			local u = span(t, SWALLOW_START, SWALLOW_END)
			local eased = u * u
			local angle = u * math.pi * 5
			local radius = (1 - u) * 1.4
			local thrash = (1 - u) * 0.25
			local offset = Vector3.new(
				math.cos(angle) * radius + math.sin(t * 37) * thrash,
				math.sin(t * 29) * thrash,
				math.sin(angle) * radius + math.cos(t * 41) * thrash
			)
			spirit.Part.Size = spirit.Size * math.max(0.05, 1 - eased * 0.95)
			spirit.Part.CFrame = CFrame.new(spiritFrom:Lerp(mouth, eased) + offset)
				* CFrame.Angles(0, t * (4 + u * 20), 0)
				* spirit.Turn
			if u >= 1 then
				spirit.Part:Destroy()
				if not options.Low then
					HuntFX.burst(mouth, SPIRIT_COLOR, 10, 4)
				end
			end
		end

		if t >= SLAM_AT and not slammed then
			slammed = true
			ChainRig.SealFlash(mouth, 10 + 10 * strength)
			HuntFX.shockwave(Vector3.new(position.X, ground, position.Z), color, 24 + 36 * strength, 0.7)
			if not options.Low then
				HuntFX.burst(mouth, color, math.floor(24 + 40 * strength), 14 + 10 * strength)
			end
			if options.Personal then
				Sounds.Play("Seal")
				HuntFX.shake(0.35 + 0.5 * strength, 0.4 + 0.3 * strength)
			end
		end

		if t >= SealBurst.Seconds then
			connection:Disconnect()
			folder:Destroy()
		end
	end)
end

function SealBurst.Play(position: Vector3, relicId: string, options: Options)
	if USE_PREMADE_VFX then
		if options.Personal then
			playPremade(relicId, options, position)
		end
		return
	end
	playLegacy(position, relicId, options)
end

function SealBurst.PlayScan(relicId: string?)
	if not USE_PREMADE_VFX or not PREMADE.PLAY_ON_SCAN then
		return
	end
	-- No sealed-curse position on AFK scan — circle (+ orb) on player only.
	playPremade(relicId or "", { Low = false, Personal = true }, nil)
end

function SealBurst.UsingPremade(): boolean
	return USE_PREMADE_VFX
end

-- Optional: wire AFK scan seals when PREMADE.PLAY_ON_SCAN is true (off by default —
-- rolling stays UI-only; Hunt bind uses SealBurst.Play).
function SealBurst.Start()
	if started then
		return
	end
	started = true
	if not PREMADE.PLAY_ON_SCAN then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local discovery = remotes:WaitForChild("DiscoveryResult") :: RemoteEvent
	discovery.OnClientEvent:Connect(function(results)
		if not USE_PREMADE_VFX or type(results) ~= "table" then
			return
		end
		local scanId: string? = nil
		for _, result in results do
			if type(result) == "table" and result.Source == "Capture" then
				return
			end
			if type(result) == "table" and result.Source == "Scan" and type(result.Id) == "string" then
				scanId = result.Id
			end
		end
		if scanId then
			task.defer(SealBurst.PlayScan, scanId)
		end
	end)
end

return SealBurst
