-- Settings menu (GDD 12.1): effects quality, reveals, camera effects, sound volume, interface size,
-- Welcome Back summary and beginner hints (ClientSettings, saved by the server). One short label
-- per row; option settings show every option as pills (On/Off reads as a switch); range settings
-- (sound volume) are sliders that can be dragged, or moved with the -/+ buttons (gamepad).
-- Below them: a code box (CodeService) and, once Config.Group has an id, the group reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)
local Config = require(ReplicatedStorage.Shared.Config)
local Motion = require(script.Parent.Motion)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local Toasts = require(script.Parent.Toasts)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RedeemCode = Remotes:WaitForChild("RedeemCode") :: RemoteFunction
local ClaimGroupReward = Remotes:WaitForChild("ClaimGroupReward") :: RemoteFunction

local SettingsPanel = {}

local ROW_HEIGHT = 60
local OPTION_WIDTH = 96
local SLIDER_WIDTH = 270
-- Shorter names for the menu rows (ClientSettings keeps the full ones).
local SHORT_LABELS = {
	["Visual effects"] = "Effects",
	["Camera effects"] = "Camera shake",
	["Sound volume"] = "Sound",
	["Interface size"] = "Menu size",
	["Welcome Back summary"] = "Welcome Back",
	["Beginner hints"] = "Tutorial",
}

function SettingsPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content =
		UIKit.modal(screen, "SettingsMenu", "SETTINGS", colors.Accent, Vector2.new(560, 560), "Settings")
	local list = UIKit.scrollList(content, 6)

	local function row(order: number, label: string, controlWidth: number): Frame
		local frame = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, { UIKit.corner(10), UIKit.padding(8) })
		UIKit.skinCard(frame)
		UIKit.label({
			Text = SHORT_LABELS[label] or label,
			TextSize = 20,
			Size = UDim2.new(1, -controlWidth - 12, 1, 0),
			Parent = frame,
		})
		return frame
	end

	-- Every option visible at once as pills; the chosen one is filled gold (On/Off is a switch).
	local function optionsControl(frame: Frame, setting: ClientSettings.Setting)
		local options = setting.Options :: { ClientSettings.Value }
		local tabs = {}
		for _, option in options do
			table.insert(tabs, { Id = tostring(option), Text = ClientSettings.display(setting.Key, option) })
		end
		local bar, buttons, selectOption = UIKit.tabBar(frame, tabs, tostring(Settings.Get(setting.Key)), function(id)
			for _, option in options do
				if tostring(option) == id then
					Settings.Set(setting.Key, option)
					for key, value in (setting.Also and setting.Also[id]) or {} do
						Settings.Set(key, value)
					end
				end
			end
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(#options * OPTION_WIDTH, ROW_HEIGHT - 16),
		})
		bar.Name = setting.Key
		for _, button in buttons do
			button.TextSize = 18
		end
		player:GetAttributeChangedSignal(`Setting_{setting.Key}`):Connect(function()
			local id = tostring(Settings.Get(setting.Key))
			selectOption(id)
			if buttons[id] then
				Motion.punch(buttons[id], 1.5)
			end
		end)
	end
	local function sliderControl(frame: Frame, setting: ClientSettings.Setting)
		local range = setting.Range :: ClientSettings.Range
		local holder = UIKit.create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(SLIDER_WIDTH, 38),
			Parent = frame,
		})
		local function nudgeButton(text: string, x: number, steps: number)
			local nudge = UIKit.button({
				Text = text,
				TextSize = 18,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, x + 15, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				Parent = holder,
			}, function()
				local value = ClientSettings.nudge(setting.Key, Settings.Get(setting.Key), steps * 2)
				if value ~= nil then
					Settings.Set(setting.Key, value)
				end
			end)
			UIKit.skinButton(nudge, "Dark")
		end
		nudgeButton("-", 0, -1)
		nudgeButton("+", SLIDER_WIDTH - 82, 1)
		local valueLabel = UIKit.label({
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(52, 22),
			Parent = holder,
		})

		local track = UIKit.create("Frame", {
			Name = "Track",
			BackgroundColor3 = colors.Panel,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 42, 0.5, 0),
			Size = UDim2.fromOffset(SLIDER_WIDTH - 136, 8),
			Parent = holder,
		}, { UIKit.corner(4) })
		local fill = UIKit.create("Frame", {
			BackgroundColor3 = colors.Accent,
			Size = UDim2.fromScale(1, 1),
			Parent = track,
		}, { UIKit.corner(4) })
		local knob = UIKit.create("Frame", {
			BackgroundColor3 = colors.Gold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(18, 18),
			ZIndex = 2,
			Parent = track,
		}, { UIKit.corner(9) })
		-- A taller invisible hit area so the thin track is easy to grab on touch screens.
		local hit = UIKit.create("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Selectable = false,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -8, 0.5, 0),
			Size = UDim2.new(1, 16, 0, 34),
			ZIndex = 3,
			Parent = track,
		})

		local dragging = false
		local function setFromX(x: number)
			local width = math.max(track.AbsoluteSize.X, 1)
			local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
			Settings.Set(setting.Key, range.Min + alpha * (range.Max - range.Min))
		end
		local function isPress(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		hit.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = true
				list.ScrollingEnabled = false
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if dragging and isPress(input) then
				dragging = false
				list.ScrollingEnabled = true
				Sounds.Play("Click")
			end
		end)

		Settings.Watch(setting.Key, function(value)
			local number = if type(value) == "number" then value else range.Max
			local alpha = (number - range.Min) / (range.Max - range.Min)
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
			valueLabel.Text = ClientSettings.display(setting.Key, value)
		end)
	end

	for order, setting in ClientSettings.Schema do
		if setting.Hidden then
			continue
		elseif setting.Range then
			sliderControl(row(order, setting.Label, SLIDER_WIDTH), setting)
		else
			local count = #(setting.Options :: { any })
			optionsControl(row(order, setting.Label, count * OPTION_WIDTH), setting)
		end
	end

	local function ask(remote: RemoteFunction, ...: any)
		local ok, message = pcall(remote.InvokeServer, remote, ...)
		Toasts.Show(if ok and type(message) == "string" then message else "Try again in a moment.")
		if ok and type(message) == "string" and (string.find(message, "Code", 1, true) == 1 or string.find(message, "Thanks", 1, true) == 1) then
			Sounds.Play("Collect")
		end
	end

	local codeRow = row(#ClientSettings.Schema + 1, "Code", 300)
	local codeBox = UIKit.create("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -112, 0.5, 0),
		Size = UDim2.fromOffset(186, 38),
		BackgroundColor3 = colors.Panel,
		Font = UIKit.Font,
		TextSize = 18,
		TextColor3 = colors.Text,
		PlaceholderText = "Enter code",
		Text = "",
		ClearTextOnFocus = false,
		Parent = codeRow,
	}, { UIKit.corner(8) })
	local redeem = UIKit.button({
		Text = "Redeem",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(104, 38),
		Parent = codeRow,
	}, function()
		ask(RedeemCode, codeBox.Text)
		codeBox.Text = ""
	end)
	UIKit.skinButton(redeem, "Gold")

	if Config.Group.GroupId > 0 then
		local groupRow = row(#ClientSettings.Schema + 2, "Group reward", 140)
		local claim = UIKit.button({
			Text = "Claim",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(120, 38),
			Parent = groupRow,
		}, function()
			ask(ClaimGroupReward)
		end)
		UIKit.skinButton(claim, "Gold")
	end

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

return SettingsPanel
