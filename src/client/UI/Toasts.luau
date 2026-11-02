-- Short messages above the bottom bar: sent by the server through the Notify remote, or shown by
-- the client with Toasts.Show. Pressing a cost button you can't afford shows "Need X more CE".
-- One message at a time, never overlapping: the others wait as a stack of cards peeking out under
-- the current one, with a skip arrow ("2 >") that jumps to the next. A message waiting in line
-- shortens the current one. The same text twice in a row is shown once. While a menu is open the
-- stack drops to the bottom edge, below the menu, so it never covers it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Banner = require(script.Parent.Banner)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Toasts = {}

local KIND_COLORS = {
	Debug = UIKit.Colors.Gold,
	Error = UIKit.Colors.Red,
	Offline = UIKit.Colors.Gold,
	Item = Color3.fromRGB(120, 235, 140),
	Jade = UIKit.Colors.Jade,
	Milestone = UIKit.Colors.Accent,
}
local MAX_WAITING = 6
local MAX_WIDTH = 720
local MIN_WIDTH = 320
local TEXT_SIZE = 21
local MIN_TEXT_SIZE = 16
local TOAST_HEIGHT = 46
local SECONDS = { Offline = 8, Item = 4, Milestone = 4.5, Error = 3.5 }
local DEFAULT_SECONDS = 3
-- With more waiting, each message only stays this long.
local BUSY_SECONDS = 1.8
local GHOSTS = 2
-- Above the bottom bar, the tutorial bubble and the wild's area label.
local NORMAL_POSITION = UDim2.new(0.5, 0, 1, -400)
local MENU_POSITION = UDim2.new(0.5, 0, 1, -10)

type Entry = { Text: string, Kind: string? }

local queue: { Entry } = {}
local holder: Frame? = nil
local card: TextLabel? = nil
local ghosts: { Frame } = {}
local skip: TextButton? = nil
local showing = false
local token = 0
local lastText: string? = nil
local lastAt = 0

local function refreshStack()
	local waiting = #queue
	for index, ghost in ghosts do
		ghost.Visible = showing and waiting >= index
	end
	if skip then
		skip.Visible = showing and waiting > 0
		skip.Text = `{waiting} \u{25B6}`
	end
end

local showNext: () -> ()

local function hideCurrent(myToken: number)
	local label = card
	if not label or myToken ~= token then
		return
	end
	local fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	TweenService:Create(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.wait(0.27)
	if myToken ~= token then
		return
	end
	showing = false
	label.Visible = false
	showNext()
end

function showNext()
	local label, frame = card, holder
	if not label or not frame or showing then
		refreshStack()
		return
	end
	local entry = table.remove(queue, 1)
	if not entry then
		refreshStack()
		return
	end
	showing = true
	token += 1
	local myToken = token
	local color = KIND_COLORS[entry.Kind or ""] or UIKit.Colors.Trim
	local width = TextService:GetTextSize(entry.Text, TEXT_SIZE, UIKit.Font, Vector2.new(MAX_WIDTH, TOAST_HEIGHT)).X + 60
	frame.Size = UDim2.fromOffset(math.clamp(width, MIN_WIDTH, MAX_WIDTH), TOAST_HEIGHT + 14)
	label.Text = entry.Text
	label.TextColor3 = if entry.Kind == "Error" then color else UIKit.Colors.Text
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.03
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	label.Visible = true
	Motion.pop(label, 0, 0.5)
	if entry.Kind == "Error" then
		Motion.shake(label, 90)
	end
	refreshStack()
	local seconds = SECONDS[entry.Kind or ""] or DEFAULT_SECONDS
	local started = os.clock()
	task.spawn(function()
		while myToken == token do
			task.wait(0.1)
			local limit = if #queue > 0 then math.min(seconds, BUSY_SECONDS) else seconds
			if os.clock() - started >= limit then
				hideCurrent(myToken)
				return
			end
		end
	end)
end

function Toasts.Show(text: string, kind: string?)
	if text == lastText and os.clock() - lastAt < 3 then
		return
	end
	lastText, lastAt = text, os.clock()
	table.insert(queue, { Text = text, Kind = kind })
	while #queue > MAX_WAITING do
		table.remove(queue, 1)
	end
	showNext()
end

function Toasts.Start(screen: ScreenGui)
	local colors = UIKit.Colors
	local frame = UIKit.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = NORMAL_POSITION,
		Size = UDim2.fromOffset(MAX_WIDTH, TOAST_HEIGHT + 14),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = screen,
	})
	UIKit.scaler(frame)
	holder = frame
	UIKit.watchMenus(screen, function(open)
		frame.Position = if open then MENU_POSITION else NORMAL_POSITION
	end)

	-- Cards peeking out under the current one: one per waiting message (up to GHOSTS).
	for index = GHOSTS, 1, -1 do
		local ghost = UIKit.create("Frame", {
			Name = `Waiting{index}`,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, index * 6),
			Size = UDim2.new(1, -index * 24, 0, TOAST_HEIGHT),
			BackgroundColor3 = colors.Panel,
			BackgroundTransparency = 0.15 + index * 0.15,
			Visible = false,
			ZIndex = 30 - index,
			Parent = frame,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.create("UIStroke", { Color = colors.Trim, Thickness = 1.5, Transparency = 0.5 }),
		})
		ghosts[index] = ghost
	end

	local label = UIKit.label({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, TOAST_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Center,
		-- Long messages shrink to fit the pill instead of being cut off.
		TextScaled = true,
		TextSize = TEXT_SIZE,
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = 31,
		Parent = frame,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = TEXT_SIZE, MinTextSize = MIN_TEXT_SIZE, Parent = label })
	UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 60), Parent = label })
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = label })
	UIKit.skinPanel(label, colors.Trim)
	card = label

	-- Skip arrow: shows how many wait and jumps to the next one.
	local skipButton = UIKit.button({
		Name = "Skip",
		Text = "",
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0, TOAST_HEIGHT / 2),
		Size = UDim2.fromOffset(52, 32),
		Visible = false,
		ZIndex = 33,
		Parent = frame,
	}, function()
		hideCurrent(token)
	end)
	UIKit.skinButton(skipButton, "Gold")
	skip = skipButton

	Notify.OnClientEvent:Connect(function(text: string, kind: string?)
		if type(text) ~= "string" then
			return
		end
		if kind == "Milestone" then
			-- Meaningful beats get a banner instead (one message, not two).
			local title = "PROGRESS"
			if string.find(text, "Rebirth", 1, true) then
				title = "REBIRTH"
			elseif string.find(text, "Fusion", 1, true) or string.find(text, "Fused", 1, true) then
				title = "FUSION"
			elseif string.find(text, "unlocked", 1, true) or string.find(text, "complete", 1, true) then
				title = "GOAL"
			end
			Banner.Show(title, text, KIND_COLORS.Milestone, if title == "REBIRTH" then 2 else 1)
			return
		end
		Toasts.Show(text, kind)
	end)

	Motion.Denied:Connect(function(button: GuiButton)
		local cost = button:GetAttribute("Cost")
		if type(cost) ~= "number" then
			return
		end
		local missing = cost - (Players.LocalPlayer:GetAttribute("CE") or 0)
		if missing > 0 then
			Toasts.Show(`Need {Format.ce(math.max(1, missing))} more CE`, "Error")
		end
	end)
end

return Toasts
