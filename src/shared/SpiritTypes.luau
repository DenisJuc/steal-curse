-- Spirit types (replace the old Edge / Deep / Heart rings). Every signal spawns as one type; the
-- farther from the hub, the better the odds of a stronger one. The type sets the bind time, the
-- bonus rolls and the orb's look, and maps to a reward band (Edge/Deep/Heart) so mastery XP,
-- bounties and the streak keep working. Pure (no Roblox APIs) so Lune tests cover it.

local SpiritTypes = {}

export type Id = "Wisp" | "Restless" | "Vengeful"

export type Options = {
	Enabled: boolean,
	Order: { string },
	Types: { [string]: any },
	-- { UpTo = radius (studs from hub center, nil = rest), Weights = { [Id] = weight } }, ascending.
	SpawnWeights: { any },
}

function SpiritTypes.weightsAt(radius: number, options: Options): { [string]: number }
	for _, row in options.SpawnWeights do
		if row.UpTo == nil or radius <= row.UpTo then
			return row.Weights
		end
	end
	return options.SpawnWeights[#options.SpawnWeights].Weights
end

-- `roll` is a number in [0, 1).
function SpiritTypes.pick(radius: number, roll: number, options: Options): string
	local weights = SpiritTypes.weightsAt(radius, options)
	local total = 0
	for _, id in options.Order do
		total += weights[id] or 0
	end
	local target = roll * total
	for _, id in options.Order do
		target -= weights[id] or 0
		if target < 0 then
			return id
		end
	end
	return options.Order[1]
end

function SpiritTypes.get(id: string?, options: Options): any
	return options.Types[id or ""] or options.Types[options.Order[1]]
end

return SpiritTypes
