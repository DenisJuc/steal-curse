-- Bottom-center ROLL bar (Slice 9): Backpack on the left, Upgrades (skill tree) on the right.
-- With Auto Roll on, the middle is only a slim "AUTO ROLL" pill that fills as the next scan
-- charges (NextScanAt / ScanInterval attributes); rolls fire by themselves and only the roll
-- animation shows. With it off, the big ROLL button appears (pill underneath): it fills up, glows
-- "ROLL!" when charged and waits for a press (R key, L1 on a gamepad). Clicking the pill toggles.
-- The server decides everything; this only shows the charge and sends RollNow / SetAutoRoll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollNow = Remotes:WaitForChild("RollNow") :: RemoteEvent
local SetAutoRoll = Remotes:WaitForChild("SetAutoRoll") :: RemoteEvent

local RollBar = {}

export type Callbacks = {
	OnBackpack: () -> (),
	OnUpgrades: () -> (),
}

local ROLL_SIZE = 112
local SIDE_SIZE = 76

local function sideButton(parent: Instance, name: string, caption: string, order: number): (TextButton, Frame)
	local slot = UIKit.slot(parent, name .. "Slot", UDim2.fromOffset(SIDE_SIZE, SIDE_SIZE), order)
	local button = UIKit.create("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		Parent = slot,
	}, { UIKit.corner(16) })
	UIKit.fill(button)
	UIKit.skinPanel(button)
	Motion.button(button)
	UIKit.label({
		Name = "Caption",
		Text = caption,
		TextSize = 13,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -4, 0, 14),
		ZIndex = 2,
		Parent = button,
	})
	return button, slot
end

-- Transparency sequence that shows the bottom `fraction` of a vertical gradient.
local function fillSequence(fraction: number): NumberSequence
	if fraction <= 0.001 then
		return NumberSequence.new(1)
	elseif fraction >= 0.999 then
		return NumberSequence.new(0)
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(fraction, 0),
		NumberSequenceKeypoint.new(math.min(fraction + 0.001, 0.999), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

function RollBar.Start(screen: ScreenGui, callbacks: Callbacks): { Frame: Frame, SetSideVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local bar = UIKit.create("Frame", {
		Name = "RollBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(SIDE_SIZE * 2 + ROLL_SIZE + 40, ROLL_SIZE + 30),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 20),
		}),
	})
	UIKit.scaler(bar)

	local backpack, backpackSlot = sideButton(bar, "BackpackButton", "Backpack", 1)
	Icons.draw(backpack, "Backpack")
	backpack.Activated:Connect(callbacks.OnBackpack)

	local middle = UIKit.create("Frame", {
		Name = "Middle",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(ROLL_SIZE, ROLL_SIZE + 30),
		BackgroundTransparency = 1,
		Parent = bar,
	})
	local roll = UIKit.create("TextButton", {
		Name = "RollButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = colors.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(ROLL_SIZE / 2, ROLL_SIZE / 2),
		Size = UDim2.fromOffset(ROLL_SIZE, ROLL_SIZE),
		Parent = middle,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local rollStroke = UIKit.stroke(colors.Accent, 4, 0.1)
	rollStroke.Parent = roll
	Motion.button(roll)
	local charge = UIKit.create("Frame", {
		Name = "Charge",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Accent,
		BackgroundTransparency = 0.25,
		Parent = roll,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local gradient = UIKit.create("UIGradient", { Rotation = -90, Parent = charge })
	local rollLabel = UIKit.label({
		Name = "Title",
		Text = "ROLL",
		TextSize = 30,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1, 0, 0, 32),
		ZIndex = 2,
		Parent = roll,
	})
	local subLabel = UIKit.label({
		Name = "Timer",
		TextSize = 14,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 2,
		Parent = roll,
	})

	-- With Auto Roll on this pill is all that shows between Backpack and Upgrades: it fills up as
	-- the next roll charges. With it off it sits under the ROLL button.
	local auto = UIKit.button({
		Name = "AutoRoll",
		Text = "",
		Parent = middle,
	})
	local autoFill = UIKit.create("Frame", {
		Name = "Charge",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = colors.Accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = auto,
	}, { UIKit.corner(8) })
	local autoLabel = UIKit.label({
		Name = "Label",
		TextSize = 14,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = auto,
	})

	local upgrades, upgradesSlot = sideButton(bar, "UpgradesButton", "Upgrades", 3)
	Icons.draw(upgrades, "Upgrades")
	upgrades.Activated:Connect(callbacks.OnUpgrades)

	local function isAuto(): boolean
		return player:GetAttribute("AutoRoll") ~= false
	end
	local wasAuto: boolean? = nil
	local function refreshAuto()
		local on = isAuto()
		local middleSize = if on then Vector2.new(ROLL_SIZE + 24, SIDE_SIZE) else Vector2.new(ROLL_SIZE, ROLL_SIZE + 30)
		middle.Size = UDim2.fromOffset(middleSize.X, middleSize.Y)
		bar.Size = UDim2.fromOffset(SIDE_SIZE * 2 + middleSize.X + 40, middleSize.Y)
		roll.Visible = not on
		auto.AnchorPoint = Vector2.new(0.5, 0.5)
		auto.Position = if on then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 1, -13)
		auto.Size = if on then UDim2.fromOffset(ROLL_SIZE + 24, 36) else UDim2.fromOffset(ROLL_SIZE, 26)
		autoFill.Visible = on
		autoLabel.Text = if on then "AUTO ROLL" else "Auto Roll: OFF"
		autoLabel.TextSize = if on then 15 else 14
		UIKit.skinButton(auto, "Dark")
		if wasAuto ~= nil and on ~= wasAuto then
			Motion.pop(if on then auto else roll, 0, 0.4)
		end
		wasAuto = on
	end
	player:GetAttributeChangedSignal("AutoRoll"):Connect(refreshAuto)
	refreshAuto()
	auto.Activated:Connect(function()
		local on = not isAuto()
		player:SetAttribute("AutoRoll", on)
		SetAutoRoll:FireServer(on)
	end)

	local function press()
		if player:GetAttribute("RollCharged") == true then
			RollNow:FireServer()
			Motion.punch(roll, 3)
		end
	end
	roll.Activated:Connect(press)
	Motion.shineLoop(roll, 1.8, function()
		return player:GetAttribute("RollCharged") == true and player:GetAttribute("ScanPaused") ~= true
	end)
	local wasCharged = player:GetAttribute("RollCharged") == true
	player:GetAttributeChangedSignal("RollCharged"):Connect(function()
		local charged = player:GetAttribute("RollCharged") == true
		if charged and not wasCharged and not isAuto() then
			Motion.punch(roll, 2)
		end
		wasCharged = charged
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonL1 then
			press()
		end
	end)

	local function refreshPaused()
		local paused = player:GetAttribute("ScanPaused") == true
		local stroke = backpack:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if paused then colors.Red else colors.Trim
			stroke.Thickness = if paused then 3 else 2
		end
		if paused then
			Motion.shake(backpack, 120)
		end
	end
	player:GetAttributeChangedSignal("ScanPaused"):Connect(refreshPaused)
	refreshPaused()

	RunService.RenderStepped:Connect(function()
		if isAuto() then
			local paused = player:GetAttribute("ScanPaused") == true
			local nextAt = player:GetAttribute("NextScanAt")
			local interval = player:GetAttribute("ScanInterval")
			local fraction = 0
			if paused then
				fraction = 1
			elseif type(nextAt) == "number" and type(interval) == "number" and interval > 0 then
				fraction = math.clamp(1 - (nextAt - workspace:GetServerTimeNow()) / interval, 0, 1)
			end
			autoFill.Size = UDim2.fromScale(fraction, 1)
			autoFill.BackgroundColor3 = if paused then colors.Red else colors.Accent
			autoLabel.Text = if paused then "FULL: sell relics" else "AUTO ROLL"
			return
		end
		if player:GetAttribute("ScanPaused") == true then
			gradient.Transparency = fillSequence(1)
			charge.BackgroundColor3 = colors.Red
			rollStroke.Color = colors.Red
			rollLabel.Text = "FULL"
			subLabel.Text = "Sell relics"
			return
		end
		if player:GetAttribute("RollCharged") == true then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
			gradient.Transparency = fillSequence(1)
			charge.BackgroundColor3 = colors.Gold
			rollStroke.Color = colors.Gold
			rollStroke.Thickness = 4 + pulse * 3
			rollLabel.Text = "ROLL!"
			subLabel.Text = "Ready"
			return
		end
		rollStroke.Thickness = 4
		rollStroke.Color = colors.Accent
		charge.BackgroundColor3 = colors.Accent
		rollLabel.Text = "ROLL"
		local nextAt = player:GetAttribute("NextScanAt")
		local interval = player:GetAttribute("ScanInterval")
		if type(nextAt) ~= "number" or type(interval) ~= "number" or interval <= 0 then
			gradient.Transparency = fillSequence(0)
			subLabel.Text = "Warming up"
			return
		end
		local remaining = math.max(0, nextAt - workspace:GetServerTimeNow())
		gradient.Transparency = fillSequence(math.clamp(1 - remaining / interval, 0, 1))
		subLabel.Text = if isAuto() then `Auto {Format.seconds(remaining)}` else Format.seconds(remaining)
	end)

	return {
		Frame = bar,
		-- Spirit Sight hides Backpack and Upgrades; the ROLL button stays.
		SetSideVisible = function(visible: boolean)
			backpackSlot.Visible = visible
			upgradesSlot.Visible = visible
		end,
	}
end

return RollBar
