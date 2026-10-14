-- Sprint: hold Shift (keyboard), press L3 (gamepad, toggles) or the touch Run button (toggles) to
-- run at Config.Sprint.Multiplier x the walk speed the server sets (BaseWalkSpeed attribute, Swift
-- Step included). Stamina math lives in Shared/Stamina; a slim screen bar just above the bottom
-- ROLL bar shows it while it is not full (a bar under your feet got covered when zoomed in).
-- A WalkSpeed of 0 means a bind froze you (HuntController): sprint stays out of it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local Stamina = require(ReplicatedStorage.Shared.Stamina)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local SprintController = {}

local ACTION = "Sprint"
local BAR_SIZE = Vector2.new(200, 10)
local BAR_COLOR = Color3.fromRGB(150, 220, 255)
local WINDED_COLOR = Color3.fromRGB(235, 80, 80)
-- Seconds a full bar stays before fading out.
local HIDE_DELAY = 0.6

local function makeBar(screen: ScreenGui): (Frame, Frame, Frame)
	local holder = UIKit.create("Frame", {
		Name = "StaminaBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(BAR_SIZE.X + 22, BAR_SIZE.Y + 8),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	UIKit.scaler(holder)
	UIKit.label({
		Name = "Icon",
		Text = "\u{00BB}",
		TextSize = 18,
		TextColor3 = BAR_COLOR,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Parent = holder,
	})
	local back = UIKit.create("Frame", {
		Name = "Back",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
		BackgroundColor3 = Color3.fromRGB(18, 14, 28),
		BackgroundTransparency = 0.25,
		Parent = holder,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, Transparency = 0.2 }),
	})
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BAR_COLOR,
		Parent = back,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	return holder, back, fill
end

-- `anchor` is the bottom ROLL bar: the stamina bar sits centred just above it.
function SprintController.Start(screen: ScreenGui, anchor: GuiObject?)
	local player = Players.LocalPlayer
	local cfg = Config.Sprint
	local state = Stamina.new()
	local held, toggled = false, false
	local fullFor = math.huge
	local holder, back, fill = makeBar(screen)
	local icon = holder:FindFirstChild("Icon") :: TextLabel

	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState, input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			held = inputState == Enum.UserInputState.Begin
		elseif inputState == Enum.UserInputState.Begin then
			toggled = not toggled
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle(ACTION, "Run")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -170, 1, -150))

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and humanoid and humanoid.Health > 0) then
			held, toggled = false, false
			holder.Visible = false
			return
		end
		local frozen = humanoid.WalkSpeed == 0
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		Stamina.step(state, dt, (held or toggled) and not frozen, moving, cfg)
		if state.Winded then
			toggled = false
		end
		if not frozen then
			local base = character:GetAttribute("BaseWalkSpeed")
			local walk = if type(base) == "number" then base else SkillConfig.walkSpeed(0)
			local speed = Stamina.speed(walk, state.Running, cfg.Multiplier, cfg.MaxSpeed)
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
		fullFor = if state.Value >= 1 then fullFor + dt else 0
		holder.Visible = fullFor < HIDE_DELAY and player:GetAttribute("HideInterface") ~= true
		if not holder.Visible then
			return
		end
		if anchor then
			local offset = anchor.AbsolutePosition - screen.AbsolutePosition
			holder.Position = UDim2.fromOffset(offset.X + anchor.AbsoluteSize.X / 2, offset.Y - 2)
		end
		fill.Size = UDim2.fromScale(state.Value, 1)
		local color = if state.Winded then WINDED_COLOR else BAR_COLOR
		fill.BackgroundColor3 = color
		icon.TextColor3 = color
		back.BackgroundTransparency = if state.Winded then 0.1 else 0.25
	end)
end

return SprintController
