-- Playtime gifts (PlaytimeService): a GIFTS button under SHOP counts down to the next gift and
-- shows a red dot when one is ready (or a bounty can be claimed); the menu lists every step with its
-- reward and a Claim button, plus a Bounties button so bounties can be claimed from anywhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Sounds = require(script.Parent.Parent.Sounds)
local Toasts = require(script.Parent.Toasts)
local UIKit = require(script.Parent.UIKit)

local ClaimPlaytimeGift = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimPlaytimeGift") :: RemoteFunction

local player = Players.LocalPlayer

local GiftPanel = {}

local COLUMNS = 4
local TILE_HEIGHT = 160

-- The tile's picture: the first potion, else Cursed Energy.
local function iconOf(gift: any): string
	for id in gift.Potions or {} do
		local item = ItemConfig.ById[id]
		if item then
			return `Potion{item.Effect}`
		end
	end
	return "CursedEnergy"
end

-- A few words for a tile: "Luck Potion", "5 min CE", "2 potions + CE".
local function shortReward(gift: any): string
	local potions = 0
	local name = nil
	for id, count in gift.Potions or {} do
		potions += count
		local item = ItemConfig.ById[id]
		name = item and item.Name or id
	end
	if potions == 0 then
		return `{gift.CEMinutes} min of CE`
	elseif potions == 1 and not gift.CEMinutes then
		return name :: string
	elseif gift.CEMinutes then
		return `{potions} potion{if potions == 1 then "" else "s"} + CE`
	end
	return `{potions} potions`
end

local function claimed(index: number): boolean
	local list = player:GetAttribute("PlaytimeClaimed")
	if type(list) ~= "string" then
		return false
	end
	for part in string.gmatch(list, "%d+") do
		if tonumber(part) == index then
			return true
		end
	end
	return false
end

-- Seconds until gift `index` unlocks (<= 0 = ready); nil before the session starts.
local function secondsLeft(index: number): number?
	local start = player:GetAttribute("PlaytimeStart")
	if type(start) ~= "number" then
		return nil
	end
	return start + Config.PlaytimeGifts[index].Minutes * 60 - workspace:GetServerTimeNow()
end

function GiftPanel.Start(
	screen: ScreenGui,
	onOpen: () -> (),
	onBounties: () -> ()
): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "GiftsMenu", "FREE GIFTS", colors.Gold, Vector2.new(560, 520))
	local list = UIKit.scrollList(content, 8)
	local bounties = UIKit.button({
		Text = "Daily bounties",
		TextSize = 18,
		LayoutOrder = 0,
		Size = UDim2.new(1, -10, 0, 44),
		Parent = list,
	}, onBounties)
	local rows: { { Button: TextButton, Index: number, Card: Frame, Stroke: UIStroke, Icon: ImageLabel? } } = {}
	-- skinButton "Gold" darkens the text and "Dark" doesn't undo it; only restyle on a change.
	local function skin(button: TextButton, kind: string)
		if button:GetAttribute("Skin") == kind then
			return
		end
		button:SetAttribute("Skin", kind)
		UIKit.skinButton(button, kind)
		if kind == "Dark" then
			button.TextColor3 = colors.Text
		end
	end

	-- Gifts as a grid of glowing tiles: big icon, short reward, a timer that turns into CLAIM!.
	local grid = UIKit.create("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, -10, 0, math.ceil(#Config.PlaytimeGifts / COLUMNS) * (TILE_HEIGHT + 10)),
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.new(1 / COLUMNS, -8, 0, TILE_HEIGHT),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, gift in Config.PlaytimeGifts do
		local card = UIKit.create("Frame", {
			Name = `Gift{index}`,
			LayoutOrder = index,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Parent = grid,
		}, {
			UIKit.corner(14),
			UIKit.create("UIGradient", { Rotation = 90 }),
		})
		local stroke = UIKit.stroke(colors.Trim, 2.5, 0.2)
		stroke.Parent = card
		Motion.shineLoop(card, 2.2, function()
			return card:GetAttribute("Ready") == true
		end)
		UIKit.label({
			Text = `{gift.Minutes} MIN`,
			FontFace = UIKit.TitleFont,
			TextSize = 16,
			TextColor3 = colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 18),
			Parent = card,
		})
		local icon = Icons.image(card, iconOf(gift), 56)
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 26)
		end
		local label = UIKit.label({
			Text = shortReward(gift),
			TextSize = 13,
			TextColor3 = Color3.fromRGB(230, 222, 240),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Position = UDim2.fromOffset(4, 84),
			Size = UDim2.new(1, -8, 0, 30),
			Parent = card,
		})
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = label })
		label.TextScaled = true
		local button = UIKit.button({
			Text = "",
			FontFace = UIKit.TitleFont,
			TextSize = 17,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -14, 0, 32),
			ZIndex = 3,
			Parent = card,
		}, function()
			local ok, message = pcall(ClaimPlaytimeGift.InvokeServer, ClaimPlaytimeGift, index)
			Toasts.Show(if ok and type(message) == "string" then message else "Try again in a moment.")
			if ok and type(message) == "string" and string.find(message, "Gift", 1, true) == 1 then
				Sounds.Play("Collect")
				Motion.flash(card, colors.Gold, 0.2)
			end
		end)
		table.insert(rows, { Button = button, Index = index, Card = card, Stroke = stroke, Icon = icon })
	end

	-- The HUD button under SHOP.
	local holder = UIKit.create("Frame", {
		Name = "GiftButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 186),
		Size = UDim2.fromOffset(150, 44),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.scaler(holder)
	UIKit.watchCompact(function(compact: boolean)
		holder.Position = if compact then UDim2.new(1, -40, 0, 34) else UDim2.new(1, -40, 0, 186)
	end)
	local open = UIKit.button({
		Text = "GIFTS",
		FontFace = UIKit.TitleFont,
		TextSize = 20,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, onOpen)
	skin(open, "Dark")
	local dot = UIKit.create("Frame", {
		Name = "Ready",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = colors.Red,
		Visible = false,
		ZIndex = 5,
		Parent = open,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Motion.badge(dot)

	local elapsed = 1
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		local ready, nextLeft = 0, math.huge
		for index in Config.PlaytimeGifts do
			local left = secondsLeft(index)
			if left and not claimed(index) then
				if left <= 0 then
					ready += 1
				else
					nextLeft = math.min(nextLeft, left)
				end
			end
		end
		local bountyReady = (player:GetAttribute("BountiesReady") or 0) > 0
		dot.Visible = ready > 0 or bountyReady
		open.Text = if ready > 0
			then "GIFT READY!"
			elseif bountyReady then "BOUNTY READY!"
			elseif nextLeft < math.huge then `GIFT {Format.duration(math.ceil(nextLeft))}`
			else "GIFTS"
		skin(open, if ready > 0 or bountyReady then "Gold" else "Dark")
		skin(bounties, if bountyReady then "Gold" else "Dark")
		if not panel.Visible then
			return
		end
		for _, row in rows do
			local left = secondsLeft(row.Index)
			local state = if claimed(row.Index) then "Claimed" elseif left and left <= 0 then "Ready" else "Waiting"
			if state == "Claimed" then
				row.Button.Text = "\u{2713} Claimed"
				skin(row.Button, "Dark")
			elseif state == "Ready" then
				row.Button.Text = "CLAIM!"
				skin(row.Button, "Gold")
			else
				row.Button.Text = if left then Format.duration(math.ceil(left)) else "..."
				skin(row.Button, "Dark")
			end
			if row.Card:GetAttribute("State") ~= state then
				row.Card:SetAttribute("State", state)
				row.Card:SetAttribute("Ready", state == "Ready")
				local top = if state == "Ready"
					then Color3.fromRGB(150, 104, 30)
					elseif state == "Claimed" then Color3.fromRGB(30, 26, 38)
					else Color3.fromRGB(64, 40, 96)
				local gradient = row.Card:FindFirstChildOfClass("UIGradient") :: UIGradient
				gradient.Color = ColorSequence.new(top, Color3.fromRGB(16, 12, 24))
				row.Stroke.Color = if state == "Ready" then colors.Gold else colors.Trim
				row.Stroke.Transparency = if state == "Claimed" then 0.7 else 0.1
				if row.Icon then
					row.Icon.ImageTransparency = if state == "Claimed" then 0.6 else 0
				end
				if state == "Ready" then
					Motion.pop(row.Card, 0, 0.8)
				end
			end
		end
	end)

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

return GiftPanel
