-- Summary of discoveries over a span of time (GDD 9.4 AFK summary and the Journal's session card):
-- scans, new unique relics, best item and best mutated item, junk sold, CE produced online.
-- Built from the discovery results the server sends. Pure, so Lune can test it.

local SessionReport = {}

export type Find = { Id: string, Mutation: string?, Score: number }

export type Report = {
	Discoveries: number,
	NewUnique: number,
	NewVariants: number,
	Best: Find?,
	BestMutated: Find?,
	SoldCount: number,
	SoldCE: number,
}

export type Result = {
	Id: string,
	Mutation: string?,
	First: boolean?,
	NewVariant: boolean?,
	Sold: number?,
}

function SessionReport.new(): Report
	return {
		Discoveries = 0,
		NewUnique = 0,
		NewVariants = 0,
		Best = nil,
		BestMutated = nil,
		SoldCount = 0,
		SoldCE = 0,
	}
end

-- `score` ranks finds (higher = better); the first find keeps a tie.
function SessionReport.add(report: Report, result: Result, score: number)
	report.Discoveries += 1
	if result.First then
		report.NewUnique += 1
	elseif result.NewVariant then
		report.NewVariants += 1
	end
	if result.Sold then
		report.SoldCount += 1
		report.SoldCE += result.Sold
	end
	local find = { Id = result.Id, Mutation = result.Mutation, Score = score }
	if not report.Best or score > report.Best.Score then
		report.Best = find
	end
	if result.Mutation and (not report.BestMutated or score > report.BestMutated.Score) then
		report.BestMutated = find
	end
end

function SessionReport.isEmpty(report: Report): boolean
	return report.Discoveries == 0
end

return SessionReport
