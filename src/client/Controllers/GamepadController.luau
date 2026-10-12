-- Controller support for menus (GDD 12.2: controller is part of feature acceptance).
--   View/Select button: jump into the open menu (or the HUD buttons); press again to leave.
--   D-pad / left stick: move between buttons (Roblox UI navigation). A: press.
--   B: close the open menu (also skips a big reveal, see RevealController).
-- When a menu opens while playing with a gamepad, its first button is selected automatically.
-- Hunting keeps its own buttons (Y Spirit Sight, R1 pulse, hold X to bind).

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local RevealController = require(script.Parent.RevealController)

local GamepadController = {}

local GAMEPAD_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

local function usingGamepad(): boolean
	return GAMEPAD_INPUTS[UserInputService:GetLastInputType()] == true
end

local function isShown(object: GuiObject): boolean
	local current: Instance? = object
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

-- Topmost-left visible button inside `root`, skipping the window's close button.
local function firstButton(root: Instance): GuiButton?
	local best: GuiButton? = nil
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Name ~= "Close" and descendant.Selectable and isShown(descendant) then
			if
				not best
				or descendant.AbsolutePosition.Y < best.AbsolutePosition.Y - 2
				or (
					math.abs(descendant.AbsolutePosition.Y - best.AbsolutePosition.Y) <= 2
					and descendant.AbsolutePosition.X < best.AbsolutePosition.X
				)
			then
				best = descendant
			end
		end
	end
	return best
end

local function openModals(screen: ScreenGui): { GuiObject }
	local result = {}
	for _, child in screen:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("Modal") and child.Visible and not child:GetAttribute("Closing") then
			table.insert(result, child)
		end
	end
	return result
end

function GamepadController.Start(screen: ScreenGui, hudButtons: () -> Instance?)
	GuiService.AutoSelectGuiEnabled = false

	local function focus()
		local modal = openModals(screen)[1]
		local root = modal or hudButtons()
		local button = root and firstButton(root)
		if button then
			GuiService.SelectedObject = button
		end
	end

	-- Auto-select inside menus opened while using a gamepad.
	local function watchModal(child: Instance)
		if not child:IsA("GuiObject") or not child:GetAttribute("Modal") then
			return
		end
		child:GetPropertyChangedSignal("Visible"):Connect(function()
			local closing = child:GetAttribute("Closing") == true
			if child.Visible and not closing and usingGamepad() then
				task.defer(focus)
			elseif closing or not child.Visible then
				local selected = GuiService.SelectedObject
				if selected and selected:IsDescendantOf(child) then
					GuiService.SelectedObject = nil
				end
			end
		end)
	end
	for _, child in screen:GetChildren() do
		watchModal(child)
	end
	screen.ChildAdded:Connect(watchModal)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonSelect then
			if GuiService.SelectedObject then
				GuiService.SelectedObject = nil
			else
				focus()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonB and not RevealController.IsShowingLarge() then
			local modals = openModals(screen)
			for _, modal in modals do
				modal.Visible = false
			end
			if #modals > 0 or GuiService.SelectedObject then
				GuiService.SelectedObject = nil
			end
		end
	end)
end

return GamepadController
