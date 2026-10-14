-- Compact hunt HUD: Spirit Sight toggle, Pulse and Hold-to-Bind buttons (mouse/touch),
-- signal counter, hint line, bind progress meter and the Lightning Luck card (a capture's finds
-- roll on the hunt papers, HuntRolls).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(script.Parent.Parent.Sounds)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local HuntHUD = {}

local LIGHTNING_COLOR = Color3.fromRGB(255, 228, 120)

export type Callbacks = {
	OnToggleSight: () -> (),
	OnPulse: () -> (),
	OnHoldStart: () -> (),
	OnHoldEnd: () -> (),
}

export type Hud = {
	SetSightMode: (on: boolean) -> (),
	SetBindAvailable: (available: boolean) -> (),
	SetPulseCooldown: (remaining: number) -> (),
	SetProgress: (progress: number?) -> (),
	SetSignalInfo: (text: string) -> (),
	ShowHint: (text: string, seconds: number?) -> (),
	ShowLightning: (factor: number, seconds: number, onClosed: () -> ()) -> (),
}

local function keyHint(key: string): string
	if UserInputService.KeyboardEnabled then
		return ` [{key}]`
	end
	return ""
end

-- A juiced button in its own layout slot (hide the slot, not the button).
local function makeButton(
	parent: Instance,
	name: string,
	text: string,
	size: Vector2,
	kind: string,
	order: number
): (TextButton, Frame)
	local slot = UIKit.slot(parent, name .. "Slot", UDim2.fromOffset(size.X, size.Y), order)
	local button = UIKit.button({
		Name = name,
		Text = text,
		TextSize = 18,
		Parent = slot,
	})
	UIKit.fill(button)
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 12)
	end
	UIKit.skinButton(button, kind)
	Icons.inline(button, name, 26)
	return button, slot
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function HuntHUD.Start(screen: ScreenGui, callbacks: Callbacks): Hud
	local colors = UIKit.Colors

	local buttons = UIKit.create("Frame", {
		Name = "HuntButtons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -170),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 8),
		}),
	})
	UIKit.scaler(buttons)

	local iconRoom = if Icons.has("Bind") then 30 else 0
	local bindButton, bindSlot =
		makeButton(buttons, "Bind", "Hold to Bind" .. keyHint("E"), Vector2.new(200 + iconRoom, 64), "Primary", 1)
	bindButton.TextSize = 20
	bindSlot.Visible = false
	local pulseButton, pulseSlot =
		makeButton(buttons, "Pulse", "Pulse" .. keyHint("Q"), Vector2.new(150 + iconRoom, 46), "Dark", 2)
	pulseSlot.Visible = false
	local sightButton =
		makeButton(buttons, "SpiritSight", "Spirit Sight" .. keyHint("F"), Vector2.new(170 + iconRoom, 50), "Dark", 3)

	sightButton.Activated:Connect(callbacks.OnToggleSight)
	pulseButton.Activated:Connect(function()
		if pulseButton:GetAttribute("Disabled") ~= true then
			callbacks.OnPulse()
		end
	end)

	local holdingBy: Enum.UserInputType? = nil
	bindButton.InputBegan:Connect(function(input)
		if isPress(input) and not holdingBy then
			holdingBy = input.UserInputType
			callbacks.OnHoldStart()
		end
	end)
	-- Releases are caught globally so sliding a finger off the button still counts as letting go.
	UserInputService.InputEnded:Connect(function(input)
		if holdingBy and input.UserInputType == holdingBy then
			holdingBy = nil
			callbacks.OnHoldEnd()
		end
	end)

	-- Bind bar and hint get their own ScreenGui: it stays up while the main UI is hidden for a seal.
	local statusScreen = Instance.new("ScreenGui")
	statusScreen.Name = "HuntStatusUI"
	statusScreen.ResetOnSpawn = false
	statusScreen.DisplayOrder = screen.DisplayOrder + 1
	statusScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	statusScreen.Parent = screen.Parent
	local bottom = UIKit.create("Frame", {
		Name = "HuntStatus",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -165),
		Size = UDim2.fromOffset(420, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = statusScreen,
	})
	UIKit.scaler(bottom)

	local track = UIKit.create("Frame", {
		Name = "BindTrack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = colors.Track,
		Visible = false,
		Parent = bottom,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.skinPanel(track, colors.Trim)
	track.BackgroundColor3 = colors.Track
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.create("UIGradient", {
			Color = ColorSequence.new(colors.Accent, colors.Gold),
		}),
	})

	local hint = UIKit.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 17,
		TextStrokeTransparency = 0.5,
		Parent = bottom,
	})

	local signalInfo = UIKit.label({
		Name = "SignalInfo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -240),
		Size = UDim2.fromOffset(460, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(170, 230, 255),
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = screen,
	})
	UIKit.scaler(signalInfo)

	-- Hunt Streak readout (top center while a streak is going): the multiplier and the time left
	-- before it ends.
	local streakBox = UIKit.create("Frame", {
		Name = "HuntStreak",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(240, 58),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	UIKit.scaler(streakBox)
	local streakLabel = UIKit.label({
		Name = "Value",
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 30,
		TextColor3 = colors.Gold,
		TextStrokeTransparency = 0.2,
		Parent = streakBox,
	})
	local streakTrack = UIKit.create("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(0.8, 0, 0, 8),
		BackgroundColor3 = colors.Track,
		Parent = streakBox,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local streakFill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Gold,
		Parent = streakTrack,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local player = Players.LocalPlayer
	local shownStreak = 1
	local function refreshStreak()
		local value = player:GetAttribute("HuntStreak")
		local active = type(value) == "number" and value > 1
		streakBox.Visible = active
		if not active then
			shownStreak = 1
			return
		end
		streakLabel.Text = `STREAK x{Format.multiplier(value)}`
		if value > shownStreak then
			Motion.punch(streakLabel, 1.6)
			Sounds.Play("StreakUp", nil, 0.9 + (value - 1) * 0.3)
		end
		shownStreak = value
	end
	player:GetAttributeChangedSignal("HuntStreak"):Connect(refreshStreak)
	refreshStreak()
	RunService.Heartbeat:Connect(function()
		if not streakBox.Visible then
			return
		end
		local endsAt = player:GetAttribute("HuntStreakEndsAt")
		local idle = player:GetAttribute("HuntStreakIdle")
		if type(endsAt) == "number" and type(idle) == "number" and idle > 0 then
			local left = math.clamp((endsAt - workspace:GetServerTimeNow()) / idle, 0, 1)
			streakFill.Size = UDim2.fromScale(left, 1)
			streakFill.BackgroundColor3 = if left < 0.25 then Color3.fromRGB(255, 110, 90) else colors.Gold
		else
			streakFill.BackgroundColor3 = colors.SubText
		end
	end)

	-- Capture summary (GDD 4.3 step 6): model, name, base odds, mutation, bonus count, notable finds.
	local cardHolder = UIKit.create("Frame", {
		Name = "CaptureSummary",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, 236),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	UIKit.scaler(cardHolder)
	local card = UIKit.create("TextButton", {
		Name = "Card",
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
		Parent = cardHolder,
	}, { UIKit.corner(14), UIKit.padding(12), UIKit.create("UIScale", { Name = "Juice" }) })
	UIKit.fill(card)
	UIKit.skinPanel(card, colors.Trim)
	local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	cardStroke.Thickness = 3
	local function cardLabel(props: { [string]: any }): TextLabel
		props.ZIndex = 21
		props.Parent = card
		return UIKit.label(props)
	end
	local cardHeader = cardLabel({
		Name = "Header",
		Text = "SEALED",
		FontFace = UIKit.TitleFont,
		TextSize = 15,
		TextColor3 = colors.Trim,
		Position = UDim2.fromOffset(122, 0),
		Size = UDim2.new(1, -122, 0, 18),
	})
	local viewport = UIKit.create("ViewportFrame", {
		Name = "Model",
		Size = UDim2.fromOffset(112, 112),
		BackgroundColor3 = colors.Card,
		BackgroundTransparency = 0.3,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		ZIndex = 21,
		Parent = card,
	}, { UIKit.corner(10) })
	local viewCamera = Instance.new("Camera")
	viewCamera.FieldOfView = 40
	viewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1, 7.5), Vector3.new(0, 0.3, 0))
	viewCamera.Parent = viewport
	viewport.CurrentCamera = viewCamera
	local cardName = cardLabel({
		Name = "RelicName",
		TextSize = 24,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(122, 20),
		Size = UDim2.new(1, -122, 0, 52),
	})
	local cardOdds = cardLabel({
		Name = "Odds",
		TextSize = 15,
		Position = UDim2.fromOffset(122, 74),
		Size = UDim2.new(1, -122, 0, 18),
	})
	local cardBonus = cardLabel({
		Name = "Bonus",
		TextSize = 16,
		TextColor3 = colors.Gold,
		Position = UDim2.fromOffset(122, 94),
		Size = UDim2.new(1, -122, 0, 20),
	})
	local notableLines = {}
	for index = 1, 3 do
		notableLines[index] = cardLabel({
			Name = "Notable" .. index,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 120 + (index - 1) * 20),
			Size = UDim2.new(1, 0, 0, 20),
		})
	end
	local cardFooter = cardLabel({
		Name = "Footer",
		TextSize = 13,
		TextColor3 = colors.SubText,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 16),
	})

	local hintToken = 0
	local cardToken = 0
	local sightOn = false
	local cardModel: BasePart? = nil
	local onCardClosed: (() -> ())? = nil

	local function closeCard()
		cardToken += 1
		cardHolder.Visible = false
		if cardModel then
			cardModel:Destroy()
			cardModel = nil
		end
		local callback = onCardClosed
		onCardClosed = nil
		if callback then
			callback()
		end
	end
	card.Activated:Connect(closeCard)
	RunService.RenderStepped:Connect(function(dt)
		if cardModel and cardHolder.Visible then
			cardModel.CFrame = CFrame.Angles(0, dt * 1.4, 0) * cardModel.CFrame
		end
	end)

	local function openCard(model: BasePart?, onClosed: () -> ())
		if model then
			model.Parent = viewport
			cardModel = model
		end
		onCardClosed = onClosed
		local token = cardToken
		cardHolder.Visible = true
		Motion.pop(card, 0, 0.5)
		task.delay(0.2, function()
			if cardToken == token then
				Motion.shine(card, 0.8)
			end
		end)
		task.delay(Config.Hunt.SummarySeconds, function()
			if cardToken == token and cardHolder.Visible then
				closeCard()
			end
		end)
	end

	local hud = {}

	local function showSlot(slot: Frame, button: GuiObject, visible: boolean)
		if visible and not slot.Visible then
			Motion.pop(button, 0, 0.4)
		end
		slot.Visible = visible
	end

	function hud.SetSightMode(on: boolean)
		if on ~= sightOn then
			Motion.punch(sightButton, 1.5)
		end
		sightOn = on
		UIKit.skinButton(sightButton, if on then "Primary" else "Dark")
		sightButton.Text = (if on then "Leave Sight" else "Spirit Sight") .. keyHint("F")
		showSlot(pulseSlot, pulseButton, on)
		bottom.Visible = on
		signalInfo.Visible = on
		if not on then
			bindSlot.Visible = false
		end
	end

	function hud.SetBindAvailable(available: boolean)
		showSlot(bindSlot, bindButton, sightOn and available)
	end

	local pulseReady = true
	function hud.SetPulseCooldown(remaining: number)
		local ready = remaining <= 0
		pulseButton.Text = if ready then "Pulse" .. keyHint("Q") else `Pulse ({math.ceil(remaining)})`
		if ready == pulseReady then
			return
		end
		pulseReady = ready
		Motion.setDisabled(pulseButton, not ready)
		pulseButton.TextTransparency = if ready then 0 else 0.45
		if ready and pulseSlot.Visible then
			Motion.shine(pulseButton, 0.5)
		end
	end

	local bindFull = false
	function hud.SetProgress(progress: number?)
		track.Visible = progress ~= nil
		local full = progress ~= nil and progress >= 1
		if progress then
			fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		end
		if full and not bindFull then
			Motion.flash(track, colors.Gold, 0.2)
		end
		bindFull = full
	end

	function hud.SetSignalInfo(text: string)
		signalInfo.Text = text
	end

	function hud.ShowHint(text: string, seconds: number?)
		hintToken += 1
		local token = hintToken
		hint.Text = text
		if seconds then
			task.delay(seconds, function()
				if hintToken == token then
					hint.Text = ""
				end
			end)
		end
	end

	-- A lightning-struck capture: nothing was rolled, the reward is Lightning Luck.
	function hud.ShowLightning(factor: number, seconds: number, onClosed: () -> ())
		onCardClosed = nil
		closeCard()
		cardHeader.Text = "LIGHTNING-STRUCK SPIRIT"
		cardHeader.TextColor3 = LIGHTNING_COLOR
		cardName.Text = "Lightning Luck!"
		cardName.TextColor3 = LIGHTNING_COLOR
		cardStroke.Color = LIGHTNING_COLOR
		cardOdds.Text = `Luck x{Format.multiplier(factor)} on every roll`
		cardOdds.TextColor3 = colors.Text
		cardBonus.Text = `for {Format.duration(seconds)}`
		cardBonus.TextColor3 = LIGHTNING_COLOR
		local lines = {
			"  No relic from this one - the storm charged you instead.",
			"  Scan and capture now: every discovery rolls luckier.",
			"  More struck spirits add time.",
		}
		for index, line in notableLines do
			line.Visible = lines[index] ~= nil
			line.Text = lines[index] or ""
			line.TextColor3 = colors.SubText
		end
		cardFooter.Text = "Tap to close"

		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.one * 2.2
		orb.Material = Enum.Material.Neon
		orb.Color = LIGHTNING_COLOR
		orb.Anchored = true
		openCard(orb, onClosed)
	end

	return hud :: Hud
end

return HuntHUD
