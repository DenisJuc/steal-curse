-- Showcases menu (GDD 6.7, 10), opened from the Shrine. Lists the three Showcases: how to unlock
-- each, its level and bonus, Upgrade, Set active and the accessory toggles. Every Showcase gives
-- the same bonus at the same level; only the active one counts. Switching is free. The server
-- validates everything and answers with the fresh state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local ShowcaseConfig = require(ReplicatedStorage.Shared.ShowcaseConfig)
local Showcases = require(ReplicatedStorage.Shared.Showcases)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShowcaseAction = Remotes:WaitForChild("ShowcaseAction") :: RemoteFunction

local ShowcasePanel = {}

local ROW_HEIGHT = 132
local LIST_TOP = 66
local FOOTER_HEIGHT = 34

local STYLE_COLORS = {
	Stance = Color3.fromRGB(150, 210, 255),
	Throne = Color3.fromRGB(235, 80, 90),
	Guardian = Color3.fromRGB(255, 200, 80),
}

type State = {
	Active: string,
	Owned: { [string]: number },
	AccessoriesOff: { [string]: boolean },
	AccessoriesUnlocked: { [string]: boolean },
}

local function percent(value: number): string
	return `{Format.number(value * 100)}%`
end

local function bonusText(level: number): string
	local stats = ShowcaseConfig.Levels[level]
	return `+{percent(stats.Income)} income, +{percent(stats.Luck)} luck`
end

local function relicName(relicId: string?): string
	local relic = relicId and RelicConfig.ById[relicId]
	return if relic then relic.Name else (relicId or "?")
end

local function unlockText(showcase: ShowcaseConfig.Showcase): string
	local unlock = showcase.Unlock
	if unlock.Kind == "CE" then
		return `Unlock for {Format.number(unlock.Price or 0)} CE`
	elseif unlock.Kind == "Relic" then
		return `Unlocks when you discover {relicName(unlock.RelicId)}`
	end
	local milestone = unlock.Milestone and CodexBook.ById[unlock.Milestone]
	return if milestone then `Codex: {Codex.goalText(CodexBook, milestone)}` else "Codex milestone"
end

function ShowcasePanel.Start(
	screen: ScreenGui,
	onBack: () -> ()
): { Open: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local state: State? = nil
	local costButtons: { { Button: TextButton, Cost: number } } = {}

	local panel, content = UIKit.modal(screen, "ShowcaseMenu", "SHOWCASES", colors.Gold, Vector2.new(560, 640))

	local activeLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -130, 0, 32),
		Parent = content,
	})
	UIKit.button({
		Text = "< Pedestals",
		BackgroundColor3 = colors.Card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(120, 32),
		Parent = content,
	}, onBack)
	local infoLabel = UIKit.label({
		TextSize = 13,
		TextColor3 = colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = content,
	})
	local list = UIKit.scrollList(content, 6)
	list.Position = UDim2.fromOffset(0, LIST_TOP)
	list.Size = UDim2.new(1, 0, 1, -(LIST_TOP + FOOTER_HEIGHT))
	UIKit.label({
		Text = "Same bonus at the same level for every Showcase. Only the active one counts; switching is free. "
			.. "Pose on your Showcase podium (G) - optional.",
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = colors.SubText,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		Parent = content,
	})

	local render: () -> ()

	local function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			local affordable = ce + 1e-9 >= entry.Cost
			entry.Button.BackgroundColor3 = if affordable then colors.Accent else colors.Card
			entry.Button.TextColor3 = if affordable then colors.Text else colors.SubText
		end
	end

	local function send(action: string, argument: any?)
		task.spawn(function()
			local ok, result = pcall(function()
				return ShowcaseAction:InvokeServer(action, argument)
			end)
			if ok and type(result) == "table" and type(result.State) == "table" then
				state = result.State
				if result.Message then
					infoLabel.Text = result.Message
				end
				render()
			end
		end)
	end

	local function rowButton(row: Instance, text: string, width: number, x: number, onClick: () -> ()): TextButton
		return UIKit.button({
			Text = text,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, x, 0, 8),
			Size = UDim2.fromOffset(width, 30),
			Parent = row,
		}, onClick)
	end

	function render()
		costButtons = {}
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local current = state
		if not current then
			return
		end
		local activeLevel = current.Owned[current.Active]
		local active = ShowcaseConfig.ById[current.Active]
		activeLabel.Text = if active and activeLevel
			then `Active: {active.Name} Lv {activeLevel}  ({bonusText(activeLevel)})`
			else "No active Showcase yet"

		for index, showcase in ShowcaseConfig.Showcases do
			local level = current.Owned[showcase.Id]
			local isActive = current.Active == showcase.Id and level ~= nil
			local accent = STYLE_COLORS[showcase.Style] or colors.Text
			local row = UIKit.create("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
				BackgroundColor3 = colors.Card,
				BackgroundTransparency = if level then 0 else 0.35,
				Parent = list,
			}, { UIKit.corner(10), UIKit.stroke(colors.Gold, 2, if isActive then 0 else 1) })
			UIKit.label({
				Text = if level then `{showcase.Name}  Lv {level}/{ShowcaseConfig.MaxLevel}` else showcase.Name,
				TextSize = 17,
				TextColor3 = accent,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -240, 0, 22),
				Parent = row,
			})
			UIKit.label({
				Text = showcase.Description,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 44),
				Size = UDim2.new(1, -20, 0, 16),
				Parent = row,
			})
			local detail
			if level then
				local nextCost = Showcases.upgradeCost(ShowcaseConfig.Levels, level)
				detail = if nextCost
					then `{bonusText(level)}   Next: {bonusText(level + 1)}`
					else `{bonusText(level)}   (max level)`
			else
				detail = unlockText(showcase)
			end
			UIKit.label({
				Text = detail,
				TextSize = 13,
				TextColor3 = if level then Color3.fromRGB(170, 230, 255) else colors.Gold,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 64),
				Size = UDim2.new(1, -20, 0, 18),
				Parent = row,
			})

			local showcaseId = showcase.Id
			if level then
				local activeButton = rowButton(row, if isActive then "Active" else "Set active", 96, -8, function()
					if not isActive then
						send("Activate", showcaseId)
					end
				end)
				if isActive then
					activeButton.BackgroundColor3 = colors.Gold
					activeButton.TextColor3 = colors.Panel
					activeButton.AutoButtonColor = false
				end
				local cost = Showcases.upgradeCost(ShowcaseConfig.Levels, level)
				if cost then
					local upgrade = rowButton(row, `Lv+ {Format.number(cost)}`, 110, -110, function()
						send("Upgrade", showcaseId)
					end)
					table.insert(costButtons, { Button = upgrade, Cost = cost })
				end
			elseif showcase.Unlock.Kind == "CE" and showcase.Unlock.Price then
				local price = showcase.Unlock.Price
				local buy = rowButton(row, `Unlock {Format.number(price)}`, 130, -8, function()
					send("Unlock", showcaseId)
				end)
				table.insert(costButtons, { Button = buy, Cost = price })
			end

			-- Accessories (cosmetic): toggle once unlocked; otherwise say which relic unlocks them.
			for accessoryIndex, accessory in showcase.Accessories do
				local unlocked = current.AccessoriesUnlocked[accessory.Id] == true
				local on = unlocked and not current.AccessoriesOff[accessory.Id]
				local text = if not unlocked
					then `{accessory.Name}: discover {relicName(accessory.RelicId)}`
					elseif on then `{accessory.Name}: shown`
					else `{accessory.Name}: hidden`
				local toggle = UIKit.button({
					Text = text,
					TextSize = 12,
					BackgroundColor3 = if on then colors.Accent else colors.Panel,
					TextColor3 = if unlocked then colors.Text else colors.SubText,
					AutoButtonColor = unlocked,
					Position = UDim2.fromOffset(10, 90 + (accessoryIndex - 1) * 34),
					Size = UDim2.new(1, -20, 0, 30),
					Parent = row,
				}, function()
					if unlocked then
						send("ToggleAccessory", accessory.Id)
					end
				end)
				toggle.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end
		refreshAffordability()
	end

	player:GetAttributeChangedSignal("CE"):Connect(refreshAffordability)

	return {
		Open = function()
			panel.Visible = true
			infoLabel.Text = "Unlock, upgrade and pick the Showcase on your plot's podium."
			send("Get")
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return ShowcasePanel
