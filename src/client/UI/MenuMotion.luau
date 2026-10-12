-- Menu windows (UIKit.modal) open with a springy pop and close with a quick shrink. While a menu
-- is open the world behind it is blurred (not on Low effects) and dimmed, and clicking empty space
-- closes it; the HUD stays bright and clickable. Panels keep simply setting window.Visible: on a
-- close this module shows the window again until the shrink finishes (marked with the "Closing"
-- attribute so controller support can ignore it; clearing it reopens the window).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Motion)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local Spring = require(script.Parent.Spring)

local MenuMotion = {}

local OPEN_FROM = 0.82
local OPEN_RISE = 18
local CLOSE_TO = 0.86
local CLOSE_SECONDS = 0.12
local BLUR_SIZE = 14
local DIM = 0.55
local FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quad)
-- Items tagged with the "PopIn" attribute pop in one after another when their menu opens,
-- including items the menu builds shortly after opening (server replies).
local POP_WINDOW = 0.6
local POP_STAGGER = 0.035
local POP_LIMIT = 14

function MenuMotion.Start(screen: ScreenGui)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "MenuBackdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Position = UDim2.fromOffset(0, -80)
	backdrop.Size = UDim2.new(1, 0, 1, 80)
	backdrop.ZIndex = 0
	backdrop.Selectable = false
	backdrop.Visible = false
	backdrop.Parent = screen

	local blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	local states: { [GuiObject]: string } = {}

	local function anyOpen(): boolean
		for _, state in states do
			if state == "Open" then
				return true
			end
		end
		return false
	end

	local function refreshBackdrop()
		local open = anyOpen() and screen.Enabled
		if open then
			backdrop.Visible = true
			TweenService:Create(backdrop, FADE, { BackgroundTransparency = DIM }):Play()
			if not Settings.LowEffects() then
				blur.Enabled = true
				TweenService:Create(blur, FADE, { Size = BLUR_SIZE }):Play()
			end
			return
		end
		local fade = TweenService:Create(backdrop, FADE, { BackgroundTransparency = 1 })
		fade.Completed:Once(function()
			if not (anyOpen() and screen.Enabled) then
				backdrop.Visible = false
			end
		end)
		fade:Play()
		local unblur = TweenService:Create(blur, FADE, { Size = 0 })
		unblur.Completed:Once(function()
			if not (anyOpen() and screen.Enabled) then
				blur.Enabled = false
			end
		end)
		unblur:Play()
	end

	backdrop.Activated:Connect(function()
		for window, state in states do
			if state == "Open" then
				window.Visible = false
			end
		end
	end)
	screen:GetPropertyChangedSignal("Enabled"):Connect(refreshBackdrop)

	local function attach(child: Instance)
		if not child:IsA("GuiObject") or not child:GetAttribute("Modal") then
			return
		end
		local window = child :: GuiObject
		local juice = window:FindFirstChild("Juice") :: UIScale?
		if not juice then
			local created = Instance.new("UIScale")
			created.Name = "Juice"
			created.Parent = window
			juice = created
		end
		local scale = juice :: UIScale
		local basePosition = window.Position
		states[window] = if window.Visible then "Open" else "Closed"
		local reshowPending, hidingByUs = false, false
		local token = 0
		local freshUntil, popCount = 0, 0

		local function popItem(item: GuiObject)
			if popCount >= POP_LIMIT then
				return
			end
			popCount += 1
			Motion.pop(item, popCount * POP_STAGGER, 0.6)
		end
		window.DescendantAdded:Connect(function(descendant)
			if os.clock() >= freshUntil then
				return
			end
			task.defer(function()
				if descendant:IsA("GuiObject") and descendant.Parent and descendant:GetAttribute("PopIn") then
					popItem(descendant)
				end
			end)
		end)

		local function popAll()
			freshUntil = os.clock() + POP_WINDOW
			popCount = 0
			local items = {}
			for _, descendant in window:GetDescendants() do
				if descendant:IsA("GuiObject") and descendant:GetAttribute("PopIn") then
					table.insert(items, descendant)
				end
			end
			table.sort(items, function(a, b)
				if math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) > 2 then
					return a.AbsolutePosition.Y < b.AbsolutePosition.Y
				end
				return a.AbsolutePosition.X < b.AbsolutePosition.X
			end)
			for _, item in items do
				popItem(item)
			end
		end

		local function open()
			token += 1
			states[window] = "Open"
			window:SetAttribute("Closing", nil)
			popAll()
			scale.Scale = OPEN_FROM
			Spring.target(scale, 3.6, 0.5, { Scale = 1 })
			window.Position = basePosition + UDim2.fromOffset(0, OPEN_RISE)
			Spring.target(window, 4, 0.8, { Position = basePosition })
			Sounds.Play("MenuOpen", nil, 0.97 + math.random() * 0.06)
			refreshBackdrop()
		end

		local function close()
			token += 1
			local mine = token
			states[window] = "Closing"
			window:SetAttribute("Closing", true)
			reshowPending = true
			window.Visible = true
			Spring.stop(scale)
			Spring.stop(window)
			TweenService:Create(
				scale,
				TweenInfo.new(CLOSE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Scale = CLOSE_TO }
			):Play()
			Sounds.Play("MenuClose", nil, 0.97 + math.random() * 0.06)
			refreshBackdrop()
			task.delay(CLOSE_SECONDS, function()
				if token ~= mine then
					return
				end
				states[window] = "Closed"
				window:SetAttribute("Closing", nil)
				if window.Visible then
					hidingByUs = true
					window.Visible = false
				end
				scale.Scale = 1
				window.Position = basePosition
			end)
		end

		window:GetPropertyChangedSignal("Visible"):Connect(function()
			if window.Visible then
				if reshowPending then
					reshowPending = false
					return
				end
				if states[window] ~= "Open" then
					open()
				end
			else
				if hidingByUs then
					hidingByUs = false
					return
				end
				if states[window] == "Open" then
					close()
				elseif states[window] == "Closing" then
					reshowPending = true
					window.Visible = true
				end
			end
		end)
		-- Clearing "Closing" mid-shrink reopens the window (Visible is already true then).
		window:GetAttributeChangedSignal("Closing"):Connect(function()
			if states[window] == "Closing" and not window:GetAttribute("Closing") then
				open()
			end
		end)
		window.Destroying:Connect(function()
			states[window] = nil
		end)
	end

	for _, child in screen:GetChildren() do
		attach(child)
	end
	screen.ChildAdded:Connect(attach)
	if anyOpen() then
		refreshBackdrop()
	end
end

return MenuMotion
