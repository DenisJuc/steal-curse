-- Builds the wild ring around the shrine town (GDD 4.1, Slice 11): Terrain ground (per-area
-- materials cross-faded in the blend zones), the stream, rim hills, one path per area from the town
-- to the edge, landmarks (WildLayout), bridges and scattered props (MapProps), then the signal spawn
-- grid with every point that ended up inside a prop removed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local BuildUtil = require(script.Parent.BuildUtil)
local MapProps = require(script.Parent.MapProps)

local WildBuilder = {}

export type SpawnPoint = { Position: Vector3, Area: string }
export type Wild = {
	Folder: Folder,
	SpawnPoints: { SpawnPoint },
	PropCount: number,
	PropsByArea: { [string]: number },
}

type AreaLook = { Main: Enum.Material, Patch: Enum.Material, Path: Enum.Material, Hill: Enum.Material }

local AREA_LOOK: { [string]: AreaLook } = {
	HauntedForest = {
		Main = Enum.Material.LeafyGrass,
		Patch = Enum.Material.Mud,
		Path = Enum.Material.Ground,
		Hill = Enum.Material.LeafyGrass,
	},
	AbandonedVillage = {
		Main = Enum.Material.Ground,
		Patch = Enum.Material.Grass,
		Path = Enum.Material.Cobblestone,
		Hill = Enum.Material.Ground,
	},
	AncientRuins = {
		Main = Enum.Material.Slate,
		Patch = Enum.Material.Sandstone,
		Path = Enum.Material.Sandstone,
		Hill = Enum.Material.Slate,
	},
}

local MATERIAL_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(70, 88, 58),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(50, 66, 52),
	[Enum.Material.Mud] = Color3.fromRGB(60, 50, 44),
	[Enum.Material.Ground] = Color3.fromRGB(92, 76, 60),
	[Enum.Material.Cobblestone] = Color3.fromRGB(112, 106, 100),
	[Enum.Material.Slate] = Color3.fromRGB(86, 84, 98),
	[Enum.Material.Sandstone] = Color3.fromRGB(150, 136, 112),
	[Enum.Material.Water] = Color3.fromRGB(60, 120, 140),
}

local CELL = 20
local GROUND_DEPTH = 12
local TERRAIN_RADIUS = Config.World.WildOuter + 120
local RIM_RADIUS = Config.World.WildOuter + 75
local WALL_RADIUS = Config.World.WildOuter + 100
local PATH_WIDTH = 12
local SCATTER_SCALE = NumberRange.new(0.8, 1.25)
local SPATIAL_CELL = 16
-- Bridge bottom height: its 1-stud walkway collider then sits level with the banks (y = 0).
local BRIDGE_BASE = -0.5
local TOWN_PATH = Enum.Material.Cobblestone
local PATH_GLOW = Color3.fromRGB(190, 140, 255)

local function look(areaId: string): AreaLook
	return AREA_LOOK[areaId] or AREA_LOOK.HauntedForest
end

-- Area at (x, z) with blend zones dithered: near a border either neighbour can win, in proportion.
local function ditheredArea(rng: Random, x: number, z: number): string
	local id, weight, other = WorldLayout.areaAt(Config.Areas, Config.World, x, z)
	if other and rng:NextNumber() > weight then
		return other
	end
	return id
end

local function fillGround(terrain: Terrain, rng: Random, seed: number)
	local world = Config.World
	terrain:FillCylinder(CFrame.new(0, -GROUND_DEPTH / 2, 0), GROUND_DEPTH, world.WildInner, Enum.Material.Grass)
	-- Cells are voxel-aligned (edges on multiples of 4): overlapping partial voxels leave dips.
	local limit = math.ceil(TERRAIN_RADIUS / CELL)
	for i = -limit, limit - 1 do
		for j = -limit, limit - 1 do
			local x, z = i * CELL + CELL / 2, j * CELL + CELL / 2
			local r = math.sqrt(x * x + z * z)
			if r > TERRAIN_RADIUS or r < world.WildInner - CELL then
				continue
			end
			local areaLook = look(ditheredArea(rng, x, z))
			local patch = math.noise(x / 70, z / 70, seed) > 0.22
			local material = if patch then areaLook.Patch else areaLook.Main
			terrain:FillBlock(CFrame.new(x, -GROUND_DEPTH / 2, z), Vector3.new(CELL, GROUND_DEPTH, CELL), material)
		end
	end
	terrain:FillCylinder(
		CFrame.new(0, -GROUND_DEPTH / 2, 0),
		GROUND_DEPTH + 0.5,
		Config.Hub.PlazaRadius + 4,
		Enum.Material.Slate
	)
	-- Grass decoration pokes through the thin plot floors, so plots stand on bare slate.
	local plots = Config.Plots
	for index = 1, plots.Count do
		local x, z = WorldLayout.plotPosition(plots, index)
		terrain:FillBlock(
			CFrame.lookAt(Vector3.new(x, -GROUND_DEPTH / 2, z), Vector3.new(0, -GROUND_DEPTH / 2, 0)),
			Vector3.new(plots.Size + 4, GROUND_DEPTH, plots.Size + 4),
			Enum.Material.Slate
		)
	end
end

-- Straight terrain strip from radius `inner` to `outer` along `angle`.
local function strip(terrain: Terrain, angle: number, inner: number, outer: number, width: number, material: Enum.Material)
	local ux, uz = WorldLayout.polar(angle, 1)
	local direction = Vector3.new(ux, 0, uz)
	local center = direction * ((inner + outer) / 2) - Vector3.new(0, GROUND_DEPTH / 2, 0)
	terrain:FillBlock(
		CFrame.lookAt(center, center + direction),
		Vector3.new(width, GROUND_DEPTH + 0.5, outer - inner),
		material
	)
end

local function buildPaths(terrain: Terrain, folder: Instance)
	local world = Config.World
	for index = 1, Config.Plots.Count do
		local angle = (index - 1) / Config.Plots.Count * 360
		strip(terrain, angle, Config.Hub.PlazaRadius, Config.Plots.RingRadius - Config.Plots.Size / 2, 10, TOWN_PATH)
	end
	for _, area in Config.Areas do
		strip(terrain, area.AngleDegrees, Config.Hub.PlazaRadius, world.WildInner, PATH_WIDTH, TOWN_PATH)
		strip(terrain, area.AngleDegrees, world.WildInner, world.WildOuter, PATH_WIDTH, look(area.Id).Path)
		-- Glowing stones lead from the plaza out to the wild.
		local ux, uz = WorldLayout.polar(area.AngleDegrees, 1)
		local side = Vector3.new(-uz, 0, ux) * (PATH_WIDTH / 2 + 1)
		for distance = Config.Hub.PlazaRadius + 8, world.WildInner + 30, 16 do
			local point = Vector3.new(ux, 0, uz) * distance + Vector3.new(0, 0.3, 0)
			for _, sign in { -1, 1 } do
				BuildUtil.decor(BuildUtil.part(folder, {
					Name = "PathGlow",
					Size = Vector3.new(0.8, 0.6, 0.8),
					CFrame = CFrame.new(point + side * sign) * CFrame.Angles(0, math.rad(45), 0),
					Material = Enum.Material.Neon,
					Color = PATH_GLOW,
				}))
			end
		end
	end
end

local function buildStream(terrain: Terrain)
	local world = Config.World
	local step = 2
	local length = 2 * math.pi * world.StreamRadius * step / 360 + 4
	for angle = 0, 360 - step, step do
		local x, z = WorldLayout.polar(angle, world.StreamRadius)
		local ux, uz = WorldLayout.polar(angle, 1)
		-- Local Z runs along the stream (tangent), X across it.
		local tangent = Vector3.new(-uz, 0, ux)
		local center = Vector3.new(x, 0, z)
		local frame = CFrame.lookAt(center, center + tangent)
		-- Clear one voxel row above the ground too (paths leave a thin layer there), then fill water
		-- up to 1 stud below the banks.
		terrain:FillBlock(frame, Vector3.new(world.StreamWidth + 4, 8, length), Enum.Material.Air)
		terrain:FillBlock(frame * CFrame.new(0, -4.5, 0), Vector3.new(world.StreamWidth + 2, 7, length), Enum.Material.Water)
	end
end

local function buildRim(terrain: Terrain, folder: Instance, rng: Random)
	for angle = 0, 355, 5 do
		local radius = RIM_RADIUS + rng:NextNumber(-15, 15)
		local x, z = WorldLayout.polar(angle + rng:NextNumber(-2, 2), radius)
		local areaId = WorldLayout.areaAt(Config.Areas, Config.World, x, z)
		terrain:FillBall(Vector3.new(x, -20, z), rng:NextNumber(55, 80), look(areaId).Hill)
	end
	-- Invisible boundary behind the hills.
	local segments = 72
	local width = 2 * math.pi * WALL_RADIUS / segments + 2
	for index = 0, segments - 1 do
		local angle = index * 360 / segments
		local x, z = WorldLayout.polar(angle, WALL_RADIUS)
		local center = Vector3.new(x, 60, z)
		local wall = BuildUtil.part(folder, {
			Name = "Boundary",
			Size = Vector3.new(width, 160, 4),
			CFrame = CFrame.lookAt(center, Vector3.new(0, 60, 0)),
			Transparency = 1,
			CastShadow = false,
		})
		wall.CanTouch = false
		wall.CanQuery = false
	end
end

-- Spatial hash of placed circles, for scatter spacing and spawn-point filtering.
type Circle = { X: number, Z: number, R: number }
local function hashKey(x: number, z: number): string
	return `{math.floor(x / SPATIAL_CELL)},{math.floor(z / SPATIAL_CELL)}`
end
local function nearby(hash: { [string]: { Circle } }, x: number, z: number, reach: number): { Circle }
	local found = {}
	local span = math.ceil(reach / SPATIAL_CELL)
	local cx, cz = math.floor(x / SPATIAL_CELL), math.floor(z / SPATIAL_CELL)
	for i = cx - span, cx + span do
		for j = cz - span, cz + span do
			for _, circle in hash[`{i},{j}`] or {} do
				table.insert(found, circle)
			end
		end
	end
	return found
end
local function addCircle(hash: { [string]: { Circle } }, circle: Circle)
	local key = hashKey(circle.X, circle.Z)
	local list = hash[key]
	if not list then
		list = {}
		hash[key] = list
	end
	table.insert(list, circle)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true

-- Terrain surface height at (x, z), so props stand on the ground instead of sinking into bumps.
local function groundY(x: number, z: number): number
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 30, z), Vector3.new(0, -60, 0), groundParams)
	return if hit then hit.Position.Y else 0
end

local function pickRule(rng: Random, rules: { WildLayout.ScatterRule }, total: number): string
	local roll = rng:NextNumber() * total
	for _, rule in rules do
		roll -= rule.Density
		if roll < 0 then
			return rule.Prop
		end
	end
	return rules[#rules].Prop
end

local function scatter(folder: Instance, rng: Random, boxes: { WorldLayout.Box }, hash: { [string]: { Circle } }): { [string]: number }
	local world = Config.World
	local inner2, outer2 = world.WildInner ^ 2, world.WildOuter ^ 2
	local sliceDegrees = 360 / #Config.Areas
	local sliceArea = math.pi * (outer2 - inner2) / #Config.Areas
	local counts: { [string]: number } = {}
	for _, area in Config.Areas do
		local rules = WildLayout.Scatter[area.Id] or {}
		local total = 0
		for _, rule in rules do
			total += rule.Density
		end
		local wanted = math.floor(total * sliceArea / 10000 + 0.5)
		local placed, attempts = 0, 0
		local spread = sliceDegrees / 2 + world.BlendDegrees / 2
		while placed < wanted and attempts < wanted * 12 do
			attempts += 1
			local r = math.sqrt(rng:NextNumber(inner2, outer2))
			local x, z = WorldLayout.polar(area.AngleDegrees + rng:NextNumber(-spread, spread), r)
			if ditheredArea(rng, x, z) ~= area.Id then
				continue
			end
			local propId = pickRule(rng, rules, total)
			local scale = rng:NextNumber(SCATTER_SCALE.Min, SCATTER_SCALE.Max)
			local radius = MapPropConfig.radius(propId) * scale
			if not WorldLayout.inWild(world, x, z, radius + 3) or WorldLayout.inStream(world, x, z, radius + 3) then
				continue
			end
			if WildLayout.pathDistance(Config.Areas, x, z) < PATH_WIDTH / 2 + radius + 2 then
				continue
			end
			local blocked = false
			for _, box in boxes do
				if WorldLayout.distanceToBox(x, z, box) < radius + 3 then
					blocked = true
					break
				end
			end
			if not blocked then
				for _, circle in nearby(hash, x, z, radius + 12) do
					if (circle.X - x) ^ 2 + (circle.Z - z) ^ 2 < ((circle.R + radius) * 0.85) ^ 2 then
						blocked = true
						break
					end
				end
			end
			if blocked then
				continue
			end
			local base = CFrame.new(x, groundY(x, z), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			MapProps.build(folder, propId, base, scale, rng)
			addCircle(hash, { X = x, Z = z, R = radius })
			placed += 1
		end
		counts[area.Id] = placed
	end
	return counts
end

local function buildLandmarks(folder: Instance, rng: Random, hash: { [string]: { Circle } })
	local areaNames: { [string]: string } = {}
	for _, area in Config.Areas do
		areaNames[area.Id] = area.Name
	end
	for _, structure in WildLayout.Structures do
		local x, z = WildLayout.position(structure)
		local rot = WildLayout.faceHubRot(structure.Angle) + structure.Twist
		local base = CFrame.new(x, groundY(x, z), z) * CFrame.Angles(0, math.rad(rot), 0)
		local model = MapProps.build(folder, structure.Prop, base, 1, rng)
		addCircle(hash, { X = x, Z = z, R = MapPropConfig.radius(structure.Prop) })
		if model and structure.Prop == "Signpost" then
			local areaId = WorldLayout.areaAt(Config.Areas, Config.World, x, z)
			local anchor = model:FindFirstChildWhichIsA("BasePart")
			if anchor then
				BuildUtil.billboard(anchor, areaNames[areaId] or areaId, 16, 2.4, 7, Color3.fromRGB(255, 236, 200))
			end
		end
	end
	local world = Config.World
	for _, angle in WildLayout.BridgeAngles do
		local x, z = WorldLayout.polar(angle, world.StreamRadius)
		local ux, uz = WorldLayout.polar(angle, 1)
		local center = Vector3.new(x, BRIDGE_BASE, z)
		MapProps.build(folder, "WoodenBridge", CFrame.lookAt(center, center + Vector3.new(ux, 0, uz)), 1, rng)
	end
	-- A torii where each path leaves the town.
	for _, area in Config.Areas do
		local x, z = WorldLayout.polar(area.AngleDegrees, world.WildInner - 10)
		MapProps.build(folder, "ShrineGate", CFrame.lookAt(Vector3.new(x, 0, z), Vector3.zero), 1, rng)
	end
end

function WildBuilder.Build(parent: Instance): Wild
	local terrain = workspace.Terrain
	local rng = Random.new(Config.Areas[1].Seed)
	for material, color in MATERIAL_COLORS do
		-- SetMaterialColor rejects Water; its color is Terrain.WaterColor.
		if material ~= Enum.Material.Water then
			terrain:SetMaterialColor(material, color)
		end
	end
	terrain.WaterColor = MATERIAL_COLORS[Enum.Material.Water]
	terrain.WaterTransparency = 0.2
	terrain.WaterWaveSize = 0.12
	pcall(function()
		terrain.Decoration = true
	end)

	local folder = Instance.new("Folder")
	folder.Name = "Wild"

	fillGround(terrain, rng, Config.Areas[1].Seed)
	buildPaths(terrain, folder)
	buildStream(terrain)
	buildRim(terrain, folder, rng)

	local hash: { [string]: { Circle } } = {}
	buildLandmarks(folder, rng, hash)
	local boxes = WildLayout.boxes(MapPropConfig.Props)
	local counts = scatter(folder, rng, boxes, hash)

	local spawns = {}
	for _, point in WorldLayout.spawnGrid(Config.Areas, Config.World, boxes) do
		local clear = true
		for _, circle in nearby(hash, point.X, point.Z, 24) do
			if (circle.X - point.X) ^ 2 + (circle.Z - point.Z) ^ 2 < (circle.R + 2) ^ 2 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(spawns, { Position = Vector3.new(point.X, 0, point.Z), Area = point.Area })
		end
	end

	local total = 0
	for _, count in counts do
		total += count
	end
	folder.Parent = parent
	return { Folder = folder, SpawnPoints = spawns, PropCount = total + #WildLayout.Structures, PropsByArea = counts }
end

return WildBuilder
