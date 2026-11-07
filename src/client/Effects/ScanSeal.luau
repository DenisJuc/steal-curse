-- The short seal under the player on every landed scan (RollReel.OnResults, so it lands with the
-- roll). Reuses the premade MeteorSpawn circle and PurpleSpikeBurst from ReplicatedStorage.VFX:
-- the circle snaps open, pulses its waves and closes again in about 0.6 s; Rare and better add
-- the spike burst and take the tier's color, and Huge / Titanic finds open a wider circle.
-- Common, Uncommon and Rare (Normal size) get the light seal instead: one reused spike burst at
-- the chest (no circle, lifetimes clipped) and a name pop over the head in the tier's colour,
-- all gone within 0.9 s. Epic and rarer, Huge and Titanic keep the full seal above.
-- Visual only, never delays scans or rewards. Hunt batches are skipped (SealBurst plays those).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SizeConfig = require(ReplicatedStorage.Shared.SizeConfig)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local RollReel = require(script.Parent.Parent.UI.RollReel)
local PedestalAuras = require(script.Parent.PedestalAuras)
local RelicAura = require(script.Parent.RelicAura)

local ScanSeal = {}

local CIRCLE_NAME = "MeteorSpawn"
local BURST_NAME = "PurpleSpikeBurst"
-- Hunt seals own the screen while their folder exists.
local HUNT_FOLDER = "SealBurstPremade"

local OPEN_SECONDS = 0.14
local CLOSE_START, CLOSE_END = 0.42, 0.62
local EMIT_AT = 0.1
local BURST_AT = 0.16
-- Long enough for the emitted waves / spikes (about 1 s lifetimes) to finish.
local CLEANUP_AT = 1.5
local SPIN = 2.2
local MIN_GAP = 0.7
local GROUND_OFFSET = 0.2
local CHEST_LIFT = 1.2
-- Epic and better: the tier's relic aura flares around the player for a moment.
local FLARE_SECONDS = { Epic = 1.2, Legendary = 1.6, Mythic = 2, Celestial = 2.2, Cosmic = 2.4 }
local BODY_HEIGHT = 5

local RARE = RarityConfig.IndexById.Rare
local EPIC = RarityConfig.IndexById.Epic
local LEGENDARY = RarityConfig.IndexById.Legendary
local PURPLE = Color3.fromRGB(150, 80, 255)

-- Circle scale (MeteorSpawn is ~20 studs authored) and wave emit factor by tier index.
local CIRCLE_SCALE = { 0.26, 0.3, 0.36, 0.42, 0.5, 0.56, 0.6, 0.65 }
local SIZE_BOOST = { Huge = 1.25, Titanic = 1.5 }
local CIRCLE_EMIT = { Smoke = 4, Wave0 = 3, Wave1 = 3, Wave2 = 2, Wave3 = 2 }
local BURST_EMIT = { Main = 10, Flare = 8, Spikes = 14 }

local lastPlayed = -math.huge

-- Light seal (Common..Rare): one burst kept parked and re-emitted, plus a name pop.
local LIGHT_EMIT = { Main = 5, Flare = 4, Spikes = 7 }
local LIGHT_LIFETIME = 0.55 -- particle lifetimes are clipped to this so nothing outlives the pop
local POP_SECONDS = 0.85
local lightBurst: Instance? = nil
local lightPop: BillboardGui? = nil
local popToken = 0

local function vfx(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("VFX")
	return folder and folder:FindFirstChild(name)
end

local function tierOf(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
end

local function tierColor(index: number): Color3
	local tier = RarityConfig.Tiers[index]
	return if tier then Color3.fromHex(tier.Color) else PURPLE
end

local function feet(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	params.IgnoreWater = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local y = if hit then hit.Position.Y else root.Position.Y - 3
	return Vector3.new(root.Position.X, y + GROUND_OFFSET, root.Position.Z)
end

local function arm(root: Instance, tint: Color3?)
	for _, item in { root, table.unpack(root:GetDescendants()) } do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.CastShadow = false
		elseif tint and (item:IsA("ParticleEmitter") or item:IsA("Beam")) then
			item.Color = ColorSequence.new(tint)
		elseif tint and item:IsA("PointLight") then
			item.Color = tint
		end
	end
end

local function emit(root: Instance, counts: { [string]: number }, factor: number)
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item:Emit(math.max(1, math.round((counts[item.Name] or 3) * factor)))
		end
	end
end

-- The reused burst: cloned once, scripts stripped, lifetimes clipped, parked out of sight.
local function getLightBurst(): Instance?
	if lightBurst and lightBurst.Parent then
		return lightBurst
	end
	local source = vfx(BURST_NAME)
	if not source then
		return nil
	end
	local burst = source:Clone()
	arm(burst, nil)
	for _, item in burst:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
			local life = item.Lifetime
			item.Lifetime = NumberRange.new(math.min(life.Min, LIGHT_LIFETIME), math.min(life.Max, LIGHT_LIFETIME))
		elseif item:IsA("Beam") or item:IsA("PointLight") or item:IsA("Trail") then
			item.Enabled = false
		end
	end
	burst.Name = "ScanSealLight"
	burst.Parent = workspace
	lightBurst = burst
	return burst
end

local function getPop(): BillboardGui
	if lightPop then
		return lightPop
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ScanSealPop"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Parent = gui
	lightPop = gui
	return gui
end

local function popName(text: string, color: Color3)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	popToken += 1
	local token = popToken
	local gui = getPop()
	local label = gui:FindFirstChild("Name") :: TextLabel
	-- Made on this client only, so nobody else sees it; it lives on the head (a new head gets a new one).
	if gui.Parent ~= head then
		gui:Destroy()
		lightPop = nil
		gui = getPop()
		label = gui:FindFirstChild("Name") :: TextLabel
		gui.Parent = head
	end
	gui.Adornee = head
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = color:Lerp(Color3.new(0, 0, 0), 0.8)
	gui.Enabled = true
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if token ~= popToken then
			connection:Disconnect()
			return
		end
		if t >= POP_SECONDS then
			connection:Disconnect()
			gui.Enabled = false
			return
		end
		-- Punch in (0.12 s overshoot), hold, then rise and fade over the last 0.35 s.
		local scale = if t < 0.12 then 0.4 + (t / 0.12) * 0.75 elseif t < 0.22 then 1.15 - (t - 0.12) / 0.1 * 0.15 else 1
		local fade = math.clamp((t - (POP_SECONDS - 0.35)) / 0.35, 0, 1)
		label.Size = UDim2.fromScale(scale, scale)
		label.Position = UDim2.fromScale(0.5, 0.5 - fade * 0.6)
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
	end)
end

-- Common, Uncommon and Rare: one quick burst plus the name pop, under 1 s, nothing to wait for.
local function playLight(relicId: string, mutation: string?, tier: number, low: boolean)
	local relic = RelicConfig.ById[relicId]
	local color = tierColor(tier)
	local name = if relic then relic.Name else relicId
	if mutation then
		name = `{mutation} {name}`
	end
	popName(name, color)
	if low and tier < RARE then
		return
	end
	local at = feet()
	local burst = getLightBurst()
	if not at or not burst then
		return
	end
	local tint = PURPLE:Lerp(color, if tier >= RARE then 0.65 else 0.35)
	local cf = CFrame.new(at + Vector3.new(0, CHEST_LIFT, 0))
	if burst:IsA("Model") then
		burst:PivotTo(cf)
	elseif burst:IsA("BasePart") then
		burst.CFrame = cf
	end
	for _, item in burst:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item.Color = ColorSequence.new(tint)
		end
	end
	emit(burst, LIGHT_EMIT, (if tier >= RARE then 1 else 0.6) * (if low then 0.5 else 1))
	if tier >= RARE then
		Sounds.PlayReveal("Seal", nil, 1.1)
	end
end

local function setBeams(root: Instance, on: boolean)
	for _, item in root:GetDescendants() do
		if item:IsA("Beam") or item:IsA("PointLight") then
			item.Enabled = on
		end
	end
end

-- Plays the seal for one landed find. `sizeId` is "Huge" / "Titanic" or nil.
function ScanSeal.Play(relicId: string, sizeId: string?, mutation: string?)
	local tier = tierOf(relicId)
	local low = Settings.LowEffects()
	local now = os.clock()
	if now - lastPlayed < MIN_GAP or workspace:FindFirstChild(HUNT_FOLDER) then
		return
	end
	if tier < EPIC and sizeId == nil then
		lastPlayed = now
		playLight(relicId, mutation, tier, low)
		return
	end
	local circleSrc = vfx(CIRCLE_NAME)
	local at = feet()
	if not circleSrc or not circleSrc:IsA("Model") or not at then
		return
	end
	lastPlayed = now

	local folder = Instance.new("Folder")
	folder.Name = "ScanSeal"
	folder.Parent = workspace
	local tint = if tier >= RARE then PURPLE:Lerp(tierColor(tier), 0.65) else PURPLE
	local scale = (CIRCLE_SCALE[tier] or CIRCLE_SCALE[#CIRCLE_SCALE]) * (SIZE_BOOST[sizeId or ""] or 1)
	local emitFactor = (if tier >= EPIC then 1.6 elseif tier >= RARE then 1.2 else 0.8) * (if low then 0.5 else 1)

	local circle = circleSrc:Clone() :: Model
	arm(circle, tint)
	circle:ScaleTo(0.05)
	circle:PivotTo(CFrame.new(at))
	circle.Parent = folder
	setBeams(circle, true)

	local burstSrc = if tier >= RARE then vfx(BURST_NAME) else nil
	if burstSrc then
		task.delay(BURST_AT, function()
			if not folder.Parent then
				return
			end
			local burst = burstSrc:Clone()
			arm(burst, tint)
			local cf = CFrame.new(at + Vector3.new(0, CHEST_LIFT, 0))
			if burst:IsA("Model") then
				burst:PivotTo(cf)
			elseif burst:IsA("BasePart") then
				burst.CFrame = cf
			end
			burst.Parent = folder
			emit(burst, BURST_EMIT, emitFactor)
		end)
	end
	if tier >= RARE then
		Sounds.PlayReveal("Seal", nil, if tier >= LEGENDARY then 0.85 else 1.1)
	end
	local tierId = RarityConfig.Tiers[tier] and RarityConfig.Tiers[tier].Id
	local flare = tierId and FLARE_SECONDS[tierId]
	local auraName = tierId and PedestalAuras.ByTier[tierId]
	local auraTemplate = auraName and RelicAura.template(auraName)
	if flare and auraTemplate then
		-- The pack's auras were authored around a 5-stud body, so this anchor matches them 1:1.
		local anchor = Instance.new("Part")
		anchor.Name = "ScanSealFlare"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(2, BODY_HEIGHT, 1)
		anchor.CFrame = CFrame.new(at + Vector3.new(0, BODY_HEIGHT / 2 - GROUND_OFFSET, 0))
		anchor.Parent = workspace
		local handle = RelicAura.attach(anchor, auraTemplate, { Low = low })
		task.delay(flare, function()
			handle:Destroy()
			anchor:Destroy()
		end)
	end

	local start = os.clock()
	local emitted = false
	local current = 0.05
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= CLEANUP_AT or not circle.Parent then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		local u: number
		if t < OPEN_SECONDS then
			local k = t / OPEN_SECONDS
			u = 1 - (1 - k) * (1 - k)
		elseif t < CLOSE_START then
			u = 1
		else
			local k = math.min((t - CLOSE_START) / (CLOSE_END - CLOSE_START), 1)
			u = 1 - k * k
			if k >= 1 then
				setBeams(circle, false)
			end
		end
		local want = math.max(0.03, scale * u)
		if math.abs(want - current) > 1e-3 then
			current = want
			circle:ScaleTo(want)
		end
		circle:PivotTo(CFrame.new(at) * CFrame.Angles(0, t * SPIN, 0))
		if not emitted and t >= EMIT_AT then
			emitted = true
			emit(circle, CIRCLE_EMIT, emitFactor)
		end
	end)
end

function ScanSeal.Start()
	RollReel.OnResults(function(results: { any }, hunt: boolean)
		if hunt then
			return
		end
		local bestId: string? = nil
		local bestRank, bestSize, bestMutation = -1, nil, nil
		for _, result in results do
			if type(result) == "table" and type(result.Id) == "string" then
				if result.Source == "Capture" then
					return
				end
				local sizeId = SizeConfig.normalize(result.Size)
				local sized = if sizeId == "Titanic" then 2 elseif sizeId == "Huge" then 1 else 0
				local rank = tierOf(result.Id) * 3 + sized
				if rank > bestRank then
					bestRank, bestId = rank, result.Id
					bestSize = if sized > 0 then sizeId else nil
					bestMutation = if type(result.Mutation) == "string" then result.Mutation else nil
				end
			end
		end
		if bestId then
			ScanSeal.Play(bestId, bestSize, bestMutation)
		end
	end)
end

return ScanSeal
