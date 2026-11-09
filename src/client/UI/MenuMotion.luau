-- Menu windows (UIKit.modal) open with a springy pop and close with a quick shrink. While a menu
-- is open the world behind it is blurred (not on Low effects) and dimmed, and clicking empty space
-- (or Escape / Backspace) closes it; the HUD stays bright and clickable.
-- RULE: a click closes menus only when its position is outside every open (or closing) window and
-- outside every visible "MenuPopup" layer. Never rely on Active/input sinking for this: clicks on
-- labels, images, scroll gaps or parts that stick out of a window reach the backdrop anyway. A popup
-- parented outside its window gets the "MenuPopup" attribute so clicks on it count as inside.
-- Panels keep simply setting window.Visible: on a
-- close this module shows the window again until the shrink finishes (marked with the "Closing"
-- attribute so controller support can ignore it; clearing it reopens the window).

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Motion = require(script.Parent.Motion)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local Spring = require(script.Parent.Spring)
local UIKit = require(script.Parent.UIKit)

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
-- Extra pixels around a window that still count as inside it (edge strokes, shadows, near-misses).
local INSIDE_MARGIN = 6

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

	local function closeAll()
		for window, state in states do
			if state == "Open" then
				window.Visible = false
			end
		end
	end

	local function within(object: GuiObject, point: Vector2, margin: number): boolean
		local topLeft, size = object.AbsolutePosition, object.AbsoluteSize
		return point.X >= topLeft.X - margin
			and point.Y >= topLeft.Y - margin
			and point.X <= topLeft.X + size.X + margin
			and point.Y <= topLeft.Y + size.Y + margin
	end

	-- True when the hit object is really drawn at the point: visible all the way up, and not
	-- clipped away by a ScrollingFrame / ClipsDescendants ancestor (scrolled-off rows don't count).
	local function shownAt(object: GuiObject, point: Vector2): boolean
		local node: Instance? = object
		while node and node ~= screen do
			if node:IsA("GuiObject") then
				if not node.Visible then
					return false
				end
				if node ~= object and (node.ClipsDescendants or node:IsA("ScrollingFrame")) and not within(node, point, 0) then
					return false
				end
			end
			node = node.Parent
		end
		return true
	end

	local function isMenuLayer(object: Instance): boolean
		local node: Instance? = object
		while node and node ~= screen do
			if node == backdrop then
				return false
			end
			if node:GetAttribute("MenuPopup") or (node:IsA("GuiObject") and states[node] and states[node] ~= "Closed") then
				return true
			end
			node = node.Parent
		end
		return false
	end

	-- Both checks use ScreenGui space (AbsolutePosition): an InputObject's Position already is that
	-- space unless the ScreenGui ignores the top-bar inset.
	local function insideAnyMenu(point: Vector2): boolean
		for window, state in states do
			if state ~= "Closed" and window.Visible and within(window, point, INSIDE_MARGIN) then
				return true
			end
		end
		local player = Players.LocalPlayer
		local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return false
		end
		local hits = playerGui:GetGuiObjectsAtPosition(point.X, point.Y)
		for _, hit in hits do
			if hit ~= backdrop and isMenuLayer(hit) and shownAt(hit, point) then
				return true
			end
		end
		return false
	end

	backdrop.Activated:Connect(function(input: InputObject?)
		if input and input.Position then
			local point = Vector2.new(input.Position.X, input.Position.Y)
			if screen.IgnoreGuiInset then
				point += GuiService:GetGuiInset()
			end
			if insideAnyMenu(point) then
				return
			end
		end
		closeAll()
	end)
	-- Menus have no close button: Escape (or Backspace, since Roblox may keep Escape for its own
	-- menu) closes them too. Gamepad B is handled by GamepadController.
	UserInputService.InputBegan:Connect(function(input, processed)
		local escape = input.KeyCode == Enum.KeyCode.Escape
		if escape or (input.KeyCode == Enum.KeyCode.Backspace and not processed) then
			closeAll()
		end
	end)
	screen:GetPropertyChangedSignal("Enabled"):Connect(refreshBackdrop)
	-- Safety net: whatever toggled it, the backdrop never stays up with no menu open (it is a
	-- full-screen button and would swallow camera drags).
	backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
		if backdrop.Visible and not (anyOpen() and screen.Enabled) then
			task.delay(0.3, function()
				if backdrop.Visible and not (anyOpen() and screen.Enabled) then
					backdrop.Visible = false
				end
			end)
		end
	end)

	local function attach(child: Instance)
		if not child:IsA("GuiObject") or not child:GetAttribute("Modal") then
			return
		end
		local window = child :: GuiObject
		-- Sinks clicks so they don't reach the world; whether a click closes the menu is decided by
		-- position in the backdrop handler (see the rule at the top), not by this.
		window.Active = true
		local juice = window:FindFirstChild("Juice") :: UIScale?
		if not juice then
			local created = Instance.new("UIScale")
			created.Name = "Juice"
			created.Parent = window
			juice = created
		end
		local scale = juice :: UIScale
		-- Resting size: menus grow on big screens (UIKit.menuScale), so text stays readable.
		local function rest(): number
			return UIKit.menuScale()
		end
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
			scale.Scale = OPEN_FROM * rest()
			Spring.target(scale, 3.6, 0.5, { Scale = rest() })
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
				{ Scale = CLOSE_TO * rest() }
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
				scale.Scale = rest()
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
