-- Slice 1 greybox hunting ground: trees, rocks and ruined walls that break line of sight,
-- plus the SignalSpawn points personal signals can appear at. Local -Z faces the hub.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildUtil = require(script.Parent.BuildUtil)

local HuntAreaBuilder = {}

export type HuntArea = {
	Model: Model,
	SpawnPoints: { Vector3 },
	Entrance: CFrame,
}

local FLOOR_TOP = 0.4

-- {x, z} offsets for signal spawn points, spread behind obstacles.
local SPAWN_OFFSETS = {
	{ -60, -50 },
	{ -20, -62 },
	{ 35, -55 },
	{ 65, -30 },
	{ -68, -10 },
	{ -35, -20 },
	{ 10, -25 },
	{ 45, 0 },
	{ -55, 30 },
	{ -15, 15 },
	{ 25, 35 },
	{ 65, 45 },
	{ -40, 65 },
	{ 5, 68 },
	{ 50, 70 },
}

-- {x, z, length, height, rotationDegrees}
local RUINED_WALLS = {
	{ -30, -40, 18, 7, 10 },
	{ 28, -35, 16, 9, -20 },
	{ -50, 10, 20, 6, 75 },
	{ 30, 15, 14, 8, 40 },
	{ -5, 45, 22, 7, -5 },
	{ 58, 20, 12, 10, 90 },
}

local function farFromAll(x: number, z: number, points: { { number } }, minDistance: number): boolean
	for _, point in points do
		local dx, dz = x - point[1], z - point[2]
		if dx * dx + dz * dz < minDistance * minDistance then
			return false
		end
	end
	return true
end

local function buildTrees(model: Model, at: (number, number, number) -> CFrame)
	local half = Config.HuntArea.Size / 2 - 7
	local rng = Random.new(Config.HuntArea.Seed)
	local placed = 0
	local attempts = 0
	while placed < Config.HuntArea.TreeCount and attempts < 2000 do
		attempts += 1
		local x = rng:NextNumber(-half, half)
		local z = rng:NextNumber(-half, half)
		local inEntrance = math.abs(x) < 8 and z < -half + 30
		if inEntrance or not farFromAll(x, z, SPAWN_OFFSETS, 9) or not farFromAll(x, z, RUINED_WALLS, 12) then
			continue
		end
		placed += 1
		local height = rng:NextNumber(14, 22)
		local diameter = rng:NextNumber(2, 3.5)
		BuildUtil.cylinder(model, at(x, FLOOR_TOP + height / 2, z), height, diameter, {
			Name = "Trunk",
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(58, 44, 40),
		})
		local canopySize = height * rng:NextNumber(0.55, 0.75)
		local tint = rng:NextNumber()
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(canopySize, canopySize, canopySize),
			CFrame = at(x, FLOOR_TOP + height, z),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(48, 58, 56):Lerp(Color3.fromRGB(70, 54, 86), tint),
		}))
	end

	for _ = 1, 12 do
		local x = rng:NextNumber(-half, half)
		local z = rng:NextNumber(-half, half)
		if not farFromAll(x, z, SPAWN_OFFSETS, 7) then
			continue
		end
		local size = rng:NextNumber(3, 7)
		BuildUtil.part(model, {
			Name = "Rock",
			Size = Vector3.new(size, size * 0.7, size * 1.2),
			CFrame = at(x, FLOOR_TOP + size * 0.25, z)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(84, 82, 92),
		})
	end
end

local function buildWalls(model: Model, at: (number, number, number) -> CFrame)
	for _, wall in RUINED_WALLS do
		local x, z, length, height, rotation = wall[1], wall[2], wall[3], wall[4], wall[5]
		BuildUtil.part(model, {
			Name = "RuinedWall",
			Size = Vector3.new(length, height, 2),
			CFrame = at(x, FLOOR_TOP + height / 2, z) * CFrame.Angles(0, math.rad(rotation), 0),
			Material = Enum.Material.Cobblestone,
			Color = Color3.fromRGB(96, 92, 100),
		})
	end
end

local function buildEntrance(model: Model, at: (number, number, number) -> CFrame): CFrame
	local z = -Config.HuntArea.Size / 2
	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "GatePillar",
			Size = Vector3.new(2.5, 16, 2.5),
			CFrame = at(side * 9, FLOOR_TOP + 8, z),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(70, 66, 80),
		})
		local lamp = BuildUtil.part(model, {
			Name = "GateLamp",
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = at(side * 9, FLOOR_TOP + 17, z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 160, 80),
		})
		BuildUtil.decor(lamp)
		BuildUtil.light(lamp, Color3.fromRGB(255, 160, 80), 14, 1.2)
	end
	local beam = BuildUtil.part(model, {
		Name = "GateBeam",
		Size = Vector3.new(22, 1.6, 2.6),
		CFrame = at(0, FLOOR_TOP + 15.6, z),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(50, 46, 60),
	})
	BuildUtil.billboard(beam, Config.HuntArea.Name, 22, 3, 4, Color3.fromRGB(200, 230, 255))
	return at(0, FLOOR_TOP + 3, z - 8)
end

function HuntAreaBuilder.Build(parent: Instance): HuntArea
	local settings = Config.HuntArea
	local angle = math.rad(settings.AngleDegrees)
	local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * settings.Radius
	local cframe = CFrame.lookAt(center, Vector3.zero)
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "HuntArea"

	BuildUtil.part(model, {
		Name = "Floor",
		Size = Vector3.new(settings.Size, 0.4, settings.Size),
		CFrame = at(0, FLOOR_TOP / 2, 0),
		Material = Enum.Material.LeafyGrass,
		Color = Color3.fromRGB(46, 56, 44),
	})
	buildWalls(model, at)
	buildTrees(model, at)
	local entrance = buildEntrance(model, at)

	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "SignalSpawns"
	spawnFolder.Parent = model
	local spawnPoints = {}
	for index, offset in SPAWN_OFFSETS do
		local marker = BuildUtil.decor(BuildUtil.part(spawnFolder, {
			Name = "SignalSpawn" .. index,
			Size = Vector3.new(1, 1, 1),
			CFrame = at(offset[1], FLOOR_TOP, offset[2]),
			Transparency = 1,
		}))
		marker:SetAttribute("Area", settings.Name)
		CollectionService:AddTag(marker, "SignalSpawn")
		spawnPoints[index] = marker.Position
	end

	model.Parent = parent
	return { Model = model, SpawnPoints = spawnPoints, Entrance = entrance }
end

return HuntAreaBuilder
