-- Compact hunt HUD: Spirit Sight toggle, Pulse and Hold-to-Bind buttons (mouse/touch),
-- signal counter, hint line, bind progress meter and the capture result card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
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
	ShowCapture: (capturedId: string, bonusCount: number, bestBonusId: string?) -> (),
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
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(360, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(170, 230, 255),
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = screen,
	})
	UIKit.scaler(signalInfo)

	local card = UIKit.create("Frame", {
		Name = "CaptureCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(380, 132),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = screen,
	}, { UIKit.corner(14), UIKit.padding(12) })
	UIKit.scaler(card)
	local cardStroke = UIKit.stroke(colors.Accent, 3, 0)
	cardStroke.Parent = card
	UIKit.label({
		Name = "Header",
		Text = "SEALED",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextColor3 = colors.SubText,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = card,
	})
	local cardName = UIKit.label({
		Name = "RelicName",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 26,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = card,
	})
	local cardOdds = UIKit.label({
		Name = "Odds",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = card,
	})
	local cardBonus = UIKit.label({
		Name = "Bonus",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = card,
	})

	local hintToken = 0
	local cardToken = 0
	local sightOn = false

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

	function hud.ShowCapture(capturedId: string, bonusCount: number, bestBonusId: string?)
		local relic = RelicConfig.ById[capturedId]
		if not relic then
			return
		end
		local tier = RarityConfig.Get(relic.Tier)
		local color = UIKit.tierColor(relic.Tier)
		local probability = RollMath.itemProbability(RarityConfig.Tiers, RelicConfig.Relics, relic.Id, 1)
		cardName.Text = relic.Name
		cardName.TextColor3 = color
		cardStroke.Color = color
		cardOdds.Text = `{if tier then tier.Name else relic.Tier}  |  {Format.odds(probability)}`
		cardOdds.TextColor3 = color
		local best = bestBonusId and RelicConfig.ById[bestBonusId]
		cardBonus.Text = `+{bonusCount} bonus discoveries` .. (if best then `  |  best: {best.Name}` else "")

		cardToken += 1
		local token = cardToken
		card.Visible = true
		task.delay(3.5, function()
			if cardToken == token then
				card.Visible = false
			end
		end)
	end

	return hud :: Hud
end

return HuntHUD
