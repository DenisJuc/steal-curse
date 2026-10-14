-- Lift the Curse rules (Config.Curse, WildLayout.CursedShrines). Pure (shrines and settings passed
-- in) so Lune tests cover them; CurseService applies them. `cleansed` = { [shrineId] = time }.

local Curse = {}

export type Shrine = { Id: string, Area: string }
export type Zone = { Title: string, Lantern: string }
export type Options = {
	CEMinutes: number,
	MinCE: number,
	PurifiedBonus: number,
	Zones: { [string]: Zone },
}

-- Cleansed and total shrines in `area`.
function Curse.progress(cleansed: { [string]: any }, shrines: { Shrine }, area: string): (number, number)
	local done, total = 0, 0
	for _, shrine in shrines do
		if shrine.Area == area then
			total += 1
			if cleansed[shrine.Id] then
				done += 1
			end
		end
	end
	return done, total
end

-- 0..1: how much of `area`'s curse is lifted (drives the fog).
function Curse.lifted(cleansed: { [string]: any }, shrines: { Shrine }, area: string): number
	local done, total = Curse.progress(cleansed, shrines, area)
	return if total > 0 then done / total else 0
end

function Curse.purified(cleansed: { [string]: any }, shrines: { Shrine }, area: string): boolean
	local done, total = Curse.progress(cleansed, shrines, area)
	return total > 0 and done == total
end

-- Titles of every purified zone ([areaId] = title).
function Curse.titles(cleansed: { [string]: any }, shrines: { Shrine }, options: Options): { [string]: string }
	local titles = {}
	for area, zone in options.Zones do
		if Curse.purified(cleansed, shrines, area) then
			titles[area] = zone.Title
		end
	end
	return titles
end

-- Bonus-roll factor for captures in `area` (1 until it is purified).
function Curse.bonus(cleansed: { [string]: any }, shrines: { Shrine }, area: string, options: Options): number
	return if Curse.purified(cleansed, shrines, area) then options.PurifiedBonus else 1
end

-- CE for cleansing a shrine at `incomePerSec` (CEMinutes of income), never below the floor.
function Curse.ceReward(incomePerSec: number, options: Options): number
	return math.max(options.MinCE, math.floor(options.CEMinutes * 60 * incomePerSec))
end

return Curse
