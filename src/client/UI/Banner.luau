-- Big celebratory banner in the upper middle of the screen. Several at once never overlap: the
-- next ones wait as cards stacked under the current one, with a skip arrow that shows the count. While a menu is open it moves up to the
-- top edge, above the menu, so it never covers the menu's header or tabs. It never blocks
-- clicks. Banners queue: each one plays in full (pop in, hold, shrink away) before the next starts,
-- so zone-depth and reward banners never stack on top of each other.

local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Motion)
local Spring = require(script.Parent.Spring)
local UIKit = require(script.Parent.UIKit)

local Banner = {}

-- Two sizes. Important banners (priority 2: events, other players' rare finds, Server Luck,
-- rebirth, anti-AFK) are big and stay 4.5 s; everything else is a small strip for 2.2 s. Up to 4
-- wait in line (stacked, with a skip arrow); when full, the least important pending one is dropped.
local STYLES = {
	[1] = { Seconds = 2.2, Size = Vector2.new(460, 90), Title = 26, Text = 21, TextTop = 32 },
	[2] = { Seconds = 4.5, Size = Vector2.new(680, 132), Title = 38, Text = 25, TextTop = 50 },
}
local HIDE_SECONDS = 0.25
local MAX_QUEUE = 4

type Entry = { Title: string, Text: string, Color: Color3, Priority: number }

local holder: Frame? = nil
local card: Frame? = nil
local titleLabel: TextLabel? = nil
local textLabel: TextLabel? = nil
local queue: { Entry } = {}
local playing = false
local token = 0
local skipButton: TextButton? = nil
local ghosts: { Frame } = {}

-- Waiting banners show as cards stacked under the current one, plus a skip arrow with the count.
local function refreshStack()
	for index, ghost in ghosts do
		ghost.Visible = playing and #queue >= index
	end
	local button = skipButton
	if button then
		button.Visible = playing and #queue > 0
		button.Text = `{#queue} \u{25B6}`
	end
end

local playNext: () -> ()

local function finish(myToken: number)
	local frame, inner = holder, card
	if myToken ~= token or not frame or not inner then
		return
	end
	token += 1
	local scale = inner:FindFirstChild("Juice") :: UIScale
	Spring.stop(scale)
	TweenService:Create(scale, TweenInfo.new(HIDE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		:Play()
	task.wait(HIDE_SECONDS + 0.05)
	if #queue == 0 then
		frame.Visible = false
	end
	playing = false
	playNext()
end

function playNext()
	if playing then
		refreshStack()
		return
	end
	local frame, inner, titleText, bodyText = holder, card, titleLabel, textLabel
	if not frame or not inner or not titleText or not bodyText then
		return
	end
	local entry = table.remove(queue, 1)
	if not entry then
		refreshStack()
		return
	end
	playing = true
	token += 1
	local myToken = token

	local style = STYLES[entry.Priority] or STYLES[1]
	frame.Size = UDim2.fromOffset(style.Size.X, style.Size.Y)
	titleText.TextSize = style.Title
	titleText.Size = UDim2.new(1, 0, 0, style.Title + 6)
	bodyText.Position = UDim2.fromOffset(0, style.TextTop)
	bodyText.Size = UDim2.new(1, 0, 1, -style.TextTop)
	local limit = bodyText:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = style.Text
		limit.MinTextSize = math.min(limit.MinTextSize, style.Text)
	end
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

	refreshStack()
	task.delay(style.Seconds, function()
		finish(myToken)
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
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 25, MinTextSize = 14, Parent = textLabel })
	-- Stacked cards for waiting banners, and the skip arrow (the only clickable part).
	for index = 2, 1, -1 do
		ghosts[index] = UIKit.create("Frame", {
			Name = `Waiting{index}`,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, index * 8),
			Size = UDim2.new(1, -index * 36, 1, 0),
			BackgroundColor3 = colors.Panel,
			BackgroundTransparency = 0.1 + index * 0.15,
			Visible = false,
			ZIndex = 0,
			Parent = frame,
		}, {
			UIKit.corner(14),
			UIKit.create("UIStroke", { Color = colors.Trim, Thickness = 1.5, Transparency = 0.4 }),
		})
	end
	local button = UIKit.button({
		Name = "Skip",
		Text = "",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(60, 34),
		Visible = false,
		ZIndex = 45,
		Parent = frame,
	}, function()
		task.spawn(finish, token)
	end)
	UIKit.skinButton(button, "Gold")
	skipButton = button
	holder = frame
	card = inner
end

-- priority: 1 = normal, 2 = important (rare finds, rebirth, events); low ones are dropped first.
function Banner.Show(title: string, text: string, color: Color3, priority: number?)
	-- Skip a duplicate of what's already playing or last in the queue.
	local last = queue[#queue]
	if last and last.Title == title and last.Text == text then
		return
	end
	if playing and titleLabel and titleLabel.Text == title and textLabel and textLabel.Text == text then
		return
	end
	table.insert(queue, { Title = title, Text = text, Color = color, Priority = priority or 1 })
	while #queue > MAX_QUEUE do
		local drop = 1
		for index, entry in queue do
			if entry.Priority < queue[drop].Priority then
				drop = index
			end
		end
		table.remove(queue, drop)
	end
	task.spawn(playNext)
end

return Banner
