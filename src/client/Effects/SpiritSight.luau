-- Client-only Spirit Sight visuals and sounds. Each of the owner's signals is a spirit core
-- (SignalCore mesh) circled by ofuda talismans above a rune ring, with a light pillar that is
-- seen from afar right after a pulse. Signals hum and whisper so they can be found by ear, and
-- their ring lights up once close enough to bind. During the bind the talismans lock into a seal
-- around the core and burn away one per beat (Bind/BindStep/Unbind). A pulse sends a ground
-- shockwave and a wisp racing to every signal, which pings when it arrives.
-- Every signal looks and sounds identical on purpose: nothing here may hint at a relic's rarity.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local Ambience = require(script.Parent.Ambience)
local HuntFX = require(script.Parent.HuntFX)
local HuntModels = require(script.Parent.HuntModels)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local SpiritSight = {}

local pulsed = Instance.new("BindableEvent")
-- Fires (origin: Vector3) whenever the local player pulses.
SpiritSight.Pulsed = pulsed.Event

local SIGNAL_COLOR = Color3.fromRGB(140, 220, 255)
local TRAIL_COLOR = Color3.fromRGB(180, 140, 255)
local SEAL_COLOR = Color3.fromRGB(190, 150, 255)
local IGNITE_COLOR = Color3.fromRGB(255, 120, 220)
local CORE_SIZE = 2.4
local TALISMAN_COUNT = 3
local TALISMAN_SIZE = 1.6
local ORBIT_RADIUS = 2.6
-- Studs kept between a talisman's bottom edge and the ground.
local GROUND_CLEARANCE = 0.3
local RING_DIAMETER = 9
local PILLAR_HEIGHT = 60
-- Studs per second the pulse wisps travel; each signal pings when its wisp arrives.
local PING_SPEED = 90
-- Seconds the talismans take to leave their orbit and lock into the seal.
local GATHER_SECONDS = 0.35
-- Seconds a talisman takes to burn away after its beat.
local BURN_SECONDS = 0.6
-- The light that blooms from the player on a pulse.
local FLASH_RANGE = 60
local FLASH_BRIGHTNESS = 2.5
local FLASH_SECONDS = 1.1

-- Zone mastery widens sight and landmark range where it applies (MasteryService).
local function rangeFactor(): number
	local factor = Players.LocalPlayer:GetAttribute("SightRangeFactor")
	return if type(factor) == "number" then factor else 1
end

type Signal = {
	Id: number,
	Base: Vector3,
	Ground: number,
	Phase: number,
	Group: Model,
	Core: HuntFX.Core,
	Talismans: { BasePart },
	TalismanTurn: CFrame,
	TalismanSize: Vector3,
	Ring: Part,
	-- Terrain attachments: sounds at the core, the pillar from the ground up.
	Anchor: Attachment,
	Foot: Attachment,
	Top: Attachment,
	Pillar: Beam,
	Loops: { Sound },
	-- Seconds the pillar keeps showing after a pulse reached this signal.
	Flare: number,
	PillarFade: number,
	Swell: number,
	Scale: number,
	Spin: number,
	Orbit: number,
	Visible: boolean,
	Ready: boolean?,
	-- Fire and lights added to ignited talismans during a bind.
	Ignites: { Instance },
}

type Bound = {
	Signal: Signal,
	Clock: number,
	Lit: number,
	-- Bind clock at which each talisman (by index) started burning.
	BurnedAt: { [number]: number },
	Facing: Vector3,
	From: { CFrame },
}

local folder = Instance.new("Folder")
folder.Name = "SpiritSignals"

local signals: { [number]: Signal } = {}
local bound: Bound? = nil
local enabled = false
local clock = 0
local ambience: Sound? = nil
-- Part 3D sounds are heard from while Spirit Sight is on (nil: the camera, Roblox's default).
local listener: Instance? = nil

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "SpiritSightTint"
tint.Saturation = -0.35
tint.Contrast = 0.1
tint.TintColor = Color3.fromRGB(205, 190, 255)
tint.Enabled = false
tint.Parent = Lighting

local function groundBelow(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = workspace:Raycast(position, Vector3.new(0, -20, 0), params)
	return if hit then hit.Position.Y else position.Y - Config.Signals.HoverHeight
end

-- Upright frame whose Y faces `normal` and Z points up (aligned talisman meshes stand on it).
local function standing(position: Vector3, normal: Vector3): CFrame
	return CFrame.fromMatrix(position, normal:Cross(Vector3.yAxis).Unit, normal, Vector3.yAxis)
end

local function terrainAttachment(name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	return attachment
end

local function placeAnchors(signal: Signal)
	signal.Anchor.Position = signal.Base
	signal.Foot.Position = Vector3.new(signal.Base.X, signal.Ground, signal.Base.Z)
	signal.Top.Position = Vector3.new(signal.Base.X, signal.Ground + PILLAR_HEIGHT, signal.Base.Z)
end

local function makeSignal(id: number, position: Vector3): Signal
	local low = Settings.LowEffects()
	local group = Instance.new("Model")
	group.Name = `Signal{id}`
	local core = HuntFX.core(CORE_SIZE, SIGNAL_COLOR, low)
	core.Part.Parent = group

	local talismans = {}
	local talismanTurn = CFrame.identity
	for _ = 1, TALISMAN_COUNT do
		local built = HuntModels.build("OfudaTalisman", TALISMAN_SIZE, true)
		local part: BasePart
		if built then
			part = built.Part
			talismanTurn = built.Turn
		else
			part = HuntFX.part({
				Size = Vector3.new(0.7, 0.05, TALISMAN_SIZE),
				Color = Color3.fromRGB(240, 225, 190),
				Material = Enum.Material.SmoothPlastic,
			})
		end
		part.Name = "Talisman"
		part.Parent = group
		table.insert(talismans, part)
	end

	local ring = HuntFX.ring(RING_DIAMETER, SIGNAL_COLOR, true)
	ring.Parent = group

	local anchor = terrainAttachment("SignalAnchor", position)
	local foot = terrainAttachment("SignalFoot", position)
	local top = terrainAttachment("SignalTop", position)
	local pillar = Instance.new("Beam")
	pillar.Attachment0 = foot
	pillar.Attachment1 = top
	pillar.Color = ColorSequence.new(SIGNAL_COLOR, TRAIL_COLOR)
	pillar.LightEmission = 1
	pillar.LightInfluence = 0
	pillar.Width0 = 2.4
	pillar.Width1 = 0.5
	pillar.FaceCamera = true
	pillar.Texture = HuntFX.SPARKLES
	pillar.TextureMode = Enum.TextureMode.Wrap
	pillar.TextureLength = 6
	pillar.TextureSpeed = 0.6
	pillar.Transparency = NumberSequence.new(0.35, 1)
	pillar.Enabled = false
	pillar.Parent = foot

	local signal: Signal = {
		Id = id,
		Base = position,
		Ground = groundBelow(position),
		Phase = id * 1.7,
		Group = group,
		Core = core,
		Talismans = talismans,
		TalismanTurn = talismanTurn,
		TalismanSize = talismans[1].Size,
		Ring = ring,
		Anchor = anchor,
		Foot = foot,
		Top = top,
		Pillar = pillar,
		Loops = {},
		Flare = 0,
		PillarFade = 0.35,
		Swell = 0,
		Scale = 1,
		Spin = id * 0.9,
		Orbit = id * 1.3,
		Visible = false,
		Ready = nil,
		Ignites = {},
	}
	placeAnchors(signal)
	return signal
end

local function destroySignal(signal: Signal)
	if bound and bound.Signal == signal then
		bound = nil
	end
	signal.Group:Destroy()
	signal.Anchor:Destroy()
	signal.Foot:Destroy()
	signal.Top:Destroy()
	table.clear(signal.Loops)
end

-- While on, 3D sounds are heard from the character's head rather than the camera, so a zoomed-out
-- camera can still hear the whispers next to you.
local function setListener(on: boolean)
	local character = Players.LocalPlayer.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	local wanted = if on then head else nil
	if wanted == listener then
		return
	end
	listener = wanted
	if wanted then
		SoundService:SetListener(Enum.ListenerType.ObjectPosition, wanted)
	else
		SoundService:SetListener(Enum.ListenerType.Camera)
	end
end

-- Hum and whisper loops only play while Spirit Sight is on.
local function setSignalSound(signal: Signal, on: boolean)
	if on and #signal.Loops == 0 then
		for _, name in { "SignalHum", "SignalWhisper" } do
			local loop = Sounds.Loop(name, signal.Anchor)
			if loop then
				loop.TimePosition = signal.Phase % 3
				table.insert(signal.Loops, loop)
			end
		end
	elseif not on then
		for _, loop in signal.Loops do
			loop:Destroy()
		end
		table.clear(signal.Loops)
	end
end

local function setCoreScale(signal: Signal, scale: number)
	if math.abs(scale - signal.Scale) > 0.005 then
		signal.Scale = scale
		signal.Core.Part.Size = signal.Core.Size * scale
	end
end

-- Keeps a standing talisman's bottom edge above the ground under its signal.
local function aboveGround(signal: Signal, position: Vector3): Vector3
	local lowest = signal.Ground + TALISMAN_SIZE / 2 + GROUND_CLEARANCE
	return if position.Y < lowest then Vector3.new(position.X, lowest, position.Z) else position
end

local function placeIdle(signal: Signal)
	local bob = math.sin(clock * 2 + signal.Phase) * 0.4
	local center = signal.Base + Vector3.new(0, bob, 0)
	setCoreScale(signal, 1 + signal.Swell * 0.5)
	signal.Core.Part.CFrame = CFrame.new(center) * CFrame.Angles(0, signal.Spin, 0) * signal.Core.Turn
	for index, talisman in signal.Talismans do
		local angle = signal.Orbit + (index - 1) / #signal.Talismans * math.pi * 2
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local height = math.sin(clock * 1.7 + index * 2.1) * 0.5
		talisman.CFrame = standing(aboveGround(signal, center + radial * ORBIT_RADIUS + Vector3.new(0, height, 0)), radial)
			* signal.TalismanTurn
	end
	signal.Ring.CFrame = CFrame.new(signal.Base.X, signal.Ground + 0.12, signal.Base.Z)
		* CFrame.Angles(0, -signal.Spin * 0.4, 0)
end

function SpiritSight.SetSignals(list: { [number]: Vector3 })
	for id, signal in signals do
		if not list[id] then
			destroySignal(signal)
			signals[id] = nil
		end
	end
	for id, position in list do
		local signal = signals[id]
		if not signal then
			local created = makeSignal(id, position)
			signals[id] = created
			setSignalSound(created, enabled)
		elseif (signal.Base - position).Magnitude > 0.1 then
			-- Signals follow the player into another district, keeping their ids.
			signal.Base = position
			signal.Ground = groundBelow(position)
			placeAnchors(signal)
		end
	end
end

-- Drops a signal right away (it was just captured; the server's update follows).
function SpiritSight.Remove(id: number)
	local signal = signals[id]
	if signal then
		destroySignal(signal)
		signals[id] = nil
	end
end

function SpiritSight.SetEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	folder.Parent = if on then workspace else nil
	tint.Enabled = on
	for _, signal in signals do
		setSignalSound(signal, on)
		if not on then
			signal.Pillar.Enabled = false
			signal.Flare = 0
		end
	end
	setListener(on)
	Sounds.Play(if on then "SightOn" else "SightOff")
	if ambience then
		ambience:Destroy()
		ambience = nil
	end
	if on then
		ambience = Sounds.Loop("SightAmbience")
	end
end

function SpiritSight.IsEnabled(): boolean
	return enabled
end

function SpiritSight.GetOrb(id: number): BasePart?
	local signal = signals[id]
	return if signal then signal.Core.Part else nil
end

-- Animates every signal not being bound, hides those beyond reveal range and fades pillars.
function SpiritSight.Update(dt: number, viewer: Vector3?)
	clock += dt
	if not enabled then
		return
	end
	-- Follows respawns (a new character has a new head).
	setListener(true)
	local rank = Players.LocalPlayer:GetAttribute("Skill_SpiritSight")
	local revealRange = SkillConfig.sightRange(if type(rank) == "number" then rank else 0) * rangeFactor()
	for _, signal in signals do
		local isBound = bound ~= nil and bound.Signal == signal
		signal.Flare = math.max(0, signal.Flare - dt)
		local distance = if viewer then (signal.Base - viewer).Magnitude else math.huge
		local visible = isBound or distance <= revealRange
		if visible ~= signal.Visible then
			signal.Visible = visible
			signal.Group.Parent = if visible then folder else nil
		end

		local flare = signal.Flare / Config.SpiritSight.PulseSeconds
		local pillarOn = visible or flare > 0
		signal.Pillar.Enabled = pillarOn
		-- Within reveal range the pillar is steady; beyond it, it fades as the pulse flare ends.
		local fade = if visible then 0.35 else 0.35 + (1 - flare) * 0.65
		if pillarOn and math.abs(fade - signal.PillarFade) > 0.01 then
			signal.PillarFade = fade
			signal.Pillar.Transparency = NumberSequence.new(fade, 1)
		end

		if not visible or isBound then
			continue
		end
		local ready = distance <= Config.Bind.LockRange
		if ready ~= signal.Ready then
			signal.Ready = ready
			HuntFX.tintRing(signal.Ring, SIGNAL_COLOR, if ready then 0 else 0.5)
		end
		local speed = if ready then 2.5 else 1
		signal.Spin += dt * 0.8 * speed
		signal.Orbit += dt * 1.2 * speed
		signal.Swell = math.max(0, signal.Swell - dt * 2.5)
		placeIdle(signal)
	end
end

-- Starts the bind look on signal `id` (talismans lock into a seal facing `from`). Returns the
-- core part, whose "Core" attachment the chains aim at.
function SpiritSight.Bind(id: number, from: Vector3): BasePart?
	local signal = signals[id]
	if not signal then
		return nil
	end
	local facing = from - signal.Base
	facing = Vector3.new(facing.X, 0, facing.Z)
	local start = {}
	for index, talisman in signal.Talismans do
		start[index] = talisman.CFrame
	end
	bound = {
		Signal = signal,
		Clock = 0,
		Lit = 0,
		BurnedAt = {},
		Facing = if facing.Magnitude > 0.1 then facing.Unit else Vector3.zAxis,
		From = start,
	}
	return signal.Core.Part
end

local function ignite(signal: Signal, talisman: BasePart)
	local light = Instance.new("PointLight")
	light.Color = IGNITE_COLOR
	light.Range = 6
	light.Brightness = 2
	light.Parent = talisman
	table.insert(signal.Ignites, light)
	if Settings.LowEffects() then
		return
	end
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = HuntFX.FIRE
	fire.Color = ColorSequence.new(IGNITE_COLOR, SEAL_COLOR)
	fire.LightEmission = 1
	fire.Rate = 30
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Speed = NumberRange.new(1, 2)
	fire.Acceleration = Vector3.new(0, 4, 0)
	fire.Size = NumberSequence.new(0.6, 0)
	fire.Parent = talisman
	table.insert(signal.Ignites, fire)
	HuntFX.burst(talisman.Position, IGNITE_COLOR, 14, 8)
end

-- progress 0..1 over the hold; `hand` is where the chains leave the player's hand. `tug` -1..1:
-- positive while the player hauls the spirit in, negative while it pulls away (SealPose.Tug).
function SpiritSight.BindStep(dt: number, progress: number, hand: Vector3?, tug: number?)
	local state = bound
	if not state then
		return
	end
	local signal = state.Signal
	state.Clock += dt
	local t = state.Clock

	-- One talisman burns away at each chain beat, the last one when the pull starts.
	local lit = 0
	for index, at in Config.Bind.TightenAt do
		if progress >= at then
			lit = index
		end
	end
	if progress >= Config.Bind.PullAt then
		lit = #Config.Bind.TightenAt + 1
	end
	while state.Lit < math.min(lit, #signal.Talismans) do
		state.Lit += 1
		ignite(signal, signal.Talismans[state.Lit])
		state.BurnedAt[state.Lit] = t
	end

	-- The core thrashes harder as the bind tightens, then is dragged toward the hand.
	local shake = 0.12 + progress * 0.4
	local jitter = Vector3.new(math.sin(t * 37) * shake, math.sin(t * 29 + 1) * shake, math.cos(t * 41) * shake)
	local pull = math.max(0, progress - Config.Bind.PullAt) / (1 - Config.Bind.PullAt)
	local center = signal.Base
	if hand then
		center = center:Lerp(hand, pull * 0.35)
		local toward = Vector3.new(hand.X - signal.Base.X, 0, hand.Z - signal.Base.Z)
		if toward.Magnitude > 0.1 then
			local amount = tug or 0
			center += toward.Unit * (if amount > 0 then amount * 0.8 else amount * 0.6)
		end
	end
	center += jitter
	signal.Spin += dt * (1.5 + progress * 10)
	local heartbeat = math.max(0, math.sin(t * (5 + progress * 8))) ^ 6
	setCoreScale(signal, (1 + progress * 0.3) * (1 + heartbeat * 0.12) * (1 - pull * 0.3))
	signal.Core.Part.CFrame = CFrame.new(center) * CFrame.Angles(0, signal.Spin, 0) * signal.Core.Turn
	local light = signal.Core.Part:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 1.5 + progress * 3
		light.Range = 12 + progress * 8
	end

	-- Talismans leave their orbit and form a turning seal between the core and the player,
	-- trembling; each burned one drifts up, shrinks and fades away.
	local gather = math.min(1, t / GATHER_SECONDS)
	gather = 1 - (1 - gather) ^ 3
	local right = state.Facing:Cross(Vector3.yAxis).Unit
	-- The seal circle flattens into an oval when the core floats too low for a full circle.
	local lift = math.clamp(signal.Base.Y - signal.Ground - TALISMAN_SIZE / 2 - GROUND_CLEARANCE, 0.6, ORBIT_RADIUS)
	for index, talisman in signal.Talismans do
		local burnedAt = state.BurnedAt[index]
		local burn = if burnedAt then math.min(1, (t - burnedAt) / BURN_SECONDS) else 0
		if burn >= 1 then
			if talisman.Parent then
				talisman.Parent = nil
			end
			continue
		end
		local angle = (index - 1) / #signal.Talismans * math.pi * 2 + t * (0.6 + progress * 2)
		local tremble = Vector3.new(0, math.sin(t * 45 + index) * 0.06 * progress, 0)
		local position = center
			+ right * math.cos(angle) * ORBIT_RADIUS
			+ Vector3.yAxis * math.sin(angle) * lift
			+ state.Facing * 0.9
			+ tremble
			+ Vector3.new(0, burn * 1.5, 0)
		position = aboveGround(signal, position)
		local goal = standing(position, state.Facing) * CFrame.Angles(0, burn * 2, 0) * signal.TalismanTurn
		talisman.CFrame = (state.From[index] or goal):Lerp(goal, gather)
		if burn > 0 then
			talisman.Size = signal.TalismanSize * (1 - burn * 0.7)
			talisman.Transparency = burn
		end
	end

	local ringSize = RING_DIAMETER * (1 - pull * 0.5)
	signal.Ring.Size = Vector3.new(ringSize, 0.05, ringSize)
	signal.Ring.CFrame = CFrame.new(signal.Base.X, signal.Ground + 0.12, signal.Base.Z)
		* CFrame.Angles(0, -signal.Spin * 0.4, 0)
	HuntFX.tintRing(signal.Ring, SIGNAL_COLOR:Lerp(SEAL_COLOR, progress), 0)
end

-- Ends the bind look; the signal goes back to idling (if it still exists).
function SpiritSight.Unbind()
	local state = bound
	if not state then
		return
	end
	bound = nil
	local signal = state.Signal
	for _, item in signal.Ignites do
		item:Destroy()
	end
	table.clear(signal.Ignites)
	for _, talisman in signal.Talismans do
		talisman.Size = signal.TalismanSize
		talisman.Transparency = 0
		talisman.Parent = signal.Group
	end
	setCoreScale(signal, 1)
	local light = signal.Core.Part:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 1.5
		light.Range = 12
	end
	signal.Ring.Size = Vector3.new(RING_DIAMETER, 0.05, RING_DIAMETER)
	signal.Ready = nil
end

type Wisp = {
	Part: BasePart,
	From: Vector3,
	Control: Vector3,
	Signal: Signal,
	Seconds: number,
	Arrived: boolean,
}

local function arrive(signal: Signal, low: boolean)
	if not enabled or signals[signal.Id] ~= signal then
		return
	end
	signal.Flare = Config.SpiritSight.PulseSeconds
	Sounds.Play("SignalPing", signal.Anchor)
	if bound and bound.Signal == signal then
		return
	end
	signal.Swell = 1
	if signal.Visible and not low then
		HuntFX.burst(signal.Base, SIGNAL_COLOR, 12, 6)
	end
end

local function makeWisp(from: Vector3, signal: Signal, low: boolean): Wisp
	local target = signal.Base
	local distance = (target - from).Magnitude
	local side = (target - from):Cross(Vector3.yAxis)
	side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
	local control = from:Lerp(target, 0.5)
		+ Vector3.new(0, distance * 0.25, 0)
		+ side * (math.random() - 0.5) * distance * 0.4
	local part = HuntFX.part({
		Name = "PulseWisp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.7,
		Color = SIGNAL_COLOR,
		CFrame = CFrame.new(from),
	})
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.5, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.5, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(SIGNAL_COLOR, TRAIL_COLOR)
	trail.LightEmission = 1
	trail.Lifetime = if low then 0.6 else 1.6
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.FaceCamera = true
	trail.Parent = part
	part.Parent = workspace
	return {
		Part = part,
		From = from,
		Control = control,
		Signal = signal,
		Seconds = math.max(0.15, distance / PING_SPEED),
		Arrived = false,
	}
end

-- A wide light that blooms from the player with the shockwave, then dies.
local function flashLight(origin: Vector3)
	local holder = HuntFX.part({ Name = "PulseLight", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(origin) })
	local light = Instance.new("PointLight")
	light.Color = SIGNAL_COLOR
	light.Range = FLASH_RANGE
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	holder.Parent = workspace
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / FLASH_SECONDS
		if t >= 1 then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		light.Brightness = FLASH_BRIGHTNESS * (if t < 0.12 then t / 0.12 else (1 - t) / 0.88)
	end)
end

-- Outlines the nearest landmarks for a few seconds so you can find your way in the fog.
local function echoLandmarks(origin: Vector3)
	local cfg = Config.SpiritSight
	local range = cfg.LandmarkRange * rangeFactor()
	local found: { { Model: Model, Distance: number } } = {}
	for _, model in CollectionService:GetTagged("Landmark") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local distance = (model:GetPivot().Position - origin).Magnitude
			if distance <= range then
				table.insert(found, { Model = model, Distance = distance })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Distance < b.Distance
	end)
	local highlights: { { Highlight: Highlight, Delay: number } } = {}
	for index = 1, math.min(cfg.LandmarkCount, #found) do
		local entry = found[index]
		local highlight = Instance.new("Highlight")
		highlight.Name = "PulseEcho"
		highlight.Adornee = entry.Model
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = SIGNAL_COLOR
		highlight.FillTransparency = 1
		highlight.OutlineColor = SIGNAL_COLOR
		highlight.OutlineTransparency = 1
		highlight.Parent = entry.Model
		-- Lights up when the shockwave would reach it.
		table.insert(highlights, { Highlight = highlight, Delay = entry.Distance / PING_SPEED })
	end
	if #highlights == 0 then
		return
	end
	local seconds = cfg.PulseSeconds
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		local done = true
		for _, entry in highlights do
			local t = (elapsed - entry.Delay) / seconds
			if t < 1 then
				done = false
			end
			local shown = if t < 0 then 0 elseif t < 0.08 then t / 0.08 else math.max(0, 1 - (t - 0.08) / 0.92)
			entry.Highlight.OutlineTransparency = 1 - shown * 0.85
			entry.Highlight.FillTransparency = 1 - shown * 0.12
		end
		if done then
			connection:Disconnect()
			for _, entry in highlights do
				entry.Highlight:Destroy()
			end
		end
	end)
end

-- Ground shockwave from the player plus a wisp flying to every signal; each pings on arrival and
-- shows its pillar for a few seconds, even beyond reveal range. In the wild the fog lifts for a
-- moment and the nearest landmarks are outlined.
function SpiritSight.Pulse(root: BasePart)
	local low = Settings.LowEffects()
	local origin = root.Position
	Sounds.Play("Pulse")
	HuntFX.shockwave(Vector3.new(origin.X, groundBelow(origin), origin.Z), TRAIL_COLOR, 120, 1)
	HuntFX.shake(0.25, 0.35)
	Ambience.Reveal()
	flashLight(origin)
	echoLandmarks(origin)
	pulsed:Fire(origin)
	if not low then
		HuntFX.burst(origin, TRAIL_COLOR, 25, 14)
	end

	local wisps: { Wisp } = {}
	for _, signal in signals do
		table.insert(wisps, makeWisp(origin, signal, low))
	end
	if #wisps == 0 then
		return
	end
	local linger = if low then 0.6 else 1.6
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		local done = true
		for _, wisp in wisps do
			local t = math.min(1, elapsed / wisp.Seconds)
			if not wisp.Arrived then
				local target = wisp.Signal.Base
				local a = wisp.From:Lerp(wisp.Control, t)
				local b = wisp.Control:Lerp(target, t)
				wisp.Part.CFrame = CFrame.new(a:Lerp(b, t))
				if t >= 1 then
					wisp.Arrived = true
					wisp.Part.Transparency = 1
					arrive(wisp.Signal, low)
				end
			end
			if elapsed < wisp.Seconds + linger then
				done = false
			end
		end
		if done then
			connection:Disconnect()
			for _, wisp in wisps do
				wisp.Part:Destroy()
			end
		end
	end)
end

return SpiritSight
