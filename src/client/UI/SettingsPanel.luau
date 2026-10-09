-- Settings menu (GDD 12.1): effects quality, reveals, camera effects, sound volume, interface size,
-- Welcome Back summary and beginner hints (ClientSettings, saved by the server). Option settings
-- are buttons that cycle to the next option; range settings (sound volume) are sliders that can be
-- dragged, or moved with the -/+ buttons (gamepad).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClientSettings = require(ReplicatedStorage.Shared.ClientSettings)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local UIKit = require(script.Parent.UIKit)

local SettingsPanel = {}

local ROW_HEIGHT = 58
local CYCLE_WIDTH = 118
local SLIDER_WIDTH = 250

function SettingsPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "SettingsMenu", "SETTINGS", colors.Accent, Vector2.new(520, 600))
	local list = UIKit.scrollList(content, 6)

	local function row(order: number, label: string, help: string, controlWidth: number): Frame
		local frame = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, { UIKit.corner(10), UIKit.padding(8) })
		UIKit.label({
			Text = label,
			TextSize = 16,
			Size = UDim2.new(1, -controlWidth - 12, 0, 20),
			Parent = frame,
		})
		UIKit.label({
			Text = help,
			TextSize = 12,
			TextColor3 = colors.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 21),
			Size = UDim2.new(1, -controlWidth - 12, 1, -21),
			Parent = frame,
		})
		return frame
	end

	local function cycleControl(frame: Frame, setting: ClientSettings.Setting)
		local button = UIKit.button({
			TextSize = 16,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(CYCLE_WIDTH, 38),
			Parent = frame,
		}, function()
			local nextValue = ClientSettings.nextOption(setting.Key, Settings.Get(setting.Key))
			if nextValue ~= nil then
				Settings.Set(setting.Key, nextValue)
			end
		end)
		Settings.Watch(setting.Key, function(value)
			button.Text = ClientSettings.display(setting.Key, value)
			button.BackgroundColor3 = if value == setting.Default then colors.Accent else colors.Card
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
			UIKit.button({
				Text = text,
				TextSize = 18,
				BackgroundColor3 = colors.Panel,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, x, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				Parent = holder,
			}, function()
				local value = ClientSettings.nudge(setting.Key, Settings.Get(setting.Key), steps * 2)
				if value ~= nil then
					Settings.Set(setting.Key, value)
					Sounds.Play("Click")
				end
			end)
		end
		nudgeButton("-", 0, -1)
		nudgeButton("+", SLIDER_WIDTH - 82, 1)
		local valueLabel = UIKit.label({
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(46, 20),
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
			BackgroundColor3 = colors.Text,
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
		if setting.Range then
			sliderControl(row(order, setting.Label, setting.Help, SLIDER_WIDTH), setting)
		else
			cycleControl(row(order, setting.Label, setting.Help, CYCLE_WIDTH), setting)
		end
	end

	return {
		Toggle = function()
			panel.Visible = not panel.Visible
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return SettingsPanel
