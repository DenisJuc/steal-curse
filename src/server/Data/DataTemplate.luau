-- Saved player data shape. Pure (no Roblox APIs) so Lune tests can load it.
-- Adding a field: add it here (Reconcile fills it for old profiles).
-- Renaming/reshaping a field: bump Version and add a step in Migrations.

local DataTemplate = {}

DataTemplate.Version = 1

export type Item = {
	Uid: number,
	Id: string,
	Mutation: string?,
	At: number,
	Source: string,
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
	RareHistory: { RareFind },
	Settings: {
		RarityFocus: string,
		Frequency: string,
		AutoDisplay: boolean,
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
	RareHistory = {},
	Settings = {
		RarityFocus = "MaxLuck",
		Frequency = "All",
		AutoDisplay = true,
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
