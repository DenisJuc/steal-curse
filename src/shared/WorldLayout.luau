-- World layout math (GDD 4.1, Slice 11), shared by the map builders, SignalService, the client
-- ambience and the Lune tests. Pure: positions are plain (x, z) numbers on the ground plane.
-- Angles are degrees measured like the plot ring: (cos a, sin a) * radius.
-- The wild ring (WildInner..WildOuter) is split into areas by angle; each area owns the slice of
-- the ring closest to its AngleDegrees, and near a border it blends with its neighbour.

local WorldLayout = {}

export type Area = { Id: string, Name: string, AngleDegrees: number, Seed: number }
export type World = {
	WildInner: number,
	WildOuter: number,
	BlendDegrees: number,
	SpawnSpacing: number,
	SpawnEdgeMargin: number,
	SpawnClearance: number,
	StreamRadius: number,
	StreamWidth: number,
}
-- A rectangle: center (X, Z), size W (along X) by D (along Z), Rot degrees about Y.
export type Box = { X: number, Z: number, W: number, D: number, Rot: number? }
export type Spawn = { X: number, Z: number, Area: string }

function WorldLayout.polar(angleDegrees: number, radius: number): (number, number)
	local radians = math.rad(angleDegrees)
	return math.cos(radians) * radius, math.sin(radians) * radius
end

-- Angle of (x, z) in [0, 360).
function WorldLayout.angleOf(x: number, z: number): number
	return math.deg(math.atan2(z, x)) % 360
end

-- Signed smallest difference a - b in (-180, 180].
local function angleDelta(a: number, b: number): number
	local delta = (a - b) % 360
	return if delta > 180 then delta - 360 else delta
end

function WorldLayout.inWild(world: World, x: number, z: number, margin: number?): boolean
	local r = math.sqrt(x * x + z * z)
	local m = margin or 0
	return r >= world.WildInner + m and r <= world.WildOuter - m
end

-- The area owning (x, z) by angle, its blend weight (1 deep inside, 0.5 right on a border) and,
-- inside a blend zone, the neighbouring area it mixes with.
function WorldLayout.areaAt(areas: { Area }, world: World, x: number, z: number): (string, number, string?)
	local angle = WorldLayout.angleOf(x, z)
	local best, second = nil, nil
	local bestDelta, secondDelta = math.huge, math.huge
	for _, area in areas do
		local delta = math.abs(angleDelta(angle, area.AngleDegrees))
		if delta < bestDelta then
			second, secondDelta = best, bestDelta
			best, bestDelta = area, delta
		elseif delta < secondDelta then
			second, secondDelta = area, delta
		end
	end
	assert(best, "no areas")
	if not second then
		return best.Id, 1, nil
	end
	local toBorder = (secondDelta - bestDelta) / 2
	local halfBlend = world.BlendDegrees / 2
	if toBorder >= halfBlend then
		return best.Id, 1, nil
	end
	return best.Id, 0.5 + 0.5 * toBorder / halfBlend, second.Id
end

-- A point in the middle of an area, on its path halfway between the town and the stream.
function WorldLayout.areaCenter(area: Area, world: World): (number, number)
	return WorldLayout.polar(area.AngleDegrees, (world.WildInner + world.StreamRadius) / 2)
end

-- Point `depth` studs inside the ring, straight out from (x, z) (east when at the very center).
function WorldLayout.wildEntry(world: World, x: number, z: number, depth: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	local ux, uz = 1, 0
	if r > 1e-6 then
		ux, uz = x / r, z / r
	end
	local target = math.clamp(r, world.WildInner + depth, world.WildOuter - depth)
	return ux * target, uz * target
end

function WorldLayout.inStream(world: World, x: number, z: number, margin: number): boolean
	local r = math.sqrt(x * x + z * z)
	return math.abs(r - world.StreamRadius) <= world.StreamWidth / 2 + margin
end

-- Center of plot `index` on the plot ring (same placement as MapBuilder).
function WorldLayout.plotPosition(plots: { Count: number, RingRadius: number }, index: number): (number, number)
	local radians = (index - 1) / plots.Count * math.pi * 2
	return math.cos(radians) * plots.RingRadius, math.sin(radians) * plots.RingRadius
end

-- Distance from (x, z) to a box in the same frame (0 inside). Rot follows CFrame.Angles(0, rot, 0).
function WorldLayout.distanceToBox(x: number, z: number, box: Box): number
	local radians = math.rad(box.Rot or 0)
	local c, s = math.cos(radians), math.sin(radians)
	local dx, dz = x - box.X, z - box.Z
	local u = dx * c - dz * s
	local v = dx * s + dz * c
	local outU = math.max(0, math.abs(u) - box.W / 2)
	local outV = math.max(0, math.abs(v) - box.D / 2)
	return math.sqrt(outU * outU + outV * outV)
end

-- Signal spawn points: a square grid over the wild ring, kept SpawnEdgeMargin from the ring edges,
-- out of the stream and SpawnClearance from every box in `blocked` (landmark footprints).
function WorldLayout.spawnGrid(areas: { Area }, world: World, blocked: { Box }): { Spawn }
	local points = {}
	local spacing = world.SpawnSpacing
	local limit = math.ceil(world.WildOuter / spacing)
	for i = -limit, limit do
		for j = -limit, limit do
			local x, z = i * spacing, j * spacing
			if not WorldLayout.inWild(world, x, z, world.SpawnEdgeMargin) then
				continue
			end
			if WorldLayout.inStream(world, x, z, world.SpawnClearance) then
				continue
			end
			local clear = true
			for _, box in blocked do
				if WorldLayout.distanceToBox(x, z, box) < world.SpawnClearance then
					clear = false
					break
				end
			end
			if clear then
				table.insert(points, { X = x, Z = z, Area = (WorldLayout.areaAt(areas, world, x, z)) })
			end
		end
	end
	return points
end

return WorldLayout
