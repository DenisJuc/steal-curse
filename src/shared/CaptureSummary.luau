-- The captured-plus-bonus summary shown after a successful bind (GDD 4.3 step 6): the captured
-- relic, the bonus count, the most notable bonus finds, and how many finds were new or auto-sold.
-- Built by the server from the discovery pipeline results. Pure, so Lune can test it.

local CaptureSummary = {}

export type Result = {
	Id: string,
	Mutation: string?,
	First: boolean?,
	NewVariant: boolean?,
	Sold: number?,
}

export type Notable = { Id: string, Mutation: string?, First: boolean, NewVariant: boolean }

export type Summary = {
	CapturedId: string,
	CapturedMutation: string?,
	CapturedFirst: boolean,
	CapturedSold: number?,
	BonusCount: number,
	Notable: { Notable },
	NewCount: number,
	SoldCount: number,
	SoldCE: number,
}

-- results[1] is the captured relic, the rest are bonus discoveries. tierOf(relicId) -> tier index.
-- Notable bonus finds: the rarest first (mutated above plain in a tier), then new ones.
function CaptureSummary.build(results: { Result }, tierOf: (string) -> number, maxNotable: number): Summary?
	local captured = results[1]
	if not captured then
		return nil
	end
	local newCount, soldCount, soldCE = 0, 0, 0
	for _, result in results do
		if result.First then
			newCount += 1
		end
		if result.Sold then
			soldCount += 1
			soldCE += result.Sold
		end
	end

	local bonus = {}
	for index = 2, #results do
		table.insert(bonus, { Index = index, Result = results[index] })
	end
	local function score(result: Result): number
		return tierOf(result.Id) * 2 + (if result.Mutation then 1 else 0)
	end
	table.sort(bonus, function(a, b)
		local scoreA, scoreB = score(a.Result), score(b.Result)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end
		local firstA, firstB = a.Result.First == true, b.Result.First == true
		if firstA ~= firstB then
			return firstA
		end
		return a.Index < b.Index
	end)
	local notable = {}
	for rank = 1, math.min(maxNotable, #bonus) do
		local result = bonus[rank].Result
		notable[rank] = {
			Id = result.Id,
			Mutation = result.Mutation,
			First = result.First == true,
			NewVariant = result.NewVariant == true,
		}
	end

	return {
		CapturedId = captured.Id,
		CapturedMutation = captured.Mutation,
		CapturedFirst = captured.First == true,
		CapturedSold = captured.Sold,
		BonusCount = #results - 1,
		Notable = notable,
		NewCount = newCount,
		SoldCount = soldCount,
		SoldCE = soldCE,
	}
end

return CaptureSummary
