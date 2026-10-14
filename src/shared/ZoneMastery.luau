-- Zone mastery: XP per capture in a zone, 10 levels, zone-only perks and per-level unlocks
-- (Config.Mastery). Pure (no Roblox APIs) so Lune tests cover it; MasteryService applies it.

local ZoneMastery = {}

export type Perk = { Level: number, Hold: number?, Pulse: number?, Idle: number? }
export type Zone = {
	Lanterns: { { Level: number, Id: string } },
	Title: string,
	Showcase: string,
}
export type Options = {
	Xp: { [string]: number },
	Levels: { number },
	Perks: { Perk },
	TitleAt: number,
	ShowcaseAt: number,
	Zones: { [string]: Zone },
}

-- What the perks add up to at a level: bind time factor (< 1 is faster), Spirit Sight range
-- factor and extra Hunt Streak seconds.
export type Perks = { Hold: number, Pulse: number, Idle: number }

-- Unlocks earned between two levels.
export type Unlocks = { Lanterns: { string }, Title: string?, Showcase: string? }

function ZoneMastery.xpFor(band: string, options: Options): number
	return options.Xp[band] or 1
end

-- Level for `xp` (0..#Levels), XP into the current level and the size of the next one
-- (0 at max level).
function ZoneMastery.level(xp: number, options: Options): (number, number, number)
	local level = 0
	local floor = 0
	for index, needed in options.Levels do
		if xp >= needed then
			level = index
			floor = needed
		else
			return level, xp - floor, needed - floor
		end
	end
	return level, 0, 0
end

function ZoneMastery.perks(level: number, options: Options): Perks
	local result = { Hold = 1, Pulse = 1, Idle = 0 }
	for _, perk in options.Perks do
		if level >= perk.Level then
			result.Hold -= perk.Hold or 0
			result.Pulse += perk.Pulse or 0
			result.Idle += perk.Idle or 0
		end
	end
	return result
end

-- The first perk above `level`, or nil at the last one.
function ZoneMastery.nextPerk(level: number, options: Options): Perk?
	for _, perk in options.Perks do
		if perk.Level > level then
			return perk
		end
	end
	return nil
end

function ZoneMastery.perkText(perk: Perk): string
	if perk.Hold then
		return `-{math.floor(perk.Hold * 100 + 0.5)}% bind time`
	elseif perk.Pulse then
		return `+{math.floor(perk.Pulse * 100 + 0.5)}% Spirit Sight range`
	elseif perk.Idle then
		return `+{perk.Idle}s Hunt Streak timer`
	end
	return ""
end

-- Everything unlocked going from level `from` to level `to` in `zoneId`.
function ZoneMastery.unlocks(zoneId: string, from: number, to: number, options: Options): Unlocks
	local result: Unlocks = { Lanterns = {} }
	local zone = options.Zones[zoneId]
	if not zone or to <= from then
		return result
	end
	for _, lantern in zone.Lanterns do
		if lantern.Level > from and lantern.Level <= to then
			table.insert(result.Lanterns, lantern.Id)
		end
	end
	if options.TitleAt > from and options.TitleAt <= to then
		result.Title = zone.Title
	end
	if options.ShowcaseAt > from and options.ShowcaseAt <= to then
		result.Showcase = zone.Showcase
	end
	return result
end

-- Mastery titles earned at these levels (by zone id), in `order` (zone ids).
function ZoneMastery.titles(levels: { [string]: number }, order: { string }, options: Options): { string }
	local list = {}
	for _, zoneId in order do
		local zone = options.Zones[zoneId]
		if zone and (levels[zoneId] or 0) >= options.TitleAt then
			table.insert(list, zone.Title)
		end
	end
	return list
end

return ZoneMastery
