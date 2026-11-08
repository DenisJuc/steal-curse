-- Builds one shrine plot: stone courtyard, path, walls, gate, raised resonator terrace,
-- pedestals and Showcase podium. Plot local -Z faces the hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local BuildUtil = require(script.Parent.BuildUtil)
local MapProps = require(script.Parent.MapProps)
local PedestalVisuals = require(script.Parent.PedestalVisuals)

local PlotBuilder = {}

local STONE = Color3.fromRGB(72, 74, 82)
local STONE_DARK = Color3.fromRGB(58, 60, 68)
local STONE_TRIM = Color3.fromRGB(110, 112, 120)
local WOOD = Color3.fromRGB(96, 70, 56)
local GATE_RED = Color3.fromRGB(150, 36, 42)
local MARBLE = Color3.fromRGB(205, 200, 215)
local SPIRIT = Color3.fromRGB(170, 110, 255)
local WARM = Color3.fromRGB(255, 190, 90)
local DAIS = Color3.fromRGB(95, 88, 78)

-- Sealing chamber dressing: dark walls, paper seals, the binding circle around the pedestals.
local WALL = Color3.fromRGB(44, 40, 52)
local WALL_PILLAR = Color3.fromRGB(30, 27, 36)
local PAPER = Color3.fromRGB(228, 216, 184)
local SEAL_INK = Color3.fromRGB(170, 24, 30)
local ROPE = Color3.fromRGB(176, 146, 98)
local SEAL_GLOW = Color3.fromRGB(150, 80, 255)
local CIRCLE_CENTER = { 0, -12 }

local FLOOR_TOP = 1.2
local WALL_H = 8
-- Front wall (the street side) is a low fence so the relics show from Shrine Street.
local FRONT_H = 3
local GATE_GAP = 16
local PATH_W = 10
local TERRACE_H = 1.0

-- Collect pad on the gate side of each pedestal: the pedestal's CE piles up there and walking onto
-- it claims the lot (PedestalService). A dark seal plate with a warm rune inlay; the trigger is an
-- invisible box so a player touches it the moment they step on. PedestalVisuals shows the amount.
local COLLECT_PAD_DISTANCE = 4.4
local PAD_STONE = Color3.fromRGB(30, 26, 36)

local function buildCollectPad(model: Model, at: (number, number, number) -> CFrame, x: number, z: number)
	local pad = BuildUtil.part(model, {
		Name = "CollectPad",
		Size = Vector3.new(4.8, 0.24, 2.8),
		CFrame = at(x, FLOOR_TOP + 0.12, z),
		Material = Enum.Material.Slate,
		Color = PAD_STONE,
	})
	pad.CanTouch = false
	BuildUtil.part(model, {
		Name = "CollectTrim",
		Size = Vector3.new(5.2, 0.16, 3.2),
		CFrame = at(x, FLOOR_TOP + 0.08, z),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 120, 70),
	}).CanTouch = false
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "CollectGlow",
		Size = Vector3.new(4.0, 0.05, 2.0),
		CFrame = at(x, FLOOR_TOP + 0.26, z),
		Material = Enum.Material.Neon,
		Color = WARM,
		Transparency = 0.75,
	}))
	local trigger = BuildUtil.part(model, {
		Name = "CollectTrigger",
		Size = Vector3.new(4.8, 5, 2.8),
		CFrame = at(x, FLOOR_TOP + 2.6, z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	trigger.CanTouch = true
end

local function buildPedestal(parent: Instance, at: (number, number, number) -> CFrame, slot: number)
	local offset = Config.Plots.PedestalOffsets[slot]
	local x, z = offset[1], offset[2]
	local model = Instance.new("Model")
	model.Name = "Pedestal" .. slot
	model:SetAttribute("Slot", slot)

	-- Thin shrine pad around the pedestal (does not change pedestal Y — relic math uses FLOOR_TOP).
	BuildUtil.part(model, {
		Name = "Dais",
		Size = Vector3.new(5.5, 0.2, 5.5),
		CFrame = at(x, FLOOR_TOP + 0.1, z),
		Material = Enum.Material.Concrete,
		Color = DAIS,
	})
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + 0.22, z), 0.08, 4.6, {
		Name = "DaisRing",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(180, 150, 90),
	}))

	local width, height = MapPropConfig.size("RelicPedestal")
	local imported = MapProps.has("RelicPedestal")
	BuildUtil.cylinder(model, at(x, FLOOR_TOP + (height - 0.4) / 2, z), height - 0.4, width * 0.85, {
		Name = "Base",
		Material = Enum.Material.Marble,
		Color = MARBLE,
	})
	BuildUtil.cylinder(model, at(x, FLOOR_TOP + height - 0.2, z), 0.4, width, {
		Name = "Top",
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	-- A small sigil under the relic (PedestalVisuals tints it by rarity), not a full neon plate.
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + height + 0.05, z), 0.1, width * 0.32, {
		Name = "Glow",
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.45,
	}))
	buildCollectPad(model, at, x, z - COLLECT_PAD_DISTANCE)
	if imported then
		local look = MapProps.build(model, "RelicPedestal", at(x, FLOOR_TOP, z))
		if look then
			look.Name = "Look"
			local collider = look:FindFirstChild("Collider")
			if collider then
				collider:Destroy()
			end
		end
	end
	model.Parent = parent
end

local function buildResonator(parent: Instance, at: (number, number, number) -> CFrame, floorY: number)
	local offset = Config.Plots.ResonatorOffset
	local x, z = offset[1], offset[2]
	local model = Instance.new("Model")
	model.Name = "SpiritResonator"
	if MapProps.has("SpiritResonator") then
		MapProps.build(model, "SpiritResonator", at(x, floorY, z))
		model.Parent = parent
		return
	end

	BuildUtil.part(model, {
		Name = "Base",
		Size = Vector3.new(8, 2, 8),
		CFrame = at(x, floorY + 1, z),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	BuildUtil.cylinder(model, at(x, floorY + 6, z), 8, 3, {
		Name = "Column",
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(40, 36, 52),
	})
	local core = BuildUtil.part(model, {
		Name = "ResonatorCore",
		Size = Vector3.new(2.6, 4, 2.6),
		CFrame = at(x, floorY + 12, z) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = SPIRIT,
	})
	BuildUtil.decor(core)
	BuildUtil.light(core, SPIRIT, 18, 2)
	BuildUtil.sparkles(core, SPIRIT, 6)
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, floorY + 12, z) * CFrame.Angles(math.rad(20), 0, 0), 0.3, 7, {
		Name = "Ring",
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.35,
	}))
	model.Parent = parent
end

local function buildShowcasePodium(parent: Instance, at: (number, number, number) -> CFrame)
	local offset = Config.Plots.ShowcaseOffset
	local x, z = offset[1], offset[2]
	local model = Instance.new("Model")
	model.Name = "ShowcasePodium"

	local dais = BuildUtil.cylinder(model, at(x, FLOOR_TOP + 0.6, z), 1.2, 16, {
		Name = "Dais",
		Material = Enum.Material.Basalt,
		Color = WALL_PILLAR,
	})
	-- Warm rim only: neon disc tucked under a slightly smaller basalt plate.
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + 1.25, z), 0.1, 16.2, {
		Name = "Edge",
		Material = Enum.Material.Neon,
		Color = WARM,
		Transparency = 0.5,
	}))
	BuildUtil.decor(BuildUtil.cylinder(model, at(x, FLOOR_TOP + 1.35, z), 0.1, 15.8, {
		Name = "Cap",
		Material = Enum.Material.Basalt,
		Color = WALL_PILLAR,
	}))
	BuildUtil.billboard(dais, "Showcase", 8, 1.6, 3, Color3.fromRGB(255, 210, 140))
	-- Binding chains laid on the rim at the four diagonals (clear of the set pieces at front/back).
	if MapProps.has("IronChain") then
		for k = 0, 3 do
			local angle = math.rad(45 + k * 90)
			local radius = 6.6
			local chain = MapProps.build(model, "IronChain", at(x, FLOOR_TOP + 1.4, z))
			if chain then
				-- Lay it flat along the rim tangent, resting on the cap.
				local box = chain:GetBoundingBox()
				chain.WorldPivot = CFrame.new(box.Position)
				local center = at(x + math.cos(angle) * radius, FLOOR_TOP + 1.65, z + math.sin(angle) * radius)
				chain:PivotTo(center * CFrame.Angles(0, -angle, 0) * CFrame.Angles(math.rad(90), 0, 0))
			end
		end
	end
	model.Parent = parent
end

-- Invisible solid boxes for the imported gate's posts and lower crossbeam (the gate prop itself is
-- walk-through, since its own box would seal the doorway). Each post box runs on out to the wall
-- wing so no gap is left beside it; the doorway between the posts stays open.
local function buildGateColliders(model: Model, at: (number, number, number) -> CFrame, z: number)
	local posts = MapPropConfig.Props.ShrineGate.Posts
	if not posts then
		return
	end
	local outer = math.max(posts.Outer, GATE_GAP / 2)
	local width = outer - posts.Inner
	local top = posts.Beam + posts.BeamH
	local boxes = {
		{ "PostCollider", Vector3.new(width, top, posts.Depth), at(-(posts.Inner + width / 2), FLOOR_TOP + top / 2, z) },
		{ "PostCollider", Vector3.new(width, top, posts.Depth), at(posts.Inner + width / 2, FLOOR_TOP + top / 2, z) },
		{ "BeamCollider", Vector3.new(posts.Inner * 2, posts.BeamH, posts.Depth), at(0, FLOOR_TOP + posts.Beam + posts.BeamH / 2, z) },
	}
	for _, box in boxes do
		BuildUtil.part(model, {
			Name = box[1],
			Size = box[2],
			CFrame = box[3],
			Transparency = 1,
			CastShadow = false,
			CanTouch = false,
		})
	end
end

local function buildGate(parent: Instance, at: (number, number, number) -> CFrame)
	local half = Config.Plots.Size / 2
	local z = -half + 0.7
	local model = Instance.new("Model")
	model.Name = "Gate"

	if MapProps.has("ShrineGate") then
		MapProps.build(model, "ShrineGate", at(0, FLOOR_TOP, z))
		buildGateColliders(model, at, z)
		local _, height, depth = MapPropConfig.size("ShrineGate")
		local sign = BuildUtil.part(model, {
			Name = "OwnerSign",
			Size = Vector3.new(10, 1.6, 0.4),
			CFrame = at(0, FLOOR_TOP + height * 0.7, z - depth / 2 - 0.4),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(30, 24, 26),
		})
		BuildUtil.surfaceText(sign, Enum.NormalId.Front, "Unclaimed Shrine", Color3.fromRGB(255, 220, 170))
		model.Parent = parent
		return
	end

	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "Pillar",
			Size = Vector3.new(1.8, 14, 1.8),
			CFrame = at(side * 8, FLOOR_TOP + 7, z),
			Material = Enum.Material.Wood,
			Color = GATE_RED,
		})
	end
	BuildUtil.part(model, {
		Name = "TopBeam",
		Size = Vector3.new(22, 1.6, 2.4),
		CFrame = at(0, FLOOR_TOP + 14.2, z),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(40, 30, 32),
	})
	BuildUtil.part(model, {
		Name = "LowerBeam",
		Size = Vector3.new(18, 1, 1.6),
		CFrame = at(0, FLOOR_TOP + 11.2, z),
		Material = Enum.Material.Wood,
		Color = GATE_RED,
	})
	local sign = BuildUtil.part(model, {
		Name = "OwnerSign",
		Size = Vector3.new(12, 1.8, 0.4),
		CFrame = at(0, FLOOR_TOP + 12.7, z - 1),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(30, 24, 26),
	})
	BuildUtil.surfaceText(sign, Enum.NormalId.Front, "Unclaimed Shrine", Color3.fromRGB(255, 220, 170))
	model.Parent = parent
end

local function buildCourtyardFloor(parent: Instance, at: (number, number, number) -> CFrame)
	local size = Config.Plots.Size
	local half = size / 2

	-- Inner limestone courtyard (Base is the thick slate pad underneath).
	BuildUtil.part(parent, {
		Name = "Floor",
		Size = Vector3.new(size - 4, 0.22, size - 4),
		CFrame = at(0, FLOOR_TOP - 0.05, 0),
		Material = Enum.Material.Limestone,
		Color = STONE,
	})

	-- Dark border frame
	local border = 2.4
	local bH = 0.16
	local frames = {
		{ Vector3.new(size - 2, bH, border), at(0, FLOOR_TOP + bH / 2, -half + border / 2 + 1) },
		{ Vector3.new(size - 2, bH, border), at(0, FLOOR_TOP + bH / 2, half - border / 2 - 1) },
		{ Vector3.new(border, bH, size - border * 2 - 2), at(-half + border / 2 + 1, FLOOR_TOP + bH / 2, 0) },
		{ Vector3.new(border, bH, size - border * 2 - 2), at(half - border / 2 - 1, FLOOR_TOP + bH / 2, 0) },
	}
	for _, frame in frames do
		BuildUtil.part(parent, {
			Name = "Border",
			Size = frame[1],
			CFrame = frame[2],
			Material = Enum.Material.Slate,
			Color = STONE_DARK,
		})
	end

	-- Processional path: gate → resonator
	BuildUtil.part(parent, {
		Name = "Path",
		Size = Vector3.new(PATH_W, 0.14, size - 10),
		CFrame = at(0, FLOOR_TOP + 0.08, 2),
		Material = Enum.Material.Cobblestone,
		Color = STONE_DARK,
	})
end

local function buildWalls(parent: Instance, at: (number, number, number) -> CFrame)
	local size = Config.Plots.Size
	local half = size / 2
	local t = 1.0
	local wing = (size - GATE_GAP) / 2
	local wallColor = WALL

	local walls = {
		-- Back
		{ Vector3.new(size, WALL_H, t), at(0, FLOOR_TOP + WALL_H / 2, half - t / 2) },
		-- Sides
		{ Vector3.new(t, WALL_H, size), at(-half + t / 2, FLOOR_TOP + WALL_H / 2, 0) },
		{ Vector3.new(t, WALL_H, size), at(half - t / 2, FLOOR_TOP + WALL_H / 2, 0) },
		-- Front wings (gate gap in the middle)
		{ Vector3.new(wing, FRONT_H, t), at(-(GATE_GAP / 2 + wing / 2), FLOOR_TOP + FRONT_H / 2, -half + t / 2) },
		{ Vector3.new(wing, FRONT_H, t), at(GATE_GAP / 2 + wing / 2, FLOOR_TOP + FRONT_H / 2, -half + t / 2) },
	}
	for _, wall in walls do
		BuildUtil.part(parent, {
			Name = "Wall",
			Size = wall[1],
			CFrame = wall[2],
			Material = Enum.Material.Slate,
			Color = wallColor,
		})
	end

	-- Capstones
	local capH = 0.32
	local caps = {
		{ Vector3.new(size, capH, t + 0.25), at(0, FLOOR_TOP + WALL_H + capH / 2, half - t / 2) },
		{ Vector3.new(t + 0.25, capH, size), at(-half + t / 2, FLOOR_TOP + WALL_H + capH / 2, 0) },
		{ Vector3.new(t + 0.25, capH, size), at(half - t / 2, FLOOR_TOP + WALL_H + capH / 2, 0) },
		{ Vector3.new(wing, capH, t + 0.25), at(-(GATE_GAP / 2 + wing / 2), FLOOR_TOP + FRONT_H + capH / 2, -half + t / 2) },
		{ Vector3.new(wing, capH, t + 0.25), at(GATE_GAP / 2 + wing / 2, FLOOR_TOP + FRONT_H + capH / 2, -half + t / 2) },
	}
	for _, cap in caps do
		BuildUtil.part(parent, {
			Name = "Capstone",
			Size = cap[1],
			CFrame = cap[2],
			Material = Enum.Material.Basalt,
			Color = WALL_PILLAR,
		})
	end
end

-- Imported talismans, cycled along the walls.
local OFUDA_PROPS = { "OfudaDemon", "OfudaFear", "OfudaMisfortune" }

-- A paper seal (ofuda) on a wall: `cframe` is the wall face point, facing into the chamber.
local function buildOfuda(parent: Instance, cframe: CFrame, variant: number)
	local propId = OFUDA_PROPS[(variant - 1) % #OFUDA_PROPS + 1]
	if MapProps.has(propId) then
		local _, height = MapPropConfig.size(propId)
		MapProps.build(parent, propId, cframe * CFrame.new(0, -height / 2, -0.06))
		return
	end
	local paper = BuildUtil.decor(BuildUtil.part(parent, {
		Name = "Ofuda",
		Size = Vector3.new(1, 2.6, 0.06),
		CFrame = cframe * CFrame.new(0, 0, -0.04),
		Material = Enum.Material.Fabric,
		Color = PAPER,
	}))
	local label = BuildUtil.surfaceText(paper, Enum.NormalId.Front, "封", SEAL_INK)
	label.Font = Enum.Font.Arial
end

-- Buttresses along the walls with a seal between each pair, so the yard reads as a sealed vault.
local function buildWallSeals(parent: Instance, at: (number, number, number) -> CFrame)
	local half = Config.Plots.Size / 2
	local inner = half - 1
	local spacing = 22
	local pillarH = WALL_H + 1.2
	local runs = {
		-- {start, along, face}: start corner, direction along the wall, direction into the chamber.
		{ Vector3.new(-half, 0, inner), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1) },
		{ Vector3.new(-inner, 0, -half), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0) },
		{ Vector3.new(inner, 0, -half), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) },
	}
	local seals = 0
	local lastPillar = Config.Plots.Size / spacing
	for _, run in runs do
		local start, along, face = run[1], run[2], run[3]
		local inward = at(face.X, 0, face.Z).Position - at(0, 0, 0).Position
		for i = 0, lastPillar do
			local p = start + along * (i * spacing)
			BuildUtil.part(parent, {
				Name = "WallPillar",
				Size = Vector3.new(2.4, pillarH, 2.4),
				CFrame = at(p.X + face.X * 0.7, FLOOR_TOP + pillarH / 2, p.Z + face.Z * 0.7),
				Material = Enum.Material.Basalt,
				Color = WALL_PILLAR,
			})
			-- Iron chains hang down the inner face of the middle pillars (not the corners).
			if i > 0 and i < lastPillar and MapProps.has("IronChain") then
				local _, chainH = MapPropConfig.size("IronChain")
				local hang = at(p.X + face.X * 2.05, FLOOR_TOP + WALL_H - chainH - 0.2, p.Z + face.Z * 2.05)
				MapProps.build(parent, "IronChain", CFrame.lookAt(hang.Position, hang.Position + inward))
			end
			if i * spacing < Config.Plots.Size - 1 then
				local mid = p + along * (spacing / 2)
				local origin = at(mid.X, FLOOR_TOP + 5, mid.Z)
				seals += 1
				buildOfuda(parent, CFrame.lookAt(origin.Position, origin.Position + inward), seals)
			end
		end
	end
end

-- Sacred rope (shimenawa) with paper streamers across the entrance, inside the gate.
local function buildEntranceRope(parent: Instance, at: (number, number, number) -> CFrame)
	local half = Config.Plots.Size / 2
	local z = -half + 2.2
	local y = FLOOR_TOP + WALL_H - 0.6
	BuildUtil.decor(BuildUtil.cylinder(parent, at(0, y, z) * CFrame.Angles(0, 0, math.rad(90)), GATE_GAP + 2, 0.9, {
		Name = "Shimenawa",
		Material = Enum.Material.Fabric,
		Color = ROPE,
	}))
	for i = -3, 3 do
		local x = i * (GATE_GAP / 8)
		local streamer = if i % 2 == 0 then 1.8 else 1.1
		BuildUtil.decor(BuildUtil.part(parent, {
			Name = "Shide",
			Size = Vector3.new(0.5, streamer, 0.05),
			CFrame = at(x, y - 0.4 - streamer / 2, z),
			Material = Enum.Material.Fabric,
			Color = PAPER,
		}))
	end
end

-- The binding circle around the pedestals: two glowing rings laid from short tangent segments
-- (they sit on the floor and path, inside the pedestal daises) with rune marks between them.
local function buildSealCircle(parent: Instance, at: (number, number, number) -> CFrame)
	local cx, cz = CIRCLE_CENTER[1], CIRCLE_CENTER[2]
	local function ring(name: string, radius: number, count: number, width: number, gap: number, transparency: number)
		local length = 2 * math.pi * radius / count - gap
		for i = 1, count do
			local angle = (i - 0.5) / count * math.pi * 2
			BuildUtil.decor(BuildUtil.part(parent, {
				Name = name,
				Size = Vector3.new(length, 0.1, width),
				CFrame = at(cx + math.cos(angle) * radius, FLOOR_TOP + 0.2, cz + math.sin(angle) * radius)
					* CFrame.Angles(0, -angle + math.pi / 2, 0),
				Material = Enum.Material.Neon,
				Color = SEAL_GLOW,
				Transparency = transparency,
			}))
		end
	end
	ring("SealRing", 28.5, 40, 0.5, 0.05, 0.3)
	ring("SealRing", 26.7, 36, 0.25, 0.05, 0.45)
	ring("SealRune", 27.6, 16, 0.6, 9.4, 0.15)
end

local function buildResonatorTerrace(parent: Instance, at: (number, number, number) -> CFrame)
	local half = Config.Plots.Size / 2
	local depth = 22
	local width = 36
	local z = half - depth / 2 - 2

	BuildUtil.part(parent, {
		Name = "Terrace",
		Size = Vector3.new(width, TERRACE_H, depth),
		CFrame = at(0, FLOOR_TOP + TERRACE_H / 2, z),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(80, 82, 90),
	})

	for i = 1, 3 do
		local stepH = TERRACE_H / 3
		local stepD = 1.6
		local y = FLOOR_TOP + stepH * (i - 0.5)
		local stepZ = z - depth / 2 - stepD * (4 - i) + stepD / 2
		BuildUtil.part(parent, {
			Name = "TerraceStep",
			Size = Vector3.new(width * 0.55, stepH, stepD),
			CFrame = at(0, y, stepZ),
			Material = Enum.Material.Concrete,
			Color = STONE_TRIM,
		})
	end

	local railH = 1.1
	for _, side in { -1, 1 } do
		BuildUtil.part(parent, {
			Name = "TerraceRail",
			Size = Vector3.new(0.5, railH, depth - 2),
			CFrame = at(side * (width / 2 - 0.4), FLOOR_TOP + TERRACE_H + railH / 2, z),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(78, 80, 90),
		})
	end
end

local function buildLantern(parent: Instance, at: (number, number, number) -> CFrame, x: number, z: number)
	if MapProps.has("StoneLantern") then
		MapProps.build(parent, "StoneLantern", at(x, FLOOR_TOP, z))
		return
	end
	BuildUtil.part(parent, {
		Name = "LanternPost",
		Size = Vector3.new(0.55, 3.2, 0.55),
		CFrame = at(x, FLOOR_TOP + 1.6, z),
		Material = Enum.Material.Wood,
		Color = WOOD,
	})
	local lamp = BuildUtil.decor(BuildUtil.part(parent, {
		Name = "Lantern",
		Size = Vector3.new(1.1, 1.3, 1.1),
		CFrame = at(x, FLOOR_TOP + 3.5, z),
		Material = Enum.Material.Neon,
		Color = WARM,
		Transparency = 0.15,
	}))
	BuildUtil.light(lamp, Color3.fromRGB(255, 200, 120), 18, 1.1)
end

local function buildCornerLanterns(parent: Instance, at: (number, number, number) -> CFrame)
	local half = Config.Plots.Size / 2
	local inset = 3.5
	buildLantern(parent, at, -half + inset, -half + inset)
	buildLantern(parent, at, half - inset, -half + inset)
	buildLantern(parent, at, -half + inset, half - inset)
	buildLantern(parent, at, half - inset, half - inset)
	-- Flanking the gate
	buildLantern(parent, at, -GATE_GAP / 2 - 2, -half + 4)
	buildLantern(parent, at, GATE_GAP / 2 + 2, -half + 4)
end

-- Sakura in the free back-left corner, mirroring the Showcase podium across the path: clear of the
-- binding circle, the terrace and its rails, the pedestals and the wall pillars. Built only when the
-- model is imported (a primitive fallback tree would look wrong in the chamber).
local BLOSSOM_TREE = { -30, 26 }

local function buildBlossomTree(parent: Instance, at: (number, number, number) -> CFrame)
	if MapProps.has("HomeBlossomTree") then
		MapProps.build(parent, "HomeBlossomTree", at(BLOSSOM_TREE[1], FLOOR_TOP, BLOSSOM_TREE[2]))
	end
end

function PlotBuilder.Build(index: number, cframe: CFrame, parent: Instance): Model
	local size = Config.Plots.Size
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)

	local base = BuildUtil.part(model, {
		Name = "Base",
		Size = Vector3.new(size, 1, size),
		CFrame = at(0, 0.5, 0),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})

	buildCourtyardFloor(model, at)
	buildSealCircle(model, at)
	buildWalls(model, at)
	buildWallSeals(model, at)
	buildEntranceRope(model, at)
	buildGate(model, at)
	buildResonatorTerrace(model, at)
	buildResonator(model, at, FLOOR_TOP + TERRACE_H)
	buildShowcasePodium(model, at)
	buildCornerLanterns(model, at)
	buildBlossomTree(model, at)

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = model
	for slot = 1, Config.Plots.MaxPedestals do
		buildPedestal(pedestals, at, slot)
	end
	PedestalVisuals.Reset(model)

	local spawnOffset = Config.Plots.SpawnOffset
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "SpawnPad",
		Size = Vector3.new(6, 1, 6),
		CFrame = at(spawnOffset[1], FLOOR_TOP, spawnOffset[2]),
		Transparency = 1,
	}))

	model.PrimaryPart = base
	model.Parent = parent
	return model
end

return PlotBuilder
