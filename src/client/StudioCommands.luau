-- Studio-only client helpers:
--   /help          prints every debug command into the chat window
--   /forgecomplete acts like an exploiter: sends Complete without a real hold, and prints the server's answer
--   /afkhop        jump the idle timer to just before the anti-AFK hop (banner, then the hop)
--   /hints         replay the beginner hints

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local HuntController = require(script.Parent.Hunt.HuntController)
local Settings = require(script.Parent.Settings)

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
	"/hunt [forest|village|ruins] - teleport to a district gate (nearest if empty)",
	"/mapstats - part counts vs the part budget",
	"/spawnsignal - spawn one of your signals in front of you",
	"/regen - refill your signals to the maximum",
	"/bindtime &lt;seconds&gt; - change hold time; /bindtime reset",
	"/huntstats - captures, cancels, average time between captures",
	"/forgecomplete - fake an early capture; the server must reject it",
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
	"/hints - replay the beginner hints",
}

local function say(text: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(text)
	end
end

local function register(alias: string, callback: () -> ())
	local command = Instance.new("TextChatCommand")
	command.Name = "Debug_" .. string.sub(alias, 2)
	command.PrimaryAlias = alias
	command.Triggered:Connect(callback)
	command.Parent = TextChatService
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
	register("/afkhop", function()
		hooks.SkipToHopWarning()
		say("[afkhop] Idle timer moved to the anti-AFK warning. Don't touch anything.")
	end)
	register("/hints", function()
		Settings.Set("Hints", "On")
	end)
end

return StudioCommands
