-- Set dressing for the wild, built from plain parts (no uploaded models): red spider lilies
-- along the stream and the paths (flowers of the dead), shimenawa ropes with paper talismans
-- around big trees, paper lanterns floating on the stream (the client drifts them, see
-- StreamLanterns), hanging red lanterns by the village houses, broken torii gates, and the rope
-- gates and glowing stones that mark where the Deep and the Heart of the wild begin.
-- WildBuilder passes a Context so nothing lands inside a prop, a landmark or a wall.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local BuildUtil = require(script.Parent.BuildUtil)

local WildDressing = {}

export type Context = {
	Folder: Instance,
	Rng: Random,
	GroundY: (x: number, z: number) -> number,
	-- True when a circle at (x, z) would overlap a prop, a landmark or a wall.
	Blocked: (x: number, z: number, radius: number) -> boolean,
	Claim: (x: number, z: number, radius: number) -> (),
	-- Tree models crows can land on (tagged "Perch", not yet in the workspace).
	Perches: { Model },
}

local LILY_PATCHES_BANK = 20
local LILY_PATCHES_PATH = 16
local LILY_STEM = Color3.fromRGB(40, 62, 36)
local LILY_HEAD = Color3.fromRGB(120, 8, 16)
local ROPE_COLOR = Color3.fromRGB(196, 170, 120)
local PAPER_COLOR = Color3.fromRGB(240, 236, 226)
-- Share of scattered dead trees that wear a rope (every ancient tree does).
local ROPE_CHANCE = 0.12
local STREAM_LANTERNS = 36
local LANTERN_GLOW = Color3.fromRGB(255, 176, 96)
local CHOCHIN_RED = Color3.fromRGB(190, 40, 28)
local TORII_COUNT = 7
local TORII_RED = Color3.fromRGB(140, 42, 32)
local TORII_CAP = Color3.fromRGB(28, 24, 24)
-- Trunk radius at scale 1 (MapPropConfig colliders / 2) and rope height share of the tree.
local TRUNKS = { DeadTree1 = { 1.2, 0.25 }, DeadTree2 = { 1.2, 0.3 }, AncientTree = { 4.6, 0.18 } }
-- Studs between the glowing stones that mark where the Deep and the Heart begin.
local BAND_STONE_SPACING = 36

local function decor(parent: Instance, props: { [string]: any }): BasePart
	return BuildUtil.decor(BuildUtil.part(parent, props))
end

local function folderOf(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function lilyPatch(context: Context, parent: Instance, x: number, z: number)
	local rng = context.Rng
	for _ = 1, rng:NextInteger(7, 11) do
		local px, pz = x + rng:NextNumber(-3.5, 3.5), z + rng:NextNumber(-3.5, 3.5)
		local height = rng:NextNumber(1, 1.7)
		local ground = context.GroundY(px, pz)
		local tilt = CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.15, 0.15))
		local base = CFrame.new(px, ground, pz) * tilt
		decor(parent, {
			Name = "LilyStem",
			Size = Vector3.new(0.12, height, 0.12),
			CFrame = base * CFrame.new(0, height / 2, 0),
			Color = LILY_STEM,
		})
		decor(parent, {
			Name = "LilyHead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(0.5, 0.75),
			CFrame = base * CFrame.new(0, height, 0),
			Material = Enum.Material.Neon,
			Color = LILY_HEAD,
		})
	end
end

local function buildLilies(context: Context)
	local folder = folderOf(context.Folder, "SpiderLilies")
	local rng = context.Rng
	local world = Config.World
	local placed, attempts = 0, 0
	while placed < LILY_PATCHES_BANK and attempts < 400 do
		attempts += 1
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local r = world.StreamRadius + side * (world.StreamWidth / 2 + rng:NextNumber(5, 10))
		local x, z = WorldLayout.polar(rng:NextNumber(0, 360), r)
		if not context.Blocked(x, z, 4) and WildLayout.pathDistance(Config.Areas, x, z) > 12 then
			lilyPatch(context, folder, x, z)
			placed += 1
		end
	end
	placed, attempts = 0, 0
	while placed < LILY_PATCHES_PATH and attempts < 400 do
		attempts += 1
		local area = Config.Areas[rng:NextInteger(1, #Config.Areas)]
		local along = rng:NextNumber(world.WildInner + 20, world.WildOuter - 20)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local ux, uz = WorldLayout.polar(area.AngleDegrees, 1)
		local offset = WildLayout.PathHalfWidth + rng:NextNumber(1.5, 5)
		local x, z = ux * along - uz * offset * side, uz * along + ux * offset * side
		if not context.Blocked(x, z, 4) and not WorldLayout.inStream(world, x, z, 6) then
			lilyPatch(context, folder, x, z)
			placed += 1
		end
	end
end

-- A straw rope around the trunk with four zigzag paper streamers hanging from it.
local function shimenawa(parent: Instance, center: Vector3, radius: number, thickness: number)
	local segments = 14
	local length = 2 * math.pi * radius / segments + thickness * 0.6
	for index = 0, segments - 1 do
		local angle = index / segments * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		decor(parent, {
			Name = "Rope",
			Size = Vector3.new(thickness, thickness, length),
			CFrame = CFrame.lookAt(at, at + tangent),
			Material = Enum.Material.Fabric,
			Color = ROPE_COLOR,
		})
	end
	for index = 0, 3 do
		local angle = (index + 0.5) / 4 * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = center + out * (radius + thickness * 0.6)
		local facing = CFrame.lookAt(at, at + out)
		for step = 0, 1 do
			decor(parent, {
				Name = "Shide",
				Size = Vector3.new(0.7, 0.8, 0.05),
				CFrame = facing * CFrame.new(if step == 0 then 0.15 else -0.15, -0.6 - step * 0.75, 0),
				Color = PAPER_COLOR,
			})
		end
	end
end

local function buildRopes(context: Context)
	local folder = folderOf(context.Folder, "Shimenawa")
	for _, model in context.Perches do
		local prop = model:GetAttribute("Prop")
		local trunk = TRUNKS[prop :: string]
		if not trunk or (prop ~= "AncientTree" and context.Rng:NextNumber() > ROPE_CHANCE) then
			continue
		end
		local scale = model:GetAttribute("Scale")
		local s = if type(scale) == "number" then scale else 1
		local _, size = model:GetBoundingBox()
		local pivot = model:GetPivot().Position
		local ground = pivot.Y
		local center = Vector3.new(pivot.X, ground + size.Y * trunk[2], pivot.Z)
		local thick = if prop == "AncientTree" then 0.9 else 0.45
		shimenawa(folder, center, trunk[1] * s + thick * 0.4, thick)
	end
end

local function buildStreamLanterns(context: Context)
	local folder = folderOf(context.Folder, "StreamLanterns")
	local rng = context.Rng
	local world = Config.World
	for index = 1, STREAM_LANTERNS do
		local angle = (index - 1) / STREAM_LANTERNS * 360 + rng:NextNumber(-3, 3)
		local offset = rng:NextNumber(-world.StreamWidth / 2 + 2, world.StreamWidth / 2 - 2)
		local model = Instance.new("Model")
		model.Name = "StreamLantern"
		model:SetAttribute("Angle", angle)
		model:SetAttribute("Offset", offset)
		model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
		local x, z = WorldLayout.polar(angle, world.StreamRadius + offset)
		local base = CFrame.new(x, -0.85, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local raft = decor(model, {
			Name = "Raft",
			Size = Vector3.new(1.4, 0.2, 1.4),
			CFrame = base,
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(70, 48, 32),
		})
		local paper = decor(model, {
			Name = "Paper",
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = base * CFrame.new(0, 0.55, 0),
			Material = Enum.Material.Neon,
			Color = LANTERN_GLOW,
		})
		local light = BuildUtil.light(paper, LANTERN_GLOW, 10, 0.9)
		CollectionService:AddTag(light, "MapLight")
		model.PrimaryPart = raft
		model.Parent = folder
		CollectionService:AddTag(model, "StreamLantern")
	end
end

-- A red paper lantern on a post beside each village house (some have gone dark and fallen).
local function buildVillageLanterns(context: Context)
	local folder = folderOf(context.Folder, "VillageLanterns")
	local rng = context.Rng
	for _, structure in WildLayout.Structures do
		if structure.Prop ~= "RuinedHouse" and structure.Prop ~= "RuinedHut" and structure.Prop ~= "BellTower" then
			continue
		end
		local x, z = WildLayout.position(structure)
		local r = math.sqrt(x * x + z * z)
		local hub = Vector3.new(-x / r, 0, -z / r)
		local side = Vector3.new(-hub.Z, 0, hub.X) * (if rng:NextNumber() < 0.5 then -1 else 1)
		local size = MapPropConfig.Props[structure.Prop].Size
		local spot = Vector3.new(x, 0, z) + hub * (size[3] / 2 + 2.5) + side * (size[1] / 2 - 1)
		if context.Blocked(spot.X, spot.Z, 0.8) then
			continue
		end
		local ground = context.GroundY(spot.X, spot.Z)
		local lit = rng:NextNumber() < 0.75
		if lit then
			local post = CFrame.new(spot.X, ground, spot.Z) * CFrame.lookAt(Vector3.zero, side)
			decor(folder, {
				Name = "LanternPost",
				Size = Vector3.new(0.4, 7, 0.4),
				CFrame = post * CFrame.new(0, 3.5, 0),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(52, 38, 30),
			})
			decor(folder, {
				Name = "LanternArm",
				Size = Vector3.new(0.3, 0.3, 2),
				CFrame = post * CFrame.new(0, 6.8, -0.9),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(52, 38, 30),
			})
			local lantern = decor(folder, {
				Name = "Chochin",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = post * CFrame.new(0, 5.9, -1.7),
				Material = Enum.Material.Neon,
				Color = CHOCHIN_RED,
			})
			local light = BuildUtil.light(lantern, Color3.fromRGB(255, 90, 60), 14, 0.9)
			CollectionService:AddTag(light, "MapLight")
		else
			decor(folder, {
				Name = "FallenChochin",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.3, 1.3, 1.3),
				CFrame = CFrame.new(spot.X, ground + 0.5, spot.Z),
				Color = Color3.fromRGB(90, 30, 24),
			})
		end
	end
end

local function cylinder(parent: Instance, from: Vector3, to: Vector3, diameter: number, color: Color3)
	local length = (to - from).Magnitude
	-- Cylinders lie along X: aim X along the segment.
	local frame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	BuildUtil.part(parent, {
		Name = "ToriiPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = frame,
		Material = Enum.Material.Wood,
		Color = color,
	})
end

-- One standing pillar, one snapped stump, the top beams fallen across the ground.
local function brokenTorii(parent: Instance, base: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "BrokenTorii"
	local function at(x: number, y: number, z: number): Vector3
		return (base * CFrame.new(x, y, z)).Position
	end
	local lean = rng:NextNumber(-0.6, 0.6)
	cylinder(model, at(-5, 0, 0), at(-5 + lean, 12, 0), 1.3, TORII_RED)
	local stump = rng:NextNumber(3, 6)
	cylinder(model, at(5, 0, 0), at(5, stump, 0), 1.3, TORII_RED)
	cylinder(model, at(6.5, 0.6, 1.5), at(7.5, 0.6, 1.5 + 12 - stump), 1.2, TORII_RED)
	local top = at(-5 + lean, 12.4, 0)
	local foot = at(7, 0.5, -2.5)
	local kasagi = CFrame.lookAt((top + foot) / 2, foot)
	local length = (foot - top).Magnitude + 3
	BuildUtil.part(model, {
		Name = "Kasagi",
		Size = Vector3.new(1.2, 1, length),
		CFrame = kasagi,
		Material = Enum.Material.Wood,
		Color = TORII_RED,
	})
	BuildUtil.part(model, {
		Name = "KasagiCap",
		Size = Vector3.new(1.4, 0.5, length + 0.6),
		CFrame = kasagi * CFrame.new(0, 0.7, 0),
		Material = Enum.Material.Wood,
		Color = TORII_CAP,
	})
	BuildUtil.part(model, {
		Name = "Nuki",
		Size = Vector3.new(10, 0.7, 0.8),
		CFrame = base * CFrame.new(rng:NextNumber(-1, 1), 0.35, 3.5) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0),
		Material = Enum.Material.Wood,
		Color = TORII_RED,
	})
	model.Parent = parent
	CollectionService:AddTag(model, "Landmark")
end

local function buildTorii(context: Context)
	local folder = folderOf(context.Folder, "BrokenTorii")
	local rng = context.Rng
	local world = Config.World
	local placed, attempts = 0, 0
	while placed < TORII_COUNT and attempts < 300 do
		attempts += 1
		local x, z = WorldLayout.polar(rng:NextNumber(0, 360), rng:NextNumber(world.WildInner + 40, world.WildOuter - 20))
		if
			context.Blocked(x, z, 10)
			or WorldLayout.inStream(world, x, z, 12)
			or WildLayout.pathDistance(Config.Areas, x, z) < WildLayout.PathHalfWidth + 12
		then
			continue
		end
		local base = CFrame.new(x, context.GroundY(x, z), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		brokenTorii(folder, base, rng)
		context.Claim(x, z, 9)
		placed += 1
	end
end

local function bandColor(band: string): Color3
	local color = Config.HuntStreak.Bands[band].Color
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- A rope gate across a path where a deeper band starts: two stone posts with glowing caps, a
-- straw rope with paper streamers and a sign naming the band on each side.
local function bandGate(parent: Instance, context: Context, angle: number, radius: number, inner: string, outer: string)
	local ux, uz = WorldLayout.polar(angle, 1)
	local center = Vector3.new(ux * radius, 0, uz * radius)
	local across = Vector3.new(-uz, 0, ux)
	local half = WildLayout.PathHalfWidth + 1.5
	local ground = math.max(context.GroundY(center.X, center.Z), context.GroundY(center.X + across.X * half, center.Z + across.Z * half))
	local gate = CFrame.lookAt(Vector3.new(center.X, ground, center.Z), Vector3.new(center.X + ux, ground, center.Z + uz))
	local color = bandColor(outer)
	local model = Instance.new("Model")
	model.Name = `BandGate_{outer}`
	for _, side in { -1, 1 } do
		local post = gate * CFrame.new(side * half, 0, 0)
		BuildUtil.part(model, {
			Name = "GatePost",
			Size = Vector3.new(1.4, 10, 1.4),
			CFrame = post * CFrame.new(0, 4, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(70, 68, 76),
		})
		local cap = decor(model, {
			Name = "GateCap",
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = post * CFrame.new(0, 9.6, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Material = Enum.Material.Neon,
			Color = color,
		})
		CollectionService:AddTag(BuildUtil.light(cap, color, 16, 1.2), "MapLight")
	end
	decor(model, {
		Name = "GateRope",
		Size = Vector3.new(half * 2, 0.7, 0.7),
		CFrame = gate * CFrame.new(0, 8.6, 0),
		Material = Enum.Material.Fabric,
		Color = ROPE_COLOR,
	})
	for step = -2, 2 do
		decor(model, {
			Name = "Shide",
			Size = Vector3.new(0.7, 1.4, 0.05),
			CFrame = gate * CFrame.new(step * half * 0.4, 7.6, 0),
			Color = PAPER_COLOR,
		})
	end
	local sign = decor(model, {
		Name = "GateSign",
		Size = Vector3.new(9, 1.6, 0.3),
		CFrame = gate * CFrame.new(0, 10.4, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(40, 32, 30),
	})
	-- The back face looks toward the hub: each side names the band you are walking into.
	BuildUtil.surfaceText(sign, Enum.NormalId.Back, string.upper(Config.HuntStreak.Bands[outer].Name), color)
	BuildUtil.surfaceText(sign, Enum.NormalId.Front, string.upper(Config.HuntStreak.Bands[inner].Name), bandColor(inner))
	model.Parent = parent
	CollectionService:AddTag(model, "Landmark")
	context.Claim(center.X, center.Z, half + 2)
end

-- Where the Deep and the Heart begin: a rope gate on every path and a ring of small glowing
-- stones between the paths, so the band lines read anywhere in the wild.
local function buildBandMarkers(context: Context)
	local folder = folderOf(context.Folder, "BandMarkers")
	local bands = Config.HuntStreak
	local lines = { { Radius = bands.EdgeUntil, Inner = "Edge", Outer = "Deep" }, { Radius = bands.DeepUntil, Inner = "Deep", Outer = "Heart" } }
	for _, line in lines do
		for _, area in Config.Areas do
			bandGate(folder, context, area.AngleDegrees, line.Radius, line.Inner, line.Outer)
		end
		local color = bandColor(line.Outer)
		local count = math.floor(2 * math.pi * line.Radius / BAND_STONE_SPACING)
		for index = 0, count - 1 do
			local x, z = WorldLayout.polar(index / count * 360, line.Radius)
			if context.Blocked(x, z, 2) or WildLayout.pathDistance(Config.Areas, x, z) < WildLayout.PathHalfWidth + 4 then
				continue
			end
			local tilt = CFrame.Angles(context.Rng:NextNumber(-0.2, 0.2), context.Rng:NextNumber(0, math.pi * 2), context.Rng:NextNumber(-0.2, 0.2))
			decor(folder, {
				Name = "BandShard",
				Size = Vector3.new(0.8, 2.4, 0.8),
				CFrame = CFrame.new(x, context.GroundY(x, z) + 0.9, z) * tilt,
				Material = Enum.Material.Neon,
				Color = color,
				Transparency = 0.15,
			})
		end
	end
end

function WildDressing.build(context: Context)
	buildBandMarkers(context)
	buildTorii(context)
	buildLilies(context)
	buildRopes(context)
	buildStreamLanterns(context)
	buildVillageLanterns(context)
end

return WildDressing
