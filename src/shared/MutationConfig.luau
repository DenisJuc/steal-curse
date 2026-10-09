-- Mutation Resonance (GDD 8). Provisional, editable values from the approved plan.
-- Rank 0 = no mutations. Each rank unlocks one more variant and raises the total chance.
-- A relic has at most one mutation, rolled once at discovery after the relic itself.

local MutationConfig = {}

export type Mutation = {
	Id: string,
	Name: string,
	UnlockRank: number,
	Weight: number,
	IncomeMultiplier: number,
	Color: string,
}

MutationConfig.MaxRank = 5

-- Total chance that a discovery is mutated, by Mutation Resonance rank.
MutationConfig.ChanceByRank = { [0] = 0, [1] = 0.10, [2] = 0.20, [3] = 0.30, [4] = 0.40, [5] = 0.50 }

-- Weight = relative chance among UNLOCKED variants once a mutation happens.
MutationConfig.Mutations = {
	{ Id = "Golden", Name = "Golden", UnlockRank = 1, Weight = 30, IncomeMultiplier = 1.5, Color = "#FFD34D" },
	{ Id = "Corrupted", Name = "Corrupted", UnlockRank = 2, Weight = 22, IncomeMultiplier = 2, Color = "#A45CFF" },
	{ Id = "Bloodmoon", Name = "Bloodmoon", UnlockRank = 3, Weight = 18, IncomeMultiplier = 2.5, Color = "#FF4050" },
	{ Id = "Divine", Name = "Divine", UnlockRank = 4, Weight = 15, IncomeMultiplier = 3, Color = "#FFF2B8" },
	{ Id = "Abyssal", Name = "Abyssal", UnlockRank = 5, Weight = 15, IncomeMultiplier = 4, Color = "#6E7BFF" },
} :: { Mutation }

MutationConfig.ById = {} :: { [string]: Mutation }
for _, mutation in MutationConfig.Mutations do
	MutationConfig.ById[mutation.Id] = mutation
end

function MutationConfig.ChanceAt(rank: number): number
	return MutationConfig.ChanceByRank[math.clamp(math.floor(rank), 0, MutationConfig.MaxRank)] or 0
end

return MutationConfig
