-- Small statistics helpers for odds verification (Lune tests and the /simroll debug command).

local Stats = {}

-- Chi-square 99.9% critical values by degrees of freedom (1..10).
Stats.ChiSquare999 = { 10.83, 13.82, 16.27, 18.47, 20.52, 22.46, 24.32, 26.12, 27.88, 29.59 }

-- Pearson chi-square. Bins expecting fewer than 5 hits are pooled so tiny bins can't dominate.
-- Returns (statistic, degrees of freedom).
function Stats.chiSquare(observed: { number }, expected: { number }): (number, number)
	local bins = {}
	local pooledObserved, pooledExpected = 0, 0
	for index, expectedCount in expected do
		if expectedCount >= 5 then
			table.insert(bins, { observed[index] or 0, expectedCount })
		else
			pooledObserved += observed[index] or 0
			pooledExpected += expectedCount
		end
	end
	if pooledExpected >= 5 or (#bins == 0 and pooledExpected > 0) then
		table.insert(bins, { pooledObserved, pooledExpected })
	elseif pooledExpected > 0 then
		local largest = bins[1]
		for _, bin in bins do
			if bin[2] > largest[2] then
				largest = bin
			end
		end
		largest[1] += pooledObserved
		largest[2] += pooledExpected
	end
	local statistic = 0
	for _, bin in bins do
		statistic += (bin[1] - bin[2]) ^ 2 / bin[2]
	end
	return statistic, math.max(1, #bins - 1)
end

-- Waiting time (in trials) until an event with per-trial probability p first happens.
-- Geometric distribution: mean 1/p, quantile q -> ln(1-q)/ln(1-p).
function Stats.waitMean(p: number): number
	return 1 / p
end

function Stats.waitQuantile(p: number, q: number): number
	-- log1p-style form keeps precision for tiny p (ln(1-p) ~ -p).
	local lnMiss = if p < 1e-6 then -p - p * p / 2 else math.log(1 - p)
	return math.log(1 - q) / lnMiss
end

return Stats
