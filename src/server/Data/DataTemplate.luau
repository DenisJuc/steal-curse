-- Saved player data shape. Pure (no Roblox APIs) so Lune tests can load it.
-- Adding a field: add it here (Reconcile fills it for old profiles).
-- Renaming/reshaping a field: bump Version and add a step in Migrations.

local DataTemplate = {}

DataTemplate.Version = 4

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
	-- The current AFK stretch (kept across anti-AFK server hops and leaving), summarized on the
	-- Welcome Back screen. Unlocks are read from the Codex/history timestamps >= StartedAt.
	AfkLog: {
		Active: boolean,
		StartedAt: number,
		ScansAtStart: number,
		-- AFK time spent in game (not offline time between sessions).
		Seconds: number,
		CE: number,
		Discoveries: number,
		Sold: number,
		SoldCE: number,
		Hops: number,
	},
	Settings: {
		RarityFocus: string,
		Frequency: string,
		AutoSell: {
			Tiers: { [string]: string },
			SellAllDuplicates: boolean,
			SellEasierThan: number,
			ProtectFirst: boolean,
			ProtectMutated: boolean,
		},
		-- Presentation settings (ClientSettings schema): string or number values.
		Client: { [string]: string | number },
	},
	-- Skill tree ranks by SkillConfig node id (all bought with CE).
	Skills: { [string]: number },
	-- Showcases.State: Active = "" when none; Owned[id] = level 1-4.
	Showcases: {
		Active: string,
		Owned: { [string]: number },
		AccessoriesOff: { [string]: boolean },
	},
	-- The one relic carried for show (GDD 9.1): Key = "<relicId>|<mutation>" ("" = none),
	-- Mode = "Float" or "Hand". Display only; it stays in the inventory and on pedestals.
	Cosmetic: {
		Key: string,
		Mode: string,
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
	AfkLog = {
		Active = false,
		StartedAt = 0,
		ScansAtStart = 0,
		Seconds = 0,
		CE = 0,
		Discoveries = 0,
		Sold = 0,
		SoldCE = 0,
		Hops = 0,
	},
	Settings = {
		RarityFocus = "MaxLuck",
		Frequency = "All",
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
		-- Must equal ClientSettings.defaults() (checked by a Lune test).
		Client = {
			Effects = "Full",
			Reveals = "Full",
			Camera = "On",
			Sound = 100,
			InterfaceSize = "Medium",
			AfkReports = "On",
			Hints = "On",
		},
	},
	-- Must list every SkillConfig node (checked by a Lune test).
	Skills = {
		CoreLuck = 0,
		ScanSpeed = 0,
		FrequencyFocus = 0,
		MutationResonance = 0,
		EnergyConduction = 0,
		SpiritMerchant = 0,
		SpiritReservoir = 0,
		SpiritSight = 0,
		BindingEfficiency = 0,
		ResonantHarvest = 0,
	},
	Showcases = {
		Active = "",
		Owned = {},
		AccessoriesOff = {},
	},
	Cosmetic = {
		Key = "",
		Mode = "Float",
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
