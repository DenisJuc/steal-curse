-- Haunted Forest (GDD 4.1): dense dead trees, rocks, ruined walls and pale glowing fungus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildUtil = require(script.Parent.Parent.BuildUtil)

local TOP = 0.4
local TREES = 40
local ROCKS = 14
local FUNGI = 16
local FUNGUS = Color3.fromRGB(150, 235, 210)

local function structure(model: Model, at, blocker)
	BuildUtil.part(model, {
		Name = "RuinedWall",
		Size = Vector3.new(blocker.W, blocker.H, blocker.D),
		CFrame = at(blocker.X, TOP + blocker.H / 2, blocker.Z) * CFrame.Angles(0, math.rad(blocker.Rot), 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(96, 92, 100),
	})
	-- A broken cap stone on top so the walls read as ruins, not fences.
	BuildUtil.part(model, {
		Name = "WallCap",
		Size = Vector3.new(blocker.W * 0.45, 1.4, blocker.D + 0.6),
		CFrame = at(blocker.X, TOP + blocker.H + 0.7, blocker.Z)
			* CFrame.Angles(0, math.rad(blocker.Rot), 0)
			* CFrame.new(-blocker.W * 0.2, 0, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(82, 78, 88),
	})
end

local function dress(model: Model, at, rng: Random, free)
	local half = Config.World.DistrictSize / 2 - 7
	local placed, attempts = 0, 0
	while placed < TREES and attempts < 3000 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 8) then
			continue
		end
		placed += 1
		local height = rng:NextNumber(14, 24)
		local diameter = rng:NextNumber(2, 3.6)
		BuildUtil.cylinder(model, at(x, TOP + height / 2, z), height, diameter, {
			Name = "Trunk",
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(58, 44, 40),
		})
		local canopySize = height * rng:NextNumber(0.55, 0.75)
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(canopySize, canopySize, canopySize),
			CFrame = at(x, TOP + height, z),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(48, 58, 56):Lerp(Color3.fromRGB(70, 54, 86), rng:NextNumber()),
		}))
	end

	placed, attempts = 0, 0
	while placed < ROCKS and attempts < 500 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 6) then
			continue
		end
		placed += 1
		local size = rng:NextNumber(3, 7)
		BuildUtil.part(model, {
			Name = "Rock",
			Size = Vector3.new(size, size * 0.7, size * 1.2),
			CFrame = at(x, TOP + size * 0.25, z)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(84, 82, 92),
		})
	end

	placed, attempts = 0, 0
	while placed < FUNGI and attempts < 500 do
		attempts += 1
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if not free(x, z, 3) then
			continue
		end
		placed += 1
		local size = rng:NextNumber(1.2, 2.2)
		BuildUtil.decor(BuildUtil.cylinder(model, at(x, TOP + 0.2, z), 0.4, size, {
			Name = "GlowFungus",
			Material = Enum.Material.Neon,
			Color = FUNGUS,
			Transparency = 0.2,
		}))
	end
end

return {
	FloorMaterial = Enum.Material.LeafyGrass,
	FloorColor = Color3.fromRGB(46, 56, 44),
	GateStone = Color3.fromRGB(70, 66, 80),
	GateLamp = Color3.fromRGB(255, 160, 80),
	NameColor = Color3.fromRGB(200, 230, 255),
	Structure = structure,
	Dress = dress,
}
