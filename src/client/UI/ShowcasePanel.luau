-- Showcases menu (GDD 6.7, 10), opened from the Shrine. Lists every Showcase: how to unlock
-- each, its level and bonus, Upgrade, Set active and the accessory toggles. Every Showcase gives
-- the same bonus at the same level; only the active one counts. Switching is free. The server
-- validates everything and answers with the fresh state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local ShowcaseConfig = require(ReplicatedStorage.Shared.ShowcaseConfig)
local Showcases = require(ReplicatedStorage.Shared.Showcases)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShowcaseAction = Remotes:WaitForChild("ShowcaseAction") :: RemoteFunction

local ShowcasePanel = {}

local ROW_HEIGHT = 132
local LIST_TOP = 66
local FOOTER_HEIGHT = 34
local PRICE_WIDTH = 150

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
	UnlockProgress: { [string]: { Have: number, Need: number } }?,
}

local PROGRESS_WIDTH = 110

local function setProgress(holder: Frame, have: number, need: number)
	local fraction = if need > 0 then math.clamp(have / need, 0, 1) else 0
	local count = holder:FindFirstChild("Count") :: TextLabel
	count.Text = `{Format.number(math.floor(math.min(have, need)))} / {Format.number(need)}`
	local fill = (holder:FindFirstChild("Track") :: Frame):FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = if fraction >= 1 then UIKit.Colors.Gold else UIKit.Colors.Jade
end

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
		return `buy it for {Format.number(unlock.Price or 0)} CE`
	elseif unlock.Kind == "Relic" then
		return `discover {relicName(unlock.RelicId)}`
	elseif unlock.Kind == "Mastery" then
		local name = unlock.Area or "?"
		for _, area in Config.Areas do
			if area.Id == unlock.Area then
				name = area.Name
			end
		end
		return `reach {name} mastery {unlock.Level or "?"} (capture signals there)`
	end
	local milestone = unlock.Milestone and CodexBook.ById[unlock.Milestone]
	return if milestone then `Codex: {Codex.goalText(CodexBook, milestone)}` else "a Codex milestone"
end

function ShowcasePanel.Start(
	screen: ScreenGui,
	onBack: () -> ()
): { Open: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local state: State? = nil
	local costButtons: { { Button: TextButton, Cost: number } } = {}
	local ceBars: { { Bar: Frame, Price: number } } = {}

	local panel, content =
		UIKit.modal(screen, "ShowcaseMenu", "SHOWCASES", colors.Gold, Vector2.new(560, 640), "Shrine")

	local activeLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -130, 0, 32),
		Parent = content,
	})
	local back = UIKit.button({
		Text = "< Pedestals",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -60, 0, 16),
		Size = UDim2.fromOffset(120, 32),
		Parent = content,
	}, onBack)
	UIKit.skinButton(back, "Dark")
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

	-- Unlock progress at the right of a locked row: "3 / 5" over a slim bar.
	local function progressBar(row: Instance, have: number, need: number): Frame
		local holder = UIKit.create("Frame", {
			Name = "Progress",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 58),
			Size = UDim2.fromOffset(PROGRESS_WIDTH, 28),
			BackgroundTransparency = 1,
			Parent = row,
		})
		UIKit.label({
			Name = "Count",
			TextSize = 12,
			TextColor3 = colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 14),
			Parent = holder,
		})
		local track = UIKit.create("Frame", {
			Name = "Track",
			Position = UDim2.fromOffset(0, 17),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = colors.Track,
			Parent = holder,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		UIKit.create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = colors.Jade,
			Parent = track,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		setProgress(holder, have, need)
		return holder
	end

	local function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			UIKit.setAffordable(entry.Button, ce + 1e-9 >= entry.Cost, entry.Cost)
		end
		for _, entry in ceBars do
			setProgress(entry.Bar, ce, entry.Price)
		end
	end

	local rowsById: { [string]: Frame } = {}

	local function send(action: string, argument: any?)
		task.spawn(function()
			local ok, result = pcall(function()
				return ShowcaseAction:InvokeServer(action, argument)
			end)
			if ok and type(result) == "table" and type(result.State) == "table" then
				local before = if state then table.clone(state.Owned) else {}
				local activeBefore = state and state.Active
				state = result.State
				if result.Message then
					infoLabel.Text = result.Message
				end
				render()
				local current = state :: State
				for id, level in current.Owned do
					local row = rowsById[id]
					if row and level > (before[id] or 0) then
						Motion.purchased(row)
					elseif row and id == current.Active and id ~= activeBefore then
						Motion.punch(row, 0.8)
					end
				end
			end
		end)
	end

	local function rowButton(row: Instance, text: string, width: number, x: number, onClick: () -> ()): TextButton
		local button = UIKit.button({
			Text = text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, x - width / 2, 0, 23),
			Size = UDim2.fromOffset(width, 30),
			Parent = row,
		}, onClick)
		UIKit.skinButton(button, "Primary")
		return button
	end

	local function priceButton(row: Instance, verb: string, cost: number, x: number, onClick: () -> ()): TextButton
		return UIKit.priceButton({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0, 23),
			Size = UDim2.fromOffset(PRICE_WIDTH, 30),
			TextSize = 15,
			Parent = row,
		}, verb, cost, onClick)
	end

	function render()
		costButtons = {}
		ceBars = {}
		rowsById = {}
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
			local holder = UIKit.slot(list, showcase.Id, UDim2.new(1, -10, 0, ROW_HEIGHT), index)
			local row = UIKit.create("Frame", {
				Name = "Card",
				BackgroundColor3 = colors.Card,
				BackgroundTransparency = if level then 0 else 0.35,
				Parent = holder,
			}, { UIKit.corner(10) })
			UIKit.fill(row)
			UIKit.skinCard(row, if isActive then colors.Gold else nil)
			row:SetAttribute("PopIn", true)
			rowsById[showcase.Id] = row
			UIKit.label({
				Text = if level then `{showcase.Name}  Lv {level}/{ShowcaseConfig.MaxLevel}` else showcase.Name,
				TextSize = 17,
				TextColor3 = accent,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -(120 + PRICE_WIDTH), 0, 22),
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
				Text = if level then detail else `How to unlock: {detail}`,
				TextSize = 13,
				TextColor3 = if level then Color3.fromRGB(170, 230, 255) else colors.Gold,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 64),
				Size = UDim2.new(1, if level then -20 else -(PROGRESS_WIDTH + 30), 0, 18),
				Parent = row,
			})
			if not level then
				local unlock = showcase.Unlock
				local progress = (current.UnlockProgress or {})[showcase.Id]
				if unlock.Kind == "CE" and unlock.Price then
					local bar = progressBar(row, 0, unlock.Price)
					table.insert(ceBars, { Bar = bar, Price = unlock.Price })
				elseif progress then
					progressBar(row, progress.Have, progress.Need)
				end
			end

			local showcaseId = showcase.Id
			if level then
				local activeButton = rowButton(row, if isActive then "Active" else "Set active", 96, -8, function()
					if not isActive then
						send("Activate", showcaseId)
					end
				end)
				if isActive then
					UIKit.skinButton(activeButton, "Gold")
				end
				local cost = Showcases.upgradeCost(ShowcaseConfig.Levels, level)
				if cost then
					local upgrade = priceButton(row, "Upgrade", cost, -110, function()
						send("Upgrade", showcaseId)
					end)
					table.insert(costButtons, { Button = upgrade, Cost = cost })
				end
			elseif showcase.Unlock.Kind == "CE" and showcase.Unlock.Price then
				local price = showcase.Unlock.Price
				local buy = priceButton(row, "Unlock", price, -8, function()
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
					Position = UDim2.fromOffset(10, 90 + (accessoryIndex - 1) * 34),
					Size = UDim2.new(1, -20, 0, 30),
					Parent = row,
				}, function()
					send("ToggleAccessory", accessory.Id)
				end)
				UIKit.skinButton(toggle, if on then "Primary" else "Dark")
				toggle.TextColor3 = if unlocked then colors.Text else colors.SubText
				toggle.TextTruncate = Enum.TextTruncate.AtEnd
				Motion.setDisabled(toggle, not unlocked)
			end
		end
		refreshAffordability()
	end

	player:GetAttributeChangedSignal("CE"):Connect(refreshAffordability)

	return {
		Open = function()
			UIKit.show(panel)
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
