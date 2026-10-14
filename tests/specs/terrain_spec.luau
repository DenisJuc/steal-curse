-- Wild terrain relief: flat where people travel, real hills/holes elsewhere, walls that never block
-- a path, and enough signal spots outside the pits.

local Config = require("../../src/shared/Config")
local MapPropConfig = require("../../src/shared/MapPropConfig")
local WildLayout = require("../../src/shared/WildLayout")
local WildTerrain = require("../../src/shared/WildTerrain")
local WorldLayout = require("../../src/shared/WorldLayout")
local expect = require("../lib/expect")

local world = Config.World
local areas = Config.Areas
local landmarks = WildLayout.boxes(MapPropConfig.Props)
local shrineBoxes = WildLayout.shrineBoxes()
local clearings = table.clone(landmarks)
for _, box in shrineBoxes do
	table.insert(clearings, box)
end

local function shape(): WildTerrain.Shape
	return WildTerrain.new({
		Areas = areas,
		World = world,
		AreaAt = WorldLayout.areaAt,
		PathDistance = WildLayout.pathDistance,
		PathHalfWidth = WildLayout.PathHalfWidth,
		Clearings = clearings,
	})
end

local terrain = shape()

local function wallCorners(box: WildLayout.Box): { { number } }
	local radians = math.rad(box.Rot or 0)
	local c, s = math.cos(radians), math.sin(radians)
	local corners = {}
	for _, signs in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local u, v = signs[1] * box.W / 2, signs[2] * box.D / 2
		table.insert(corners, { box.X + u * c + v * s, box.Z - u * s + v * c })
	end
	return corners
end

return {
	{
		Name = "heights are deterministic",
		Run = function()
			local again = shape()
			math.randomseed(3)
			for _ = 1, 200 do
				local x, z = WorldLayout.polar(math.random() * 360, world.WildInner + math.random() * (world.WildOuter - world.WildInner))
				expect.equal(terrain.heightAt(x, z), again.heightAt(x, z), "same height")
			end
		end,
	},
	{
		Name = "flat in town, at the inner edge, on the paths, at the stream and under landmarks",
		Run = function()
			expect.equal(terrain.heightAt(0, 0), 0, "hub")
			for _, area in areas do
				for distance = world.WildInner - 40, world.WildOuter, 5 do
					local x, z = WorldLayout.polar(area.AngleDegrees, distance)
					expect.equal(terrain.heightAt(x, z), 0, `{area.Id} path at {distance}`)
				end
			end
			for angle = 0, 359, 3 do
				local x, z = WorldLayout.polar(angle, world.WildInner + 1)
				expect.near(terrain.heightAt(x, z), 0, 0.1, `inner edge at {angle}`)
				x, z = WorldLayout.polar(angle, world.StreamRadius)
				expect.equal(terrain.heightAt(x, z), 0, `stream at {angle}`)
			end
			for index, box in landmarks do
				expect.equal(terrain.heightAt(box.X, box.Z), 0, `landmark #{index}`)
			end
		end,
	},
	{
		Name = "the wild has real relief: hills, holes and reasonable extremes",
		Run = function()
			local high, low, bumpy, total = 0, 0, 0, 0
			for angle = 0, 359, 2 do
				for distance = world.WildInner + 20, world.WildOuter - 10, 8 do
					local x, z = WorldLayout.polar(angle, distance)
					local h = terrain.heightAt(x, z)
					expect.truthy(h > -24 and h < 36, `height {h} at ({x}, {z})`)
					high = math.max(high, h)
					low = math.min(low, h)
					total += 1
					if math.abs(h) > 2 then
						bumpy += 1
					end
				end
			end
			expect.truthy(high >= 12, `tallest point {high}`)
			expect.truthy(low <= -6, `deepest hole {low}`)
			expect.truthy(bumpy / total > 0.35, `bumpy share {bumpy / total}`)
		end,
	},
	{
		Name = "path edges ramp up gently",
		Run = function()
			for _, area in areas do
				for distance = world.WildInner + 20, world.WildOuter - 10, 10 do
					local previous = nil
					for side = 0, 28, 2 do
						local px, pz = WorldLayout.polar(area.AngleDegrees, distance)
						local ux, uz = WorldLayout.polar(area.AngleDegrees + 90, 1)
						local h = terrain.heightAt(px + ux * side, pz + uz * side)
						if previous then
							expect.truthy(math.abs(h - previous) <= 5, `{area.Id} slope at r={distance} side={side}: {h - previous}`)
						end
						previous = h
					end
				end
			end
		end,
	},
	{
		Name = "walls: inside the ring, off the paths, the stream and the landmarks",
		Run = function()
			for index, box in WildLayout.wallBoxes() do
				for _, corner in wallCorners(box) do
					local x, z = corner[1], corner[2]
					expect.truthy(WorldLayout.inWild(world, x, z, 4), `wall box #{index} inside the ring`)
					expect.truthy(not WorldLayout.inStream(world, x, z, 6), `wall box #{index} out of the stream`)
					local path = WildLayout.pathDistance(areas, x, z)
					expect.truthy(path > WildLayout.PathHalfWidth + 6, `wall box #{index} blocks a path ({path})`)
				end
				for other, landmark in landmarks do
					local gap = WorldLayout.distanceToBox(box.X, box.Z, landmark)
					expect.truthy(gap >= box.D / 2 + 3, `wall box #{index} hits landmark #{other} ({gap})`)
				end
			end
			for _, wall in WildLayout.Walls do
				for _, area in areas do
					local delta = (area.AngleDegrees - wall.Angle0) % 360
					expect.truthy(delta > wall.Angle1 - wall.Angle0, `wall {wall.Angle0}-{wall.Angle1} crosses the {area.Id} path`)
				end
			end
		end,
	},
	{
		Name = "signal spots outside pits still cover every area and the near band",
		Run = function()
			local blocked = table.clone(clearings)
			for _, box in WildLayout.wallBoxes() do
				table.insert(blocked, box)
			end
			local points = {}
			local perArea: { [string]: number } = {}
			for _, point in WorldLayout.spawnGrid(areas, world, blocked) do
				if terrain.heightAt(point.X, point.Z) >= -WildLayout.MaxSpawnDepth then
					table.insert(points, point)
					perArea[point.Area] = (perArea[point.Area] or 0) + 1
				end
			end
			for _, area in areas do
				expect.truthy((perArea[area.Id] or 0) >= 300, `{area.Id} has {perArea[area.Id]} spots`)
			end
			math.randomseed(8)
			local signals = Config.Signals
			for _ = 1, 150 do
				local x, z = WorldLayout.polar(math.random() * 360, world.WildInner + math.random() * (world.WildOuter - world.WildInner))
				local inBand = 0
				for _, point in points do
					local distance = math.sqrt((point.X - x) ^ 2 + (point.Z - z) ^ 2)
					if distance >= signals.NearMin and distance <= signals.NearMax then
						inBand += 1
					end
				end
				expect.truthy(inBand >= signals.MaxCount * 3, `only {inBand} spots near ({x}, {z})`)
			end
		end,
	},
	{
		Name = "cursed shrines: 5 per area, mostly deep, flat, clear of paths, the stream, walls and landmarks",
		Run = function()
			local perArea: { [string]: number } = {}
			local deep: { [string]: number } = {}
			local seen: { [string]: boolean } = {}
			local half = WildLayout.ShrineSize / 2
			local walls = WildLayout.wallBoxes()
			for index, shrine in WildLayout.CursedShrines do
				expect.truthy(not seen[shrine.Id], `{shrine.Id} is unique`)
				seen[shrine.Id] = true
				local x, z = WildLayout.shrinePosition(shrine)
				expect.equal((WorldLayout.areaAt(areas, world, x, z)), shrine.Area, `{shrine.Id} inside its area`)
				expect.truthy(WorldLayout.inWild(world, x, z, half + 10), `{shrine.Id} inside the ring`)
				expect.truthy(not WorldLayout.inStream(world, x, z, half + 10), `{shrine.Id} out of the stream`)
				local path = WildLayout.pathDistance(areas, x, z)
				expect.truthy(path > WildLayout.PathHalfWidth + half + 6, `{shrine.Id} too close to a path ({path})`)
				for other, landmark in landmarks do
					local gap = WorldLayout.distanceToBox(x, z, landmark)
					expect.truthy(gap >= half + 12, `{shrine.Id} too close to landmark #{other} ({gap})`)
				end
				for other, wall in walls do
					local gap = WorldLayout.distanceToBox(x, z, wall)
					expect.truthy(gap >= half + 12, `{shrine.Id} too close to wall box #{other} ({gap})`)
				end
				for other, box in shrineBoxes do
					if other ~= index then
						expect.truthy(WorldLayout.distanceToBox(x, z, box) >= 40, `{shrine.Id} too close to shrine #{other}`)
					end
				end
				for _, offset in { { 0, 0 }, { half - 1, 0 }, { 0, half - 1 }, { -(half - 1), 0 }, { 0, -(half - 1) } } do
					expect.near(terrain.heightAt(x + offset[1], z + offset[2]), 0, 0.5, `{shrine.Id} ground is flat`)
				end
				perArea[shrine.Area] = (perArea[shrine.Area] or 0) + 1
				if shrine.Radius >= Config.HuntStreak.EdgeUntil then
					deep[shrine.Area] = (deep[shrine.Area] or 0) + 1
				end
			end
			for _, area in areas do
				expect.equal(perArea[area.Id], 5, `{area.Id} shrines`)
				expect.truthy((deep[area.Id] or 0) >= 4, `{area.Id} shrines mostly Deep or Heart`)
			end
		end,
	},
}
