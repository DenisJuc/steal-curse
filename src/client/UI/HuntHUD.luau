-- Compact hunt HUD: Spirit Sight toggle, Pulse and Hold-to-Bind buttons (mouse/touch),
-- signal counter, hint line, bind progress meter and the capture summary card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CaptureSummary = require(ReplicatedStorage.Shared.CaptureSummary)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicShapes = require(ReplicatedStorage.Shared.RelicShapes)
local MutationVFX = require(script.Parent.Parent.Effects.MutationVFX)
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

local function makeButton(parent: Instance, name: string, text: string, size: Vector2, color: Color3): TextButton
	return UIKit.create("TextButton", {
		Name = name,
		Text = text,
		Font = UIKit.Font,
		TextSize = 18,
		TextColor3 = UIKit.Colors.Text,
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = parent,
	}, {
		UIKit.corner(12),
		UIKit.stroke(Color3.new(1, 1, 1), 2, 0.6),
	})
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

	local bindButton = makeButton(buttons, "Bind", "Hold to Bind" .. keyHint("E"), Vector2.new(200, 64), colors.Accent)
	bindButton.LayoutOrder = 1
	bindButton.TextSize = 20
	bindButton.Visible = false
	local pulseButton = makeButton(buttons, "Pulse", "Pulse" .. keyHint("Q"), Vector2.new(150, 46), colors.Card)
	pulseButton.LayoutOrder = 2
	pulseButton.Visible = false
	local sightButton = makeButton(buttons, "SpiritSight", "Spirit Sight" .. keyHint("F"), Vector2.new(170, 50), colors.Card)
	sightButton.LayoutOrder = 3

	sightButton.Activated:Connect(callbacks.OnToggleSight)
	pulseButton.Activated:Connect(callbacks.OnPulse)

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

	local bottom = UIKit.create("Frame", {
		Name = "HuntStatus",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(420, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
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
	}, { UIKit.corner(9), UIKit.stroke(colors.Accent, 2, 0.2) })
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = colors.Accent,
		Parent = track,
	}, { UIKit.corner(9) })

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
		Position = UDim2.new(0.5, 0, 1, -186),
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
	local card = UIKit.create("TextButton", {
		Name = "CaptureSummary",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, 236),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	}, { UIKit.corner(14), UIKit.padding(12) })
	UIKit.scaler(card)
	local cardStroke = UIKit.stroke(colors.Accent, 3, 0)
	cardStroke.Parent = card
	local function cardLabel(props: { [string]: any }): TextLabel
		props.ZIndex = 21
		props.Parent = card
		return UIKit.label(props)
	end
	cardLabel({
		Name = "Header",
		Text = "SEALED",
		TextSize = 15,
		TextColor3 = colors.SubText,
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
		card.Visible = false
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
		if cardModel and card.Visible then
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

	function hud.SetSightMode(on: boolean)
		sightOn = on
		sightButton.BackgroundColor3 = if on then colors.Accent else colors.Card
		sightButton.Text = (if on then "Leave Sight" else "Spirit Sight") .. keyHint("F")
		pulseButton.Visible = on
		bottom.Visible = on
		signalInfo.Visible = on
		if not on then
			bindButton.Visible = false
		end
	end

	function hud.SetBindAvailable(available: boolean)
		bindButton.Visible = sightOn and available
	end

	function hud.SetPulseCooldown(remaining: number)
		if remaining > 0 then
			pulseButton.Text = `Pulse ({math.ceil(remaining)})`
			pulseButton.AutoButtonColor = false
			pulseButton.BackgroundTransparency = 0.4
		else
			pulseButton.Text = "Pulse" .. keyHint("Q")
			pulseButton.AutoButtonColor = true
			pulseButton.BackgroundTransparency = 0
		end
	end

	function hud.SetProgress(progress: number?)
		track.Visible = progress ~= nil
		if progress then
			fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		end
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

		local props = RelicShapes.props(relic.ObjectType, CFrame.new(), 1.15)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Material = Enum.Material.SmoothPlastic
		part.Color = UIKit.tierColor(relic.Tier)
		part.Shape = props.Shape or Enum.PartType.Block
		part.Size = props.Size
		part.CFrame = props.CFrame
		if mutation then
			MutationVFX.Apply(part, mutation, { Highlight = false, Particles = false })
		end
		part.Parent = viewport
		cardModel = part

		onCardClosed = onClosed
		local token = cardToken
		card.Visible = true
		task.delay(Config.Hunt.SummarySeconds, function()
			if cardToken == token and card.Visible then
				closeCard()
			end
		end)
	end

	return hud :: Hud
end

return HuntHUD
