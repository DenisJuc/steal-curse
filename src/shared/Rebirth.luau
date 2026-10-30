-- Rebirth rules (Config.Rebirth). Pure (settings passed in) so the server, the menu, the
-- progression sim and Lune tests share them. A Rebirth spends Rebirth.cost(n) CE and grants
-- permanent income/luck multipliers. Reset behaviour depends on mode:
--   "Live"  — production: CE=0, pedestal levels→1, skill ranks→0
--   "BPlus" — Studio SoftCap_P4: CE=0 only; skills, pedestals, Collection/Fusion kept

local Rebirth = {}

export type Settings = {
	BaseCost: number,
	CostGrowth: number,
	IncomeGrowth: number,
	LuckGrowth: number,
}

export type Model = "Live" | "BPlus"

-- CE needed for the next Rebirth when `rebirths` are done.
function Rebirth.cost(settings: Settings, rebirths: number): number
	return settings.BaseCost * settings.CostGrowth ^ rebirths
end

function Rebirth.incomeMultiplier(settings: Settings, rebirths: number): number
	return settings.IncomeGrowth ^ rebirths
end

function Rebirth.luckMultiplier(settings: Settings, rebirths: number): number
	return settings.LuckGrowth ^ rebirths
end

-- Applies one Rebirth to saved data in place (caller checked the cost).
-- Always: Rebirths += 1, CE = 0. Permanent mults come from the new count (no double-grant).
-- Live additionally resets pedestal levels and skill ranks. BPlus preserves both.
function Rebirth.apply(data: any, mode: Model?)
	local model: Model = if mode == "BPlus" then "BPlus" else "Live"
	data.Rebirths = (tonumber(data.Rebirths) or 0) + 1
	data.CE = 0
	if model == "BPlus" then
		return
	end
	for _, pedestal in data.Pedestals do
		pedestal.Level = 1
	end
	for id in data.Skills do
		data.Skills[id] = 0
	end
end

return Rebirth
