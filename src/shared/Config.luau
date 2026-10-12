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

-- The ROLL button (Slice 9). Each scan still charges on the same timer. With Auto Roll on (the
-- default, and always while AFK) a full charge fires by itself; with it off the charge waits
-- (never stacks) until the player presses ROLL. The roll animation (RollReel, in the style the
-- player picks) is cosmetic: the server has already decided the result and it always lands on it.
Config.Roll = {
	-- Roll length = this fraction of the scan interval, clamped to Min..Max seconds.
	ReelFraction = 0.6,
	ReelMinSeconds = 0.35,
	ReelMaxSeconds = 1.6,
	-- "Fast" roll animation setting.
	FastSeconds = 0.35,
	-- Relics the Flicker style cycles through; the result is the one at LandIndex (the last).
	StripLength = 16,
	LandIndex = 16,
	-- Teasers over-sample rare tiers so near-misses happen. Cosmetic only, never shown as odds.
	TeaserTierWeights = {
		Common = 30,
		Uncommon = 22,
		Rare = 16,
		Epic = 12,
		Legendary = 9,
		Mythic = 6,
		Celestial = 3.5,
		Cosmic = 1.5,
	},
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
-- Range: 3D sounds (played at a signal) fade out over this many studs.
-- Gap: replay limit in seconds (default 0.15); coin ticks need a shorter one.
-- Mutation is still a Roblox built-in placeholder.
Config.Sounds = {
	RevealSmall = { Id = "rbxassetid://79130903404606", Volume = 0.25 },
	RevealMedium = { Id = "rbxassetid://114349697462397", Volume = 0.5 },
	RevealLarge = { Id = "rbxassetid://95039614319250", Volume = 0.6 },
	Mutation = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.6, Speed = 1.9 },
	-- Interface
	Hover = { Id = "rbxassetid://139800881181209", Volume = 0.15, Gap = 0.06 },
	Click = { Id = "rbxassetid://6895079853", Volume = 0.35, Gap = 0.08 },
	MenuOpen = { Id = "rbxassetid://74947743572579", Volume = 0.35 },
	MenuClose = { Id = "rbxassetid://88861317075079", Volume = 0.3 },
	Upgrade = { Id = "rbxassetid://14810387808", Volume = 0.5 },
	Error = { Id = "rbxassetid://9120885640", Volume = 0.4 },
	Coin = { Id = "rbxassetid://307631257", Volume = 0.22, Gap = 0.035 },
	Shine = { Id = "rbxassetid://132381858621446", Volume = 0.35 },
	Seal = { Id = "rbxassetid://127907930462931", Volume = 0.6 },
	Collect = { Id = "rbxassetid://96524940709824", Volume = 0.45 },
	ReelTick = { Id = "rbxassetid://75458150587771", Volume = 0.12, Gap = 0.03 },
	ReelLand = { Id = "rbxassetid://115778296381875", Volume = 0.35 },
	-- Hunt (Spirit Sight, pulse, signals, bind)
	SightOn = { Id = "rbxassetid://126941244422484", Volume = 0.5 },
	SightOff = { Id = "rbxassetid://9118158252", Volume = 0.4 },
	SightAmbience = { Id = "rbxassetid://82923387179908", Volume = 0.25 },
	Pulse = { Id = "rbxassetid://9116394525", Volume = 0.5 },
	SignalPing = { Id = "rbxassetid://119114391168229", Volume = 0.6, Range = 120 },
	SignalHum = { Id = "rbxassetid://9125898973", Volume = 0.5, Range = 70 },
	SignalWhisper = { Id = "rbxassetid://79028898635420", Volume = 0.35, Range = 25 },
	Lock = { Id = "rbxassetid://108682776074559", Volume = 0.6 },
	ChainRattle = { Id = "rbxassetid://9116539362", Volume = 0.35 },
	ChainTighten = { Id = "rbxassetid://92066478647048", Volume = 0.55 },
	BindRiser = { Id = "rbxassetid://9043356042", Volume = 0.4 },
	SealSuck = { Id = "rbxassetid://676242549", Volume = 0.5 },
	Cancel = { Id = "rbxassetid://119398240584172", Volume = 0.45 },
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
	-- New signals appear this far from the player (anywhere in the wild ring).
	NearMin = 25,
	NearMax = 90,
	-- Walking this far from every one of your signals moves them near you again.
	RelocateDistance = 130,
	CheckSeconds = 1,
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
	-- Presentation beats (fractions of the hold): a chain clink and a talisman ignites at each
	-- TightenAt; from PullAt the spirit is dragged toward the hand.
	TightenAt = { 1 / 3, 2 / 3 },
	PullAt = 0.9,
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

-- World layout (GDD 4.1, Slice 11): a shrine town in the center (hub plaza + plot ring) inside one
-- continuous wild ring. The ring is split by angle into the Areas below; within BlendDegrees of a
-- border the two neighbours mix (props, terrain and ambience). No walls between areas.
-- Landmarks live in WildLayout; signal spawn points are a generated grid (WorldLayout, Lune-tested).
Config.World = {
	-- Wild ring, in studs from the hub center.
	WildInner = 190,
	WildOuter = 410,
	BlendDegrees = 25,
	-- Signal spawn grid: spacing, distance kept from the ring edges and from landmark footprints.
	SpawnSpacing = 20,
	SpawnEdgeMargin = 12,
	SpawnClearance = 5,
	-- A water stream circles through all three areas (bridges in WildLayout).
	StreamRadius = 300,
	StreamWidth = 12,
	-- The server warns at startup when the built map has more parts than this.
	PartBudget = 9000,
	-- Default Roblox walk speed (studs/s), used by the travel-time tests.
	WalkSpeed = 16,
	-- Every plot must reach the wild within this many seconds of walking.
	MaxTravelSeconds = 15,
}

-- AngleDegrees: the middle of each area's slice of the ring, and where its path runs out of town.
-- Plots sit at multiples of 45 degrees, so every area angle is a gap between two plots (22.5 + 45k).
Config.Areas = {
	{ Id = "HauntedForest", Name = "Haunted Forest", AngleDegrees = 22.5, Seed = 7 },
	{ Id = "AbandonedVillage", Name = "Abandoned Village", AngleDegrees = 157.5, Seed = 11 },
	{ Id = "AncientRuins", Name = "Ancient Ruins", AngleDegrees = 292.5, Seed = 13 },
}

-- Client ambience per area (Slice 11), blended by WorldLayout.areaAt weights and faded in over
-- TownFadeStuds when leaving the town. Atmosphere/Tint apply on top of the server's Lighting.
-- Particles follow the camera (Rate per second at full weight; Low effects turns them off).
-- SoundId: a looping ambient track ("rbxassetid://..."); empty = no sound for that area yet.
-- Colors are {r, g, b} 0-255 and Drift is {x, y, z} studs/s^2 (plain numbers so Lune can load Config).
-- Low particles (mist, ash, dust) hug the ground instead of filling the camera box.
local FIREFLY = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local EMBER = "rbxasset://textures/particles/fire_main.dds"
Config.Ambience = {
	TownFadeStuds = 20,
	-- Fraction of the gap to the target closed per second (higher = snappier transitions).
	BlendSpeed = 1.5,
	ParticleBox = { 90, 24, 90 },
	SoundVolume = 0.35,
	Town = {
		Atmosphere = { Density = 0.32, Haze = 1.6, Color = { 200, 175, 230 }, Decay = { 110, 80, 150 } },
		Tint = { 255, 255, 255 },
		Saturation = 0,
		Particles = {},
		SoundId = "",
	},
	Areas = {
		HauntedForest = {
			Atmosphere = { Density = 0.44, Haze = 2.4, Color = { 150, 190, 170 }, Decay = { 55, 85, 75 } },
			Tint = { 225, 255, 238 },
			Saturation = -0.05,
			Particles = {
				{ Name = "Fireflies", Texture = FIREFLY, Color = { 205, 255, 140 }, Rate = 14, Size = 0.35, Lifetime = 6, Speed = 0.6, LightEmission = 1, Drift = { 0, 0.2, 0 } },
				{ Name = "Mist", Texture = SMOKE, Color = { 190, 215, 205 }, Rate = 3, Size = 9, Lifetime = 10, Speed = 0.4, LightEmission = 0, Transparency = 0.85, Low = true },
			},
			SoundId = "",
		},
		AbandonedVillage = {
			Atmosphere = { Density = 0.38, Haze = 1.9, Color = { 215, 170, 140 }, Decay = { 120, 70, 55 } },
			Tint = { 255, 236, 220 },
			Saturation = -0.1,
			Particles = {
				{ Name = "Embers", Texture = EMBER, Color = { 255, 150, 70 }, Rate = 10, Size = 0.25, Lifetime = 5, Speed = 1.5, LightEmission = 1, Drift = { 0, 1.2, 0 } },
				{ Name = "Ash", Texture = SMOKE, Color = { 160, 145, 140 }, Rate = 2, Size = 7, Lifetime = 9, Speed = 0.5, LightEmission = 0, Transparency = 0.88, Low = true },
			},
			SoundId = "",
		},
		AncientRuins = {
			Atmosphere = { Density = 0.34, Haze = 1.3, Color = { 175, 185, 235 }, Decay = { 80, 80, 145 } },
			Tint = { 230, 236, 255 },
			Saturation = 0.05,
			Particles = {
				{ Name = "Glyphs", Texture = FIREFLY, Color = { 140, 200, 255 }, Rate = 10, Size = 0.45, Lifetime = 5, Speed = 0.8, LightEmission = 1, Drift = { 0, 0.6, 0 } },
				{ Name = "Dust", Texture = SMOKE, Color = { 200, 195, 220 }, Rate = 2, Size = 6, Lifetime = 8, Speed = 0.6, LightEmission = 0, Transparency = 0.9, Low = true },
			},
			SoundId = "",
		},
	},
	-- Map lights (lanterns, fungus, runes) farther than this from the camera are switched off.
	LightRange = 120,
}

-- Home / Hub / Wild buttons (server picks every destination).
Config.Travel = {
	CooldownSeconds = 4,
	-- "Wild" lands this far inside the ring, straight out from where you stand.
	WildDepth = 16,
	-- "Hub" lands here {x, z}, facing the obelisk (the hub spawn, on the side with no kiosk).
	HubSpot = { 0, -22 },
}

-- Plot local space: -Z faces the hub (entrance side). Offsets are {x, z} in studs.
Config.Plots = {
	Count = 8,
	RingRadius = 140,
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
	LanternCount = 8,
	-- Hub kiosks open a menu through a proximity prompt. Angle in degrees, Radius from the center.
	-- Prop: optional map prop standing beside the counter (MapPropConfig).
	KioskRadius = 31,
	Kiosks = {
		{ Menu = "Codex", Label = "Codex Archive", AngleDegrees = 30, Prop = "CodexLectern" },
		{ Menu = "Skills", Label = "Rune Monolith", AngleDegrees = 90, Prop = "RuneMonolith" },
		{ Menu = "Luck", Label = "Fortune Shrine", AngleDegrees = 150, Prop = "OfferingBox" },
		{ Menu = "Relics", Label = "Relic Keeper", AngleDegrees = 210 },
		{ Menu = "Journal", Label = "Journal Board", AngleDegrees = 330 },
	},
}

return Config
