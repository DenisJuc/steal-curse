-- Hand-placed landmarks and scatter rules of the wild ring (Slice 11). Pure data so Lune can check
-- that landmarks stay inside the ring, off the paths and the stream, and apart from each other.
--   Paths:      one straight path per area from the town out to the edge, at the area's angle.
--   Structures: landmarks at (Angle degrees, Radius studs). Twist turns them away from facing
--               the hub. Their footprint comes from MapPropConfig and stays clear of signals.
--   Bridges:    angles where a WoodenBridge crosses the stream.
--   Scatter:    per area, props per 10,000 square studs; placed randomly by the WildBuilder (blend
--               zones mix both neighbours' lists).
-- No requires (Lune loads it directly): footprints take MapPropConfig.Props as an argument.

local WildLayout = {}

export type Structure = { Prop: string, Angle: number, Radius: number, Twist: number }
export type ScatterRule = { Prop: string, Density: number }
export type Box = { X: number, Z: number, W: number, D: number, Rot: number? }
type Props = { [string]: { Size: { number } } }

local function at(prop: string, angle: number, radius: number, twist: number?): Structure
	return { Prop = prop, Angle = angle, Radius = radius, Twist = twist or 0 }
end

-- Half width of the path lane kept free of landmarks.
WildLayout.PathHalfWidth = 9

-- stylua: ignore
WildLayout.Structures = {
	-- Haunted Forest (around 22.5 degrees)
	at("AncientTree", 44.5, 507),
	at("JizoStatue", 12.5, 237, 10),
	at("JizoStatue", 36.5, 303, -15),
	at("JizoStatue", 0.5, 466, 30),
	at("JizoStatue", 62.5, 262),
	at("GlowMushrooms", 28.5, 573),
	at("AncientTree", 0.5, 565),
	at("JizoStatue", 48.5, 590, -10),
	at("JizoStatue", 70.5, 520),
	at("GlowMushrooms", 8.5, 380),
	-- Abandoned Village (around 157.5 degrees)
	at("BellTower", 169.5, 297),
	at("RuinedHouse", 139.5, 262, 8),
	at("RuinedHouse", 146.5, 339, -10),
	at("RuinedHouse", 177.5, 251, 5),
	at("RuinedHouse", 173.5, 348, 12),
	at("RuinedHouse", 140.5, 489, -6),
	at("RuinedHouse", 177.5, 507, 10),
	at("RuinedHut", 127.5, 309, 20),
	at("RuinedHut", 187.5, 315, -20),
	at("RuinedHut", 131.5, 554, 15),
	at("RuinedHut", 185.5, 446, -12),
	at("OldWell", 151.5, 466),
	at("BrokenCart", 165.5, 223, 40),
	at("CrateBarrelPile", 135.5, 215, 15),
	at("RuinedHouse", 150.5, 590, -8),
	at("RuinedHut", 168.5, 580, 10),
	at("OldWell", 162.5, 520),
	at("BellTower", 200.5, 540),
	-- Ancient Ruins (around 292.5 degrees)
	at("GuardianStatueHead", 309.5, 297, -20),
	at("RuinArch", 276.5, 284),
	at("RuinArch", 313.5, 477, 20),
	at("RuinArch", 282.5, 573, -10),
	at("RuneObelisk", 270.5, 376),
	at("RuneObelisk", 318.5, 536),
	at("RuneObelisk", 263.5, 507),
	at("RuneObelisk", 298.5, 452),
	at("GuardianStatueHead", 268.5, 590, 15),
	at("RuinArch", 252.5, 450, 25),
	at("RuneObelisk", 330.5, 590),
	at("RuneObelisk", 300.5, 345),
	-- Signposts beside each path where the wild begins.
	at("Signpost", 27.5, 203),
	at("Signpost", 162.5, 203),
	at("Signpost", 297.5, 203),
}

-- Cursed Shrines (Lift the Curse): 5 per area at (Angle degrees, Radius studs), mostly deep in.
-- Each keeps a flat Shrine-sized clearing like a landmark.
export type Shrine = { Id: string, Area: string, Angle: number, Radius: number }

WildLayout.ShrineSize = 10

-- stylua: ignore
WildLayout.CursedShrines = {
	{ Id = "Forest1", Area = "HauntedForest", Angle = 5, Radius = 290 },
	{ Id = "Forest2", Area = "HauntedForest", Angle = 68, Radius = 365 },
	{ Id = "Forest3", Area = "HauntedForest", Angle = -5, Radius = 453 },
	{ Id = "Forest4", Area = "HauntedForest", Angle = 15, Radius = 535 },
	{ Id = "Forest5", Area = "HauntedForest", Angle = 58, Radius = 560 },
	{ Id = "Village1", Area = "AbandonedVillage", Angle = 110, Radius = 280 },
	{ Id = "Village2", Area = "AbandonedVillage", Angle = 205, Radius = 370 },
	{ Id = "Village3", Area = "AbandonedVillage", Angle = 120, Radius = 450 },
	{ Id = "Village4", Area = "AbandonedVillage", Angle = 190, Radius = 575 },
	{ Id = "Village5", Area = "AbandonedVillage", Angle = 108, Radius = 580 },
	{ Id = "Ruins1", Area = "AncientRuins", Angle = 245, Radius = 270 },
	{ Id = "Ruins2", Area = "AncientRuins", Angle = 322, Radius = 370 },
	{ Id = "Ruins3", Area = "AncientRuins", Angle = 240, Radius = 470 },
	{ Id = "Ruins4", Area = "AncientRuins", Angle = 286, Radius = 540 },
	{ Id = "Ruins5", Area = "AncientRuins", Angle = 315, Radius = 585 },
} :: { Shrine }

WildLayout.ShrineById = {} :: { [string]: Shrine }
for _, shrine in WildLayout.CursedShrines do
	WildLayout.ShrineById[shrine.Id] = shrine
end

function WildLayout.shrinePosition(shrine: Shrine): (number, number)
	local radians = math.rad(shrine.Angle)
	return math.cos(radians) * shrine.Radius, math.sin(radians) * shrine.Radius
end

-- Ground footprint of every shrine (flattened and kept clear like landmarks).
function WildLayout.shrineBoxes(): { Box }
	local boxes = {}
	for _, shrine in WildLayout.CursedShrines do
		local x, z = WildLayout.shrinePosition(shrine)
		local size = WildLayout.ShrineSize
		table.insert(boxes, { X = x, Z = z, W = size, D = size, Rot = WildLayout.faceHubRot(shrine.Angle) })
	end
	return boxes
end

-- Area angles and the borders between them.
WildLayout.BridgeAngles = { 22.5, 90, 157.5, 225, 292.5, 337.5 }

-- stylua: ignore
WildLayout.Scatter = {
	HauntedForest = {
		{ Prop = "DeadTree1", Density = 4.4 },
		{ Prop = "DeadTree2", Density = 3.3 },
		{ Prop = "MossyRocks", Density = 1.6 },
		{ Prop = "GlowMushrooms", Density = 2.2 },
		{ Prop = "FernBush", Density = 3.1 },
		{ Prop = "FallenLog", Density = 0.8 },
	},
	AbandonedVillage = {
		{ Prop = "FernBush", Density = 1.6 },
		{ Prop = "CrateBarrelPile", Density = 0.65 },
		{ Prop = "MossyRocks", Density = 0.5 },
		{ Prop = "DeadTree2", Density = 0.65 },
		{ Prop = "FallenLog", Density = 0.3 },
	},
	AncientRuins = {
		{ Prop = "BrokenPillar1", Density = 1.3 },
		{ Prop = "BrokenPillar2", Density = 1.6 },
		{ Prop = "MossyRocks", Density = 1.6 },
		{ Prop = "FernBush", Density = 0.8 },
	},
} :: { [string]: { ScatterRule } }

-- Rock walls: arcs around the hub from Angle0 to Angle1 (degrees) at Radius. Open arcs only, never
-- across a path, a bridge or the stream, so they steer you without boxing anyone in. Material is
-- an Enum.Material name.
export type Wall = {
	Angle0: number,
	Angle1: number,
	Radius: number,
	Height: number,
	Thickness: number,
	Material: string,
}

-- stylua: ignore
WildLayout.Walls = {
	-- Haunted Forest: mossy rock ridges
	{ Angle0 = 32, Angle1 = 52, Radius = 360, Height = 12, Thickness = 7, Material = "Rock" },
	{ Angle0 = -25, Angle1 = -2, Radius = 520, Height = 14, Thickness = 7, Material = "Rock" },
	{ Angle0 = 55, Angle1 = 78, Radius = 440, Height = 11, Thickness = 7, Material = "Rock" },
	-- Abandoned Village: low old stone walls
	{ Angle0 = 118, Angle1 = 136, Radius = 370, Height = 7, Thickness = 5, Material = "Cobblestone" },
	{ Angle0 = 166, Angle1 = 182, Radius = 470, Height = 7, Thickness = 5, Material = "Cobblestone" },
	{ Angle0 = 110, Angle1 = 126, Radius = 520, Height = 7, Thickness = 5, Material = "Cobblestone" },
	-- Ancient Ruins: tall broken fortress walls
	{ Angle0 = 250, Angle1 = 280, Radius = 330, Height = 18, Thickness = 7, Material = "Basalt" },
	{ Angle0 = 300, Angle1 = 325, Radius = 520, Height = 18, Thickness = 7, Material = "Basalt" },
	{ Angle0 = 235, Angle1 = 258, Radius = 560, Height = 16, Thickness = 7, Material = "Basalt" },
} :: { Wall }

-- Studs along a wall per built segment (and per footprint box).
WildLayout.WallSegment = 6

-- Signal spawn points deeper than this below the flat ground (pits, ravines, their puddles) are
-- dropped.
WildLayout.MaxSpawnDepth = 4.5

-- Rot (degrees, CFrame.Angles(0, rot, 0)) that makes local -Z face the hub from `angle`.
function WildLayout.faceHubRot(angle: number): number
	return 90 - angle
end

function WildLayout.position(structure: Structure): (number, number)
	local radians = math.rad(structure.Angle)
	return math.cos(radians) * structure.Radius, math.sin(radians) * structure.Radius
end

-- Ground footprint of a landmark as a WorldLayout box (`props` = MapPropConfig.Props).
function WildLayout.box(structure: Structure, props: Props): Box
	local x, z = WildLayout.position(structure)
	local size = props[structure.Prop].Size
	return { X = x, Z = z, W = size[1], D = size[3], Rot = WildLayout.faceHubRot(structure.Angle) + structure.Twist }
end

function WildLayout.boxes(props: Props): { Box }
	local boxes = {}
	for _, structure in WildLayout.Structures do
		table.insert(boxes, WildLayout.box(structure, props))
	end
	return boxes
end

-- Centers (angle degrees) of the segments a wall is built from.
function WildLayout.wallAngles(wall: Wall): { number }
	local span = wall.Angle1 - wall.Angle0
	local count = math.max(1, math.ceil(math.rad(span) * wall.Radius / WildLayout.WallSegment))
	local angles = {}
	for index = 1, count do
		table.insert(angles, wall.Angle0 + (index - 0.5) * span / count)
	end
	return angles
end

-- Ground footprint of every wall segment (keeps props and signal spawns off the walls).
function WildLayout.wallBoxes(): { Box }
	local boxes = {}
	for _, wall in WildLayout.Walls do
		local angles = WildLayout.wallAngles(wall)
		local length = math.rad(wall.Angle1 - wall.Angle0) * wall.Radius / #angles + 1
		for _, angle in angles do
			local radians = math.rad(angle)
			table.insert(boxes, {
				X = math.cos(radians) * wall.Radius,
				Z = math.sin(radians) * wall.Radius,
				W = length,
				D = wall.Thickness,
				Rot = WildLayout.faceHubRot(angle),
			})
		end
	end
	return boxes
end

-- Distance from (x, z) to the nearest path center line (paths run from the town out along each
-- area angle).
function WildLayout.pathDistance(areas: { { AngleDegrees: number } }, x: number, z: number): number
	local best = math.huge
	for _, area in areas do
		local radians = math.rad(area.AngleDegrees)
		local ux, uz = math.cos(radians), math.sin(radians)
		local along = x * ux + z * uz
		if along > 0 then
			best = math.min(best, math.abs(x * uz - z * ux))
		end
	end
	return best
end

return WildLayout
