-- Big celebratory banner in the upper middle of the screen. While a menu is open it moves up to the
-- top edge, above the menu, so it never covers the menu's header or tabs. It never blocks
-- clicks. Banners queue: each one plays in full (pop in, hold, shrink away) before the next starts,
-- so zone-depth and reward banners never stack on top of each other.

local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Motion)
local Spring = require(script.Parent.Spring)
local UIKit = require(script.Parent.UIKit)

local Banner = {}

-- Big and slow enough to read; only 2 wait in line (older ones are dropped, the newest matter).
local SHOW_SECONDS = 4.5
local HIDE_SECONDS = 0.25
local MAX_QUEUE = 2

type Entry = { Title: string, Text: string, Color: Color3 }

local holder: Frame? = nil
local card: Frame? = nil
local titleLabel: TextLabel? = nil
local textLabel: TextLabel? = nil
local queue: { Entry } = {}
local playing = false

local function playNext()
	if playing then
		return
	end
	local frame, inner, titleText, bodyText = holder, card, titleLabel, textLabel
	if not frame or not inner or not titleText or not bodyText then
		return
	end
	local entry = table.remove(queue, 1)
	if not entry then
		return
	end
	playing = true

	titleText.Text = entry.Title
	titleText.TextColor3 = entry.Color
	bodyText.Text = entry.Text
	local stroke = inner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = entry.Color
	end
	local scale = inner:FindFirstChild("Juice") :: UIScale
	Spring.stop(scale)
	scale.Scale = 0.4
	frame.Visible = true
	Spring.target(scale, 3.4, 0.45, { Scale = 1 })
	task.delay(0.15, function()
		if frame.Visible and titleText.Text == entry.Title then
			Motion.shine(inner, 0.8)
		end
	end)

	task.delay(SHOW_SECONDS, function()
		if titleText.Text ~= entry.Title then
			playing = false
			playNext()
			return
		end
		Spring.stop(scale)
		TweenService:Create(
			scale,
			TweenInfo.new(HIDE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		):Play()
		task.wait(HIDE_SECONDS + 0.05)
		if #queue == 0 then
			frame.Visible = false
		end
		playing = false
		playNext()
	end)
end

function Banner.Start(screen: ScreenGui)
	local colors = UIKit.Colors
	local frame = UIKit.create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(680, 132),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = screen,
	})
	UIKit.scaler(frame)
	UIKit.watchMenus(screen, function(open)
		frame.AnchorPoint = if open then Vector2.new(0.5, 0) else Vector2.new(0.5, 0.5)
		frame.Position = if open then UDim2.fromOffset(0, 2) + UDim2.fromScale(0.5, 0) else UDim2.fromScale(0.5, 0.2)
	end)
	local inner = UIKit.create("Frame", {
		Name = "Card",
		Active = false,
		Parent = frame,
	}, { UIKit.corner(14), UIKit.padding(10), UIKit.create("UIScale", { Name = "Juice" }) })
	UIKit.fill(inner)
	UIKit.skinPanel(inner, colors.Gold)
	titleLabel = UIKit.label({
		FontFace = UIKit.TitleFont,
		TextSize = 38,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = inner,
	})
	textLabel = UIKit.label({
		TextSize = 25,
		TextWrapped = true,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		Parent = inner,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 25, MinTextSize = 18, Parent = textLabel })
	holder = frame
	card = inner
end

function Banner.Show(title: string, text: string, color: Color3)
	-- Skip a duplicate of what's already playing or last in the queue.
	local last = queue[#queue]
	if last and last.Title == title and last.Text == text then
		return
	end
	if playing and titleLabel and titleLabel.Text == title and textLabel and textLabel.Text == text then
		return
	end
	table.insert(queue, { Title = title, Text = text, Color = color })
	while #queue > MAX_QUEUE do
		table.remove(queue, 1)
	end
	task.spawn(playNext)
end

return Banner
