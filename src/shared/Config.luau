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
	-- Fewer lines on small (phone) screens.
	CompactMaxLines = 2,
	LineLifetimeSeconds = 8,
	-- Feed lines at or above this tier get a highlighted border.
	HighlightTier = "Epic",
}

-- Reveal presentation (GDD 3.2). Tiers below MediumTier get a small projection + feed line;
-- MediumTier.. get an enlarged model, flash and sound; LargeTier.. get the dramatic skippable
-- reveal. A mutation adds a second stage after the base relic. Reveals never block scanning.
Config.Reveal = {
	MediumTier = "Epic",
	LargeTier = "Celestial",
	SmallSeconds = 0.5,
	MediumSeconds = 1.3,
	MediumMutationSeconds = 0.6,
	LargeSeconds = 3,
	LargeMutationSeconds = 1.5,
	-- Waiting overlays beyond this are coalesced (still in the feed and the Journal).
	MaxQueued = 3,
	-- Small projections above the player at once.
	MaxProjections = 3,
}

-- Server-wide chat message for very rare finds (GDD 3.1 "optional server message", 12.2).
Config.Announce = {
	Enabled = true,
	MinTier = "Celestial",
	-- Mutated finds at or above this tier are announced too.
	MutatedMinTier = "Mythic",
}

-- AFK (GDD 2.2, 9.4). AFKing in game just keeps scanning; nothing pops up. The AFK stretch is
-- logged and summarized on the Welcome Back screen the next time the player opens the game, or
-- when they return after an anti-AFK server hop.
Config.Afk = {
	-- No input for this long marks the player AFK (the logged stretch starts here).
	MarkAfterSeconds = 60,
	-- Anti-AFK: Roblox disconnects players idle for 20 minutes, so idle players are moved to a
	-- fresh server before that and keep AFKing. A banner warns HopWarningSeconds before the hop.
	HopAfterSeconds = 17 * 60,
	HopWarningSeconds = 15,
	-- The AFK part of Welcome Back shows only after at least this much AFK time with a find.
	MinReportSeconds = 60,
	-- Most entries in the "Unlocked" list (the rest are counted as "and N more").
	MaxUnlocks = 80,
	-- /afksim: most scans simulated in one go.
	SimMaxScans = 600,
}

-- Client sounds: Id, Volume (0..1 before the player's volume setting), Speed (pitch).
-- Placeholders from Roblox's built-in sounds until Slice 8 adds the real audio.
Config.Sounds = {
	RevealSmall = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.12, Speed = 1.5 },
	RevealMedium = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.6, Speed = 0.7 },
	RevealLarge = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.45, Speed = 0.6 },
	Mutation = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.6, Speed = 1.9 },
	Click = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.25, Speed = 1.2 },
	Seal = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.3, Speed = 1.4 },
	Collect = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.45, Speed = 2.2 },
}

Config.RemoteLimits = {
	Default = { Rate = 10, Burst = 20 },
	Bind = { Rate = 8, Burst = 12 },
	Settings = { Rate = 4, Burst = 8 },
	Shrine = { Rate = 8, Burst = 16 },
	Inventory = { Rate = 8, Burst = 16 },
	Afk = { Rate = 1, Burst = 4 },
}

-- Inventory (GDD 9.2, 9.3). Displayed relics count toward the capacity.
-- When full, a new find that the rules would keep is sold instead, unless it is protected
-- below; protected finds go over the limit ("protected overflow") and are never discarded.
Config.Inventory = {
	-- Held relic limit (GDD 9.2). No skill raises it; selling and auto-sell keep room free.
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
	-- Capture summary card (GDD 4.3 step 6): how many notable bonus finds it lists, and how long
	-- it stays up unless tapped.
	SummaryNotable = 3,
	SummarySeconds = 6,
	-- Other players' binds and captures are drawn (cosmetic only) within this distance.
	OthersVisibleRange = 200,
}

Config.SpiritSight = {
	-- Signal orbs are only drawn within this distance; pulses point to all of them.
	RevealRange = 90,
	PulseSeconds = 4,
	PulseCooldownSeconds = 3,
}

-- World layout (GDD 4.1): one map with the hub, the plot ring and three short walkable hunting
-- districts between plots. Each district is a square; its local -Z faces the hub (entrance side).
-- Spawn points and big structures of each district live in DistrictLayouts (Lune-tested).
Config.World = {
	DistrictRadius = 310,
	DistrictSize = 170,
	-- The server warns at startup when the built map has more parts than this.
	PartBudget = 6000,
	-- Default Roblox walk speed (studs/s), used by the travel-time tests.
	WalkSpeed = 16,
	-- How often the server checks which district each player is in (signals follow the player).
	DistrictCheckSeconds = 1,
}

-- AngleDegrees: around the hub, between two plots (plots sit at multiples of 45 degrees).
Config.Districts = {
	{ Id = "HauntedForest", Name = "Haunted Forest", AngleDegrees = 22.5, Seed = 7 },
	{ Id = "AbandonedVillage", Name = "Abandoned Village", AngleDegrees = 157.5, Seed = 11 },
	{ Id = "AncientRuins", Name = "Ancient Ruins", AngleDegrees = 292.5, Seed = 13 },
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
	-- Hub kiosks open a menu through a proximity prompt. Angle in degrees, Radius from the center.
	KioskRadius = 31,
	Kiosks = {
		{ Menu = "Codex", Label = "Codex Archive", AngleDegrees = 30 },
		{ Menu = "Luck", Label = "Fortune Shrine", AngleDegrees = 150 },
		{ Menu = "Relics", Label = "Relic Keeper", AngleDegrees = 210 },
		{ Menu = "Journal", Label = "Journal Board", AngleDegrees = 330 },
	},
}

return Config
