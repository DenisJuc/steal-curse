-- The short seal under the player on every landed scan (RollReel.OnResults, so it lands with the
-- roll). Reuses the premade MeteorSpawn circle and PurpleSpikeBurst from ReplicatedStorage.VFX:
-- the circle snaps open, pulses its waves and closes again in about 0.6 s; Rare and better add
-- the spike burst and take the tier's color, and Huge / Titanic finds open a wider circle.
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

local function setBeams(root: Instance, on: boolean)
	for _, item in root:GetDescendants() do
		if item:IsA("Beam") or item:IsA("PointLight") then
			item.Enabled = on
		end
	end
end

-- Plays the seal for one landed find. `sizeId` is "Huge" / "Titanic" or nil.
function ScanSeal.Play(relicId: string, sizeId: string?)
	local tier = tierOf(relicId)
	local low = Settings.LowEffects()
	if low and tier < RARE and sizeId == nil then
		return
	end
	local now = os.clock()
	if now - lastPlayed < MIN_GAP or workspace:FindFirstChild(HUNT_FOLDER) then
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
		Sounds.Play("Seal", nil, if tier >= LEGENDARY then 0.85 else 1.1)
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
		local bestRank, bestSize = -1, nil
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
				end
			end
		end
		if bestId then
			ScanSeal.Play(bestId, bestSize)
		end
	end)
end

return ScanSeal
