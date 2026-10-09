-- Builds one hunting district (GDD 4.1) from its DistrictLayouts entry and a visual theme: floor,
-- named entrance gate facing the hub, themed structures that break line of sight, dressing, and
-- the SignalSpawn markers personal signals appear at. Local -Z faces the hub.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DistrictLayouts = require(ReplicatedStorage.Shared.DistrictLayouts)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local BuildUtil = require(script.Parent.BuildUtil)

local DistrictBuilder = {}

export type At = (x: number, y: number, z: number) -> CFrame
-- free(x, z, clearance): inside the district, outside the entrance lane, `clearance` studs from
-- every structure and signal spawn point. Themes use it to scatter dressing.
export type Free = (x: number, z: number, clearance: number) -> boolean
export type Theme = {
	FloorMaterial: Enum.Material,
	FloorColor: Color3,
	GateStone: Color3,
	GateLamp: Color3,
	NameColor: Color3,
	Structure: (model: Model, at: At, blocker: DistrictLayouts.Blocker) -> (),
	Dress: (model: Model, at: At, rng: Random, free: Free) -> (),
}

export type District = {
	Id: string,
	Name: string,
	Model: Model,
	SpawnPoints: { Vector3 },
	-- Teleport target just outside the gate, facing into the district.
	Entrance: CFrame,
}

DistrictBuilder.FloorTop = 0.4

local function buildGate(model: Model, at: At, theme: Theme, name: string): CFrame
	local top = DistrictBuilder.FloorTop
	local z = -Config.World.DistrictSize / 2
	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "GatePillar",
			Size = Vector3.new(2.5, 16, 2.5),
			CFrame = at(side * 9, top + 8, z),
			Material = Enum.Material.Slate,
			Color = theme.GateStone,
		})
		local lamp = BuildUtil.part(model, {
			Name = "GateLamp",
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = at(side * 9, top + 17, z),
			Material = Enum.Material.Neon,
			Color = theme.GateLamp,
		})
		BuildUtil.decor(lamp)
		BuildUtil.light(lamp, theme.GateLamp, 14, 1.2)
	end
	local beam = BuildUtil.part(model, {
		Name = "GateBeam",
		Size = Vector3.new(22, 1.6, 2.6),
		CFrame = at(0, top + 15.6, z),
		Material = Enum.Material.Slate,
		Color = theme.GateStone:Lerp(Color3.new(0, 0, 0), 0.3),
	})
	BuildUtil.billboard(beam, name, 26, 3.4, 4, theme.NameColor)
	return at(0, top + 3, z - 8) * CFrame.Angles(0, math.pi, 0)
end

function DistrictBuilder.Build(parent: Instance, district: WorldLayout.District, theme: Theme): District
	local world = Config.World
	local layout = DistrictLayouts.ById[district.Id]
	local half = world.DistrictSize / 2
	local cx, cz = WorldLayout.districtCenter(district, world)
	local cframe = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.zero)
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local lane = DistrictLayouts.EntranceLane
	local function free(x: number, z: number, clearance: number): boolean
		if math.abs(x) > half - 6 or math.abs(z) > half - 6 then
			return false
		end
		if math.abs(x) < lane.HalfWidth + 2 and z < -half + lane.Depth + 5 then
			return false
		end
		for _, spawn in layout.Spawns do
			if (spawn[1] - x) ^ 2 + (spawn[2] - z) ^ 2 < clearance * clearance then
				return false
			end
		end
		for _, blocker in layout.Blockers do
			if WorldLayout.distanceToBox(x, z, blocker) < clearance then
				return false
			end
		end
		return true
	end

	local model = Instance.new("Model")
	model.Name = district.Id
	model:SetAttribute("District", district.Id)
	model:SetAttribute("DisplayName", district.Name)

	BuildUtil.part(model, {
		Name = "Floor",
		Size = Vector3.new(world.DistrictSize, DistrictBuilder.FloorTop, world.DistrictSize),
		CFrame = at(0, DistrictBuilder.FloorTop / 2, 0),
		Material = theme.FloorMaterial,
		Color = theme.FloorColor,
	})
	for _, blocker in layout.Blockers do
		theme.Structure(model, at, blocker)
	end
	theme.Dress(model, at, Random.new(district.Seed), free)
	local entrance = buildGate(model, at, theme, district.Name)

	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "SignalSpawns"
	spawnFolder.Parent = model
	local spawnPoints = {}
	for index, offset in layout.Spawns do
		local marker = BuildUtil.decor(BuildUtil.part(spawnFolder, {
			Name = "SignalSpawn" .. index,
			Size = Vector3.new(1, 1, 1),
			CFrame = at(offset[1], DistrictBuilder.FloorTop, offset[2]),
			Transparency = 1,
		}))
		marker:SetAttribute("District", district.Id)
		CollectionService:AddTag(marker, "SignalSpawn")
		spawnPoints[index] = marker.Position
	end

	model.Parent = parent
	return { Id = district.Id, Name = district.Name, Model = model, SpawnPoints = spawnPoints, Entrance = entrance }
end

return DistrictBuilder
