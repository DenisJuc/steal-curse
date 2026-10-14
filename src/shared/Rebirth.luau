-- Rebirth rules (Config.Rebirth). Pure (settings passed in) so the server, the menu, the
-- progression sim and Lune tests share them. A Rebirth spends Rebirth.cost(n) CE and resets CE,
-- pedestal levels and skill ranks; every Rebirth multiplies income and luck for good.

local Rebirth = {}

export type Settings = {
	BaseCost: number,
	CostGrowth: number,
	IncomeGrowth: number,
	LuckGrowth: number,
}

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

-- Applies one Rebirth to saved data in place (the caller checked the cost). CE goes to 0, every
-- pedestal back to level 1 (slots, relics and locks stay) and every skill rank to 0.
function Rebirth.apply(data: any)
	data.Rebirths = (tonumber(data.Rebirths) or 0) + 1
	data.CE = 0
	for _, pedestal in data.Pedestals do
		pedestal.Level = 1
	end
	for id in data.Skills do
		data.Skills[id] = 0
	end
end

return Rebirth
