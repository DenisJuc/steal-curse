-- First-run tutorial (GDD 15.1 onboarding), in the style of the big RNG games: each step points
-- an arrow at one thing and waits until the player has actually done it (press ROLL, turn on
-- Auto Roll, open the Backpack, Equip Best, open Pedestals, buy an upgrade), then a few short
-- tips with a Next button. Shown while the "Hints" setting is On. It only covers what a new player
-- has (ROLL, Auto Roll, Backpack, Upgrades): steps for a feature still locked by the roll-only start
-- (Gate = a HudUnlocks gate) wait until that feature unlocks at its milestone, then show once
-- right after its unlock banner. Finishing sets Hints to "Unlocks" (those later tips still come);
-- Skip sets it Off (only the banners). Turning it back On in Settings replays it. New players
-- start with Auto Roll off (DataTemplate), so the first rolls are theirs.

--
-- Layout: the bubble grows to fit its text (never cut off). Steps with Clear = "RollReel" sit
-- above the roll reel so the first rolls' results stay visible. Spirit Sight's unlock starts a
-- short sealing tutorial (see, find, hold to bind); before that, a player's first walk into the
-- wild gets one tip: no hunting yet, look for Lost Ones and offering boxes meanwhile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local Ambience = require(script.Parent.Parent.Effects.Ambience)
local SpiritSight = require(script.Parent.Parent.Effects.SpiritSight)
local Settings = require(script.Parent.Parent.Settings)
local HudUnlocks = require(script.Parent.HudUnlocks)
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
	-- HudUnlocks gate: shown only once this feature is unlocked (at its unlock, or in a replay).
	Gate: string?,
	-- A descendant name the bubble must stay clear of (placed above it), e.g. the roll reel.
	Clear: string?,
	-- Shown only when Trigger fires (never in the main run), e.g. "WildEntry".
	Trigger: string?,
}

local STEP_SECONDS = 9
local GAP = 16
local ROLLS_TO_LEARN = 3
local BUBBLE_WIDTH = 320
local BUBBLE_MIN_HEIGHT = 104
-- Padding (10 top + 10 bottom) plus the Next/Skip row under the text.
local BUBBLE_CHROME = 20 + 34
local TEXT_SIZE = 18
-- Wild weight (Ambience) that counts as being out in the wild.
local WILD_AT = 0.6

-- The main screen, for Done checks that look at the HUD (set by Start).
local screenRef: ScreenGui? = nil
-- Set when a bind finished since the step started (BindResult).
local sealed = false

local function hudShown(name: string): boolean
	local screen = screenRef
	local object = screen and screen:FindFirstChild(name, true)
	while object and object ~= screen do
		if object:IsA("GuiObject") and not object.Visible then
			return false
		end
		object = object.Parent
	end
	return object ~= nil
end

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
		Clear = "RollReel",
		Text = "Tap ROLL to seal your first cursed relic!",
		Done = function(player)
			return number(player, "TotalScans") >= startScans + 1
		end,
	},
	{
		Target = "RollButton",
		Side = "Above",
		Clear = "RollReel",
		Text = `Nice! Roll {ROLLS_TO_LEARN - 1} more times. The bar at the top shows what opens next.`,
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
		Gate = "Pedestals",
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
		Gate = "Pedestals",
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
		Gate = "Gifts",
		Side = "Left",
		Text = "Free gifts unlock while you play, even when you're AFK. Claim them here.",
	},
	{
		Target = "CodexButton",
		Gate = "Codex",
		Side = "Right",
		Text = "The Codex tracks every relic you find. Milestones give permanent Luck and income.",
	},
	{
		Target = "CollectionButton",
		Gate = "Codex",
		Side = "Right",
		Text = "Fusion: collect 3 copies of one relic, open Collection, tap it, and Fuse.",
		Skip = BalanceTrials.coreLoopPresentation(),
	},
	-- Sealing tutorial: plays when Spirit Sight unlocks (see, find, hold to bind, done).
	{
		Target = "SpiritSight",
		Gate = "Hunt",
		Side = "Left",
		Text = "You can seal curses now! Go out into the wild and turn on Spirit Sight to see them.",
		Done = function()
			return SpiritSight.IsEnabled()
		end,
	},
	{
		Target = "Pulse",
		Gate = "Hunt",
		Side = "Left",
		Text = "Pulse to sense the curses around you, then walk up to a glowing signal.",
		Done = function()
			return hudShown("Bind")
		end,
		Fallback = { Target = "SpiritSight", Side = "Left", Text = "Turn Spirit Sight back on to keep sealing." },
	},
	{
		Target = "Bind",
		Gate = "Hunt",
		Side = "Left",
		Text = "Hold Bind to seal it. Keep holding until the chains close!",
		Done = function()
			return sealed
		end,
		Fallback = { Target = "Pulse", Side = "Left", Text = "Get close to a signal: the Bind button appears." },
	},
	{
		Target = "SpiritSight",
		Gate = "Hunt",
		Side = "Left",
		Text = "Sealed! Every seal gives that relic plus bonus finds. Leave Sight to go back to your shrine.",
	},
	-- First walk into the wild before Spirit Sight: no hunting yet, but there is plenty to find.
	{
		Target = "NextUnlockChip",
		Trigger = "WildEntry",
		Side = "Below",
		Text = "The spirits here stay hidden until Spirit Sight unlocks. For now, follow the Lost Ones and listen for chiming offering boxes!",
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
	screenRef = screen
	local activeSteps: { Step } = {}
	-- Steps for features unlocked from here on wait their turn (one tip at a time).
	local waitingTips: { Step } = {}
	local function mainSteps(): { Step }
		local list = {}
		for _, step in STEPS do
			if not step.Skip and not step.Trigger and (not step.Gate or HudUnlocks.IsUnlocked(step.Gate)) then
				table.insert(list, step)
			end
		end
		return list
	end
	activeSteps = mainSteps()

	local bubble = UIKit.create("Frame", {
		Name = "HintBubble",
		Size = UDim2.fromOffset(BUBBLE_WIDTH, BUBBLE_MIN_HEIGHT),
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
		TextSize = TEXT_SIZE,
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
	local bindResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BindResult") :: RemoteEvent
	bindResult.OnClientEvent:Connect(function(result)
		if type(result) == "table" and result.Ok then
			sealed = true
		end
	end)

	-- Grow the bubble to its text so long tips are never cut off (offsets are pre-UIScale, like
	-- the bubble's own size, so the scaler keeps them in step).
	local fittedText = ""
	local function setText(text: string)
		if text == fittedText then
			return
		end
		fittedText = text
		textLabel.Text = text
		local bounds = TextService:GetTextSize(text, TEXT_SIZE, textLabel.Font, Vector2.new(BUBBLE_WIDTH - 20, 1000))
		bubble.Size = UDim2.fromOffset(BUBBLE_WIDTH, math.max(BUBBLE_MIN_HEIGHT, math.ceil(bounds.Y) + BUBBLE_CHROME + 4))
	end

	local index = 0
	local token = 0
	local running = false

	local startTips: () -> ()
	-- Done with the steps: the tutorial leaves unlock tips on; tips just wait for the next unlock.
	local function finish()
		running = false
		token += 1
		bubble.Visible = false
		player:SetAttribute("TutorialTarget", nil)
		if Settings.Get("Hints") == "On" then
			Settings.Set("Hints", "Unlocks")
		end
		task.defer(startTips)
	end
	-- Skip: no more tutorial or tips (the unlock banners still play).
	local function skip()
		table.clear(waitingTips)
		finish()
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
	}, skip)
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
		sealed = false
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
		-- Which features are still locked decides the steps: wait until HudUnlocks knows.
		local waited = 0
		while not HudUnlocks.IsReady() and waited < 20 do
			waited += task.wait(0.25)
		end
		if not running then
			return
		end
		activeSteps = mainSteps()
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
		setText(text)
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
		-- Stay above a frame the player must see (the roll reel shows what each roll found).
		local clear = step.Clear and target == find(step.Target) and screen:FindFirstChild(step.Clear, true)
		if side == "Above" and clear and clear:IsA("GuiObject") then
			point = Vector2.new(point.X, math.min(point.Y, clear.AbsolutePosition.Y - (GAP + 22)))
		end
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

	-- Unlock tips: shown one feature at a time, after the main tutorial, only while Hints is not Off.
	function startTips()
		if running or #waitingTips == 0 or Settings.Get("Hints") == "Off" then
			return
		end
		running = true
		activeSteps = table.clone(waitingTips)
		table.clear(waitingTips)
		showStep(1)
	end
	HudUnlocks.Unlocked:Connect(function(gateId: string, announced: boolean)
		-- Join-time and "everything unlocked" opens are silent: veterans get no tips.
		if not announced or Settings.Get("Hints") == "Off" then
			return
		end
		for _, step in STEPS do
			if step.Gate == gateId and not step.Skip then
				table.insert(waitingTips, step)
			end
		end
		-- After the unlock banner has had its moment; during the tutorial they follow its last step.
		task.delay(2.5, startTips)
	end)

	-- Event tips (Trigger): they matter now, so they cut in front of the step showing, which
	-- comes back once the tip is read.
	local triggered: { [string]: boolean } = {}
	local function fire(trigger: string)
		if triggered[trigger] or Settings.Get("Hints") == "Off" then
			return
		end
		triggered[trigger] = true
		local tips = {}
		for _, step in STEPS do
			if step.Trigger == trigger then
				table.insert(tips, step)
			end
		end
		if running and activeSteps[index] then
			for offset, step in tips do
				table.insert(activeSteps, index + offset - 1, step)
			end
			showStep(index)
		else
			for _, step in tips do
				table.insert(waitingTips, step)
			end
			startTips()
		end
	end
	-- First walk into the wild while Spirit Sight is still locked (once a session).
	task.spawn(function()
		while not triggered.WildEntry do
			task.wait(1)
			if HudUnlocks.IsReady() and not HudUnlocks.IsUnlocked("Hunt") and Ambience.WildWeight() >= WILD_AT then
				fire("WildEntry")
			elseif HudUnlocks.IsReady() and HudUnlocks.IsUnlocked("Hunt") then
				-- Spirit Sight is open: the sealing tutorial covers the wild from here.
				break
			end
		end
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
			elseif value == "Off" and running then
				running = false
				bubble.Visible = false
			end
		end)
	end)
end

return Onboarding
