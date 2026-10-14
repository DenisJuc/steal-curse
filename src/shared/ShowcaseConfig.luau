-- Showcases (GDD 6.7, 10): collectible pose/display setups on the plot's Showcase podium. Every
-- Showcase uses the SAME level table, so equal levels give equal buffs whichever one is chosen;
-- only how it is unlocked and how it looks differ. Only the active Showcase gives its buff, and
-- posing is never needed for it. Pure data (Lune-tested).

local ShowcaseConfig = {}

-- Kind "CE" (bought for Price), "Relic" (discover RelicId), "Codex" (reach Milestone) or
-- "Mastery" (reach zone mastery Level in Area).
export type Unlock = {
	Kind: string,
	Price: number?,
	RelicId: string?,
	Milestone: string?,
	Area: string?,
	Level: number?,
}

export type Accessory = {
	Id: string,
	Name: string,
	-- Discovering this relic (any mutation) unlocks the accessory. Cosmetic only, no buff.
	RelicId: string,
}

export type Showcase = {
	Id: string,
	Name: string,
	Style: string,
	Description: string,
	Unlock: Unlock,
	Accessories: { Accessory },
}

-- Level n: Income and Luck bonus; Cost = CE to reach level n from n - 1 (level 1 comes from the unlock).
ShowcaseConfig.Levels = {
	{ Income = 0.02, Luck = 0.01 },
	{ Income = 0.05, Luck = 0.03, Cost = 200000 },
	{ Income = 0.10, Luck = 0.05, Cost = 20000000 },
	{ Income = 0.15, Luck = 0.10, Cost = 2000000000 },
}

ShowcaseConfig.MaxLevel = #ShowcaseConfig.Levels

ShowcaseConfig.Showcases = {
	{
		Id = "SimpleStance",
		Name = "Simple Stance",
		Style = "Stance",
		Description = "A quiet spirit circle. You stand at its heart while wisps orbit.",
		Unlock = { Kind = "CE", Price = 500000 },
		Accessories = {
			{ Id = "BoneFluteCharm", Name = "Hollo Bait Charm", RelicId = "HolloBait" },
		},
	},
	{
		Id = "CrimsonThrone",
		Name = "Crimson Throne",
		Style = "Throne",
		Description = "A throne of red bone and iron for whoever holds the cursed king's finger.",
		Unlock = { Kind = "Relic", RelicId = "SukanasFinger" },
		Accessories = {
			{ Id = "AshenBanners", Name = "Exploding Tag Banners", RelicId = "ExplodingTag" },
		},
	},
	{
		Id = "GoldenGuardian",
		Name = "Golden Guardian",
		Style = "Guardian",
		Description = "A golden guardian spirit stands watch behind you.",
		Unlock = { Kind = "Codex", Milestone = "Essential60" },
		Accessories = {
			{ Id = "GuardianSigilTome", Name = "Guardian's Grimoire", RelicId = "QuadLeafGrimoire" },
		},
	},
	{
		Id = "ForestGrove",
		Name = "Forest Grove",
		Style = "Stance",
		Description = "The forest's spirits gather around the one who knows its every path.",
		Unlock = { Kind = "Mastery", Area = "HauntedForest", Level = 10 },
		Accessories = {},
	},
	{
		Id = "BellWatch",
		Name = "Bell Watch",
		Style = "Throne",
		Description = "The old village seat, kept for the one who walked every lane after dark.",
		Unlock = { Kind = "Mastery", Area = "AbandonedVillage", Level = 10 },
		Accessories = {},
	},
	{
		Id = "StarCircle",
		Name = "Star Circle",
		Style = "Guardian",
		Description = "An ancient guardian of the ruins stands behind the one who read their stones.",
		Unlock = { Kind = "Mastery", Area = "AncientRuins", Level = 10 },
		Accessories = {},
	},
} :: { Showcase }

ShowcaseConfig.ById = {} :: { [string]: Showcase }
ShowcaseConfig.AccessoryById = {} :: { [string]: Accessory }
ShowcaseConfig.AccessoryOwner = {} :: { [string]: string }
for _, showcase in ShowcaseConfig.Showcases do
	ShowcaseConfig.ById[showcase.Id] = showcase
	for _, accessory in showcase.Accessories do
		ShowcaseConfig.AccessoryById[accessory.Id] = accessory
		ShowcaseConfig.AccessoryOwner[accessory.Id] = showcase.Id
	end
end

return ShowcaseConfig
