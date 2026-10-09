-- First-minute hints (GDD 15.1 onboarding): a short sequence of tips, each pointing at the HUD
-- element it explains. Shown while the "Hints" setting is On; finishing or skipping turns it Off
-- (saved), and turning it back On in Settings replays the tips.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local Onboarding = {}

type Side = "Right" | "Below" | "Left"
type Step = { Target: string, Side: Side, Text: string }

local STEP_SECONDS = 9
local GAP = 12

local STEPS: { Step } = {
	{
		Target = "ResonatorPanel",
		Side = "Right",
		Text = "Your Spirit Resonator scans for relics on its own, every few seconds. No clicking needed!",
	},
	{
		Target = "DiscoveryFeed",
		Side = "Below",
		Text = "Every find shows up here. Rare ones get a big reveal, and rare finds are saved in your Journal.",
	},
	{
		Target = "ShrineButton",
		Side = "Right",
		Text = "Relics on your shrine pedestals earn Cursed Energy (CE). Buy and upgrade pedestals here.",
	},
	{
		Target = "RelicsButton",
		Side = "Right",
		Text = "Open Relics and press Equip Best to put your best finds on the pedestals. Sell, lock and Auto-Sell live here too.",
	},
	{
		Target = "CodexButton",
		Side = "Right",
		Text = "The Codex records every relic you discover. Milestones give permanent Luck and income.",
	},
	{
		Target = "SpiritSight",
		Side = "Left",
		Text = "Spirit Sight lets you hunt your own signals. Each bind gives a relic plus bonus discoveries.",
	},
}

local ANCHORS: { [Side]: Vector2 } = {
	Right = Vector2.new(0, 0.5),
	Below = Vector2.new(0.5, 0),
	Left = Vector2.new(1, 0.5),
}

function Onboarding.Start(screen: ScreenGui)
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local bubble = UIKit.create("Frame", {
		Name = "HintBubble",
		Size = UDim2.fromOffset(300, 112),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = 25,
		Parent = screen,
	}, { UIKit.corner(12), UIKit.padding(10), UIKit.stroke(colors.Gold, 2, 0) })
	UIKit.scaler(bubble)
	local textLabel = UIKit.label({
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 1, -34),
		ZIndex = 26,
		Parent = bubble,
	})
	local stepLabel = UIKit.label({
		TextSize = 12,
		TextColor3 = colors.SubText,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(60, 28),
		ZIndex = 26,
		Parent = bubble,
	})

	local index = 0
	local token = 0
	local running = false

	local function finish()
		running = false
		token += 1
		bubble.Visible = false
		Settings.Set("Hints", "Off")
	end

	local showStep: (number) -> ()
	function showStep(stepIndex: number)
		if stepIndex > #STEPS then
			finish()
			return
		end
		index = stepIndex
		token += 1
		local myToken = token
		textLabel.Text = STEPS[stepIndex].Text
		stepLabel.Text = `Tip {stepIndex}/{#STEPS}`
		bubble.AnchorPoint = ANCHORS[STEPS[stepIndex].Side]
		task.delay(STEP_SECONDS, function()
			if running and token == myToken then
				showStep(stepIndex + 1)
			end
		end)
	end

	UIKit.button({
		Text = "Next",
		TextSize = 14,
		BackgroundColor3 = colors.Gold,
		TextColor3 = colors.Panel,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(70, 28),
		ZIndex = 26,
		Parent = bubble,
	}, function()
		showStep(index + 1)
	end)
	UIKit.button({
		Text = "Skip tips",
		TextSize = 13,
		BackgroundColor3 = colors.Card,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -78, 1, 0),
		Size = UDim2.fromOffset(80, 28),
		ZIndex = 26,
		Parent = bubble,
	}, finish)

	local function begin()
		if running then
			return
		end
		running = true
		showStep(1)
	end

	local function shown(object: Instance): boolean
		local current: Instance? = object
		while current and current ~= screen do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			current = current.Parent
		end
		return current == screen
	end

	-- Follow the target every frame (layouts move with screen size and UI scale).
	RunService.RenderStepped:Connect(function()
		if not running then
			return
		end
		local step = STEPS[index]
		local target = step and screen:FindFirstChild(step.Target, true)
		if not target or not target:IsA("GuiObject") or not shown(target) then
			bubble.Visible = false
			return
		end
		local position, size = target.AbsolutePosition, target.AbsoluteSize
		local point = if step.Side == "Right"
			then Vector2.new(position.X + size.X + GAP, position.Y + size.Y / 2)
			elseif step.Side == "Below" then Vector2.new(position.X + size.X / 2, position.Y + size.Y + GAP)
			else Vector2.new(position.X - GAP, position.Y + size.Y / 2)
		bubble.Position = UDim2.fromOffset(point.X, point.Y)
		bubble.Visible = true
	end)

	-- Wait for the saved value before deciding, so returning players never see a flash of tips.
	task.spawn(function()
		local waited = 0
		while player:GetAttribute("Setting_Hints") == nil and waited < 20 do
			waited += task.wait(0.5)
		end
		Settings.Watch("Hints", function(value)
			if value == "On" then
				begin()
			elseif running then
				running = false
				bubble.Visible = false
			end
		end)
	end)
end

return Onboarding
