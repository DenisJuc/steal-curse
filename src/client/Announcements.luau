-- Server-wide messages for very rare finds (GDD 3.1, 12.2): one colored system line in chat.
-- The server decides what is announced (Config.Announce); this only formats it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Odds = require(script.Parent.UI.Odds)
local UIKit = require(script.Parent.UI.UIKit)

local Announce = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Announce") :: RemoteEvent

local Announcements = {}

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

function Announcements.Start()
	Announce.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Id) ~= "string" or type(payload.Name) ~= "string" then
			return
		end
		local relic = RelicConfig.ById[payload.Id]
		if not relic then
			return
		end
		local mutation = if type(payload.Mutation) == "string" then payload.Mutation else nil
		local tier = RarityConfig.Get(relic.Tier)
		local color = if mutation then UIKit.mutationColor(mutation) else UIKit.tierColor(relic.Tier)
		local text = `[RELIC] {escape(payload.Name)} found {Odds.displayName(relic.Id, mutation)}`
			.. ` ({if tier then tier.Name else relic.Tier}, {Format.odds(Odds.baseItem(relic.Id))})!`
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(`<font color="#{color:ToHex()}"><b>{text}</b></font>`)
		end
	end)
end

return Announcements
