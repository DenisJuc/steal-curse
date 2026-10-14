-- Player titles (TitleService, Spirit Wardrobe): the earned list from every source and which one
-- is shown for the player's choice: a title, Auto (the first earned) or Off. Pure (no Roblox APIs)
-- so Lune tests cover it.

local Titles = {}

Titles.Auto = "Auto"
Titles.Off = "Off"

-- Every title from `groups` (best source first), in order, without duplicates.
function Titles.earned(groups: { { string } }): { string }
	local list, seen = {}, {}
	for _, group in groups do
		for _, title in group do
			if not seen[title] then
				seen[title] = true
				table.insert(list, title)
			end
		end
	end
	return list
end

function Titles.valid(choice: any, earned: { string }): boolean
	return choice == Titles.Auto or choice == Titles.Off or (type(choice) == "string" and table.find(earned, choice) ~= nil)
end

-- The title to show: nil when Off or nothing is earned; Auto (or a title no longer earned) falls
-- back to the first earned one.
function Titles.shown(choice: string, earned: { string }): string?
	if choice == Titles.Off then
		return nil
	end
	if choice ~= Titles.Auto and table.find(earned, choice) then
		return choice
	end
	return earned[1]
end

-- One title and how it is earned, for the Wardrobe. Have/Need is the progress ("3 / 5 shrines").
export type Entry = {
	Title: string,
	Source: string,
	Have: number,
	Need: number,
	Unit: string,
	Earned: boolean,
}

-- Every title from `groups` once (the first source wins): earned ones first in source order, then
-- the locked ones, closest to done first.
function Titles.catalog(groups: { { Entry } }): { Entry }
	local earned, locked, seen = {}, {}, {}
	for _, group in groups do
		for _, entry in group do
			if not seen[entry.Title] then
				seen[entry.Title] = true
				table.insert(if entry.Earned then earned else locked, entry)
			end
		end
	end
	local order = {}
	for index, entry in locked do
		order[entry] = index
	end
	local function fraction(entry: Entry): number
		return if entry.Need > 0 then math.clamp(entry.Have / entry.Need, 0, 1) else 0
	end
	table.sort(locked, function(a, b)
		local fa, fb = fraction(a), fraction(b)
		if fa ~= fb then
			return fa > fb
		end
		return order[a] < order[b]
	end)
	for _, entry in locked do
		table.insert(earned, entry)
	end
	return earned
end

return Titles
