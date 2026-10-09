-- Abandoned Village (GDD 4.1): empty houses with dim windows, a central well, a dirt square,
-- broken fences, crates and a few street lamps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildUtil = require(script.Parent.Parent.BuildUtil)

local TOP = 0.4
local LAMP = Color3.fromRGB(255, 196, 120)
local WINDOW = Color3.fromRGB(255, 170, 90)
local WALLS = {
	Color3.fromRGB(122, 104, 90),
	Color3.fromRGB(108, 100, 96),
	Color3.fromRGB(132, 116, 100),
}
local ROOF = Color3.fromRGB(70, 46, 46)

local function house(model: Model, at, blocker)
	local w, d, h = blocker.W, blocker.D, blocker.H - 4
	local base = at(blocker.X, TOP, blocker.Z) * CFrame.Angles(0, math.rad(blocker.Rot), 0)
	local wallColor = WALLS[(math.abs(blocker.X + blocker.Z) % #WALLS) + 1]
	BuildUtil.part(model, {
		Name = "HouseWalls",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = wallColor,
	})
	local roofHeight = blocker.H - h
	for _, side in { -1, 1 } do
		BuildUtil.wedge(model, {
			Name = "Roof",
			Size = Vector3.new(w + 1.4, roofHeight, d / 2 + 0.8),
			CFrame = base * CFrame.new(0, h + roofHeight / 2, side * (d / 4 + 0.4)) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0),
			Material = Enum.Material.Slate,
			Color = ROOF,
		})
	end
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "Door",
		Size = Vector3.new(3.4, 6, 0.3),
		CFrame = base * CFrame.new(0, 3, -d / 2 - 0.15),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(52, 36, 30),
	}))
	for _, side in { -1, 1 } do
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Window",
			Size = Vector3.new(2.4, 2.4, 0.2),
			CFrame = base * CFrame.new(side * w / 3, h * 0.6, -d / 2 - 0.1),
			Material = Enum.Material.Neon,
			Color = WINDOW,
			Transparency = 0.35,
		}))
	end
	if blocker.H >= 13 then
		BuildUtil.part(model, {
			Name = "Chimney",
			Size = Vector3.new(2, 5, 2),
			CFrame = base * CFrame.new(w / 3, blocker.H - 0.5, d / 5),
			Material = Enum.Material.Brick,
			Color = Color3.fromRGB(90, 70, 66),
		})
	end
end

local function well(model: Model, at, blocker)
	local center = at(blocker.X, TOP, blocker.Z)
	BuildUtil.cylinder(model, center * CFrame.new(0, 1.5, 0), 3, blocker.W, {
		Name = "Well",
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(100, 98, 104),
	})
	BuildUtil.decor(BuildUtil.cylinder(model, center * CFrame.new(0, 2.95, 0), 0.2, blocker.W - 1.6, {
		Name = "WellWater",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 0.4,
	}))
	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "WellPost",
			Size = Vector3.new(0.6, 6, 0.6),
			CFrame = center * CFrame.new(side * (blocker.W / 2 - 0.3), 4.5, 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(64, 48, 40),
		})
	end
	BuildUtil.wedge(model, {
		Name = "WellRoof",
		Size = Vector3.new(blocker.W + 1, 1.6, 2.4),
		CFrame = center * CFrame.new(0, 8.2, -1.2),
		Material = Enum.Material.Slate,
		Color = ROOF,
	})
	BuildUtil.wedge(model, {
		Name = "WellRoof",
		Size = Vector3.new(blocker.W + 1, 1.6, 2.4),
		CFrame = center * CFrame.new(0, 8.2, 1.2) * CFrame.Angles(0, math.pi, 0),
		Material = Enum.Material.Slate,
		Color = ROOF,
	})
end

local function structure(model: Model, at, blocker)
	if blocker.Kind == "Well" then
		well(model, at, blocker)
	else
		house(model, at, blocker)
	end
end

local function dress(model: Model, at, rng: Random, free)
	-- Dirt main street from the gate to the square, and the square around the well.
	BuildUtil.decor(BuildUtil.part(model, {
		Name = "Street",
		Size = Vector3.new(12, 0.1, 90),
		CFrame = at(0, TOP + 0.05, -40),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(92, 76, 62),
	}))
	BuildUtil.decor(BuildUtil.cylinder(model, at(0, TOP + 0.05, 10), 0.1, 44, {
		Name = "Square",
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(92, 76, 62),
	}))

	for _, spot in { { -10, -30 }, { 10, -64 }, { -45, -2 }, { 45, 4 }, { -8, 70 }, { 30, 74 } } do
		local x, z = spot[1], spot[2]
		BuildUtil.part(model, {
			Name = "LampPost",
			Size = Vector3.new(0.8, 10, 0.8),
			CFrame = at(x, TOP + 5, z),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 38, 44),
		})
		local lamp = BuildUtil.part(model, {
			Name = "Lamp",
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = at(x, TOP + 10.6, z),
			Material = Enum.Material.Neon,
			Color = LAMP,
		})
		BuildUtil.decor(lamp)
		BuildUtil.light(lamp, LAMP, 18, 1.2)
	end

	local half = Config.World.DistrictSize / 2 - 7
	local placed, attempts = 0, 0
	while placed < 18 and attempts < 800 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 5) then
			continue
		end
		placed += 1
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			local size = rng:NextNumber(2.4, 3.6)
			BuildUtil.part(model, {
				Name = "Crate",
				Size = Vector3.new(size, size, size),
				CFrame = at(x, TOP + size / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(110, 84, 60),
			})
		elseif kind == 2 then
			BuildUtil.cylinder(model, at(x, TOP + 1.6, z), 3.2, 2.4, {
				Name = "Barrel",
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(88, 62, 46),
			})
		else
			local length = rng:NextNumber(8, 14)
			local rotation = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			BuildUtil.part(model, {
				Name = "FenceRail",
				Size = Vector3.new(length, 0.4, 0.3),
				CFrame = at(x, TOP + 2.2, z) * rotation,
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(80, 64, 52),
			})
			for _, side in { -1, 1 } do
				BuildUtil.part(model, {
					Name = "FencePost",
					Size = Vector3.new(0.5, 3, 0.5),
					CFrame = at(x, TOP + 1.5, z) * rotation * CFrame.new(side * length / 2, 0, 0),
					Material = Enum.Material.Wood,
					Color = Color3.fromRGB(70, 56, 46),
				})
			end
		end
	end

	placed, attempts = 0, 0
	while placed < 8 and attempts < 400 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 8) then
			continue
		end
		placed += 1
		local height = rng:NextNumber(10, 16)
		BuildUtil.cylinder(model, at(x, TOP + height / 2, z), height, 1.6, {
			Name = "DeadTree",
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(62, 52, 48),
		})
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "DeadBranch",
			Size = Vector3.new(0.7, height * 0.4, 0.7),
			CFrame = at(x, TOP + height * 0.8, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(40)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(62, 52, 48),
		}))
	end
end

return {
	FloorMaterial = Enum.Material.Mud,
	FloorColor = Color3.fromRGB(70, 66, 52),
	GateStone = Color3.fromRGB(88, 70, 60),
	GateLamp = LAMP,
	NameColor = Color3.fromRGB(255, 225, 190),
	Structure = structure,
	Dress = dress,
}
