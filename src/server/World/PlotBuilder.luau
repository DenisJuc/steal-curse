-- Builds one shrine plot: floor, walls, entrance gate with owner sign, Spirit Resonator,
-- starting pedestals and the Showcase podium. Plot local -Z faces the hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildUtil = require(script.Parent.BuildUtil)

local PlotBuilder = {}

local STONE = Color3.fromRGB(72, 68, 84)
local WOOD = Color3.fromRGB(96, 70, 56)
local GATE_RED = Color3.fromRGB(150, 36, 42)
local MARBLE = Color3.fromRGB(205, 200, 215)
local SPIRIT = Color3.fromRGB(170, 110, 255)

local FLOOR_TOP = 1.2

local function buildPedestal(parent: Instance, at: (number, number, number) -> CFrame, slot: number)
	local offset = Config.Plots.PedestalOffsets[slot]
	local x, z = offset[1], offset[2]
	local model = Instance.new("Model")
	model.Name = "Pedestal" .. slot
	model:SetAttribute("Slot", slot)

	BuildUtil.cylinder(model, at(x, FLOOR_TOP + 1.5, z), 3, 6, {
		Name = "Base",
		Material = Enum.Material.Marble,
		Color = MARBLE,
	})
	BuildUtil.cylinder(model, at(x, FLOOR_TOP + 3.2, z), 0.4, 7, {
		Name = "Top",
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + 3.45, z), 0.1, 6.4, {
		Name = "Glow",
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.45,
	}))
	model.Parent = parent
end

local function buildResonator(parent: Instance, at: (number, number, number) -> CFrame)
	local offset = Config.Plots.ResonatorOffset
	local x, z = offset[1], offset[2]
	local model = Instance.new("Model")
	model.Name = "SpiritResonator"

	BuildUtil.part(model, {
		Name = "Base",
		Size = Vector3.new(8, 2, 8),
		CFrame = at(x, FLOOR_TOP + 1, z),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	BuildUtil.cylinder(model, at(x, FLOOR_TOP + 6, z), 8, 3, {
		Name = "Column",
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(40, 36, 52),
	})
	local core = BuildUtil.part(model, {
		Name = "ResonatorCore",
		Size = Vector3.new(2.6, 4, 2.6),
		CFrame = at(x, FLOOR_TOP + 12, z) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = SPIRIT,
	})
	BuildUtil.decor(core)
	BuildUtil.light(core, SPIRIT, 18, 2)
	BuildUtil.sparkles(core, SPIRIT, 6)
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + 12, z) * CFrame.Angles(math.rad(20), 0, 0), 0.3, 7, {
		Name = "Ring",
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.35,
	}))
	model.Parent = parent
end

local function buildShowcasePodium(parent: Instance, at: (number, number, number) -> CFrame)
	local offset = Config.Plots.ShowcaseOffset
	local x, z = offset[1], offset[2]
	local model = Instance.new("Model")
	model.Name = "ShowcasePodium"

	local dais = BuildUtil.cylinder(model, at(x, FLOOR_TOP + 0.6, z), 1.2, 16, {
		Name = "Dais",
		Material = Enum.Material.Marble,
		Color = MARBLE,
	})
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + 1.25, z), 0.1, 16.4, {
		Name = "Edge",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 190, 90),
		Transparency = 0.5,
	}))
	BuildUtil.billboard(dais, "Showcase", 8, 1.6, 3, Color3.fromRGB(255, 210, 140))
	model.Parent = parent
end

local function buildGate(parent: Instance, at: (number, number, number) -> CFrame)
	local half = Config.Plots.Size / 2
	local z = -half + 0.7
	local model = Instance.new("Model")
	model.Name = "Gate"

	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "Pillar",
			Size = Vector3.new(1.8, 14, 1.8),
			CFrame = at(side * 8, FLOOR_TOP + 7, z),
			Material = Enum.Material.Wood,
			Color = GATE_RED,
		})
	end
	BuildUtil.part(model, {
		Name = "TopBeam",
		Size = Vector3.new(22, 1.6, 2.4),
		CFrame = at(0, FLOOR_TOP + 14.2, z),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(40, 30, 32),
	})
	BuildUtil.part(model, {
		Name = "LowerBeam",
		Size = Vector3.new(18, 1, 1.6),
		CFrame = at(0, FLOOR_TOP + 11.2, z),
		Material = Enum.Material.Wood,
		Color = GATE_RED,
	})
	local sign = BuildUtil.part(model, {
		Name = "OwnerSign",
		Size = Vector3.new(12, 1.8, 0.4),
		CFrame = at(0, FLOOR_TOP + 12.7, z - 1),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(30, 24, 26),
	})
	BuildUtil.surfaceText(sign, Enum.NormalId.Front, "Unclaimed Shrine", Color3.fromRGB(255, 220, 170))
	model.Parent = parent
end

local function buildWalls(parent: Instance, at: (number, number, number) -> CFrame)
	local size = Config.Plots.Size
	local half = size / 2
	local gap = 14
	local sideLength = (size - gap) / 2
	local wallProps = {
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(55, 52, 66),
	}
	local walls = {
		{ Vector3.new(size, 1.6, 1.4), at(0, FLOOR_TOP + 0.8, half - 0.7) },
		{ Vector3.new(1.4, 1.6, size), at(-half + 0.7, FLOOR_TOP + 0.8, 0) },
		{ Vector3.new(1.4, 1.6, size), at(half - 0.7, FLOOR_TOP + 0.8, 0) },
		{ Vector3.new(sideLength, 1.6, 1.4), at(-(gap / 2 + sideLength / 2), FLOOR_TOP + 0.8, -half + 0.7) },
		{ Vector3.new(sideLength, 1.6, 1.4), at(gap / 2 + sideLength / 2, FLOOR_TOP + 0.8, -half + 0.7) },
	}
	for _, wall in walls do
		local props = table.clone(wallProps)
		props.Name = "Wall"
		props.Size = wall[1]
		props.CFrame = wall[2]
		BuildUtil.part(parent, props)
	end
end

function PlotBuilder.Build(index: number, cframe: CFrame, parent: Instance): Model
	local size = Config.Plots.Size
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)

	local base = BuildUtil.part(model, {
		Name = "Base",
		Size = Vector3.new(size, 1, size),
		CFrame = at(0, 0.5, 0),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	BuildUtil.part(model, {
		Name = "Floor",
		Size = Vector3.new(size - 6, 0.2, size - 6),
		CFrame = at(0, 1.1, 0),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD,
	})
	buildWalls(model, at)
	buildGate(model, at)
	buildResonator(model, at)
	buildShowcasePodium(model, at)

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = model
	for slot = 1, Config.Plots.StartingPedestals do
		buildPedestal(pedestals, at, slot)
	end

	local spawnOffset = Config.Plots.SpawnOffset
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "SpawnPad",
		Size = Vector3.new(6, 1, 6),
		CFrame = at(spawnOffset[1], FLOOR_TOP, spawnOffset[2]),
		Transparency = 1,
	}))

	model.PrimaryPart = base
	model.Parent = parent
	return model
end

return PlotBuilder
