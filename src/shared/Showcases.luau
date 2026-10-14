-- Showcase rules (GDD 6.7, 10.2). Pure (config passed in) so Lune can test them. Saved state:
--   { Active = showcaseId or "", Owned = { [showcaseId] = level }, AccessoriesOff = { [accessoryId] = true } }
-- Only the active, owned Showcase gives a buff, and the buff depends on its level only.

local Showcases = {}

export type Level = { Income: number, Luck: number, Cost: number? }
export type Accessory = { Id: string, Name: string, RelicId: string }
export type Unlock = {
	Kind: string,
	Price: number?,
	RelicId: string?,
	Milestone: string?,
	Area: string?,
	Level: number?,
}
export type Showcase = { Id: string, Unlock: Unlock, Accessories: { Accessory } }

export type State = {
	Active: string,
	Owned: { [string]: number },
	AccessoriesOff: { [string]: boolean },
}

-- What a player has, for unlock checks: discovered relic ids, reached or claimed milestone ids
-- and zone mastery levels by area id.
export type Progress = {
	Discovered: { [string]: any },
	Milestones: { [string]: any },
	Mastery: { [string]: number }?,
}

-- (income bonus, luck bonus) of the active Showcase; (0, 0) when none is active.
function Showcases.bonus(state: State, levels: { Level }): (number, number)
	local level = state.Owned[state.Active]
	local stats = level and levels[level]
	if not stats then
		return 0, 0
	end
	return stats.Income, stats.Luck
end

-- CE to go from `level` to `level + 1`; nil at max level.
function Showcases.upgradeCost(levels: { Level }, level: number): number?
	local nextLevel = levels[level + 1]
	return if nextLevel then nextLevel.Cost else nil
end

-- True when a relic, Codex or mastery unlock condition is met (CE unlocks are bought, never
-- automatic).
function Showcases.freeUnlockMet(showcase: Showcase, progress: Progress): boolean
	local unlock = showcase.Unlock
	if unlock.Kind == "Relic" then
		return unlock.RelicId ~= nil and progress.Discovered[unlock.RelicId] ~= nil
	elseif unlock.Kind == "Codex" then
		return unlock.Milestone ~= nil and progress.Milestones[unlock.Milestone] ~= nil
	elseif unlock.Kind == "Mastery" then
		local levels = progress.Mastery
		return levels ~= nil and unlock.Area ~= nil and (levels[unlock.Area] or 0) >= (unlock.Level or math.huge)
	end
	return false
end

-- Accessories are unlocked by discovering their relic (any mutation). Cosmetic only.
function Showcases.accessoryUnlocked(accessory: Accessory, progress: Progress): boolean
	return progress.Discovered[accessory.RelicId] ~= nil
end

-- Accessory ids shown on a Showcase: unlocked and not switched off.
function Showcases.visibleAccessories(state: State, showcase: Showcase, progress: Progress): { string }
	local list = {}
	for _, accessory in showcase.Accessories do
		if Showcases.accessoryUnlocked(accessory, progress) and not state.AccessoriesOff[accessory.Id] then
			table.insert(list, accessory.Id)
		end
	end
	return list
end

return Showcases
