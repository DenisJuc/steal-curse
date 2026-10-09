-- Shared tunable settings for core systems. Balancing = editing numbers here.
-- Kept free of Roblox types so headless Lune tests can require it.

local Config = {}

Config.GameName = "Supernatural Relic Collector"

Config.Scan = {
	BaseIntervalSeconds = 4.0,
	DebugMinIntervalSeconds = 0.1,
	-- How often the single scheduler loop checks every player.
	TickSeconds = 0.1,
	-- After a server hitch, grant at most this many overdue scans at once.
	MaxCatchUpScans = 3,
}

Config.Feed = {
	MaxLines = 4,
	LineLifetimeSeconds = 8,
	-- Feed lines at or above this tier get a highlighted border.
	HighlightTier = "Epic",
}

Config.RemoteLimits = {
	Default = { Rate = 10, Burst = 20 },
	Bind = { Rate = 8, Burst = 12 },
	Settings = { Rate = 4, Burst = 8 },
	Shrine = { Rate = 8, Burst = 16 },
	Inventory = { Rate = 8, Burst = 16 },
}

-- Inventory (GDD 9.2, 9.3). Displayed relics count toward the capacity.
-- When full, a new find that the rules would keep is sold instead, unless it is protected
-- below; protected finds go over the limit ("protected overflow") and are never discarded.
Config.Inventory = {
	-- Base capacity; skill tree upgrades will add to it (Slice 7).
	Capacity = 100,
	-- Always kept when full: first discoveries, finds at or above this tier...
	OverflowKeepTier = "Legendary",
	-- ...and mutated finds at or above this tier.
	OverflowKeepMutatedTier = "Epic",
}

Config.Debug = {
	MaxRollsPerCommand = 1000,
	MaxSimulatedRolls = 1000000,
}

-- Persistence (ProfileStore). Never one DataStore write per scan: ProfileStore autosaves every 5 min and
-- on leave/shutdown; rare finds additionally request the next allowed save slot.
Config.Save = {
	-- Changing this name starts everyone with fresh data.
	StoreName = "PlayerData_v1",
	MinSecondsBetweenSaves = 7,
	-- A find at or above this tier requests an immediate (throttled) save.
	PriorityTier = "Mythic",
	-- A mutated find at or above this tier also requests one.
	PriorityMutatedTier = "Legendary",
	-- Finds at or above this tier (or priority mutated finds) go into the rare-find history.
	RareHistoryTier = "Epic",
	RareHistoryMax = 50,
}

-- Rarity Focus (GDD 5.2): choosing a tier caps luck so that tier realistically appears again.
-- At the cap, the chance of rolling the focused tier OR HIGHER equals TierOrHigherChance.
Config.Focus = {
	Default = "MaxLuck",
	TierOrHigherChance = 0.5,
}

-- Signal Frequency (GDD 3.3): weights the chosen family inside whichever tier was rolled.
-- MultiplierByRank is indexed by Frequency Focus skill rank 0..5 (GDD 6.6: up to ~3x).
Config.Frequency = {
	Default = "All",
	MultiplierByRank = { [0] = 1.5, [1] = 1.8, [2] = 2.1, [3] = 2.4, [4] = 2.7, [5] = 3.0 },
}

-- Shrine economy (GDD 6). Cursed Energy (CE) is the only currency; displayed relics are the main income.
--   CE/min = IncomeMultiplier x sum(TierIncome x MutationIncomeMultiplier x PedestalMultiplier)
--   IncomeMultiplier = 1 + (sum of global income bonuses: Codex, Showcase, Energy Conduction...)
Config.Economy = {
	TickSeconds = 1,
	-- A server hitch longer than this pays at most this much time in one tick.
	MaxTickSeconds = 5,
	TierIncomePerMin = {
		Common = 10,
		Uncommon = 25,
		Rare = 75,
		Epic = 200,
		Legendary = 600,
		Mythic = 2000,
		Celestial = 6000,
		Cosmic = 20000,
	},
	-- Price of pedestal slots 4, 5 and 6 (slots 1..Plots.StartingPedestals are free).
	SlotPrices = { [4] = 500, [5] = 15000, [6] = 250000 },
	PedestalMaxLevel = 10,
	-- Level 1 -> 2 costs this; every next level costs UpgradeCostGrowth times more.
	FirstUpgradeCost = 500,
	UpgradeCostGrowth = 2,
	-- Selling pays this fraction of one minute of the relic's base income (mutation included).
	SellFraction = 0.01,
	AutoDisplayDefault = true,
}

-- Offline earnings (GDD 2.2): no scans offline; displayed relics pay a reduced, capped amount.
Config.Offline = {
	Rate = 0.25,
	CapSeconds = 2 * 3600,
	-- Shorter absences pay nothing (avoids a payout on every quick rejoin).
	MinSeconds = 60,
}

-- Endgame luck stack reference values (GDD 5.2 / 5.3), used by balance reports and tests.
Config.Luck = {
	CoreLuckMaxRank = 100,
	CodexMaxBonus = 0.5,
	ShowcaseMaxBonus = 0.10,
	MaxConsumable = 2,
	MaxEvent = 1.5,
	FastestScanSeconds = 1,
}

-- Personal hunt signals (GDD 4.2). Only the owner ever receives their positions.
Config.Signals = {
	StartCount = 3,
	MaxCount = 5,
	-- One new signal per this many seconds while below MaxCount. Also the hunt
	-- "opportunity window" used by the bonus-roll formula.
	RegenSeconds = 120,
	-- New signals avoid spawning closer than this to the owner's existing signals.
	MinSpacing = 18,
	-- Signal orbs float this high above their spawn point.
	HoverHeight = 3,
}

-- Hold to Bind (GDD 4.3). Hold time is measured by the server.
Config.Bind = {
	HoldSeconds = 6,
	LockRange = 12,
	-- Extra distance the server tolerates on Begin for network lag.
	RangeSlack = 4,
	-- While binding, moving farther than this cancels.
	BreakRange = 20,
	-- Clock-sync tolerance when checking the hold duration on Complete.
	CompleteTolerance = 0.15,
	CancelCooldownSeconds = 1.5,
	-- A bind that never completes is cancelled after HoldSeconds + this.
	TimeoutGraceSeconds = 4,
	DebugMinHoldSeconds = 0.5,
}

-- Bonus discoveries per successful capture (GDD 4.4):
-- B = max(BonusFloor, ceil(BonusFactor * RegenSeconds / scanIntervalSeconds))
Config.Hunt = {
	BonusFloor = 10,
	BonusFactor = 0.35,
}

Config.SpiritSight = {
	-- Signal orbs are only drawn within this distance; pulses point to all of them.
	RevealRange = 90,
	PulseSeconds = 4,
	PulseCooldownSeconds = 3,
}

-- Slice 1 greybox hunting ground. Angle is degrees around the hub; it sits between plots 1 and 2.
Config.HuntArea = {
	Name = "Haunted Grove",
	AngleDegrees = 22.5,
	Radius = 310,
	Size = 170,
	TreeCount = 34,
	Seed = 7,
}

-- Plot local space: -Z faces the hub (entrance side). Offsets are {x, z} in studs.
Config.Plots = {
	Count = 8,
	RingRadius = 170,
	Size = 64,
	StartingPedestals = 3,
	MaxPedestals = 6,
	PedestalOffsets = {
		{ -16, -16 },
		{ 0, -16 },
		{ 16, -16 },
		{ -16, -2 },
		{ 0, -2 },
		{ 16, -2 },
	},
	ResonatorOffset = { 0, 18 },
	ShowcaseOffset = { 22, 14 },
	SpawnOffset = { 0, -24 },
}

Config.Hub = {
	PlazaRadius = 46,
	GroundSize = 900,
	LanternCount = 8,
}

return Config
