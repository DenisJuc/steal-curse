local SoftCapRarity = require("../lib/softCapRarity")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local rules = require("../lib/rules")
local expect = require("../lib/expect")

local LUCK_SWEEP = { 1, 5, 20, 60, 150, 500, 2000, 10000, 100000 }

return {
	{
		Name = "SoftCap rows cover all 99 relics with distinct R",
		Run = function()
			local rows = SoftCapRarity.rows()
			expect.equal(#rows, 99, "99 rows")
			expect.equal(#RelicConfig.Relics, 99, "roster")
			local seenR = {}
			local dupR = 0
			for _, row in rows do
				local key = string.format("%.8f", row.R)
				if seenR[key] then
					dupR += 1
				end
				seenR[key] = true
				expect.truthy(row.R > 0, "R>0")
				expect.truthy(row.M > 0, "M>0")
			end
			expect.truthy(dupR < 5, "almost all R distinct")
		end,
	},
	{
		Name = "SoftCap probabilities sum to 1",
		Run = function()
			for _, L in { 1, 20, 150, 1e5 } do
				local p = SoftCapRarity.probabilities(L)
				local s = 0
				for _, pi in p do
					s += pi
				end
				expect.truthy(math.abs(s - 1) < 1e-9, `sum@{L}`)
			end
		end,
	},
	{
		Name = "SoftCap Luck changes mix (not cancelled at mid L)",
		Run = function()
			local d = SoftCapRarity.l1Distance(60, 150)
			expect.truthy(d > 0.05, `L1 dist 60vs150={d}`)
			local dLow = SoftCapRarity.l1Distance(0.5, 0.8)
			-- SoftCap should move slightly even when mostly uncapped
			expect.truthy(dLow > 0, `low-L dist={dLow}`)
		end,
	},
	{
		Name = "SoftCap avoids 99% Rare at L=150; SoftAC ladder does not",
		Run = function()
			local sc = SoftCapRarity.softCapBandPercents(150)
			local lad = SoftCapRarity.ladderBandPercents(150, 20000, 500000)
			expect.truthy(sc.Rare < 40, `SoftCap Rare={sc.Rare}`)
			expect.truthy(lad.Rare > 95, `Ladder Rare={lad.Rare}`)
			expect.truthy(sc.Epic > 0.3 and sc.Epic < 5, `SoftCap Epic={sc.Epic}`)
		end,
	},
	{
		Name = "Index 1/p_i is finite for every relic at L=150",
		Run = function()
			for _, relic in RelicConfig.Relics do
				local n = SoftCapRarity.effectiveOneIn(150, relic.Id)
				expect.truthy(n > 1 and n < 1e20, relic.Id)
			end
		end,
	},
	{
		Name = "Monte Carlo SoftCap band shares track closed-form at L=150",
		Run = function()
			local state = 424242
			local function rng()
				state = (state * 48271) % 2147483647
				return (state - 1) / 2147483646
			end
			local expected = SoftCapRarity.softCapBandPercents(150)
			local counts = {}
			local N = 20000
			for _ = 1, N do
				local _, tier = SoftCapRarity.roll(150, rng)
				counts[tier] = (counts[tier] or 0) + 1
			end
			for _, t in { "Common", "Uncommon", "Rare", "Epic" } do
				local obs = 100 * (counts[t] or 0) / N
				local exp = expected[t] or 0
				expect.truthy(math.abs(obs - exp) < 2.5, `{t}: obs={obs} exp={exp}`)
			end
		end,
	},
	{
		Name = "Luck sweep: no ~99% ordinary tier; Σp=1; SoftCap Rare stays below SoftAC Rare",
		Run = function()
			for _, L in LUCK_SWEEP do
				local sc = SoftCapRarity.softCapBandPercents(L)
				local lad = SoftCapRarity.ladderBandPercents(L, 20000, 500000)
				local sum = 0
				local maxBand = 0
				for _, t in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" } do
					sum += sc[t] or 0
					if (sc[t] or 0) > maxBand then
						maxBand = sc[t]
					end
				end
				expect.truthy(math.abs(sum - 100) < 1e-6, `sum@{L}={sum}`)
				expect.truthy(maxBand < 95, `SoftCap max band @{L}={maxBand}`)
				if L >= 60 and L <= 500 then
					expect.truthy((sc.Rare or 0) < (lad.Rare or 0) - 40, `Rare SoftCap<{L} SoftAC`)
				end
			end
		end,
	},
	{
		Name = "FLAG: SoftCap early Epic ~15× Soft A+C at L=1 (intentional, watch playtests)",
		Run = function()
			local sc1 = SoftCapRarity.softCapBandPercents(1)
			local lad1 = SoftCapRarity.ladderBandPercents(1, 20000, 500000)
			local ratio = (sc1.Epic or 0) / math.max(1e-12, lad1.Epic or 0)
			expect.truthy(ratio > 10 and ratio < 25, `Epic ratio L=1 SoftCap/SoftAC={ratio}`)
		end,
	},
	{
		Name = "RollMath SoftCap Sampler: itemProbability matches SoftCapRarity; Codex 1/p_i",
		Run = function()
			local ctx = RollMath.contextFor(rules, { FullLuck = 150, Sampler = "SoftCap" })
			expect.equal(ctx.Sampler, "SoftCap", "sampler")
			local pMap = SoftCapRarity.probabilities(150)
			local sum = 0
			for _, relic in RelicConfig.Relics do
				local p = RollMath.itemProbability(ctx, relic.Id)
				sum += p
				expect.truthy(math.abs(p - (pMap[relic.Id] or 0)) < 1e-12, relic.Id)
				local oneIn = if p > 0 then 1 / p else math.huge
				expect.truthy(oneIn > 1, `1/p {relic.Id}`)
			end
			expect.truthy(math.abs(sum - 1) < 1e-9, `Σp={sum}`)
		end,
	},
	{
		Name = "RollMath SoftCap roll + mutation uses one RNG stream (server-authoritative path)",
		Run = function()
			local ctx = RollMath.contextFor(rules, {
				FullLuck = 150,
				Sampler = "SoftCap",
				MutationRank = 1,
			})
			local state = 99
			local function rng()
				state = (state * 48271) % 2147483647
				return (state - 1) / 2147483646
			end
			local counts = {}
			for _ = 1, 5000 do
				local relic, mut = RollMath.roll(ctx, rng)
				counts[relic.Tier] = (counts[relic.Tier] or 0) + 1
				if mut then
					counts._mut = (counts._mut or 0) + 1
				end
			end
			expect.truthy((counts.Common or 0) > 1500, "commons present")
			expect.truthy((counts.Rare or 0) < 2000, "not Rare plateau")
			expect.truthy((counts._mut or 0) > 200 and (counts._mut or 0) < 800, `mut~10% got={counts._mut}`)
		end,
	},
	{
		Name = "SoftAC Ladder Sampler at Epic20k still ~99% Rare at L=150 (control)",
		Run = function()
			local softTiers = {}
			for _, tier in rules.Tiers do
				local denom = tier.Denominator
				if tier.Id == "Epic" then
					denom = 20000
				elseif tier.Id == "Legendary" then
					denom = 500000
				end
				table.insert(softTiers, { Id = tier.Id, Denominator = denom })
			end
			local softRules = table.clone(rules)
			softRules.Tiers = softTiers
			local ctx = RollMath.contextFor(softRules, { FullLuck = 150, Sampler = "Ladder" })
			expect.equal(ctx.Sampler, "Ladder", "sampler")
			local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
			local rareI = RollMath.tierIndexOf(ctx.Tiers, "Rare") :: number
			expect.truthy(masses[rareI] > 0.95, `SoftAC Rare mass={masses[rareI]}`)
		end,
	},
}
