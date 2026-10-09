-- Top-middle feed of recent discoveries, newest on top. Lines fade out on their own and never block anything.
-- Base odds come from RollMath (via Odds), the same math the server rolls with.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local DiscoveryResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DiscoveryResult") :: RemoteEvent

local DiscoveryFeed = {}

type Result = { Uid: number, Id: string, Mutation: string?, Source: string, First: boolean?, Displayed: boolean? }

local LINE_HEIGHT = 44
local order = 0

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 0 else 0
end

local function fadeLater(line: Frame)
	task.delay(Config.Feed.LineLifetimeSeconds, function()
		if not line.Parent then
			return
		end
		for _, child in line:GetDescendants() do
			if child:IsA("TextLabel") then
				UIKit.tween(child, 0.4, { TextTransparency = 1 })
			elseif child:IsA("UIStroke") then
				UIKit.tween(child, 0.4, { Transparency = 1 })
			end
		end
		UIKit.tween(line, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.45)
		line:Destroy()
	end)
end

local function makeLine(list: Frame, title: string, subtitle: string, color: Color3, highlight: boolean)
	order -= 1
	local line = UIKit.create("Frame", {
		Name = "Line",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
		BackgroundColor3 = UIKit.Colors.Card,
		BackgroundTransparency = 0.15,
		Parent = list,
	}, {
		UIKit.corner(10),
		UIKit.stroke(color, if highlight then 2 else 1, if highlight then 0 else 0.6),
	})
	UIKit.create("Frame", {
		Name = "TierBar",
		Size = UDim2.new(0, 5, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = line,
	}, { UIKit.corner(3) })
	UIKit.label({
		Name = "Title",
		Text = title,
		TextSize = 16,
		TextColor3 = if highlight then color else UIKit.Colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = line,
	})
	UIKit.label({
		Name = "Subtitle",
		Text = subtitle,
		TextSize = 13,
		TextColor3 = color,
		Position = UDim2.fromOffset(18, 23),
		Size = UDim2.new(1, -24, 0, 16),
		Parent = line,
	})

	local lines = {}
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = Config.Feed.MaxLines + 1, #lines do
		lines[index]:Destroy()
	end
	fadeLater(line)
end

local function showRelic(list: Frame, result: Result)
	local relic = RelicConfig.ById[result.Id]
	if not relic then
		return
	end
	local highlightIndex = RarityConfig.IndexById[Config.Feed.HighlightTier] or math.huge
	local highlight = tierIndex(relic.Id) >= highlightIndex or result.Mutation ~= nil
	local title = Odds.displayName(relic.Id, result.Mutation)
	if result.First then
		title = "NEW! " .. title
	end
	local color = if result.Mutation then UIKit.mutationColor(result.Mutation) else UIKit.tierColor(relic.Tier)
	local subtitle = Odds.describe(relic.Id, result.Mutation)
	if result.Displayed then
		subtitle ..= "  |  on pedestal"
	end
	makeLine(list, title, subtitle, color, highlight)
end

-- Sort key: tier first, mutated above plain within a tier.
local function rarityKey(result: Result): number
	return tierIndex(result.Id) * 2 + (if result.Mutation then 1 else 0)
end

function DiscoveryFeed.Start(screen: ScreenGui)
	local list = UIKit.create("Frame", {
		Name = "DiscoveryFeed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(340, (LINE_HEIGHT + 6) * Config.Feed.MaxLines),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	UIKit.scaler(list)

	DiscoveryResult.OnClientEvent:Connect(function(results: { Result })
		if type(results) ~= "table" then
			return
		end
		if #results <= Config.Feed.MaxLines then
			for _, result in results do
				showRelic(list, result)
			end
			return
		end
		-- Big batches: show the rarest few plus one summary line instead of flooding the feed.
		local sorted = table.clone(results)
		table.sort(sorted, function(a, b)
			return rarityKey(a) < rarityKey(b)
		end)
		local shown = Config.Feed.MaxLines - 1
		makeLine(list, `+{#results - shown} more discoveries`, "Batch summary", UIKit.Colors.SubText, false)
		for index = #sorted - shown + 1, #sorted do
			showRelic(list, sorted[index])
		end
	end)
end

return DiscoveryFeed
