-- Zone luck gates (Config.ZoneGates): which (area, depth band) cells of the wild a player may stand
-- in for their Lasting Luck, the nearest open spot to push them back to, and the borders between
-- open and locked cells (what the client draws as seal lines). Pure (no Roblox APIs) so Lune tests
-- cover it. The town (inside World.WildInner) is always open. Areas split the ring by angle; the
-- dominant area (WorldLayout.areaAt, no blending) owns a point. Bands are by radius.

local WorldLayout = if script ~= nil then require(script.Parent.WorldLayout) else require("./WorldLayout")

local ZoneGates = {}

export type Band = "Edge" | "Deep" | "Heart"
export type Context = {
	Areas: { WorldLayout.Area },
	World: WorldLayout.World,
	Bands: { EdgeUntil: number, DeepUntil: number },
	Gates: { Enabled: boolean, Required: { [string]: { [string]: number } } },
}
export type Border = {
	-- "Arc": a circle piece at Radius from angle From to To (degrees, To > From).
	-- "Ray": a straight line at Angle from radius From to To.
	Kind: "Arc" | "Ray",
	Radius: number?,
	Angle: number?,
	From: number,
	To: number,
	-- The locked cell behind this border and the luck it needs.
	Area: string,
	Band: Band,
	Required: number,
}

ZoneGates.BANDS = { "Edge", "Deep", "Heart" } :: { Band }

local EPSILON = 1e-9

local function angleDelta(a: number, b: number): number
	local delta = (a - b) % 360
	return if delta > 180 then delta - 360 else delta
end

-- Radius range of a band: Edge starts at the wild's inner edge, Heart ends at its outer edge.
function ZoneGates.bandRange(ctx: Context, band: Band): (number, number)
	if band == "Edge" then
		return ctx.World.WildInner, ctx.Bands.EdgeUntil
	elseif band == "Deep" then
		return ctx.Bands.EdgeUntil, ctx.Bands.DeepUntil
	end
	return ctx.Bands.DeepUntil, ctx.World.WildOuter
end

-- Half-widths (degrees) of an area's slice toward lower and higher angles.
function ZoneGates.sliceOf(ctx: Context, areaId: string): (number, number, number)
	local center, low, high = 0, 180, 180
	for _, area in ctx.Areas do
		if area.Id == areaId then
			center = area.AngleDegrees
		end
	end
	for _, area in ctx.Areas do
		if area.Id ~= areaId then
			local delta = angleDelta(area.AngleDegrees, center)
			if delta < 0 then
				low = math.min(low, -delta / 2)
			elseif delta > 0 then
				high = math.min(high, delta / 2)
			end
		end
	end
	return center, low, high
end

-- The cell at (x, z): area and band, or nil in the town.
function ZoneGates.cellAt(ctx: Context, x: number, z: number): (string?, Band?)
	local r = math.sqrt(x * x + z * z)
	if r < ctx.World.WildInner then
		return nil, nil
	end
	local area = WorldLayout.areaAt(ctx.Areas, ctx.World, x, z)
	local band: Band = if r <= ctx.Bands.EdgeUntil then "Edge" elseif r <= ctx.Bands.DeepUntil then "Deep" else "Heart"
	return area, band
end

function ZoneGates.required(ctx: Context, area: string, band: string): number
	local byBand = ctx.Gates.Required[area]
	return (byBand and byBand[band]) or 1
end

function ZoneGates.allowedCell(ctx: Context, luck: number, area: string, band: string): boolean
	if not ctx.Gates.Enabled then
		return true
	end
	return luck + EPSILON >= ZoneGates.required(ctx, area, band)
end

function ZoneGates.allowedAt(ctx: Context, luck: number, x: number, z: number): boolean
	local area, band = ZoneGates.cellAt(ctx, x, z)
	if not area or not band then
		return true
	end
	return ZoneGates.allowedCell(ctx, luck, area, band)
end

-- The saved peak after seeing `lasting`: never lower than before, never below 1.
function ZoneGates.updatePeak(peak: any, lasting: number): number
	local before = if type(peak) == "number" and peak == peak then peak else 0
	return math.max(before, lasting, 1)
end

-- Luck the gates check: the current Lasting Luck or the highest ever reached.
function ZoneGates.gateLuck(lasting: number, peak: any): number
	return math.max(lasting, if type(peak) == "number" and peak == peak then peak else 0)
end

-- Clamps (x, z) into a cell, `inside` studs from its edges.
local function clampInto(ctx: Context, area: string, band: Band, x: number, z: number, inside: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	local low, high = ZoneGates.bandRange(ctx, band)
	local radius = math.clamp(r, low + inside, math.max(low + inside, high - inside))
	local center, left, right = ZoneGates.sliceOf(ctx, area)
	local margin = math.deg(inside / math.max(radius, 1))
	local delta = angleDelta(WorldLayout.angleOf(x, z), center)
	delta = math.clamp(delta, -left + margin, math.max(-left + margin, right - margin))
	return WorldLayout.polar(center + delta, radius)
end

-- Nearest open spot to (x, z), `inside` studs within an open cell (or the town unless wildOnly).
function ZoneGates.nearestAllowed(
	ctx: Context,
	luck: number,
	x: number,
	z: number,
	inside: number,
	wildOnly: boolean?
): (number, number)
	local r = math.sqrt(x * x + z * z)
	local bestX, bestZ, bestDistance = x, z, math.huge
	if not wildOnly then
		if r > 1e-6 then
			local townR = math.min(r, ctx.World.WildInner - inside)
			bestX, bestZ = x / r * townR, z / r * townR
		end
		bestDistance = math.sqrt((bestX - x) ^ 2 + (bestZ - z) ^ 2)
	end
	for _, area in ctx.Areas do
		for _, band in ZoneGates.BANDS do
			if ZoneGates.allowedCell(ctx, luck, area.Id, band) then
				local cx, cz = clampInto(ctx, area.Id, band, x, z, inside)
				local distance = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
				if distance < bestDistance then
					bestX, bestZ, bestDistance = cx, cz, distance
				end
			end
		end
	end
	return bestX, bestZ
end

-- Whether a bounty filter ({ Area = id } / { MinBand = band }) can be done with `luck`, and if
-- not, the lowest luck that opens it.
local BAND_RANK = { Edge = 1, Deep = 2, Heart = 3 }
function ZoneGates.filterReachable(ctx: Context, luck: number, filter: { [string]: any }?): (boolean, number?)
	if not filter or not ctx.Gates.Enabled or not (filter.Area or filter.MinBand) then
		return true, nil
	end
	local need = math.huge
	for _, area in ctx.Areas do
		if filter.Area and filter.Area ~= area.Id then
			continue
		end
		for _, band in ZoneGates.BANDS do
			if filter.MinBand and BAND_RANK[band] < (BAND_RANK[filter.MinBand] or 1) then
				continue
			end
			local required = ZoneGates.required(ctx, area.Id, band)
			if luck + EPSILON >= required then
				return true, nil
			end
			need = math.min(need, required)
		end
	end
	return false, if need < math.huge then need else nil
end

-- Every border between an open and a locked cell (or the town and a locked Edge).
function ZoneGates.borders(ctx: Context, luck: number): { Border }
	local list: { Border } = {}
	if not ctx.Gates.Enabled then
		return list
	end
	local function locked(area: string, band: Band): boolean
		return not ZoneGates.allowedCell(ctx, luck, area, band)
	end
	for _, area in ctx.Areas do
		local center, left, right = ZoneGates.sliceOf(ctx, area.Id)
		local from, to = center - left, center + right
		-- Town -> Edge, Edge -> Deep, Deep -> Heart.
		local previousOpen = true
		local radii = { ctx.World.WildInner, ctx.Bands.EdgeUntil, ctx.Bands.DeepUntil }
		for index, band in ZoneGates.BANDS do
			local isLocked = locked(area.Id, band)
			if isLocked and previousOpen then
				table.insert(list, {
					Kind = "Arc",
					Radius = radii[index],
					From = from,
					To = to,
					Area = area.Id,
					Band = band,
					Required = ZoneGates.required(ctx, area.Id, band),
				})
			end
			previousOpen = not isLocked
		end
		-- Side border toward the higher-angle neighbour, per band (each pair once).
		local neighbour = nil
		for _, other in ctx.Areas do
			if other.Id ~= area.Id and math.abs(angleDelta(other.AngleDegrees, center) - 2 * right) < 1e-6 then
				neighbour = other
			end
		end
		if neighbour then
			for _, band in ZoneGates.BANDS do
				local mine, theirs = locked(area.Id, band), locked(neighbour.Id, band)
				if mine ~= theirs then
					local low, high = ZoneGates.bandRange(ctx, band)
					local lockedArea = if mine then area.Id else neighbour.Id
					table.insert(list, {
						Kind = "Ray",
						Angle = to % 360,
						From = low,
						To = high,
						Area = lockedArea,
						Band = band,
						Required = ZoneGates.required(ctx, lockedArea, band),
					})
				end
			end
		end
	end
	return list
end

return ZoneGates
