-- Compact hunt HUD: Spirit Sight toggle, Pulse and Hold-to-Bind buttons (mouse/touch),
-- signal counter, hint line, bind progress meter and the capture summary card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CaptureSummary = require(ReplicatedStorage.Shared.CaptureSummary)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local MutationVFX = require(script.Parent.Parent.Effects.MutationVFX)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local HuntHUD = {}

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
	ShowSummary: (summary: CaptureSummary.Summary, onClosed: () -> ()) -> (),
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
	cardLabel({
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

	local function relicColor(relicId: string, mutation: string?): Color3
		local relic = RelicConfig.ById[relicId]
		if mutation then
			return UIKit.mutationColor(mutation)
		end
		return if relic then UIKit.tierColor(relic.Tier) else colors.Text
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

	function hud.ShowSummary(summary: CaptureSummary.Summary, onClosed: () -> ())
		local relic = RelicConfig.ById[summary.CapturedId]
		if not relic then
			onClosed()
			return
		end
		-- A newer capture replaces the card without running the old card's close callback.
		onCardClosed = nil
		closeCard()
		local mutation = summary.CapturedMutation
		local color = relicColor(relic.Id, mutation)
		cardName.Text = (if summary.CapturedFirst then "NEW! " else "") .. Odds.displayName(relic.Id, mutation)
		cardName.TextColor3 = color
		cardStroke.Color = color
		cardOdds.Text = Odds.describe(relic.Id, mutation)
		cardOdds.TextColor3 = color
		cardBonus.Text = `+{summary.BonusCount} bonus discoveries`

		for index, line in notableLines do
			local notable = summary.Notable[index]
			line.Visible = notable ~= nil
			if notable then
				local tag = if notable.First then "  NEW!" elseif notable.NewVariant then "  NEW VARIANT" else ""
				line.Text = `  {Odds.displayName(notable.Id, notable.Mutation)}  ({Format.odds(Odds.baseItem(notable.Id))}){tag}`
				line.TextColor3 = relicColor(notable.Id, notable.Mutation)
			end
		end
		local footer = {}
		if summary.NewCount > 0 then
			table.insert(footer, `{summary.NewCount} new to your Codex`)
		end
		if summary.SoldCount > 0 then
			table.insert(footer, `{summary.SoldCount} auto-sold (+{Format.number(summary.SoldCE)} CE)`)
		end
		table.insert(footer, "Tap to close")
		cardFooter.Text = table.concat(footer, "   |   ")

		local part = RelicModels.build(relic.Id, CFrame.new(), 1.15)
		if part then
			if mutation then
				MutationVFX.Apply(part, mutation, { Highlight = false, Particles = false })
			end
			part.Parent = viewport
			cardModel = part
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

	return hud :: Hud
end

return HuntHUD
