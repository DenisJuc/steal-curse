-- Studio-only client helper: /help prints every debug command into the chat window.

local TextChatService = game:GetService("TextChatService")

local StudioCommands = {}

local HELP = {
	"<b>Debug commands (Studio only)</b>",
	"/roll [count] - instant extra scans, e.g. /roll 50",
	"/roll &lt;tier&gt; - instant relic of a tier, e.g. /roll cosmic",
	"/scanspeed &lt;seconds&gt; - change scan interval; /scanspeed reset",
	"/wipedata - reset your data",
}

function StudioCommands.Start()
	local command = Instance.new("TextChatCommand")
	command.Name = "Debug_help"
	command.PrimaryAlias = "/help"
	command.Triggered:Connect(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(table.concat(HELP, "\n"))
		end
	end)
	command.Parent = TextChatService
end

return StudioCommands
