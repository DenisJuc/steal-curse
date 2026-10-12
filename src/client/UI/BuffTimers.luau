-- Bottom-right potion timers (Slice 12): one pill per active buff with its time left, read from the
-- BuffEnds_<id> attributes. Timers only run while you are online (the server pauses them offline).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local BuffTimers = {}

local PILL_WIDTH = 170
local PILL_HEIGHT = 30
-- On touch screens the jump button owns the bottom-right corner.
local TOUCH_LIFT = 150
-- Under this many seconds left the pill bounces every second.
local WARN_SECONDS = 10

local SHORT_NAMES = {
	Luck = "Luck x2",
	Haste = "Haste -25%",
	Fortune = "Fortune +50%",
}

function BuffTimers.Start(screen: ScreenGui)
	local player = Players.LocalPlayer
	local lift = if UserInputService.TouchEnabled then TOUCH_LIFT else 0

	local holder = UIKit.create("Frame", {
		Name = "BuffTimers",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12 - lift),
		Size = UDim2.fromOffset(PILL_WIDTH, (PILL_HEIGHT + 6) * #ItemConfig.Items),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
		}),
	})
	UIKit.scaler(holder)

	local pills: { [string]: TextLabel } = {}
	local slots: { [string]: Frame } = {}
	local lastSecond: { [string]: number } = {}
	for index, item in ItemConfig.Items do
		local color = Color3.fromRGB(item.Color[1], item.Color[2], item.Color[3])
		local slot = UIKit.slot(holder, item.Id, UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT), index)
		slot.Visible = false
		local pill = UIKit.label({
			Name = "Pill",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = slot,
		})
		UIKit.fill(pill)
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		UIKit.create("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingLeft = UDim.new(0, 30), Parent = pill })
		UIKit.skinPanel(pill, color)
		slots[item.Id] = slot
		UIKit.create("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -22, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = color,
			Parent = pill,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		pills[item.Id] = pill
	end

	local elapsed = 1
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, item in ItemConfig.Items do
			local pill = pills[item.Id]
			local slot = slots[item.Id]
			local ends = player:GetAttribute(`BuffEnds_{item.Id}`)
			local left = if type(ends) == "number" then ends - now else 0
			local active = left > 0
			if active and not slot.Visible then
				Motion.pop(pill, 0, 0.3)
			end
			slot.Visible = active
			if active then
				pill.Text = `{SHORT_NAMES[item.Effect] or item.Name}  {ItemConfig.formatTime(left)}`
				local second = math.ceil(left)
				if left < WARN_SECONDS and second ~= lastSecond[item.Id] then
					Motion.punch(pill, 1.5)
				end
				lastSecond[item.Id] = second
			end
		end
	end)
end

return BuffTimers
