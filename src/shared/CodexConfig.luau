-- Codex milestones (GDD 7). Data only; Codex.luau turns this into concrete thresholds.
--
-- Counts are fractions of a pool, not fixed numbers, because the roster is still placeholder
-- (GDD 7.2: "specific counts remain data-driven"). Earned milestones are saved, so adding relics
-- later raises future thresholds but never takes away an earned reward.
--
-- Essential rewards (Luck, Income) count unique BASE relic ids from Common through
-- EssentialMaxTier only, regardless of mutation. Mythic and rarer relics and mutated finds only
-- give optional titles (prestige), never power.

local CodexConfig = {}

CodexConfig.EssentialMaxTier = "Legendary"

-- Luck adds up to Config.Luck.CodexMaxBonus (+50%); Income adds to the global income bonus.
CodexConfig.Essential = {
	{ Id = "Essential20", Fraction = 0.2, Luck = 0.05, Income = 0 },
	{ Id = "Essential40", Fraction = 0.4, Luck = 0.10, Income = 0.05 },
	{ Id = "Essential60", Fraction = 0.6, Luck = 0.10, Income = 0.05 },
	{ Id = "Essential80", Fraction = 0.8, Luck = 0.10, Income = 0.05 },
	{ Id = "Essential100", Fraction = 1.0, Luck = 0.15, Income = 0.05 },
}

-- Optional prestige titles over the WHOLE roster (every tier).
CodexConfig.Collection = {
	{ Id = "Collection50", Fraction = 0.5, Title = "Relic Seeker" },
	{ Id = "Collection100", Fraction = 1.0, Title = "Keeper of Every Relic" },
}

-- Optional prestige titles for finding any mutated relic of this tier or rarer.
CodexConfig.MutatedTier = {
	{ Id = "MutatedLegendary", Tier = "Legendary", Title = "Twisted Hoarder" },
	{ Id = "MutatedCosmic", Tier = "Cosmic", Title = "Eclipse-Marked" },
}

-- Themed sets = supernatural families. Only the family's attainable relics (Common through
-- EssentialMaxTier) count. A family with no attainable relics has its frequency open from the start.
CodexConfig.Themes = {
	-- Share of a family's attainable relics needed to unlock its Signal Frequency.
	FrequencyFraction = 0.5,
	-- Title for discovering every attainable relic of a family: "<Family> Archivist".
	CompletionTitleSuffix = "Archivist",
}

-- Balance check (Lune test): expected time to finish every essential milestone at a mid-game
-- reference, switching Rarity Focus to each tier in turn, must stay under this many hours.
CodexConfig.EssentialTargetHours = 10
CodexConfig.ReferenceLuck = 1e4
CodexConfig.ReferenceScanSeconds = 2

return CodexConfig
