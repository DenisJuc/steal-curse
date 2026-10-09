-- Saved player data shape. Pure (no Roblox APIs) so Lune tests can load it.
-- Adding a field: add it here (Reconcile fills it for old profiles).
-- Renaming/reshaping a field: bump Version and add a step in Migrations.

local DataTemplate = {}

DataTemplate.Version = 2

export type Item = {
	Uid: number,
	Id: string,
	Mutation: string?,
	At: number,
	Source: string,
	-- Locked copies can't be sold by any path.
	Locked: boolean?,
}

export type RareFind = {
	Id: string,
	Mutation: string?,
	At: number,
	Source: string,
}

-- An owned pedestal. Uid = the displayed inventory item (nil = empty); the item stays in Inventory.
export type Pedestal = {
	Uid: number?,
	Level: number,
	Locked: boolean,
}

export type Data = {
	DataVersion: number,
	TotalScans: number,
	TotalCaptures: number,
	NextUid: number,
	-- Cursed Energy, fractional internally (the UI rounds down).
	CE: number,
	LifetimeCE: number,
	Inventory: { Item },
	-- One entry per OWNED pedestal, in slot order.
	Pedestals: { Pedestal },
	-- Income snapshot refreshed every economy tick; pays offline earnings on the next join.
	Offline: {
		IncomePerMin: number,
		At: number,
	},
	-- Codex discovery keyed by BASE relic id (mutations never create separate entries).
	Discovered: { [string]: number },
	-- Mutations seen per base relic id (item-detail flags, prestige titles): [id][mutation] = time.
	CodexMutations: { [string]: { [string]: number } },
	-- Milestones reached but not yet claimed (kept even if a bigger roster raises the threshold).
	CodexReady: { [string]: number },
	-- Claimed Codex milestones; only these give rewards (never removed): [milestoneId] = time.
	CodexMilestones: { [string]: number },
	-- Favorite relic + mutation keys (AutoSell.favoriteKey); protects future copies from auto-sell.
	Favorites: { [string]: boolean },
	RareHistory: { RareFind },
	Settings: {
		RarityFocus: string,
		Frequency: string,
		AutoDisplay: boolean,
		AutoSell: {
			Tiers: { [string]: string },
			SellAllDuplicates: boolean,
			SellEasierThan: number,
			ProtectFirst: boolean,
			ProtectMutated: boolean,
		},
	},
	Skills: {
		CoreLuck: number,
		FrequencyFocus: number,
		MutationResonance: number,
	},
}

DataTemplate.Template = {
	DataVersion = DataTemplate.Version,
	TotalScans = 0,
	TotalCaptures = 0,
	NextUid = 1,
	CE = 0,
	LifetimeCE = 0,
	Inventory = {},
	Pedestals = {
		{ Level = 1, Locked = false },
		{ Level = 1, Locked = false },
		{ Level = 1, Locked = false },
	},
	Offline = {
		IncomePerMin = 0,
		At = 0,
	},
	Discovered = {},
	CodexMutations = {},
	CodexReady = {},
	CodexMilestones = {},
	Favorites = {},
	RareHistory = {},
	Settings = {
		RarityFocus = "MaxLuck",
		Frequency = "All",
		AutoDisplay = true,
		-- Must equal AutoSell.defaults() (checked by a Lune test).
		AutoSell = {
			Tiers = {
				Common = "Keep",
				Uncommon = "Keep",
				Rare = "Keep",
				Epic = "Keep",
				Legendary = "Keep",
				Mythic = "Keep",
				Celestial = "Keep",
				Cosmic = "Keep",
			},
			SellAllDuplicates = false,
			SellEasierThan = 0,
			ProtectFirst = true,
			ProtectMutated = true,
		},
	},
	Skills = {
		CoreLuck = 0,
		FrequencyFocus = 0,
		MutationResonance = 0,
	},
} :: Data

function DataTemplate.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = DataTemplate.deepCopy(inner)
	end
	return copy :: any
end

function DataTemplate.fresh(): Data
	return DataTemplate.deepCopy(DataTemplate.Template)
end

return DataTemplate
