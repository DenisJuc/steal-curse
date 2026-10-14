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
	RevealSmall = { Id = "rbxassetid://79130903404606", Volume = 0.15 },
	RevealMedium = { Id = "rbxassetid://114349697462397", Volume = 0.3 },
	RevealLarge = { Id = "rbxassetid://95039614319250", Volume = 0.36 },
	Mutation = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.36, Speed = 1.9 },
	-- Interface
	Hover = { Id = "rbxassetid://139800881181209", Volume = 0.09, Gap = 0.06 },
	Click = { Id = "rbxassetid://6895079853", Volume = 0.2, Gap = 0.08 },
	MenuOpen = { Id = "rbxassetid://74947743572579", Volume = 0.2 },
	MenuClose = { Id = "rbxassetid://88861317075079", Volume = 0.18 },
	Upgrade = { Id = "rbxassetid://14810387808", Volume = 0.3 },
	Error = { Id = "rbxassetid://9120885640", Volume = 0.24 },
	Coin = { Id = "rbxassetid://307631257", Volume = 0.13, Gap = 0.035 },
	Shine = { Id = "rbxassetid://132381858621446", Volume = 0.2 },
	Seal = { Id = "rbxassetid://127907930462931", Volume = 0.36 },
	Collect = { Id = "rbxassetid://96524940709824", Volume = 0.27 },
	ReelTick = { Id = "rbxassetid://75458150587771", Volume = 0.07, Gap = 0.03 },
	ReelLand = { Id = "rbxassetid://115778296381875", Volume = 0.2 },
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
	-- Hunt Streak going up (pitch rises with the streak).
	StreakUp = { Id = "rbxassetid://132381858621446", Volume = 0.3 },
	-- A zone event begins.
	EventStart = { Id = "rbxassetid://1846987019", Volume = 0.45 },
	-- A hidden offering box chimes every couple of seconds; players find it by ear, so it carries far.
	OfferingChime = { Id = "rbxassetid://103648463150595", Volume = 0.55, Range = 150 },
	-- Empty = silent until an id is pasted in.
	OfferingOpen = { Id = "", Volume = 0.4 },
	-- The Lost One kneels and leaves its gift / turns out to be the False Watcher.
	SpiritGift = { Id = "rbxassetid://9046882224", Volume = 0.4 },
	FalseWatcher = { Id = "rbxassetid://96061686619018", Volume = 0.5 },
	-- The False Watcher's face in yours (a scream / horror stinger) and its slow breathing before
	-- it lunges. Empty = silent until an id is pasted in (FalseWatcher plays instead of the stinger).
	WatcherStinger = { Id = "", Volume = 0.7 },
	WatcherBreath = { Id = "", Volume = 0.5 },
	-- Wild life and weather.
	CrowCaw = { Id = "rbxassetid://5829815715", Volume = 0.6, Range = 90, Gap = 0.4 },
	CrowFlap = { Id = "rbxassetid://9113444792", Volume = 0.4, Range = 50 },
	FigureVanish = { Id = "rbxassetid://79028898635420", Volume = 0.6, Range = 120, Speed = 0.7 },
	Thunder = { Id = "rbxassetid://140089926923698", Volume = 0.24, Gap = 2 },
	-- Random distant sounds per area (WildSounds), played somewhere out in the fog.
	BellToll = { Id = "rbxassetid://18197817277", Volume = 0.45, Range = 250 },
	DistantWhisper = { Id = "rbxassetid://9126213995", Volume = 0.4, Range = 120 },
	BranchSnap = { Id = "rbxassetid://9113593581", Volume = 0.5, Range = 120 },
	StoneGrind = { Id = "rbxassetid://103179450736739", Volume = 0.45, Range = 160 },
	DistantHowl = { Id = "rbxassetid://9113956884", Volume = 0.4, Range = 300 },
}

-- Footstep sound per floor material (Enum.Material name; WildSounds swaps the character's running
-- sound). Empty / missing = Roblox's default step.
local STEP = "rbxassetid://92061301674605"
Config.Footsteps = {
	Grass = STEP,
	LeafyGrass = STEP,
	Mud = STEP,
	Ground = STEP,
	Rock = STEP,
	Slate = STEP,
	Basalt = STEP,
	Limestone = STEP,
	Sandstone = STEP,
	Cobblestone = STEP,
	Wood = STEP,
	WoodPlanks = STEP,
} :: { [string]: string }

Config.RemoteLimits = {
	Default = { Rate = 10, Burst = 20 },
	Bind = { Rate = 8, Burst = 12 },
	Settings = { Rate = 4, Burst = 8 },
	Shrine = { Rate = 8, Burst = 16 },
	Inventory = { Rate = 8, Burst = 16 },
	Afk = { Rate = 1, Burst = 4 },
	WildFind = { Rate = 4, Burst = 8 },
	Cleanse = { Rate = 4, Burst = 8 },
}

-- Inventory (GDD 9.2, 9.3). The capacity is the backpack: relics on pedestals don't count.
-- When full, a new find that the rules would keep is sold instead, unless it is protected
-- below; protected finds go over the limit ("protected overflow") and are never discarded.
Config.Inventory = {
	-- Held relic limit (GDD 9.2). No skill raises it; selling and auto-sell keep room free.
	Capacity = 250,
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
	-- Changing this name starts everyone with fresh data (v2: the per-second economy and Rebirth).
	StoreName = "PlayerData_v2",
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
--   CE/sec = IncomeMultiplier x Rebirth x sum(RelicIncome x MutationIncomeMultiplier x PedestalMultiplier)
--   IncomeMultiplier = 1 + (sum of global income bonuses: Codex, Showcase, Energy Conduction...)
-- Every relic has its own income, from its base odds: IncomeScale x (1-in-X) ^ IncomeExponent,
-- so rarer relics earn more inside a tier too and the tiers stay far apart (Economy.relicBaseIncome).
-- Balance check: lune run tests/economyReport (progression sim, tests/lib/economySim).
Config.Economy = {
	TickSeconds = 1,
	-- A server hitch longer than this pays at most this much time in one tick.
	MaxTickSeconds = 5,
	IncomeScale = 1,
	IncomeExponent = 0.6,
	-- Price of pedestal slots 4, 5 and 6 (slots 1..Plots.StartingPedestals are free).
	SlotPrices = { [4] = 2500, [5] = 150000, [6] = 25000000 },
	PedestalMaxLevel = 50,
	-- Each level multiplies the pedestal's income by LevelGrowth (level 50 = about x100).
	LevelGrowth = 1.1,
	-- Level 1 -> 2 costs this; every next level costs UpgradeCostGrowth times more.
	FirstUpgradeCost = 60,
	UpgradeCostGrowth = 1.28,
	-- Selling pays this many seconds of the relic's base income (mutation included).
	SellSeconds = 30,
}

-- Offline earnings (GDD 2.2): no scans offline; displayed relics pay a reduced, capped amount.
Config.Offline = {
	Rate = 0.25,
	CapSeconds = 2 * 3600,
	-- Shorter absences pay nothing (avoids a payout on every quick rejoin).
	MinSeconds = 60,
}

-- Rebirth (Shared/Rebirth, RebirthService): pay Rebirth.cost(n) CE to reset CE, pedestal levels and
-- skill ranks; relics, pedestal slots, Codex, titles, Showcases, lanterns, mastery and potions stay.
-- Each Rebirth multiplies income by IncomeGrowth and luck by LuckGrowth, for good.
-- Game pass ids from the Creator Dashboard (Monetization > Passes). 0 = not on sale yet: nobody
-- owns it except through the Studio /gamepass command.
Config.GamePasses = {
	-- Auto-equip best after every find, purchase and upgrade (the Equip Best button stays free).
	AutoEquip = 0,
}

Config.Rebirth = {
	BaseCost = 4e8,
	CostGrowth = 4,
	IncomeGrowth = 2,
	LuckGrowth = 1.5,
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
	-- Every bonus-roll multiplier (streak, struck signals, zone events, purified zones) multiplies
	-- together, then is capped here so hunting stays within the GDD active-vs-AFK target.
	MaxBonusMultiplier = 3,
}

-- Hunt Streak: every capture on one trip into the wild raises a bonus-roll multiplier, more the
-- deeper you are (bands by distance from the hub center). It resets in town or after IdleSeconds
-- without a capture (the timer pauses while you have no signals left).
Config.HuntStreak = {
	EdgeUntil = 330,
	DeepUntil = 500,
	Gains = { Edge = 0.1, Deep = 0.2, Heart = 0.3 },
	Max = 2,
	IdleSeconds = 90,
	-- How each band is shown: the zone label on the HUD, the banner when you go deeper, and the
	-- rope gates and boundary stones in the wild (WildDressing).
	Bands = {
		Edge = { Name = "The Edge", Color = { 190, 225, 200 } },
		Deep = { Name = "The Deep", Color = { 130, 160, 255 } },
		Heart = { Name = "Heart of the Wild", Color = { 255, 90, 100 } },
	},
}

Config.SpiritSight = {
	-- Signal orbs are only drawn within this distance; pulses point to all of them.
	RevealRange = 90,
	PulseSeconds = 4,
	-- Longer than Ambience.Reveal, so the wild fog always rolls back in between pulses.
	PulseCooldownSeconds = 6,
	-- A pulse outlines this many of the nearest landmarks within LandmarkRange (seen through fog).
	LandmarkCount = 10,
	LandmarkRange = 150,
}

-- Personal finds in the wild (WildFindsService), timed per player while in the wild:
--   Strike: lightning lands Distance studs away every Every seconds; your signals within Radius
--     are struck for Seconds (no signal there: one moves there). Binding one gives Lightning Luck.
--   Offering: a lost offering box hidden Distance studs away, found by its chime (pulses don't
--     show it), gone after Seconds; open it within ClaimRange. Rewards: Offerings module.
--   LostOne: the Watcher appears StartDistance away; come within Trigger and it blinks HopDistance
--     farther, Hops times, then leaves a Spirit Gift (or, FalseChance, it is the False Watcher: it
--     lunges at you, puts the lights out and drains your Hunt Streak). A pulse scares it off; it
--     also leaves after Seconds without being reached.
Config.WildFinds = {
	-- Lightning Luck: Luck x`Luck` for LuckSeconds per struck capture, up to LuckMaxSeconds.
	Strike = { Every = { 60, 120 }, Distance = { 60, 150 }, Radius = 25, Seconds = 45, Luck = 1.5, LuckSeconds = 60, LuckMaxSeconds = 180 },
	Offering = { FirstAfter = 150, Every = { 480, 720 }, Distance = { 60, 150 }, Seconds = 180, ClaimRange = 10 },
	LostOne = {
		FirstAfter = 90,
		Every = { 180, 300 },
		StartDistance = { 45, 65 },
		HopDistance = { 35, 55 },
		Hops = 4,
		Trigger = 20,
		FalseChance = 0.125,
		-- Share of your Hunt Streak gain the False Watcher drains (0 = harmless). From hop
		-- FalseTellsFrom on its eyes flicker red now and then: pulse it away in time.
		FalseDrain = 0.5,
		FalseTellsFrom = 2,
		Seconds = 60,
	},
}

-- Offering box rewards (Offerings module). Tier by Weight; after PityAt - 1 boxes in a row below
-- Uncommon the next one is at least Uncommon. Each tier picks one of its Rewards (by Weight):
--   CE = minutes of the player's current income (at least MinCE), Rolls = extra discoveries,
--   Potion = one random potion from Potions, Bundle = Items, LanternChance = a chance at one of
--   the Lanterns not owned yet.
Config.Offerings = {
	PityAt = 10,
	MinCE = 1000,
	Tiers = {
		{ Id = "Common", Name = "Small Offering", Weight = 70, Color = { 210, 210, 220 } },
		{ Id = "Uncommon", Name = "Fine Offering", Weight = 25, Color = { 120, 220, 255 } },
		{ Id = "Rare", Name = "Sacred Offering", Weight = 5, Color = { 255, 205, 90 } },
	},
	Rewards = {
		Common = {
			{ Weight = 50, CE = { 2, 4 } },
			{ Weight = 50, Rolls = { 5, 10 } },
		},
		Uncommon = {
			{ Weight = 50, Potion = { "LuckPotion", "HastePotion", "FortunePotion" } },
			{ Weight = 30, CE = { 10, 15 } },
			{ Weight = 20, Rolls = { 20, 30 } },
		},
		Rare = {
			{
				Weight = 100,
				CE = { 30, 45 },
				Bundle = { LuckPotion = 1, HastePotion = 1, FortunePotion = 1 },
				LanternChance = 0.5,
			},
		},
	},
	Lanterns = { "Sakura", "GoldLeaf", "Void" },
}

-- Zone mastery (ZoneMastery, MasteryService): each capture gives XP in its zone by depth band.
-- Levels = total XP needed for levels 1..10. Perks work only inside that zone: Hold = share of
-- the bind time removed, Pulse = extra Spirit Sight / landmark range, Idle = extra Hunt Streak
-- seconds. Per zone: lantern colours at levels, a title at TitleAt, its Showcase at ShowcaseAt
-- (ShowcaseConfig, Kind "Mastery").
Config.Mastery = {
	Xp = { Edge = 1, Deep = 2, Heart = 3 },
	Levels = { 10, 25, 50, 85, 130, 190, 270, 370, 500, 660 },
	Perks = {
		{ Level = 2, Hold = 0.05 },
		{ Level = 4, Pulse = 0.15 },
		{ Level = 6, Hold = 0.05 },
		{ Level = 8, Idle = 15 },
	},
	TitleAt = 9,
	ShowcaseAt = 10,
	Zones = {
		HauntedForest = {
			Lanterns = { { Level = 3, Id = "Moss" }, { Level = 5, Id = "Firefly" }, { Level = 7, Id = "Willow" } },
			Title = "Forest Warden",
			Showcase = "ForestGrove",
		},
		AbandonedVillage = {
			Lanterns = { { Level = 3, Id = "Ember" }, { Level = 5, Id = "Chochin" }, { Level = 7, Id = "Bronze" } },
			Title = "Village Keeper",
			Showcase = "BellWatch",
		},
		AncientRuins = {
			Lanterns = { { Level = 3, Id = "Glyph" }, { Level = 5, Id = "Moonstone" }, { Level = 7, Id = "Arcane" } },
			Title = "Ruins Seer",
			Showcase = "StarCircle",
		},
	},
}

-- Lift the Curse (CurseService, shrines in WildLayout.CursedShrines): hold HoldSeconds within Range
-- of a Cursed Shrine to cleanse it, once per player. Each pays CEMinutes of income (at least
-- MinCE), one random potion and its Lore page. Every cleansed shrine thins its zone's fog (up to
-- FogLift) and warms it toward WarmTint; all of a zone's shrines purify it: a title, a lantern and
-- PurifiedBonus x bonus rolls there (inside Hunt.MaxBonusMultiplier). Cleansed shrines are fast
-- travel spots.
Config.Curse = {
	HoldSeconds = 10,
	Range = 12,
	CEMinutes = 8,
	MinCE = 5000,
	Potions = { "LuckPotion", "HastePotion", "FortunePotion" },
	FogLift = 0.15,
	WarmTint = { 255, 232, 205 },
	PurifiedBonus = 1.1,
	Zones = {
		HauntedForest = { Title = "Forest Purifier", Lantern = "ForestHeart" },
		AbandonedVillage = { Title = "Village Purifier", Lantern = "VillageHeart" },
		AncientRuins = { Title = "Ruins Purifier", Lantern = "RuinsHeart" },
	},
	Lore = {
		Forest1 = "The first charm was tied by a woodcutter who heard his name called from the trees. He never cut wood again.",
		Forest2 = "Moss grows over the old seal in a perfect circle. Something underneath does not like the light.",
		Forest3 = "The monks counted the trees each spring. Every year there was one more than they had planted.",
		Forest4 = "A child's straw sandal hangs inside this shrine. No one remembers whose it was.",
		Forest5 = "At the heart of the forest the spirits were bound in chains of prayer. You have loosened the last of them.",
		Village1 = "The village bell rang on its own the night the well was sealed. It still rings in the villagers' dreams.",
		Village2 = "Doors were painted red to keep the hungry ones out. The paint is still wet.",
		Village3 = "The headman's ledger lists every family. The last page lists them again, in a different hand.",
		Village4 = "Lanterns were left burning for the ones who never came home. Some of them did.",
		Village5 = "The curse began at the autumn festival. The masks were never taken off.",
		Ruins1 = "These stones were old before the first temple was built on them.",
		Ruins2 = "The glyphs repeat one word over and over. Scholars disagree whether it is a name or a warning.",
		Ruins3 = "Star charts carved here show a sky with one more moon.",
		Ruins4 = "The guardians were not built to keep people out.",
		Ruins5 = "Beneath the last seal the oldest relic waits. It has been listening the whole time.",
	} :: { [string]: string },
}

-- Daily bounties (Bounties module, BountyService). Every UTC day each player gets one Easy, one
-- Medium and one Hard bounty from Pool, and every week (from Monday) one Weekly; the pick is fixed
-- by (UserId, day). One free reroll a day. Rewards by difficulty: CEMinutes of income (at least
-- MinCE), Potion = one random potion, Potions = these items, Rolls = extra discoveries. Claiming
-- all three dailies on consecutive days builds a streak; Chests pay out on those streak days and
-- the streak starts over after the last one.
-- Pool entries count Event ("Captured", "ShrineCleansed", "OfferingOpened", "LostOneCaught") up
-- to Goal when Filter matches: Area, MinBand ("Edge" < "Deep" < "Heart"), MinStreak, Struck,
-- Event (a zone event id, or "Any").
Config.Bounties = {
	MinCE = 2000,
	Potions = { "LuckPotion", "HastePotion", "FortunePotion" },
	Rewards = {
		Easy = { CEMinutes = 3 },
		Medium = { CEMinutes = 6, Potion = true },
		Hard = { CEMinutes = 12, Rolls = 15 },
		Weekly = { CEMinutes = 40, Potions = { LuckPotion = 1, HastePotion = 1, FortunePotion = 1 } },
	},
	Chests = {
		{ Day = 3, CEMinutes = 15, Potions = { LuckPotion = 1 } },
		{ Day = 5, CEMinutes = 25, Potions = { LuckPotion = 1, FortunePotion = 1 } },
		{ Day = 7, CEMinutes = 45, Potions = { LuckPotion = 2, HastePotion = 1, FortunePotion = 1 } },
	},
	-- stylua: ignore
	Pool = {
		{ Id = "Capture5", Difficulty = "Easy", Text = "Capture 5 spirits", Event = "Captured", Goal = 5 },
		{ Id = "Forest4", Difficulty = "Easy", Text = "Capture 4 spirits in the Haunted Forest", Event = "Captured", Goal = 4, Filter = { Area = "HauntedForest" } },
		{ Id = "Village4", Difficulty = "Easy", Text = "Capture 4 spirits in the Abandoned Village", Event = "Captured", Goal = 4, Filter = { Area = "AbandonedVillage" } },
		{ Id = "Ruins4", Difficulty = "Easy", Text = "Capture 4 spirits in the Ancient Ruins", Event = "Captured", Goal = 4, Filter = { Area = "AncientRuins" } },
		{ Id = "Streak13", Difficulty = "Easy", Text = "Reach a x1.3 Hunt Streak", Event = "Captured", Goal = 1, Filter = { MinStreak = 1.3 } },
		{ Id = "Deep6", Difficulty = "Medium", Text = "Capture 6 spirits Deep in the wild or in its Heart", Event = "Captured", Goal = 6, Filter = { MinBand = "Deep" } },
		{ Id = "Struck1", Difficulty = "Medium", Text = "Capture a lightning-struck spirit", Event = "Captured", Goal = 1, Filter = { Struck = true } },
		{ Id = "Offering1", Difficulty = "Medium", Text = "Find and open a lost offering box", Event = "OfferingOpened", Goal = 1 },
		{ Id = "Streak15", Difficulty = "Medium", Text = "Reach a x1.5 Hunt Streak", Event = "Captured", Goal = 1, Filter = { MinStreak = 1.5 } },
		{ Id = "Capture15", Difficulty = "Medium", Text = "Capture 15 spirits", Event = "Captured", Goal = 15 },
		{ Id = "Heart8", Difficulty = "Hard", Text = "Capture 8 spirits in the Heart of the wild", Event = "Captured", Goal = 8, Filter = { MinBand = "Heart" } },
		{ Id = "LostOne1", Difficulty = "Hard", Text = "Follow the Lost One to its Spirit Gift", Event = "LostOneCaught", Goal = 1 },
		{ Id = "Shrine1", Difficulty = "Hard", Text = "Cleanse a Cursed Shrine", Event = "ShrineCleansed", Goal = 1 },
		{ Id = "Event3", Difficulty = "Hard", Text = "Capture 3 spirits during a zone event", Event = "Captured", Goal = 3, Filter = { Event = "Any" } },
		{ Id = "Streak2", Difficulty = "Hard", Text = "Reach the x2 Hunt Streak", Event = "Captured", Goal = 1, Filter = { MinStreak = 2 } },
		{ Id = "Capture100", Difficulty = "Weekly", Text = "Capture 100 spirits", Event = "Captured", Goal = 100 },
		{ Id = "Struck5", Difficulty = "Weekly", Text = "Capture 5 lightning-struck spirits", Event = "Captured", Goal = 5, Filter = { Struck = true } },
		{ Id = "Offering3", Difficulty = "Weekly", Text = "Open 3 lost offering boxes", Event = "OfferingOpened", Goal = 3 },
		{ Id = "BloodMoon10", Difficulty = "Weekly", Text = "Capture 10 spirits during a Blood Moon", Event = "Captured", Goal = 10, Filter = { Event = "BloodMoon" } },
		{ Id = "LostOne3", Difficulty = "Weekly", Text = "Follow the Lost One to its gift 3 times", Event = "LostOneCaught", Goal = 3 },
	},
}

-- Spirit lantern colours (SpiritLantern; chosen at the hub's Spirit Wardrobe). Unlocked by zone mastery, purifying
-- a zone or Sacred Offerings; Default is everyone's.
Config.Lanterns = {
	Default = "Spirit",
	List = {
		{ Id = "Spirit", Name = "Spirit Blue", Color = { 170, 225, 255 } },
		{ Id = "Moss", Name = "Moss", Color = { 150, 255, 170 } },
		{ Id = "Firefly", Name = "Firefly", Color = { 205, 255, 120 } },
		{ Id = "Willow", Name = "Willow", Color = { 120, 255, 210 } },
		{ Id = "ForestHeart", Name = "Forest Heart", Color = { 80, 255, 140 } },
		{ Id = "Ember", Name = "Ember", Color = { 255, 150, 70 } },
		{ Id = "Chochin", Name = "Chochin Red", Color = { 255, 110, 80 } },
		{ Id = "Bronze", Name = "Bell Bronze", Color = { 230, 180, 110 } },
		{ Id = "VillageHeart", Name = "Village Heart", Color = { 255, 70, 60 } },
		{ Id = "Glyph", Name = "Glyph", Color = { 140, 200, 255 } },
		{ Id = "Moonstone", Name = "Moonstone", Color = { 205, 215, 255 } },
		{ Id = "Arcane", Name = "Arcane", Color = { 170, 130, 255 } },
		{ Id = "RuinsHeart", Name = "Ruins Heart", Color = { 120, 90, 255 } },
		{ Id = "Sakura", Name = "Sakura", Color = { 255, 170, 210 } },
		{ Id = "GoldLeaf", Name = "Gold Leaf", Color = { 255, 215, 110 } },
		{ Id = "Void", Name = "Void", Color = { 130, 90, 170 } },
	},
}

-- Zone events (ZoneEventService): every Every[1]..Every[2] seconds one area gets an event for
-- Duration seconds, announced Warning seconds early. Effects only apply to captures inside that
-- area: Luck multiplies luck (capped by Config.Luck.MaxEvent), Bonus multiplies bonus rolls (inside
-- Config.Hunt.MaxBonusMultiplier), Mutation multiplies the mutation chance (once unlocked).
-- Overlay recolours that area's ambience; Particles use the Config.Ambience particle format;
-- StrikeEvery replaces the lightning interval there (Config.WildFinds.Strike).
Config.ZoneEvents = {
	FirstAfter = 240,
	Every = { 900, 1200 },
	Duration = 300,
	Warning = 60,
	Events = {
		{
			Id = "BloodMoon",
			Name = "Blood Moon",
			Area = "AbandonedVillage",
			Effect = "Luck x1.5",
			Luck = 1.5,
			Bonus = 1,
			Mutation = 1,
			Color = { 255, 50, 60 },
			Overlay = { Color = { 90, 20, 24 }, Decay = { 60, 8, 10 }, Tint = { 255, 200, 200 }, Density = 0.72 },
			Particles = {
				{ Name = "BloodAsh", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = { 255, 70, 60 }, Rate = 18, Size = 0.3, Lifetime = 6, Speed = 0.8, LightEmission = 1, Drift = { 0, 0.4, 0 } },
			},
		},
		{
			Id = "SpiritStorm",
			Name = "Spirit Storm",
			Area = "HauntedForest",
			Effect = "Bonus rolls x2",
			Luck = 1,
			Bonus = 2,
			Mutation = 1,
			Color = { 120, 200, 255 },
			Overlay = { Color = { 30, 44, 62 }, Decay = { 14, 22, 40 }, Tint = { 210, 230, 255 }, Density = 0.82 },
			StrikeEvery = { 15, 30 },
			Particles = {
				{ Name = "StormRain", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = { 180, 200, 230 }, Rate = 700, Size = 0.1, Lifetime = 0.45, Speed = 70, LightEmission = 0.5, Transparency = 0.4, Fall = true, Squash = 3 },
			},
		},
		{
			Id = "StarFall",
			Name = "Star Fall",
			Area = "AncientRuins",
			Effect = "Mutation chance x2",
			Luck = 1,
			Bonus = 1,
			Mutation = 2,
			Color = { 190, 160, 255 },
			Overlay = { Color = { 52, 44, 92 }, Decay = { 40, 30, 90 }, Tint = { 225, 215, 255 }, Density = 0.66 },
			Particles = {
				{ Name = "Stars", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = { 220, 200, 255 }, Rate = 40, Size = 0.5, Lifetime = 1.6, Speed = 30, LightEmission = 1, Transparency = 0.1, Fall = true, Squash = 2 },
			},
		},
	},
}

-- World layout (GDD 4.1, Slice 11): a shrine town in the center (hub plaza + plot ring) inside one
-- continuous wild ring. The ring is split by angle into the Areas below; within BlendDegrees of a
-- border the two neighbours mix (props, terrain and ambience). No walls between areas.
-- Landmarks live in WildLayout; signal spawn points are a generated grid (WorldLayout, Lune-tested).
Config.World = {
	-- Wild ring, in studs from the hub center.
	WildInner = 190,
	WildOuter = 620,
	BlendDegrees = 25,
	-- Signal spawn grid: spacing, distance kept from the ring edges and from landmark footprints.
	SpawnSpacing = 20,
	SpawnEdgeMargin = 12,
	SpawnClearance = 5,
	-- A water stream circles through all three areas (bridges in WildLayout).
	StreamRadius = 405,
	StreamWidth = 12,
	-- The server warns at startup when the built map has more parts than this.
	PartBudget = 12000,
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
-- Distant: Config.Sounds names played now and then somewhere out in the fog (WildSounds).
-- Fall particles (rain) drop straight down as streaks (Squash stretches them).
-- Colors are {r, g, b} 0-255 and Drift is {x, y, z} studs/s^2 (plain numbers so Lune can load Config).
-- Low particles (mist, ash, dust) hug the ground instead of filling the camera box.
-- Lighting: the wild is night with thick fog (you barely see past your spirit lantern); the town
-- keeps MapBuilder's dusk. Exposure is Lighting.ExposureCompensation.
local FIREFLY = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local EMBER = "rbxasset://textures/particles/fire_main.dds"
local WILD_LIGHT = {
	ClockTime = 21,
	Brightness = 0.15,
	Ambient = { 12, 10, 20 },
	OutdoorAmbient = { 16, 16, 26 },
	Exposure = -0.6,
}
Config.Ambience = {
	TownFadeStuds = 20,
	-- Fraction of the gap to the target closed per second (higher = snappier transitions).
	BlendSpeed = 1.5,
	ParticleBox = { 90, 24, 90 },
	SoundVolume = 0.35,
	-- Lightning flashes (timing: Config.WildFinds.Strike): brightness, the sky/ambient colour of
	-- the flash and how far it thins the fog.
	Lightning = { Brightness = 2.6, Ambient = { 140, 150, 200 }, Density = 0.45 },
	-- Ground mist pooling in pits and ravines near you (LowMist): spots lower than Depth.
	LowMist = { Depth = -2.5, Range = 90, Step = 12, Max = 14 },
	-- Random distant sounds in the wild (WildSounds): one every Every[1]..Every[2] seconds,
	-- Distance studs away, picked from the area's Distant list.
	DistantSounds = { Every = { 18, 40 }, Distance = { 40, 90 } },
	-- A spirit pulse lifts the wild fog toward these values, then it rolls back in.
	Reveal = { Density = 0.38, Brightness = 1.1, Exposure = 0.1, RiseSeconds = 0.2, Seconds = 2.6 },
	-- The spirit lantern every character carries in the wild (SpiritLantern).
	Lantern = { Range = 22, Brightness = 1.8, Color = { 170, 225, 255 }, Shadows = true },
	-- The veil (WildVeil): rings of darkness just past the town edge, seen only from the town side,
	-- so the wild is black from outside. Each layer sits Offset studs past WildInner; SolidUntil is
	-- the share of Height that is fully dark before it fades up into the sky. Mist: dark smoke
	-- rolling along the edge. Everything fades away as you step into the wild.
	Veil = {
		Segments = 72,
		Height = 150,
		SolidUntil = 0.6,
		Color = { 4, 3, 8 },
		Layers = {
			{ Offset = 3, Opacity = 0.5 },
			{ Offset = 12, Opacity = 0.8 },
			{ Offset = 24, Opacity = 1 },
		},
		Mist = { Offset = 8, Emitters = 48, Rate = 1.5, Size = 28, Color = { 10, 8, 16 } },
		-- The dark lid over the wild (seen when zoomed out above the rings) reaches this far past
		-- the wild's outer edge.
		LidBeyond = 80,
	},
	Town = {
		Atmosphere = { Density = 0.32, Offset = 0.1, Haze = 1.6, Color = { 200, 175, 230 }, Decay = { 110, 80, 150 } },
		Lighting = {
			ClockTime = 17.6,
			Brightness = 2.5,
			Ambient = { 70, 60, 95 },
			OutdoorAmbient = { 115, 105, 145 },
			Exposure = 0,
		},
		Tint = { 255, 255, 255 },
		Saturation = 0,
		Particles = {},
		SoundId = "",
	},
	Areas = {
		HauntedForest = {
			Atmosphere = { Density = 0.8, Offset = 0.25, Haze = 2.8, Color = { 38, 52, 50 }, Decay = { 14, 24, 22 } },
			Lighting = WILD_LIGHT,
			Tint = { 225, 255, 238 },
			Saturation = -0.05,
			Particles = {
				{ Name = "Fireflies", Texture = FIREFLY, Color = { 205, 255, 140 }, Rate = 14, Size = 0.35, Lifetime = 6, Speed = 0.6, LightEmission = 1, Drift = { 0, 0.2, 0 } },
				{ Name = "Mist", Texture = SMOKE, Color = { 190, 215, 205 }, Rate = 3, Size = 9, Lifetime = 10, Speed = 0.4, LightEmission = 0, Transparency = 0.85, Low = true },
				{ Name = "Rain", Texture = SMOKE, Color = { 170, 185, 200 }, Rate = 450, Size = 0.09, Lifetime = 0.5, Speed = 55, LightEmission = 0.4, Transparency = 0.45, Fall = true, Squash = 3 },
			},
			SoundId = "rbxassetid://82469083481448",
			Distant = { "DistantWhisper", "BranchSnap", "DistantHowl" },
		},
		AbandonedVillage = {
			Atmosphere = { Density = 0.78, Offset = 0.25, Haze = 2.6, Color = { 56, 42, 38 }, Decay = { 26, 14, 12 } },
			Lighting = WILD_LIGHT,
			Tint = { 255, 236, 220 },
			Saturation = -0.1,
			Particles = {
				{ Name = "Embers", Texture = EMBER, Color = { 255, 150, 70 }, Rate = 10, Size = 0.25, Lifetime = 5, Speed = 1.5, LightEmission = 1, Drift = { 0, 1.2, 0 } },
				{ Name = "Ash", Texture = SMOKE, Color = { 160, 145, 140 }, Rate = 2, Size = 7, Lifetime = 9, Speed = 0.5, LightEmission = 0, Transparency = 0.88, Low = true },
			},
			SoundId = "rbxassetid://9114574159",
			Distant = { "BellToll", "DistantWhisper", "BranchSnap" },
		},
		AncientRuins = {
			Atmosphere = { Density = 0.76, Offset = 0.25, Haze = 2.4, Color = { 40, 44, 66 }, Decay = { 16, 16, 32 } },
			Lighting = WILD_LIGHT,
			Tint = { 230, 236, 255 },
			Saturation = 0.05,
			Particles = {
				{ Name = "Glyphs", Texture = FIREFLY, Color = { 140, 200, 255 }, Rate = 10, Size = 0.45, Lifetime = 5, Speed = 0.8, LightEmission = 1, Drift = { 0, 0.6, 0 } },
				{ Name = "Dust", Texture = SMOKE, Color = { 200, 195, 220 }, Rate = 2, Size = 6, Lifetime = 8, Speed = 0.6, LightEmission = 0, Transparency = 0.9, Low = true },
			},
			SoundId = "rbxassetid://273398061",
			Distant = { "StoneGrind", "DistantWhisper", "DistantHowl" },
		},
	},
	-- Map lights (lanterns, fungus, runes) farther than this from the camera are switched off.
	LightRange = 120,
}

-- Sprint (client): hold Shift / press L3 / the touch button to run at Multiplier x your walk
-- speed (Swift Step included, capped at MaxSpeed). Stamina (0..1) drains over StaminaSeconds of
-- running, refills over RefillSeconds after RefillDelay; once empty you need ResumeAt to run again.
Config.Sprint = {
	Multiplier = 1.6,
	MaxSpeed = 72,
	StaminaSeconds = 6.5,
	RefillSeconds = 3.5,
	RefillDelay = 0.75,
	ResumeAt = 0.2,
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
		{ Menu = "Bounties", Label = "Bounty Board", AngleDegrees = 0 },
		{ Menu = "Wardrobe", Label = "Spirit Wardrobe", AngleDegrees = 250 },
	},
}

return Config
