-- World layout math (GDD 4.1), shared by the map builders, SignalService and the Lune tests.
-- Pure: positions are plain (x, z) numbers on the ground plane. A district's local frame matches
-- CFrame.lookAt(center, hub): local -Z points at the hub, local +X is its right-hand side.

local WorldLayout = {}

export type District = { Id: string, Name: string, AngleDegrees: number, Seed: number }
export type World = { DistrictRadius: number, DistrictSize: number }
-- A rectangle in some local frame: center (X, Z), size W (along X) by D (along Z), Rot degrees about Y.
export type Box = { X: number, Z: number, W: number, D: number, Rot: number? }

local function angle(degrees: number): (number, number)
	local radians = math.rad(degrees)
	return math.cos(radians), math.sin(radians)
end

function WorldLayout.districtCenter(district: District, world: World): (number, number)
	local c, s = angle(district.AngleDegrees)
	return c * world.DistrictRadius, s * world.DistrictRadius
end

-- District-local (x, z) -> world (x, z).
function WorldLayout.toWorld(district: District, world: World, x: number, z: number): (number, number)
	local c, s = angle(district.AngleDegrees)
	local cx, cz = c * world.DistrictRadius, s * world.DistrictRadius
	return cx + s * x + c * z, cz - c * x + s * z
end

-- World (x, z) -> district-local (x, z).
function WorldLayout.toLocal(district: District, world: World, x: number, z: number): (number, number)
	local c, s = angle(district.AngleDegrees)
	local dx, dz = x - c * world.DistrictRadius, z - s * world.DistrictRadius
	return s * dx - c * dz, c * dx + s * dz
end

-- The district containing world (x, z) (its square grown by `margin` studs), or nil.
function WorldLayout.districtAt(districts: { District }, world: World, x: number, z: number, margin: number?): string?
	local half = world.DistrictSize / 2 + (margin or 0)
	for _, district in districts do
		local lx, lz = WorldLayout.toLocal(district, world, x, z)
		if math.abs(lx) <= half and math.abs(lz) <= half then
			return district.Id
		end
	end
	return nil
end

-- The district whose center is closest to world (x, z).
function WorldLayout.nearestDistrict(districts: { District }, world: World, x: number, z: number): string
	local best, bestDistance = districts[1].Id, math.huge
	for _, district in districts do
		local cx, cz = WorldLayout.districtCenter(district, world)
		local distance = (cx - x) ^ 2 + (cz - z) ^ 2
		if distance < bestDistance then
			best, bestDistance = district.Id, distance
		end
	end
	return best
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

return WorldLayout
