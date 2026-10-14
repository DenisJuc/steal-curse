-- Bottom-center ROLL bar (Slice 9): Backpack on the left, Upgrades (skill tree) on the right.
-- With Auto Roll on, the middle is only a slim "AUTO ROLL" pill that fills as the next scan
-- charges (NextScanAt / ScanInterval attributes); rolls fire by themselves and only the roll
-- animation shows. With it off, the ROLL button appears (pill underneath): an omikuji box
-- (OmikujiBox) that fills with gold, rocks with "ROLL!" when charged and waits for a press (click,
-- R key, L1 on a gamepad); pressing rattles it and rolls. Clicking the pill toggles.
-- The server decides everything; this only shows the charge and sends RollNow / SetAutoRoll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local OmikujiBox = require(script.Parent.OmikujiBox)
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
local BOX_SIZE = Vector2.new(78, 102)
-- The charge lights the lacquer up from the bottom (bright red over the dark box).
local CHARGE_COLOR = Color3.fromRGB(235, 82, 58)
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
	UIKit.iconCaption(button, caption, 15)
	return button, slot
end

-- The icon centered in a side button at full size (the caption hangs below the button).
local function sideIcon(button: TextButton, key: string)
	local icon = Icons.draw(button, key)
	if not icon then
		return
	end
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.5, -3)
	local scale = icon:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = math.max(scale.Scale, 1.15)
	end
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
	sideIcon(backpack, "Backpack")
	backpack.Activated:Connect(callbacks.OnBackpack)

	local middle = UIKit.create("Frame", {
		Name = "Middle",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(ROLL_SIZE, ROLL_SIZE + 30),
		BackgroundTransparency = 1,
		Parent = bar,
	})
	-- The ROLL button is the omikuji box (the same one the roll animation rattles): the charge fills
	-- it from the bottom in gold, and the caption on its bottom edge shows the timer, "ROLL!" or FULL.
	-- `roll` holds the box and does the charged rocking; the box is the button (and shakes).
	local roll = UIKit.create("Frame", {
		Name = "RollButton",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(ROLL_SIZE / 2, math.round(ROLL_SIZE * 0.47)),
		Size = UDim2.fromOffset(BOX_SIZE.X, BOX_SIZE.Y),
		Parent = middle,
	})
	local box = OmikujiBox.draw(roll, BOX_SIZE, 1, "TextButton") :: TextButton
	Motion.button(box)
	OmikujiBox.SetLauncher(box)
	local rollStroke = box:FindFirstChildOfClass("UIStroke") :: UIStroke
	local charge = UIKit.create("Frame", {
		Name = "Charge",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CHARGE_COLOR,
		BackgroundTransparency = 0.35,
		ZIndex = 1,
		Parent = box,
	}, { UIKit.corner(math.round(8 * BOX_SIZE.X / 66)) })
	local gradient = UIKit.create("UIGradient", { Rotation = -90, Parent = charge })
	local rollLabel = UIKit.iconCaption(box, "ROLL", 20)

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
	sideIcon(upgrades, "Upgrades")
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
			Motion.shake(box, 120)
		end
	end
	box.Activated:Connect(press)
	Motion.shineLoop(box, 1.8, function()
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
			rollStroke.Thickness = 3
			roll.Rotation = 0
			rollLabel.Text = "FULL"
			rollLabel.TextColor3 = colors.Red
			return
		end
		if player:GetAttribute("RollCharged") == true then
			-- Charged: the box lights up, its rim pulses and it rocks, begging to be shaken.
			local now = os.clock()
			local pulse = 0.5 + 0.5 * math.sin(now * 8)
			gradient.Transparency = fillSequence(1)
			charge.BackgroundColor3 = CHARGE_COLOR
			rollStroke.Color = colors.Gold
			rollStroke.Thickness = 2 + pulse * 3
			roll.Rotation = math.sin(now * 6) * 4
			rollLabel.Text = "ROLL!"
			rollLabel.TextColor3 = colors.Gold
			return
		end
		rollStroke.Thickness = 2
		rollStroke.Color = colors.Gold
		charge.BackgroundColor3 = CHARGE_COLOR
		roll.Rotation = 0
		rollLabel.TextColor3 = colors.Text
		local nextAt = player:GetAttribute("NextScanAt")
		local interval = player:GetAttribute("ScanInterval")
		if type(nextAt) ~= "number" or type(interval) ~= "number" or interval <= 0 then
			gradient.Transparency = fillSequence(0)
			rollLabel.Text = "ROLL"
			return
		end
		local remaining = math.max(0, nextAt - workspace:GetServerTimeNow())
		gradient.Transparency = fillSequence(math.clamp(1 - remaining / interval, 0, 1))
		rollLabel.Text = Format.seconds(remaining)
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
