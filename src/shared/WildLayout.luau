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
	at("AncientTree", 44.5, 352),
	at("JizoStatue", 12.5, 214, 10),
	at("JizoStatue", 36.5, 248, -15),
	at("JizoStatue", 0.5, 331, 30),
	at("JizoStatue", 62.5, 227),
	at("GlowMushrooms", 28.5, 386),
	-- Abandoned Village (around 157.5 degrees)
	at("BellTower", 169.5, 245),
	at("RuinedHouse", 139.5, 227, 8),
	at("RuinedHouse", 146.5, 266, -10),
	at("RuinedHouse", 177.5, 221, 5),
	at("RuinedHouse", 173.5, 271, 12),
	at("RuinedHouse", 140.5, 343, -6),
	at("RuinedHouse", 177.5, 352, 10),
	at("RuinedHut", 127.5, 251, 20),
	at("RuinedHut", 187.5, 254, -20),
	at("RuinedHut", 131.5, 376, 15),
	at("RuinedHut", 185.5, 321, -12),
	at("OldWell", 151.5, 331),
	at("BrokenCart", 165.5, 207, 40),
	at("CrateBarrelPile", 135.5, 203, 15),
	-- Ancient Ruins (around 292.5 degrees)
	at("GuardianStatueHead", 309.5, 245, -20),
	at("RuinArch", 276.5, 238),
	at("RuinArch", 313.5, 337, 20),
	at("RuinArch", 282.5, 386, -10),
	at("RuneObelisk", 270.5, 285),
	at("RuneObelisk", 318.5, 367),
	at("RuneObelisk", 263.5, 352),
	at("RuneObelisk", 298.5, 324),
	-- Signposts beside each path where the wild begins.
	at("Signpost", 27.5, 203),
	at("Signpost", 162.5, 203),
	at("Signpost", 297.5, 203),
}

-- Area angles and the borders between them.
WildLayout.BridgeAngles = { 22.5, 90, 157.5, 225, 292.5, 337.5 }

-- stylua: ignore
WildLayout.Scatter = {
	HauntedForest = {
		{ Prop = "DeadTree1", Density = 5.2 },
		{ Prop = "DeadTree2", Density = 3.9 },
		{ Prop = "MossyRocks", Density = 2 },
		{ Prop = "GlowMushrooms", Density = 2.6 },
		{ Prop = "FernBush", Density = 3.9 },
		{ Prop = "FallenLog", Density = 1 },
	},
	AbandonedVillage = {
		{ Prop = "FernBush", Density = 2 },
		{ Prop = "CrateBarrelPile", Density = 0.8 },
		{ Prop = "MossyRocks", Density = 0.65 },
		{ Prop = "DeadTree2", Density = 0.8 },
		{ Prop = "FallenLog", Density = 0.4 },
	},
	AncientRuins = {
		{ Prop = "BrokenPillar1", Density = 1.6 },
		{ Prop = "BrokenPillar2", Density = 2 },
		{ Prop = "MossyRocks", Density = 2 },
		{ Prop = "FernBush", Density = 1 },
	},
} :: { [string]: { ScatterRule } }

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
