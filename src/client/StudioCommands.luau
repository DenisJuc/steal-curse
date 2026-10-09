-- Studio-only client helpers:
--   /help          prints every debug command into the chat window
--   /forgecomplete acts like an exploiter: sends Complete without a real hold, and prints the server's answer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local HuntController = require(script.Parent.Hunt.HuntController)

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
	"/hunt - teleport to the Haunted Grove",
	"/spawnsignal - spawn one of your signals in front of you",
	"/regen - refill your signals to the maximum",
	"/bindtime &lt;seconds&gt; - change hold time; /bindtime reset",
	"/huntstats - captures, cancels, average time between captures",
	"/forgecomplete - fake an early capture; the server must reject it",
	"/forceroll &lt;tier|relicId&gt; [mutation] - e.g. /forceroll cosmic abyssal",
	"/simroll [count] - simulate rolls with your current settings (no relics granted)",
	"/setluck &lt;x&gt; - extra luck multiplier, e.g. /setluck 1e10; /setluck reset",
	"/luckrank &lt;0-100&gt; - set your Core Luck rank",
	"/focus &lt;tier|max&gt; - set Rarity Focus",
	"/freq &lt;family|all&gt; - set Signal Frequency",
	"/mutrank &lt;0-5&gt; - set Mutation Resonance rank",
	"/savestatus - save mode, last save time, relic counts",
	"/runtests - run the persistence tests (mock store)",
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

function StudioCommands.Start()
	register("/help", function()
		say(table.concat(HELP, "\n"))
	end)
	register("/forgecomplete", forgeComplete)
end

return StudioCommands
