-- Studio-only chat commands for fast testing. Nothing here is created outside Studio.
--   /roll [count]      instant extra scans (max Config.Debug.MaxRollsPerCommand)
--   /roll <tier>       instant relic of that tier, e.g. /roll cosmic
--   /scanspeed <sec>   change your scan interval; /scanspeed reset restores it
--   /wipedata          reset your data to a fresh profile
--   /hunt [district]   teleport to the nearest district gate, or forest / village / ruins
--   /mapstats          part counts of the map and each district vs the part budget
--   /spawnsignal       spawn one of your signals right in front of you (ignores the cap)
--   /regen             refill your signals to the maximum
--   /bindtime <sec>    change your hold-to-bind time; /bindtime reset restores it
--   /huntstats         captures, cancels and average time between captures this session
--   /forceroll <tier|relicId> [mutation]   grant an exact relic, e.g. /forceroll cosmic abyssal
--   /simroll [count]   simulate rolls with your current context and compare with the math (Output)
--   /setluck <x>       extra debug luck multiplier; /setluck reset
--   /luckrank <n>      set Core Luck rank 0..100
--   /focus <tier|max>  set Rarity Focus
--   /freq <family|all> set Signal Frequency
--   /mutrank <n>       set Mutation Resonance rank 0..5
--   /savestatus        save mode, last save time and counts
--   /runtests          run the persistence tests on the ProfileStore mock
--   /ce <amount>       add CE (negative removes); /ce set <amount>
--   /offline <seconds> pretend you were away that long, pay offline earnings and show Welcome Back
--   /afksim [minutes]  simulate an AFK stretch with anti-AFK hops (scans + shrine CE), then show
--                      Welcome Back as if you just came back (default 30)
--   /pedlevel <slot> <level>   set a pedestal level directly
--   /give <relicId> [mutation|none] [count]   grant exact copies through the full pipeline (auto-sell included)
--   /codexfill [n]     mark the first n relics (rarity order, default all) as discovered, without items

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Stats = require(ReplicatedStorage.Shared.Stats)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local AfkService = require(script.Parent.Services.AfkService)
local BindService = require(script.Parent.Services.BindService)
local CodexService = require(script.Parent.Services.CodexService)
local DataService = require(script.Parent.Services.DataService)
local EconomyService = require(script.Parent.Services.EconomyService)
local MultiplierService = require(script.Parent.Services.MultiplierService)
local PedestalService = require(script.Parent.Services.PedestalService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local SettingsService = require(script.Parent.Services.SettingsService)
local SignalService = require(script.Parent.Services.SignalService)
local DiscoveryPipeline = require(script.Parent.DiscoveryPipeline)
local PersistenceTests = require(script.Parent.Tests.PersistenceTests)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local DebugCommands = {}

type Map = {
	Districts: { { Id: string, Name: string, Model: Model, Entrance: CFrame } },
	PartCount: number,
}

local DISTRICT_ALIASES = {
	forest = "HauntedForest",
	village = "AbandonedVillage",
	ruins = "AncientRuins",
}

local function reply(player: Player, text: string)
	Notify:FireClient(player, text, "Debug")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function findTier(text: string): string?
	local lowered = string.lower(text)
	for _, tier in RarityConfig.Tiers do
		if string.lower(tier.Id) == lowered then
			return tier.Id
		end
	end
	return nil
end

local function findRelic(text: string): string?
	local lowered = string.lower(text)
	for _, relic in RelicConfig.Relics do
		if string.lower(relic.Id) == lowered then
			return relic.Id
		end
	end
	return nil
end

local function findMutation(text: string): string?
	local lowered = string.lower(text)
	for _, mutation in MutationConfig.Mutations do
		if string.lower(mutation.Id) == lowered then
			return mutation.Id
		end
	end
	return nil
end

local function findFamily(text: string): string?
	local lowered = string.lower(text)
	for _, family in RelicConfig.Families do
		if string.lower(family) == lowered then
			return family
		end
	end
	return nil
end

local function describeLuck(player: Player): string
	return `Luck {Format.number(RollService.GetFullLuck(player))}x, effective {Format.number(
		RollService.BuildContext(player).Luck
	)}x`
end

local function simulate(player: Player, count: number)
	local ctx = RollService.BuildContext(player)
	local rng = Random.new()
	local nextNumber = function()
		return rng:NextNumber()
	end
	local tierCounts: { [string]: number } = {}
	local mutationCounts: { [string]: number } = {}
	for index = 1, count do
		local relic, mutation = RollMath.roll(ctx, nextNumber)
		tierCounts[relic.Tier] = (tierCounts[relic.Tier] or 0) + 1
		local key = mutation or "Normal"
		mutationCounts[key] = (mutationCounts[key] or 0) + 1
		if index % 50000 == 0 then
			task.wait()
		end
	end

	print(`[SimRoll] {count} rolls | luck {ctx.Luck} | mutation rank {ctx.MutationRank}`)
	local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
	local observed, expected = {}, {}
	for index, tier in ctx.Tiers do
		observed[index] = tierCounts[tier.Id] or 0
		expected[index] = masses[index] * count
		print(string.format("  %-10s observed %9d   expected %14.3f", tier.Id, observed[index], expected[index]))
	end
	local tierChi, tierDf = Stats.chiSquare(observed, expected)
	print(string.format("  tiers chi-square %.2f (df %d, 99.9%% limit %.2f)", tierChi, tierDf, Stats.ChiSquare999[tierDf]))

	local mutationOdds = RollMath.mutationProbabilities(ctx)
	local mObserved, mExpected = {}, {}
	for id, p in mutationOdds do
		table.insert(mObserved, mutationCounts[id] or 0)
		table.insert(mExpected, p * count)
		print(string.format("  %-10s observed %9d   expected %14.3f", id, mutationCounts[id] or 0, p * count))
	end
	local mutationChi, mutationDf = Stats.chiSquare(mObserved, mExpected)
	print(
		string.format(
			"  mutations chi-square %.2f (df %d, 99.9%% limit %.2f)",
			mutationChi,
			mutationDf,
			Stats.ChiSquare999[mutationDf]
		)
	)
	local passed = tierChi <= Stats.ChiSquare999[tierDf] and mutationChi <= Stats.ChiSquare999[mutationDf]
	reply(
		player,
		`Simulated {Format.number(count)} rolls: {if passed then "matches the math" else "MISMATCH"} (details in Output).`
	)
end

local function buildHandlers(map: Map): { [string]: (Player, { string }) -> () }
	return {
		roll = function(player, args)
			local argument = args[1]
			local tierId = argument and findTier(argument)
			if tierId then
				local relicId = RollService.RollFromTier(player, tierId)
				if relicId then
					DataService.Increment(player, "TotalScans", 1)
					DiscoveryPipeline.Grant(player, { relicId }, "Debug")
					reply(player, `Granted a {tierId} relic.`)
				end
				return
			end
			local count = math.clamp(math.floor(tonumber(argument) or 1), 1, Config.Debug.MaxRollsPerCommand)
			local ran = ScanService.ForceScans(player, count, "Debug")
			if ran == 0 then
				Notify:FireClient(player, ScanService.FullMessage, "Error")
				return
			end
			reply(player, `Ran {ran} instant scan(s){if ran < count then " (stopped: inventory full)" else ""}.`)
		end,

		scanspeed = function(player, args)
			local argument = args[1]
			if argument == "reset" then
				ScanService.SetIntervalOverride(player, nil)
				reply(player, "Scan interval restored.")
				return
			end
			local seconds = tonumber(argument)
			if not seconds then
				reply(player, "Usage: /scanspeed <seconds> or /scanspeed reset")
				return
			end
			ScanService.SetIntervalOverride(player, seconds)
			reply(player, `Scan interval set to {Format.seconds(ScanService.GetInterval(player))}.`)
		end,

		wipedata = function(player)
			DataService.Wipe(player)
			MultiplierService.Refresh(player)
			ScanService.Restart(player)
			reply(player, "Your data was wiped.")
		end,

		forceroll = function(player, args)
			local target = args[1] or ""
			local tierId = findTier(target)
			local relicId = if tierId then RollService.RollFromTier(player, tierId) else findRelic(target)
			if not relicId then
				reply(player, "Usage: /forceroll <tier|relicId> [mutation], e.g. /forceroll cosmic abyssal")
				return
			end
			local mutation = nil
			if args[2] and args[2] ~= "" then
				mutation = findMutation(args[2])
				if not mutation then
					reply(player, `Unknown mutation "{args[2]}".`)
					return
				end
			end
			DiscoveryPipeline.GrantBatch(player, { { Id = relicId, Mutation = mutation, Source = "Debug" } })
			local label = if mutation then `{mutation} {relicId}` else relicId
			reply(player, `Granted {label}. Check /savestatus in ~{Config.Save.MinSecondsBetweenSaves}s.`)
		end,

		simroll = function(player, args)
			local count = math.clamp(math.floor(tonumber(args[1]) or 100000), 1, Config.Debug.MaxSimulatedRolls)
			reply(player, `Simulating {Format.number(count)} rolls...`)
			simulate(player, count)
		end,

		setluck = function(player, args)
			local argument = args[1]
			if argument == "reset" then
				RollService.SetDebugLuck(player, nil)
			else
				local value = tonumber(argument)
				if not value or value < 1 then
					reply(player, "Usage: /setluck <multiplier at least 1> or /setluck reset")
					return
				end
				RollService.SetDebugLuck(player, value)
			end
			reply(player, describeLuck(player))
		end,

		luckrank = function(player, args)
			local rank = tonumber(args[1])
			local data = DataService.Get(player)
			if not rank or not data then
				reply(player, "Usage: /luckrank <0-100>")
				return
			end
			data.Skills.CoreLuck = math.clamp(math.floor(rank), 0, Config.Luck.CoreLuckMaxRank)
			MultiplierService.Refresh(player)
			reply(player, `Core Luck rank {data.Skills.CoreLuck}. {describeLuck(player)}`)
		end,

		focus = function(player, args)
			local argument = string.lower(args[1] or "")
			local focus = if argument == "max" or argument == "maxluck" then "MaxLuck" else findTier(argument)
			if not focus or not SettingsService.SetFocus(player, focus) then
				reply(player, "Usage: /focus <tier|max>")
				return
			end
			reply(player, `Rarity Focus: {focus}. {describeLuck(player)}`)
		end,

		freq = function(player, args)
			local argument = string.lower(args[1] or "")
			local frequency = if argument == "all" then "All" else findFamily(argument)
			if not frequency or not SettingsService.SetFrequency(player, frequency) then
				reply(player, `Usage: /freq <all|{string.lower(table.concat(RelicConfig.Families, "|"))}>`)
				return
			end
			reply(player, `Signal Frequency: {frequency}.`)
		end,

		mutrank = function(player, args)
			local rank = tonumber(args[1])
			local data = DataService.Get(player)
			if not rank or not data then
				reply(player, `Usage: /mutrank <0-{MutationConfig.MaxRank}>`)
				return
			end
			data.Skills.MutationResonance = math.clamp(math.floor(rank), 0, MutationConfig.MaxRank)
			RollService.RefreshAttributes(player)
			local chance = MutationConfig.ChanceAt(data.Skills.MutationResonance)
			reply(player, `Mutation Resonance rank {data.Skills.MutationResonance}: {chance * 100}% mutation chance.`)
		end,

		savestatus = function(player)
			local data = DataService.Get(player)
			if not data then
				return
			end
			local state = DataService.GetStoreState()
			local mode = if state == "Access"
				then "real DataStore"
				else `mock ({state}) - nothing persists after Stop`
			local lastSaved = player:GetAttribute("LastSavedAt")
			local ago = if type(lastSaved) == "number"
				then `{Format.seconds(workspace:GetServerTimeNow() - lastSaved)} ago`
				else "not yet this session"
			local pending = if DataService.IsSavePending(player) then "yes" else "no"
			local discovered = player:GetAttribute("DiscoveredCount") or 0
			local text = `Save: {mode} | Last save {ago} | Pending {pending} | Relics {#data.Inventory} | Codex {discovered} | Rare history {#data.RareHistory}`
			reply(player, text)
			print(`[SaveStatus] {player.Name}: {text}`)
		end,

		ce = function(player, args)
			local data = DataService.Get(player)
			if not data then
				return
			end
			local setMode = args[1] == "set"
			local amount = tonumber(if setMode then args[2] else args[1])
			if not amount then
				reply(player, "Usage: /ce <amount> or /ce set <amount>")
				return
			end
			data.CE = math.max(0, if setMode then amount else data.CE + amount)
			EconomyService.Mirror(player)
			reply(player, `You now have {Format.ce(data.CE)} CE.`)
		end,

		offline = function(player, args)
			local data = DataService.Get(player)
			local seconds = tonumber(args[1])
			if not data or not seconds or seconds < 0 then
				reply(player, "Usage: /offline <seconds>, e.g. /offline 3600")
				return
			end
			data.Offline.IncomePerMin = EconomyService.GetIncomePerMin(player)
			data.Offline.At = os.time() - math.floor(seconds)
			local paid = EconomyService.PayOffline(player)
			if paid <= 0 then
				local why = if data.Offline.IncomePerMin <= 0
					then "nothing is displayed"
					else `under {Config.Offline.MinSeconds}s pays nothing`
				reply(player, `No offline earnings ({why}).`)
				return
			end
			AfkService.Welcome(player, EconomyService.TakeOfflinePayout(player), false)
		end,

		afksim = function(player, args)
			local data = DataService.Get(player)
			local minutes = tonumber(args[1] or "30")
			if not data or not minutes or minutes <= 0 then
				reply(player, "Usage: /afksim [minutes], e.g. /afksim 60")
				return
			end
			AfkService.Start(player)
			local log = data.AfkLog
			local seconds = math.floor(minutes * 60)
			local scans = math.min(math.floor(seconds / Config.Scan.BaseIntervalSeconds), Config.Afk.SimMaxScans)
			local ran = ScanService.ForceScans(player, scans, "Scan")
			local income = EconomyService.GetIncomePerMin(player) * minutes
			EconomyService.Add(player, income)
			log.CE += income
			log.Seconds += seconds
			log.Hops += math.max(1, math.floor(seconds / Config.Afk.HopAfterSeconds))
			reply(player, `Simulated {minutes} min AFK: {ran} scans, +{Format.ce(income)} CE. Showing Welcome Back.`)
			AfkService.Welcome(player, nil, true)
		end,

		pedlevel = function(player, args)
			local slot, level = tonumber(args[1]), tonumber(args[2])
			if not slot or not level or not PedestalService.SetLevel(player, slot, level) then
				reply(player, "Usage: /pedlevel <owned slot> <level 1-10>")
				return
			end
			reply(player, `Pedestal {slot} is now level {math.clamp(math.floor(level), 1, Config.Economy.PedestalMaxLevel)}.`)
		end,

		give = function(player, args)
			local relicId = findRelic(args[1] or "")
			if not relicId then
				reply(player, "Usage: /give <relicId> [mutation|none] [count], e.g. /give CrackedPrayerBead golden 5")
				return
			end
			local mutation = nil
			local countArg = args[2]
			local noMutation = args[2] and (string.lower(args[2]) == "none" or string.lower(args[2]) == "nil")
			if noMutation then
				countArg = args[3]
			elseif args[2] and not tonumber(args[2]) and args[2] ~= "" then
				mutation = findMutation(args[2])
				if not mutation then
					reply(player, `Unknown mutation "{args[2]}".`)
					return
				end
				countArg = args[3]
			end
			local count = math.clamp(math.floor(tonumber(countArg) or 1), 1, Config.Debug.MaxRollsPerCommand)
			local entries = table.create(count)
			for index = 1, count do
				entries[index] = { Id = relicId, Mutation = mutation, Source = "Debug" }
			end
			local results = DiscoveryPipeline.GrantBatch(player, entries)
			local sold = 0
			for _, result in results do
				if result.Sold then
					sold += 1
				end
			end
			reply(player, `Granted {count} x {if mutation then mutation .. " " else ""}{relicId} ({sold} auto-sold).`)
		end,

		codexfill = function(player, args)
			local data = DataService.Get(player)
			if not data then
				return
			end
			local count = math.clamp(math.floor(tonumber(args[1]) or #CodexBook.AllIds), 0, #CodexBook.AllIds)
			local now = os.time()
			for index = 1, count do
				local relicId = CodexBook.AllIds[index]
				if data.Discovered[relicId] == nil then
					data.Discovered[relicId] = now
				end
			end
			CodexService.Evaluate(player)
			DataService.MirrorAttributes(player)
			DataService.RequestSave(player)
			reply(player, `Codex: first {count} relics marked as discovered.`)
		end,

		runtests = function(player)
			reply(player, "Running persistence tests (mock store)...")
			local results = PersistenceTests.Run()
			local passed = 0
			for _, result in results do
				if result.Ok then
					passed += 1
					print(`  PASS  {result.Name}`)
				else
					warn(`  FAIL  {result.Name}: {result.Error}`)
				end
			end
			reply(player, `Persistence tests: {passed}/{#results} passed (details in Output).`)
		end,

		hunt = function(player, args)
			local character = player.Character
			local root = rootOf(player)
			if not character or not root then
				return
			end
			local wanted = string.lower(args[1] or "")
			local target = nil
			if wanted ~= "" then
				local id = DISTRICT_ALIASES[wanted]
				for _, district in map.Districts do
					if district.Id == id or string.lower(district.Id) == wanted then
						target = district
					end
				end
				if not target then
					reply(player, "Usage: /hunt [forest|village|ruins]")
					return
				end
			else
				local nearest =
					WorldLayout.nearestDistrict(Config.Districts, Config.World, root.Position.X, root.Position.Z)
				for _, district in map.Districts do
					if district.Id == nearest then
						target = district
					end
				end
			end
			if target then
				character:PivotTo(target.Entrance)
				reply(player, `Teleported to the {target.Name} gate.`)
			end
		end,

		mapstats = function(player)
			local counts = {}
			for _, district in map.Districts do
				local parts = 0
				for _, descendant in district.Model:GetDescendants() do
					if descendant:IsA("BasePart") then
						parts += 1
					end
				end
				table.insert(counts, `{district.Name} {parts}`)
			end
			local workspaceParts = 0
			for _, descendant in workspace:GetDescendants() do
				if descendant:IsA("BasePart") then
					workspaceParts += 1
				end
			end
			local text = `Map {map.PartCount} parts at build (budget {Config.World.PartBudget}) | now in Workspace {workspaceParts}`
				.. ` | {table.concat(counts, ", ")} | StreamingEnabled {workspace.StreamingEnabled}`
			reply(player, text)
			print(`[MapStats] {text}`)
		end,

		spawnsignal = function(player)
			local root = rootOf(player)
			if not root then
				return
			end
			local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if forward.Magnitude < 0.01 then
				forward = Vector3.zAxis
			end
			local position = root.Position + forward.Unit * 8
			SignalService.SpawnAt(player, position)
			reply(player, "Spawned a signal in front of you.")
		end,

		regen = function(player)
			SignalService.FillToMax(player)
			reply(player, "Signals refilled.")
		end,

		bindtime = function(player, args)
			local argument = args[1]
			if argument == "reset" then
				BindService.SetHoldOverride(player, nil)
			else
				local seconds = tonumber(argument)
				if not seconds then
					reply(player, "Usage: /bindtime <seconds> or /bindtime reset")
					return
				end
				BindService.SetHoldOverride(player, seconds)
			end
			reply(player, `Hold to Bind now takes {Format.seconds(BindService.GetHoldSeconds(player))}.`)
		end,

		huntstats = function(player)
			local stats = BindService.GetStats(player)
			local average = "n/a"
			if stats.Captures >= 2 and stats.FirstCaptureAt and stats.LastCaptureAt then
				average = Format.seconds((stats.LastCaptureAt - stats.FirstCaptureAt) / (stats.Captures - 1))
			end
			local text = `Captures {stats.Captures} | Cancels {stats.Cancels} | Avg between captures {average}`
			reply(player, text)
			print(`[HuntStats] {player.Name}: {text}`)
		end,
	}
end

function DebugCommands.Init(map: Map)
	if not RunService:IsStudio() then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "RelicDebugCommands"
	folder.Parent = TextChatService

	for name, handler in buildHandlers(map) do
		local command = Instance.new("TextChatCommand")
		command.Name = "Debug_" .. name
		command.PrimaryAlias = "/" .. name
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if not player or not DataService.IsLoaded(player) then
				return
			end
			local args = string.split(text, " ")
			table.remove(args, 1)
			local ok, err = pcall(handler, player, args)
			if not ok then
				warn(`[DebugCommands] /{name} failed: {err}`)
			end
		end)
		command.Parent = folder
	end
	print("[DebugCommands] Studio commands ready (type /help in chat for the list)")
end

return DebugCommands
