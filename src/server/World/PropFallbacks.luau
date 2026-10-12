-- Primitive stand-ins for map props without an imported model (MapPropConfig Fallback kinds).
-- Each builder fills `model` with a few parts inside `size` (W, H, D) standing on `base` (bottom
-- center; local -Z is the front). Kept to a handful of parts: the wild repeats them hundreds of times.

local BuildUtil = require(script.Parent.BuildUtil)

local PropFallbacks = {}

type Builder = (model: Model, base: CFrame, size: Vector3, rng: Random) -> ()

local STONE = Color3.fromRGB(96, 92, 104)
local DARK_STONE = Color3.fromRGB(64, 60, 74)
local WOOD = Color3.fromRGB(82, 60, 48)
local DARK_WOOD = Color3.fromRGB(52, 40, 36)
local RED = Color3.fromRGB(150, 36, 42)
local SPIRIT = Color3.fromRGB(170, 110, 255)

local function block(model: Model, name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
	return BuildUtil.part(model, { Name = name, Size = size, CFrame = cframe, Material = material, Color = color })
end

local function glow(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = block(model, name, size, cframe, Enum.Material.Neon, color)
	BuildUtil.decor(part)
	return part
end

local builders: { [string]: Builder } = {}

builders.Gate = function(model, base, size)
	local w, h = size.X, size.Y
	for _, side in { -1, 1 } do
		block(model, "Pillar", Vector3.new(1.6, h, 1.6), base * CFrame.new(side * (w / 2 - 3), h / 2, 0), Enum.Material.Wood, RED)
	end
	block(model, "TopBeam", Vector3.new(w, 1.4, 2.2), base * CFrame.new(0, h - 0.7, 0), Enum.Material.Wood, DARK_WOOD)
	block(model, "LowerBeam", Vector3.new(w - 4, 0.9, 1.4), base * CFrame.new(0, h - 3.4, 0), Enum.Material.Wood, RED)
end

builders.Temple = function(model, base, size)
	local w, h = size.X, size.Y
	block(model, "Base", Vector3.new(w, h * 0.12, w), base * CFrame.new(0, h * 0.06, 0), Enum.Material.Slate, DARK_STONE)
	block(model, "Hall", Vector3.new(w * 0.7, h * 0.3, w * 0.7), base * CFrame.new(0, h * 0.27, 0), Enum.Material.Wood, RED)
	block(model, "Roof1", Vector3.new(w * 1.05, h * 0.08, w * 1.05), base * CFrame.new(0, h * 0.46, 0), Enum.Material.Slate, DARK_STONE)
	block(model, "Upper", Vector3.new(w * 0.45, h * 0.25, w * 0.45), base * CFrame.new(0, h * 0.62, 0), Enum.Material.Wood, RED)
	block(model, "Roof2", Vector3.new(w * 0.7, h * 0.07, w * 0.7), base * CFrame.new(0, h * 0.78, 0), Enum.Material.Slate, DARK_STONE)
	block(model, "Spire", Vector3.new(1.2, h * 0.18, 1.2), base * CFrame.new(0, h * 0.9, 0), Enum.Material.Metal, Color3.fromRGB(200, 160, 80))
end

builders.Lantern = function(model, base, size)
	local w, h = size.X, size.Y
	block(model, "Foot", Vector3.new(w, h * 0.15, w), base * CFrame.new(0, h * 0.075, 0), Enum.Material.Slate, STONE)
	block(model, "Post", Vector3.new(w * 0.4, h * 0.45, w * 0.4), base * CFrame.new(0, h * 0.375, 0), Enum.Material.Slate, STONE)
	glow(model, "Light", Vector3.new(w * 0.65, h * 0.2, w * 0.65), base * CFrame.new(0, h * 0.7, 0), Color3.fromRGB(255, 176, 96))
	block(model, "Cap", Vector3.new(w * 1.1, h * 0.12, w * 1.1), base * CFrame.new(0, h * 0.86, 0), Enum.Material.Slate, DARK_STONE)
end

builders.Pedestal = function(model, base, size)
	BuildUtil.cylinder(model, base * CFrame.new(0, size.Y / 2, 0), size.Y, size.X, { Name = "Base", Material = Enum.Material.Marble, Color = Color3.fromRGB(205, 200, 215) })
end

builders.Resonator = function(model, base, size)
	local w, h = size.X, size.Y
	block(model, "Base", Vector3.new(w, h * 0.14, w), base * CFrame.new(0, h * 0.07, 0), Enum.Material.Slate, DARK_STONE)
	BuildUtil.cylinder(model, base * CFrame.new(0, h * 0.42, 0), h * 0.56, w * 0.35, { Name = "Column", Material = Enum.Material.Basalt, Color = Color3.fromRGB(40, 36, 52) })
	glow(model, "Core", Vector3.new(w * 0.3, h * 0.25, w * 0.3), base * CFrame.new(0, h * 0.85, 0) * CFrame.Angles(0, math.rad(45), 0), SPIRIT)
end

builders.Lectern = function(model, base, size)
	local w, h = size.X, size.Y
	block(model, "Stand", Vector3.new(w * 0.3, h * 0.7, w * 0.3), base * CFrame.new(0, h * 0.35, 0), Enum.Material.Wood, DARK_WOOD)
	block(model, "Desk", Vector3.new(w, h * 0.08, size.Z), base * CFrame.new(0, h * 0.72, 0) * CFrame.Angles(math.rad(-20), 0, 0), Enum.Material.Wood, WOOD)
	glow(model, "Tome", Vector3.new(w * 0.5, h * 0.08, size.Z * 0.6), base * CFrame.new(0, h * 0.92, 0), Color3.fromRGB(255, 205, 90))
end

builders.Monolith = function(model, base, size)
	block(model, "Stone", size, base * CFrame.new(0, size.Y / 2, 0), Enum.Material.Slate, DARK_STONE)
	glow(model, "Runes", Vector3.new(size.X * 0.5, size.Y * 0.6, 0.1), base * CFrame.new(0, size.Y * 0.55, -size.Z / 2 - 0.06), SPIRIT)
end

builders.Box = function(model, base, size)
	block(model, "Box", size * Vector3.new(1, 0.8, 1), base * CFrame.new(0, size.Y * 0.4, 0), Enum.Material.Wood, WOOD)
	block(model, "Lid", Vector3.new(size.X * 1.1, size.Y * 0.2, size.Z * 1.1), base * CFrame.new(0, size.Y * 0.9, 0), Enum.Material.Wood, RED)
end

builders.DeadTree = function(model, base, size, rng)
	local h = size.Y
	local trunk = math.max(1.4, size.X * 0.18)
	BuildUtil.cylinder(model, base * CFrame.new(0, h * 0.5, 0), h, trunk, { Name = "Trunk", Material = Enum.Material.Wood, Color = Color3.fromRGB(58, 44, 40) })
	for index = 1, 3 do
		local height = h * rng:NextNumber(0.5, 0.85)
		local length = size.X * rng:NextNumber(0.3, 0.5)
		local turn = CFrame.Angles(0, math.rad(index * 120 + rng:NextNumber(-25, 25)), math.rad(rng:NextNumber(35, 60)))
		local branch = base * CFrame.new(0, height, 0) * turn * CFrame.new(length / 2, 0, 0)
		local part = block(model, "Branch", Vector3.new(length, trunk * 0.45, trunk * 0.45), branch, Enum.Material.Wood, Color3.fromRGB(58, 44, 40))
		BuildUtil.decor(part)
	end
end

builders.AncientTree = function(model, base, size)
	local h = size.Y
	BuildUtil.cylinder(model, base * CFrame.new(0, h * 0.35, 0), h * 0.7, size.X * 0.22, { Name = "Trunk", Material = Enum.Material.Wood, Color = Color3.fromRGB(62, 46, 40) })
	for index, fraction in { 0.75, 0.62, 0.88 } do
		local offset = CFrame.Angles(0, math.rad(index * 120), 0) * CFrame.new(size.X * 0.18, 0, 0)
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size.X * 0.6,
			CFrame = base * CFrame.new(0, h * fraction, 0) * offset,
			Material = Enum.Material.LeafyGrass,
			Color = Color3.fromRGB(56, 70, 66),
		}))
	end
	glow(model, "Charms", Vector3.new(size.X * 0.24, 0.3, 0.3), base * CFrame.new(0, h * 0.45, -size.X * 0.12), Color3.fromRGB(255, 236, 200))
end

builders.Rocks = function(model, base, size, rng)
	for index = 1, 3 do
		local scale = rng:NextNumber(0.45, 0.8)
		local offset = CFrame.new((index - 2) * size.X * 0.28, size.Y * scale * 0.4, rng:NextNumber(-0.2, 0.2) * size.Z)
		block(
			model,
			"Rock",
			Vector3.new(size.X * scale * 0.6, size.Y * scale, size.Z * scale * 0.8),
			base * offset * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Enum.Material.Slate,
			Color3.fromRGB(84, 90, 86)
		)
	end
end

builders.Mushrooms = function(model, base, size, rng)
	for index = 1, 3 do
		local x, z = rng:NextNumber(-0.35, 0.35) * size.X, rng:NextNumber(-0.35, 0.35) * size.Z
		local height = size.Y * (0.5 + index * 0.15)
		local stem = block(model, "Stem", Vector3.new(0.4, height, 0.4), base * CFrame.new(x, height / 2, z), Enum.Material.SmoothPlastic, Color3.fromRGB(220, 215, 200))
		BuildUtil.decor(stem)
		local cap = BuildUtil.cylinder(model, base * CFrame.new(x, height, z), 0.4, size.X * 0.35, { Name = "Cap", Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 235, 210) })
		BuildUtil.decor(cap)
	end
end

builders.Jizo = function(model, base, size)
	local w, h = size.X, size.Y
	block(model, "Body", Vector3.new(w, h * 0.6, w * 0.8), base * CFrame.new(0, h * 0.3, 0), Enum.Material.Slate, STONE)
	BuildUtil.part(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * w * 0.75, CFrame = base * CFrame.new(0, h * 0.78, 0), Material = Enum.Material.Slate, Color = STONE })
	block(model, "Bib", Vector3.new(w * 0.8, h * 0.18, 0.2), base * CFrame.new(0, h * 0.52, -w * 0.41), Enum.Material.Fabric, Color3.fromRGB(200, 40, 40))
end

builders.House = function(model, base, size, rng)
	local w, h, d = size.X, size.Y, size.Z
	block(model, "Walls", Vector3.new(w, h * 0.6, d), base * CFrame.new(0, h * 0.3, 0), Enum.Material.WoodPlanks, Color3.fromRGB(92, 72, 58))
	for _, side in { -1, 1 } do
		local roof = base * CFrame.new(0, h * 0.78, side * d * 0.25) * CFrame.Angles(math.rad(side * 28), 0, 0)
		block(model, "Roof", Vector3.new(w * 1.08, 0.8, d * 0.6), roof, Enum.Material.Slate, Color3.fromRGB(56, 48, 66))
	end
	block(model, "Door", Vector3.new(w * 0.2, h * 0.38, 0.3), base * CFrame.new(0, h * 0.19, -d / 2 - 0.1), Enum.Material.Wood, DARK_WOOD)
	if rng:NextNumber() < 0.6 then
		local window = glow(model, "Window", Vector3.new(w * 0.15, h * 0.12, 0.2), base * CFrame.new(w * 0.28, h * 0.38, -d / 2 - 0.1), Color3.fromRGB(255, 176, 96))
		window:SetAttribute("Window", true)
	end
end

builders.Hut = builders.House

builders.Well = function(model, base, size)
	local w, h = size.X, size.Y
	BuildUtil.cylinder(model, base * CFrame.new(0, h * 0.18, 0), h * 0.36, w, { Name = "Ring", Material = Enum.Material.Cobblestone, Color = STONE })
	for _, side in { -1, 1 } do
		block(model, "Post", Vector3.new(0.6, h * 0.65, 0.6), base * CFrame.new(side * w * 0.4, h * 0.5, 0), Enum.Material.Wood, DARK_WOOD)
	end
	block(model, "Roof", Vector3.new(w * 1.05, 0.6, w * 0.7), base * CFrame.new(0, h * 0.86, 0), Enum.Material.Slate, Color3.fromRGB(56, 48, 66))
end

builders.Cart = function(model, base, size)
	local w, h, d = size.X, size.Y, size.Z
	block(model, "Bed", Vector3.new(w * 0.75, h * 0.35, d), base * CFrame.new(0, h * 0.5, 0) * CFrame.Angles(0, 0, math.rad(8)), Enum.Material.WoodPlanks, WOOD)
	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, h * 0.55, h * 0.55),
			CFrame = base * CFrame.new(-w * 0.1, h * 0.28, side * d * 0.5) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Wood,
			Color = DARK_WOOD,
		})
	end
end

builders.Crates = function(model, base, size, rng)
	for index = 1, 3 do
		local s = size.Y * rng:NextNumber(0.4, 0.55)
		local offset = CFrame.new((index - 2) * size.X * 0.3, s / 2 + (if index == 2 then s * 0.9 else 0), rng:NextNumber(-0.2, 0.2) * size.Z)
		block(model, "Crate", Vector3.one * s, base * offset * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Enum.Material.WoodPlanks, WOOD)
	end
end

builders.Tower = function(model, base, size)
	local w, h = size.X, size.Y
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		block(model, "Leg", Vector3.new(1, h * 0.75, 1), base * CFrame.new(corner[1] * w * 0.4, h * 0.375, corner[2] * w * 0.4), Enum.Material.Wood, DARK_WOOD)
	end
	block(model, "Deck", Vector3.new(w, 1, w), base * CFrame.new(0, h * 0.75, 0), Enum.Material.WoodPlanks, WOOD)
	block(model, "Bell", Vector3.new(w * 0.3, w * 0.35, w * 0.3), base * CFrame.new(0, h * 0.82, 0), Enum.Material.Metal, Color3.fromRGB(160, 120, 60))
	block(model, "Roof", Vector3.new(w * 1.2, 1, w * 1.2), base * CFrame.new(0, h * 0.97, 0), Enum.Material.Slate, Color3.fromRGB(56, 48, 66))
end

builders.Pillar = function(model, base, size, rng)
	BuildUtil.cylinder(model, base * CFrame.new(0, size.Y / 2, 0), size.Y, size.X * 0.8, { Name = "Pillar", Material = Enum.Material.Limestone, Color = Color3.fromRGB(176, 168, 150) })
	block(model, "Chunk", Vector3.new(size.X, size.Y * 0.12, size.Z), base * CFrame.new(rng:NextNumber(-1, 1), size.Y * 0.06, rng:NextNumber(-1, 1)), Enum.Material.Limestone, Color3.fromRGB(150, 142, 126))
end

builders.Arch = function(model, base, size)
	local w, h, d = size.X, size.Y, size.Z
	for _, side in { -1, 1 } do
		block(model, "Leg", Vector3.new(w * 0.2, h * 0.8, d), base * CFrame.new(side * w * 0.4, h * 0.4, 0), Enum.Material.Limestone, Color3.fromRGB(176, 168, 150))
	end
	block(model, "Lintel", Vector3.new(w, h * 0.2, d), base * CFrame.new(0, h * 0.9, 0) * CFrame.Angles(0, 0, math.rad(4)), Enum.Material.Limestone, Color3.fromRGB(160, 150, 134))
end

builders.StatueHead = function(model, base, size)
	BuildUtil.part(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * size.Y * 1.1, CFrame = base * CFrame.new(0, size.Y * 0.4, 0), Material = Enum.Material.Limestone, Color = Color3.fromRGB(150, 146, 136) })
	for _, side in { -1, 1 } do
		glow(model, "Eye", Vector3.new(size.X * 0.12, size.Y * 0.06, 0.3), base * CFrame.new(side * size.X * 0.16, size.Y * 0.55, -size.Y * 0.52), SPIRIT)
	end
end

builders.Obelisk = function(model, base, size)
	block(model, "Stone", Vector3.new(size.X, size.Y * 0.9, size.Z), base * CFrame.new(0, size.Y * 0.45, 0), Enum.Material.Basalt, Color3.fromRGB(40, 36, 52))
	glow(model, "Tip", Vector3.new(size.X * 0.6, size.Y * 0.1, size.Z * 0.6), base * CFrame.new(0, size.Y * 0.95, 0) * CFrame.Angles(0, math.rad(45), 0), SPIRIT)
end

builders.Bush = function(model, base, size)
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size.X, size.Y * 1.2, size.Z),
		CFrame = base * CFrame.new(0, size.Y * 0.4, 0),
		Material = Enum.Material.LeafyGrass,
		Color = Color3.fromRGB(58, 84, 60),
	}))
end

builders.Bridge = function(model, base, size)
	local w, h, d = size.X, size.Y, size.Z
	block(model, "Deck", Vector3.new(w, 0.8, d), base * CFrame.new(0, h * 0.4, 0), Enum.Material.WoodPlanks, WOOD)
	for _, side in { -1, 1 } do
		block(model, "Rail", Vector3.new(0.5, 1.2, d), base * CFrame.new(side * w / 2, h * 0.4 + 1, 0), Enum.Material.Wood, DARK_WOOD)
	end
end

builders.Signpost = function(model, base, size)
	block(model, "Pole", Vector3.new(0.6, size.Y, 0.6), base * CFrame.new(0, size.Y / 2, 0), Enum.Material.Wood, DARK_WOOD)
	block(model, "Board", Vector3.new(size.X, 1.6, 0.3), base * CFrame.new(0, size.Y * 0.8, 0), Enum.Material.WoodPlanks, Color3.fromRGB(96, 74, 58))
end

builders.Log = function(model, base, size)
	BuildUtil.part(model, {
		Name = "Log",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size.Z, size.Y * 0.75, size.Y * 0.75),
		CFrame = base * CFrame.new(0, size.Y * 0.375, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(70, 54, 44),
	})
end

PropFallbacks.Builders = builders

function PropFallbacks.build(kind: string, model: Model, base: CFrame, size: Vector3, rng: Random)
	local builder = builders[kind] or builders.Box
	builder(model, base, size, rng)
end

return PropFallbacks
