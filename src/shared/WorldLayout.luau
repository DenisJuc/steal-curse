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

-- Shrine Street (Config.Plots.Street): a straight avenue through the town. Street coordinates are
-- (along, across): along runs from the map center toward the wild gate, across is perpendicular.
export type Street = {
	AngleDegrees: number,
	HalfWidth: number,
	HubAt: number,
	FirstPlotAt: number,
	PlotSpacing: number,
	RowOffset: number,
	LanternSpacing: number,
	LanternLight: { Range: number, Brightness: number },
	Lane: { Multiplier: number },
	Bends: { [string]: { { number } } },
}
export type Plots = { Count: number, Size: number, Street: Street }

-- Unit vectors (x, z) of the street's along and across directions.
function WorldLayout.streetAxes(street: Street): (number, number, number, number)
	local dx, dz = WorldLayout.polar(street.AngleDegrees, 1)
	return dx, dz, -dz, dx
end

-- World (x, z) of street coordinates (along, across).
function WorldLayout.fromStreet(street: Street, along: number, across: number): (number, number)
	local dx, dz, nx, nz = WorldLayout.streetAxes(street)
	return dx * along + nx * across, dz * along + nz * across
end

-- Street coordinates (along, across) of world (x, z).
function WorldLayout.toStreet(street: Street, x: number, z: number): (number, number)
	local dx, dz, nx, nz = WorldLayout.streetAxes(street)
	return x * dx + z * dz, x * nx + z * nz
end

-- Street coordinates of plot `index`: pairs face each other across the street, 1 and 2 by the hub.
function WorldLayout.plotStreet(plots: Plots, index: number): (number, number, number)
	local street = plots.Street
	local side = if index % 2 == 1 then 1 else -1
	local along = street.FirstPlotAt + (math.ceil(index / 2) - 1) * street.PlotSpacing
	return along, side * street.RowOffset, side
end

-- Center of plot `index` (same placement as MapBuilder).
function WorldLayout.plotPosition(plots: Plots, index: number): (number, number)
	local along, across = WorldLayout.plotStreet(plots, index)
	return WorldLayout.fromStreet(plots.Street, along, across)
end

-- Unit (x, z) a plot's entrance faces: straight across to the street.
function WorldLayout.plotFacing(plots: Plots, index: number): (number, number)
	local _, _, side = WorldLayout.plotStreet(plots, index)
	local _, _, nx, nz = WorldLayout.streetAxes(plots.Street)
	return -nx * side, -nz * side
end

-- A plot's footprint as a Box (squares, so the street angle is all the rotation needed).
function WorldLayout.plotBox(plots: Plots, index: number): Box
	local x, z = WorldLayout.plotPosition(plots, index)
	return { X = x, Z = z, W = plots.Size, D = plots.Size, Rot = -plots.Street.AngleDegrees }
end

-- Hub plaza center (x, z) at the street's near end.
function WorldLayout.hubPosition(plots: Plots): (number, number)
	return WorldLayout.fromStreet(plots.Street, plots.Street.HubAt, 0)
end

-- Hub plaza center plus the unit (x, z) of its -Z: hub space -Z points down the street.
function WorldLayout.hubFrame(plots: Plots): (number, number, number, number)
	local x, z = WorldLayout.hubPosition(plots)
	local dx, dz = WorldLayout.streetAxes(plots.Street)
	return x, z, dx, dz
end

-- World (x, z) of hub-space offset {x, z} (hub -Z points down the street, like a CFrame.lookAt).
function WorldLayout.fromHub(plots: Plots, hx: number, hz: number): (number, number)
	local cx, cz, fx, fz = WorldLayout.hubFrame(plots)
	-- lookAt frame: LookVector = (fx, fz) = -Z, RightVector = (-fz, fx) = +X.
	local rx, rz = -fz, fx
	return cx + rx * hx - fx * hz, cz + rz * hx - fz * hz
end

-- Where the street meets the wild (`depth` studs past WildInner, on the street's center line).
function WorldLayout.streetGate(plots: Plots, world: World, depth: number): (number, number)
	return WorldLayout.fromStreet(plots.Street, world.WildInner + depth, 0)
end

-- The plaza rectangle as a Box (W along the street, D across it), centered on the hub.
function WorldLayout.plazaBox(plots: Plots, plazaSize: { number }): Box
	local x, z = WorldLayout.hubPosition(plots)
	return { X = x, Z = z, W = plazaSize[2], D = plazaSize[1], Rot = -plots.Street.AngleDegrees }
end

-- Along-street distance where the street leaves the plaza (its front edge).
function WorldLayout.streetStart(plots: Plots, plazaSize: { number }): number
	return plots.Street.HubAt + plazaSize[2] / 2
end

-- True on the paved street between the plaza and the wild gate (the Spirit Lane).
function WorldLayout.onStreet(plots: Plots, world: World, plazaSize: { number }, x: number, z: number): boolean
	local street = plots.Street
	local along, across = WorldLayout.toStreet(street, x, z)
	return math.abs(across) <= street.HalfWidth
		and along >= WorldLayout.streetStart(plots, plazaSize)
		and along <= world.WildInner
end

-- Town paths as polylines of world (x, z) points, one per area: the street itself for the area it
-- points at, otherwise plaza edge -> optional bends -> where that area's wild path starts.
function WorldLayout.townPaths(plots: Plots, world: World, areas: { Area }, plazaSize: { number }): { [string]: { { number } } }
	local street = plots.Street
	local paths = {}
	for _, area in areas do
		local delta = math.abs(angleDelta(area.AngleDegrees, street.AngleDegrees))
		local points = {}
		if delta < 1e-6 then
			table.insert(points, { WorldLayout.fromStreet(street, WorldLayout.streetStart(plots, plazaSize), 0) })
			table.insert(points, { WorldLayout.fromStreet(street, world.WildInner, 0) })
		else
			local ex, ez = WorldLayout.polar(area.AngleDegrees, world.WildInner)
			local bends = street.Bends[area.Id] or {}
			local first = if #bends > 0 then { WorldLayout.fromStreet(street, bends[1][1], bends[1][2]) } else { ex, ez }
			-- Leave the plaza through its edge, heading for the first point.
			local hubAlong = street.HubAt
			local fa, fc = WorldLayout.toStreet(street, first[1], first[2])
			local da, dc = fa - hubAlong, fc
			local length = math.sqrt(da * da + dc * dc)
			da, dc = da / length, dc / length
			local t = math.min(
				if math.abs(da) > 1e-9 then plazaSize[2] / 2 / math.abs(da) else math.huge,
				if math.abs(dc) > 1e-9 then plazaSize[1] / 2 / math.abs(dc) else math.huge
			)
			table.insert(points, { WorldLayout.fromStreet(street, hubAlong + da * t, dc * t) })
			for _, bend in bends do
				table.insert(points, { WorldLayout.fromStreet(street, bend[1], bend[2]) })
			end
			table.insert(points, { ex, ez })
		end
		paths[area.Id] = points
	end
	return paths
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
