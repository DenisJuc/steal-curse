-- Spirit Wardrobe (hub kiosk only): the title over your head (TitleService: Auto, Off or any earned
-- title) and your spirit lantern colour (LanternService). Locked titles (GetTitles) and lanterns
-- show how to earn them, titles with a progress bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SpiritLantern = require(script.Parent.Parent.Effects.SpiritLantern)
local Icons = require(script.Parent.Icons)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetTitle = Remotes:WaitForChild("SetTitle") :: RemoteEvent
local GetTitles = Remotes:WaitForChild("GetTitles") :: RemoteFunction
local SetLantern = Remotes:WaitForChild("SetLantern") :: RemoteEvent

local player = Players.LocalPlayer

local WardrobePanel = {}

local CELL = Vector2.new(150, 54)
local LANTERN_CELL = Vector2.new(150, 56)

local areaNames: { [string]: string } = {}
for _, area in Config.Areas do
	areaNames[area.Id] = area.Name
end

-- How each lantern is earned.
local lanternSource: { [string]: string } = { [Config.Lanterns.Default] = "Everyone's" }
for area, zone in Config.Mastery.Zones do
	for _, lantern in zone.Lanterns do
		lanternSource[lantern.Id] = `{areaNames[area] or area} mastery {lantern.Level}`
	end
end
for area, zone in Config.Curse.Zones do
	lanternSource[zone.Lantern] = `Purify the {areaNames[area] or area}`
end

local function split(attribute: string, separator: string): { string }
	local text = player:GetAttribute(attribute)
	return if type(text) == "string" and text ~= "" then string.split(text, separator) else {}
end

function WardrobePanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "WardrobeMenu", "SPIRIT WARDROBE", colors.Gold, Vector2.new(540, 600))
	local list = UIKit.scrollList(content, 8)

	local function grid(order: number, cell: Vector2): Frame
		return UIKit.create("Frame", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -10, 0, 0),
			Parent = list,
		}, {
			UIKit.create("UIGridLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				CellSize = UDim2.fromOffset(cell.X, cell.Y),
				CellPadding = UDim2.fromOffset(8, 8),
			}),
		})
	end

	-- A locked title: padlock, name, how to earn it and a progress bar.
	local function lockedTitleRow(entry: any, order: number)
		local row = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 58),
			BackgroundColor3 = colors.Card,
			BackgroundTransparency = 0.2,
			Parent = list,
		}, { UIKit.corner(10) })
		UIKit.skinCard(row)
		local lock = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = colors.Track,
			Parent = row,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Icons.padlock(lock, 16, colors.SubText)
		UIKit.label({
			Text = entry.Title,
			TextSize = 16,
			TextColor3 = colors.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(50, 6),
			Size = UDim2.new(1, -220, 0, 20),
			Parent = row,
		})
		UIKit.label({
			Text = entry.Source,
			TextSize = 12,
			TextColor3 = colors.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(50, 36),
			Size = UDim2.new(1, -60, 0, 16),
			Parent = row,
		})
		local need = math.max(1, entry.Need)
		local fraction = math.clamp(entry.Have / need, 0, 1)
		local track = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 26),
			Size = UDim2.fromOffset(110, 8),
			BackgroundColor3 = colors.Track,
			Parent = row,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		UIKit.create("Frame", {
			Size = UDim2.fromScale(fraction, 1),
			BackgroundColor3 = if fraction >= 1 then colors.Gold else colors.Jade,
			Parent = track,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		UIKit.label({
			Text = `{entry.Have} / {entry.Need} {entry.Unit}`,
			TextSize = 12,
			TextColor3 = colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.fromOffset(150, 18),
			Parent = row,
		})
	end

	local catalog: { any }? = nil
	local renderTicket = 0

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		UIKit.heading({ LayoutOrder = 1, Text = "Title over your head", TextSize = 16, Size = UDim2.new(1, -10, 0, 24), Parent = list })
		local earned = split("TitlesEarned", "\n")
		local choice = player:GetAttribute("TitleChoice")
		choice = if type(choice) == "string" then choice else "Auto"
		local titles = grid(2, CELL)
		local sources: { [string]: string } = {}
		for _, entry in catalog or {} do
			if entry.Earned then
				sources[entry.Title] = entry.Source
			end
		end
		local options = {
			{ Value = "Auto", Text = "Best (auto)", Source = "Your best title" },
			{ Value = "Off", Text = "Off", Source = "No title" },
		}
		for _, title in earned do
			table.insert(options, { Value = title, Text = title, Source = sources[title] or "" })
		end
		for index, option in options do
			local selected = option.Value == choice
			local button = UIKit.button({
				LayoutOrder = index,
				Text = "",
				Parent = titles,
			}, function()
				SetTitle:FireServer(option.Value)
			end)
			UIKit.skinButton(button, if selected then "Gold" else "Dark")
			local textColor = if selected then colors.Panel else colors.Text
			UIKit.label({
				Text = option.Text,
				TextSize = 14,
				TextColor3 = textColor,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(4, 5),
				Size = UDim2.new(1, -8, 0, 18),
				Parent = button,
			})
			UIKit.label({
				Text = option.Source,
				TextSize = 10,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = if selected then colors.Panel else colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(4, 23),
				Size = UDim2.new(1, -8, 0, 26),
				Parent = button,
			})
		end
		UIKit.label({
			LayoutOrder = 3,
			Text = if #earned == 0
				then "No titles yet. See below how to earn each one."
				else `Showing: {player:GetAttribute("Title") or "nothing"}`,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = colors.SubText,
			Size = UDim2.new(1, -10, 0, 22),
			Parent = list,
		})
		local lockedTitles = {}
		for _, entry in catalog or {} do
			if not entry.Earned then
				table.insert(lockedTitles, entry)
			end
		end
		if #lockedTitles > 0 then
			UIKit.heading({
				LayoutOrder = 4,
				Text = "Titles to earn",
				TextSize = 15,
				Size = UDim2.new(1, -10, 0, 22),
				Parent = list,
			})
			for index, entry in lockedTitles do
				lockedTitleRow(entry, 4 + index)
			end
		end

		UIKit.heading({ LayoutOrder = 1000, Text = "Lantern colour", TextSize = 16, Size = UDim2.new(1, -10, 0, 24), Parent = list })
		local owned = {}
		for _, id in split("LanternsOwned", ",") do
			owned[id] = true
		end
		owned[Config.Lanterns.Default] = true
		local active = player:GetAttribute("Lantern")
		active = if type(active) == "string" then active else Config.Lanterns.Default
		local lanterns = grid(1001, LANTERN_CELL)
		for index, lantern in Config.Lanterns.List do
			local have = owned[lantern.Id] == true
			local button = UIKit.button({
				LayoutOrder = index,
				Text = "",
				Parent = lanterns,
			}, function()
				if have then
					SetLantern:FireServer(lantern.Id)
				end
			end)
			UIKit.skinButton(button, if lantern.Id == active then "Gold" else "Dark")
			UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = SpiritLantern.Color(lantern.Id),
				BackgroundTransparency = if have then 0 else 0.7,
				Parent = button,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local textColor = if lantern.Id == active then colors.Panel else colors.Text
			UIKit.label({
				Text = lantern.Name,
				TextSize = 14,
				TextColor3 = if have then textColor else colors.SubText,
				Position = UDim2.fromOffset(32, 6),
				Size = UDim2.new(1, -36, 0, 18),
				Parent = button,
			})
			UIKit.label({
				Text = if have then (if lantern.Id == active then "Equipped" else "Owned") else lanternSource[lantern.Id] or "Sacred Offering",
				TextSize = 11,
				TextWrapped = true,
				TextColor3 = if lantern.Id == active then textColor else colors.SubText,
				Position = UDim2.fromOffset(32, 24),
				Size = UDim2.new(1, -36, 0, 28),
				Parent = button,
			})
		end
	end

	-- Renders right away, then again once the server sends the title catalog.
	local function refresh()
		render()
		renderTicket += 1
		local ticket = renderTicket
		task.spawn(function()
			local ok, result = pcall(function()
				return GetTitles:InvokeServer()
			end)
			if ok and type(result) == "table" and ticket == renderTicket and panel.Visible then
				catalog = result
				render()
			end
		end)
	end

	for _, attribute in { "TitlesEarned", "TitleChoice", "Title", "LanternsOwned", "Lantern" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if panel.Visible then
				if attribute == "TitlesEarned" then
					refresh()
				else
					render()
				end
			end
		end)
	end

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				refresh()
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return WardrobePanel
