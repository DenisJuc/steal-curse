-- Short messages at the bottom center, sent by the server through the Notify remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Toasts = {}

local KIND_COLORS = {
	Debug = UIKit.Colors.Gold,
	Error = UIKit.Colors.Red,
	Offline = UIKit.Colors.Gold,
}

function Toasts.Start(screen: ScreenGui)
	local holder = UIKit.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 200),
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
	UIKit.scaler(holder)

	Notify.OnClientEvent:Connect(function(text: string, kind: string?)
		if type(text) ~= "string" then
			return
		end
		local color = KIND_COLORS[kind or ""] or UIKit.Colors.Accent
		local toast = UIKit.label({
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = UIKit.Colors.Panel,
			Parent = holder,
		})
		UIKit.create("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			Parent = toast,
		})
		UIKit.corner(10).Parent = toast
		UIKit.stroke(color, 2, 0.2).Parent = toast
		task.delay(if kind == "Offline" then 8 else 3, function()
			UIKit.tween(toast, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.wait(0.45)
			toast:Destroy()
		end)
	end)
end

return Toasts
