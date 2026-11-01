-- Playtime gifts (PlaytimeService): a GIFTS button under SHOP counts down to the next gift and
-- shows a red dot when one is ready; the menu lists every step with its reward and a Claim button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Motion = require(script.Parent.Motion)
local Toasts = require(script.Parent.Toasts)
local UIKit = require(script.Parent.UIKit)

local ClaimPlaytimeGift = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimPlaytimeGift") :: RemoteFunction

local player = Players.LocalPlayer

local GiftPanel = {}

local ROW_HEIGHT = 64

local function rewardText(gift: any): string
	local parts = {}
	if gift.CEMinutes then
		table.insert(parts, `{gift.CEMinutes} min of CE`)
	end
	for id, count in gift.Potions or {} do
		local item = ItemConfig.ById[id]
		table.insert(parts, if count > 1 then `{count}x {item and item.Name or id}` else (item and item.Name or id))
	end
	return table.concat(parts, " + ")
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

function GiftPanel.Start(screen: ScreenGui, onOpen: () -> ()): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "GiftsMenu", "GIFTS", colors.Gold, Vector2.new(480, 520))
	local list = UIKit.scrollList(content, 8)
	local rows: { { Button: TextButton, Index: number } } = {}
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

	for index, gift in Config.PlaytimeGifts do
		local slot = UIKit.slot(list, `Gift{index}`, UDim2.new(1, -10, 0, ROW_HEIGHT), index)
		local card = UIKit.create("Frame", { BackgroundColor3 = colors.Card, Parent = slot }, {
			UIKit.corner(10),
			UIKit.padding(10),
		})
		UIKit.fill(card)
		UIKit.skinCard(card)
		UIKit.label({
			Text = `{gift.Minutes} min`,
			FontFace = UIKit.TitleFont,
			TextSize = 22,
			TextColor3 = colors.Gold,
			Size = UDim2.new(0, 80, 1, 0),
			Parent = card,
		})
		UIKit.label({
			Text = rewardText(gift),
			TextSize = 16,
			TextWrapped = true,
			Position = UDim2.fromOffset(84, 0),
			Size = UDim2.new(1, -84 - 130, 1, 0),
			Parent = card,
		})
		local button = UIKit.button({
			Text = "",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(120, 40),
			Parent = card,
		}, function()
			local ok, message = pcall(ClaimPlaytimeGift.InvokeServer, ClaimPlaytimeGift, index)
			Toasts.Show(if ok and type(message) == "string" then message else "Try again in a moment.")
		end)
		table.insert(rows, { Button = button, Index = index })
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
		dot.Visible = ready > 0
		open.Text = if ready > 0
			then "GIFT READY!"
			elseif nextLeft < math.huge then `GIFT {Format.duration(math.ceil(nextLeft))}`
			else "GIFTS"
		skin(open, if ready > 0 then "Gold" else "Dark")
		if not panel.Visible then
			return
		end
		for _, row in rows do
			local left = secondsLeft(row.Index)
			if claimed(row.Index) then
				row.Button.Text = "Claimed"
				skin(row.Button, "Dark")
			elseif left and left <= 0 then
				row.Button.Text = "Claim"
				skin(row.Button, "Gold")
			else
				row.Button.Text = if left then Format.duration(math.ceil(left)) else "..."
				skin(row.Button, "Dark")
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
