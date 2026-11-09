-- Base interior rules (pure, Lune-tested): which relic rests on the Great Altar, and each owner's
-- garden. Every shrine shares the same frame (walls, gate, binding circle, seals); what makes one
-- base look different from the next comes from its owner:
--   * Great Altar: the owner's best Huge or Titanic relic (Titanic first, then rarer tier).
--   * Garden: one of several themes in the back-left corner, picked from the owner's UserId (so
--     the same player keeps the same garden) and moved to a free theme when a neighbour in the same
--     server already has it. It grows with the owner's Seal ladder rank: more pieces at higher
--     ranks, so a base at hour five looks different from hour one. Unclaimed shrines stay bare.

local BaseDecor = {}

export type Item = { Uid: number?, Id: string, Size: string?, Mutation: string? }
-- Offset {x, z} from the garden anchor (plot space), Stage = first growth stage that shows it.
export type Piece = { Prop: string, At: { number }, Scale: number?, Turn: number?, Stage: number }
export type Garden = { Id: string, Name: string, Pieces: { Piece } }

local SIZE_RANK = { Huge = 1, Titanic = 2 }

-- The inventory item for the Great Altar, or nil when the owner has no Huge or Titanic relic.
-- `tierIndexOf(relicId)` gives the relic's rarity order (higher = rarer).
function BaseDecor.altarPick(items: { Item }, tierIndexOf: (string) -> number): Item?
	local best: Item? = nil
	local bestScore = -math.huge
	for _, item in items do
		local size = item.Size and SIZE_RANK[item.Size]
		if size then
			local score = size * 1000 + tierIndexOf(item.Id) * 10 + (if item.Mutation then 1 else 0)
			if score > bestScore then
				best, bestScore = item, score
			end
		end
	end
	return best
end

-- stylua: ignore
BaseDecor.Gardens = {
	{ Id = "Sakura", Name = "Sakura Garden", Pieces = {
		{ Prop = "HomeBlossomTree", At = { 0, 0 }, Stage = 1 },
		{ Prop = "SpiderLilyPatch", At = { 6, -6 }, Stage = 2 },
		{ Prop = "StoneLantern", At = { -7, -5 }, Stage = 2 },
		{ Prop = "SpiderLilyPatch", At = { -5, 6 }, Scale = 0.8, Stage = 3 },
		{ Prop = "MossRock1", At = { 7, 5 }, Scale = 0.7, Stage = 3 },
	} },
	{ Id = "Bamboo", Name = "Bamboo Grove", Pieces = {
		{ Prop = "BambooGrove", At = { 0, 2 }, Stage = 1 },
		{ Prop = "FernBush", At = { 6, -5 }, Stage = 2 },
		{ Prop = "BambooGrove2", At = { -7, 3 }, Scale = 0.85, Turn = 90, Stage = 2 },
		{ Prop = "StoneLantern", At = { 5, 7 }, Stage = 3 },
		{ Prop = "FernBush", At = { -5, -6 }, Scale = 0.8, Stage = 3 },
	} },
	{ Id = "Withered", Name = "Withered Grove", Pieces = {
		{ Prop = "DeadTree2", At = { 0, 0 }, Stage = 1 },
		{ Prop = "GlowMushrooms", At = { 5, -5 }, Stage = 2 },
		{ Prop = "JizoStatue", At = { -6, -5 }, Stage = 2 },
		{ Prop = "GlowMushrooms", At = { -5, 5 }, Scale = 0.8, Stage = 3 },
		{ Prop = "FallenLog", At = { 6, 5 }, Scale = 0.6, Turn = 60, Stage = 3 },
	} },
	{ Id = "Stone", Name = "Stone Garden", Pieces = {
		{ Prop = "MossRock3", At = { 0, 0 }, Stage = 1 },
		{ Prop = "JizoStatue", At = { -5, -5 }, Stage = 2 },
		{ Prop = "MossSlab", At = { -1, -6 }, Turn = 15, Stage = 2 },
		{ Prop = "MossLantern", At = { 6, -5 }, Stage = 3 },
		{ Prop = "MossRock2", At = { 5, 6 }, Turn = 120, Stage = 3 },
	} },
	{ Id = "Rune", Name = "Rune Garden", Pieces = {
		{ Prop = "RuneObelisk", At = { 0, 0 }, Stage = 1 },
		{ Prop = "BrokenPillar2", At = { -6, -4 }, Stage = 2 },
		{ Prop = "BrokenPillar1", At = { 6, 4 }, Stage = 2 },
		{ Prop = "RuneObelisk", At = { 6, -6 }, Scale = 0.6, Stage = 3 },
		{ Prop = "FernBush", At = { -5, 6 }, Stage = 3 },
	} },
} :: { Garden }

-- Seal ladder tier index (1-12) -> garden growth stage (1-3).
BaseDecor.StageFromTier = { 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3 }

function BaseDecor.stageFor(tierIndex: number): number
	return BaseDecor.StageFromTier[math.clamp(tierIndex, 1, #BaseDecor.StageFromTier)]
end

-- Garden theme for `userId`: its own pick from the UserId, or the next one not in `taken`
-- (themes already used by other owners in the server). With more owners than themes, repeats.
function BaseDecor.gardenFor(userId: number, taken: { [string]: boolean }): Garden
	local gardens = BaseDecor.Gardens
	local start = math.abs(userId) % #gardens
	for step = 0, #gardens - 1 do
		local garden = gardens[(start + step) % #gardens + 1]
		if not taken[garden.Id] then
			return garden
		end
	end
	return gardens[start + 1]
end

-- The pieces shown at `stage`.
function BaseDecor.piecesAt(garden: Garden, stage: number): { Piece }
	local shown = {}
	for _, piece in garden.Pieces do
		if piece.Stage <= stage then
			table.insert(shown, piece)
		end
	end
	return shown
end

return BaseDecor
