-- Studio-only client helpers:
--   /help          prints every debug command into the chat window
--   /forgecomplete acts like an exploiter: sends Complete without a real hold, and prints the server's answer
--   /afkhop        jump the idle timer to just before the anti-AFK hop (banner, then the hop)
--   /hints         replay the beginner hints
--   /sealpose      play the bind's seal pose for 5 s, then the post-capture finale; reports joint types
--   /rollstyle     switch the roll animation style (Flicker, Flame, Omikuji)
--   /rolldemo      play a roll for a tier or relic without granting anything

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SealPose = require(script.Parent.Effects.SealPose)
local HuntController = require(script.Parent.Hunt.HuntController)
local Settings = require(script.Parent.Settings)
local RollReel = require(script.Parent.UI.RollReel)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BeginBind = Remotes:WaitForChild("BeginBind") :: RemoteEvent
local CancelBind = Remotes:WaitForChild("CancelBind") :: RemoteEvent
local CompleteBind = Remotes:WaitForChild("CompleteBind") :: RemoteEvent
local BindResult = Remotes:WaitForChild("BindResult") :: RemoteEvent

local StudioCommands = {}

local HELP = {
	"<b>Debug commands (Studio only)</b>",
	"/roll [count] - instant extra scans, e.g. /roll 50",
	"/roll &lt;tier&gt; - instant relic of a tier, e.g. /roll cosmic",
	"/scanspeed &lt;seconds&gt; - change scan interval; /scanspeed reset",
	"/wipedata - reset your data",
	"/hunt [forest|village|ruins] - teleport to the middle of a wild area (nearest if empty)",
	"/mapstats - part count vs the budget, props per area, signal spots",
	"/modelcheck [all|clear] - gallery of imported relic models; map prop import status in Output",
	"/spawnsignal - spawn one of your signals in front of you",
	"/regen - refill your signals to the maximum",
	"/relocate - move your signals near you now",
	"/bindtime &lt;seconds&gt; - change hold time; /bindtime reset",
	"/huntstats - captures, cancels, average time between captures",
	"/forgecomplete - fake an early capture; the server must reject it",
	"/sealpose - play the seal pose for 5 s, then the post-capture finale (and show joint types)",
	"/forceroll &lt;tier|relicId&gt; [mutation] - e.g. /forceroll cosmic abyssal",
	"/simroll [count] - simulate rolls with your current settings (no relics granted)",
	"/setluck &lt;x&gt; - extra luck multiplier, e.g. /setluck 1e10; /setluck reset",
	"/luckrank &lt;0-100&gt; - set your Core Luck rank",
	"/skill &lt;node&gt; &lt;rank&gt; - set any skill rank, e.g. /skill scanspeed 12",
	"/grantshowcase &lt;id|all&gt; - unlock a Showcase, e.g. /grantshowcase crimsonthrone",
	"/showcaselevel &lt;id&gt; &lt;1-4&gt; - set an owned Showcase's level",
	"/focus &lt;tier|max&gt; - set Rarity Focus",
	"/freq &lt;family|all&gt; - set Signal Frequency",
	"/savestatus - save mode, last save time, relic counts",
	"/runtests - run the persistence tests (mock store)",
	"/ce &lt;amount&gt; - add CE; /ce set &lt;amount&gt;",
	"/offline &lt;seconds&gt; - pay offline earnings as if you were away (shows Welcome Back)",
	"/afksim [minutes] - simulate AFKing that long, then show Welcome Back",
	"/afkhop - skip to the anti-AFK warning; touch nothing for 15 s to see the hop",
	"/pedlevel &lt;slot&gt; &lt;level&gt; - set a pedestal level",
	"/give &lt;relicId&gt; [mutation|none] [count] - grant exact copies (auto-sell applies)",
	"/codexfill [n] - mark the first n relics as discovered",
	"/potion &lt;luck|haste|fortune|all&gt; [count] - give potions",
	"/clearbuffs - end every active potion buff",
	"/hints - replay the beginner hints",
	"/rollstyle [omikuji|flicker|flame] - switch the roll animation (no name: next style)",
	"/rolldemo [tier|relicId] - play a roll without granting anything, e.g. /rolldemo cosmic",
}

local function say(text: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(text)
	end
end

-- `callback` gets the words typed after the command.
local function register(alias: string, callback: ({ string }) -> ())
	local command = Instance.new("TextChatCommand")
	command.Name = "Debug_" .. string.sub(alias, 2)
	command.PrimaryAlias = alias
	command.Triggered:Connect(function(_source, text)
		local words = string.split(string.lower(text), " ")
		table.remove(words, 1)
		callback(words)
	end)
	command.Parent = TextChatService
end

-- A relic for /rolldemo: a tier ("cosmic") picks a random relic of it, an id picks that relic,
-- nothing picks any relic.
local function demoRelic(word: string?): string?
	local pool = {}
	for _, relic in RelicConfig.Relics do
		if not word or word == "" or string.lower(relic.Tier) == word then
			table.insert(pool, relic.Id)
		elseif string.lower(relic.Id) == word then
			return relic.Id
		end
	end
	return if #pool > 0 then pool[math.random(#pool)] else nil
end

-- Plays the seal pose on your character for 5 s (progress 0 -> 1), then the post-capture finale,
-- and reports its joint types.
local function testSealPose()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		say("[sealpose] No character.")
		return
	end
	say(`[sealpose] {SealPose.Describe(character)}`)
	local pose = SealPose.Start(character)
	if not pose then
		say("[sealpose] No pose for this avatar (see Output).")
		return
	end
	local target = root.Position + root.CFrame.LookVector * 10 + Vector3.new(0, 1, 0)
	local seconds = 5
	local slamAt = 1.4
	local start = os.clock()
	local finale: SealPose.Pose? = nil
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local clock = os.clock() - start
		if not character.Parent or clock >= seconds + SealPose.FinaleSeconds(slamAt) then
			connection:Disconnect()
			pose.Restore()
			if finale then
				finale.Restore()
			end
			return
		end
		if clock < seconds then
			pose.Update(clock, clock / seconds, target, 0)
			return
		end
		if not finale then
			pose.Restore()
			finale = SealPose.Finale(character, slamAt)
		end
		if finale then
			finale.Update(clock - seconds, 0, target, 0)
		end
	end)
end

local function forgeComplete()
	local connection = BindResult.OnClientEvent:Connect(function(result)
		if type(result) == "table" then
			local verdict = if result.Ok then "ACCEPTED (this is a bug!)" else `rejected: {result.Reason}`
			say(`[forgecomplete] Server {verdict}`)
		end
	end)
	task.delay(3, function()
		connection:Disconnect()
	end)

	local nearest = HuntController.GetNearestSignalId()
	if nearest then
		say("[forgecomplete] Begin + instant Complete on the nearest signal (expect TooEarly)")
		BeginBind:FireServer(nearest)
		CompleteBind:FireServer(nearest)
		task.delay(0.5, function()
			CancelBind:FireServer(nearest)
		end)
	else
		local ids = HuntController.GetSignalIds()
		say("[forgecomplete] Complete with no bind in progress (expect NotBinding)")
		CompleteBind:FireServer(ids[1] or 1)
	end
end

function StudioCommands.Start(hooks: { SkipToHopWarning: () -> () })
	register("/help", function()
		say(table.concat(HELP, "\n"))
	end)
	register("/forgecomplete", forgeComplete)
	register("/sealpose", testSealPose)
	register("/afkhop", function()
		hooks.SkipToHopWarning()
		say("[afkhop] Idle timer moved to the anti-AFK warning. Don't touch anything.")
	end)
	register("/hints", function()
		Settings.Set("Hints", "On")
	end)
	register("/rollstyle", function(words)
		local options = ClientSettings.ByKey.RollStyle.Options :: { string }
		local wanted = words[1]
		local value = ClientSettings.nextOption("RollStyle", Settings.Get("RollStyle"))
		for _, option in options do
			if wanted and string.lower(option) == wanted then
				value = option
			end
		end
		Settings.Set("RollStyle", value :: string)
		say(`[rollstyle] Roll style: {value} (options: {table.concat(options, ", ")})`)
	end)
	register("/rolldemo", function(words)
		local relicId = demoRelic(words[1])
		if not relicId then
			say("[rolldemo] Unknown tier or relic id.")
			return
		end
		RollReel.Demo(relicId)
		say(`[rolldemo] Rolling {relicId} ({Settings.Get("RollStyle")} style, nothing granted)`)
	end)
end

return StudioCommands
