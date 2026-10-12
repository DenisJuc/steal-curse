-- Big celebratory banner in the upper middle of the screen, above every menu. It never blocks
-- clicks, pops in on a spring with a light sweep and shrinks away on its own; a newer banner
-- replaces an older one.

local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Motion)
local Spring = require(script.Parent.Spring)
local UIKit = require(script.Parent.UIKit)

local Banner = {}

local SHOW_SECONDS = 3.5

local holder: Frame? = nil
local card: Frame? = nil
local titleLabel: TextLabel? = nil
local textLabel: TextLabel? = nil
local showId = 0

function Banner.Start(screen: ScreenGui)
	local colors = UIKit.Colors
	local frame = UIKit.create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(460, 92),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = screen,
	})
	UIKit.scaler(frame)
	local inner = UIKit.create("Frame", {
		Name = "Card",
		Active = false,
		Parent = frame,
	}, { UIKit.corner(14), UIKit.padding(10), UIKit.create("UIScale", { Name = "Juice" }) })
	UIKit.fill(inner)
	UIKit.skinPanel(inner, colors.Gold)
	titleLabel = UIKit.label({
		FontFace = UIKit.TitleFont,
		TextSize = 24,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = inner,
	})
	textLabel = UIKit.label({
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = inner,
	})
	holder = frame
	card = inner
end

function Banner.Show(title: string, text: string, color: Color3)
	local frame, inner, titleText, bodyText = holder, card, titleLabel, textLabel
	if not frame or not inner or not titleText or not bodyText then
		return
	end
	showId += 1
	local myId = showId
	titleText.Text = title
	titleText.TextColor3 = color
	bodyText.Text = text
	local stroke = inner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	local scale = inner:FindFirstChild("Juice") :: UIScale
	Spring.stop(scale)
	scale.Scale = 0.4
	frame.Visible = true
	Spring.target(scale, 3.4, 0.45, { Scale = 1 })
	task.delay(0.15, function()
		if showId == myId then
			Motion.shine(inner, 0.8)
		end
	end)
	task.delay(SHOW_SECONDS, function()
		if showId ~= myId then
			return
		end
		Spring.stop(scale)
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			:Play()
		task.wait(0.25)
		if showId == myId then
			frame.Visible = false
		end
	end)
end

return Banner
