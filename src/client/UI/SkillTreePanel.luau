-- Skills menu (GDD 6.6): three branch tabs (Resonance, Sanctuary, Binding Arts), one row per node
-- with its rank, what it does now and at the next rank, and Buy / +10 / Max buttons (all CE).
-- Costs come from SkillConfig (shared with the server); the server re-checks every purchase and
-- answers with the fresh ranks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SkillAction = Remotes:WaitForChild("SkillAction") :: RemoteFunction

local SkillTreePanel = {}

local ROW_HEIGHT = 84
local LIST_TOP = 66

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
	end
	return ""
end

function SkillTreePanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local ranks: { [string]: number } = {}
	local branch = SkillConfig.Branches[1].Id
	local costButtons: { { Button: TextButton, Cost: number } } = {}

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

	local render: () -> ()
	local tabButtons: { [string]: TextButton } = {}
	local branchBlurb: { [string]: string } = {}
	for index, each in SkillConfig.Branches do
		branchBlurb[each.Id] = each.Blurb
		tabButtons[each.Id] = UIKit.button({
			Text = each.Name,
			LayoutOrder = index,
			Size = UDim2.new(1 / #SkillConfig.Branches, -4, 1, 0),
			Parent = tabs,
		}, function()
			branch = each.Id
			infoLabel.Text = each.Blurb
			render()
		end)
	end

	local function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			local affordable = ce + 1e-9 >= entry.Cost
			entry.Button.BackgroundColor3 = if affordable then colors.Accent else colors.Card
			entry.Button.TextColor3 = if affordable then colors.Text else colors.SubText
		end
	end

	local function send(action: string, ...: any)
		local args = table.pack(...)
		task.spawn(function()
			local ok, result = pcall(function()
				return SkillAction:InvokeServer(action, table.unpack(args, 1, args.n))
			end)
			if ok and type(result) == "table" and type(result.State) == "table" then
				ranks = result.State.Ranks or ranks
				if result.Message then
					infoLabel.Text = result.Message
				end
				render()
			end
		end)
	end

	local function rowButton(row: Instance, text: string, width: number, x: number, onClick: () -> ()): TextButton
		local instance = UIKit.button({
			Text = text,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, x, 1, -8),
			Size = UDim2.fromOffset(width, 30),
			Parent = row,
		}, onClick)
		return instance
	end

	function render()
		costButtons = {}
		for id, tab in tabButtons do
			tab.BackgroundColor3 = if id == branch then colors.Accent else colors.Card
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
			local row = UIKit.create("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
				BackgroundColor3 = colors.Card,
				Parent = list,
			}, { UIKit.corner(10) })
			UIKit.label({
				Text = node.Name,
				TextSize = 16,
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -120, 0, 20),
				Parent = row,
			})
			UIKit.label({
				Text = `Rank {rank}/{node.MaxRank}`,
				TextSize = 14,
				TextColor3 = if maxed then colors.Gold else colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 6),
				Size = UDim2.fromOffset(110, 20),
				Parent = row,
			})
			UIKit.label({
				Text = node.Summary,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 27),
				Size = UDim2.new(1, -20, 0, 16),
				Parent = row,
			})
			local now = effectText(node.Id, rank)
			UIKit.label({
				Text = if maxed then `Now: {now}` else `Now: {now}  ->  {effectText(node.Id, rank + 1)}`,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(170, 230, 255),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 50),
				Size = UDim2.new(1, -230, 0, 18),
				Parent = row,
			})

			local nodeId = node.Id
			if maxed then
				local done = rowButton(row, "MAXED", 120, -8, function() end)
				done.BackgroundColor3 = colors.Gold
				done.TextColor3 = colors.Panel
				done.AutoButtonColor = false
				continue
			end
			local cost = SkillConfig.cost(node, rank) or 0
			local maxButton = rowButton(row, "Max", 46, -8, function()
				send("Buy", nodeId, "Max")
			end)
			table.insert(costButtons, { Button = maxButton, Cost = cost })
			local nextX = -60
			if node.MaxRank - rank > 1 then
				local tenButton = rowButton(row, "+10", 46, nextX, function()
					send("Buy", nodeId, 10)
				end)
				table.insert(costButtons, { Button = tenButton, Cost = cost })
				nextX -= 52
			end
			local buyButton = rowButton(row, `+1  {Format.number(cost)} CE`, 110, nextX, function()
				send("Buy", nodeId, 1)
			end)
			table.insert(costButtons, { Button = buyButton, Cost = cost })
		end
		refreshAffordability()
		if infoLabel.Text == "" then
			infoLabel.Text = branchBlurb[branch] or ""
		end
	end

	player:GetAttributeChangedSignal("CE"):Connect(refreshAffordability)

	return {
		Toggle = function()
			panel.Visible = not panel.Visible
			if panel.Visible then
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
