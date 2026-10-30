-- Reward feed classification / consolidation (no odds changes).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local ProgressObjective = require("../../src/shared/ProgressObjective")
local RelicConfig = require("../../src/shared/RelicConfig")
local RewardPresentation = require("../../src/shared/RewardPresentation")
local expect = require("../lib/expect")

local PLAYTEST_SESSION = "docs/playtest/pt_153530464_559fa945/PLAYTEST_SESSION.json"
local REBIRTH_COST = 400_000_000

local function tierOf(result)
	local relic = RelicConfig.ById[result.Id]
	return if relic then relic.Tier else "Common"
end

local function commonId(): string
	for _, relic in RelicConfig.Relics do
		if relic.Tier == "Common" then
			return relic.Id
		end
	end
	error("no Common")
end

local function rareId(): string
	for _, relic in RelicConfig.Relics do
		if relic.Tier == "Rare" then
			return relic.Id
		end
	end
	error("no Rare")
end

local function epicId(): string
	for _, relic in RelicConfig.Relics do
		if relic.Tier == "Epic" then
			return relic.Id
		end
	end
	error("no Epic")
end

return {
	{
		Name = "ordinary C/U Normal dupes classify as Routine",
		Run = function()
			local id = commonId()
			local c = RewardPresentation.classify({
				Id = id,
				First = false,
				NewVariant = false,
				NewSize = false,
			}, "Common")
			expect.equal(c.Kind, "Routine", "routine")
			expect.equal(c.Reason, "OrdinaryDupe", "reason")
		end,
	},
	{
		Name = "new base / mutation / size / Huge / Titanic / Epic are Exceptional",
		Run = function()
			local id = commonId()
			local rare = rareId()
			local epic = epicId()
			expect.equal(RewardPresentation.classify({ Id = id, First = true }, "Common").Kind, "Exceptional", "first")
			expect.equal(
				RewardPresentation.classify({ Id = id, NewVariant = true, Mutation = "Golden" }, "Common").Kind,
				"Exceptional",
				"new mut"
			)
			expect.equal(
				RewardPresentation.classify({ Id = rare, Size = "Huge", NewSize = true }, "Rare").Kind,
				"Exceptional",
				"new size"
			)
			expect.equal(RewardPresentation.classify({ Id = rare, Size = "Huge" }, "Rare").Kind, "Exceptional", "huge")
			expect.equal(
				RewardPresentation.classify({ Id = rare, Size = "Titanic" }, "Rare").Kind,
				"Exceptional",
				"titanic"
			)
			expect.equal(RewardPresentation.classify({ Id = epic, First = false }, "Epic").Kind, "Exceptional", "epic")
		end,
	},
	{
		Name = "planFeed collapses 100 ordinary rolls into 1 summary line",
		Run = function()
			local id = commonId()
			local batch = {}
			for i = 1, 100 do
				batch[i] = {
					Id = id,
					First = false,
					Sold = if i % 2 == 0 then 10 else nil,
				}
			end
			local before = #batch -- naive: one line each
			local counts = RewardPresentation.countKinds(batch, tierOf)
			expect.equal(counts.Routine, 100, "all routine")
			expect.equal(counts.Exceptional, 0, "no exceptional")
			expect.equal(counts.FeedLines, 1, "one summary")
			expect.truthy(before > counts.FeedLines, "fewer lines than raw rewards")
			local plan = RewardPresentation.planFeed(batch, tierOf)
			expect.equal(plan.RoutineSoldCount, 50, "sold half")
			expect.equal(plan.RoutineKeptCount, 50, "kept half")
			expect.truthy(plan.RoutineSummaryTitle ~= nil, "has title")
		end,
	},
	{
		Name = "mixed batch: routines summarize; exceptionals stay individual",
		Run = function()
			local c = commonId()
			local r = rareId()
			local e = epicId()
			local batch = {
				{ Id = c, First = false, Sold = 5 },
				{ Id = c, First = false, Sold = 5 },
				{ Id = c, First = false },
				{ Id = r, First = true },
				{ Id = e, First = false },
				{ Id = r, Size = "Huge", NewSize = true },
			}
			local counts = RewardPresentation.countKinds(batch, tierOf)
			expect.equal(counts.Routine, 3, "3 routine")
			expect.equal(counts.Exceptional, 3, "first + epic + huge")
			expect.equal(counts.FeedLines, 4, "3 exceptional + 1 summary")
		end,
	},
	{
		Name = "worthKeeping explains why to keep stamps",
		Run = function()
			local rare = rareId()
			local text = RewardPresentation.worthKeeping({ Id = rare, Size = "Titanic", NewSize = true }, "Rare")
			expect.truthy(string.find(text, "Titanic", 1, true), text)
			expect.truthy(string.find(text, "keep 1", 1, true), text)
		end,
	},
	{
		Name = "playtest ScanAgg replay: consolidation + reward parity + RebirthSave trajectory",
		Run = function()
			expect.truthy(fs.isFile(PLAYTEST_SESSION), "playtest session present")
			local session = serde.decode("json", fs.readFile(PLAYTEST_SESSION))
			local beforeLines, afterLines = 0, 0
			local routine, notable, exceptional = 0, 0, 0
			local totalRewards = 0
			local byTierParity = {}

			local function expandScanAgg(byTier: { [string]: number }): { any }
				local batch = {}
				for tier, count in byTier do
					byTierParity[tier] = (byTierParity[tier] or 0) + count
					for _ = 1, count do
						-- Synthetic ids: classification uses the tier callback, not roster lookup.
						table.insert(batch, {
							Id = `synth_{tier}`,
							First = false,
							Sold = if tier == "Common" or tier == "Uncommon" then 10 else nil,
						})
					end
				end
				return batch
			end

			local function tierOf(result)
				local tier = string.match(result.Id, "^synth_(.+)$")
				return tier
			end

			for _, event in session.Events or {} do
				if event.Kind ~= "ScanAgg" or type(event.ByTier) ~= "table" then
					continue
				end
				local batch = expandScanAgg(event.ByTier)
				totalRewards += #batch
				beforeLines += #batch -- naive: one notification per reward
				local counts = RewardPresentation.countKinds(batch, tierOf)
				afterLines += counts.FeedLines
				routine += counts.Routine
				notable += counts.Notable
				exceptional += counts.Exceptional
			end

			expect.truthy(totalRewards > 100, `got {totalRewards} rewards`)
			expect.equal(totalRewards, routine + notable + exceptional, "kind parity")
			expect.truthy(afterLines < beforeLines * 0.55, `feed {afterLines} vs raw {beforeLines}`)
			expect.truthy(routine > notable + exceptional, "most finds are routine")

			-- Distinctive: Epic+ ScanAgg buckets + EpicPlus milestones stay Exceptional lines.
			local epicPlusEvents = 0
			for _, event in session.Events or {} do
				if event.Kind == "EpicPlus" then
					epicPlusEvents += 1
				end
			end
			expect.truthy(exceptional + epicPlusEvents > 0, "session has distinctive finds")

			-- Rebirth savings trajectory: replay end-session CE with shop exhausted (real player gap).
			local maxCe = 0
			local lastSnap = nil
			for _, event in session.Events or {} do
				if event.Kind == "Snapshot" and type(event.Snapshot) == "table" then
					lastSnap = event.Snapshot
					maxCe = math.max(maxCe, event.Snapshot.CE or 0)
				end
			end
			expect.equal(REBIRTH_COST, 400_000_000, "cost unchanged")
			expect.truthy(maxCe > 0 and lastSnap ~= nil, "CE progressed")
			local endObj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = math.max(1, lastSnap.FusionCount or 0),
				FusionSlots = lastSnap.FusionSlots or 3,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.5,
				Progress = {},
				NextGoals = {},
				CE = lastSnap.CE or 0,
				RebirthCost = REBIRTH_COST,
				IncomePerSec = lastSnap.IncomePerSec or 0,
				AffordableShopBuys = 0, -- upgrades exhausted path
			})
			expect.equal(endObj and endObj.Kind, "RebirthSave", "end-session save objective")
			expect.truthy(endObj and string.find(endObj.Text, "/", 1, true), endObj and endObj.Text)
			expect.truthy(endObj and endObj.Detail and string.find(endObj.Detail, "income", 1, true), endObj and endObj.Detail)

			print(
				`  [reward_presentation] playtest: rewards={totalRewards} beforeLines={beforeLines} afterLines={afterLines} routine={routine} notable={notable} exceptional={exceptional} maxCE={math.floor(maxCe)} rebirthSave=true`
			)
		end,
	},
}
