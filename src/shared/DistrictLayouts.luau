-- Hand-placed content of each hunting district in district-local studs (WorldLayout frame: -Z faces
-- the hub, the entrance gate is at z = -DistrictSize/2). Pure data so Lune can check that every
-- signal spawn point is inside the district, clear of structures and spread out.
--   Spawns:   signal spawn points {x, z}, placed behind structures (line-of-sight breaks).
--   Blockers: big structures {X, Z, W, D, Rot, H, Kind}; the district builder turns each Kind
--             into a themed model of that footprint. Trees, lamps and rubble are added around them.

local DistrictLayouts = {}

export type Blocker = { X: number, Z: number, W: number, D: number, Rot: number, H: number, Kind: string }
export type Layout = { Spawns: { { number } }, Blockers: { Blocker } }

local function blocker(x: number, z: number, w: number, d: number, rot: number, h: number, kind: string): Blocker
	return { X = x, Z = z, W = w, D = d, Rot = rot, H = h, Kind = kind }
end

-- Signals never spawn in the entrance lane: |x| < half width, within this distance of the gate.
DistrictLayouts.EntranceLane = { HalfWidth = 10, Depth = 25 }

DistrictLayouts.ById = {
	HauntedForest = {
		Spawns = {
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
		},
		Blockers = {
			blocker(-30, -40, 18, 2, 10, 7, "Wall"),
			blocker(28, -35, 16, 2, -20, 9, "Wall"),
			blocker(-50, 10, 20, 2, 75, 6, "Wall"),
			blocker(30, 15, 14, 2, 40, 8, "Wall"),
			blocker(-5, 45, 22, 2, -5, 7, "Wall"),
			blocker(58, 20, 12, 2, 90, 10, "Wall"),
		},
	},
	AbandonedVillage = {
		Spawns = {
			{ -12, -62 },
			{ 14, -40 },
			{ -50, -34 },
			{ 52, -62 },
			{ -15, -5 },
			{ 16, -5 },
			{ 64, 0 },
			{ -64, 5 },
			{ -35, 40 },
			{ 0, 35 },
			{ 42, 40 },
			{ 65, 64 },
			{ -60, 66 },
			{ 4, 72 },
			{ -40, -74 },
		},
		Blockers = {
			blocker(-30, -55, 16, 12, 0, 12, "House"),
			blocker(30, -55, 16, 12, 0, 13, "House"),
			blocker(-34, -20, 14, 16, 0, 11, "House"),
			blocker(34, -22, 18, 12, 0, 12, "House"),
			blocker(-55, 25, 16, 14, 15, 12, "House"),
			blocker(50, 20, 14, 14, -10, 14, "House"),
			blocker(-20, 55, 18, 12, 0, 12, "House"),
			blocker(25, 55, 16, 14, 5, 11, "House"),
			blocker(-64, -50, 12, 12, 0, 10, "House"),
			blocker(64, -42, 12, 14, 0, 10, "House"),
			blocker(0, 10, 6, 6, 0, 4, "Well"),
		},
	},
	AncientRuins = {
		Spawns = {
			{ -15, -66 },
			{ 20, -55 },
			{ -60, -30 },
			{ -30, -25 },
			{ 60, -50 },
			{ 35, -10 },
			{ -40, 0 },
			{ 70, 0 },
			{ -70, 40 },
			{ -35, 30 },
			{ 40, 40 },
			{ 0, 45 },
			{ -45, 70 },
			{ 10, 75 },
			{ 60, 75 },
		},
		Blockers = {
			blocker(0, 10, 22, 22, 45, 3, "Altar"),
			blocker(-40, -40, 24, 3, 0, 12, "Wall"),
			blocker(40, -35, 20, 3, 30, 10, "Wall"),
			blocker(-55, 15, 3, 26, 0, 11, "Wall"),
			blocker(55, 20, 3, 22, 0, 13, "Wall"),
			blocker(-20, 55, 26, 3, 0, 12, "Wall"),
			blocker(30, 60, 20, 3, -20, 9, "Wall"),
			blocker(-20, -15, 3, 3, 0, 16, "Column"),
			blocker(20, -15, 3, 3, 0, 9, "Column"),
			blocker(-20, 35, 3, 3, 0, 12, "Column"),
			blocker(20, 35, 3, 3, 0, 16, "Column"),
			blocker(-65, -65, 3, 3, 0, 14, "Column"),
			blocker(65, -62, 3, 3, 0, 8, "Column"),
			blocker(-65, 58, 3, 3, 0, 16, "Column"),
			blocker(70, 62, 3, 3, 0, 11, "Column"),
			blocker(-2, -45, 14, 3, 70, 3, "Fallen"),
			blocker(52, -6, 12, 3, 15, 3, "Fallen"),
		},
	},
} :: { [string]: Layout }

return DistrictLayouts
