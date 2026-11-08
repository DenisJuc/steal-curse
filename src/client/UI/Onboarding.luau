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
-- Layout: the bubble grows to fit its text (never cut off). The first roll steps sit right above
-- ROLL and lift the roll reel above the bubble (screen attribute "ReelLift"), so each roll's result
-- stays visible. World steps (collect coins, go to the wild, find a spirit) put the bubble at the
-- top and lay glowing arrows on the ground (Effects/GroundGuide). Before Spirit Sight, a player's
-- first walk into the wild gets one tip: no hunting yet, look for Lost Ones and offering boxes.
--
-- Spirit hunt tutorial: when Spirit Sight unlocks (at its milestone, not on join) everything stops
-- for it: menus close, the HUD except travel and the hunt buttons is hidden (rolling carries on in
-- the background) and it walks through: go to the wild (ground arrows), fast travel exists, F for
-- Spirit Sight, Q to pulse, arrows to the nearest spirit, hold to bind. It plays even with Hints
-- off; Skip ends just this tutorial. Whatever tutorial was showing comes back afterwards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local ZoneGates = require(ReplicatedStorage.Shared.ZoneGates)
local Ambience = require(script.Parent.Parent.Effects.Ambience)
local GroundGuide = require(script.Parent.Parent.Effects.GroundGuide)
local SpiritSight = require(script.Parent.Parent.Effects.SpiritSight)
local HuntController = require(script.Parent.Parent.Hunt.HuntController)
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
	-- A function is re-read every frame (e.g. a live countdown).
	Text: string | (Player) -> string,
	Done: ((Player) -> boolean)?,
	Fallback: { Target: string, Side: Side, Text: string }?,
	Skip: boolean?,
	-- HudUnlocks gate: shown only once this feature is unlocked (at its unlock, or in a replay).
	Gate: string?,
	-- A descendant name the bubble must stay clear of: placed above it for Side Above (e.g. the
	-- roll reel), left of it for Side Left (e.g. the Backpack button beside Auto Roll).
	Clear: string?,
	-- Shown only when Trigger fires (never in the main run), e.g. "WildEntry".
	Trigger: string?,
	-- Bubble right above its target, with the roll reel lifted above the bubble.
	LiftReel: boolean?,
	-- Done when the target button is pressed (see `pressed`).
	Press: boolean?,
	-- Ground arrows lead to this spot while the step shows (nil from the getter hides them).
	Guide: (() -> Vector3?)?,
	-- Part of the spirit hunt tutorial (only runs when Spirit Sight unlocks).
	Hunt: boolean?,
}

local STEP_SECONDS = 9
local GAP = 16
local ROLLS_TO_LEARN = 3
local BUBBLE_WIDTH = 320
-- One line of text plus the Next/Skip row; longer tips grow (setText).
local BUBBLE_MIN_HEIGHT = 72
-- Padding (10 top + 10 bottom) plus the Next/Skip row under the text.
local BUBBLE_CHROME = 20 + 34
local TEXT_SIZE = 18
-- Wild weight (Ambience) that counts as being out in the wild.
local WILD_AT = 0.6

-- Invisible anchor at the top center: world steps point their bubble down from here.
local TOP = "TutorialTopAnchor"
local ZONE_CONTEXT: ZoneGates.Context = {
	Areas = Config.Areas,
	World = Config.World,
	Bands = Config.HuntStreak,
	Gates = Config.ZoneGates,
}

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
local startCE = 0
local stepClock = 0
-- Set when the step's target button (Press steps) was pressed since the step started.
local pressed = false

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function inWild(): boolean
	local position = rootPosition()
	return position ~= nil and WorldLayout.inWild(Config.World, position.X, position.Z)
end

local function menuShown(name: string): boolean
	local ui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local menu = ui and ui:FindFirstChild(name, true)
	return menu ~= nil and menu:IsA("GuiObject") and menu.Visible
end

-- The collect pad to walk to: one of your pedestals with coins waiting (brightest glow), nearest.
local function collectPad(): Vector3?
	local position = rootPosition()
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not position or not plots then
		return nil
	end
	local best: Vector3?, bestScore = nil, math.huge
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") ~= Players.LocalPlayer.UserId then
			continue
		end
		local folder = plot:FindFirstChild("Pedestals")
		if not folder then
			continue
		end
		for _, pedestal in folder:GetChildren() do
			local pad = pedestal:FindFirstChild("CollectPad")
			local glow = pedestal:FindFirstChild("CollectGlow")
			local trigger = pedestal:FindFirstChild("CollectTrigger")
			if not (pad and pad:IsA("BasePart") and pad.Transparency < 1 and trigger and trigger:IsA("BasePart")) then
				continue
			end
			-- Ready pads glow brighter (lower transparency): prefer those, then the nearest.
			local glowT = if glow and glow:IsA("BasePart") then glow.Transparency else 1
			local score = glowT * 1000 + (trigger.Position - position).Magnitude
			if score < bestScore then
				best, bestScore = trigger.Position, score
			end
		end
	end
	return best
end

-- Nearest open wild spot (zone gates respected), refreshed once a second.
local wildCache: Vector3? = nil
local wildCachedAt = 0
local function wildSpot(): Vector3?
	if wildCache and os.clock() - wildCachedAt < 1 then
		return wildCache
	end
	local position = rootPosition()
	if not position then
		return nil
	end
	-- Through the street's wild gate (walking straight out would run into the plot's back wall).
	local x, z = WorldLayout.streetGate(Config.Plots, Config.World, Config.Travel.WildDepth)
	local luck = Players.LocalPlayer:GetAttribute("GateLuck")
	x, z = ZoneGates.nearestAllowed(ZONE_CONTEXT, if type(luck) == "number" then luck else 1, x, z, 8, true)
	wildCache, wildCachedAt = Vector3.new(x, position.Y, z), os.clock()
	return wildCache
end

local function nearestSpirit(): Vector3?
	local _, position = HuntController.GetNearestSignalAny()
	return position
end
-- Set when CE goes down (something was bought) since the step started.
local spent = false

local STEPS: { Step } = {
	{
		Target = "RollButton",
		Side = "Above",
		LiftReel = true,
		Text = "Tap ROLL to seal your first cursed relic!",
		Done = function(player)
			return number(player, "TotalScans") >= startScans + 1
		end,
	},
	{
		Target = "RollButton",
		Side = "Above",
		LiftReel = true,
		Text = function(player)
			local left = math.max(1, ROLLS_TO_LEARN - number(player, "TotalScans"))
			local rolls = if left == 1 then "1 more time" else `{left} more times`
			return `Nice! Roll {rolls}. The bar at the top shows what opens next.`
		end,
		Done = function(player)
			return number(player, "TotalScans") >= ROLLS_TO_LEARN
		end,
	},
	{
		Target = "AutoRoll",
		-- Beside the switch: above it would cover the ROLL button (covering Backpack is fine).
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
		Text = "Equip Best swaps your best relics onto your pedestals. Tap it now!",
		Press = true,
		Done = function()
			return pressed
		end,
		Fallback = { Target = "BackpackButton", Side = "Above", Text = "Open your Backpack and press Equip Best." },
	},
	{
		Target = "RelicsMenu/EquipBest",
		Side = "Above",
		Text = "Nice! Tap anywhere outside the menu to close it.",
		Done = function()
			return not menuShown("RelicsMenu")
		end,
	},
	{
		Target = TOP,
		Side = "Below",
		Text = "Your pedestals fill up with coins (CE). Follow the arrows and walk over the glowing pad to collect them!",
		Guide = collectPad,
		Done = function(player)
			return number(player, "CE") > startCE + 0.001
		end,
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
		Done = function()
			return menuShown("CodexMenu")
		end,
	},
	{
		Target = "CollectionButton",
		Gate = "Codex",
		Side = "Right",
		Text = "Fusion: collect 3 copies of one relic, open Collection, tap it, and Fuse.",
		Skip = BalanceTrials.coreLoopPresentation(),
	},
	-- First walk into the wild before Spirit Sight: no hunting yet, but there is plenty to find.
	{
		Target = "NextUnlockChip",
		Trigger = "WildEntry",
		Side = "Below",
		Text = "The spirits here stay hidden until Spirit Sight unlocks. For now, follow the Lost Ones and listen for chiming offering boxes!",
	},
}

-- Spirit hunt tutorial (see the header): plays once when Spirit Sight unlocks.
local HUNT_STEPS: { Step } = {
	{
		Hunt = true,
		Target = TOP,
		Side = "Below",
		Text = "Spirit Sight unlocked! You can hunt spirits now. Follow the arrows to the wild.",
		Guide = wildSpot,
		Done = function()
			return inWild()
		end,
	},
	{
		Hunt = true,
		Target = "TravelBar",
		Side = "Below",
		Text = "Tip: these buttons are fast travel. They take you Home, to the Hub, the Wild or a Shrine instantly.",
	},
	{
		Hunt = true,
		Target = "SpiritSight",
		Side = "Left",
		Text = "Press F to enter the spirit world.",
		Done = function()
			return SpiritSight.IsEnabled()
		end,
	},
	{
		Hunt = true,
		Target = "Pulse",
		Side = "Left",
		Text = "Press Q to pulse: it shows where the spirits are hiding.",
		Done = function()
			return HuntController.LastPulse() > stepClock
		end,
		Fallback = { Target = "SpiritSight", Side = "Left", Text = "Press F to go back into the spirit world." },
	},
	{
		Hunt = true,
		Target = TOP,
		Side = "Below",
		Text = function()
			return if SpiritSight.IsEnabled()
				then "Follow the arrows to the nearest spirit."
				else "Press F to go back into the spirit world, then follow the arrows."
		end,
		Guide = nearestSpirit,
		Done = function()
			return hudShown("Bind")
		end,
	},
	{
		Hunt = true,
		Target = "Bind",
		Side = "Left",
		Text = "Hold E (or the Bind button) to seal it. Keep holding until the chains close!",
		Guide = nearestSpirit,
		Done = function()
			return sealed
		end,
		Fallback = { Target = TOP, Side = "Below", Text = "Get closer to the spirit: the Bind button appears." },
	},
	{
		Hunt = true,
		Target = TOP,
		Side = "Below",
		Text = "Sealed! Every seal gives that relic plus bonus rolls. Press F to leave the spirit world.",
	},
}
-- Direct children of the main screen that stay up during the spirit hunt tutorial. Rolling goes
-- on in the background, so a rare find's reveal (card, band, glow, dim, flashes) must still show.
local HUNT_KEEP = {
	HintBubble = true,
	TravelBar = true,
	HuntButtons = true,
	[TOP] = true,
	RevealCard = true,
	RevealBand = true,
	RevealGlow = true,
	RevealDim = true,
	RevealFlash = true,
	RollDim = true,
	RollFlash = true,
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
			if
				not step.Skip
				and not step.Trigger
				and not step.Hunt
				and (not step.Gate or HudUnlocks.IsUnlocked(step.Gate))
			then
				table.insert(list, step)
			end
		end
		return list
	end
	activeSteps = mainSteps()

	UIKit.create("Frame", {
		Name = TOP,
		AnchorPoint = Vector2.new(0.5, 0),
		-- Below the unlock banner (top center) so the two never overlap.
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
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
	-- "main" (tutorial and unlock tips) or "hunt" (the spirit hunt tutorial).
	local mode = "main"
	local endHunt: () -> ()

	local startTips: () -> ()
	-- Done with the steps: the tutorial leaves unlock tips on; tips just wait for the next unlock.
	local function finish()
		running = false
		token += 1
		bubble.Visible = false
		screen:SetAttribute("ReelLift", nil)
		GroundGuide.SetTarget(nil)
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
	}, function()
		if mode == "hunt" then
			endHunt()
		else
			skip()
		end
	end)
	UIKit.skinButton(skipButton, "Dark")

	local showStep: (number) -> ()
	function showStep(stepIndex: number)
		if stepIndex > #activeSteps then
			if mode == "hunt" then
				endHunt()
			else
				finish()
			end
			return
		end
		index = stepIndex
		token += 1
		local myToken = token
		local step = activeSteps[stepIndex]
		spent = false
		sealed = false
		pressed = false
		startScans = number(player, "TotalScans")
		startCE = number(player, "CE")
		stepClock = os.clock()
		GroundGuide.SetTarget(step.Guide)
		if not step.LiftReel then
			screen:SetAttribute("ReelLift", nil)
		end
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

	local pressHooked: GuiButton? = nil
	local pressConnection: RBXScriptConnection? = nil
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
		local side, text = step.Side, (if type(step.Text) == "function" then (step.Text :: any)(player) else step.Text) :: string
		if not target and step.Fallback then
			target = find(step.Fallback.Target)
			side, text = step.Fallback.Side, step.Fallback.Text
		end
		local inMenu = string.find(step.Target, "/", 1, true) ~= nil and target ~= nil and find(step.Target) ~= nil
		-- A rare find's reveal has the screen: the tip waits behind it.
		local reveal = screen:FindFirstChild("RevealCard")
		local revealing = reveal ~= nil and reveal:IsA("GuiObject") and reveal.Visible
		if not target or revealing or (menuOpen() and not inMenu) then
			bubble.Visible = false
			screen:SetAttribute("ReelLift", nil)
			return
		end
		-- Press steps: listen to the target button itself (once per button instance).
		if step.Press and target:IsA("GuiButton") and pressHooked ~= target then
			pressHooked = target
			if pressConnection then
				pressConnection:Disconnect()
			end
			pressConnection = target.Activated:Connect(function()
				pressed = true
			end)
		end
		setText(text)
		bubble.AnchorPoint = ANCHORS[side]
		local shape = ARROWS[side]
		arrow.Text = shape.Text
		-- Top-anchored world steps point at nothing on screen: no arrow.
		arrow.Visible = target.Name ~= TOP
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
		elseif side == "Left" and clear and clear:IsA("GuiObject") then
			point = Vector2.new(math.min(point.X, clear.AbsolutePosition.X - GAP), point.Y)
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
		-- The arrow stays level with the target when the bubble had to slide. Its offsets are inside
		-- the bubble's UIScale, so screen pixels are divided by that scale.
		local scale = math.max(bubbleSize.X / BUBBLE_WIDTH, 0.01)
		arrow.Position -= UDim2.fromOffset(shiftX / scale, shiftY / scale)
		bubble.Visible = true
		-- Roll steps: lift the reel so its bottom clears the bubble's top.
		local reel = step.LiftReel and screen:FindFirstChild("RollReel")
		if reel and reel:IsA("GuiObject") then
			local current = screen:GetAttribute("ReelLift")
			local reelBottom = reel.AbsolutePosition.Y + reel.AbsoluteSize.Y + (if type(current) == "number" then current else 0)
			local bubbleTop = point.Y + shiftY - bubble.AnchorPoint.Y * bubbleSize.Y
			screen:SetAttribute("ReelLift", math.max(0, reelBottom - (bubbleTop - 6)))
		end
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
	-- Spirit hunt tutorial: hides everything but travel and the hunt buttons, and remembers what
	-- other code wanted visible meanwhile so it can be put back afterwards.
	local huntHidden: { [GuiObject]: boolean } = {}
	local huntConnections: { RBXScriptConnection } = {}
	local savedRun: { Steps: { Step }, Index: number, Running: boolean }? = nil
	local function startHunt()
		if mode == "hunt" then
			return
		end
		savedRun = { Steps = activeSteps, Index = index, Running = running }
		mode = "hunt"
		token += 1
		for _, child in screen:GetChildren() do
			if not child:IsA("GuiObject") or HUNT_KEEP[child.Name] then
				continue
			end
			local gui = child :: GuiObject
			-- Open menus close for good; the HUD comes back as it was.
			huntHidden[gui] = gui.Visible and not gui:GetAttribute("Modal")
			gui.Visible = false
			table.insert(
				huntConnections,
				gui:GetPropertyChangedSignal("Visible"):Connect(function()
					if mode == "hunt" and gui.Visible then
						huntHidden[gui] = not gui:GetAttribute("Modal")
						gui.Visible = false
					end
				end)
			)
		end
		running = true
		activeSteps = table.clone(HUNT_STEPS)
		showStep(1)
	end
	function endHunt()
		if mode ~= "hunt" then
			return
		end
		mode = "main"
		for _, connection in huntConnections do
			connection:Disconnect()
		end
		table.clear(huntConnections)
		for gui, visible in huntHidden do
			if gui.Parent then
				gui.Visible = visible
			end
		end
		table.clear(huntHidden)
		GroundGuide.SetTarget(nil)
		local saved = savedRun
		savedRun = nil
		if saved and saved.Running and saved.Steps[saved.Index] and not saved.Steps[saved.Index].Hunt then
			activeSteps = saved.Steps
			showStep(saved.Index)
		else
			running = false
			token += 1
			bubble.Visible = false
			player:SetAttribute("TutorialTarget", nil)
			task.defer(startTips)
		end
	end

	HudUnlocks.Unlocked:Connect(function(gateId: string, announced: boolean)
		-- Spirit Sight's own unlock stops everything for the hunt tutorial (even with Hints off).
		if gateId == "Hunt" and announced then
			task.delay(2.5, startHunt)
			return
		end
		-- Join-time and "everything unlocked" opens are silent: veterans get no tips.
		if not announced or Settings.Get("Hints") == "Off" then
			return
		end
		for _, step in STEPS do
			if step.Gate == gateId and not step.Skip and not step.Hunt then
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
			elseif value == "Off" and running and mode ~= "hunt" then
				running = false
				bubble.Visible = false
			end
		end)
	end)
end

return Onboarding
