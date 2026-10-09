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
	MaxLines = 6,
	LineLifetimeSeconds = 8,
	-- Feed lines at or above this tier get a highlighted border.
	HighlightTier = "Epic",
}

Config.RemoteLimits = {
	Default = { Rate = 10, Burst = 20 },
}

Config.Debug = {
	MaxRollsPerCommand = 1000,
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
