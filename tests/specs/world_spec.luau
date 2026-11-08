-- World layout (GDD 4.1, 4.2; Slice 11 ring) and capture presentation data (GDD 4.3, 4.4).

local CaptureFamilies = require("../../src/shared/CaptureFamilies")
local CaptureSummary = require("../../src/shared/CaptureSummary")
local Config = require("../../src/shared/Config")
local MapPropConfig = require("../../src/shared/MapPropConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local WildLayout = require("../../src/shared/WildLayout")
local WorldLayout = require("../../src/shared/WorldLayout")
local expect = require("../lib/expect")

local world = Config.World
local areas = Config.Areas

local function boxCorners(box: WorldLayout.Box): { { number } }
	local radians = math.rad(box.Rot or 0)
	local c, s = math.cos(radians), math.sin(radians)
	local corners = { { box.X, box.Z } }
	for _, signs in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local u, v = signs[1] * box.W / 2, signs[2] * box.D / 2
		-- Inverse of distanceToBox's rotation.
		table.insert(corners, { box.X + u * c + v * s, box.Z - u * s + v * c })
	end
	return corners
end

local function plotCorners(index: number): { { number } }
	return boxCorners(WorldLayout.plotBox(Config.Plots, index))
end

local props = MapPropConfig.Props
local grid = WorldLayout.spawnGrid(areas, world, WildLayout.boxes(props))

return {
	{
		Name = "areas own their slice of the ring and blend near the borders",
		Run = function()
			for _, area in areas do
				local x, z = WorldLayout.areaCenter(area, world)
				local id, weight, other = WorldLayout.areaAt(areas, world, x, z)
				expect.equal(id, area.Id, "center belongs to its area")
				expect.equal(weight, 1, "no blend at the center")
				expect.equal(other, nil, "no neighbour at the center")
			end
			-- Forest (22.5) / Village (157.5) border is at 90 degrees.
			local bx, bz = WorldLayout.polar(90.001, 300)
			local _, borderWeight, neighbour = WorldLayout.areaAt(areas, world, bx, bz)
			expect.near(borderWeight, 0.5, 1e-3, "an even mix on the border")
			expect.truthy(neighbour ~= nil, "the border mixes two areas")
			local last = 0.5
			for offset = 1, 20 do
				local x, z = WorldLayout.polar(90 - offset, 300)
				local id, weight = WorldLayout.areaAt(areas, world, x, z)
				expect.equal(id, "HauntedForest", "forest side")
				expect.truthy(weight >= last, "weight grows away from the border")
				last = weight
			end
			expect.equal(last, 1, "past the blend zone the area is pure")
		end,
	},
	{
		Name = "the town fits inside the ring: plaza and every plot stay out of the wild",
		Run = function()
			local street = Config.Plots.Street
			local plaza = Config.Hub.PlazaRadius
			local hx, hz = WorldLayout.hubPosition(Config.Plots)
			for index = 1, Config.Plots.Count do
				for _, corner in plotCorners(index) do
					local r = math.sqrt(corner[1] ^ 2 + corner[2] ^ 2)
					expect.truthy(r < world.WildInner - 10, `plot {index} corner at {r}`)
				end
				local gap = WorldLayout.distanceToBox(hx, hz, WorldLayout.plotBox(Config.Plots, index)) - plaza
				expect.truthy(gap >= 8, `plaza {gap} studs from plot {index}`)
				-- Entrances open onto the street, and plots never overlap each other.
				local x, z = WorldLayout.plotPosition(Config.Plots, index)
				local fx, fz = WorldLayout.plotFacing(Config.Plots, index)
				local h = Config.Plots.Size / 2
				local _, across = WorldLayout.toStreet(street, x + fx * h, z + fz * h)
				expect.near(math.abs(across), street.HalfWidth, 1e-6, `plot {index} entrance on the curb`)
				for other = index + 1, Config.Plots.Count do
					local ox, oz = WorldLayout.plotPosition(Config.Plots, other)
					local d = WorldLayout.distanceToBox(ox, oz, WorldLayout.plotBox(Config.Plots, index))
					expect.truthy(d >= h, `plots {index} and {other} overlap`)
				end
			end
			expect.truthy(math.sqrt(hx * hx + hz * hz) + plaza < world.WildInner - 10, "plaza inside the town")
			-- Plot pairs face each other across the street.
			local x1, z1 = WorldLayout.plotPosition(Config.Plots, 1)
			local x2, z2 = WorldLayout.plotPosition(Config.Plots, 2)
			expect.near(math.sqrt((x1 - x2) ^ 2 + (z1 - z2) ^ 2), street.RowOffset * 2, 1e-6, "pair across the street")
		end,
	},
	{
		Name = "town paths: the street reaches the gate, hub paths reach each wild path clear of every plot",
		Run = function()
			-- WildBuilder hub paths are 12 wide with glow stones 1 stud outside; keep 3 more studs of air.
			local clearance = 6 + 1 + 3
			local street = Config.Plots.Street
			local paths = WorldLayout.townPaths(Config.Plots, world, areas, Config.Hub.PlazaRadius)
			for _, area in areas do
				local points = paths[area.Id]
				expect.truthy(points ~= nil and #points >= 2, `{area.Id} has a town path`)
				local last = points[#points]
				local ex, ez = WorldLayout.polar(area.AngleDegrees, world.WildInner)
				expect.near(last[1], ex, 1e-6, `{area.Id} path ends at its wild path (x)`)
				expect.near(last[2], ez, 1e-6, `{area.Id} path ends at its wild path (z)`)
				local isStreet = math.abs(area.AngleDegrees - street.AngleDegrees) < 1e-6
				for index = 1, #points - 1 do
					local a, b = points[index], points[index + 1]
					local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
					for step = 0, length, 2 do
						local t = step / length
						local x, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
						expect.truthy(math.sqrt(x * x + z * z) <= world.WildInner + 1e-6, `{area.Id} path stays in town`)
						for plot = 1, Config.Plots.Count do
							local gap = WorldLayout.distanceToBox(x, z, WorldLayout.plotBox(Config.Plots, plot))
							local need = if isStreet then street.HalfWidth else clearance
							expect.truthy(gap >= need - 1e-6, `{area.Id} path {gap} studs from plot {plot}`)
						end
					end
				end
			end
		end,
	},
	{
		Name = "landmarks: known props, inside the ring, off the paths and the stream, apart from each other",
		Run = function()
			for index, structure in WildLayout.Structures do
				local label = `{structure.Prop} #{index}`
				expect.truthy(MapPropConfig.Props[structure.Prop] ~= nil, `{label} is a known prop`)
				local box = WildLayout.box(structure, props)
				for _, corner in boxCorners(box) do
					local x, z = corner[1], corner[2]
					expect.truthy(WorldLayout.inWild(world, x, z, 2), `{label} inside the ring`)
					expect.truthy(not WorldLayout.inStream(world, x, z, 3), `{label} out of the stream`)
					local path = WildLayout.pathDistance(areas, x, z)
					expect.truthy(path > WildLayout.PathHalfWidth, `{label} blocks a path ({path})`)
				end
				for other = index + 1, #WildLayout.Structures do
					local second = WildLayout.Structures[other]
					local ox, oz = WildLayout.position(second)
					local distance = math.sqrt((box.X - ox) ^ 2 + (box.Z - oz) ^ 2)
					local needed = MapPropConfig.radius(structure.Prop) + MapPropConfig.radius(second.Prop)
					expect.truthy(distance >= needed, `{label} overlaps {second.Prop} #{other}`)
				end
			end
		end,
	},
	{
		Name = "spawn grid covers every area, avoids landmarks and the stream",
		Run = function()
			local perArea: { [string]: number } = {}
			local seen: { [string]: boolean } = {}
			local boxes = WildLayout.boxes(props)
			for _, point in grid do
				perArea[point.Area] = (perArea[point.Area] or 0) + 1
				expect.truthy(WorldLayout.inWild(world, point.X, point.Z, world.SpawnEdgeMargin), "inside the ring")
				expect.truthy(not WorldLayout.inStream(world, point.X, point.Z, 0), "not in the stream")
				for _, box in boxes do
					expect.truthy(WorldLayout.distanceToBox(point.X, point.Z, box) >= world.SpawnClearance, "clear of landmarks")
				end
				local key = `{point.X},{point.Z}`
				expect.truthy(not seen[key], "unique points")
				seen[key] = true
			end
			for _, area in areas do
				expect.truthy((perArea[area.Id] or 0) >= 200, `{area.Id} has {perArea[area.Id]} spawn points`)
			end
		end,
	},
	{
		Name = "anywhere in the wild has signal spots 25-90 studs away",
		Run = function()
			math.randomseed(4)
			local signals = Config.Signals
			for _ = 1, 300 do
				local angle = math.random() * 360
				local radius = world.WildInner + math.random() * (world.WildOuter - world.WildInner)
				local x, z = WorldLayout.polar(angle, radius)
				local inBand = 0
				for _, point in grid do
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
		Name = "travel stays short: every plot and the hub walk the street to the wild gate within the limit",
		Run = function()
			local street = Config.Plots.Street
			for index = 1, Config.Plots.Count do
				-- Out the entrance to the curb, then down the street to the gate.
				local along = WorldLayout.plotStreet(Config.Plots, index)
				local walk = (Config.Plots.Size / 2) + (world.WildInner - along)
				local seconds = walk / world.WalkSpeed
				expect.truthy(seconds <= world.MaxTravelSeconds, `plot {index} -> wild gate: {seconds} s`)
			end
			local hubWalk = world.WildInner - street.HubAt
			expect.truthy(hubWalk / world.WalkSpeed <= world.MaxHubTravelSeconds, "hub -> wild gate")
			local gx, gz = WorldLayout.streetGate(Config.Plots, world, 0)
			expect.near(math.sqrt(gx * gx + gz * gz), world.WildInner, 1e-6, "gate on the ring")
			expect.equal((WorldLayout.areaAt(areas, world, gx, gz)), "HauntedForest", "the gate opens on the forest")
			-- Hub space: -Z points down the street toward the gate.
			local hx, hz = WorldLayout.hubPosition(Config.Plots)
			local fx, fz = WorldLayout.fromHub(Config.Plots, 0, -10)
			local ax = WorldLayout.toStreet(street, fx, fz) - WorldLayout.toStreet(street, hx, hz)
			expect.near(ax, 10, 1e-6, "hub -Z points down the street")
			local x, z = WorldLayout.wildEntry(world, 0, 0, Config.Travel.WildDepth)
			expect.near(x, world.WildInner + Config.Travel.WildDepth, 1e-9, "from the center: east")
			expect.near(z, 0, 1e-9, "from the center: z")
			x, z = WorldLayout.wildEntry(world, 0, -2000, 10)
			expect.near(z, -(world.WildOuter - 10), 1e-9, "outside the map clamps back in")
			expect.near(x, 0, 1e-9, "same direction")
		end,
	},
	{
		Name = "map props: 29 models, known fallbacks, sane sizes, scatter uses known props",
		Run = function()
			local count = 0
			local kinds: { [string]: boolean } = {}
			for _, kind in MapPropConfig.FallbackKinds do
				kinds[kind] = true
			end
			for id, prop in MapPropConfig.Props do
				count += 1
				expect.truthy(kinds[prop.Fallback], `{id} fallback {prop.Fallback}`)
				for _, value in prop.Size do
					expect.truthy(value > 0 and value <= 80, `{id} size`)
				end
				expect.truthy(prop.Collide == "Box" or prop.Collide == "None", `{id} collide mode`)
			end
			expect.equal(count, 37, "prop count (the Tripo list + 8 Creator Store imports)")
			for areaId, rules in WildLayout.Scatter do
				local known = false
				for _, area in areas do
					known = known or area.Id == areaId
				end
				expect.truthy(known, `{areaId} is an area`)
				for _, rule in rules do
					expect.truthy(MapPropConfig.Props[rule.Prop] ~= nil, `{areaId} scatters {rule.Prop}`)
					expect.truthy(rule.Density > 0, `{rule.Prop} density`)
				end
			end
		end,
	},
	{
		Name = "shrine gate posts are solid but leave a walkable doorway",
		Run = function()
			local gate = MapPropConfig.Props.ShrineGate
			local posts = gate.Posts
			expect.truthy(posts ~= nil, "ShrineGate has post data")
			assert(posts, "ShrineGate.Posts")
			-- A character is about 2 studs wide and 5 tall, and jumps about 7 studs.
			expect.truthy(posts.Inner * 2 >= 8, `doorway {posts.Inner * 2} studs wide`)
			expect.truthy(posts.Beam >= 11, `crossbeam clearance {posts.Beam} studs`)
			expect.truthy(posts.Outer > posts.Inner and posts.Outer <= gate.Size[1] / 2, "posts inside the gate")
			expect.truthy(posts.Beam + posts.BeamH <= gate.Size[2], "beam under the gate top")
			expect.truthy(posts.Depth > 0 and posts.Depth <= gate.Size[3], "post depth")
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
