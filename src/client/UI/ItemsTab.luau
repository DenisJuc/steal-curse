-- Backpack "Items" tab (Slice 12): one row per potion with how many you own, the active timer and
-- a Use button. Counts and timers come from the Item_<id> / BuffEnds_<id> attributes; using one is
-- an ItemAction request the server validates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)
local Sounds = require(script.Parent.Parent.Sounds)

local ItemAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemAction") :: RemoteFunction

local ItemsTab = {}

local ROW_HEIGHT = 74

type Row = {
	Item: ItemConfig.Item,
	Count: TextLabel,
	Timer: TextLabel,
	Use: TextButton,
}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

function ItemsTab.Build(page: Frame): { Refresh: () -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local status = UIKit.label({
		Name = "Status",
		Text = "Potions drop from hunt captures, Codex rewards and your first Legendary find.",
		TextColor3 = colors.SubText,
		TextSize = 14,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = page,
	})
	local list = UIKit.scrollList(page, 8)
	list.Position = UDim2.fromOffset(0, 42)
	list.Size = UDim2.new(1, 0, 1, -42)

	local rows: { Row } = {}
	local busy = false

	local function countOf(id: string): number
		local count = player:GetAttribute(`Item_{id}`)
		return if type(count) == "number" then count else 0
	end

	local function leftOf(id: string): number
		local ends = player:GetAttribute(`BuffEnds_{id}`)
		return if type(ends) == "number" then math.max(0, ends - workspace:GetServerTimeNow()) else 0
	end

	local function refreshRow(row: Row)
		local id = row.Item.Id
		local count = countOf(id)
		local left = leftOf(id)
		row.Count.Text = `Owned: {count}`
		row.Timer.Text = if left > 0 then `Active: {ItemConfig.formatTime(left)}` else ""
		local full = left >= ItemConfig.MaxBuffSeconds - 1
		local usable = count > 0 and not full
		row.Use.Text = if full then "Max" else "Use"
		UIKit.skinButton(row.Use, if usable then "Gold" else "Dark")
		if usable then
			row.Use.BackgroundColor3 = rgb(row.Item.Color)
		end
		row.Use.TextColor3 = if usable then colors.Panel else colors.SubText
		Motion.setDisabled(row.Use, not usable)
	end

	for index, item in ItemConfig.Items do
		local color = rgb(item.Color)
		local frame = UIKit.create("Frame", {
			Name = item.Id,
			LayoutOrder = index,
			BackgroundColor3 = colors.Card,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			Parent = list,
		}, { UIKit.corner(10), UIKit.stroke(color, 2, 0.4) })
		UIKit.skinCard(frame)
		UIKit.create("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = color,
			Parent = frame,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(0, 0.5),
			}),
		})
		UIKit.label({
			Name = "Title",
			Text = item.Name,
			TextSize = 17,
			TextColor3 = color,
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -190, 0, 20),
			Parent = frame,
		})
		UIKit.label({
			Name = "Description",
			Text = item.Description,
			TextSize = 13,
			TextColor3 = colors.SubText,
			TextWrapped = true,
			Position = UDim2.fromOffset(68, 28),
			Size = UDim2.new(1, -190, 0, 18),
			Parent = frame,
		})
		local count = UIKit.label({
			Name = "Count",
			TextSize = 13,
			Position = UDim2.fromOffset(68, 48),
			Size = UDim2.fromOffset(90, 18),
			Parent = frame,
		})
		local timer = UIKit.label({
			Name = "Timer",
			TextSize = 13,
			TextColor3 = color,
			Position = UDim2.fromOffset(160, 48),
			Size = UDim2.fromOffset(140, 18),
			Parent = frame,
		})
		local useButton = UIKit.button({
			Name = "Use",
			Text = "Use",
			TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -60, 0.5, 0),
			Size = UDim2.fromOffset(96, 40),
			Parent = frame,
		})
		local row = { Item = item, Count = count, Timer = timer, Use = useButton }
		table.insert(rows, row)

		useButton.Activated:Connect(function()
			if busy or countOf(item.Id) <= 0 or useButton:GetAttribute("Disabled") then
				return
			end
			busy = true
			local ok, result = pcall(function()
				return ItemAction:InvokeServer("Use", item.Id)
			end)
			busy = false
			if ok and type(result) == "table" and type(result.Message) == "string" then
				status.Text = result.Message
				status.TextColor3 = if result.Ok then color else colors.Red
				if result.Ok then
					Motion.flash(frame, color, 0.5)
					Motion.punch(useButton, 2.5)
					Sounds.Play("Shine", nil, 1.1)
				else
					Motion.deny(useButton)
				end
			end
			refreshRow(row)
		end)

		player:GetAttributeChangedSignal(`Item_{item.Id}`):Connect(function()
			refreshRow(row)
		end)
		player:GetAttributeChangedSignal(`BuffEnds_{item.Id}`):Connect(function()
			refreshRow(row)
		end)
		refreshRow(row)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 or not page.Visible then
			return
		end
		elapsed = 0
		for _, row in rows do
			refreshRow(row)
		end
	end)

	return {
		Refresh = function()
			for _, row in rows do
				refreshRow(row)
			end
		end,
	}
end

return ItemsTab
