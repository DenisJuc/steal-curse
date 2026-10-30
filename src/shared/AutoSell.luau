-- Auto-sell rules (GDD 9.2, 9.3). Pure: no Roblox APIs, no requires, so Lune tests it as a
-- decision table. The server runs decide() on every new find;
-- the UI runs the same function for its "what will happen" preview.
--
-- Precedence (first match wins):
--   1. Favorite relic (relic + mutation + size)     -> keep
--   2. Fusion reserve (pinned / mid-fusion copies) -> keep
--   3. First discovery, if ProtectFirst is on       -> keep
--   4. Mutated, if ProtectMutated is on             -> keep
--   5. Sized stamp that is the only owned copy of   -> keep
--      that (relic, mutation, size) identity
--   6. Rarity rule "Sell All"                       -> sell
--   7. Duplicate, with rarity rule "Sell Duplicates" or the global Sell All Duplicates toggle -> sell
--      (includes excess Huge/Titanic of the same identity)
--   8. Base odds more common than 1 in SellEasierThan -> sell
--   9. Otherwise                                     -> keep
-- Displayed and locked items never reach decide(); the Codex records a find before this runs.
-- CodexSizes is written at grant time and is never cleared by selling.

local AutoSell = {}

export type Mode = "Keep" | "SellDuplicates" | "SellAll"

export type Rules = {
	Tiers: { [string]: Mode },
	SellAllDuplicates: boolean,
	-- 0 = off. Otherwise sell finds whose base odds are better (more common) than 1 in this number.
	SellEasierThan: number,
	ProtectFirst: boolean,
	ProtectMutated: boolean,
}

export type Facts = {
	Tier: string,
	-- Base odds as "1 in BaseOneIn" (1x luck, no focus, no frequency).
	BaseOneIn: number,
	First: boolean,
	Mutated: boolean,
	-- SoftCap Studio Huge/Titanic stamp.
	Sized: boolean?,
	-- True when another copy of the same (Id, Mutation, Size) is already owned (backpack or pedestal).
	-- Excess sized stamps fall through to duplicate / rarity rules instead of always-keep.
	SizedDuplicate: boolean?,
	-- You already hold a copy of the same base relic that earns at least as much.
	Duplicate: boolean,
	Favorite: boolean,
	-- Phase 2: selling would drop below the fusion / favourite reserve.
	FusionReserve: boolean?,
}

export type Reason =
	"Favorite"
	| "FusionReserve"
	| "FirstDiscovery"
	| "Mutated"
	| "Sized"
	| "RarityRule"
	| "Duplicate"
	| "OddsThreshold"
	| "NoRule"

AutoSell.Modes = { "Keep", "SellDuplicates", "SellAll" } :: { Mode }

AutoSell.ModeLabels = {
	Keep = "Keep All",
	SellDuplicates = "Sell Duplicates",
	SellAll = "Sell All",
} :: { [Mode]: string }

AutoSell.ThresholdPresets = { 0, 10, 100, 1000, 10000, 100000, 1000000 }

AutoSell.ReasonText = {
	Favorite = "favorite",
	FusionReserve = "fusion reserve",
	FirstDiscovery = "first discovery",
	Mutated = "mutated",
	Sized = "first huge/titanic",
	RarityRule = "rarity rule",
	Duplicate = "duplicate",
	OddsThreshold = "odds rule",
	NoRule = "no rule",
	InventoryFull = "inventory full",
} :: { [string]: string }

-- Every tier starts on "Keep All": auto-selling is opt-in (Backpack > Auto-sell).
function AutoSell.defaults(tierIds: { string }): Rules
	local tiers = {}
	for _, tierId in tierIds do
		tiers[tierId] = "Keep"
	end
	return {
		Tiers = tiers,
		SellAllDuplicates = false,
		SellEasierThan = 0,
		ProtectFirst = true,
		ProtectMutated = true,
	}
end

local VALID_MODE = { Keep = true, SellDuplicates = true, SellAll = true }

-- Builds a clean rule set from untrusted input; anything missing or invalid falls back to `base`.
function AutoSell.sanitize(raw: any, tierIds: { string }, base: Rules): Rules
	local source = if type(raw) == "table" then raw else {}
	local rawTiers = if type(source.Tiers) == "table" then source.Tiers else {}
	local tiers = {}
	for _, tierId in tierIds do
		local mode = rawTiers[tierId]
		tiers[tierId] = if type(mode) == "string" and VALID_MODE[mode] then mode else base.Tiers[tierId] or "Keep"
	end
	local function flag(value: any, fallback: boolean): boolean
		return if type(value) == "boolean" then value else fallback
	end
	local threshold = source.SellEasierThan
	if type(threshold) ~= "number" or threshold ~= threshold or threshold < 0 or threshold > 1e18 then
		threshold = base.SellEasierThan
	end
	return {
		Tiers = tiers,
		SellAllDuplicates = flag(source.SellAllDuplicates, base.SellAllDuplicates),
		SellEasierThan = threshold,
		ProtectFirst = flag(source.ProtectFirst, base.ProtectFirst),
		ProtectMutated = flag(source.ProtectMutated, base.ProtectMutated),
	}
end

-- Returns (sell?, reason).
function AutoSell.decide(rules: Rules, facts: Facts): (boolean, Reason)
	if facts.Favorite then
		return false, "Favorite"
	end
	if facts.FusionReserve then
		return false, "FusionReserve"
	end
	if facts.First and rules.ProtectFirst then
		return false, "FirstDiscovery"
	end
	if facts.Mutated and rules.ProtectMutated then
		return false, "Mutated"
	end
	-- Keep the first owned stamp of each (relic, mutation, size). Excess may sell as duplicates.
	if facts.Sized and not facts.SizedDuplicate then
		return false, "Sized"
	end
	local mode = rules.Tiers[facts.Tier] or "Keep"
	if mode == "SellAll" then
		return true, "RarityRule"
	end
	if facts.Duplicate and (mode == "SellDuplicates" or rules.SellAllDuplicates) then
		return true, "Duplicate"
	end
	-- Sized excess also sells when the global Sell-all-duplicates toggle is on, even if
	-- Duplicate (income) is false — identity match is what SizedDuplicate encodes.
	if facts.Sized and facts.SizedDuplicate and (mode == "SellDuplicates" or rules.SellAllDuplicates) then
		return true, "Duplicate"
	end
	if rules.SellEasierThan > 0 and facts.BaseOneIn < rules.SellEasierThan then
		return true, "OddsThreshold"
	end
	return false, "NoRule"
end

export type Copy = {
	Uid: number,
	-- On a pedestal: not in the backpack at all.
	Displayed: boolean,
	Locked: boolean,
	Favorite: boolean,
	Floating: boolean,
	-- Kept for Collection fusion progress (soft-pin / pin / mid-rank).
	FusionReserve: boolean?,
	-- SoftCap Studio Huge/Titanic stamp.
	Sized: boolean?,
	-- Identity key for keep-1 sized overflow (favoriteKey).
	IdentityKey: string?,
}

-- The Backpack's "Sell all": every unprotected copy except locked, favorite, floating,
-- fusion-reserved. Sized stamps keep one per identity; excess sized copies sell.
-- Relics on pedestals aren't in the backpack (they still count as the kept identity via Displayed).
function AutoSell.sellAll(copies: { Copy }): { number }
	local sizedKept: { [string]: boolean } = {}
	-- Prefer keeping a displayed/locked/favorite/floating sized copy as the "one".
	for _, copy in copies do
		if copy.Sized and copy.IdentityKey then
			if copy.Displayed or copy.Locked or copy.Favorite or copy.Floating or copy.FusionReserve then
				sizedKept[copy.IdentityKey] = true
			end
		end
	end
	local sell = {}
	for _, copy in copies do
		if copy.Displayed or copy.Locked or copy.Favorite or copy.Floating or copy.FusionReserve then
			continue
		end
		if copy.Sized and copy.IdentityKey then
			if sizedKept[copy.IdentityKey] then
				table.insert(sell, copy.Uid)
			else
				sizedKept[copy.IdentityKey] = true
			end
			continue
		end
		table.insert(sell, copy.Uid)
	end
	return sell
end

-- Favorites are per relic + mutation + size, so future matching copies are protected too.
function AutoSell.favoriteKey(relicId: string, mutationId: string?, sizeId: string?): string
	local key = if mutationId then `{relicId}|{mutationId}` else relicId
	if sizeId == "Huge" or sizeId == "Titanic" then
		return `{key}|{sizeId}`
	end
	return key
end

return AutoSell
