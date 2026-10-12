-- Skills menu (GDD 6.6): three branch tabs (Resonance, Sanctuary, Binding Arts), one row per node
-- with its rank, what it does now and at the next rank, and Buy / +10 / Max buttons (all CE).
-- Costs come from SkillConfig (shared with the server); the server re-checks every purchase and
-- answers with the fresh ranks.
-- Feel: rows pop in one after another when the menu opens (MenuMotion "PopIn") or the tab changes; a purchase flashes
-- the row gold, springs its rank bar forward and plays the upgrade sound (plus a shine when the
-- node maxes); buttons you can't afford shake "no" (Toasts says how much CE is missing).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local Motion = require(script.Parent.Motion)
local Spring = require(script.Parent.Spring)
local UIKit = require(script.Parent.UIKit)
local Sounds = require(script.Parent.Parent.Sounds)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SkillAction = Remotes:WaitForChild("SkillAction") :: RemoteFunction

local SkillTreePanel = {}

local ROW_HEIGHT = 84
local LIST_TOP = 66
local STAGGER = 0.045

local function percent(value: number): string
	return `{Format.number(value * 100)}%`
end

-- What a node does at `rank`, in a few words.
local function effectText(nodeId: string, rank: number): string
	if nodeId == "CoreLuck" then
		return `x{Format.number(Formulas.coreLuck(rank))} luck`
	elseif nodeId == "ScanSpeed" then
		return `scan every {Format.seconds(SkillConfig.scanInterval(rank))}`
	elseif nodeId == "FrequencyFocus" then
		return `Frequency x{Format.number(Config.Frequency.MultiplierByRank[rank] or 1)}`
	elseif nodeId == "MutationResonance" then
		if rank <= 0 then
			return "no mutations"
		end
		local unlocked = 0
		for _, mutation in MutationConfig.Mutations do
			if mutation.UnlockRank <= rank then
				unlocked += 1
			end
		end
		return `{percent(MutationConfig.ChanceAt(rank))} mutated, {unlocked} variant{if unlocked == 1 then "" else "s"}`
	elseif nodeId == "EnergyConduction" then
		return `+{percent(SkillConfig.incomeBonus(rank))} income`
	elseif nodeId == "SpiritMerchant" then
		return `+{percent(SkillConfig.sellBonus(rank))} sell value`
	elseif nodeId == "SpiritReservoir" then
		return `offline up to {Format.duration(SkillConfig.offlineCapSeconds(rank))}`
	elseif nodeId == "SpiritSight" then
		return `see {Format.number(SkillConfig.sightRange(rank))} studs, pulse {Format.seconds(SkillConfig.pulseCooldown(rank))}`
	elseif nodeId == "BindingEfficiency" then
		return `bind in {Format.seconds(SkillConfig.holdSeconds(rank))}`
	elseif nodeId == "ResonantHarvest" then
		return `+{percent(SkillConfig.harvestMultiplier(rank) - 1)} bonus finds`
	elseif nodeId == "SwiftStep" then
		return `walk speed {Format.number(SkillConfig.walkSpeed(rank))}`
	end
	return ""
end

type RowParts = { Card: Frame, Fill: Frame, Rank: TextLabel, MaxRank: number }

function SkillTreePanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local ranks: { [string]: number } = {}
	local branch = SkillConfig.Branches[1].Id
	local costButtons: { { Button: TextButton, Cost: number } } = {}
	local rows: { [string]: RowParts } = {}
	local popNext = false

	local panel, content = UIKit.modal(screen, "SkillsMenu", "SKILLS", colors.Accent, Vector2.new(560, 620))

	local tabs = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
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
	list.Size = UDim2.new(1, 0, 1, -LIST_TOP)
	list.ScrollBarImageColor3 = colors.Trim

	local render: () -> ()
	local tabButtons: { [string]: TextButton } = {}
	local branchBlurb: { [string]: string } = {}
	for index, each in SkillConfig.Branches do
		branchBlurb[each.Id] = each.Blurb
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
			infoLabel.Text = each.Blurb
			popNext = true
			render()
		end)
	end

	local function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			UIKit.setAffordable(entry.Button, ce + 1e-9 >= entry.Cost, entry.Cost)
		end
	end

	-- Celebrates the rows whose rank went up (rows were just rebuilt by render).
	local function celebrate(before: { [string]: number })
		for nodeId, parts in rows do
			local old = before[nodeId] or 0
			local new = ranks[nodeId] or 0
			if new <= old then
				continue
			end
			parts.Fill.Size = UDim2.fromScale(math.clamp(old / parts.MaxRank, 0, 1), 1)
			Spring.target(parts.Fill, 3, 0.6, { Size = UDim2.fromScale(math.clamp(new / parts.MaxRank, 0, 1), 1) })
			Motion.purchased(parts.Card)
			Motion.punch(parts.Rank, 3)
			if new >= parts.MaxRank then
				Motion.shine(parts.Card, 0.9)
				Sounds.Play("Shine")
			end
		end
	end

	local function send(action: string, ...: any)
		local args = table.pack(...)
		task.spawn(function()
			local ok, result = pcall(function()
				return SkillAction:InvokeServer(action, table.unpack(args, 1, args.n))
			end)
			if ok and type(result) == "table" and type(result.State) == "table" then
				local before = table.clone(ranks)
				ranks = result.State.Ranks or ranks
				if result.Message then
					infoLabel.Text = result.Message
				end
				render()
				if action == "Buy" then
					celebrate(before)
				end
			end
		end)
	end

	local function rowButton(card: Instance, text: string, width: number, x: number, cost: number, onClick: () -> ()): TextButton
		local button = UIKit.button({
			Text = text,
			TextSize = 14,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, x - width / 2, 1, -23),
			Size = UDim2.fromOffset(width, 30),
			Parent = card,
		}, onClick)
		table.insert(costButtons, { Button = button, Cost = cost })
		return button
	end

	function render()
		costButtons = {}
		rows = {}
		for id, tab in tabButtons do
			UIKit.skinButton(tab, if id == branch then "Primary" else "Dark")
		end
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		for _, node in SkillConfig.Nodes do
			if node.Branch ~= branch then
				continue
			end
			order += 1
			local rank = ranks[node.Id] or 0
			local maxed = rank >= node.MaxRank
			local slot = UIKit.slot(list, node.Id, UDim2.new(1, -10, 0, ROW_HEIGHT), order)
			local card = UIKit.create("Frame", {
				Name = "Card",
				BackgroundColor3 = colors.Card,
				Parent = slot,
			}, {
				UIKit.corner(10),
				UIKit.stroke(if maxed then colors.Gold else colors.Trim, 1.5, if maxed then 0.2 else 0.7),
				UIKit.create("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 145, 160)),
				}),
			})
			UIKit.fill(card)
			UIKit.create("Frame", {
				Name = "Spine",
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.new(0, 3, 1, -20),
				BackgroundColor3 = if maxed then colors.Gold else colors.Accent,
				BorderSizePixel = 0,
				Parent = card,
			}, { UIKit.corner(2) })
			UIKit.label({
				Text = node.Name,
				TextSize = 16,
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -130, 0, 20),
				Parent = card,
			})
			local rankLabel = UIKit.label({
				Name = "Rank",
				Text = `Rank {rank}/{node.MaxRank}`,
				TextSize = 14,
				TextColor3 = if maxed then colors.Gold else colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -65, 0, 16),
				Size = UDim2.fromOffset(110, 20),
				Parent = card,
			})
			UIKit.label({
				Text = node.Summary,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(12, 27),
				Size = UDim2.new(1, -22, 0, 16),
				Parent = card,
			})
			local now = effectText(node.Id, rank)
			UIKit.label({
				Text = if maxed then `Now: {now}` else `Now: {now}  ->  {effectText(node.Id, rank + 1)}`,
				TextSize = 13,
				TextColor3 = colors.Cyan,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(12, 48),
				Size = UDim2.new(1, -240, 0, 18),
				Parent = card,
			})
			local track = UIKit.create("Frame", {
				Name = "RankBar",
				Position = UDim2.new(0, 12, 1, -13),
				Size = UDim2.new(1, -252, 0, 5),
				BackgroundColor3 = colors.Track,
				BorderSizePixel = 0,
				Parent = card,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local fill = UIKit.create("Frame", {
				Name = "Fill",
				Size = UDim2.fromScale(math.clamp(rank / node.MaxRank, 0, 1), 1),
				BackgroundColor3 = if maxed then colors.Gold else colors.Accent,
				BorderSizePixel = 0,
				Parent = track,
			}, {
				UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				UIKit.create("UIGradient", {
					Color = ColorSequence.new(Color3.fromRGB(200, 200, 210), Color3.new(1, 1, 1)),
				}),
			})
			rows[node.Id] = { Card = card, Fill = fill, Rank = rankLabel, MaxRank = node.MaxRank }
			card:SetAttribute("PopIn", true)
			if popNext then
				Motion.pop(card, (order - 1) * STAGGER, 0.6)
			end

			local nodeId = node.Id
			if maxed then
				local tag = UIKit.label({
					Text = "MAXED",
					TextSize = 15,
					TextColor3 = colors.Panel,
					TextXAlignment = Enum.TextXAlignment.Center,
					BackgroundTransparency = 0,
					BackgroundColor3 = colors.Gold,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -68, 1, -23),
					Size = UDim2.fromOffset(120, 30),
					Parent = card,
				})
				UIKit.corner(8).Parent = tag
				continue
			end
			local cost = SkillConfig.cost(node, rank) or 0
			rowButton(card, "Max", 46, -8, cost, function()
				send("Buy", nodeId, "Max")
			end)
			local nextX = -60
			if node.MaxRank - rank > 1 then
				rowButton(card, "+10", 46, nextX, cost, function()
					send("Buy", nodeId, 10)
				end)
				nextX -= 52
			end
			rowButton(card, `+1  {Format.number(cost)} CE`, 110, nextX, cost, function()
				send("Buy", nodeId, 1)
			end)
		end
		popNext = false
		refreshAffordability()
		if infoLabel.Text == "" then
			infoLabel.Text = branchBlurb[branch] or ""
		end
	end

	player:GetAttributeChangedSignal("CE"):Connect(refreshAffordability)

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				infoLabel.Text = ""
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
