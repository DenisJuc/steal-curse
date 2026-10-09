-- Multiplier stacks (GDD 5.2, 6.2). New sources (Codex, Showcases, consumables, events, skills)
-- plug in here without touching roll or income code. Totals are mirrored as "<Kind>Multiplier"
-- attributes for the UI.
--   "Product" kinds (Luck): total = product of every source factor.
--   "Additive" kinds (Income): total = 1 + sum of every source bonus (GDD 6.2: global income
--   bonuses add together, then apply once, so they can't compound by accident).

local GameEvents = require(script.Parent.GameEvents)

local MultiplierService = {}

export type Mode = "Product" | "Additive"

type Source = {
	Name: string,
	Get: (Player) -> number,
}

local modes: { [string]: Mode } = {}
local sources: { [string]: { Source } } = {}

function MultiplierService.DefineKind(kind: string, mode: Mode)
	modes[kind] = mode
	sources[kind] = sources[kind] or {}
end

-- Product kinds: `get` returns a factor (1 = no effect). Additive kinds: a bonus (0 = no effect).
function MultiplierService.Register(kind: string, name: string, get: (Player) -> number)
	assert(modes[kind], `multiplier kind {kind} is not defined`)
	table.insert(sources[kind], { Name = name, Get = get })
end

function MultiplierService.Get(player: Player, kind: string): number
	local mode = modes[kind]
	assert(mode, `multiplier kind {kind} is not defined`)
	if mode == "Additive" then
		local bonus = 0
		for _, source in sources[kind] do
			bonus += source.Get(player)
		end
		return 1 + bonus
	end
	local total = 1
	for _, source in sources[kind] do
		total *= source.Get(player)
	end
	return total
end

-- Each source's current value, for debug output.
function MultiplierService.Breakdown(player: Player, kind: string): { { Name: string, Value: number } }
	local list = {}
	for _, source in sources[kind] or {} do
		table.insert(list, { Name = source.Name, Value = source.Get(player) })
	end
	return list
end

-- Call after anything that changes a source value (skill rank, debug override...).
function MultiplierService.Refresh(player: Player)
	for kind in modes do
		player:SetAttribute(`{kind}Multiplier`, MultiplierService.Get(player, kind))
	end
	GameEvents.Fire("MultipliersChanged", player)
end

return MultiplierService
