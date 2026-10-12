-- Game-feel presets for the interface, built on Spring: buttons that grow on hover, squish on
-- press and bounce back, pops, shakes, shine sweeps, pulsing badges, counting numbers and coins
-- that fly into a counter. Every effect is purely visual and safe to call repeatedly.
--
-- Scaling uses a "Juice" UIScale on the object. Objects placed by a UIListLayout / UIGridLayout
-- should sit inside a fixed-size slot frame (UIKit.slot) so their bounce never shifts the layout;
-- buttons directly inside a layout only get the hover glow.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)
local Spring = require(script.Parent.Spring)

local Motion = {}

-- Spring feels: { frequency, damping }.
local PRESS = { 6, 0.45 }
local POP = { 3.2, 0.55 }
local PUNCH = { 4, 0.3 }
local WOBBLE = { 7, 0.22 }
local GLOW = { 8, 1 }

local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.9

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local DENY = Color3.fromRGB(220, 70, 58)

local function isTouch(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function vary(spread: number): number
	return 1 + (math.random() * 2 - 1) * spread
end

local function inLayout(gui: GuiObject): boolean
	local parent = gui.Parent
	return parent ~= nil and parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

-- The object's own UIScale for animation (nil if it already has a different UIScale).
local function juiceScale(gui: GuiObject): UIScale?
	local scale = gui:FindFirstChild("Juice")
	if scale and scale:IsA("UIScale") then
		return scale
	end
	if gui:FindFirstChildOfClass("UIScale") then
		return nil
	end
	local created = Instance.new("UIScale")
	created.Name = "Juice"
	created.Parent = gui
	return created
end

-- Sizes `child` to cover `parent` exactly (undoing the parent's UIPadding), shrunk by `inset`.
function Motion.cover(child: GuiObject, parent: GuiObject, inset: number?)
	local padding = parent:FindFirstChildOfClass("UIPadding")
	local left, right, top, bottom = 0, 0, 0, 0
	if padding then
		left, right = padding.PaddingLeft.Offset, padding.PaddingRight.Offset
		top, bottom = padding.PaddingTop.Offset, padding.PaddingBottom.Offset
	end
	local gap = inset or 0
	child.Position = UDim2.fromOffset(-left + gap, -top + gap)
	child.Size = UDim2.new(1, left + right - gap * 2, 1, top + bottom - gap * 2)
end

-- Overlay frame (same shape as `gui`) used for glows, flashes and shines.
local function overlay(gui: GuiObject, name: string): Frame
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = 8
	frame.Active = false
	frame.Selectable = false
	Motion.cover(frame, gui)
	local corner = gui:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = frame
	end
	frame.Parent = gui
	return frame
end

local selectionFrame: Frame? = nil
local function selectionImage(): Frame
	if not selectionFrame then
		local frame = Instance.new("Frame")
		frame.Name = "GoldSelection"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 8, 1, 8)
		frame.Position = UDim2.fromOffset(-4, -4)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(240, 200, 110)
		stroke.Thickness = 3
		stroke.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame
		selectionFrame = frame
	end
	return selectionFrame :: Frame
end

-- Fires with the button whenever a disabled button is pressed (Toasts explains unaffordable costs).
local deniedEvent = Instance.new("BindableEvent")
Motion.Denied = deniedEvent.Event

-- Disabled buttons don't grow, and pressing them shakes "no" instead of clicking.
function Motion.setDisabled(button: GuiButton, disabled: boolean)
	button:SetAttribute("Disabled", disabled or nil)
end

-- Hover grow + glow, press squish, bouncy release, click/hover sounds, gold gamepad outline.
function Motion.button(button: GuiButton)
	if button:GetAttribute("Juiced") then
		return
	end
	button:SetAttribute("Juiced", true)
	button.AutoButtonColor = false
	button.SelectionImageObject = selectionImage()
	local hovered, pressed = false, false

	local function refresh()
		local disabled = button:GetAttribute("Disabled") == true
		if not inLayout(button) then
			local scale = juiceScale(button)
			if scale then
				local goal = if pressed then PRESS_SCALE elseif hovered and not disabled then HOVER_SCALE else 1
				Spring.target(scale, PRESS[1], PRESS[2], { Scale = goal })
			end
		end
		local glow = overlay(button, "HoverGlow")
		glow.BackgroundColor3 = if pressed then BLACK else WHITE
		local goal = if pressed then 0.78 elseif hovered and not disabled then 0.86 else 1
		Spring.target(glow, GLOW[1], GLOW[2], { BackgroundTransparency = goal })
	end

	local function hover(on: boolean)
		if on == hovered then
			return
		end
		hovered = on
		if on and button:GetAttribute("Disabled") ~= true then
			Sounds.Play("Hover", nil, vary(0.06))
		end
		refresh()
	end

	button.MouseEnter:Connect(function()
		if not isTouch() then
			hover(true)
		end
	end)
	button.MouseLeave:Connect(function()
		pressed = false
		hover(false)
		refresh()
	end)
	button.SelectionGained:Connect(function()
		hover(true)
	end)
	button.SelectionLost:Connect(function()
		pressed = false
		hover(false)
	end)
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			pressed = true
			refresh()
		end
	end)
	button.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			pressed = false
			if kind == Enum.UserInputType.Touch then
				hovered = false
			end
			refresh()
		end
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") == true then
			Motion.deny(button)
			deniedEvent:Fire(button)
		else
			Sounds.Play("Click", nil, vary(0.05))
		end
	end)
end

-- Scales in from nothing (or `from`) after `delay` seconds, overshooting slightly.
function Motion.pop(gui: GuiObject, delay: number?, from: number?)
	local scale = juiceScale(gui)
	if not scale then
		return
	end
	scale.Scale = from or 0
	local function go()
		if gui.Parent then
			Spring.target(scale, POP[1], POP[2], { Scale = 1 })
		end
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

-- A quick "boing": the object swells and settles back. `strength` is extra scale speed.
function Motion.punch(gui: GuiObject, strength: number?)
	local scale = juiceScale(gui)
	if scale then
		Spring.impulse(scale, PUNCH[1], PUNCH[2], { Scale = strength or 2.5 })
	end
end

-- A side-to-side wobble (rotation), for "no" and attention.
function Motion.shake(gui: GuiObject, strength: number?)
	Spring.impulse(gui, WOBBLE[1], WOBBLE[2], { Rotation = strength or 160 })
end

-- Briefly tints the object (white by default) and fades back.
function Motion.flash(gui: GuiObject, color: Color3?, from: number?)
	local frame = overlay(gui, "Flash")
	frame.ZIndex = 9
	frame.BackgroundColor3 = color or WHITE
	frame.BackgroundTransparency = from or 0.35
	TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- Refusal feedback: red flash, wobble and the error sound.
function Motion.deny(gui: GuiObject)
	Motion.flash(gui, DENY, 0.45)
	Motion.shake(gui)
	Sounds.Play("Error", nil, vary(0.04))
end

-- A successful purchase or upgrade: gold flash, a bounce and the purchase sound.
function Motion.purchased(gui: GuiObject)
	Motion.flash(gui, Color3.fromRGB(240, 194, 104), 0.5)
	Motion.punch(gui, 0.8)
	Sounds.Play("Upgrade", nil, vary(0.03))
end

-- One diagonal light sweep across the object.
function Motion.shine(gui: GuiObject, seconds: number?)
	local frame = overlay(gui, "Shine")
	frame.ZIndex = 9
	frame.BackgroundTransparency = 0.25
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Rotation = 25
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
	end
	local sweep = gradient :: UIGradient
	sweep.Offset = Vector2.new(-1, 0)
	TweenService:Create(
		sweep,
		TweenInfo.new(seconds or 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Offset = Vector2.new(1, 0) }
	):Play()
end

-- Repeats `effect(gui)` every `interval` seconds while the object exists and `active()` is true.
-- Returns a function that stops the loop.
local function every(gui: GuiObject, interval: number, active: (() -> boolean)?, effect: (GuiObject) -> ()): () -> ()
	local running = true
	task.spawn(function()
		while running and gui.Parent do
			if (not active or active()) and gui.Visible then
				effect(gui)
			end
			task.wait(interval)
		end
	end)
	return function()
		running = false
	end
end

function Motion.shineLoop(gui: GuiObject, interval: number, active: (() -> boolean)?): () -> ()
	return every(gui, interval, active, function(target)
		Motion.shine(target)
	end)
end

-- Notification badges breathe so they catch the eye without flashing.
function Motion.badge(gui: GuiObject): () -> ()
	return every(gui, 1.3, nil, function(target)
		Motion.punch(target, 3)
	end)
end

-- Rolls a label's number toward each new value instead of jumping. Returns `set(value, instant?)`.
function Motion.counter(label: TextLabel, format: (number) -> string): (number, boolean?) -> ()
	local value = Instance.new("NumberValue")
	value.Name = "Counter"
	value.Parent = label
	local tween: Tween? = nil
	value.Changed:Connect(function(current)
		label.Text = format(current)
	end)
	return function(target: number, instant: boolean?)
		if tween then
			tween:Cancel()
			tween = nil
		end
		local from = value.Value
		if instant or from == target then
			value.Value = target
			label.Text = format(target)
			return
		end
		local ratio = math.abs(target - from) / math.max(1, math.abs(from))
		local seconds = math.clamp(0.3 + ratio * 0.4, 0.3, 0.9)
		local created = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Quint), { Value = target })
		tween = created
		created:Play()
	end
end

-- Text that rises and fades (e.g. "+120"). `position` is inside `parent`.
function Motion.floatText(parent: GuiObject, text: string, color: Color3, position: UDim2, font: Enum.Font?)
	local label = Instance.new("TextLabel")
	label.Name = "FloatText"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = position
	label.Size = UDim2.fromOffset(160, 24)
	label.Font = font or Enum.Font.FredokaOne
	label.Text = text
	label.TextSize = 20
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 20
	label.Parent = parent
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad)
	TweenService:Create(label, info, {
		Position = position + UDim2.fromOffset(0, -30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		label:Destroy()
	end)
end

-- Coins burst out at `from` (screen pixels inside `screen`) and fly into `target`, one after
-- another; `onArrive(index)` runs as each lands (pulse the counter, tick a rising coin sound).
function Motion.flyCoins(
	screen: ScreenGui,
	from: Vector2,
	target: GuiObject,
	count: number,
	makeCoin: () -> GuiObject,
	onArrive: (number) -> ()
)
	local total = if Settings.LowEffects() then math.min(count, 4) else count
	local coins = {}
	for index = 1, total do
		local coin = makeCoin()
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromOffset(from.X, from.Y)
		coin.ZIndex = 30
		coin.Parent = screen
		local angle = math.random() * math.pi * 2
		local radius = 30 + math.random() * 60
		table.insert(coins, {
			Gui = coin,
			Scatter = from + Vector2.new(math.cos(angle), math.sin(angle)) * radius,
			Start = 0.28 + (index - 1) * 0.05,
			Done = false,
		})
	end
	local SCATTER = 0.25
	local FLIGHT = 0.45
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		local goal = target.AbsolutePosition + target.AbsoluteSize / 2
		local remaining = 0
		for index, coin in coins do
			if coin.Done then
				continue
			end
			remaining += 1
			local position: Vector2
			if elapsed < SCATTER then
				local t = 1 - (1 - elapsed / SCATTER) ^ 3
				position = from:Lerp(coin.Scatter, t)
			elseif elapsed < coin.Start then
				position = coin.Scatter
			else
				local t = math.min(1, (elapsed - coin.Start) / FLIGHT)
				local eased = t * t
				local control = coin.Scatter:Lerp(goal, 0.5) + Vector2.new(0, -80)
				position = coin.Scatter:Lerp(control, eased):Lerp(control:Lerp(goal, eased), eased)
				if t >= 1 then
					coin.Done = true
					coin.Gui:Destroy()
					onArrive(index)
					continue
				end
			end
			coin.Gui.Position = UDim2.fromOffset(position.X, position.Y)
		end
		if remaining == 0 then
			connection:Disconnect()
		end
	end)
end

-- The CE counter registers itself so any screen can pay out coins into it.
local coinTarget: { Target: GuiObject, Pulse: GuiObject, Make: () -> GuiObject }? = nil

function Motion.setCoinTarget(target: GuiObject, pulse: GuiObject, make: () -> GuiObject)
	coinTarget = { Target = target, Pulse = pulse, Make = make }
end

-- Coins fly from `from` (screen pixels) into the CE counter; `onFirst` runs when the first lands.
function Motion.payout(screen: ScreenGui, from: Vector2, count: number, onFirst: (() -> ())?)
	local target = coinTarget
	if not target then
		if onFirst then
			onFirst()
		end
		return
	end
	Motion.flyCoins(screen, from, target.Target, count, target.Make, function(index: number)
		if index == 1 and onFirst then
			onFirst()
		end
		Motion.punch(target.Pulse, 1.2)
		Sounds.Play("Coin", nil, 1 + index * 0.05)
	end)
end

-- Where the next CE windfall's coins should burst from: a button that just earned CE (e.g. Sell)
-- marks itself; otherwise the screen center. A mark is used once and expires after 3 seconds.
local coinSource: { At: Vector2, Time: number }? = nil

function Motion.markCoinSource(gui: GuiObject)
	coinSource = { At = gui.AbsolutePosition + gui.AbsoluteSize / 2, Time = os.clock() }
end

function Motion.coinSource(screen: ScreenGui): Vector2
	local mark = coinSource
	coinSource = nil
	if mark and os.clock() - mark.Time < 3 then
		return mark.At
	end
	return screen.AbsoluteSize / 2
end

return Motion
