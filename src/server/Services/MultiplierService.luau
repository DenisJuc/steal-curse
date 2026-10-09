-- Multiplier stacks (GDD 5.2). Each kind ("Luck" now; income, speed... later) is the PRODUCT of
-- every registered source, so new sources (Codex, Showcases, consumables, events) plug in without
-- touching the roll code. Totals are mirrored as "<Kind>Multiplier" attributes for the UI.

local GameEvents = require(script.Parent.GameEvents)

local MultiplierService = {}

type Source = {
	Name: string,
	Get: (Player) -> number,
}

local sources: { [string]: { Source } } = {}

function MultiplierService.Register(kind: string, name: string, get: (Player) -> number)
	local list = sources[kind]
	if not list then
		list = {}
		sources[kind] = list
	end
	table.insert(list, { Name = name, Get = get })
end

function MultiplierService.Get(player: Player, kind: string): number
	local total = 1
	for _, source in sources[kind] or {} do
		total *= source.Get(player)
	end
	return total
end

-- Each source's current factor, for debug output.
function MultiplierService.Breakdown(player: Player, kind: string): { { Name: string, Value: number } }
	local list = {}
	for _, source in sources[kind] or {} do
		table.insert(list, { Name = source.Name, Value = source.Get(player) })
	end
	return list
end

-- Call after anything that changes a source value (skill rank, debug override...).
function MultiplierService.Refresh(player: Player)
	for kind in sources do
		player:SetAttribute(`{kind}Multiplier`, MultiplierService.Get(player, kind))
	end
	GameEvents.Fire("MultipliersChanged", player)
end

return MultiplierService
