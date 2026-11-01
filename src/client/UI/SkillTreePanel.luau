-- Skills menu as a tree (GDD 6.6, v0.1): one tree per branch tab (Resonance, Sanctuary, Binding
-- Arts). Each node is a round icon with its rank under it, placed by SkillConfig Pos and joined to
-- the node it Requires by a line that lights up once the path is open. Tapping a node opens the
-- sheet at the bottom: name, rank, what it does now -> next, and one price button (x1 / x10 / Max
-- toggle). Locked nodes say which node opens them; nodes you can afford breathe gold.
-- Feel: a purchase bounces the node, bursts sparks from it, runs light down its child lines and
-- plays the upgrade sound (plus a shine when it maxes). The server re-checks every purchase
-- (SkillService) and answers with the fresh ranks. Effect texts come from SkillListPanel, the
-- old list menu kept as a fallback (Config.SkillTreeUI = false).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Toasts = require(script.Parent.Toasts)
local SkillListPanel = require(script.Parent.SkillListPanel)
local UIKit = require(script.Parent.UIKit)
local Sounds = require(script.Parent.Parent.Sounds)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SkillAction = Remotes:WaitForChild("SkillAction") :: RemoteFunction

local SkillTreePanel = {}

local NODE = 72
local ICON = 42
local COLUMN_X = { 0.18, 0.5, 0.82 }
local ROW_TOP = 50
local ROW_GAP = 124
local SHEET_HEIGHT = 140
local LABEL_HEIGHT = 34
local MODE_HEIGHT = 40
local TREE_TOP = UIKit.TAB_HEIGHT + 8 + MODE_HEIGHT + 6
local BUTTON_WIDTH = 176
local BUY_MODES = { { Id = "One", Text = "x1" }, { Id = "Ten", Text = "x10" }, { Id = "Max", Text = "Max" } }
local BUY_AMOUNTS: { [string]: any } = { One = 1, Ten = 10, Max = "Max" }
local SPARKS = 12

type NodeParts = {
	Button: TextButton,
	Ring: UIStroke,
	Rank: TextLabel,
	Lock: GuiObject?,
}

local function coreLuckCostOverride(nodeId: string): SkillConfig.CostOverride?
	return if nodeId == "CoreLuck" then BalanceTrials.coreLuckCostOverride() else nil
end

function SkillTreePanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local ranks: { [string]: number } = {}
	local branch = SkillConfig.Branches[1].Id
	local selected: string? = nil
	local buyMode = "One"
	local nodes: { [string]: NodeParts } = {}
	local lines: { [string]: Frame } = {}

	local panel, content =
		UIKit.modal(screen, "SkillsMenu", "SKILLS", colors.Accent, Vector2.new(620, 740), "Upgrades")

	local tabs = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, UIKit.TAB_HEIGHT),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local blurb = UIKit.label({
		Text = "",
		TextSize = 15,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(6, UIKit.TAB_HEIGHT + 8),
		Size = UDim2.new(1, -230, 0, MODE_HEIGHT),
		TextWrapped = true,
		Parent = content,
	})

	local tree = UIKit.create("ScrollingFrame", {
		Name = "Tree",
		Position = UDim2.fromOffset(0, TREE_TOP),
		Size = UDim2.new(1, 0, 1, -(TREE_TOP + SHEET_HEIGHT + 8)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = colors.Trim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	-- A faint violet glow behind the tree so it reads as a place, not a list.
	UIKit.create("Frame", {
		Name = "Glow",
		Position = tree.Position,
		Size = tree.Size,
		BackgroundColor3 = colors.Accent,
		BackgroundTransparency = 0.82,
		ZIndex = 0,
		Parent = content,
	}, {
		UIKit.corner(12),
		UIKit.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.6, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
		}),
	})
	local canvas = UIKit.create("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = tree,
	})

	-- Bottom sheet: the selected node.
	local sheet = UIKit.create("Frame", {
		Name = "Sheet",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, SHEET_HEIGHT),
		BackgroundColor3 = colors.Card,
		Parent = content,
	}, { UIKit.corner(12), UIKit.padding(12) })
	UIKit.skinCard(sheet)
	local sheetIcon = UIKit.create("Frame", {
		Name = "IconHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(64, 64),
		Parent = sheet,
	})
	local sheetName = UIKit.label({
		FontFace = UIKit.TitleFont,
		TextSize = 24,
		Position = UDim2.fromOffset(76, 0),
		Size = UDim2.new(1, -76 - BUTTON_WIDTH - 12, 0, 28),
		Parent = sheet,
	})
	local sheetRank = UIKit.label({
		TextSize = 16,
		TextColor3 = colors.Gold,
		Position = UDim2.fromOffset(76, 28),
		Size = UDim2.new(1, -76 - BUTTON_WIDTH - 12, 0, 20),
		Parent = sheet,
	})
	local sheetSummary = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, -BUTTON_WIDTH - 12, 0, 38),
		Parent = sheet,
	})
	local sheetEffect = UIKit.label({
		TextSize = 17,
		TextScaled = true,
		TextColor3 = colors.Cyan,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -BUTTON_WIDTH - 12, 0, 24),
		Parent = sheet,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = sheetEffect })

	local send: (string, ...any) -> ()
	local buyButton = UIKit.priceButton({
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(BUTTON_WIDTH, 60),
		TextSize = 20,
		Parent = sheet,
	}, "+1", 0, function()
		if selected then
			send("Buy", selected, BUY_AMOUNTS[buyMode])
		end
	end)
	local sheetNote = UIKit.label({
		Name = "Note",
		Text = "",
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = colors.SubText,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(BUTTON_WIDTH, 60),
		BackgroundTransparency = 0,
		BackgroundColor3 = colors.Panel,
		Visible = false,
		Parent = sheet,
	})
	UIKit.corner(8).Parent = sheetNote

	-- Short screens (phones in landscape): the sheet sits beside the tree instead of under it, with
	-- the price button across its bottom.
	-- The branch tabs and x1/x10/Max share one row there, and the sheet drops its summary.
	local function applyCompact(compact: boolean)
		local modeBar = content:FindFirstChild("BuyMode") :: Frame?
		local top = if compact then UIKit.TAB_HEIGHT + 6 else TREE_TOP
		blurb.Visible = not compact
		sheetSummary.Visible = not compact
		tabs.Size = if compact then UDim2.new(0.6, -6, 0, UIKit.TAB_HEIGHT) else UDim2.new(1, 0, 0, UIKit.TAB_HEIGHT)
		if modeBar then
			modeBar.Position = if compact then UDim2.fromScale(1, 0) else UDim2.new(1, -10, 0, UIKit.TAB_HEIGHT + 8)
			modeBar.Size = if compact then UDim2.new(0.4, 0, 0, UIKit.TAB_HEIGHT) else UDim2.fromOffset(204, MODE_HEIGHT)
		end
		tree.Position = UDim2.fromOffset(0, top)
		local glow = content:FindFirstChild("Glow") :: Frame?
		if compact then
			tree.Size = UDim2.new(0.55, 0, 1, -top)
			if glow then
				glow.Position = tree.Position
				glow.Size = tree.Size
			end
			sheet.AnchorPoint = Vector2.new(1, 0)
			sheet.Position = UDim2.new(1, 0, 0, top)
			sheet.Size = UDim2.new(0.45, -8, 1, -top)
			sheetName.Size = UDim2.new(1, -76, 0, 28)
			sheetRank.Size = UDim2.new(1, -76, 0, 20)
			sheetEffect.Position = UDim2.new(0, 0, 1, -58)
			sheetEffect.Size = UDim2.new(1, 0, 0, 22)
			for _, button in { buyButton, sheetNote } do
				button.Size = UDim2.new(1, 0, 0, 50)
			end
		else
			tree.Size = UDim2.new(1, 0, 1, -(TREE_TOP + SHEET_HEIGHT + 8))
			if glow then
				glow.Position = tree.Position
				glow.Size = tree.Size
			end
			sheet.AnchorPoint = Vector2.new(0, 1)
			sheet.Position = UDim2.fromScale(0, 1)
			sheet.Size = UDim2.new(1, 0, 0, SHEET_HEIGHT)
			sheetName.Size = UDim2.new(1, -76 - BUTTON_WIDTH - 12, 0, 28)
			sheetRank.Size = UDim2.new(1, -76 - BUTTON_WIDTH - 12, 0, 20)
			sheetSummary.Size = UDim2.new(1, -BUTTON_WIDTH - 12, 0, 38)
			sheetEffect.Position = UDim2.fromScale(0, 1)
			sheetEffect.Size = UDim2.new(1, -BUTTON_WIDTH - 12, 0, 24)
			for _, button in { buyButton, sheetNote } do
				button.Size = UDim2.fromOffset(BUTTON_WIDTH, 60)
			end
		end
	end

	local render: () -> ()
	local tabButtons: { [string]: TextButton } = {}
	for index, each in SkillConfig.Branches do
		tabButtons[each.Id] = UIKit.button({
			Text = each.Name,
			TextSize = 15,
			LayoutOrder = index,
			Size = UDim2.new(1 / #SkillConfig.Branches, -4, 1, 0),
			Parent = tabs,
		}, function()
			if branch == each.Id then
				return
			end
			branch = each.Id
			selected = nil
			render()
		end)
	end
	UIKit.tabBar(content, BUY_MODES, buyMode, function(id)
		buyMode = id
		render()
	end, {
		Name = "BuyMode",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, UIKit.TAB_HEIGHT + 8),
		Size = UDim2.fromOffset(204, MODE_HEIGHT),
	})

	UIKit.watchCompact(applyCompact)

	local function maxRankOf(node: SkillConfig.Node): number
		return BalanceTrials.skillMaxRank(node.Id, player:GetAttribute("Rebirths") or 0)
	end

	-- What the price button buys now: count and total cost (x10 / Max as many as CE allows).
	local function quote(node: SkillConfig.Node): (number, number, boolean)
		local rank = ranks[node.Id] or 0
		local remaining = maxRankOf(node) - rank
		local override = coreLuckCostOverride(node.Id)
		local oneCost = SkillConfig.cost(node, rank, override) or 0
		local ce = player:GetAttribute("CE") or 0
		local count, cost = 1, oneCost
		if buyMode ~= "One" and remaining > 0 then
			local limit = if buyMode == "Ten" then math.min(10, remaining) else remaining
			local bought, total = SkillConfig.affordable(node, rank, ce, limit, override)
			if bought > 0 then
				count, cost = bought, total
			end
		end
		return count, cost, ce + 1e-9 >= oneCost
	end

	local function nodeState(node: SkillConfig.Node): string
		local rank = ranks[node.Id] or 0
		if rank >= maxRankOf(node) then
			return "Maxed"
		elseif not SkillConfig.unlocked(node.Id, ranks) then
			return "Locked"
		end
		local _, _, affordable = quote(node)
		return if affordable then "Ready" else "Open"
	end

	local function refreshSheet()
		local node = selected and SkillConfig.ById[selected]
		sheet.Visible = node ~= nil
		if not node then
			return
		end
		if sheetIcon:GetAttribute("Node") ~= node.Id then
			sheetIcon:SetAttribute("Node", node.Id)
			for _, child in sheetIcon:GetChildren() do
				child:Destroy()
			end
			local icon = Icons.image(sheetIcon, node.Icon, 64)
			if icon then
				icon.Position = UDim2.fromOffset(0, 0)
			end
		end
		local rank = ranks[node.Id] or 0
		local maxRank = maxRankOf(node)
		local state = nodeState(node)
		sheetName.Text = node.Name
		sheetRank.Text = `Rank {rank}/{maxRank}`
		sheetSummary.Text = node.Summary
		local now = SkillListPanel.effectText(node.Id, rank)
		sheetEffect.Text = if state == "Maxed" then now else `{now}  \u{2192}  {SkillListPanel.effectText(node.Id, rank + 1)}`
		buyButton.Visible = state ~= "Maxed" and state ~= "Locked"
		sheetNote.Visible = not buyButton.Visible
		if state == "Maxed" then
			sheetNote.Text = "MAXED"
			sheetNote.TextColor3 = colors.Gold
		elseif state == "Locked" then
			local required = SkillConfig.ById[node.Requires :: string]
			sheetNote.Text = `Unlock {if required then required.Name else "the node above"} first`
			sheetNote.TextColor3 = colors.SubText
		else
			local count, cost, affordable = quote(node)
			UIKit.setPrice(buyButton, `+{count}`, cost)
			UIKit.setAffordable(buyButton, affordable, cost)
		end
	end

	local function styleNode(node: SkillConfig.Node)
		local parts = nodes[node.Id]
		if not parts then
			return
		end
		local state = nodeState(node)
		local rank = ranks[node.Id] or 0
		parts.Rank.Text = `{rank}/{maxRankOf(node)}`
		parts.Ring.Color = if state == "Maxed"
			then colors.Gold
			elseif state == "Ready" then colors.Gold
			elseif state == "Open" then colors.Accent
			else colors.Trim
		parts.Ring.Thickness = if node.Id == selected then 5 else 3
		parts.Button.BackgroundColor3 = if state == "Maxed"
			then Color3.fromRGB(70, 56, 30)
			elseif state == "Locked" then Color3.fromRGB(14, 11, 20)
			else colors.Card
		parts.Rank.TextColor3 = if state == "Maxed" then colors.Gold else colors.Text
		if parts.Lock then
			parts.Lock.Visible = state == "Locked"
		end
		local icon = parts.Button:FindFirstChild(`{node.Icon}Icon`) :: ImageLabel?
		if icon then
			icon.ImageTransparency = if state == "Locked" then 0.55 else 0
			icon.ImageColor3 = if state == "Locked" then Color3.fromRGB(120, 115, 130) else Color3.new(1, 1, 1)
		end
		local line = lines[node.Id]
		if line then
			local open = SkillConfig.unlocked(node.Id, ranks)
			line.BackgroundColor3 = if rank > 0 then colors.Gold elseif open then colors.Accent else colors.Track
			line.BackgroundTransparency = if open then 0.1 else 0.4
			line.Size = UDim2.fromOffset(line.Size.X.Offset, if rank > 0 then 8 else 5)
		end
	end

	local function refreshAll()
		for _, node in SkillConfig.Nodes do
			styleNode(node)
		end
		refreshSheet()
	end

	-- Canvas width in layout units: AbsoluteSize includes the menu's UIScale, offsets don't.
	local function canvasWidth(): number
		local factor = 1
		for _, parts in nodes do
			local size = (parts.Button.Parent :: Frame).AbsoluteSize.X
			if size > 0 then
				factor = size / NODE
			end
			break
		end
		return canvas.AbsoluteSize.X / factor
	end

	-- Centre of a node in canvas layout units.
	local function centre(node: SkillConfig.Node, width: number): Vector2
		return Vector2.new(width * COLUMN_X[node.Pos[1]], ROW_TOP + (node.Pos[2] - 1) * ROW_GAP)
	end
	-- Holders are anchored at their centre and hold the label under the round button.
	local HOLDER_SHIFT = LABEL_HEIGHT / 2

	local function placeLine(line: Frame, from: Vector2, to: Vector2)
		local delta = to - from
		line.Size = UDim2.fromOffset(delta.Magnitude, if line.Size.Y.Offset > 0 then line.Size.Y.Offset else 6)
		line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end

	local function layout()
		local width = canvasWidth()
		for _, node in SkillConfig.Nodes do
			local parts = nodes[node.Id]
			if parts then
				local at = centre(node, width)
				parts.Button.Parent.Position = UDim2.new(COLUMN_X[node.Pos[1]], 0, 0, at.Y + HOLDER_SHIFT)
				local line = lines[node.Id]
				local parent = node.Requires and SkillConfig.ById[node.Requires]
				if line and parent then
					placeLine(line, centre(parent, width), at)
				end
			end
		end
	end
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	-- Sparks out of a node and a light running down each line to its children.
	local function burst(nodeId: string)
		local parts = nodes[nodeId]
		if not parts then
			return
		end
		local holder = parts.Button.Parent :: Frame
		for index = 1, SPARKS do
			local angle = (index / SPARKS) * math.pi * 2 + math.random() * 0.4
			local spark = UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(9, 9),
				BackgroundColor3 = if index % 3 == 0 then colors.Accent else colors.Gold,
				ZIndex = 8,
				Parent = holder,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local distance = NODE * (0.8 + math.random() * 0.5)
			local tween = TweenService:Create(
				spark,
				TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
					Size = UDim2.fromOffset(2, 2),
					BackgroundTransparency = 1,
				}
			)
			tween:Play()
			tween.Completed:Once(function()
				spark:Destroy()
			end)
		end
		local ring = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(NODE, NODE),
			BackgroundTransparency = 1,
			ZIndex = 7,
			Parent = holder,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.create("UIStroke", { Color = colors.Gold, Thickness = 4 }),
		})
		local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(NODE * 1.9, NODE * 1.9) })
			:Play()
		local fade = TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 })
		fade:Play()
		fade.Completed:Once(function()
			ring:Destroy()
		end)
		for _, child in SkillConfig.Nodes do
			local line = lines[child.Id]
			if child.Requires == nodeId and line then
				Motion.flash(line, colors.Text, 0)
			end
		end
	end

	local function celebrate(before: { [string]: number })
		for nodeId, parts in nodes do
			local old = before[nodeId] or 0
			local new = ranks[nodeId] or 0
			if new > old then
				Motion.purchased(parts.Button)
				Motion.punch(parts.Rank, 3)
				burst(nodeId)
				local node = SkillConfig.ById[nodeId]
				if node and new >= maxRankOf(node) then
					Motion.shine(parts.Button, 0.9)
					Sounds.Play("Shine")
				end
			end
		end
	end

	function send(action: string, ...: any)
		local args = table.pack(...)
		task.spawn(function()
			local ok, result = pcall(function()
				return SkillAction:InvokeServer(action, table.unpack(args, 1, args.n))
			end)
			if ok and type(result) == "table" and type(result.State) == "table" then
				local before = table.clone(ranks)
				ranks = result.State.Ranks or ranks
				refreshAll()
				if action == "Buy" then
					celebrate(before)
					local node = selected and nodes[selected]
					if node and (ranks[selected :: string] or 0) <= (before[selected :: string] or 0) then
						Motion.deny(buyButton)
						if type(result.Message) == "string" then
							Toasts.Show(result.Message)
						end
					end
				end
			end
		end)
	end

	function render()
		for id, tab in tabButtons do
			UIKit.skinTab(tab, id == branch)
		end
		for _, each in SkillConfig.Branches do
			if each.Id == branch then
				blurb.Text = each.Blurb
			end
		end
		for _, child in canvas:GetChildren() do
			child:Destroy()
		end
		nodes = {}
		lines = {}
		local rows = 1
		local first: string? = nil
		for _, node in SkillConfig.Nodes do
			if node.Branch ~= branch or not BalanceTrials.skillNodeEnabled(node.Id) then
				continue
			end
			rows = math.max(rows, node.Pos[2])
			first = first or node.Id
			if node.Requires then
				lines[node.Id] = UIKit.create("Frame", {
					Name = `Line_{node.Id}`,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BorderSizePixel = 0,
					BackgroundColor3 = colors.Track,
					ZIndex = 1,
					Parent = canvas,
				}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			end
			local holder = UIKit.create("Frame", {
				Name = node.Id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(NODE, NODE + LABEL_HEIGHT),
				BackgroundTransparency = 1,
				ZIndex = 2,
				Parent = canvas,
			})
			local button = UIKit.create("TextButton", {
				Name = "Node",
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.fromOffset(NODE, NODE),
				BackgroundColor3 = colors.Card,
				ZIndex = 3,
				Parent = holder,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local ring = UIKit.create("UIStroke", {
				Color = colors.Trim,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = button,
			})
			Motion.button(button)
			local icon = Icons.image(button, node.Icon, ICON)
			if icon then
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.ZIndex = 4
			end
			local lock = Icons.image(button, "Lock", 26)
			if lock then
				lock.AnchorPoint = Vector2.new(1, 1)
				lock.Position = UDim2.new(1, 4, 1, 4)
				lock.ZIndex = 5
			end
			if node.Badge then
				local badge = UIKit.label({
					Name = "Badge",
					Text = node.Badge,
					FontFace = UIKit.TitleFont,
					TextSize = 18,
					TextColor3 = colors.Panel,
					TextXAlignment = Enum.TextXAlignment.Center,
					BackgroundTransparency = 0,
					BackgroundColor3 = colors.Gold,
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(-4, -4),
					Size = UDim2.fromOffset(24, 24),
					ZIndex = 6,
					Parent = button,
				})
				UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
			end
			-- Name and rank sit on a dark pill so the path lines pass behind them.
			local label = UIKit.label({
				Name = "NodeName",
				Text = node.Name,
				TextSize = 13,
				TextColor3 = colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 0.15,
				BackgroundColor3 = colors.Panel,
				ZIndex = 4,
				Parent = holder,
			})
			UIKit.create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = label })
			UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = label })
			local rank = UIKit.label({
				Name = "Rank",
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 0.15,
				BackgroundColor3 = colors.Panel,
				ZIndex = 4,
				Parent = holder,
			})
			UIKit.create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = rank })
			UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = rank })
			local nodeId = node.Id
			button.Activated:Connect(function()
				selected = nodeId
				Motion.punch(button, 2)
				refreshAll()
			end)
			nodes[node.Id] = { Button = button, Ring = ring, Rank = rank, Lock = lock }
		end
		tree.CanvasSize = UDim2.fromOffset(0, ROW_TOP + (rows - 1) * ROW_GAP + NODE)
		selected = selected or first
		layout()
		refreshAll()
		-- Holder sizes are only known after a frame (the scale factor in canvasWidth).
		task.defer(layout)
	end

	-- Nodes you can afford breathe so the tree pulls you back.
	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
		for nodeId, parts in nodes do
			local node = SkillConfig.ById[nodeId]
			if node and parts.Ring.Color == colors.Gold and (ranks[nodeId] or 0) < maxRankOf(node) then
				parts.Ring.Transparency = 0.35 * pulse
			else
				parts.Ring.Transparency = 0
			end
		end
	end)
	-- Ranks also come from the Skill_<id> attributes (rebirth, data reset, debug) so the tree is
	-- right before Get answers and while it stays open.
	local function readAttributes()
		for _, node in SkillConfig.Nodes do
			local value = player:GetAttribute(`Skill_{node.Id}`)
			if type(value) == "number" then
				ranks[node.Id] = value
			end
		end
	end
	readAttributes()
	for _, node in SkillConfig.Nodes do
		player:GetAttributeChangedSignal(`Skill_{node.Id}`):Connect(function()
			readAttributes()
			if panel.Visible then
				refreshAll()
			end
		end)
	end
	player:GetAttributeChangedSignal("CE"):Connect(function()
		if panel.Visible then
			refreshAll()
		end
	end)

	render()

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				render()
				send("Get")
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return SkillTreePanel
