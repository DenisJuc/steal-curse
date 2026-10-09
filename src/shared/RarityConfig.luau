-- Rarity tiers in ascending order (GDD 5.2).
-- Denominator = base "1 in X" chance of rolling this tier OR HIGHER at 1x luck.

local RarityConfig = {}

export type Tier = {
	Id: string,
	Name: string,
	Denominator: number,
	Color: string,
}

RarityConfig.Tiers = {
	{ Id = "Common", Name = "Common", Denominator = 1, Color = "#B9C0C9" },
	{ Id = "Uncommon", Name = "Uncommon", Denominator = 4, Color = "#5FD068" },
	{ Id = "Rare", Name = "Rare", Denominator = 45, Color = "#4FA3FF" },
	{ Id = "Epic", Name = "Epic", Denominator = 500, Color = "#B05CFF" },
	{ Id = "Legendary", Name = "Legendary", Denominator = 25000, Color = "#FFB12E" },
	{ Id = "Mythic", Name = "Mythic", Denominator = 1e7, Color = "#FF4F6D" },
	{ Id = "Celestial", Name = "Celestial", Denominator = 1e11, Color = "#7FF3FF" },
	{ Id = "Cosmic", Name = "Cosmic", Denominator = 1.32e15, Color = "#FF6BF1" },
} :: { Tier }

RarityConfig.IndexById = {} :: { [string]: number }
for index, tier in RarityConfig.Tiers do
	RarityConfig.IndexById[tier.Id] = index
end

function RarityConfig.Get(tierId: string): Tier?
	local index = RarityConfig.IndexById[tierId]
	return if index then RarityConfig.Tiers[index] else nil
end

return RarityConfig
