-- Journal (GDD 3.2 rare-find history, 9.4 recent notable finds): this session's report and the
-- saved list of rare finds, so nothing found while away or coalesced by a reveal is missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Session = require(script.Parent.Parent.Session)
local Odds = require(script.Parent.Odds)
local ReportCard = require(script.Parent.ReportCard)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetJournal = Remotes:WaitForChild("GetJournal") :: RemoteFunction
local DiscoveryResult = Remotes:WaitForChild("DiscoveryResult") :: RemoteEvent

local JournalPanel = {}

local SOURCE_TEXT: { [string]: string } = {
	Scan = "scan",
	Capture = "sealed",
	Bonus = "hunt bonus",
	Debug = "debug",
}

function JournalPanel.Start(screen: ScreenGui): { Toggle: () -> (), Open: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "JournalMenu", "JOURNAL", colors.Accent, Vector2.new(520, 600))
	local list = UIKit.scrollList(content, 4)

	local function heading(text: string, order: number)
		UIKit.label({
			LayoutOrder = order,
			Text = text,
			TextSize = 16,
			TextColor3 = colors.Accent,
			Size = UDim2.new(1, -10, 0, 26),
			Parent = list,
		})
	end

	local function render(history: { any })
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		heading("This session", 1)
		local order = ReportCard.Fill(list, Session.Summarize(Session.Total), 1)
		order += 1
		heading(`Rare finds ({Config.Save.RareHistoryTier} or rarer, last {Config.Save.RareHistoryMax})`, order)
		if #history == 0 then
			order += 1
			UIKit.label({
				LayoutOrder = order,
				Text = "Nothing rare yet. Keep scanning!",
				TextSize = 14,
				TextColor3 = colors.SubText,
				Size = UDim2.new(1, -10, 0, 24),
				Parent = list,
			})
			return
		end
		local now = os.time()
		for _, find in history do
			local relic = RelicConfig.ById[find.Id]
			if not relic then
				continue
			end
			order += 1
			local color = if find.Mutation then UIKit.mutationColor(find.Mutation) else UIKit.tierColor(relic.Tier)
			local row = UIKit.create("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, 44),
				BackgroundColor3 = colors.Card,
				Parent = list,
			}, { UIKit.corner(8), UIKit.stroke(color, 1, 0.5) })
			UIKit.create("Frame", {
				Size = UDim2.new(0, 5, 1, -12),
				Position = UDim2.fromOffset(6, 6),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = row,
			}, { UIKit.corner(3) })
			UIKit.label({
				Text = Odds.displayName(find.Id, find.Mutation),
				TextSize = 15,
				TextColor3 = color,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(18, 4),
				Size = UDim2.new(1, -24, 0, 18),
				Parent = row,
			})
			local ago = math.max(0, now - (tonumber(find.At) or now))
			UIKit.label({
				Text = `{Odds.describe(find.Id, nil)}  |  {SOURCE_TEXT[find.Source] or "found"} {Format.duration(ago)} ago`,
				TextSize = 13,
				TextColor3 = colors.SubText,
				Position = UDim2.fromOffset(18, 23),
				Size = UDim2.new(1, -24, 0, 16),
				Parent = row,
			})
		end
	end

	local function load()
		task.spawn(function()
			local ok, result = pcall(function()
				return GetJournal:InvokeServer()
			end)
			if ok and type(result) == "table" and panel.Visible then
				render(if type(result.RareHistory) == "table" then result.RareHistory else {})
			end
		end)
	end

	local refreshQueued = false
	DiscoveryResult.OnClientEvent:Connect(function()
		if not panel.Visible or refreshQueued then
			return
		end
		refreshQueued = true
		task.delay(1, function()
			refreshQueued = false
			if panel.Visible then
				load()
			end
		end)
	end)

	local function open()
		panel.Visible = true
		load()
	end

	return {
		Toggle = function()
			if panel.Visible then
				panel.Visible = false
			else
				open()
			end
		end,
		Open = open,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return JournalPanel
