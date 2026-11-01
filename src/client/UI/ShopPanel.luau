-- Shop menu (ShopService), laid out like a store front: one big glowing featured card (Server
-- Luck), a row of event summons (start a zone event for everyone), then passes and potions as
-- coloured cards with a big icon, a ribbon on the best deals and a slow shine. Prices come from
-- Roblox; an item whose id is still 0 shows "Soon" and can't be bought. Owned passes show
-- "Owned" (Pass<Name> attributes from GamePassService). Opened by the gold SHOP button under the
-- travel bar (top right).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local ShopPanel = {}

local CARD_HEIGHT = 128
local EVENT_HEIGHT = 168
local FEATURED_HEIGHT = 150

type Entry = {
	Name: string,
	Title: string?,
	Text: string?,
	Icon: string?,
	Color: { number }?,
	Tag: string?,
	Event: string?,
}

local function rgb(values: { number }?): Color3
	return if values then Color3.fromRGB(values[1], values[2], values[3]) else UIKit.Colors.Gold
end

function ShopPanel.Start(screen: ScreenGui, onOpen: () -> ()): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "ShopMenu", "SHOP", colors.Gold, Vector2.new(640, 680))
	local list = UIKit.scrollList(content, 10)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function heading(text: string)
		UIKit.label({
			LayoutOrder = nextOrder(),
			Text = text,
			FontFace = UIKit.TitleFont,
			TextSize = 22,
			TextColor3 = colors.Gold,
			Size = UDim2.new(1, -10, 0, 28),
			Parent = list,
		})
	end

	local function row(height: number, columns: number, count: number): Frame
		local rows = math.ceil(count / columns)
		return UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, rows * (height + 10)),
			BackgroundTransparency = 1,
			Parent = list,
		}, {
			UIKit.create("UIGridLayout", {
				CellSize = UDim2.new(1 / columns, -8, 0, height),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	-- One store card: tinted gradient, glowing edge, big icon, title, one line, ribbon, buy button.
	local function card(parent: Instance, index: number, entry: Entry, isPass: boolean, layout: string): Frame
		local id = (if isPass then Config.GamePasses[entry.Name] else Config.DevProducts[entry.Name]) or 0
		local tint = rgb(entry.Color)
		local featured = layout == "Featured"
		local event = layout == "Event"
		local frame = UIKit.create("Frame", {
			Name = entry.Name,
			LayoutOrder = index,
			Size = if featured then UDim2.new(1, -10, 0, FEATURED_HEIGHT) else UDim2.fromScale(1, 1),
			BackgroundColor3 = tint,
			ClipsDescendants = true,
			Parent = parent,
		}, {
			UIKit.corner(14),
			UIKit.create("UIStroke", { Color = tint, Thickness = 2.5, Transparency = 0.1 }),
			UIKit.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(tint:Lerp(Color3.new(0, 0, 0), 0.35), Color3.fromRGB(16, 12, 24)),
			}),
		})
		Motion.shineLoop(frame, 3 + (index % 3) * 0.7)

		local iconSize = if featured then 110 elseif event then 64 else 76
		local icon = Icons.image(frame, entry.Icon or "Luck", iconSize)
		if icon then
			if event then
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 8)
			else
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.Position = UDim2.new(0, 12, 0.5, 0)
			end
		end

		local textLeft = if event then 8 else iconSize + 22
		local titleTop = if event then iconSize + 10 else 12
		UIKit.label({
			Text = entry.Title or entry.Name,
			FontFace = UIKit.TitleFont,
			TextSize = if featured then 32 elseif event then 20 else 24,
			TextStrokeTransparency = 0.4,
			TextXAlignment = if event then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(textLeft, titleTop),
			Size = UDim2.new(1, -textLeft - 8, 0, if event then 22 else 32),
			Parent = frame,
		})
		if entry.Text then
			UIKit.label({
				Text = entry.Text,
				TextSize = if featured then 18 elseif event then 14 else 15,
				TextColor3 = Color3.fromRGB(230, 222, 240),
				TextWrapped = true,
				TextXAlignment = if event then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(textLeft, titleTop + (if event then 24 else 34)),
				Size = UDim2.new(1, -textLeft - 8, 0, if event then 18 else 36),
				Parent = frame,
			})
		end
		if entry.Tag then
			local ribbon = UIKit.label({
				Name = "Ribbon",
				Text = entry.Tag,
				FontFace = UIKit.TitleFont,
				TextSize = 13,
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = colors.Red,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 14, 0, 12),
				Size = UDim2.fromOffset(130, 22),
				Rotation = 20,
				ZIndex = 5,
				Parent = frame,
			})
			UIKit.corner(4).Parent = ribbon
		end

		local buySize = if event
			then UDim2.new(1, -20, 0, 34)
			elseif featured then UDim2.fromOffset(170, 48)
			else UDim2.fromOffset(120, 38)
		local buy = UIKit.button({
			Name = "Buy",
			Text = if id > 0 then "..." else "Soon",
			FontFace = UIKit.TitleFont,
			TextSize = if featured then 24 else 18,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = buySize,
			ZIndex = 4,
			Parent = frame,
		}, function()
			if id <= 0 then
				return
			end
			if isPass then
				if player:GetAttribute(`Pass{entry.Name}`) ~= true then
					MarketplaceService:PromptGamePassPurchase(player, id)
				end
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		UIKit.skinButton(buy, if id > 0 then "Gold" else "Dark")
		if id <= 0 then
			buy.TextColor3 = colors.SubText
		end

		local price: string? = nil
		local function refresh()
			if isPass and player:GetAttribute(`Pass{entry.Name}`) == true then
				buy.Text = "Owned"
				UIKit.skinButton(buy, "Dark")
				buy.TextColor3 = colors.Text
			elseif id > 0 then
				buy.Text = if price then price else "Buy"
			end
		end
		if isPass then
			player:GetAttributeChangedSignal(`Pass{entry.Name}`):Connect(refresh)
		end
		if id > 0 then
			task.spawn(function()
				local infoType = if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
				if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
					price = `R$ {info.PriceInRobux}`
				end
				refresh()
			end)
		end
		refresh()
		return frame
	end

	card(list, nextOrder(), Config.Shop.Featured, false, "Featured")

	heading("Summon an event")
	local events = row(EVENT_HEIGHT, 3, #Config.Shop.Events)
	for index, entry in Config.Shop.Events do
		local zone = nil
		for _, each in Config.ZoneEvents.Events do
			if each.Id == entry.Event then
				zone = each
			end
		end
		card(events, index, {
			Name = entry.Name,
			Title = if zone then zone.Name else entry.Event,
			Text = if zone then zone.Effect else nil,
			Icon = entry.Icon,
			Color = if zone then zone.Color else nil,
		}, false, "Event")
	end

	heading("Passes")
	local passes = row(CARD_HEIGHT, 2, #Config.Shop.Passes)
	for index, entry in Config.Shop.Passes do
		card(passes, index, entry, true, "Card")
	end

	heading("Potions")
	local products = row(CARD_HEIGHT, 2, #Config.Shop.Products)
	for index, entry in Config.Shop.Products do
		card(products, index, entry, false, "Card")
	end

	local holder = UIKit.create("Frame", {
		Name = "ShopButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 116),
		Size = UDim2.fromOffset(150, 48),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.scaler(holder)
	-- Small screens: SHOP and GIFTS share one row under the travel bar, clear of Spirit Sight.
	UIKit.watchCompact(function(compact: boolean)
		holder.Position = if compact then UDim2.new(1, -190, 0, 34) else UDim2.new(1, -40, 0, 116)
	end)
	local open = UIKit.button({
		Text = "SHOP",
		FontFace = UIKit.TitleFont,
		TextSize = 24,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, onOpen)
	UIKit.skinButton(open, "Gold")

	return {
		Toggle = function()
			UIKit.toggle(panel)
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return ShopPanel
