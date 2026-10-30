-- Studio playtest analytics export builders + rarity counters (Lune-safe).

local PlaytestAnalyticsExport = require("../../src/shared/PlaytestAnalyticsExport")
local BalanceTrials = require("../../src/shared/BalanceTrials")
local expect = require("../lib/expect")

local function sampleSession(): PlaytestAnalyticsExport.Session
	return {
		SessionId = "pt_test_abc",
		StartedAtUnix = 1_700_000_000,
		EndedAtUnix = 1_700_001_800,
		DurationSec = 1800,
		Events = {
			{ Id = "e1", Kind = "Purchase", ElapsedSec = 12, Elapsed = "00:12" },
			{ Id = "e2", Kind = "Milestone", ElapsedSec = 60, Elapsed = "01:00" },
			{ Id = "cf1", Kind = "CollectionFunnel", Event = "CollectionOpen", ElapsedSec = 90, Elapsed = "01:30" },
			{ Id = "cf2", Kind = "CollectionFunnel", Event = "FuseComplete", Detail = "Foo:r1", ElapsedSec = 120, Elapsed = "02:00" },
		},
		Purchases = {
			{
				Elapsed = "00:12",
				ElapsedSec = 12,
				System = "Skill",
				Item = "CoreLuck",
				RankBefore = 0,
				RankAfter = 1,
				Price = 100,
				Currency = "CE",
				CEBefore = 500,
				CEAfter = 400,
				EssenceBefore = 0,
				EssenceAfter = 0,
				Luck = 1.2,
				IncomePerSec = 3.5,
				Rebirths = 0,
				SecSincePrev = 0,
				Kind = "Unlock",
				Ok = true,
				Reason = "ok",
			},
			{
				Elapsed = "02:00",
				ElapsedSec = 120,
				System = "Skill",
				Item = "CoreLuck",
				RankBefore = 1,
				RankAfter = 1,
				Price = 160,
				Currency = "CE",
				CEBefore = 150,
				CEAfter = 150,
				EssenceBefore = 2,
				EssenceAfter = 2,
				Luck = 1.3,
				IncomePerSec = 4,
				Rebirths = 0,
				SecSincePrev = 108,
				Kind = "Failed",
				Ok = false,
				Reason = "Need more CE",
			},
		},
		Milestones = {
			{ Elapsed = "01:00", Label = "First Epic", Detail = "relic_x" },
			{ Elapsed = "10:00", Label = "Rebirth → 1", Detail = "Rebirth" },
		},
		Snapshots = {
			{ ElapsedSec = 0, CE = 500, Essence = 0, Luck = 1, Rebirths = 0 },
			{ ElapsedSec = 600, CE = 2000, Essence = 5, Luck = 2, Rebirths = 1 },
		},
		MinuteMarks = {
			{
				Minute = 5,
				Snapshot = {
					CE = 800,
					Essence = 1,
					Luck = 1.5,
					IncomePerSec = 5,
					CoreLuck = 3,
					Rebirths = 0,
					UniqueDiscoveries = 12,
					EpicExact = 1,
					MutationGoals = 0,
					FusionRanks = 0,
				},
			},
		},
		Activity = {
			Scan = 900,
			Hunt = 200,
			Travel = 100,
			UpgradeUI = 150,
			CollectionUI = 80,
			Pedestal = 40,
			Idle = 30,
			Other = 20,
		},
		ScanAgg = { { Elapsed = "05:00", Total = 40, ByTier = { Common = 30, Rare = 10 } } },
		Friction = {
			LongestGapMin = 6.5,
			MeaningfulCount = 8,
			RoutinePurchases = 12,
			FailedPurchases = 1,
			EpicExact = 2,
			UniqueEpicExact = 1,
			DuplicateSells = 15,
			UnusedUnlocks = { "Goal:ThreeMutated" },
			HuntCaptures = 3,
			ScanBatches = 20,
			MaxEssenceIdleMin = 4.2,
			CollectionUISec = 42.5,
			CollectionPanelVisits = 2,
			CollectionFailedAttempts = 1,
			Inferences = { "Session appears scan-heavy relative to spirit captures (inferred)." },
			Findings = { "Observed ≥5 min without a meaningful unlock (longest 6.5 min)." },
		},
		Meta = {
			Studio = true,
			Balance = "E20k_L12_C17_HR",
			Collection = true,
			AnonymousPlayerKey = "P12345",
		},
	}
end

return {
	{
		Name = "tracking stays off in Lune/production path",
		Run = function()
			expect.equal(BalanceTrials.collectionEnabled(), false, "collection off outside Studio")
			expect.equal(BalanceTrials.current(), nil, "no live trial")
		end,
	},
	{
		Name = "formatElapsed is MM:SS",
		Run = function()
			expect.equal(PlaytestAnalyticsExport.formatElapsed(0), "00:00", "zero")
			expect.equal(PlaytestAnalyticsExport.formatElapsed(65), "01:05", "65s")
			expect.equal(PlaytestAnalyticsExport.formatElapsed(1800), "30:00", "30m")
		end,
	},
	{
		Name = "purchases csv timestamps prices and balances",
		Run = function()
			local csv = PlaytestAnalyticsExport.purchasesCsv(sampleSession())
			expect.truthy(string.find(csv, "Elapsed,ElapsedSec,System,Item", 1, true), "header")
			expect.truthy(string.find(csv, "00:12,12,Skill,CoreLuck,0,1,100,CE,500,400", 1, true), "buy row")
			expect.truthy(string.find(csv, "false,Need more CE", 1, true), "failed row")
			local lines = string.split(csv, "\n")
			-- header + 2 purchases + trailing empty from final newline
			expect.truthy(#lines >= 3, "at least header + 2 rows")
		end,
	},
	{
		Name = "summary markdown includes purchases milestones friction",
		Run = function()
			local md = PlaytestAnalyticsExport.summaryMarkdown(sampleSession())
			expect.truthy(string.find(md, "pt_test_abc", 1, true), "session id")
			expect.truthy(string.find(md, "Chronological purchases", 1, true), "purchases")
			expect.truthy(string.find(md, "First Epic", 1, true), "milestone")
			expect.truthy(string.find(md, "Failed purchases", 1, true), "failed")
			expect.truthy(string.find(md, "Need more CE", 1, true), "fail reason")
			expect.truthy(string.find(md, "Inferred notes", 1, true), "inferences separate")
			expect.truthy(string.find(md, "scan-heavy", 1, true), "inference text")
			expect.truthy(string.find(md, "Longest gap", 1, true), "friction")
			expect.truthy(string.find(md, "Rebirth → 1", 1, true), "rebirth kept in history")
			expect.truthy(string.find(md, "Collection HUD funnel", 1, true), "funnel section")
			expect.truthy(string.find(md, "CollectionOpen", 1, true), "open count")
			expect.truthy(string.find(md, "FuseComplete", 1, true), "fuse count")
			expect.truthy(string.find(md, "Time in Collection UI", 1, true), "dwell time")
			expect.truthy(string.find(md, "42.5", 1, true), "dwell seconds")
		end,
	},
	{
		Name = "session json is complete and ordered events preserved",
		Run = function()
			local session = sampleSession()
			local json = PlaytestAnalyticsExport.sessionJson(session)
			expect.truthy(string.find(json, '"SessionId":"pt_test_abc"', 1, true), "id")
			expect.truthy(string.find(json, '"Purchases":[', 1, true), "purchases")
			expect.truthy(string.find(json, '"Events":[', 1, true), "events")
			local e1 = string.find(json, '"Id":"e1"', 1, true)
			local e2 = string.find(json, '"Id":"e2"', 1, true)
			expect.truthy(e1 ~= nil and e2 ~= nil and e1 < e2, "event order")
			-- currency balances match purchase rows
			expect.truthy(string.find(json, '"CEBefore":500', 1, true), "ce before")
			expect.truthy(string.find(json, '"CEAfter":400', 1, true), "ce after")
			expect.truthy(string.find(json, '"Price":100', 1, true), "price")
		end,
	},
	{
		Name = "rarity metrics distinguish exact Epic from Epic-or-higher",
		Run = function()
			local m = PlaytestAnalyticsExport.newRarityMetrics()
			local epic = 4
			-- Epic relic A twice
			PlaytestAnalyticsExport.noteDiscovery(m, "A", 4, epic, true)
			PlaytestAnalyticsExport.noteDiscovery(m, "A", 4, epic, false)
			-- Legendary (epic+) relic B
			PlaytestAnalyticsExport.noteDiscovery(m, "B", 5, epic, true)
			-- Rare (below)
			PlaytestAnalyticsExport.noteDiscovery(m, "C", 3, epic, true)
			expect.equal(m.EpicExact, 2, "exact epic drops")
			expect.equal(m.UniqueEpicExact, 1, "unique exact epic ids")
			expect.equal(m.EpicPlus, 3, "epic+ drops (2 epic + 1 legendary)")
			expect.equal(m.UniqueEpicPlus, 2, "unique epic+ ids A+B")
			expect.equal(m.UniqueCount, 3, "unique relics")
		end,
	},
	{
		Name = "export has no duplicate purchase rows for same timeline",
		Run = function()
			local session = sampleSession()
			local csv = PlaytestAnalyticsExport.purchasesCsv(session)
			local count = 0
			for _ in string.gmatch(csv, "Skill,CoreLuck") do
				count += 1
			end
			expect.equal(count, 2, "exactly two CoreLuck lines (success + fail)")
			local json = PlaytestAnalyticsExport.sessionJson(session)
			local ids = {}
			for id in string.gmatch(json, '"Id":"(e%d+)"') do
				expect.equal(ids[id], nil, `no dup event {id}`)
				ids[id] = true
			end
		end,
	},
	{
		Name = "rebirth milestone does not erase prior purchases in export",
		Run = function()
			local session = sampleSession()
			-- Simulate post-rebirth append (session history kept)
			table.insert(session.Purchases, {
				Elapsed = "12:00",
				ElapsedSec = 720,
				System = "Resonance",
				Item = "Seeker",
				RankBefore = 0,
				RankAfter = 1,
				Price = 0,
				Currency = "Essence",
				CEBefore = 0,
				CEAfter = 0,
				EssenceBefore = 5,
				EssenceAfter = 5,
				Luck = 2,
				IncomePerSec = 8,
				Rebirths = 1,
				SecSincePrev = 600,
				Kind = "Specialization",
				Ok = true,
				Reason = "ok",
			})
			local csv = PlaytestAnalyticsExport.purchasesCsv(session)
			expect.truthy(string.find(csv, "00:12,12,Skill,CoreLuck", 1, true), "pre-rebirth buy")
			expect.truthy(string.find(csv, "12:00,720,Resonance,Seeker", 1, true), "post-rebirth")
			expect.truthy(string.find(csv, ",1,", 1, true), "rebirth count column present")
			local md = PlaytestAnalyticsExport.summaryMarkdown(session)
			expect.truthy(string.find(md, "CoreLuck", 1, true), "old purchase in summary")
			expect.truthy(string.find(md, "Resonance/Seeker", 1, true), "new purchase in summary")
		end,
	},
}
