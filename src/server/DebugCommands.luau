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
--   /analytics [start|stop|export|status]   Studio playtest session recording + export
--   /forceroll <tier|relicId> [mutation]   grant an exact relic, e.g. /forceroll cosmic abyssal
--   /simroll [count]   simulate rolls with your current context and compare with the math (Output)
--   /setluck <x>       extra debug luck multiplier; /setluck reset
--   /luckrank <n>      set Core Luck rank 0..100
--   /skill <node> <n>  set any skill rank, e.g. /skill mutationresonance 3
--   /grantshowcase <id|all>          unlock a Showcase (level 1), e.g. /grantshowcase crimsonthrone
--   /showcaselevel <id> <level>      set an owned Showcase's level 1..4
--   /allshowcases      own every Showcase at the base level (1; 0 means not owned) to watch each
--                      upgrade stage; add CE with /ce to buy the upgrades in the menu
--   /focus <tier|max>  set Rarity Focus
--   /freq <family|all> set Signal Frequency
--   /savestatus        save mode, last save time and counts
--   /runtests          run the persistence tests on the ProfileStore mock
--   /ce <amount>       add CE (negative removes); /ce set <amount>
--   /offline <seconds> pretend you were away that long, pay offline earnings and show Welcome Back
--   /afksim [minutes]  simulate an AFK stretch with anti-AFK hops (scans + shrine CE), then show
--                      Welcome Back as if you just came back (default 30)
--   /pedlevel <slot> <level>   set a pedestal level directly
--   /rebirths <n>      set your Rebirth count (income and luck multipliers) without resetting anything
--   /gamepass <name> [on|off]   pretend you own (or don't own) a game pass, e.g. /gamepass autoequip
--   /buy <product>     grant a developer product without Roblox, e.g. /buy serverluck
--   /friends <n>       pretend n friends are in the server (friend luck bonus)
--   /gifts <minutes>   move this session's playtime clock forward (playtime gifts)
--   /give <relicId> [mutation|none] [huge|titanic|normal] [count]   grant copies (Size optional; Studio SoftCap)
--   /sizekit [relicId]   Studio fixture: Huge + Titanic of a relic (defaults to a Rare) for visual/ownership checks
--   /codexfill [n]     mark the first n relics (rarity order, default all) as discovered, without items
--   /potion <luck|haste|fortune|all> [count]   give potions
--   /clearbuffs        end every active potion buff
--   /streak <x|reset>  set your Hunt Streak multiplier (in the wild) or end it
--   /zoneevent <bloodmoon|spiritstorm|starfall|off>   start a zone event now, or end it
--   /strike [here]     lightning near you now (here = right in front of you)
--   /lightning         charge Lightning Luck as if you captured a struck spirit
--   /lostone [gift|false]   the Lost One near you (forced to give a gift / be the False Watcher)
--   /falsewatcher [now]     a False Watcher on its last hop (walk up to it); now = it lunges at once
--   /facepitch <deg|auto>   tip the jumpscare mask back this many degrees (tuning a new model)
--   /p41smoke              Phase 4.1 integration smoke (mock ProfileStore): Rank2 reserve, Board ×1.28, retire, B+
--   /p6smoke               Phase 6 smoke: Rank2→3 mut reserve, sell-all keep-1, BoardFocus, Rank3 fuse, B+
--   /rewardpreview         Studio: grant ordinary dupes + new/mut/Huge/Titanic for feed/reveal check

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
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
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local AfkService = require(script.Parent.Services.AfkService)
local BindService = require(script.Parent.Services.BindService)
local CodexService = require(script.Parent.Services.CodexService)
local DataService = require(script.Parent.Services.DataService)
local EconomyService = require(script.Parent.Services.EconomyService)
local GamePassService = require(script.Parent.Services.GamePassService)
local ShopService = require(script.Parent.Services.ShopService)
local FriendService = require(script.Parent.Services.FriendService)
local PlaytimeService = require(script.Parent.Services.PlaytimeService)
local ItemService = require(script.Parent.Services.ItemService)
local MultiplierService = require(script.Parent.Services.MultiplierService)
local PedestalService = require(script.Parent.Services.PedestalService)
local RollService = require(script.Parent.Services.RollService)
local ScanService = require(script.Parent.Services.ScanService)
local SettingsService = require(script.Parent.Services.SettingsService)
local ShowcaseService = require(script.Parent.Services.ShowcaseService)
local SignalService = require(script.Parent.Services.SignalService)
local SkillService = require(script.Parent.Services.SkillService)
local StreakService = require(script.Parent.Services.StreakService)
local ZoneEventService = require(script.Parent.Services.ZoneEventService)
local WildFindsService = require(script.Parent.Services.WildFindsService)
local LightningService = require(script.Parent.Services.LightningService)
local LanternService = require(script.Parent.Services.LanternService)
local MasteryService = require(script.Parent.Services.MasteryService)
local CurseService = require(script.Parent.Services.CurseService)
local BountyService = require(script.Parent.Services.BountyService)
local DiscoveryPipeline = require(script.Parent.DiscoveryPipeline)
local PersistenceTests = require(script.Parent.Tests.PersistenceTests)
local PlaytestAnalyticsService = require(script.Parent.Services.PlaytestAnalyticsService)
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

		allshowcases = function(player)
			ShowcaseService.Grant(player, "all")
			for _, showcase in ShowcaseConfig.Showcases do
				ShowcaseService.SetLevel(player, showcase.Id, 1)
			end
			reply(player, "Every Showcase is yours at level 1. Upgrade them in the Showcases menu (/ce 3000000000 covers every level), or jump a level with /showcaselevel.")
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
			-- "5e555" parses as infinity: safeCE caps it at Economy.MaxCE instead of breaking the balance.
			data.CE = Economy.safeCE(if setMode then amount else data.CE + amount, data.CE)
			EconomyService.Mirror(player)
			local capped = if data.CE >= Economy.MaxCE then " (the maximum)" else ""
			reply(player, `You now have {Format.ce(data.CE)} CE{capped}.`)
		end,

		offline = function(player, args)
			local data = DataService.Get(player)
			local seconds = tonumber(args[1])
			if not data or not seconds or seconds < 0 then
				reply(player, "Usage: /offline <seconds>, e.g. /offline 3600")
				return
			end
			data.Offline.IncomePerSec = EconomyService.GetIncomePerSec(player)
			data.Offline.At = os.time() - math.floor(seconds)
			local paid = EconomyService.PayOffline(player)
			if paid <= 0 then
				local why = if data.Offline.IncomePerSec <= 0
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
			local income = EconomyService.GetIncomePerSec(player) * seconds
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
				reply(player, `Usage: /pedlevel <owned slot> <level 1-{Config.Economy.PedestalMaxLevel}>`)
				return
			end
			reply(player, `Pedestal {slot} is now level {math.clamp(math.floor(level), 1, Config.Economy.PedestalMaxLevel)}.`)
		end,

		rebirths = function(player, args)
			local data = DataService.Get(player)
			local count = tonumber(args[1])
			if not data or not count or count < 0 then
				reply(player, "Usage: /rebirths <n>, e.g. /rebirths 3")
				return
			end
			data.Rebirths = math.floor(count)
			player:SetAttribute("Rebirths", data.Rebirths)
			MultiplierService.Refresh(player)
			PedestalService.Refresh(player)
			reply(player, `Rebirths set to {data.Rebirths}.`)
		end,

		gamepass = function(player, args)
			local wanted = string.lower(args[1] or "")
			local name = nil
			for passName in Config.GamePasses do
				if string.lower(passName) == wanted then
					name = passName
				end
			end
			if not name then
				local names = {}
				for passName in Config.GamePasses do
					table.insert(names, string.lower(passName))
				end
				reply(player, `Usage: /gamepass <{table.concat(names, "|")}> [on|off]`)
				return
			end
			local on = string.lower(args[2] or "on") ~= "off"
			GamePassService.SetOwned(player, name, on)
			reply(player, `Game pass {name}: {if on then "owned" else "not owned"} (this session).`)
		end,

		gifts = function(player, args)
			local minutes = tonumber(args[1]) or 60
			PlaytimeService.Skip(player, minutes)
			reply(player, `Playtime clock +{minutes} min.`)
		end,

		friends = function(player, args)
			local n = math.max(0, math.floor(tonumber(args[1]) or 0))
			FriendService.SetFake(player, n)
			reply(player, `Pretending {n} friends are here.`)
		end,

		buy = function(player, args)
			local wanted = string.lower(args[1] or "")
			for name in Config.DevProducts do
				if string.lower(name) == wanted then
					ShopService.DebugGrant(player, name)
					reply(player, `Granted {name} (no receipt).`)
					return
				end
			end
			reply(player, "Usage: /buy <luckpotion|potionbundle|serverluck>")
		end,

		give = function(player, args)
			local relicId = findRelic(args[1] or "")
			if not relicId then
				reply(
					player,
					"Usage: /give <relicId> [mutation|none] [huge|titanic|normal] [count], e.g. /give SenzoBean none huge 1"
				)
				return
			end
			local mutation = nil
			local size: string? = nil
			local countArg: string? = nil
			local function parseSize(token: string?): boolean
				if not token then
					return false
				end
				local lower = string.lower(token)
				if lower == "huge" then
					size = "Huge"
					return true
				elseif lower == "titanic" then
					size = "Titanic"
					return true
				elseif lower == "normal" or lower == "base" then
					size = nil
					return true
				end
				return false
			end
			local i = 2
			local token2 = args[i]
			if token2 and (string.lower(token2) == "none" or string.lower(token2) == "nil") then
				mutation = nil
				i += 1
			elseif token2 and not tonumber(token2) and not parseSize(token2) and token2 ~= "" then
				mutation = findMutation(token2)
				if not mutation then
					reply(player, `Unknown mutation "{token2}".`)
					return
				end
				i += 1
			end
			if parseSize(args[i]) then
				i += 1
			end
			countArg = args[i]
			local count = math.clamp(math.floor(tonumber(countArg) or 1), 1, Config.Debug.MaxRollsPerCommand)
			local entries = table.create(count)
			for index = 1, count do
				entries[index] = { Id = relicId, Mutation = mutation, Size = size, Source = "Debug" }
			end
			local results = DiscoveryPipeline.GrantBatch(player, entries)
			local sold = 0
			for _, result in results do
				if result.Sold then
					sold += 1
				end
			end
			local label = `{if size then size .. " " else ""}{if mutation then mutation .. " " else ""}{relicId}`
			reply(player, `Granted {count} x {label} ({sold} auto-sold).`)
		end,

		sizekit = function(player, args)
			local relicId = findRelic(args[1] or "") or findRelic("RedStoneOfAia") or findRelic("SenzoBean")
			if not relicId then
				for _, relic in RelicConfig.Relics do
					if relic.Tier == "Rare" then
						relicId = relic.Id
						break
					end
				end
			end
			if not relicId then
				reply(player, "No relic id available for sizekit.")
				return
			end
			local entries = {
				{ Id = relicId, Mutation = nil, Size = "Huge", Source = "Debug" },
				{ Id = relicId, Mutation = nil, Size = "Titanic", Source = "Debug" },
			}
			DiscoveryPipeline.GrantBatch(player, entries)
			reply(player, `Size kit: Huge + Titanic {relicId}. Equip / float / check sell protect.`)
		end,

		rewardpreview = function(player)
			-- Deterministic presentation sequence (same grant pipeline as real rolls).
			local commonId = findRelic("SenzoBean") or findRelic("StealBall")
			local uncommonId = findRelic("BuraBuraFruit") or findRelic("YutosRing")
			local rareId = findRelic("RedStoneOfAia")
			if not rareId then
				for _, relic in RelicConfig.Relics do
					if relic.Tier == "Rare" then
						rareId = relic.Id
						break
					end
				end
			end
			local epicId = nil
			for _, relic in RelicConfig.Relics do
				if relic.Tier == "Epic" then
					epicId = relic.Id
					break
				end
			end
			if not (commonId and uncommonId and rareId) then
				reply(player, "rewardpreview: missing roster ids")
				return
			end
			local mut = findMutation("Golden")
			local entries = {
				{ Id = commonId, Source = "Debug" },
				{ Id = commonId, Source = "Debug" },
				{ Id = commonId, Source = "Debug" },
				{ Id = uncommonId, Source = "Debug" },
				{ Id = uncommonId, Source = "Debug" },
				{ Id = rareId, Source = "Debug" },
				{ Id = commonId, Mutation = mut, Source = "Debug" },
				{ Id = rareId, Size = "Huge", Source = "Debug" },
				{ Id = rareId, Size = "Titanic", Source = "Debug" },
			}
			if epicId then
				table.insert(entries, { Id = epicId, Source = "Debug" })
			end
			DiscoveryPipeline.GrantBatch(player, entries)
			reply(
				player,
				"Reward preview granted: 5 ordinary C/U dupes (one feed summary), Rare, Golden mut, Huge, Titanic"
					.. (if epicId then ", Epic" else "")
					.. ". Watch DiscoveryFeed + reveals."
			)
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

		streak = function(player, args)
			local argument = args[1]
			if argument == "reset" then
				StreakService.Reset(player)
				reply(player, "Hunt Streak ended.")
				return
			end
			local value = tonumber(argument)
			if not value then
				reply(player, `Usage: /streak <1-{Config.HuntStreak.Max}> or /streak reset`)
				return
			end
			StreakService.Set(player, value)
			reply(player, `Hunt Streak x{Format.multiplier(StreakService.Get(player))}.`)
		end,

		zoneevent = function(player, args)
			local wanted = string.lower(args[1] or "")
			local id = if wanted == "off" then "off" else nil
			for _, event in Config.ZoneEvents.Events do
				if string.lower(event.Id) == wanted then
					id = event.Id
				end
			end
			if not id or not ZoneEventService.Force(id) then
				local ids = {}
				for _, event in Config.ZoneEvents.Events do
					table.insert(ids, string.lower(event.Id))
				end
				reply(player, `Usage: /zoneevent <{table.concat(ids, "|")}|off>`)
				return
			end
			reply(player, if id == "off" then "Zone event ending." else `Zone event {id} started.`)
		end,

		strike = function(player, args)
			local root = rootOf(player)
			if not root then
				return
			end
			local at = nil
			if args[1] == "here" then
				local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.zAxis
				local spot = root.Position + forward * 12
				local ray = workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0))
				at = if ray then ray.Position else spot
			end
			local hit = WildFindsService.Strike(player, at)
			reply(player, if hit then "Lightning struck." else "No spot for lightning (go into the wild).")
		end,

		offering = function(player, args)
			local root = rootOf(player)
			if not root then
				return
			end
			local at = nil
			if args[1] == "here" then
				local spot = root.Position + root.CFrame.LookVector * Vector3.new(1, 0, 1) * 15
				local ray = workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0))
				at = if ray then ray.Position else spot
			end
			local hit = WildFindsService.SpawnOffering(player, at)
			reply(player, if hit then "An offering box is hidden nearby - listen for it." else "No spot (go into the wild).")
		end,

		lostone = function(player, args)
			local kind = string.lower(args[1] or "")
			local isFalse = if kind == "false" then true elseif kind == "gift" then false else nil
			local hit = WildFindsService.SpawnLostOne(player, { False = isFalse })
			reply(player, if hit then "The Lost One appeared nearby." else "No spot (go into the wild).")
		end,

		falsewatcher = function(player, args)
			local now = string.lower(args[1] or "") == "now"
			local hit = WildFindsService.SpawnLostOne(player, {
				False = true,
				Blinks = Config.WildFinds.LostOne.Hops,
				Now = now,
			})
			if not hit then
				reply(player, "No spot (go into the wild).")
			elseif now then
				reply(player, "The False Watcher lunges.")
			else
				reply(player, "A False Watcher is on its last hop nearby - walk up to it.")
			end
		end,

		facepitch = function(player, args)
			local degrees = tonumber(args[1])
			player:SetAttribute("DebugFacePitch", degrees)
			reply(
				player,
				if degrees
					then `Jumpscare mask tilt set to {degrees} degrees - try /falsewatcher now.`
					else "Jumpscare mask tilt back to the model's own."
			)
		end,

		lightning = function(player)
			local factor, untilTime = LightningService.Charge(player)
			reply(player, `Lightning Luck x{Format.multiplier(factor)} for {math.ceil(untilTime - workspace:GetServerTimeNow())}s.`)
		end,

		mastery = function(player, args)
			local wanted = string.lower(args[1] or "")
			local level = tonumber(args[2])
			local areas = {}
			for _, area in Config.Areas do
				if wanted == "all" or string.find(string.lower(area.Id), wanted, 1, true) then
					table.insert(areas, area.Id)
				end
			end
			if wanted == "" or #areas == 0 or not level then
				reply(player, "Usage: /mastery <forest|village|ruins|all> <level 0-10>")
				return
			end
			local levels = Config.Mastery.Levels
			local index = math.clamp(math.floor(level), 0, #levels)
			for _, area in areas do
				MasteryService.SetXp(player, area, if index == 0 then 0 else levels[index])
			end
			reply(player, `Mastery set to level {index} in {table.concat(areas, ", ")}.`)
		end,

		cleanse = function(player, args)
			local wanted = string.lower(args[1] or "")
			if wanted == "reset" then
				CurseService.Reset(player)
				reply(player, "Every Cursed Shrine is cursed again.")
				return
			end
			local done = {}
			for _, shrine in WildLayout.CursedShrines do
				local id = string.lower(shrine.Id)
				local matches = wanted == "all" or id == wanted or (wanted ~= "" and string.find(string.lower(shrine.Area), wanted, 1, true) ~= nil)
				if matches and CurseService.Cleanse(player, shrine.Id) then
					table.insert(done, shrine.Id)
				end
			end
			if wanted == "" then
				reply(player, "Usage: /cleanse <shrine id (forest1..ruins5)|forest|village|ruins|all|reset>")
				return
			end
			reply(player, if #done > 0 then `Cleansed {table.concat(done, ", ")}.` else "Nothing to cleanse.")
		end,

		bounty = function(player, args)
			local what = string.lower(args[1] or "")
			if not BountyService.Debug(player, what) then
				reply(player, "Usage: /bounty <complete|reset|nextday>")
				return
			end
			reply(player, `Bounties: {what} done.`)
		end,

		lantern = function(player, args)
			local wanted = string.lower(args[1] or "")
			for _, lantern in Config.Lanterns.List do
				if string.lower(lantern.Id) == wanted then
					LanternService.Grant(player, lantern.Id, "debug")
					reply(player, `Granted lantern {lantern.Id}.`)
					return
				end
			end
			if wanted == "all" then
				for _, lantern in Config.Lanterns.List do
					LanternService.Grant(player, lantern.Id, "debug")
				end
				reply(player, "Granted every lantern.")
				return
			end
			reply(player, "Usage: /lantern <id|all>")
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

		analytics = function(player, args)
			local sub = string.lower(args[1] or "status")
			if sub == "start" then
				local ok, msg = PlaytestAnalyticsService.Start(player)
				reply(player, msg)
				print(`[PlaytestAnalytics] /analytics start → {msg}`)
			elseif sub == "stop" then
				local ok, msg = PlaytestAnalyticsService.Stop(player)
				reply(player, msg)
				print(`[PlaytestAnalytics] /analytics stop → {msg}`)
			elseif sub == "export" then
				local ok, msg = PlaytestAnalyticsService.Export(player)
				reply(player, msg)
				print(`[PlaytestAnalytics] /analytics export → {msg}`)
			else
				local st = PlaytestAnalyticsService.GetStatus(player)
				local msg = `Analytics recording={st.Recording} elapsed={st.Elapsed} events={st.EventCount} purchases={st.PurchaseCount} session={st.SessionId or "—"}`
				reply(player, msg)
				print(`[PlaytestAnalytics] {msg}`)
			end
		end,

		-- Phase 4.1: seed Rank1 Board + copies on mock ProfileStore; verify reserve/Rank2/Board/retire/B+.
		p41smoke = function(player)
			local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
			local CollectionConfig = require(ReplicatedStorage.Shared.CollectionConfig)
			local CollectionMath = require(ReplicatedStorage.Shared.CollectionMath)
			local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
			local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
			local CollectionService = require(script.Parent.Services.CollectionService)
			local MultiplierService = require(script.Parent.Services.MultiplierService)

			local lines = { "[p41smoke] Phase 4.1 integration (Studio mock store)" }
			local function check(cond: boolean, label: string)
				table.insert(lines, if cond then `  PASS  {label}` else `  FAIL  {label}`)
				return cond
			end

			local allOk = true
			allOk = check(DataService.IsStudioIsolated(), "ProfileStore.Mock isolation") and allOk
			allOk = check(BalanceTrials.collectionEnabled(), "Collection enabled") and allOk
			allOk = check(BalanceTrials.boardGlobalFusionIncome(), "SoftCap_P4 board-global income") and allOk
			allOk = check(BalanceTrials.rebirthModel() == "BPlus", "B+ Rebirth model") and allOk
			allOk = check(Config.Rebirth.BaseCost == 4e8, "BaseCost 400M") and allOk

			local data = DataService.Get(player)
			if not data then
				reply(player, "p41smoke: data not loaded")
				return
			end

			local relicId: string? = nil
			for _, relic in RelicConfig.Relics do
				if relic.Tier == "Common" then
					relicId = relic.Id
					break
				end
			end
			if not relicId then
				reply(player, "p41smoke: no Common relic")
				return
			end

			-- Snapshot fields we mutate so we can restore a minimal clean board after.
			local state = data.Collection
			local prevEssence = state.Essence
			local prevFusion = state.Fusion[relicId]
			local prevPin = state.FusionPins[relicId]
			local prevCE = data.CE
			local prevRebirths = data.Rebirths
			local prevCL = data.Skills.CoreLuck
			local prevPedLevels = {}
			for i, ped in data.Pedestals do
				prevPedLevels[i] = ped.Level
			end

			-- Strip base copies of the test relic (leave pedestaled/locked alone).
			local keptInv = {}
			for _, item in data.Inventory do
				if not (item.Id == relicId and item.Mutation == nil) then
					table.insert(keptInv, item)
				end
			end
			data.Inventory = keptInv

			local function addBaseCopies(n: number)
				data.Cosmetic.Uid = (data.Cosmetic.Uid or 0)
				for _ = 1, n do
					data.Cosmetic.Uid += 1
					table.insert(data.Inventory, {
						Uid = data.Cosmetic.Uid,
						Id = relicId,
						At = os.time(),
						Source = "Debug",
					})
				end
			end

			state.Essence = 500
			state.Fusion[relicId] = { Rank = 1, Charm = "Hunt" }
			state.FusionPins[relicId] = true
			addBaseCopies(5)

			local need2 = CollectionMath.copiesForRank(2)
			local reserved5 = CollectionService.IsFusionReserved(player, relicId, nil)
			allOk = check(need2 == 5 and reserved5 == true, `AutoSell reserve at 5 copies (need={need2})`) and allOk

			local rules = AutoSell.defaults({ "Common" })
			rules.Tiers.Common = "SellDuplicates"
			local sell5, reason5 = AutoSell.decide(rules, {
				Tier = "Common",
				BaseOneIn = 2,
				First = false,
				Mutated = false,
				Duplicate = true,
				Favorite = false,
				FusionReserve = reserved5,
			})
			allOk = check(sell5 == false and reason5 == "FusionReserve", "AutoSell keeps 5th copy") and allOk

			local beforeOwned = CollectionService.OwnedCopies(player, relicId)
			local fuseOk, fuseMsg = CollectionService.TryFuse(player, relicId)
			local rank = if state.Fusion[relicId] then state.Fusion[relicId].Rank else 0
			local board = CollectionService.BoardIncomeMult(player)
			local pedFuse = CollectionService.FusionIncomeMult(player, relicId)
			allOk = check(fuseOk == true and rank == 2, `TryFuse Rank2 ({fuseMsg})`) and allOk
			allOk = check(math.abs(board - 1.28) < 1e-9, `BoardIncomeMult ×1.28 (got {board})`) and allOk
			allOk = check(pedFuse == 1, `per-ped FusionIncomeMult=1 under P4 (got {pedFuse})`) and allOk
			allOk = check(CollectionService.OwnedCopies(player, relicId) == beforeOwned - CollectionMath.consumeForRank(2), "consumed Rank2 copies") and allOk

			MultiplierService.Refresh(player)
			EconomyService.Mirror(player)
			local ips = player:GetAttribute("IncomePerSec")
			allOk = check(type(ips) == "number", `IncomePerSec mirrored ({ips})`) and allOk

			-- Retire
			state.Essence = math.max(state.Essence, CollectionConfig.BoardRetireEssence or 80)
			local retireOk, retireMsg = CollectionService.TryRetireBoard(player, relicId)
			allOk = check(retireOk == true, `RetireBoard ({retireMsg})`) and allOk
			allOk = check(state.Fusion[relicId] == nil, "Fusion cleared") and allOk
			allOk = check(state.FusionPins[relicId] == nil, "pin cleared") and allOk
			allOk = check(CollectionService.BoardIncomeMult(player) == 1, "Board mult back to ×1") and allOk

			-- B+ preserve: re-seed Fusion, bump skills/peds/CE, apply B+
			state.Fusion[relicId] = { Rank = 2, Charm = "Workshop" }
			state.FusionPins[relicId] = true
			state.Essence = 42
			data.Skills.CoreLuck = 18
			if data.Pedestals[1] then
				data.Pedestals[1].Level = 25
			end
			data.CE = Config.Rebirth.BaseCost
			local rebBefore = data.Rebirths or 0
			Rebirth.apply(data, "BPlus")
			allOk = check(data.CE == 0, "B+ CE=0") and allOk
			allOk = check(data.Rebirths == rebBefore + 1, "B+ increments Rebirths") and allOk
			allOk = check(data.Skills.CoreLuck == 18, "B+ keeps CoreLuck") and allOk
			allOk = check(data.Pedestals[1] and data.Pedestals[1].Level == 25, "B+ keeps pedestal") and allOk
			allOk = check(state.Fusion[relicId] and state.Fusion[relicId].Rank == 2, "B+ keeps Fusion") and allOk
			allOk = check(state.Fusion[relicId] and state.Fusion[relicId].Charm == "Workshop", "B+ keeps Charm") and allOk
			allOk = check(state.Essence == 42, "B+ keeps Essence") and allOk

			-- Restore session-ish state (mock; still polite)
			state.Essence = prevEssence
			state.Fusion[relicId] = prevFusion
			state.FusionPins[relicId] = prevPin
			data.CE = prevCE
			data.Rebirths = prevRebirths
			data.Skills.CoreLuck = prevCL
			for i, lvl in prevPedLevels do
				if data.Pedestals[i] then
					data.Pedestals[i].Level = lvl
				end
			end
			MultiplierService.Refresh(player)
			EconomyService.Mirror(player)
			DataService.RequestSave(player)

			local summary = if allOk then "ALL PASS" else "FAILURES — see Output"
			table.insert(lines, `Result: {summary} (relic={relicId})`)
			for _, line in lines do
				print(line)
			end
			reply(player, `p41smoke: {summary}. Details in Output.`)
		end,

		-- Phase 6: mutated reserve, sell-all UID slots, BoardFocus, Rank3 fuse (Studio mock).
		p6smoke = function(player)
			local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
			local CollectionConfig = require(ReplicatedStorage.Shared.CollectionConfig)
			local CollectionMath = require(ReplicatedStorage.Shared.CollectionMath)
			local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
			local CollectionService = require(script.Parent.Services.CollectionService)
			local MultiplierService = require(script.Parent.Services.MultiplierService)

			local lines = { "[p6smoke] Phase 6 Rank3 / mut-reserve (Studio mock store)" }
			local function check(cond: boolean, label: string)
				table.insert(lines, if cond then `  PASS  {label}` else `  FAIL  {label}`)
				return cond
			end

			local allOk = true
			allOk = check(DataService.IsStudioIsolated(), "ProfileStore.Mock isolation") and allOk
			allOk = check(BalanceTrials.collectionEnabled(), "Collection enabled") and allOk
			allOk = check(BalanceTrials.boardGlobalFusionIncome(), "SoftCap_P4 board-global income") and allOk
			allOk = check(CollectionConfig.Rank3NeedsMutation == true, "Rank3NeedsMutation") and allOk

			local data = DataService.Get(player)
			if not data then
				reply(player, "p6smoke: data not loaded")
				return
			end

			local aId: string? = nil
			local bId: string? = nil
			for _, relic in RelicConfig.Relics do
				if relic.Tier == "Common" then
					if not aId then
						aId = relic.Id
					elseif not bId then
						bId = relic.Id
						break
					end
				end
			end
			if not aId or not bId then
				reply(player, "p6smoke: need two Common relics")
				return
			end

			local state = data.Collection
			local prevEssence = state.Essence
			local prevFocus = state.BoardFocusId
			local prevFusionA = state.Fusion[aId]
			local prevFusionB = state.Fusion[bId]
			local prevPinA = state.FusionPins[aId]
			local prevPinB = state.FusionPins[bId]

			local function stripRelic(relicId: string)
				local kept = {}
				for _, item in data.Inventory do
					if item.Id ~= relicId then
						table.insert(kept, item)
					end
				end
				data.Inventory = kept
			end

			local function addCopies(relicId: string, n: number, mutation: string?)
				data.Cosmetic.Uid = data.Cosmetic.Uid or 0
				for _ = 1, n do
					data.Cosmetic.Uid += 1
					table.insert(data.Inventory, {
						Uid = data.Cosmetic.Uid,
						Id = relicId,
						Mutation = mutation,
						At = os.time(),
						Source = "Debug",
					})
				end
			end

			stripRelic(aId)
			stripRelic(bId)
			state.Essence = 800
			state.Fusion[aId] = { Rank = 2, Charm = "Hunt" }
			state.FusionPins[aId] = true
			state.BoardFocusId = nil
			addCopies(aId, 4, nil)
			addCopies(aId, 1, "Golden")

			allOk = check(CollectionMath.mutatedCopiesToReserve(state, aId) == 1, "mutatedCopiesToReserve=1 at Rank2") and allOk
			allOk = check(CollectionService.IsFusionReserved(player, aId, "Golden") == true, "IsFusionReserved keeps sole mut") and allOk

			-- Second mutated: sequential AutoSell may sell; sell-all still protects exactly one UID.
			addCopies(aId, 1, "Golden")
			allOk = check(CollectionService.IsFusionReserved(player, aId, "Golden") == false, "extra mut not reserved (owned>1)") and allOk
			local reserved = CollectionService.FusionReserveByUid(player)
			local mutKept = 0
			local mutTotal = 0
			for _, item in data.Inventory do
				if item.Id == aId and item.Mutation ~= nil then
					mutTotal += 1
					if reserved[item.Uid] then
						mutKept += 1
					end
				end
			end
			allOk = check(mutTotal == 2 and mutKept == 1, `sell-all keeps exactly 1 mut UID (kept={mutKept}/{mutTotal})`) and allOk

			local focusResolved = CollectionMath.resolveBoardFocusId(state)
			allOk = check(focusResolved == aId, "auto BoardFocus with one Rank2 candidate") and allOk

			-- Second Rank2 candidate → Pursue sets focus
			state.MutationGoalsClaimed.FirstGolden = state.MutationGoalsClaimed.FirstGolden or 1
			state.Fusion[bId] = { Rank = 2, Charm = "Shrine" }
			state.FusionPins[bId] = true
			local setOk, setMsg = CollectionService.SetBoardFocus(player, bId)
			allOk = check(setOk == true and state.BoardFocusId == bId, `SetBoardFocus B ({setMsg})`) and allOk
			allOk = check(player:GetAttribute("BoardFocusId") == bId or CollectionMath.resolveBoardFocusId(state) == bId, "focus readable") and allOk

			-- Rank3 fuse on A: need 4 base + 1 mut + essence
			state.BoardFocusId = aId
			state.Fusion[bId] = nil
			state.FusionPins[bId] = nil
			stripRelic(aId)
			addCopies(aId, 4, nil)
			addCopies(aId, 1, "Golden")
			state.Essence = math.max(state.Essence, CollectionMath.fusionEssenceCost("Common", 3))
			local fuseOk, fuseMsg = CollectionService.TryFuse(player, aId)
			local rank = if state.Fusion[aId] then state.Fusion[aId].Rank else 0
			local board = CollectionService.BoardIncomeMult(player)
			allOk = check(fuseOk == true and rank == 3, `TryFuse Rank3 ({fuseMsg})`) and allOk
			allOk = check(math.abs(board - 1.5) < 1e-9, `BoardIncomeMult ×1.50 (got {board})`) and allOk
			allOk = check(state.BoardFocusId == nil, "BoardFocus cleared at max rank") and allOk
			allOk = check(CollectionMath.mutatedCopiesToReserve(state, aId) == 0, "mut reserve cleared at Rank3") and allOk

			MultiplierService.Refresh(player)
			EconomyService.Mirror(player)

			-- Restore
			state.Essence = prevEssence
			state.BoardFocusId = prevFocus
			state.Fusion[aId] = prevFusionA
			state.Fusion[bId] = prevFusionB
			state.FusionPins[aId] = prevPinA
			state.FusionPins[bId] = prevPinB
			stripRelic(aId)
			stripRelic(bId)
			MultiplierService.Refresh(player)
			EconomyService.Mirror(player)
			DataService.RequestSave(player)

			local summary = if allOk then "ALL PASS" else "FAILURES — see Output"
			table.insert(lines, `Result: {summary} (A={aId} B={bId})`)
			for _, line in lines do
				print(line)
			end
			reply(player, `p6smoke: {summary}. Details in Output.`)
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
