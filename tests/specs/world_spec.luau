-- World layout (GDD 4.1, 4.2) and capture presentation data (GDD 4.3, 4.4).

local CaptureFamilies = require("../../src/shared/CaptureFamilies")
local CaptureSummary = require("../../src/shared/CaptureSummary")
local Config = require("../../src/shared/Config")
local DistrictLayouts = require("../../src/shared/DistrictLayouts")
local RelicConfig = require("../../src/shared/RelicConfig")
local WorldLayout = require("../../src/shared/WorldLayout")
local expect = require("../lib/expect")

local world = Config.World
local half = world.DistrictSize / 2

local function plotCorners(index: number): { { number } }
	local px, pz = WorldLayout.plotPosition(Config.Plots, index)
	local radians = (index - 1) / Config.Plots.Count * math.pi * 2
	-- A plot faces the hub; its square is rotated with the ring, so check its rotated corners.
	local ux, uz = math.cos(radians), math.sin(radians)
	local vx, vz = -uz, ux
	local h = Config.Plots.Size / 2
	local corners = {}
	for _, signs in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(corners, { px + (ux * signs[1] + vx * signs[2]) * h, pz + (uz * signs[1] + vz * signs[2]) * h })
	end
	table.insert(corners, { px, pz })
	return corners
end

return {
	{
		Name = "district local/world conversion round-trips and matches CFrame.lookAt(center, hub)",
		Run = function()
			for _, district in Config.Districts do
				local wx, wz = WorldLayout.toWorld(district, world, 12, -30)
				local lx, lz = WorldLayout.toLocal(district, world, wx, wz)
				expect.near(lx, 12, 1e-9, "x round-trip")
				expect.near(lz, -30, 1e-9, "z round-trip")
				-- Local -Z points at the hub: moving toward the gate gets closer to the center.
				local gx, gz = WorldLayout.toWorld(district, world, 0, -half)
				local cx, cz = WorldLayout.districtCenter(district, world)
				expect.truthy(gx * gx + gz * gz < cx * cx + cz * cz, `{district.Id} gate faces the hub`)
				expect.equal(WorldLayout.districtAt(Config.Districts, world, cx, cz), district.Id, "center is inside")
			end
			-- Angle 0: CFrame.lookAt((R,0,0), origin) has RightVector (0,0,-1) and LookVector (-1,0,0).
			local east = { Id = "East", Name = "East", AngleDegrees = 0, Seed = 1 }
			local x, z = WorldLayout.toWorld(east, world, 1, 0)
			expect.near(x, world.DistrictRadius, 1e-9, "right x")
			expect.near(z, -1, 1e-9, "right is -Z")
			x, z = WorldLayout.toWorld(east, world, 0, 1)
			expect.near(x, world.DistrictRadius + 1, 1e-9, "back is away from the hub")
			expect.near(z, 0, 1e-9, "back z")
		end,
	},
	{
		Name = "districts fit on the ground and never overlap the hub, the plots or each other",
		Run = function()
			local groundHalf = Config.Hub.GroundSize / 2
			for _, district in Config.Districts do
				for _, corner in { { half, half }, { half, -half }, { -half, half }, { -half, -half } } do
					local x, z = WorldLayout.toWorld(district, world, corner[1], corner[2])
					expect.truthy(math.abs(x) <= groundHalf and math.abs(z) <= groundHalf, `{district.Id} corner on the ground`)
					local hubDistance = math.sqrt(x * x + z * z)
					expect.truthy(hubDistance > Config.Hub.PlazaRadius, `{district.Id} clear of the plaza`)
					for _, other in Config.Districts do
						if other ~= district then
							local lx, lz = WorldLayout.toLocal(other, world, x, z)
							expect.truthy(math.abs(lx) > half or math.abs(lz) > half, `{district.Id} overlaps {other.Id}`)
						end
					end
				end
				for index = 1, Config.Plots.Count do
					for _, corner in plotCorners(index) do
						expect.equal(
							WorldLayout.districtAt({ district }, world, corner[1], corner[2], 2),
							nil,
							`plot {index} overlaps {district.Id}`
						)
					end
				end
			end
		end,
	},
	{
		Name = "every district has 12+ spawn points inside it, clear of structures and spread out",
		Run = function()
			local lane = DistrictLayouts.EntranceLane
			for _, district in Config.Districts do
				local layout = DistrictLayouts.ById[district.Id]
				expect.truthy(layout ~= nil, `{district.Id} has a layout`)
				expect.truthy(#layout.Spawns >= 12, `{district.Id} spawn count`)
				for index, spawn in layout.Spawns do
					local x, z = spawn[1], spawn[2]
					local label = `{district.Id} spawn {index}`
					expect.truthy(math.abs(x) <= half - 6 and math.abs(z) <= half - 6, `{label} inside the walls`)
					expect.truthy(
						not (math.abs(x) < lane.HalfWidth and z < -half + lane.Depth),
						`{label} is in the entrance lane`
					)
					for _, structure in layout.Blockers do
						local distance = WorldLayout.distanceToBox(x, z, structure)
						expect.truthy(distance >= 4, `{label} is {distance} from a {structure.Kind}`)
					end
					for other = index + 1, #layout.Spawns do
						local dx, dz = x - layout.Spawns[other][1], z - layout.Spawns[other][2]
						expect.truthy(math.sqrt(dx * dx + dz * dz) >= 15, `{label} too close to spawn {other}`)
					end
				end
				for _, structure in layout.Blockers do
					local entrance = { X = 0, Z = -half + lane.Depth / 2, W = lane.HalfWidth * 2, D = lane.Depth }
					local inLane = WorldLayout.distanceToBox(structure.X, structure.Z, entrance)
						< math.max(structure.W, structure.D) / 2
					expect.truthy(not inLane, `{district.Id} {structure.Kind} blocks the entrance`)
				end
			end
		end,
	},
	{
		Name = "travel stays short: every plot reaches a district gate within 20 s, signals within 10 s of the gate",
		Run = function()
			for index = 1, Config.Plots.Count do
				local px, pz = WorldLayout.plotPosition(Config.Plots, index)
				local nearest = WorldLayout.nearestDistrict(Config.Districts, world, px, pz)
				for _, district in Config.Districts do
					if district.Id == nearest then
						local gx, gz = WorldLayout.toWorld(district, world, 0, -half)
						local seconds = math.sqrt((gx - px) ^ 2 + (gz - pz) ^ 2) / world.WalkSpeed
						expect.truthy(seconds <= 20, `plot {index} -> {district.Id}: {seconds} s`)
					end
				end
			end
			for _, district in Config.Districts do
				local total = 0
				local spawns = DistrictLayouts.ById[district.Id].Spawns
				for _, spawn in spawns do
					total += math.sqrt(spawn[1] ^ 2 + (spawn[2] + half) ^ 2)
				end
				local seconds = total / #spawns / world.WalkSpeed
				expect.truthy(seconds <= 10, `{district.Id} mean gate -> signal walk {seconds} s`)
			end
		end,
	},
	{
		Name = "every relic object type has a capture animation family (5 families total)",
		Run = function()
			local count = 0
			for _ in CaptureFamilies.Families do
				count += 1
			end
			expect.equal(count, 5, "five shared families (GDD 4.3)")
			for _, objectType in RelicConfig.ObjectTypes do
				expect.truthy(CaptureFamilies.ByObjectType[objectType] ~= nil, `{objectType} has a family`)
			end
			for _, relic in RelicConfig.Relics do
				local family = CaptureFamilies.forObjectType(relic.ObjectType)
				local seconds = CaptureFamilies.totalSeconds(family)
				expect.truthy(seconds >= 1 and seconds <= 3, `{relic.Id} capture animation {seconds} s`)
			end
		end,
	},
	{
		Name = "capture summary: captured relic, bonus count, notable finds rarest first, new and sold totals",
		Run = function()
			local tiers = { C = 1, R = 3, E = 4, M = 6 }
			local function tierOf(id: string): number
				return tiers[id] or 1
			end
			local results = {
				{ Id = "R", First = true },
				{ Id = "C", Sold = 0.1 },
				{ Id = "E" },
				{ Id = "C", Mutation = "Golden", First = false, NewVariant = true },
				{ Id = "M", First = true },
				{ Id = "E", First = true },
				{ Id = "C", Sold = 0.1 },
			}
			local summary = CaptureSummary.build(results, tierOf, 3) :: CaptureSummary.Summary
			expect.equal(summary.CapturedId, "R", "captured is the first result")
			expect.equal(summary.CapturedFirst, true, "captured was new")
			expect.equal(summary.BonusCount, 6, "bonus count excludes the captured relic")
			expect.equal(summary.NewCount, 3, "new to the Codex (captured included)")
			expect.equal(summary.SoldCount, 2, "auto-sold")
			expect.near(summary.SoldCE, 0.2, 1e-9, "sold CE")
			expect.equal(#summary.Notable, 3, "capped")
			expect.equal(summary.Notable[1].Id, "M", "rarest first")
			expect.equal(summary.Notable[2].Id, "E", "then epic")
			expect.equal(summary.Notable[2].First, true, "the new epic before the old one")
			expect.equal(summary.Notable[3].Id, "E", "second epic")
			expect.equal(CaptureSummary.build({}, tierOf, 3), nil, "nothing captured")
		end,
	},
}
