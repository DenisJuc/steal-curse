-- Reveal presentation rules (GDD 3.2) and the reveal queue. Pure: tier indexes and timings are
-- passed in, so Lune can test it.
--   Small  (Common..Rare)       spectral projection + feed line, about 0.5 s
--   Medium (Epic..Mythic)       enlarged model, rarity flash, sound, 1-2 s
--   Large  (Celestial..Cosmic)  dramatic overlay, camera/audio, 3-5 s, skippable
-- The tier decides the category; a mutation adds a second stage (base relic first, mutation second).
-- Rewards are already granted when a reveal starts; reveals only ever show them.

local Presentation = {}

export type Category = "Small" | "Medium" | "Large"
export type RevealMode = "Full" | "Short" | "Off"

export type Timings = {
	SmallSeconds: number,
	MediumSeconds: number,
	MediumMutationSeconds: number,
	LargeSeconds: number,
	LargeMutationSeconds: number,
}

export type Entry = {
	Category: Category,
	Score: number,
	Seq: number,
	[string]: any,
}

export type Queue = {
	Items: { Entry },
	Max: number,
	-- Overlays dropped by coalescing since the last pop (they stay in the feed and Journal).
	Dropped: number,
	NextSeq: number,
}

function Presentation.category(tierIndex: number, mediumIndex: number, largeIndex: number): Category
	if tierIndex >= largeIndex then
		return "Large"
	elseif tierIndex >= mediumIndex then
		return "Medium"
	end
	return "Small"
end

-- Player preference: Full keeps the category, Short turns Large into Medium,
-- Off shows everything as Small (feed + history only, no overlay).
function Presentation.applyMode(category: Category, mode: string): Category
	if mode == "Off" then
		return "Small"
	elseif mode == "Short" and category == "Large" then
		return "Medium"
	end
	return category
end

-- Base stage and mutation stage lengths in seconds (mutation stage is 0 when not mutated).
function Presentation.durations(category: Category, mutated: boolean, timings: Timings): (number, number)
	if category == "Large" then
		return timings.LargeSeconds, if mutated then timings.LargeMutationSeconds else 0
	elseif category == "Medium" then
		return timings.MediumSeconds, if mutated then timings.MediumMutationSeconds else 0
	end
	return timings.SmallSeconds, 0
end

-- Higher = more important to show. Tier first; a mutated find beats a plain one of the same tier.
function Presentation.score(tierIndex: number, mutated: boolean): number
	return tierIndex * 2 + (if mutated then 1 else 0)
end

-- Server-wide chat message for very rare finds.
function Presentation.announces(tierIndex: number, mutated: boolean, minIndex: number, mutatedMinIndex: number): boolean
	return tierIndex >= minIndex or (mutated and tierIndex >= mutatedMinIndex)
end

function Presentation.newQueue(max: number): Queue
	return { Items = {}, Max = math.max(1, max), Dropped = 0, NextSeq = 1 }
end

-- Adds an overlay reveal. Never reorders: earlier rewards always play first. When the queue is
-- over its limit, the least important waiting entry is dropped (the newest one on ties).
-- Returns the dropped entry, if any.
function Presentation.push(queue: Queue, entry: Entry): Entry?
	entry.Seq = queue.NextSeq
	queue.NextSeq += 1
	table.insert(queue.Items, entry)
	if #queue.Items <= queue.Max then
		return nil
	end
	local worst = 1
	for index, item in queue.Items do
		local current = queue.Items[worst]
		if item.Score < current.Score or (item.Score == current.Score and item.Seq > current.Seq) then
			worst = index
		end
	end
	queue.Dropped += 1
	return table.remove(queue.Items, worst)
end

-- Next reveal to play (oldest first) and how many were dropped since the previous pop.
function Presentation.pop(queue: Queue): (Entry?, number)
	local entry = table.remove(queue.Items, 1)
	if not entry then
		return nil, 0
	end
	local dropped = queue.Dropped
	queue.Dropped = 0
	return entry, dropped
end

return Presentation
