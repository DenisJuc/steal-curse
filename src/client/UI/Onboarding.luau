-- First-run tutorial (GDD 15.1 onboarding), in the style of the big RNG games: each step points
-- an arrow at one thing and waits until the player has actually done it (press ROLL, turn on
-- Auto Roll, open the Backpack, Equip Best, open Pedestals, buy an upgrade), then a few short
-- tips with a Next button. Shown while the "Hints" setting is On; finishing or skipping turns it
-- Off (saved), and turning it back On in Settings replays it. New players start with Auto Roll
-- off (DataTemplate), so the first rolls are theirs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local Settings = require(script.Parent.Parent.Settings)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local Onboarding = {}

type Side = "Right" | "Below" | "Above" | "Left"
-- Target: a descendant name under the screen, or "Menu/Name" for a name inside that menu.
-- Done: polled while the step shows; nil means the step waits for Next (or STEP_SECONDS).
-- Fallback: shown instead while Target is hidden (e.g. its menu is closed).
type Step = {
	Target: string,
	Side: Side,
	Text: string,
	Done: ((Player) -> boolean)?,
	Fallback: { Target: string, Side: Side, Text: string }?,
	Skip: boolean?,
}

local STEP_SECONDS = 9
local GAP = 16
local ROLLS_TO_LEARN = 3

local function number(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- Values captured when a step starts, for steps that wait for a change.
local startScans = 0
-- Set when CE goes down (something was bought) since the step started.
local spent = false

local STEPS: { Step } = {
	{
		Target = "RollButton",
		Side = "Above",
		Text = "Tap ROLL to seal your first cursed relic!",
		Done = function(player)
			return number(player, "TotalScans") >= startScans + 1
		end,
	},
	{
		Target = "RollButton",
		Side = "Above",
		Text = `Nice! Roll {ROLLS_TO_LEARN - 1} more times. Rarer relics are worth far more.`,
		Done = function(player)
			return number(player, "TotalScans") >= ROLLS_TO_LEARN
		end,
	},
	{
		Target = "AutoRoll",
		-- Beside the switch: above it would cover the ROLL button, to the right the Upgrades button.
		Side = "Left",
		Text = "Now let it roll for you: turn on Auto Roll.",
		Done = function(player)
			return player:GetAttribute("AutoRoll") ~= false
		end,
	},
	{
		Target = "BackpackButton",
		Side = "Above",
		Text = "Your finds fill empty pedestals and earn CE. Open your Backpack to see them all.",
		Done = function(player)
			local ui = player:FindFirstChildOfClass("PlayerGui")
			local menu = ui and ui:FindFirstChild("RelicsMenu", true)
			return menu ~= nil and (menu :: GuiObject).Visible
		end,
	},
	{
		Target = "RelicsMenu/EquipBest",
		Side = "Above",
		Text = "Equip Best swaps your best relics onto your pedestals. Use it after a great find.",
		Fallback = { Target = "BackpackButton", Side = "Above", Text = "Open your Backpack and press Equip Best." },
	},
	{
		Target = "ShrineButton",
		Side = "Right",
		Text = "Your relics earn Cursed Energy (CE). Open Pedestals to spend it.",
		Done = function(player)
			local ui = player:FindFirstChildOfClass("PlayerGui")
			local menu = ui and ui:FindFirstChild("ShrineMenu", true)
			return menu ~= nil and (menu :: GuiObject).Visible
		end,
	},
	{
		Target = "ShrineMenu/Upgrade",
		Side = "Below",
		Text = "Upgrade a pedestal: it earns more CE every second. Save up if you can't afford it yet.",
		Done = function()
			return spent
		end,
		Fallback = { Target = "ShrineButton", Side = "Right", Text = "When you have enough CE, open Pedestals and upgrade one." },
	},
	{
		Target = "UpgradesButton",
		Side = "Above",
		Text = "Upgrades is your skill tree. Core Luck finds rarer relics: tap a node, then buy.",
		Done = function(player)
			local ui = player:FindFirstChildOfClass("PlayerGui")
			local menu = ui and ui:FindFirstChild("SkillsMenu", true)
			return menu ~= nil and (menu :: GuiObject).Visible
		end,
	},
	{
		Target = "GiftButton",
		Side = "Left",
		Text = "Free gifts unlock while you play, even when you're AFK. Claim them here.",
	},
	{
		Target = "CodexButton",
		Side = "Right",
		Text = "The Codex tracks every relic you find. Milestones give permanent Luck and income.",
	},
	{
		Target = "CollectionButton",
		Side = "Right",
		Text = "Fusion: collect 3 copies of one relic, open Collection, tap it, and Fuse.",
		Skip = BalanceTrials.coreLoopPresentation(),
	},
	{
		Target = "SpiritSight",
		Side = "Left",
		Text = "Spirit Sight lets you hunt your own signals in the wild. Each bind gives a relic plus bonus finds.",
	},
}

local ANCHORS: { [Side]: Vector2 } = {
	Right = Vector2.new(0, 0.5),
	Below = Vector2.new(0.5, 0),
	Above = Vector2.new(0.5, 1),
	Left = Vector2.new(1, 0.5),
}
-- Arrow glyph and where it sits on the bubble, pointing back at the target.
local ARROWS: { [Side]: { Text: string, Anchor: Vector2, Position: UDim2 } } = {
	Above = { Text = "▼", Anchor = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2) },
	Below = { Text = "▲", Anchor = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2) },
	Right = { Text = "◀", Anchor = Vector2.new(1, 0.5), Position = UDim2.new(0, -2, 0.5, 0) },
	Left = { Text = "▶", Anchor = Vector2.new(0, 0.5), Position = UDim2.new(1, 2, 0.5, 0) },
}

function Onboarding.Start(screen: ScreenGui)
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local activeSteps = {}
	for _, step in STEPS do
		if not step.Skip then
			table.insert(activeSteps, step)
		end
	end

	local bubble = UIKit.create("Frame", {
		Name = "HintBubble",
		Size = UDim2.fromOffset(320, 104),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = 25,
		Parent = screen,
	}, { UIKit.corner(12), UIKit.padding(10), UIKit.stroke(colors.Gold, 2, 0) })
	UIKit.skinPanel(bubble, colors.Gold)
	UIKit.scaler(bubble)
	-- One guidance voice: the HUD's NEXT card steps aside while a tutorial bubble shows.
	bubble:GetPropertyChangedSignal("Visible"):Connect(function()
		Players.LocalPlayer:SetAttribute("TutorialShowing", bubble.Visible)
	end)
	local infoIcon = Icons.image(bubble, "Info", 30)
	if infoIcon then
		infoIcon.Position = UDim2.fromOffset(-24, -24)
		infoIcon.ZIndex = 27
	end
	local textLabel = UIKit.label({
		TextSize = 18,
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
	local arrow = UIKit.label({
		Name = "Arrow",
		Text = "▼",
		TextSize = 34,
		TextColor3 = colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		Size = UDim2.fromOffset(36, 36),
		ZIndex = 27,
		Parent = bubble,
	})

	local lastCE = number(player, "CE")
	player:GetAttributeChangedSignal("CE"):Connect(function()
		local ce = number(player, "CE")
		if ce < lastCE - 0.5 then
			spent = true
		end
		lastCE = ce
	end)

	local index = 0
	local token = 0
	local running = false

	local function finish()
		running = false
		token += 1
		bubble.Visible = false
		Settings.Set("Hints", "Off")
	end

	local nextButton = UIKit.button({
		Text = "Next",
		TextSize = 15,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -35, 1, -14),
		Size = UDim2.fromOffset(70, 28),
		ZIndex = 26,
		Parent = bubble,
	})
	UIKit.skinButton(nextButton, "Gold")
	local skipButton = UIKit.button({
		Text = "Skip",
		TextSize = 13,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -35, 1, -14),
		Size = UDim2.fromOffset(64, 28),
		ZIndex = 26,
		Parent = bubble,
	}, finish)
	UIKit.skinButton(skipButton, "Dark")

	local showStep: (number) -> ()
	function showStep(stepIndex: number)
		if stepIndex > #activeSteps then
			finish()
			return
		end
		index = stepIndex
		token += 1
		local myToken = token
		local step = activeSteps[stepIndex]
		spent = false
		startScans = number(player, "TotalScans")
		stepLabel.Text = `{stepIndex}/{#activeSteps}`
		-- Action steps wait for the action (Skip leaves the tutorial); tips have Next.
		nextButton.Visible = step.Done == nil
		skipButton.Position = if step.Done then UDim2.new(1, -35, 1, -14) else UDim2.new(1, -112, 1, -14)
		Motion.shine(bubble, 0.6)
		if step.Done == nil then
			task.delay(STEP_SECONDS, function()
				if running and token == myToken then
					showStep(stepIndex + 1)
				end
			end)
		end
	end
	nextButton.Activated:Connect(function()
		showStep(index + 1)
	end)

	local function begin()
		if running then
			return
		end
		running = true
		-- Returning to the tips skips action steps the player has already done.
		local first = 1
		while first <= #activeSteps and activeSteps[first].Done and (activeSteps[first].Done :: any)(player) do
			first += 1
		end
		showStep(first)
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

	local function find(path: string): GuiObject?
		local menuName, name = string.match(path, "^(.-)/(.+)$")
		local root: Instance? = screen
		if menuName then
			root = screen:FindFirstChild(menuName, true)
		end
		local target = root and root:FindFirstChild(name or path, true)
		return if target and target:IsA("GuiObject") and shown(target) then target else nil
	end

	-- While a menu is open only hints pointing inside it show; anything else would cover it.
	local function menuOpen(): boolean
		for _, child in screen:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and child:GetAttribute("Modal") then
				return true
			end
		end
		return false
	end

	local checkElapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		if not running then
			return
		end
		local step = activeSteps[index]
		if not step then
			return
		end
		checkElapsed += dt
		if step.Done and checkElapsed >= 0.2 then
			checkElapsed = 0
			if step.Done(player) then
				Motion.pop(bubble, 0, 0.3)
				showStep(index + 1)
				return
			end
		end
		-- HudUnlocks shows a still-locked HUD entry as soon as the tutorial points at it.
		if player:GetAttribute("TutorialTarget") ~= step.Target then
			player:SetAttribute("TutorialTarget", step.Target)
		end
		local target = find(step.Target)
		local side, text = step.Side, step.Text
		if not target and step.Fallback then
			target = find(step.Fallback.Target)
			side, text = step.Fallback.Side, step.Fallback.Text
		end
		local inMenu = string.find(step.Target, "/", 1, true) ~= nil and target ~= nil and find(step.Target) ~= nil
		if not target or (menuOpen() and not inMenu) then
			bubble.Visible = false
			return
		end
		textLabel.Text = text
		bubble.AnchorPoint = ANCHORS[side]
		local shape = ARROWS[side]
		arrow.Text = shape.Text
		arrow.AnchorPoint = shape.Anchor
		-- The arrow bobs toward the target.
		local bob = math.sin(os.clock() * 6) * 5
		local push = if side == "Above" then UDim2.fromOffset(0, bob)
			elseif side == "Below" then UDim2.fromOffset(0, -bob)
			elseif side == "Right" then UDim2.fromOffset(-bob, 0)
			else UDim2.fromOffset(bob, 0)
		arrow.Position = shape.Position + push
		local position, size = target.AbsolutePosition, target.AbsoluteSize
		local gap = GAP + 22
		local point = if side == "Right"
			then Vector2.new(position.X + size.X + gap, position.Y + size.Y / 2)
			elseif side == "Below" then Vector2.new(position.X + size.X / 2, position.Y + size.Y + gap)
			elseif side == "Above" then Vector2.new(position.X + size.X / 2, position.Y - gap)
			else Vector2.new(position.X - gap, position.Y + size.Y / 2)
		-- Keep the whole bubble on screen (a target near an edge would push it off).
		local bubbleSize = bubble.AbsoluteSize
		local screenSize = screen.AbsoluteSize
		local anchor = bubble.AnchorPoint
		local left = point.X - anchor.X * bubbleSize.X
		local top = point.Y - anchor.Y * bubbleSize.Y
		local shiftX = math.clamp(left, 8, math.max(8, screenSize.X - bubbleSize.X - 8)) - left
		local shiftY = math.clamp(top, 8, math.max(8, screenSize.Y - bubbleSize.Y - 8)) - top
		bubble.Position = UDim2.fromOffset(point.X + shiftX, point.Y + shiftY)
		-- The arrow stays level with the target when the bubble had to slide.
		arrow.Position -= UDim2.fromOffset(shiftX, shiftY)
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
