-- The intro hunt's glade (IntroLayout): a narrow forest trail cut off from the world, walled in by
-- dead trees, bamboo and rocks, from the mossy hollow where a new player wakes up to a ruined
-- shrine clearing where the spirit is sealed. Built from the same map props as the wild (models
-- still to come are their primitive fallbacks) plus a few parts. Invisible walls keep players on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IntroLayout = require(ReplicatedStorage.Shared.IntroLayout)
local BuildUtil = require(script.Parent.BuildUtil)
local MapProps = require(script.Parent.MapProps)

local IntroBuilder = {}

local GROUND = Color3.fromRGB(40, 54, 44)
local DARK = Color3.fromRGB(22, 24, 26)
local STONE = Color3.fromRGB(70, 72, 82)
local GLOW = Color3.fromRGB(150, 220, 255)

local function prop(parent: Instance, id: string, point: Vector3, turn: number, scale: number, rng: Random)
	if not MapProps.has(id) then
		return nil
	end
	local frame = IntroLayout.frame(point) * CFrame.Angles(0, math.rad(turn), 0)
	return MapProps.build(parent, id, frame, scale, rng)
end

-- Shortest distance from (x, z) to the trail polyline.
local function trailDistance(trail: { Vector3 }, x: number, z: number): number
	local best = math.huge
	for i = 1, #trail - 1 do
		local a, b = trail[i], trail[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local t = math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / (abx * abx + abz * abz), 0, 1)
		local px, pz = a.X + abx * t, a.Z + abz * t
		best = math.min(best, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))
	end
	return best
end

function IntroBuilder.Build(parent: Instance): Model
	local rng = Random.new(2026)
	local model = Instance.new("Model")
	model.Name = "IntroGlade"
	local half, back, front = IntroLayout.HalfWidth, IntroLayout.Back, IntroLayout.Front
	local length = back + front
	local centerZ = (back - front) / 2

	-- Ground: the glade floor, and a wide dark plain under it so nothing looks out into the void.
	BuildUtil.part(model, {
		Name = "GladeFloor",
		Size = Vector3.new(half * 2 + 20, 2, length + 20),
		CFrame = IntroLayout.frame(Vector3.new(0, -1, centerZ)),
		Material = Enum.Material.Grass,
		Color = GROUND,
	})
	BuildUtil.part(model, {
		Name = "GladePlain",
		Size = Vector3.new(900, 1, 900),
		CFrame = IntroLayout.frame(Vector3.new(0, -1.7, centerZ)),
		Material = Enum.Material.Mud,
		Color = DARK,
	})

	-- The trail: flagstone slabs between its points (every other one a hair lower so overlapping
	-- ends never share a plane).
	local trail = IntroLayout.trail()
	for i = 1, #trail - 1 do
		local a, b = trail[i], trail[i + 1]
		local from, to = IntroLayout.world(a), IntroLayout.world(b)
		local span = (to - from).Magnitude
		local slab = BuildUtil.part(model, {
			Name = "Trail",
			Size = Vector3.new(6, 0.3, span + 6),
			CFrame = CFrame.lookAt((from + to) / 2, to) + Vector3.new(0, 0.05 - (i % 2) * 0.04, 0),
			Material = Enum.Material.Cobblestone,
			Color = STONE,
		})
		slab.MaterialVariant = "ShrineFlagstone"
	end

	-- Walls of forest down both sides, thinner scatter inside (never on the trail).
	local edgeProps = { "DeadTree1", "DeadTree2", "BambooGrove", "BambooGrove2", "DeadTree1", "MossyRocks" }
	for z = back - 6, -front + 6, -9 do
		for _, side in { -1, 1 } do
			local x = side * rng:NextNumber(half - 10, half - 2)
			prop(model, edgeProps[rng:NextInteger(1, #edgeProps)], Vector3.new(x, 0, z + rng:NextNumber(-3, 3)), rng:NextNumber(0, 360), rng:NextNumber(0.9, 1.4), rng)
		end
	end
	local innerProps = { "DeadTree2", "FernBush", "MossyRocks", "SpiderLilyPatch", "GlowMushrooms", "FernBush", "FallenLog" }
	for _ = 1, 70 do
		local x, z = rng:NextNumber(-half + 8, half - 8), rng:NextNumber(-front + 30, back - 8)
		-- Off the trail and out of the space behind the waking spot (the opening camera).
		local behindWake = math.abs(x) < 14 and z > -4
		if trailDistance(trail, x, z) > 9 and not behindWake then
			prop(model, innerProps[rng:NextInteger(1, #innerProps)], Vector3.new(x, 0, z), rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.3), rng)
		end
	end

	-- The waking hollow: a fallen log, mushrooms and ferns off to the sides (the camera rises behind
	-- the player along +Z, so nothing stands there).
	prop(model, "FallenLog", Vector3.new(-14, 0, -6), 20, 0.9, rng)
	prop(model, "GlowMushrooms", Vector3.new(7, 0, -6), 0, 1.2, rng)
	prop(model, "GlowMushrooms", Vector3.new(-6, 0, -14), 40, 0.9, rng)
	prop(model, "FernBush", Vector3.new(11, 0, -2), 0, 1.2, rng)

	-- Stone lanterns along the trail light the way (spaced, alternating sides).
	for i = 2, #trail - 1, 2 do
		local point = trail[i]
		local side = if i % 4 == 0 then 1 else -1
		prop(model, "StoneLantern", Vector3.new(point.X + side * 6, 0, point.Z), 0, 0.9, rng)
	end

	-- The ruined shrine clearing: a stone seal circle, a broken torii behind, the ancient tree, a
	-- rune monolith and two lanterns.
	local final = IntroLayout.Spots[#IntroLayout.Spots].At
	BuildUtil.cylinder(model, IntroLayout.frame(final + Vector3.new(0, 0.15, 0)), 0.3, 18, {
		Name = "SealStone",
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(46, 44, 54),
	})
	BuildUtil.decor(BuildUtil.cylinder(model, IntroLayout.frame(final + Vector3.new(0, 0.33, 0)), 0.05, 15, {
		Name = "SealGlow",
		Material = Enum.Material.Neon,
		Color = GLOW,
		Transparency = 0.88,
	}))
	prop(model, "ShrineGate", final + Vector3.new(0, 0, -22), 180, 1, rng)
	prop(model, "AncientTree", final + Vector3.new(-26, 0, -30), 0, 0.55, rng)
	prop(model, "RuneMonolith", final + Vector3.new(16, 0, -14), -30, 1, rng)
	prop(model, "StoneLantern", final + Vector3.new(-9, 0, 9), 0, 1, rng)
	prop(model, "StoneLantern", final + Vector3.new(9, 0, 9), 0, 1, rng)

	-- Invisible walls around the glade.
	local walls = {
		{ Vector3.new(2, 40, length + 20), Vector3.new(-half, 20, centerZ) },
		{ Vector3.new(2, 40, length + 20), Vector3.new(half, 20, centerZ) },
		{ Vector3.new(half * 2, 40, 2), Vector3.new(0, 20, back) },
		{ Vector3.new(half * 2, 40, 2), Vector3.new(0, 20, -front) },
	}
	for _, wall in walls do
		local part = BuildUtil.part(model, {
			Name = "GladeWall",
			Size = wall[1],
			CFrame = IntroLayout.frame(wall[2]),
			Transparency = 1,
		})
		part.CanQuery = false
		part.CastShadow = false
	end

	model.Parent = parent
	return model
end

return IntroBuilder
