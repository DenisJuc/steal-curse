-- Short messages at the bottom center: sent by the server through the Notify remote, or shown by
-- the client with Toasts.Show. Pressing a cost button you can't afford shows "Need X more CE".
-- While a menu is open the toasts drop to the bottom edge, below the menu, so they never cover it.

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
-- Few and readable: at most 3 at once, rewards stay 4 s, routine ones 3 s, the same text twice in
-- a row is shown once.
local MAX_SHOWN = 3
local MAX_WIDTH = 720
local TEXT_SIZE = 21
local MIN_TEXT_SIZE = 16
local TOAST_HEIGHT = 46
local SECONDS = { Offline = 8, Item = 4, Milestone = 4.5, Error = 3.5 }
local DEFAULT_SECONDS = 3
local NORMAL_POSITION = UDim2.new(0.5, 0, 1, -330)
local MENU_POSITION = UDim2.new(0.5, 0, 1, -10)

local holder: Frame? = nil
local order = 0
local lastText: string? = nil
local lastAt = 0

function Toasts.Show(text: string, kind: string?)
	local list = holder
	if not list then
		return
	end
	if text == lastText and os.clock() - lastAt < 3 then
		return
	end
	lastText, lastAt = text, os.clock()
	local shown = {}
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(shown, child)
		end
	end
	table.sort(shown, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #shown - MAX_SHOWN + 1 do
		shown[index]:Destroy()
	end

	order += 1
	local color = KIND_COLORS[kind or ""] or UIKit.Colors.Trim
	local width = TextService:GetTextSize(text, TEXT_SIZE, UIKit.Font, Vector2.new(MAX_WIDTH, TOAST_HEIGHT)).X + 48
	local slot = UIKit.slot(list, "Toast", UDim2.fromOffset(math.min(width, MAX_WIDTH), TOAST_HEIGHT), order)
	local toast = UIKit.label({
		Text = text,
		TextColor3 = if kind == "Error" then color else UIKit.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		-- Long messages shrink to fit the pill instead of being cut off.
		TextScaled = true,
		TextSize = TEXT_SIZE,
		Parent = slot,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = TEXT_SIZE, MinTextSize = MIN_TEXT_SIZE, Parent = toast })
	UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = toast })
	UIKit.fill(toast)
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = toast })
	UIKit.skinPanel(toast, color)
	Motion.pop(toast, 0, 0.5)
	if kind == "Error" then
		Motion.shake(toast, 90)
	end
	task.delay(SECONDS[kind or ""] or DEFAULT_SECONDS, function()
		if not toast.Parent then
			return
		end
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
		TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		for _, descendant in toast:GetDescendants() do
			if descendant:IsA("UIStroke") then
				TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		slot:Destroy()
	end)
end

function Toasts.Start(screen: ScreenGui)
	local list = UIKit.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = NORMAL_POSITION,
		Size = UDim2.fromOffset(MAX_WIDTH, (TOAST_HEIGHT + 6) * MAX_SHOWN),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
		}),
	})
	UIKit.scaler(list)
	holder = list
	UIKit.watchMenus(screen, function(open)
		list.Position = if open then MENU_POSITION else NORMAL_POSITION
	end)

	Notify.OnClientEvent:Connect(function(text: string, kind: string?)
		if type(text) ~= "string" then
			return
		end
		if kind == "Milestone" then
			-- Meaningful beats: Banner + toast so they are not missed during AFK scanning.
			local title = "PROGRESS"
			if string.find(text, "Rebirth", 1, true) then
				title = "REBIRTH"
			elseif string.find(text, "Fusion", 1, true) or string.find(text, "Fused", 1, true) then
				title = "FUSION"
			elseif string.find(text, "unlocked", 1, true) or string.find(text, "complete", 1, true) then
				title = "GOAL"
			end
			Banner.Show(title, text, KIND_COLORS.Milestone, if title == "REBIRTH" then 2 else 1)
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
