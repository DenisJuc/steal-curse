-- Map props (Slice 11): every model the map places, with the size it is scaled to. Imported models
-- live in ServerStorage.MapProps as "<PropId>" (synced from assets/MapProps/<PropId>.rbxm); without
-- one the server builds the primitive Fallback shape of the same size, so the map always works.
--   Size:     {W, H, D} studs. Imports are scaled so their height matches H.
--   Fit:      "Length" = scale imports by their longest ground side instead (to the larger of W and D)
--             and turn that side along local Z. For long, flat props (bridge, log).
--   Sink:     studs the prop is pushed into the ground (models with an uneven or hanging bottom);
--             negative lifts it.
--   Tilt:     degrees an imported model's front (-Z) is pitched up toward the sky; the tilted model
--             is stood back on the ground.
--   Collide:  "Box" = an invisible box collider of Collider size (default Size), "None" = walk through.
--   Light:    optional warm/cold glow (PointLight, switched off by distance on the client).
-- Pure, so Lune can test it.

local MapPropConfig = {}

export type Light = { Color: { number }, Range: number, Brightness: number, Height: number }
export type Prop = {
	Size: { number },
	Collide: "Box" | "None",
	Collider: { number }?,
	Fit: "Length"?,
	Sink: number?,
	Tilt: number?,
	Fallback: string,
	Light: Light?,
}

local WARM: Light = { Color = { 255, 170, 90 }, Range = 16, Brightness = 1.4, Height = 0.8 }
local FUNGUS: Light = { Color = { 120, 235, 210 }, Range = 10, Brightness = 1, Height = 0.4 }
local RUNE: Light = { Color = { 150, 120, 255 }, Range = 14, Brightness = 1.2, Height = 0.7 }

-- stylua: ignore
MapPropConfig.Props = {
	-- Shrine town
	ShrineGate         = { Size = { 22, 18, 3 },  Collide = "None", Fallback = "Gate" },
	HubTemple          = { Size = { 26, 40, 26 }, Collide = "Box",  Fallback = "Temple", Light = WARM },
	StoneLantern       = { Size = { 3, 7, 3 },    Collide = "Box",  Fallback = "Lantern", Light = WARM },
	RelicPedestal      = { Size = { 7.5, 4.6, 7.5 }, Collide = "Box", Fallback = "Pedestal" },
	SpiritResonator    = { Size = { 8, 14, 8 },   Collide = "Box",  Fallback = "Resonator", Light = RUNE },
	CodexLectern       = { Size = { 4, 6, 3 },    Collide = "Box",  Fallback = "Lectern" },
	RuneMonolith       = { Size = { 5, 12, 3 },   Collide = "Box",  Fallback = "Monolith", Light = RUNE },
	OfferingBox        = { Size = { 5, 3.6, 4 },  Collide = "Box",  Sink = -0.4, Fallback = "Box" },
	-- Haunted Forest
	DeadTree1          = { Size = { 10, 22, 10 }, Collide = "Box",  Collider = { 2.4, 22, 2.4 }, Fallback = "DeadTree" },
	DeadTree2          = { Size = { 12, 18, 12 }, Collide = "Box",  Collider = { 2.4, 18, 2.4 }, Fallback = "DeadTree" },
	AncientTree        = { Size = { 40, 60, 40 }, Collide = "Box",  Collider = { 9, 60, 9 }, Fallback = "AncientTree" },
	MossyRocks         = { Size = { 8, 5, 7 },    Collide = "Box",  Fallback = "Rocks" },
	GlowMushrooms      = { Size = { 4, 2.5, 4 },  Collide = "None", Fallback = "Mushrooms", Light = FUNGUS },
	JizoStatue         = { Size = { 2.5, 4, 2.5 }, Collide = "Box", Fallback = "Jizo" },
	-- Abandoned Village
	RuinedHouse        = { Size = { 18, 16, 14 }, Collide = "Box",  Fallback = "House" },
	RuinedHut          = { Size = { 11, 11, 10 }, Collide = "Box",  Fallback = "Hut" },
	OldWell            = { Size = { 7, 8, 7 },    Collide = "Box",  Fallback = "Well" },
	BrokenCart         = { Size = { 9, 5, 5 },    Collide = "Box",  Fallback = "Cart" },
	CrateBarrelPile    = { Size = { 10, 7, 9 },   Collide = "Box",  Fallback = "Crates" },
	BellTower          = { Size = { 10, 34, 10 }, Collide = "Box",  Fallback = "Tower", Light = WARM },
	-- Ancient Ruins
	BrokenPillar1      = { Size = { 4, 13, 4 },   Collide = "Box",  Fallback = "Pillar" },
	BrokenPillar2      = { Size = { 4, 7, 4 },    Collide = "Box",  Fallback = "Pillar" },
	RuinArch           = { Size = { 18, 18, 4 },  Collide = "Box",  Collider = { 18, 18, 2 }, Fallback = "Arch" },
	GuardianStatueHead = { Size = { 18, 16, 18 }, Collide = "Box",  Sink = 2, Tilt = 70, Fallback = "StatueHead" },
	RuneObelisk        = { Size = { 4, 16, 4 },   Collide = "Box",  Fallback = "Obelisk", Light = RUNE },
	-- Shared / blend zones
	FernBush           = { Size = { 5, 3, 5 },    Collide = "None", Fallback = "Bush" },
	-- The bridge collider is a flat walkway level with the banks (the bridge base sits just below).
	WoodenBridge       = { Size = { 8, 4, 26 },   Collide = "Box",  Collider = { 7, 1, 26 }, Fit = "Length", Fallback = "Bridge" },
	Signpost           = { Size = { 6, 9, 2 },    Collide = "Box",  Collider = { 1, 9, 1 }, Fallback = "Signpost" },
	FallenLog          = { Size = { 5, 4, 16 },   Collide = "Box",  Collider = { 3, 3, 15 }, Fit = "Length", Fallback = "Log" },
} :: { [string]: Prop }

-- Shapes the server knows how to build without an imported model.
MapPropConfig.FallbackKinds = {
	"Gate", "Temple", "Lantern", "Pedestal", "Resonator", "Lectern", "Monolith", "Box",
	"DeadTree", "AncientTree", "Rocks", "Mushrooms", "Jizo",
	"House", "Hut", "Well", "Cart", "Crates", "Tower",
	"Pillar", "Arch", "StatueHead", "Obelisk",
	"Bush", "Bridge", "Signpost", "Log",
}

function MapPropConfig.size(propId: string): (number, number, number)
	local prop = MapPropConfig.Props[propId]
	return prop.Size[1], prop.Size[2], prop.Size[3]
end

-- Footprint radius (half the larger ground side).
function MapPropConfig.radius(propId: string): number
	local prop = MapPropConfig.Props[propId]
	return math.max(prop.Size[1], prop.Size[3]) / 2
end

return MapPropConfig
