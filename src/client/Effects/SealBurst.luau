-- The seal moment right after a validated capture: a spirit jar (SealJar mesh) rises where the
-- signal was, the spirit (SignalCore) thrashes above it and is swallowed in a spiral, the jar
-- rattles, then slams shut in a flash, ground shockwave and burst. The caller starts the relic's
-- family animation (CaptureAnimation) at SealBurst.RevealAt, so the relic rises out of the jar
-- while it lingers and sinks away. The capture is already validated here, so the slam may scale
-- with the relic's tier (the bind before it never hints at rarity).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local ChainRig = require(script.Parent.ChainRig)
local HuntFX = require(script.Parent.HuntFX)
local HuntModels = require(script.Parent.HuntModels)
local Sounds = require(script.Parent.Parent.Sounds)

local SealBurst = {}

-- Timeline in seconds from the capture.
local APPEAR_END = 0.35
local SWALLOW_START, SWALLOW_END = 0.45, 1.05
local SLAM_AT = 1.4
SealBurst.SlamAt = SLAM_AT
SealBurst.RevealAt = SLAM_AT + 0.1
local SINK_START = 1.9
SealBurst.Seconds = 2.4

export type Options = {
	Low: boolean,
	-- Sound and camera shake: only for the local player's own captures.
	Personal: boolean,
}

local SPIRIT_COLOR = Color3.fromRGB(140, 220, 255)
local JAR_SIZE = 3
local SPIRIT_SIZE = 2.4

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function span(t: number, from: number, to: number): number
	return math.clamp((t - from) / (to - from), 0, 1)
end

-- Tier color, and strength 0 (lowest tier) .. 1 (highest).
local function tierLook(relicId: string): (Color3, number)
	local relic = RelicConfig.ById[relicId]
	local tier = relic and RarityConfig.Get(relic.Tier)
	if not relic or not tier then
		return SPIRIT_COLOR, 0
	end
	local index = RarityConfig.IndexById[relic.Tier]
	return Color3.fromHex(tier.Color), (index - 1) / math.max(1, #RarityConfig.Tiers - 1)
end

-- Ground height under the signal (characters ignored; hunt effects never block queries).
local function groundBelow(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	params.IgnoreWater = true
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -25, 0), params)
	return if hit then hit.Position.Y else position.Y - Config.Signals.HoverHeight
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

function SealBurst.Play(position: Vector3, relicId: string, options: Options)
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

		-- Jar: pops up spinning, glows as it fills, rattles, slams, lingers, then sinks away.
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

		-- Spirit: thrashes above the jar, then spirals down into its mouth, shrinking.
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

return SealBurst
