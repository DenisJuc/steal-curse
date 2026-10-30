-- Search SoftCap BAND_M / BAND_R tweaks for SoftCap_P5. Run: lune run tests/softCapBandCandidates
-- Does not modify shipping SoftCap_P4 Default profile.

local SoftCapRarity = require("../src/shared/SoftCapRarity")
local SizeConfig = require("../src/shared/SizeConfig")
local RarityConfig = require("../src/shared/RarityConfig")

local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }
local RPM = 49

local function cloneM(base)
	local t = {}
	for k, v in base do
		t[k] = v
	end
	return t
end

local function cloneR(base)
	local t = {}
	for k, v in base do
		t[k] = { v[1], v[2] }
	end
	return t
end

local function apply(profileId: string, M, R)
	SoftCapRarity.registerProfile(profileId, { M = M, R = R })
	SoftCapRarity.setProfile(profileId)
end

local function bands(luck: number)
	return SoftCapRarity.softCapBandPercents(luck)
end

local function ePlus(b)
	local s = 0
	for _, t in TIERS do
		local idx = RarityConfig.IndexById[t] or 0
		if idx >= (RarityConfig.IndexById.Epic or 4) then
			s += b[t] or 0
		end
	end
	return s
end

local function score(name: string, M, R)
	apply(name, M, R)
	local pts = { 1, 10, 30, 50, 80, 150 }
	local rows = {}
	local ok = true
	local reasons = {}
	for _, L in pts do
		local b = bands(L)
		local sum = 0
		for _, t in TIERS do
			sum += b[t] or 0
		end
		if math.abs(sum - 100) > 0.05 then
			ok = false
			table.insert(reasons, `sum@{L}={sum}`)
		end
		local rare = b.Rare or 0
		local ep = ePlus(b)
		if rare > 40 then
			ok = false
			table.insert(reasons, `Rare wall @{L}={rare}`)
		end
		if ep > 8 then
			ok = false
			table.insert(reasons, `Epic flood @{L}={ep}`)
		end
		table.insert(rows, { L = L, C = b.Common, U = b.Uncommon, R = rare, E = ep })
	end
	local b80 = bands(80)
	local b1 = bands(1)
	local b30 = bands(30)
	local target =
		-- Prefer mid-session cut of Common without Rare wall / Epic flood
		math.abs((b80.Common or 0) - 40)
		+ math.abs((b80.Uncommon or 0) - 34)
		+ math.abs((b80.Rare or 0) - 18)
		+ math.abs(ePlus(b80) - 1.6) * 8
		-- Luck should visibly move Common down
		+ math.max(0, 8 - ((b1.Common or 0) - (b80.Common or 0))) * 2
		-- Early game still Common-led
		+ math.max(0, 55 - (b1.Common or 0)) * 1.5
		-- Avoid parking spam in Uncommon
		+ math.max(0, (b80.Uncommon or 0) - 40) * 2
		+ math.max(0, (b30.Rare or 0) - 25) * 3

	-- Soft size absolute rates at L80 (should stay in same ballpark; SizeConfig unchanged)
	local pH, pT = 0, 0
	for _, tier in TIERS do
		local share = (b80[tier] or 0) / 100
		local row = SizeConfig.ChanceByTier[tier]
		pH += share * (row.Huge or 0)
		pT += share * (row.Titanic or 0)
	end
	local epic22 = ePlus(b80) / 100 * RPM * 22.5
	return {
		Name = name,
		Ok = ok,
		Reasons = reasons,
		Score = target,
		Rows = rows,
		Epic22 = epic22,
		PHuge = pH,
		PTit = pT,
		B80 = b80,
	}
end

-- Restore Default first so register works
SoftCapRarity.setProfile("Default")
local baseM = SoftCapRarity.bandM()
local baseR = SoftCapRarity.bandR()

local candidates = {}

-- A: mild Common M cut, Rare/Epic M bump
do
	local M = cloneM(baseM)
	M.Common = 0.72
	M.Uncommon = 0.95
	M.Rare = 1.15
	M.Epic = 0.48
	M.Legendary = 0.14
	table.insert(candidates, score("SoftenA", M, cloneR(baseR)))
end

-- B: stronger Common R stretch + Rare R compress
do
	local M = cloneM(baseM)
	M.Common = 0.78
	M.Uncommon = 1.0
	M.Rare = 1.05
	M.Epic = 0.45
	local R = cloneR(baseR)
	R.Common = { 3.5, 28.0 }
	R.Rare = { 90.0, 700.0 }
	R.Epic = { 1800.0, 18000.0 }
	table.insert(candidates, score("SoftenB", M, R))
end

-- C: balanced target-seek (more aggressive Common cut)
do
	local M = cloneM(baseM)
	M.Common = 0.62
	M.Uncommon = 0.92
	M.Rare = 1.25
	M.Epic = 0.55
	M.Legendary = 0.16
	M.Mythic = 0.05
	local R = cloneR(baseR)
	R.Common = { 2.8, 24.0 }
	R.Uncommon = { 20.0, 85.0 }
	R.Rare = { 100.0, 750.0 }
	R.Epic = { 2000.0, 20000.0 }
	table.insert(candidates, score("SoftenC", M, R))
end

-- D: Luck-forward — keep early Common high, pull harder after L30
do
	local M = cloneM(baseM)
	M.Common = 0.85
	M.Uncommon = 1.05
	M.Rare = 1.35
	M.Epic = 0.58
	M.Legendary = 0.18
	local R = cloneR(baseR)
	R.Common = { 2.2, 20.0 }
	R.Rare = { 80.0, 650.0 }
	R.Epic = { 1600.0, 16000.0 }
	table.insert(candidates, score("SoftenD", M, R))
end

-- E: conservative — small moves only
do
	local M = cloneM(baseM)
	M.Common = 0.88
	M.Rare = 1.0
	M.Epic = 0.42
	table.insert(candidates, score("SoftenE", M, cloneR(baseR)))
end

table.sort(candidates, function(a, b)
	if a.Ok ~= b.Ok then
		return a.Ok
	end
	return a.Score < b.Score
end)

print("=== SoftCap band candidates (lower score better; Ok=no Rare wall / Epic flood) ===\n")
for _, c in candidates do
	print(string.format(
		"%s  score=%.1f  ok=%s  E[Epic+]/22m@L80]=%.1f  P(Huge)@L80=%.5f",
		c.Name,
		c.Score,
		tostring(c.Ok),
		c.Epic22,
		c.PHuge
	))
	if not c.Ok then
		print("  FAIL: " .. table.concat(c.Reasons, "; "))
	end
	for _, row in c.Rows do
		print(string.format(
			"  L%-3d  C=%5.1f  U=%5.1f  R=%5.1f  E+=%4.2f",
			row.L,
			row.C,
			row.U,
			row.R,
			row.E
		))
	end
	print("")
end

local best = candidates[1]
print(`WINNER: {best.Name} (score={string.format("%.1f", best.Score)})`)
SoftCapRarity.setProfile("Default")
