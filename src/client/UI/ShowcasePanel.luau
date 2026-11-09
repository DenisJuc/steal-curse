-- Showcases menu (GDD 6.7, 10), opened from the Shrine. Reworked 2026-11-09 (the old one was a
-- long list of crowded cards): a short list of Showcases on the left; on the right a turning 3D
-- preview of the picked one (ReplicatedStorage.ShowcasePreviews, built by ShowcaseVisuals) with its
-- level stamps set around the bottom of the view (tap one to preview that level), its bonus, the
-- Unlock / Upgrade / Set active buttons and the accessory chips. Every Showcase gives the same
-- bonus at the same level; only the active one counts. Switching is free. The server validates
-- everything and answers with the fresh state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local PANEL_SIZE = Vector2.new(780, 600)
local TOP = 44
local LIST_WIDTH = 220
local TILE_HEIGHT = 58
local PREVIEW_HEIGHT = 270
local PIP = 34
local SPIN_SPEED = 0.35

local STYLE_COLORS = {
	Stance = Color3.fromRGB(150, 210, 255),
	Throne = Color3.fromRGB(235, 80, 90),
	Guardian = Color3.fromRGB(255, 200, 80),
	Grove = Color3.fromRGB(120, 235, 160),
	Bell = Color3.fromRGB(255, 170, 80),
	Star = Color3.fromRGB(175, 160, 255),
}

type State = {
	Active: string,
	Owned: { [string]: number },
	AccessoriesOff: { [string]: boolean },
	AccessoriesUnlocked: { [string]: boolean },
	UnlockProgress: { [string]: { Have: number, Need: number } }?,
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
		return `Buy it for {Format.number(unlock.Price or 0)} CE`
	elseif unlock.Kind == "Relic" then
		return `Discover {relicName(unlock.RelicId)}`
	elseif unlock.Kind == "Mastery" then
		local name = unlock.Area or "?"
		for _, area in Config.Areas do
			if area.Id == unlock.Area then
				name = area.Name
			end
		end
		return `Reach {name} mastery {unlock.Level or "?"}`
	end
	local milestone = unlock.Milestone and CodexBook.ById[unlock.Milestone]
	return if milestone then `Codex: {Codex.goalText(CodexBook, milestone)}` else "A Codex milestone"
end

function ShowcasePanel.Start(
	screen: ScreenGui,
	onBack: () -> ()
): { Open: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local state: State? = nil
	local selectedId: string = ShowcaseConfig.Showcases[1].Id
	local previewLevel: number? = nil
	local costButtons: { { Button: TextButton, Cost: number } } = {}

	local panel, content = UIKit.modal(screen, "ShowcaseMenu", "SHOWCASES", colors.Gold, PANEL_SIZE, "Pedestals")
	local render: () -> ()

	-- Header: what is active, and the way back.
	local activeLabel = UIKit.label({
		TextSize = 16,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -140, 0, 32),
		Parent = content,
	})
	local back = UIKit.button({
		Text = "< Pedestals",
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(128, 32),
		Parent = content,
	}, onBack)
	UIKit.skinButton(back, "Dark")

	-- Left: the Showcases.
	local list = UIKit.scrollList(content, 6)
	list.Position = UDim2.fromOffset(0, TOP)
	list.Size = UDim2.new(0, LIST_WIDTH, 1, -TOP)

	-- Right: preview + detail.
	local side = UIKit.create("Frame", {
		Name = "Detail",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(LIST_WIDTH + 12, TOP),
		Size = UDim2.new(1, -(LIST_WIDTH + 12), 1, -TOP),
		Parent = content,
	})
	local stage = UIKit.create("Frame", {
		Name = "Stage",
		Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = side,
	}, { UIKit.corner(14) })
	local stageStroke = UIKit.stroke(colors.Trim, 2, 0.3)
	stageStroke.Parent = stage
	local glow = UIKit.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(40, 30, 60), Color3.fromRGB(12, 9, 18)),
		Parent = stage,
	})
	local viewport = UIKit.create("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 170),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
		Size = UDim2.fromScale(1, 1),
		Parent = stage,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local lockedVeil = UIKit.label({
		Name = "Locked",
		Text = "LOCKED",
		FontFace = UIKit.TitleFont,
		TextSize = 22,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 3,
		Parent = stage,
	})
	-- Level stamps on an arc along the bottom of the stage.
	local pips: { TextButton } = {}
	local maxLevel = ShowcaseConfig.MaxLevel
	for level = 1, maxLevel do
		-- A shallow smile under the set piece: ends a little higher than the middle.
		local t = if maxLevel == 1 then 0.5 else (level - 1) / (maxLevel - 1)
		local u = (t - 0.5) * 2
		local x = 0.5 + u * 0.36
		local y = 0.9 - 0.07 * u * u
		local pip = UIKit.button({
			Name = `Level{level}`,
			Text = tostring(level),
			TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(PIP, PIP),
			ZIndex = 4,
			Parent = stage,
		}, function()
			previewLevel = level
			render()
		end)
		pip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		pips[level] = pip
	end

	local nameLabel = UIKit.label({
		Name = "Name",
		FontFace = UIKit.TitleFont,
		TextSize = 24,
		Position = UDim2.fromOffset(2, PREVIEW_HEIGHT + 8),
		Size = UDim2.new(1, -4, 0, 28),
		Parent = side,
	})
	local descLabel = UIKit.label({
		Name = "Description",
		TextSize = 15,
		TextColor3 = colors.SubText,
		TextWrapped = true,
		Position = UDim2.fromOffset(2, PREVIEW_HEIGHT + 38),
		Size = UDim2.new(1, -4, 0, 36),
		Parent = side,
	})
	local bonusLabel = UIKit.label({
		Name = "Bonus",
		TextSize = 17,
		RichText = true,
		TextWrapped = true,
		Position = UDim2.fromOffset(2, PREVIEW_HEIGHT + 76),
		Size = UDim2.new(1, -4, 0, 24),
		Parent = side,
	})
	local actions = UIKit.create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, PREVIEW_HEIGHT + 106),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = side,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local extras = UIKit.create("Frame", {
		Name = "Extras",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, PREVIEW_HEIGHT + 158),
		Size = UDim2.new(1, 0, 1, -(PREVIEW_HEIGHT + 158)),
		Parent = side,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	-- The turning preview model.
	local shownKey = ""
	local shown: Model? = nil
	local spin = 0
	local function showPreview(id: string, level: number)
		local key = `{id}_{level}`
		if key == shownKey and shown then
			return
		end
		shownKey = key
		if shown then
			shown:Destroy()
			shown = nil
		end
		local folder = ReplicatedStorage:FindFirstChild("ShowcasePreviews")
		local source = folder and folder:FindFirstChild(key)
		if not source or not source:IsA("Model") then
			shownKey = ""
			return
		end
		local model = source:Clone()
		model.Parent = viewport
		model:SetAttribute("Home", model:GetPivot())
		shown = model
		local box, size = model:GetBoundingBox()
		local radius = math.max(size.X, size.Z) * 0.5
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.12
		local center = Vector3.new(0, box.Position.Y - size.Y * 0.08, 0)
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * 0.45, -distance), center)
	end
	RunService.RenderStepped:Connect(function(dt)
		local model = shown
		if not panel.Visible or not model or not model.PrimaryPart then
			return
		end
		spin += dt * SPIN_SPEED
		local home = model:GetAttribute("Home")
		if typeof(home) == "CFrame" then
			model:PivotTo(CFrame.Angles(0, spin, 0) * home)
		end
	end)

	local function send(action: string, argument: any?)
		task.spawn(function()
			local ok, result = pcall(function()
				return ShowcaseAction:InvokeServer(action, argument)
			end)
			if ok and type(result) == "table" and type(result.State) == "table" then
				local first = state == nil
				local before = if state then (state :: State).Owned[selectedId] else nil
				state = result.State
				-- Opening the menu starts on the active Showcase.
				if first and (state :: State).Owned[(state :: State).Active] then
					selectedId = (state :: State).Active
				end
				previewLevel = nil
				render()
				local after = (state :: State).Owned[selectedId]
				if after and after ~= before then
					Motion.purchased(stage)
				end
			end
		end)
	end

	local function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			UIKit.setAffordable(entry.Button, ce + 1e-9 >= entry.Cost, entry.Cost)
		end
	end

	local tilesById: { [string]: TextButton } = {}
	local function buildTiles()
		for index, showcase in ShowcaseConfig.Showcases do
			local holder = UIKit.slot(list, showcase.Id, UDim2.new(1, -8, 0, TILE_HEIGHT), index)
			local tile = UIKit.button({
				Name = "Tile",
				Text = "",
				Parent = holder,
			}, function()
				selectedId = showcase.Id
				previewLevel = nil
				render()
			end)
			UIKit.fill(tile)
			UIKit.label({
				Name = "Title",
				Text = showcase.Name,
				TextSize = 17,
				TextColor3 = STYLE_COLORS[showcase.Style] or colors.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -16, 0, 22),
				Parent = tile,
			})
			UIKit.label({
				Name = "Status",
				Text = "",
				TextSize = 14,
				TextColor3 = colors.SubText,
				Position = UDim2.fromOffset(10, 30),
				Size = UDim2.new(1, -16, 0, 18),
				Parent = tile,
			})
			tilesById[showcase.Id] = tile
		end
	end
	buildTiles()

	function render()
		costButtons = {}
		local current = state
		if not current then
			return
		end
		local activeLevel = current.Owned[current.Active]
		local active = ShowcaseConfig.ById[current.Active]
		activeLabel.Text = if active and activeLevel
			then `Active: {active.Name} Lv {activeLevel}  ({bonusText(activeLevel)})`
			else "No active Showcase yet"

		-- Tiles.
		for id, tile in tilesById do
			local showcase = ShowcaseConfig.ById[id]
			local level = current.Owned[id]
			local isActive = current.Active == id and level ~= nil
			local status = tile:FindFirstChild("Status") :: TextLabel
			status.Text = if isActive then `Active  ·  Lv {level}/{maxLevel}`
				elseif level then `Lv {level}/{maxLevel}`
				else "Locked"
			status.TextColor3 = if isActive then colors.Gold elseif level then colors.Text else colors.SubText
			UIKit.skinButton(tile, "Dark")
			local stroke = tile:FindFirstChildOfClass("UIStroke")
			if stroke then
				local selected = id == selectedId
				stroke.Color = if selected then (STYLE_COLORS[showcase.Style] or colors.Gold) elseif isActive then colors.Gold else colors.Trim
				stroke.Thickness = if selected then 3 else 1.5
				stroke.Transparency = if selected or isActive then 0 else 0.55
			end
			tile.BackgroundTransparency = if level then 0 else 0.35
		end

		-- Detail.
		local showcase = ShowcaseConfig.ById[selectedId]
		local accent = STYLE_COLORS[showcase.Style] or colors.Text
		local level = current.Owned[selectedId]
		local isActive = current.Active == selectedId and level ~= nil
		local shownLevel = previewLevel or level or 1
		showPreview(selectedId, shownLevel)
		stageStroke.Color = accent
		glow.Color = ColorSequence.new(accent:Lerp(Color3.fromRGB(20, 14, 30), 0.78), Color3.fromRGB(10, 8, 15))
		lockedVeil.Visible = level == nil
		lockedVeil.Text = if level then "" else "LOCKED  ·  preview"
		for pipLevel, pip in pips do
			local owned = level ~= nil and pipLevel <= level
			UIKit.skinButton(pip, if owned then "Gold" else "Dark")
			pip.TextColor3 = if owned then colors.Panel else colors.SubText
			local stroke = pip:FindFirstChildOfClass("UIStroke")
			if stroke and pipLevel == shownLevel then
				stroke.Color = colors.Text
				stroke.Thickness = 3
				stroke.Transparency = 0
			end
		end
		nameLabel.Text = showcase.Name
		nameLabel.TextColor3 = accent
		descLabel.Text = showcase.Description
		local stats = `Lv {shownLevel}: <font color="#AAE6FF">{bonusText(shownLevel)}</font>`
		if level and shownLevel == level and level < maxLevel then
			stats ..= `   <font color="#B6AA9E">Next: {bonusText(level + 1)}</font>`
		end
		bonusLabel.Text = stats

		for _, child in actions:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, child in extras:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local showcaseId = showcase.Id
		if level then
			local cost = Showcases.upgradeCost(ShowcaseConfig.Levels, level)
			if cost then
				local upgrade = UIKit.priceButton({
					LayoutOrder = 1,
					Size = UDim2.fromOffset(200, 44),
					TextSize = 17,
					Parent = actions,
				}, "Upgrade", cost, function()
					send("Upgrade", showcaseId)
				end)
				table.insert(costButtons, { Button = upgrade, Cost = cost })
			end
			local activeButton = UIKit.button({
				LayoutOrder = 2,
				Text = if isActive then "Active" else "Set active",
				TextSize = 18,
				Size = UDim2.fromOffset(150, 44),
				Parent = actions,
			}, function()
				if not isActive then
					send("Activate", showcaseId)
				end
			end)
			UIKit.skinButton(activeButton, if isActive then "Gold" else "Equip")
		else
			local unlock = showcase.Unlock
			if unlock.Kind == "CE" and unlock.Price then
				local buy = UIKit.priceButton({
					LayoutOrder = 1,
					Size = UDim2.fromOffset(200, 44),
					TextSize = 17,
					Parent = actions,
				}, "Unlock", unlock.Price, function()
					send("Unlock", showcaseId)
				end)
				table.insert(costButtons, { Button = buy, Cost = unlock.Price })
			else
				local progress = (current.UnlockProgress or {})[showcaseId]
				UIKit.label({
					LayoutOrder = 1,
					Text = if progress
						then `{unlockText(showcase)}  ({Format.number(math.min(progress.Have, progress.Need))}/{Format.number(progress.Need)})`
						else unlockText(showcase),
					TextSize = 16,
					TextColor3 = colors.Gold,
					TextWrapped = true,
					Size = UDim2.fromScale(1, 1),
					Parent = actions,
				})
			end
		end

		-- Accessories: small chips (cosmetic). Locked ones name the relic that unlocks them.
		for index, accessory in showcase.Accessories do
			local unlocked = current.AccessoriesUnlocked[accessory.Id] == true
			local on = unlocked and not current.AccessoriesOff[accessory.Id]
			local chip = UIKit.button({
				LayoutOrder = index,
				Text = if unlocked then accessory.Name else `{accessory.Name} · find {relicName(accessory.RelicId)}`,
				TextSize = 13,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
				Parent = extras,
			}, function()
				send("ToggleAccessory", accessory.Id)
			end)
			UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
			UIKit.skinButton(chip, if on then "Buy" else "Dark")
			chip.TextColor3 = if unlocked then colors.Text else colors.SubText
			Motion.setDisabled(chip, not unlocked)
		end
		refreshAffordability()
	end

	player:GetAttributeChangedSignal("CE"):Connect(refreshAffordability)

	return {
		Open = function()
			UIKit.show(panel)
			state = nil
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
