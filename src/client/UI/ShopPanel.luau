-- Shop menu (ShopService): game passes on top, developer products below (Config.Shop order and
-- text). Prices come from Roblox; an item whose id is still 0 shows "Soon" and can't be bought.
-- Owned passes show "Owned" (Pass<Name> attributes from GamePassService). Opened by the gold SHOP
-- button under the travel bar (top right).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local ShopPanel = {}

local CARD = Vector2.new(250, 118)

type Entry = { Name: string, Title: string, Text: string }

function ShopPanel.Start(screen: ScreenGui, onOpen: () -> ()): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "ShopMenu", "SHOP", colors.Gold, Vector2.new(580, 620))
	local list = UIKit.scrollList(content, 10)

	local function section(order: number, title: string, count: number): Frame
		UIKit.label({
			LayoutOrder = order,
			Text = title,
			FontFace = UIKit.TitleFont,
			TextSize = 22,
			TextColor3 = colors.Gold,
			Size = UDim2.new(1, -10, 0, 28),
			Parent = list,
		})
		local rows = math.ceil(count / 2)
		return UIKit.create("Frame", {
			LayoutOrder = order + 1,
			Size = UDim2.new(1, -10, 0, rows * (CARD.Y + 10)),
			BackgroundTransparency = 1,
			Parent = list,
		}, {
			UIKit.create("UIGridLayout", {
				CellSize = UDim2.new(0.5, -5, 0, CARD.Y),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	local function card(grid: Frame, order: number, entry: Entry, isPass: boolean)
		local id = (if isPass then Config.GamePasses[entry.Name] else Config.DevProducts[entry.Name]) or 0
		local frame = UIKit.create("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = colors.Card,
			Parent = grid,
		}, { UIKit.corner(10), UIKit.padding(10) })
		UIKit.skinCard(frame, colors.Gold)
		UIKit.label({
			Text = entry.Title,
			FontFace = UIKit.TitleFont,
			TextSize = 22,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = frame,
		})
		UIKit.label({
			Text = entry.Text,
			TextSize = 15,
			TextColor3 = colors.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 36),
			Parent = frame,
		})
		local buy = UIKit.button({
			Text = if id > 0 then "..." else "Soon",
			TextSize = 18,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34),
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

		local price: string? = nil
		local function refresh()
			if isPass and player:GetAttribute(`Pass{entry.Name}`) == true then
				buy.Text = "Owned"
				UIKit.skinButton(buy, "Dark")
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
	end

	local passes = section(1, "Passes", #Config.Shop.Passes)
	for index, entry in Config.Shop.Passes do
		card(passes, index, entry, true)
	end
	local products = section(3, "Boosts", #Config.Shop.Products)
	for index, entry in Config.Shop.Products do
		card(products, index, entry, false)
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
