-- Top-right quick travel (Slice 11): Home (your shrine), Hub (the plaza) and Wild (the nearest edge
-- of the wild ring). The server picks the spot, applies the cooldown and refuses during a bind;
-- this only sends Teleport and greys the buttons while the cooldown runs (TravelReadyAt). Pressing
-- a greyed button shakes it and says when travel is ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Toasts = require(script.Parent.Toasts)
local UIKit = require(script.Parent.UIKit)

local Teleport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Teleport") :: RemoteEvent

local TravelBar = {}

local DESTINATIONS = {
	{ Id = "Home", Label = "Home" },
	{ Id = "Hub", Label = "Hub" },
	{ Id = "Wild", Label = "Wild" },
}
local BUTTON_HEIGHT = 34

function TravelBar.Start(screen: ScreenGui): { SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local width = if Icons.has("Home") then 92 else 64

	local bar = UIKit.create("Frame", {
		Name = "TravelBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(width * #DESTINATIONS + 6 * (#DESTINATIONS - 1), BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	UIKit.scaler(bar)

	local function readyIn(): number
		local readyAt = player:GetAttribute("TravelReadyAt")
		return if type(readyAt) == "number" then readyAt - workspace:GetServerTimeNow() else 0
	end

	local buttons = {}
	for index, destination in DESTINATIONS do
		local slot = UIKit.slot(bar, destination.Id .. "Slot", UDim2.fromOffset(width, BUTTON_HEIGHT), index)
		local button = UIKit.button({
			Name = destination.Id .. "Travel",
			Text = destination.Label,
			TextSize = 15,
			Parent = slot,
		}, function()
			Teleport:FireServer(destination.Id)
		end)
		UIKit.fill(button)
		UIKit.skinButton(button, "Dark")
		button.BackgroundColor3 = colors.Panel
		Icons.inline(button, destination.Id, 22)
		button.Activated:Connect(function()
			local left = readyIn()
			if button:GetAttribute("Disabled") and left > 0 then
				Toasts.Show(`Travel ready in {math.ceil(left)}s`)
			end
		end)
		table.insert(buttons, button)
	end

	local wasCooling = false
	RunService.Heartbeat:Connect(function()
		local cooling = readyIn() > 0
		if cooling == wasCooling then
			return
		end
		wasCooling = cooling
		for _, button in buttons do
			button.TextTransparency = if cooling then 0.55 else 0
			Motion.setDisabled(button, cooling)
		end
		if not cooling then
			for _, button in buttons do
				Motion.shine(button, 0.5)
			end
		end
	end)

	return {
		SetVisible = function(visible: boolean)
			bar.Visible = visible
		end,
	}
end

return TravelBar
