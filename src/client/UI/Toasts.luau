-- Short messages at the bottom center: sent by the server through the Notify remote, or shown by
-- the client with Toasts.Show. Pressing a cost button you can't afford shows "Need X more CE".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Toasts = {}

local KIND_COLORS = {
	Debug = UIKit.Colors.Gold,
	Error = UIKit.Colors.Red,
	Offline = UIKit.Colors.Gold,
	Item = Color3.fromRGB(120, 235, 140),
}
local MAX_SHOWN = 4
local MAX_WIDTH = 520
local TEXT_SIZE = 16

local holder: Frame? = nil
local order = 0

function Toasts.Show(text: string, kind: string?)
	local list = holder
	if not list then
		return
	end
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
	local width = TextService:GetTextSize(text, TEXT_SIZE, UIKit.Font, Vector2.new(MAX_WIDTH, 34)).X + 36
	local slot = UIKit.slot(list, "Toast", UDim2.fromOffset(math.min(width, MAX_WIDTH), 34), order)
	local toast = UIKit.label({
		Text = text,
		TextColor3 = if kind == "Error" then color else UIKit.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = TEXT_SIZE,
		Parent = slot,
	})
	UIKit.fill(toast)
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = toast })
	UIKit.skinPanel(toast, color)
	Motion.pop(toast, 0, 0.5)
	if kind == "Error" then
		Motion.shake(toast, 90)
	end
	task.delay(if kind == "Offline" then 8 else 3, function()
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
		Position = UDim2.new(0.5, 0, 1, -270),
		Size = UDim2.fromOffset(MAX_WIDTH, 200),
		BackgroundTransparency = 1,
		ZIndex = 20,
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

	Notify.OnClientEvent:Connect(function(text: string, kind: string?)
		if type(text) == "string" then
			Toasts.Show(text, kind)
		end
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
