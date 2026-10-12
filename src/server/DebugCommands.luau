-- Studio-only chat commands for fast testing. Nothing here is created outside Studio.
--   /roll [count]      instant extra scans (max Config.Debug.MaxRollsPerCommand)
--   /roll <tier>       instant relic of that tier, e.g. /roll cosmic
--   /scanspeed <sec>   change your scan interval; /scanspeed reset restores it
--   /wipedata          reset your data to a fresh profile
--   /hunt [area]       teleport to the middle of the nearest wild area, or forest / village / ruins
--   /mapstats          part count vs the budget, props per area, signal spots
--   /modelcheck [all|clear]   gallery of imported relic models with warnings (all = include missing ones);
--                      also lists which map props are imported, still primitives, or wrongly named
--   /spawnsignal       spawn one of your signals right in front of you (ignores the cap)
--   /regen             refill your signals to the maximum
--   /relocate          move your signals near you now
--   /bindtime <sec>    change your hold-to-bind time; /bindtime reset restores it
--   /huntstats         captures, cancels and average time between captures this session
--   /forceroll <tier|relicId> [mutation]   grant an exact relic, e.g. /forceroll cosmic abyssal
--   /simroll [count]   simulate rolls with your current context and compare with the math (Output)
--   /setluck <x>       extra debug luck multiplier; /setluck reset
--   /luckrank <n>      set Core Luck rank 0..100
--   /skill <node> <n>  set any skill rank, e.g. /skill mutationresonance 3
--   /grantshowcase <id|all>          unlock a Showcase (level 1), e.g. /grantshowcase crimsonthrone
--   /showcaselevel <id> <level>      set an owned Showcase's level 1..4
--   /focus <tier|max>  set Rarity Focus
--   /freq <family|all> set Signal Frequency
--   /savestatus        save mode, last save time and counts
--   /runtests          run the persistence tests on the ProfileStore mock
--   /ce <amount>       add CE (negative removes); /ce set <amount>
--   /offline <seconds> pretend you were away that long, pay offline earnings and show Welcome Back
--   /afksim [minutes]  simulate an AFK stretch with anti-AFK hops (scans + shrine CE), then show
--                      Welcome Back as if you just came back (default 30)
--   /pedlevel <slot> <level>   set a pedestal level directly
--   /give <relicId> [mutation|none] [count]   grant exact copies through the full pipeline (auto-sell included)
--   /codexfill [n]     mark the first n relics (rarity order, default all) as discovered, without items
--   /potion <luck|haste|fortune|all> [count]   give potions
--   /clearbuffs        end every active potion buff

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local ModelCheck = require(ReplicatedStorage.Shared.ModelCheck)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local ShowcaseConfig = require(ReplicatedStorage.Shared.ShowcaseConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local Stats = require(ReplicatedStorage.Shared.Stats)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local AfkService = require(script.Parent.Services.AfkService)
local BindService = require(script.Parent.Services.BindService)
local CodexService = require(script.Parent.Services.CodexService)
local DataService = require(script.Parent.Services.DataService)
local EconomyService = require(script.Parent.Services.EconomyService)
local ItemService = require(script.Parent.Services.ItemService)
local MultiplierService = require(script.Parent.Services.MultiplierService)
local PedestalService = require(script.Parent.Services.PedestalService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local SettingsService = require(script.Parent.Services.SettingsService)
local ShowcaseService = require(script.Parent.Services.ShowcaseService)
local SignalService = require(script.Parent.Services.SignalService)
local SkillService = require(script.Parent.Services.SkillService)
local DiscoveryPipeline = require(script.Parent.DiscoveryPipeline)
local PersistenceTests = require(script.Parent.Tests.PersistenceTests)
local MapProps = require(script.Parent.World.MapProps)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local DebugCommands = {}

type Map = {
	Wild: { SpawnPoints: { { Position: Vector3, Area: string } }, PropCount: number, PropsByArea: { [string]: number } },
	PartCount: number,
}

local GALLERY_NAME = "ModelGallery"
local GALLERY_COLUMNS = 8
local GALLERY_SPACING = 9

local AREA_ALIASES = {
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

local function findSkill(text: string)
	local lowered = string.lower(text)
	for _, node in SkillConfig.Nodes do
		if string.lower(node.Id) == lowered then
			return node
		end
	end
	return nil
end

local function findShowcase(text: string): string?
	local lowered = string.lower(text)
	for _, showcase in ShowcaseConfig.Showcases do
		if string.lower(showcase.Id) == lowered then
			return showcase.Id
		end
	end
	return nil
end

local function showcaseIds(): string
	local ids = {}
	for _, showcase in ShowcaseConfig.Showcases do
		table.insert(ids, string.lower(showcase.Id))
	end
	return table.concat(ids, "|")
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
			local set = rank and SkillService.SetRank(player, "CoreLuck", rank)
			if not set then
				reply(player, "Usage: /luckrank <0-100>")
				return
			end
			reply(player, `Core Luck rank {set}. {describeLuck(player)}`)
		end,

		skill = function(player, args)
			local node = findSkill(args[1] or "")
			local rank = tonumber(args[2])
			local set = node and rank and SkillService.SetRank(player, node.Id, rank)
			if not node or not set then
				local ids = {}
				for _, each in SkillConfig.Nodes do
					table.insert(ids, string.lower(each.Id))
				end
				reply(player, `Usage: /skill <{table.concat(ids, "|")}> <rank>`)
				return
			end
			reply(player, `{node.Name} rank {set}/{node.MaxRank}. {describeLuck(player)}`)
		end,

		grantshowcase = function(player, args)
			local wanted = string.lower(args[1] or "")
			local id = if wanted == "all" then "all" else findShowcase(wanted)
			if not id or not ShowcaseService.Grant(player, id) then
				reply(player, `Usage: /grantshowcase <{showcaseIds()}|all>`)
				return
			end
			reply(player, `Granted {if id == "all" then "every Showcase" else id}. {describeLuck(player)}`)
		end,

		showcaselevel = function(player, args)
			local id = findShowcase(args[1] or "")
			local level = tonumber(args[2])
			if not id or not level or not ShowcaseService.SetLevel(player, id, level) then
				reply(player, `Usage: /showcaselevel <{showcaseIds()}> <1-{ShowcaseConfig.MaxLevel}> (owned only)`)
				return
			end
			reply(player, `{id} is now level {math.clamp(math.floor(level), 1, ShowcaseConfig.MaxLevel)}. {describeLuck(player)}`)
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
			local scans = math.min(math.floor(seconds / ScanService.GetInterval(player)), Config.Afk.SimMaxScans)
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
				reply(player, "Usage: /give <relicId> [mutation|none] [count], e.g. /give SenzoBean golden 5")
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

		potion = function(player, args)
			local wanted = string.lower(args[1] or "")
			local count = math.clamp(math.floor(tonumber(args[2]) or 1), 1, ItemConfig.MaxStack)
			local rewards: { [string]: number } = {}
			for _, item in ItemConfig.Items do
				if wanted == "all" or string.lower(item.Id) == wanted or string.lower(item.Id) == wanted .. "potion" then
					rewards[item.Id] = count
				end
			end
			if next(rewards) == nil then
				reply(player, "Usage: /potion <luck|haste|fortune|all> [count]")
				return
			end
			ItemService.Grant(player, rewards, "debug")
		end,

		clearbuffs = function(player)
			ItemService.ClearBuffs(player)
			reply(player, "Every potion buff ended.")
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
				local id = AREA_ALIASES[wanted]
				for _, area in Config.Areas do
					if area.Id == id or string.lower(area.Id) == wanted then
						target = area
					end
				end
				if not target then
					reply(player, "Usage: /hunt [forest|village|ruins]")
					return
				end
			else
				local nearest = WorldLayout.areaAt(Config.Areas, Config.World, root.Position.X, root.Position.Z)
				for _, area in Config.Areas do
					if area.Id == nearest then
						target = area
					end
				end
			end
			if target then
				local x, z = WorldLayout.areaCenter(target, Config.World)
				local ray = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0))
				local y = if ray then ray.Position.Y + 4 else 10
				character:PivotTo(CFrame.new(x, y, z))
				reply(player, `Teleported to the middle of the {target.Name}.`)
			end
		end,

		relocate = function(player)
			SignalService.Relocate(player)
			reply(player, "Signals moved near you.")
		end,

		mapstats = function(player)
			local counts = {}
			for _, area in Config.Areas do
				table.insert(counts, `{area.Name} {map.Wild.PropsByArea[area.Id] or 0} props`)
			end
			local workspaceParts = 0
			for _, descendant in workspace:GetDescendants() do
				if descendant:IsA("BasePart") then
					workspaceParts += 1
				end
			end
			local text = `Map {map.PartCount} parts at build (budget {Config.World.PartBudget}) | now in Workspace {workspaceParts}`
				.. ` | {map.Wild.PropCount} wild props: {table.concat(counts, ", ")}`
				.. ` | {#map.Wild.SpawnPoints} signal spots | StreamingEnabled {workspace.StreamingEnabled}`
			reply(player, text)
			print(`[MapStats] {text}`)
		end,

		modelcheck = function(player, args)
			local old = workspace:FindFirstChild(GALLERY_NAME)
			if old then
				old:Destroy()
			end
			local mode = string.lower(args[1] or "")
			if mode == "clear" then
				reply(player, "Model gallery removed.")
				return
			end
			local root = rootOf(player)
			if not root then
				return
			end
			local imported, warned, shown = 0, 0, {}
			print("[ModelCheck] relic | model | warnings")
			for _, relic in RelicConfig.Relics do
				local asset = RelicModels.asset(relic.Id)
				local issues = if asset then ModelCheck.issues(RelicModels.facts(asset)) else {}
				if asset then
					imported += 1
					if #issues > 0 then
						warned += 1
					end
				end
				if asset or mode == "all" then
					table.insert(shown, { Relic = relic, Asset = asset, Issues = issues })
					local status = if asset then (if #issues > 0 then table.concat(issues, "; ") else "ok") else "MODEL NEEDED"
					print(`  {relic.Id} ({relic.Tier}) | {status}`)
				end
			end
			local unknown = RelicModels.unknownNames()
			for _, name in unknown do
				print(`  {name} | NOT A RELIC ID: rename the .rbxm file to a relic id`)
			end

			local propIds = {}
			for id in MapPropConfig.Props do
				table.insert(propIds, id)
			end
			table.sort(propIds)
			local propsImported, missingProps = 0, {}
			for _, id in propIds do
				if MapProps.has(id) then
					propsImported += 1
				else
					table.insert(missingProps, id)
				end
			end
			local unknownProps = MapProps.unknownNames()
			print(`[ModelCheck] map props imported {propsImported}/{#propIds}`)
			print(`  still primitives (ModelNeeded): {table.concat(missingProps, ", ")}`)
			for _, name in unknownProps do
				print(`  {name} | NOT A MAP PROP ID: rename the .rbxm file in assets/MapProps`)
			end

			local gallery = Instance.new("Folder")
			gallery.Name = GALLERY_NAME
			local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.zAxis
			local origin = CFrame.lookAt(root.Position, root.Position + forward)
			for index, entry in shown do
				local column = (index - 1) % GALLERY_COLUMNS
				local row = (index - 1) // GALLERY_COLUMNS
				local x = (column - (GALLERY_COLUMNS - 1) / 2) * GALLERY_SPACING
				local spot = origin * CFrame.new(x, -2.5, -12 - row * GALLERY_SPACING)
				local stand = Instance.new("Part")
				stand.Anchored = true
				stand.CanCollide = false
				stand.Size = Vector3.new(4, 1, 4)
				stand.CFrame = spot
				stand.Color = Color3.fromRGB(40, 40, 52)
				stand.Parent = gallery
				local model = RelicModels.build(entry.Relic.Id, spot * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.pi, 0))
				if model then
					model.Parent = gallery
				end
				local billboard = Instance.new("BillboardGui")
				billboard.Size = UDim2.fromOffset(220, 70)
				billboard.StudsOffset = Vector3.new(0, 6.5, 0)
				billboard.MaxDistance = 60
				billboard.Parent = stand
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.TextScaled = true
				label.Font = Enum.Font.GothamBold
				label.TextStrokeTransparency = 0.3
				label.TextColor3 = if not entry.Asset
					then Color3.fromRGB(160, 160, 170)
					elseif #entry.Issues > 0 then Color3.fromRGB(255, 190, 80)
					else Color3.fromRGB(120, 230, 140)
				label.Text = `{entry.Relic.Name}\n`
					.. (if not entry.Asset then "model needed" elseif #entry.Issues > 0 then entry.Issues[1] else "ok")
				label.Parent = billboard
			end
			gallery.Parent = workspace

			local text = `Models imported: {imported}/{#RelicConfig.Relics}, {warned} with warnings`
				.. (if #unknown > 0 then `, {#unknown} file(s) with an unknown name` else "")
				.. ` | map props {propsImported}/{#propIds}`
				.. (if #unknownProps > 0 then ` ({#unknownProps} wrongly named)` else "")
				.. ` | gallery of {#shown} in front of you (details in Output; /modelcheck clear removes it)`
			reply(player, text)
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
