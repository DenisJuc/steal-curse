-- Ancient Ruins (GDD 4.1): a stepped central altar with a glowing rune, broken temple walls,
-- standing and fallen columns, rubble and spirit braziers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildUtil = require(script.Parent.Parent.BuildUtil)

local TOP = 0.4
local STONE = Color3.fromRGB(150, 138, 116)
local DARK_STONE = Color3.fromRGB(118, 108, 92)
local RUNE = Color3.fromRGB(120, 230, 255)
local FIRE = Color3.fromRGB(120, 200, 255)

local function rotated(at, blocker, y: number): CFrame
	return at(blocker.X, y, blocker.Z) * CFrame.Angles(0, math.rad(blocker.Rot), 0)
end

local function altar(model: Model, at, blocker)
	local step = blocker.H / 3
	for index = 0, 2 do
		local scale = 1 - index * 0.28
		BuildUtil.part(model, {
			Name = "AltarStep",
			Size = Vector3.new(blocker.W * scale, step, blocker.D * scale),
			CFrame = rotated(at, blocker, TOP + step * (index + 0.5)),
			Material = Enum.Material.Sandstone,
			Color = STONE:Lerp(DARK_STONE, index / 2),
		})
	end
	local rune = BuildUtil.decor(BuildUtil.cylinder(model, rotated(at, blocker, TOP + blocker.H + 0.05), 0.1, blocker.W * 0.36, {
		Name = "AltarRune",
		Material = Enum.Material.Neon,
		Color = RUNE,
		Transparency = 0.3,
	}))
	BuildUtil.light(rune, RUNE, 22, 1.4)
	BuildUtil.sparkles(rune, RUNE, 6)
end

local function wall(model: Model, at, blocker)
	-- Two segments of different heights read as a broken temple wall.
	local long = blocker.W >= blocker.D
	local length = if long then blocker.W else blocker.D
	for _, piece in { { -0.25, 1 }, { 0.25, 0.65 } } do
		local height = blocker.H * piece[2]
		local offset = piece[1] * length
		BuildUtil.part(model, {
			Name = "TempleWall",
			Size = if long
				then Vector3.new(length / 2, height, blocker.D)
				else Vector3.new(blocker.W, height, length / 2),
			CFrame = rotated(at, blocker, TOP + height / 2)
				* (if long then CFrame.new(offset, 0, 0) else CFrame.new(0, 0, offset)),
			Material = Enum.Material.Sandstone,
			Color = STONE,
		})
	end
end

local function column(model: Model, at, blocker)
	BuildUtil.part(model, {
		Name = "ColumnBase",
		Size = Vector3.new(blocker.W + 1.2, 1, blocker.D + 1.2),
		CFrame = rotated(at, blocker, TOP + 0.5),
		Material = Enum.Material.Sandstone,
		Color = DARK_STONE,
	})
	BuildUtil.cylinder(model, rotated(at, blocker, TOP + 1 + (blocker.H - 2) / 2), blocker.H - 2, blocker.W, {
		Name = "Column",
		Material = Enum.Material.Sandstone,
		Color = STONE,
	})
	BuildUtil.part(model, {
		Name = "ColumnCapital",
		Size = Vector3.new(blocker.W + 1.2, 1, blocker.D + 1.2),
		CFrame = rotated(at, blocker, TOP + blocker.H - 0.5),
		Material = Enum.Material.Sandstone,
		Color = DARK_STONE,
	})
end

local function fallen(model: Model, at, blocker)
	local part = BuildUtil.part(model, {
		Name = "FallenColumn",
		CFrame = rotated(at, blocker, TOP + blocker.D / 2),
		Material = Enum.Material.Sandstone,
		Color = STONE,
	})
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(blocker.W, blocker.D, blocker.D)
end

local STRUCTURES = { Altar = altar, Wall = wall, Column = column, Fallen = fallen }

local function structure(model: Model, at, blocker)
	STRUCTURES[blocker.Kind](model, at, blocker)
end

local function dress(model: Model, at, rng: Random, free)
	-- A paved processional way from the gate to the altar.
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "Processional",
		Size = Vector3.new(10, 0.1, 74),
		CFrame = at(0, TOP + 0.05, -48),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(128, 118, 100),
	}))

	for _, spot in { { -12, -30 }, { 12, -30 }, { -16, 22 }, { 16, 22 } } do
		local x, z = spot[1], spot[2]
		BuildUtil.part(model, {
			Name = "Brazier",
			Size = Vector3.new(2.4, 4, 2.4),
			CFrame = at(x, TOP + 2, z),
			Material = Enum.Material.Sandstone,
			Color = DARK_STONE,
		})
		local flame = BuildUtil.decor(BuildUtil.part(model, {
			Name = "SpiritFlame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 1.8),
			CFrame = at(x, TOP + 4.8, z),
			Material = Enum.Material.Neon,
			Color = FIRE,
			Transparency = 0.15,
		}))
		BuildUtil.light(flame, FIRE, 16, 1.2)
	end

	local half = Config.World.DistrictSize / 2 - 7
	local placed, attempts = 0, 0
	while placed < 24 and attempts < 800 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 5) then
			continue
		end
		placed += 1
		local size = rng:NextNumber(1.6, 4.2)
		BuildUtil.part(model, {
			Name = "Rubble",
			Size = Vector3.new(size * 1.3, size * 0.7, size),
			CFrame = at(x, TOP + size * 0.3, z)
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
			Material = Enum.Material.Sandstone,
			Color = STONE:Lerp(DARK_STONE, rng:NextNumber()),
		})
	end

	placed, attempts = 0, 0
	while placed < 12 and attempts < 400 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 3) then
			continue
		end
		placed += 1
		local size = rng:NextNumber(4, 9)
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Moss",
			Size = Vector3.new(size, 0.12, size * rng:NextNumber(0.6, 1)),
			CFrame = at(x, TOP + 0.06, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(70, 92, 60),
		}))
	end
end

return {
	FloorMaterial = Enum.Material.Sandstone,
	FloorColor = Color3.fromRGB(112, 102, 84),
	GateStone = Color3.fromRGB(140, 128, 106),
	GateLamp = FIRE,
	NameColor = Color3.fromRGB(200, 245, 255),
	Structure = structure,
	Dress = dress,
}
