-- Ground height of the wild ring (pure, Lune-tested; no requires: the layout functions are passed
-- in). Every area has its own relief on top of rolling hills:
--   Haunted Forest:    hills, ravines winding through, root mounds.
--   Abandoned Village: stepped terraces, sunken pits.
--   Ancient Ruins:     raised plateaus with cliff edges, craters.
-- Blend zones mix both neighbours by WorldLayout.areaAt weight. The ground is flat (height 0) in
-- the town, at the ring's inner edge, along the paths, on the stream banks and in a clearing
-- around every landmark; it eases into the relief over FADE studs.

local WildTerrain = {}

export type Box = { X: number, Z: number, W: number, D: number, Rot: number? }
export type Options = {
	Areas: { { Id: string, AngleDegrees: number, Seed: number } },
	World: { WildInner: number, StreamRadius: number, StreamWidth: number },
	AreaAt: (areas: any, world: any, x: number, z: number) -> (string, number, string?),
	PathDistance: (areas: any, x: number, z: number) -> number,
	PathHalfWidth: number,
	-- Landmark footprints (WildLayout.boxes): flat clearings around them.
	Clearings: { Box },
}
export type Shape = { heightAt: (x: number, z: number) -> number }

-- Studs over which flat zones ease into the relief.
local FADE = 16
-- Extra flat studs around paths, stream banks and landmarks.
local PATH_MARGIN = 3
local BANK_MARGIN = 6
local CLEARING_MARGIN = 5

local noise = math.noise

local function smooth(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

local function forest(x: number, z: number, seed: number): number
	local hills = 9 * noise(x / 90, z / 90, seed) + 2.5 * noise(x / 30, z / 30, seed + 3)
	local winding = math.abs(noise(x / 140, z / 140, seed + 7))
	local ravine = -11 * smooth(1 - winding / 0.08)
	local mounds = 5 * smooth((noise(x / 22, z / 22, seed + 11) - 0.2) / 0.3)
	return hills + ravine + mounds
end

local function village(x: number, z: number, seed: number): number
	local step = 4
	local level = 14 * noise(x / 110, z / 110, seed) / step
	local floor = math.floor(level)
	local terraces = (floor + smooth((level - floor - 0.55) / 0.45)) * step
	local hills = 2 * noise(x / 30, z / 30, seed + 3)
	local pits = -8 * smooth((noise(x / 45, z / 45, seed + 13) - 0.25) / 0.25)
	return terraces + hills + pits
end

local function ruins(x: number, z: number, seed: number): number
	local hills = 7 * noise(x / 80, z / 80, seed)
	local plateau = 16 * smooth((noise(x / 120, z / 120, seed + 17) - 0.15) / 0.05)
	local craters = -9 * smooth((noise(x / 50, z / 50, seed + 19) - 0.25) / 0.25)
	return hills + plateau + craters
end

local RELIEF: { [string]: (number, number, number) -> number } = {
	HauntedForest = forest,
	AbandonedVillage = village,
	AncientRuins = ruins,
}

function WildTerrain.new(options: Options): Shape
	local world = options.World
	local seeds: { [string]: number } = {}
	for _, area in options.Areas do
		seeds[area.Id] = area.Seed
	end
	-- Clearings as circles around each footprint.
	local clearings: { { X: number, Z: number, R: number } } = {}
	for _, box in options.Clearings do
		table.insert(clearings, { X = box.X, Z = box.Z, R = math.sqrt(box.W * box.W + box.D * box.D) / 2 + CLEARING_MARGIN })
	end

	local function relief(id: string, x: number, z: number): number
		local shape = RELIEF[id]
		return if shape then shape(x, z, seeds[id] or 0) else 0
	end

	-- 0 on flat ground (town edge, paths, stream banks, clearings), 1 where the relief is full.
	local function mask(x: number, z: number, r: number): number
		local value = smooth((r - world.WildInner) / (FADE * 2.5))
		if value <= 0 then
			return 0
		end
		local path = options.PathDistance(options.Areas, x, z) - options.PathHalfWidth - PATH_MARGIN
		value *= smooth(path / FADE)
		local bank = math.abs(r - world.StreamRadius) - world.StreamWidth / 2 - BANK_MARGIN
		value *= smooth(bank / FADE)
		if value <= 0 then
			return 0
		end
		for _, clearing in clearings do
			local dx, dz = x - clearing.X, z - clearing.Z
			if math.abs(dx) < clearing.R + FADE and math.abs(dz) < clearing.R + FADE then
				value *= smooth((math.sqrt(dx * dx + dz * dz) - clearing.R) / FADE)
				if value <= 0 then
					return 0
				end
			end
		end
		return value
	end

	local function heightAt(x: number, z: number): number
		local r = math.sqrt(x * x + z * z)
		if r <= world.WildInner then
			return 0
		end
		local flat = mask(x, z, r)
		if flat <= 0 then
			return 0
		end
		local id, weight, other = options.AreaAt(options.Areas, world, x, z)
		local height = relief(id, x, z) * weight
		if other then
			height += relief(other, x, z) * (1 - weight)
		end
		return height * flat
	end

	return { heightAt = heightAt }
end

return WildTerrain
