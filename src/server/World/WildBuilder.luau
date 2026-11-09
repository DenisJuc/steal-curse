-- Builds the wild ring around the shrine town (GDD 4.1, Slice 11): Terrain ground shaped by
-- WildTerrain (hills, ravines, terraces, plateaus, pits; per-area materials cross-faded in the
-- blend zones, cliff material on steep ground), the stream, rim hills, rock walls, one path per
-- area from the town to the edge, landmarks (WildLayout), bridges and scattered props (MapProps),
-- then the signal spawn grid with every point inside a prop, a wall or a deep pit removed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local WildTerrain = require(ReplicatedStorage.Shared.WildTerrain)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local BuildUtil = require(script.Parent.BuildUtil)
local MapProps = require(script.Parent.MapProps)
local WildDressing = require(script.Parent.WildDressing)

local WildBuilder = {}

export type SpawnPoint = { Position: Vector3, Area: string }
export type Wild = {
	Folder: Folder,
	SpawnPoints: { SpawnPoint },
	PropCount: number,
	PropsByArea: { [string]: number },
}

type AreaLook = {
	Main: Enum.Material,
	Patch: Enum.Material,
	Path: Enum.Material,
	Hill: Enum.Material,
	-- Steep ground (cliffs, pit and ravine sides).
	Cliff: Enum.Material,
	-- Small scattered patches (leaf litter, old paving, rubble).
	Litter: Enum.Material,
	-- Pit and ravine floors, and the stream banks.
	Low: Enum.Material,
	Bank: Enum.Material,
	-- Rain water collects in the deepest pits and ravines.
	Puddles: boolean,
}

local AREA_LOOK: { [string]: AreaLook } = {
	HauntedForest = {
		Main = Enum.Material.LeafyGrass,
		Patch = Enum.Material.Mud,
		Path = Enum.Material.Ground,
		Hill = Enum.Material.LeafyGrass,
		Cliff = Enum.Material.Rock,
		Litter = Enum.Material.Ground,
		Low = Enum.Material.Mud,
		Bank = Enum.Material.Mud,
		Puddles = true,
	},
	AbandonedVillage = {
		Main = Enum.Material.Ground,
		Patch = Enum.Material.Grass,
		Path = Enum.Material.Cobblestone,
		Hill = Enum.Material.Ground,
		Cliff = Enum.Material.Mud,
		Litter = Enum.Material.Cobblestone,
		Low = Enum.Material.Mud,
		Bank = Enum.Material.Mud,
		Puddles = true,
	},
	AncientRuins = {
		Main = Enum.Material.Slate,
		Patch = Enum.Material.Sandstone,
		Path = Enum.Material.Sandstone,
		Hill = Enum.Material.Slate,
		Cliff = Enum.Material.Basalt,
		Litter = Enum.Material.Limestone,
		Low = Enum.Material.Basalt,
		Bank = Enum.Material.Ground,
		Puddles = false,
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
	[Enum.Material.Rock] = Color3.fromRGB(78, 80, 78),
	[Enum.Material.Basalt] = Color3.fromRGB(58, 56, 66),
	[Enum.Material.Limestone] = Color3.fromRGB(118, 112, 100),
	[Enum.Material.Water] = Color3.fromRGB(60, 120, 140),
}

local GROUND_DEPTH = 12
-- Heightfield voxels: 4-stud columns written in 64-stud chunks, from GROUND_BOTTOM to GROUND_TOP
-- (multiples of 4 so the regions sit on the voxel grid).
local VOXEL = 4
local CHUNK = 16
local GROUND_BOTTOM = -28
local GROUND_TOP = 44
-- Rise per stud above which the ground shows its area's cliff material.
local CLIFF_SLOPE = 0.9
-- Ground below this is a pit/ravine floor (Low material); puddles fill up to WATER_LEVEL.
local LOW_HEIGHT = -3.5
local WATER_LEVEL = -4
-- Studs from the stream edge that stay muddy bank.
local BANK_WIDTH = 10
-- Little stone clusters dotted over the wild (decor parts, no collision).
local PEBBLE_CLUSTERS = 140
local PEBBLE_COLOR = Color3.fromRGB(62, 62, 66)
local TERRAIN_RADIUS = Config.World.WildOuter + 120
local RIM_RADIUS = Config.World.WildOuter + 75
local WALL_RADIUS = Config.World.WildOuter + 100
local PATH_WIDTH = 12
local SCATTER_SCALE = NumberRange.new(0.8, 1.25)
local SPATIAL_CELL = 16
-- Bridge bottom height: its 1-stud walkway collider then sits level with the banks (y = 0).
local BRIDGE_BASE = -0.5
-- Smoothed terrain puts the flat town surface (street, plaza, lawns) this high (measured in Studio).
local TOWN_SURFACE = 2.2
-- Paved town paths are parts (crisp edges, flagstone material) standing this high, just above the
-- terrain; terrain voxels drew them as 4-stud staircase edges ("pixelated").
local PAVE_TOP = TOWN_SURFACE + 0.2
local PAVE_KERB = Color3.fromRGB(44, 40, 54)
local PATH_GLOW = Color3.fromRGB(190, 140, 255)
-- Landmarks a spirit pulse outlines through the fog (client SpiritSight).
local LANDMARK_TAG = "Landmark"
-- Cursed Shrines (CurseService; client CursedShrines draws the cleanse and its light).
local SHRINE_TAG = "CursedShrine"
-- Trees crows land on (client WildLife) and that can wear a shimenawa rope (WildDressing).
local PERCH_TAG = "Perch"
local PERCHES = { DeadTree1 = true, DeadTree2 = true, AncientTree = true }

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

-- One 64x64-stud chunk of the heightfield. Heights carry a one-column border so every column can
-- measure its slope (steep columns take the cliff material).
local function writeChunk(terrain: Terrain, rng: Random, seed: number, shape: WildTerrain.Shape, x0: number, z0: number)
	local world = Config.World
	local heights: { { number } } = {}
	for i = 0, CHUNK + 1 do
		local row = {}
		for j = 0, CHUNK + 1 do
			row[j] = shape.heightAt(x0 + (i - 0.5) * VOXEL, z0 + (j - 0.5) * VOXEL)
		end
		heights[i] = row
	end
	local layers = (GROUND_TOP - GROUND_BOTTOM) / VOXEL
	local materials, occupancies = {}, {}
	for i = 1, CHUNK do
		local materialRows, occupancyRows = {}, {}
		for k = 1, layers do
			materialRows[k], occupancyRows[k] = {}, {}
		end
		for j = 1, CHUNK do
			local x, z = x0 + (i - 0.5) * VOXEL, z0 + (j - 0.5) * VOXEL
			local r = math.sqrt(x * x + z * z)
			local height = if r > TERRAIN_RADIUS then -math.huge else heights[i][j]
			local material = Enum.Material.Grass
			-- Town lawn: patches of leafy grass and bare earth so it isn't one flat green carpet.
			if r < world.WildInner then
				local patch = math.noise(x / 46, z / 46, seed + 21)
				if patch > 0.3 then
					material = Enum.Material.LeafyGrass
				elseif patch < -0.38 then
					material = Enum.Material.Ground
				end
			end
			local puddles = false
			if r >= world.WildInner then
				local areaLook = look(ditheredArea(rng, x, z))
				puddles = areaLook.Puddles
				local rise = math.max(
					math.abs(heights[i + 1][j] - heights[i - 1][j]),
					math.abs(heights[i][j + 1] - heights[i][j - 1])
				) / (2 * VOXEL)
				if rise > CLIFF_SLOPE then
					material = areaLook.Cliff
				elseif height < LOW_HEIGHT then
					material = areaLook.Low
				elseif math.abs(r - world.StreamRadius) < world.StreamWidth / 2 + BANK_WIDTH then
					material = areaLook.Bank
				elseif math.noise(x / 70, z / 70, seed) > 0.22 then
					material = areaLook.Patch
				elseif math.noise(x / 18, z / 18, seed + 5) > 0.32 then
					material = areaLook.Litter
				else
					material = areaLook.Main
				end
			end
			for k = 1, layers do
				local bottom = GROUND_BOTTOM + (k - 1) * VOXEL
				local fill = math.clamp((height - bottom) / VOXEL, 0, 1)
				if puddles and fill < 0.5 and bottom + VOXEL <= WATER_LEVEL and height < WATER_LEVEL - 1 then
					occupancyRows[k][j] = 1
					materialRows[k][j] = Enum.Material.Water
				else
					occupancyRows[k][j] = fill
					materialRows[k][j] = if fill > 0 then material else Enum.Material.Air
				end
			end
		end
		materials[i], occupancies[i] = materialRows, occupancyRows
	end
	local region = Region3.new(Vector3.new(x0, GROUND_BOTTOM, z0), Vector3.new(x0 + CHUNK * VOXEL, GROUND_TOP, z0 + CHUNK * VOXEL))
	terrain:WriteVoxels(region, VOXEL, materials, occupancies)
end

local function fillGround(terrain: Terrain, rng: Random, seed: number, shape: WildTerrain.Shape)
	local span = CHUNK * VOXEL
	local limit = math.ceil(TERRAIN_RADIUS / span)
	for ci = -limit, limit - 1 do
		for cj = -limit, limit - 1 do
			local x0, z0 = ci * span, cj * span
			local nx = math.clamp(0, x0, x0 + span)
			local nz = math.clamp(0, z0, z0 + span)
			if nx * nx + nz * nz <= TERRAIN_RADIUS * TERRAIN_RADIUS then
				writeChunk(terrain, rng, seed, shape, x0, z0)
			end
		end
		task.wait()
	end
	local hubX, hubZ, hubFX, hubFZ = WorldLayout.hubFrame(Config.Plots)
	local plazaSize = Config.Hub.PlazaSize
	local hubCenter = Vector3.new(hubX, -GROUND_DEPTH / 2, hubZ)
	local hubFacing = CFrame.lookAt(hubCenter, hubCenter + Vector3.new(hubFX, 0, hubFZ))
	terrain:FillBlock(hubFacing, Vector3.new(plazaSize[1] + 8, GROUND_DEPTH + 0.5, plazaSize[2] + 8), Enum.Material.Slate)
	-- Clear the top voxels under the plaza slab (like the plots): the smoothed terrain surface sits
	-- at the slab's own height and flickers through its tiles otherwise.
	local clearCenter = Vector3.new(hubX, 2, hubZ)
	terrain:FillBlock(
		CFrame.lookAt(clearCenter, clearCenter + Vector3.new(hubFX, 0, hubFZ)),
		Vector3.new(plazaSize[1] - 2, 12, plazaSize[2] - 2),
		Enum.Material.Air
	)
	-- Grass decoration pokes through the thin plot floors, so plots stand on bare slate.
	local plots = Config.Plots
	for index = 1, plots.Count do
		local x, z = WorldLayout.plotPosition(plots, index)
		local fx, fz = WorldLayout.plotFacing(plots, index)
		local facing = Vector3.new(fx, 0, fz)
		terrain:FillBlock(
			CFrame.lookAt(Vector3.new(x, -GROUND_DEPTH / 2, z), Vector3.new(x, -GROUND_DEPTH / 2, z) + facing),
			Vector3.new(plots.Size + 4, GROUND_DEPTH, plots.Size + 4),
			Enum.Material.Slate
		)
		-- Smoothing puts a full top voxel's surface ~2 studs up, over the plot floor (top 1.26)
		-- and its daises and binding circle; clear one voxel more so the surface sits below the Base.
		local center = Vector3.new(x, 2, z)
		terrain:FillBlock(
			CFrame.lookAt(center, center + facing),
			Vector3.new(plots.Size - 2, 12, plots.Size - 2),
			Enum.Material.Air
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

-- Paved strip between two ground points (x, z): a flagstone slab with low dark kerbs. Ends are
-- padded so bends join without gaps.
local function pave(folder: Instance, a: { number }, b: { number }, width: number)
	local from = Vector3.new(a[1], PAVE_TOP - 0.3, a[2])
	local to = Vector3.new(b[1], PAVE_TOP - 0.3, b[2])
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local frame = CFrame.lookAt((from + to) / 2, to)
	local slab = BuildUtil.part(folder, {
		Name = "Pavement",
		Size = Vector3.new(width, 0.6, length + width / 2),
		CFrame = frame,
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(150, 146, 156),
	})
	slab.MaterialVariant = "ShrineFlagstone"
	for _, side in { -1, 1 } do
		BuildUtil.part(folder, {
			Name = "PavementKerb",
			Size = Vector3.new(0.8, 0.8, length + width / 2),
			CFrame = frame * CFrame.new(side * (width / 2 + 0.4), 0.1, 0),
			Material = Enum.Material.Basalt,
			Color = PAVE_KERB,
		})
	end
end

local function glowPair(folder: Instance, point: Vector3, side: Vector3)
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

-- Brighter street lanterns: Shrine Street is lit, the wild is not.
local function brighten(model: Model?, light: { Range: number, Brightness: number })
	if not model then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Range = light.Range
			descendant.Brightness = light.Brightness
		end
	end
end

-- Town dressing on the open ground beside the plot rows: composed vignettes instead of single
-- props on a grid (the grid read as the same 3-4 models copy-pasted). Each spot on a loose grid
-- becomes one small scene (a bamboo grove, a sakura glade, a rock garden, a roadside jizo
-- shrine, a withered tree with mushrooms) or stays empty, every piece clear of plots, the plaza,
-- the street and the town paths. Spider lily patches are 14 parts each: use few.
type Piece = { Prop: string, R: { number }, Scale: { number }, Count: { number } }
-- stylua: ignore
local VIGNETTES: { { Weight: number, Pieces: { Piece } } } = {
	-- Bamboo grove: a tight clump of mixed bamboo, ferns at its feet.
	{ Weight = 5, Pieces = {
		{ Prop = "BambooGrove", R = { 0, 5 }, Scale = { 0.75, 1.25 }, Count = { 1, 2 } },
		{ Prop = "BambooGrove2", R = { 2, 6 }, Scale = { 0.7, 1.2 }, Count = { 1, 2 } },
		{ Prop = "FernBush", R = { 5, 9 }, Scale = { 0.7, 1.2 }, Count = { 2, 4 } },
	} },
	-- Sakura glade: one tree, a ring of spider lilies and a rock.
	{ Weight = 2, Pieces = {
		{ Prop = "HomeBlossomTree", R = { 0, 1 }, Scale = { 0.9, 1.25 }, Count = { 1, 1 } },
		{ Prop = "SpiderLilyPatch", R = { 5, 9 }, Scale = { 0.8, 1.2 }, Count = { 1, 2 } },
		{ Prop = "MossRock2", R = { 6, 9 }, Scale = { 0.8, 1.2 }, Count = { 0, 1 } },
	} },
	-- Rock garden: big and small mossy rocks, a slab, sometimes a lantern.
	{ Weight = 4, Pieces = {
		{ Prop = "MossRock3", R = { 0, 3 }, Scale = { 1.1, 1.8 }, Count = { 1, 1 } },
		{ Prop = "MossRock1", R = { 3, 6 }, Scale = { 0.6, 1.1 }, Count = { 1, 2 } },
		{ Prop = "MossRock4", R = { 3, 7 }, Scale = { 0.5, 0.9 }, Count = { 0, 2 } },
		{ Prop = "MossSlab", R = { 4, 7 }, Scale = { 0.8, 1.3 }, Count = { 1, 2 } },
		{ Prop = "MossLantern", R = { 6, 8 }, Scale = { 0.9, 1 }, Count = { 0, 1 } },
	} },
	-- Roadside shrine: a few jizo statues, a lantern, lilies.
	{ Weight = 2, Pieces = {
		{ Prop = "JizoStatue", R = { 0, 3 }, Scale = { 1.1, 1.4 }, Count = { 2, 3 } },
		{ Prop = "MossLantern", R = { 4, 5 }, Scale = { 0.9, 1 }, Count = { 1, 1 } },
		{ Prop = "SpiderLilyPatch", R = { 4, 7 }, Scale = { 0.6, 0.9 }, Count = { 0, 1 } },
	} },
	-- Withered corner: a dead tree, glowing mushrooms, a fallen log.
	{ Weight = 2, Pieces = {
		{ Prop = "DeadTree2", R = { 0, 2 }, Scale = { 0.9, 1.2 }, Count = { 1, 1 } },
		{ Prop = "GlowMushrooms", R = { 3, 6 }, Scale = { 0.7, 1.1 }, Count = { 2, 3 } },
		{ Prop = "FallenLog", R = { 5, 8 }, Scale = { 0.5, 0.8 }, Count = { 0, 1 } },
	} },
	-- Open grass (breathing room).
	{ Weight = 3, Pieces = {} },
}
local DRESSING_SPACING = 32
local DRESSING_JITTER = 10

local function segmentDistance(x: number, z: number, a: { number }, b: { number }): number
	local abx, abz = b[1] - a[1], b[2] - a[2]
	local t = math.clamp(((x - a[1]) * abx + (z - a[2]) * abz) / (abx * abx + abz * abz), 0, 1)
	local px, pz = a[1] + abx * t, a[2] + abz * t
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
end

local function dressTown(folder: Instance, paths: { [string]: { { number } } })
	local world = Config.World
	local plots = Config.Plots
	local street = plots.Street
	local rng = Random.new(2611)
	local plaza = WorldLayout.plazaBox(plots, Config.Hub.PlazaSize)
	local function clear(x: number, z: number): boolean
		if math.sqrt(x * x + z * z) > world.WildInner - 10 then
			return false
		end
		local along, across = WorldLayout.toStreet(street, x, z)
		if math.abs(across) < street.HalfWidth + 6 and along > street.HubAt then
			return false
		end
		if WorldLayout.distanceToBox(x, z, plaza) < 8 then
			return false
		end
		for index = 1, plots.Count do
			if WorldLayout.distanceToBox(x, z, WorldLayout.plotBox(plots, index)) < 5 then
				return false
			end
		end
		for _, points in paths do
			for k = 1, #points - 1 do
				if segmentDistance(x, z, points[k], points[k + 1]) < PATH_WIDTH / 2 + 4 then
					return false
				end
			end
		end
		return true
	end
	local total = 0
	for _, vignette in VIGNETTES do
		total += vignette.Weight
	end
	local limit = math.ceil(world.WildInner / DRESSING_SPACING)
	for i = -limit, limit do
		for j = -limit, limit do
			local cx = i * DRESSING_SPACING + rng:NextNumber(-DRESSING_JITTER, DRESSING_JITTER)
			local cz = j * DRESSING_SPACING + rng:NextNumber(-DRESSING_JITTER, DRESSING_JITTER)
			if not clear(cx, cz) then
				continue
			end
			local pick = rng:NextNumber() * total
			local vignette = VIGNETTES[#VIGNETTES]
			for _, entry in VIGNETTES do
				pick -= entry.Weight
				if pick <= 0 then
					vignette = entry
					break
				end
			end
			for _, piece in vignette.Pieces do
				for _ = 1, rng:NextInteger(piece.Count[1], piece.Count[2]) do
					local angle = rng:NextNumber(0, math.pi * 2)
					local radius = rng:NextNumber(piece.R[1], piece.R[2])
					local x, z = cx + math.cos(angle) * radius, cz + math.sin(angle) * radius
					if clear(x, z) then
						local base = CFrame.new(x, TOWN_SURFACE, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
						MapProps.build(folder, piece.Prop, base, rng:NextNumber(piece.Scale[1], piece.Scale[2]), rng)
					end
				end
			end
		end
	end
	-- Treeline along the town edge (in front of the veil): bamboo with the odd dead tree, so the
	-- town reads as a clearing in the forest. Gaps where the street and the town paths leave.
	local exits = {}
	for _, points in paths do
		local last = points[#points]
		table.insert(exits, WorldLayout.angleOf(last[1], last[2]))
	end
	local edgeR = world.WildInner - 9
	local step = 360 / math.floor(2 * math.pi * edgeR / 15)
	for angle = 0, 360 - step, step do
		local blocked = false
		for _, exit in exits do
			local delta = math.abs((angle - exit + 180) % 360 - 180)
			blocked = blocked or delta * math.pi / 180 * edgeR < PATH_WIDTH + 8
		end
		local a = angle + rng:NextNumber(-step / 3, step / 3)
		local x, z = WorldLayout.polar(a, edgeR + rng:NextNumber(-3, 3))
		if blocked or not clear(x, z) then
			continue
		end
		local roll = rng:NextNumber()
		local prop = if roll < 0.12 then "DeadTree1" elseif roll < 0.56 then "BambooGrove" else "BambooGrove2"
		local base = CFrame.new(x, TOWN_SURFACE, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		MapProps.build(folder, prop, base, rng:NextNumber(0.9, 1.35), rng)
		if rng:NextNumber() < 0.35 then
			local fx, fz = WorldLayout.polar(a + rng:NextNumber(-1, 1), edgeR - rng:NextNumber(5, 9))
			if clear(fx, fz) then
				MapProps.build(folder, "FernBush", CFrame.new(fx, TOWN_SURFACE, fz), rng:NextNumber(0.8, 1.2), rng)
			end
		end
	end
end

-- Shrine Street: the paved avenue from the hub plaza to the wild gate, stone lanterns along both
-- curbs, a torii where it leaves the plaza and the Spirit Lane inlay down the middle; town paths
-- from the plaza to the other areas, then dressing on the open ground.
local function buildTown(folder: Instance)
	local world = Config.World
	local plots = Config.Plots
	local street = plots.Street
	local plazaSize = Config.Hub.PlazaSize
	local startAt = WorldLayout.streetStart(plots, plazaSize)
	local nearEnd = { WorldLayout.fromStreet(street, startAt, 0) }
	local farEnd = { WorldLayout.fromStreet(street, world.WildInner, 0) }
	pave(folder, nearEnd, farEnd, street.HalfWidth * 2)
	local dx, dz, nx, nz = WorldLayout.streetAxes(street)
	local along = Vector3.new(dx, 0, dz)
	for distance = startAt + 8, world.WildInner - 14, street.LanternSpacing do
		-- Keep plot entrances clear.
		local blocking = false
		for index = 1, plots.Count, 2 do
			blocking = blocking or math.abs(distance - (WorldLayout.plotStreet(plots, index))) < 10
		end
		if blocking then
			continue
		end
		for _, side in { -1, 1 } do
			local x, z = WorldLayout.fromStreet(street, distance, side * (street.HalfWidth - 2))
			local position = Vector3.new(x, PAVE_TOP, z)
			brighten(MapProps.build(folder, "ToroLantern", CFrame.lookAt(position, position + Vector3.new(-nx * side, 0, -nz * side))), street.LanternLight)
		end
	end
	local gx, gz = WorldLayout.fromStreet(street, startAt + 2, 0)
	local gate = Vector3.new(gx, PAVE_TOP, gz)
	MapProps.build(folder, "ShrineGate", CFrame.lookAt(gate, gate + along))

	-- Spirit Lane: glowing diamond tiles down the center line (the street is faster to walk).
	for distance = startAt + 6, world.WildInner - 2, 9 do
		local x, z = WorldLayout.fromStreet(street, distance, 0)
		local center = Vector3.new(x, PAVE_TOP + 0.06, z)
		BuildUtil.decor(BuildUtil.part(folder, {
			Name = "SpiritLane",
			Size = Vector3.new(2.2, 0.16, 2.2),
			CFrame = CFrame.lookAt(center, center + along) * CFrame.Angles(0, math.rad(45), 0),
			Material = Enum.Material.Neon,
			Color = PATH_GLOW,
			Transparency = 0.25,
		}))
	end
	for _, side in { -1, 1 } do
		local x, z = WorldLayout.fromStreet(street, (startAt + world.WildInner) / 2, side * 3.2)
		local center = Vector3.new(x, PAVE_TOP + 0.04, z)
		BuildUtil.decor(BuildUtil.part(folder, {
			Name = "SpiritLaneLine",
			Size = Vector3.new(0.35, 0.12, world.WildInner - startAt - 4),
			CFrame = CFrame.lookAt(center, center + along),
			Material = Enum.Material.Neon,
			Color = PATH_GLOW,
			Transparency = 0.45,
		}))
	end

	local paths = WorldLayout.townPaths(plots, world, Config.Areas, plazaSize)
	for _, area in Config.Areas do
		local points = paths[area.Id]
		if math.abs(area.AngleDegrees - street.AngleDegrees) < 1e-6 then
			continue
		end
		for index = 1, #points - 1 do
			local a, b = points[index], points[index + 1]
			pave(folder, a, b, PATH_WIDTH)
			local from, to = Vector3.new(a[1], PAVE_TOP + 0.3, a[2]), Vector3.new(b[1], PAVE_TOP + 0.3, b[2])
			local direction = (to - from).Unit
			local side = Vector3.new(-direction.Z, 0, direction.X) * (PATH_WIDTH / 2 + 1)
			for distance = 8, (to - from).Magnitude, 16 do
				glowPair(folder, from + direction * distance, side)
			end
		end
	end
	dressTown(folder, paths)
end

local function buildPaths(terrain: Terrain, folder: Instance)
	local world = Config.World
	buildTown(folder)
	for _, area in Config.Areas do
		strip(terrain, area.AngleDegrees, world.WildInner, world.WildOuter, PATH_WIDTH, look(area.Id).Path)
		-- Glowing stones lead from the town edge into the wild, then sparser all the way to the edge
		-- (in the dark they are how you find the path back).
		local ux, uz = WorldLayout.polar(area.AngleDegrees, 1)
		local side = Vector3.new(-uz, 0, ux) * (PATH_WIDTH / 2 + 1)
		local distances = {}
		for distance = world.WildInner + 2, world.WildInner + 30, 16 do
			table.insert(distances, distance)
		end
		for distance = world.WildInner + 58, world.WildOuter - 10, 28 do
			if not WorldLayout.inStream(world, distance, 0, 8) then
				table.insert(distances, distance)
			end
		end
		for _, distance in distances do
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

-- Rock walls (WildLayout.Walls): segments of terrain standing on the relief, a bit taller or
-- shorter each, with boulders on top so the skyline is ragged.
local function buildWalls(terrain: Terrain, rng: Random, shape: WildTerrain.Shape)
	for wallIndex, wall in WildLayout.Walls do
		local material = (Enum.Material :: any)[wall.Material] or Enum.Material.Rock
		local angles = WildLayout.wallAngles(wall)
		local length = math.rad(wall.Angle1 - wall.Angle0) * wall.Radius / #angles + 1.5
		for index, angle in angles do
			local x, z = WorldLayout.polar(angle, wall.Radius)
			local ux, uz = WorldLayout.polar(angle, 1)
			local ground = shape.heightAt(x, z)
			-- Ends taper down so the walls fade into the ground.
			local taper = math.min(1, math.min(index, #angles + 1 - index) / 3)
			local height = wall.Height * taper * (0.8 + 0.4 * (math.noise(index * 0.31, wallIndex * 7.1, 2) + 0.5))
			local center = Vector3.new(x, ground - 4 + (height + 4) / 2, z)
			local frame = CFrame.lookAt(center, center + Vector3.new(-uz, 0, ux))
			terrain:FillBlock(frame, Vector3.new(wall.Thickness, height + 4, length), material)
			if rng:NextNumber() < 0.35 then
				terrain:FillBall(center + Vector3.new(0, height / 2, 0), wall.Thickness * rng:NextNumber(0.5, 0.75), material)
			end
		end
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
	local hit = workspace:Raycast(Vector3.new(x, GROUND_TOP + 40, z), Vector3.new(0, -(GROUND_TOP + 40 - GROUND_BOTTOM), 0), groundParams)
	return if hit then hit.Position.Y else 0
end

-- Small stone clusters (3-6 decor parts each) so the ground is not bare between props.
local function scatterPebbles(folder: Instance, rng: Random)
	local pebbles = Instance.new("Folder")
	pebbles.Name = "Pebbles"
	pebbles.Parent = folder
	local world = Config.World
	local inner2, outer2 = world.WildInner ^ 2, world.WildOuter ^ 2
	local placed = 0
	while placed < PEBBLE_CLUSTERS do
		local x, z = WorldLayout.polar(rng:NextNumber(0, 360), math.sqrt(rng:NextNumber(inner2, outer2)))
		if WorldLayout.inStream(world, x, z, 3) or WildLayout.pathDistance(Config.Areas, x, z) < PATH_WIDTH / 2 then
			continue
		end
		placed += 1
		for _ = 1, rng:NextInteger(3, 6) do
			local px, pz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
			local size = rng:NextNumber(0.5, 1.6)
			BuildUtil.decor(BuildUtil.part(pebbles, {
				Name = "Pebble",
				Size = Vector3.new(size, size * rng:NextNumber(0.4, 0.8), size * rng:NextNumber(0.7, 1.2)),
				CFrame = CFrame.new(px, groundY(px, pz) + size * 0.15, pz)
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4)),
				Material = Enum.Material.Slate,
				Color = PEBBLE_COLOR:Lerp(Color3.fromRGB(90, 86, 80), rng:NextNumber()),
			}))
		end
	end
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
			-- One placement seeds a small group: 1-4 more props of the same kind or a companion,
			-- tighter and with more size spread, so the wild reads as groves, rock fields and
			-- mushroom rings instead of one even sprinkle.
			local group = { { Prop = propId, X = x, Z = z, Scale = scale } }
			local companions = WildLayout.Companions[propId]
			for _ = 1, rng:NextInteger(1, 4) do
				local partner = if companions and rng:NextNumber() < 0.55
					then companions[rng:NextInteger(1, #companions)]
					else propId
				local angle = rng:NextNumber(0, math.pi * 2)
				local distance = rng:NextNumber(3, 6) + MapPropConfig.radius(partner)
				table.insert(group, {
					Prop = partner,
					X = x + math.cos(angle) * distance,
					Z = z + math.sin(angle) * distance,
					Scale = rng:NextNumber(SCATTER_SCALE.Min * 0.8, SCATTER_SCALE.Max * 1.25),
				})
			end
			for index, piece in group do
				if placed >= wanted then
					break
				end
				local px, pz = piece.X, piece.Z
				local pr = MapPropConfig.radius(piece.Prop) * piece.Scale
				if index > 1 then
					if
						not WorldLayout.inWild(world, px, pz, pr + 3)
						or WorldLayout.inStream(world, px, pz, pr + 3)
						or WildLayout.pathDistance(Config.Areas, px, pz) < PATH_WIDTH / 2 + pr + 2
						or ditheredArea(rng, px, pz) ~= area.Id
					then
						continue
					end
				end
				local blocked = false
				for _, box in boxes do
					if WorldLayout.distanceToBox(px, pz, box) < pr + 3 then
						blocked = true
						break
					end
				end
				if not blocked then
					for _, circle in nearby(hash, px, pz, pr + 12) do
						if (circle.X - px) ^ 2 + (circle.Z - pz) ^ 2 < ((circle.R + pr) * 0.85) ^ 2 then
							blocked = true
							break
						end
					end
				end
				if blocked then
					continue
				end
				local base = CFrame.new(px, groundY(px, pz), pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local model = MapProps.build(folder, piece.Prop, base, piece.Scale, rng)
				if model and PERCHES[piece.Prop] then
					model:SetAttribute("Scale", piece.Scale)
					CollectionService:AddTag(model, PERCH_TAG)
				end
				addCircle(hash, { X = px, Z = pz, R = pr })
				placed += 1
			end
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
		if model then
			CollectionService:AddTag(model, LANDMARK_TAG)
			if PERCHES[structure.Prop] then
				model:SetAttribute("Scale", 1)
				CollectionService:AddTag(model, PERCH_TAG)
			end
		end
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
		local bridge = MapProps.build(folder, "WoodenBridge", CFrame.lookAt(center, center + Vector3.new(ux, 0, uz)), 1, rng)
		if bridge then
			CollectionService:AddTag(bridge, LANDMARK_TAG)
		end
	end
	-- A torii where each path leaves the town.
	for _, area in Config.Areas do
		local x, z = WorldLayout.polar(area.AngleDegrees, world.WildInner - 10)
		MapProps.build(folder, "ShrineGate", CFrame.lookAt(Vector3.new(x, 0, z), Vector3.zero), 1, rng)
	end
end

-- A small cursed hokora on a stone base, bound by chains between four posts, with a sealed paper
-- charm and a dark aura. Clients light it up once they cleanse it (CursedShrines).
local SHRINE_STONE = Color3.fromRGB(58, 56, 62)
local SHRINE_WOOD = Color3.fromRGB(46, 32, 30)
local SHRINE_CHAIN = Color3.fromRGB(70, 66, 72)
local SHRINE_AURA = Color3.fromRGB(120, 60, 170)

local function buildShrine(folder: Instance, shrine: WildLayout.Shrine): Model
	local x, z = WildLayout.shrinePosition(shrine)
	local base = CFrame.lookAt(Vector3.new(x, groundY(x, z), z), Vector3.new(0, groundY(x, z), 0))
	local model = Instance.new("Model")
	model.Name = `CursedShrine_{shrine.Id}`
	local size = WildLayout.ShrineSize
	local slab = BuildUtil.part(model, {
		Name = "Base",
		Size = Vector3.new(size - 1, 1, size - 1),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = SHRINE_STONE,
		Material = Enum.Material.Slate,
	})
	BuildUtil.part(model, {
		Name = "Body",
		Size = Vector3.new(3.6, 3.4, 3.2),
		CFrame = base * CFrame.new(0, 2.7, 0),
		Color = SHRINE_WOOD,
		Material = Enum.Material.Wood,
	})
	for _, side in { -1, 1 } do
		BuildUtil.wedge(model, {
			Name = "Roof",
			Size = Vector3.new(4.8, 1.4, 2.4),
			CFrame = base * CFrame.new(0, 5.1, side * 1.2) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Color = SHRINE_STONE,
			Material = Enum.Material.Slate,
		})
	end
	local charm = BuildUtil.part(model, {
		Name = "Charm",
		Size = Vector3.new(1, 1.8, 0.06),
		CFrame = base * CFrame.new(0, 2.8, -1.64),
		Color = Color3.fromRGB(232, 222, 196),
		Material = Enum.Material.Fabric,
	})
	BuildUtil.decor(charm)
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "CharmMark",
		Size = Vector3.new(0.2, 1.3, 0.02),
		CFrame = charm.CFrame * CFrame.new(0, 0, -0.04),
		Color = Color3.fromRGB(170, 30, 30),
	}))
	local posts = {}
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local post = BuildUtil.part(model, {
			Name = "Post",
			Size = Vector3.new(0.8, 3.6, 0.8),
			CFrame = base * CFrame.new(corner[1] * 3.6, 2.8, corner[2] * 3.6),
			Color = SHRINE_STONE,
			Material = Enum.Material.Slate,
		})
		table.insert(posts, post)
	end
	-- Chains: two crossed spans over the hokora and a ring between the posts.
	local function chain(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Chain",
			Size = Vector3.new(0.25, 0.25, length),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = SHRINE_CHAIN,
			Material = Enum.Material.DiamondPlate,
		}))
	end
	for index, post in posts do
		local top = post.Position + Vector3.new(0, 1.4, 0)
		chain(top, posts[index % #posts + 1].Position + Vector3.new(0, 1.4, 0))
	end
	chain(posts[1].Position + Vector3.new(0, 1.6, 0), posts[3].Position + Vector3.new(0, 1.6, 0))
	chain(posts[2].Position + Vector3.new(0, 1.6, 0), posts[4].Position + Vector3.new(0, 1.6, 0))

	local aura = Instance.new("Attachment")
	aura.Name = "Aura"
	aura.Position = Vector3.new(0, 3, 0)
	aura.Parent = slab
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "CurseAura"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(SHRINE_AURA, Color3.fromRGB(20, 10, 30))
	smoke.Size = NumberSequence.new(2.5, 5)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 4
	smoke.Parent = aura
	local light = Instance.new("PointLight")
	light.Name = "CurseLight"
	light.Color = SHRINE_AURA
	light.Range = 14
	light.Brightness = 0.8
	light.Parent = aura

	model.PrimaryPart = slab
	model:SetAttribute("ShrineId", shrine.Id)
	model:SetAttribute("Area", shrine.Area)
	CollectionService:AddTag(model, SHRINE_TAG)
	CollectionService:AddTag(model, LANDMARK_TAG)
	model.Parent = folder
	return model
end

local function buildShrines(folder: Instance, hash: { [string]: { Circle } })
	for _, shrine in WildLayout.CursedShrines do
		buildShrine(folder, shrine)
		local x, z = WildLayout.shrinePosition(shrine)
		addCircle(hash, { X = x, Z = z, R = WildLayout.ShrineSize * 0.75 })
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

	local landmarkBoxes = WildLayout.boxes(MapPropConfig.Props)
	for _, box in WildLayout.shrineBoxes() do
		table.insert(landmarkBoxes, box)
	end
	local shape = WildTerrain.new({
		Areas = Config.Areas,
		World = Config.World,
		AreaAt = WorldLayout.areaAt,
		PathDistance = WildLayout.pathDistance,
		PathHalfWidth = WildLayout.PathHalfWidth,
		Clearings = landmarkBoxes,
	})

	fillGround(terrain, rng, Config.Areas[1].Seed, shape)
	buildPaths(terrain, folder)
	buildStream(terrain)
	buildRim(terrain, folder, rng)
	buildWalls(terrain, rng, shape)

	local hash: { [string]: { Circle } } = {}
	buildLandmarks(folder, rng, hash)
	buildShrines(folder, hash)
	local boxes = table.clone(landmarkBoxes)
	for _, box in WildLayout.wallBoxes() do
		table.insert(boxes, box)
	end
	local counts = scatter(folder, rng, boxes, hash)
	scatterPebbles(folder, rng)

	local function blocked(x: number, z: number, radius: number): boolean
		for _, box in boxes do
			if WorldLayout.distanceToBox(x, z, box) < radius then
				return true
			end
		end
		for _, circle in nearby(hash, x, z, radius + 12) do
			if (circle.X - x) ^ 2 + (circle.Z - z) ^ 2 < (circle.R + radius) ^ 2 then
				return true
			end
		end
		return false
	end
	local perches = {}
	for _, model in folder:GetDescendants() do
		if model:IsA("Model") and CollectionService:HasTag(model, PERCH_TAG) then
			table.insert(perches, model)
		end
	end
	WildDressing.build({
		Folder = folder,
		Rng = rng,
		GroundY = groundY,
		Blocked = blocked,
		Claim = function(x: number, z: number, radius: number)
			addCircle(hash, { X = x, Z = z, R = radius })
		end,
		Perches = perches,
	})

	local spawns = {}
	for _, point in WorldLayout.spawnGrid(Config.Areas, Config.World, boxes) do
		local height = shape.heightAt(point.X, point.Z)
		local clear = height >= -WildLayout.MaxSpawnDepth
		for _, circle in nearby(hash, point.X, point.Z, 24) do
			if not clear then
				break
			end
			if (circle.X - point.X) ^ 2 + (circle.Z - point.Z) ^ 2 < (circle.R + 2) ^ 2 then
				clear = false
			end
		end
		if clear then
			table.insert(spawns, { Position = Vector3.new(point.X, height, point.Z), Area = point.Area })
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
