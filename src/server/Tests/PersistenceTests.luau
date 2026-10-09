-- Studio persistence tests (run with /runtests). They use ProfileStore's MOCK store, which behaves
-- like the real one (session lock, save, end session, reload) but never touches real player data.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataTemplate = require(script.Parent.Parent.Data.DataTemplate)
local DataService = require(script.Parent.Parent.Services.DataService)
local DiscoveryPipeline = require(script.Parent.Parent.DiscoveryPipeline)

local PersistenceTests = {}

export type Result = { Name: string, Ok: boolean, Error: string? }

local SAVE_TIMEOUT = 20

local function firstRelicOfTier(tierId: string): string
	for _, relic in RelicConfig.Relics do
		if relic.Tier == tierId then
			return relic.Id
		end
	end
	error(`no relic of tier {tierId}`)
end

local function check(condition: any, message: string)
	if not condition then
		error(message, 2)
	end
end

local function mockStore(): any
	return DataService.GetStore().Mock
end

local function newKey(): string
	return "Test_" .. string.sub(HttpService:GenerateGUID(false), 1, 18)
end

local function waitForSave(profile: any, action: () -> ())
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	action()
	local started = os.clock()
	while not saved and os.clock() - started < SAVE_TIMEOUT do
		task.wait(0.05)
	end
	connection:Disconnect()
	check(saved, "save did not finish in time")
end

local function open(key: string): any
	local profile = mockStore():StartSessionAsync(key)
	check(profile, "mock session did not start")
	DataService.PrepareProfile(profile)
	return profile
end

local function endAndReopen(profile: any, key: string): any
	waitForSave(profile, function()
		profile:EndSession()
	end)
	check(not profile:IsActive(), "session should be inactive after EndSession")
	return open(key)
end

local function findItem(data: any, relicId: string, mutation: string?): any
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation == mutation then
			return item
		end
	end
	return nil
end

local TESTS: { { Name: string, Run: () -> () } } = {
	{
		Name = "Cosmic Abyssal survives session end and reload",
		Run = function()
			local key = newKey()
			local cosmic = firstRelicOfTier("Cosmic")
			local profile = open(key)
			local _, first, priority = DiscoveryPipeline.ApplyEntry(
				profile.Data,
				{ Id = cosmic, Mutation = "Abyssal", Source = "Debug" },
				os.time()
			)
			check(first and priority, "a first Cosmic must be a priority find")
			local reloaded = endAndReopen(profile, key)
			check(findItem(reloaded.Data, cosmic, "Abyssal"), "Cosmic Abyssal missing after reload")
			check(reloaded.Data.Discovered[cosmic], "Codex discovery missing after reload")
			local history = reloaded.Data.RareHistory[1]
			check(history and history.Id == cosmic and history.Mutation == "Abyssal", "rare history missing")
			reloaded:EndSession()
		end,
	},
	{
		Name = "priority save stores the find while the session stays open",
		Run = function()
			local key = newKey()
			local mythic = firstRelicOfTier("Mythic")
			local profile = open(key)
			DiscoveryPipeline.ApplyEntry(profile.Data, { Id = mythic, Source = "Scan" }, os.time())
			waitForSave(profile, function()
				profile:Save()
			end)
			check(profile:IsActive(), "session should still be active")
			check(findItem(profile.LastSavedData, mythic, nil), "saved copy is missing the Mythic")
			profile:EndSession()
		end,
	},
	{
		Name = "a full capture batch (1 + 42 bonus) survives reload",
		Run = function()
			local key = newKey()
			local profile = open(key)
			local now = os.time()
			DiscoveryPipeline.ApplyEntry(profile.Data, { Id = firstRelicOfTier("Rare"), Source = "Capture" }, now)
			for _ = 1, 42 do
				DiscoveryPipeline.ApplyEntry(profile.Data, { Id = firstRelicOfTier("Common"), Source = "Bonus" }, now)
			end
			local reloaded = endAndReopen(profile, key)
			check(#reloaded.Data.Inventory == 43, `expected 43 items, got {#reloaded.Data.Inventory}`)
			check(reloaded.Data.NextUid == 44, `expected NextUid 44, got {reloaded.Data.NextUid}`)
			reloaded:EndSession()
		end,
	},
	{
		Name = "CE, bought pedestals, levels, locks and offline snapshot survive reload",
		Run = function()
			local key = newKey()
			local profile = open(key)
			local data = profile.Data
			local item = DiscoveryPipeline.ApplyEntry(data, { Id = firstRelicOfTier("Epic"), Source = "Scan" }, os.time())
			data.CE = 1234.56
			table.insert(data.Pedestals, { Level = 7, Locked = true, Uid = item.Uid })
			data.Settings.AutoDisplay = false
			data.Offline.IncomePerMin = 321
			data.Offline.At = 1700000000
			local reloaded = endAndReopen(profile, key)
			local after = reloaded.Data
			check(math.abs(after.CE - 1234.56) < 1e-9, `CE lost fractions: {after.CE}`)
			check(#after.Pedestals == 4, `expected 4 pedestals, got {#after.Pedestals}`)
			local fourth = after.Pedestals[4]
			check(fourth.Level == 7 and fourth.Locked == true and fourth.Uid == item.Uid, "pedestal 4 not restored")
			check(after.Settings.AutoDisplay == false, "Auto-Display setting lost")
			check(after.Offline.IncomePerMin == 321 and after.Offline.At == 1700000000, "offline snapshot lost")
			reloaded:EndSession()
		end,
	},
	{
		Name = "save priority rules (first find, Mythic+, mutated Legendary+)",
		Run = function()
			local data = DataTemplate.fresh()
			local now = os.time()
			local function apply(tierId: string, mutation: string?): (boolean, boolean)
				local _, first, priority =
					DiscoveryPipeline.ApplyEntry(data, { Id = firstRelicOfTier(tierId), Mutation = mutation, Source = "Scan" }, now)
				return first, priority
			end
			local first, priority = apply("Common")
			check(first and priority, "first Common is a first discovery")
			first, priority = apply("Common", "Golden")
			check(not first and not priority, "repeat mutated Common is not priority (same Codex entry)")
			apply("Legendary")
			_, priority = apply("Legendary")
			check(not priority, "repeat plain Legendary is not priority")
			_, priority = apply("Legendary", "Golden")
			check(priority, "mutated Legendary is priority")
			apply("Mythic")
			_, priority = apply("Mythic")
			check(priority, "repeat Mythic is still priority")
			local epicsBefore = #data.RareHistory
			apply("Epic")
			check(#data.RareHistory == epicsBefore + 1, "Epic goes into rare history")
		end,
	},
	{
		Name = "a mutated-only find marks the base Codex entry and its mutation, and both survive reload",
		Run = function()
			local key = newKey()
			local profile = open(key)
			local relicId = firstRelicOfTier("Rare")
			local _, first, _, newVariant =
				DiscoveryPipeline.ApplyEntry(profile.Data, { Id = relicId, Mutation = "Corrupted", Source = "Scan" }, 1234)
			check(first and newVariant, "mutated-only find should be first + new variant")
			local _, againFirst, _, againVariant =
				DiscoveryPipeline.ApplyEntry(profile.Data, { Id = relicId, Source = "Scan" }, 1300)
			check(not againFirst and not againVariant, "plain copy is neither a new entry nor a new variant")
			profile.Data.CodexMilestones.Essential20 = 1234
			profile.Data.CodexReady.Essential40 = 1240
			local reloaded = endAndReopen(profile, key)
			local after = reloaded.Data
			check(after.Discovered[relicId] == 1234, "base Codex entry lost")
			check(after.CodexMutations[relicId] and after.CodexMutations[relicId].Corrupted == 1234, "seen mutation lost")
			check(after.CodexMilestones.Essential20 == 1234, "claimed milestone lost")
			check(after.CodexReady.Essential40 == 1240, "ready-to-claim milestone lost")
			reloaded:EndSession()
		end,
	},
	{
		Name = "old unversioned data migrates and keeps its relics",
		Run = function()
			local key = newKey()
			local profile = mockStore():StartSessionAsync(key)
			check(profile, "mock session did not start")
			profile.Data = {
				TotalScans = 12,
				TotalCaptures = 1,
				NextUid = 3,
				Inventory = {
					{ Uid = 1, Id = firstRelicOfTier("Common"), At = 100, Source = "Scan" },
					{ Uid = 2, Id = firstRelicOfTier("Epic"), At = 200, Source = "Capture" },
				},
			}
			waitForSave(profile, function()
				profile:EndSession()
			end)
			local reloaded = open(key)
			local data = reloaded.Data
			check(data.DataVersion == DataTemplate.Version, "DataVersion not upgraded")
			check(#data.Inventory == 2 and data.TotalScans == 12, "old values lost")
			check(data.Discovered[firstRelicOfTier("Epic")] == 200, "Discovered not rebuilt from inventory")
			check(data.Settings and data.Settings.RarityFocus == "MaxLuck", "new fields not reconciled")
			reloaded:EndSession()
		end,
	},
	{
		Name = "data from a newer game version is not downgraded",
		Run = function()
			local data = { DataVersion = DataTemplate.Version + 5, Custom = true }
			local profile = {
				Data = data,
				Reconcile = function()
					error("must not reconcile newer data")
				end,
			}
			check(DataService.PrepareProfile(profile) == "Newer", "expected Newer")
			check(data.DataVersion == DataTemplate.Version + 5 and data.Custom, "newer data was modified")
		end,
	},
}

function PersistenceTests.Run(): { Result }
	local results = {}
	for _, test in TESTS do
		local ok, err = pcall(test.Run)
		table.insert(results, { Name = test.Name, Ok = ok, Error = if ok then nil else tostring(err) })
	end
	return results
end

return PersistenceTests
