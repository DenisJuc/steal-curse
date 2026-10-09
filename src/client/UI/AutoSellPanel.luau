-- Auto-sell rules menu (GDD 9.2). Every change is sent at once and the server's cleaned-up rules
-- are redrawn. The preview runs the same AutoSell.decide the server uses on your current
-- inventory and Codex, so "what will happen" is exactly what will happen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetInventory = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local InventoryAction = Remotes:WaitForChild("InventoryAction") :: RemoteFunction
local GetCodex = Remotes:WaitForChild("GetCodex") :: RemoteFunction

local AutoSellPanel = {}

local ROW_HEIGHT = 40
-- The preview shows a mutated copy as the most common mutation.
local PREVIEW_MUTATION = MutationConfig.Mutations[1]

local function nextIn<T>(list: { T }, current: T): T
	local index = table.find(list, current) or 0
	return list[index % #list + 1]
end

local function thresholdLabel(value: number): string
	return if value <= 0 then "Off" else `1 in {Format.number(value)}`
end

function AutoSellPanel.Start(screen: ScreenGui): { Open: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local state: any = nil
	local discovered: { [string]: number } = {}

	local panel, content = UIKit.modal(screen, "AutoSellMenu", "AUTO-SELL RULES", colors.Accent, Vector2.new(540, 640))
	local body = UIKit.scrollList(content, 6)
	local order = 0

	local function clear()
		order = 0
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function row(height: number?): Frame
		order += 1
		return UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, height or ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = body,
		}, { UIKit.corner(8) })
	end

	local function text(parent: Instance, value: string, props: { [string]: any }?)
		local label = UIKit.label({
			Text = value,
			TextSize = 14,
			TextWrapped = true,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Parent = parent,
		})
		for key, prop in props or {} do
			(label :: any)[key] = prop
		end
		return label
	end

	local function heading(value: string)
		order += 1
		UIKit.label({
			LayoutOrder = order,
			Text = value,
			TextSize = 15,
			TextColor3 = colors.Accent,
			Size = UDim2.new(1, -10, 0, 24),
			Parent = body,
		})
	end

	local render: () -> ()

	local function save(change: (any) -> ())
		if not state then
			return
		end
		local draft = table.clone(state.AutoSell)
		draft.Tiers = table.clone(state.AutoSell.Tiers)
		change(draft)
		state.AutoSell = draft
		render()
		task.spawn(function()
			local ok, result = pcall(function()
				return InventoryAction:InvokeServer("SetAutoSell", draft)
			end)
			if ok and type(result) == "table" and result.State then
				state = result.State
				render()
			end
		end)
	end

	local function control(parent: Frame, label: string, width: number, color: Color3, onClick: () -> ())
		UIKit.button({
			Text = label,
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(width, 32),
			Parent = parent,
		}, onClick)
	end

	local function toggleRow(label: string, key: string)
		local on = state.AutoSell[key] == true
		local frame = row()
		text(frame, label, { Size = UDim2.new(1, -110, 1, 0) })
		control(frame, if on then "ON" else "OFF", 80, if on then colors.Accent else colors.Panel, function()
			save(function(draft)
				draft[key] = not on
			end)
		end)
	end

	local function previewRow(relic: RelicConfig.Relic)
		local rules = state.AutoSell
		local plainIncome = Economy.relicIncome(Config.Economy, relic.Tier, 1)
		local mutatedIncome = Economy.relicIncome(Config.Economy, relic.Tier, PREVIEW_MUTATION.IncomeMultiplier)
		local bestHeld = -1
		local favorites = {}
		for _, group in state.Groups do
			if group.Id == relic.Id then
				bestHeld = math.max(bestHeld, group.IncomePerMin)
				if group.Favorite then
					favorites[AutoSell.favoriteKey(group.Id, group.Mutation)] = true
				end
			end
		end
		local base = {
			Tier = relic.Tier,
			BaseOneIn = 1 / math.max(Odds.baseItem(relic.Id), 1e-300),
			First = discovered[relic.Id] == nil,
		}
		local function outcome(mutated: boolean, income: number, key: string): (string, Color3)
			local sell, reason = AutoSell.decide(rules, {
				Tier = base.Tier,
				BaseOneIn = base.BaseOneIn,
				First = base.First,
				Mutated = mutated,
				Duplicate = bestHeld >= income,
				Favorite = favorites[key] == true,
			})
			local word = if sell then "SELL" else "KEEP"
			return `{word} ({AutoSell.ReasonText[reason]})`, if sell then colors.Red else Color3.fromRGB(120, 230, 140)
		end
		local plainText, plainColor = outcome(false, plainIncome, relic.Id)
		local mutatedText = outcome(true, mutatedIncome, AutoSell.favoriteKey(relic.Id, PREVIEW_MUTATION.Id))

		local frame = row(46)
		local name = if discovered[relic.Id] then relic.Name else `??? (new {relic.Tier})`
		text(frame, name, {
			TextColor3 = UIKit.tierColor(relic.Tier),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Size = UDim2.new(0.45, -10, 1, 0),
		})
		text(frame, `Next copy: {plainText}`, {
			TextSize = 12,
			TextColor3 = plainColor,
			Position = UDim2.new(0.45, 0, 0, 4),
			Size = UDim2.new(0.55, -10, 0, 18),
		})
		text(frame, `{PREVIEW_MUTATION.Name} copy: {mutatedText}`, {
			TextSize = 12,
			TextColor3 = colors.SubText,
			Position = UDim2.new(0.45, 0, 0, 23),
			Size = UDim2.new(0.55, -10, 0, 18),
		})
	end

	function render()
		clear()
		if not state then
			return
		end
		local rules = state.AutoSell

		text(
			row(64),
			"Applies to new finds only. Pedestal, locked and favorite relics are never auto-sold, and every first find is recorded in the Codex even if it is sold.",
			{ TextSize = 13, TextColor3 = colors.SubText, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8) }
		)

		heading("By rarity")
		for _, tier in RarityConfig.Tiers do
			local mode = rules.Tiers[tier.Id] or "Keep"
			local frame = row()
			text(frame, tier.Name, { TextColor3 = UIKit.tierColor(tier.Id), Size = UDim2.new(1, -180, 1, 0) })
			control(frame, AutoSell.ModeLabels[mode], 160, if mode == "Keep" then colors.Panel else colors.Accent, function()
				save(function(draft)
					draft.Tiers[tier.Id] = nextIn(AutoSell.Modes, mode)
				end)
			end)
		end

		heading("Extra rules")
		toggleRow("Sell duplicates of every rarity", "SellAllDuplicates")
		local thresholdFrame = row(58)
		text(thresholdFrame, "Also sell anything MORE COMMON than:", {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -150, 0, 22),
		})
		text(
			thresholdFrame,
			if rules.SellEasierThan > 0
				then `e.g. a 1 in {Format.number(rules.SellEasierThan / 2)} relic is sold, a 1 in {Format.number(
					rules.SellEasierThan * 5
				)} relic is kept.`
				else "Off: base odds never sell anything by themselves.",
			{
				TextSize = 12,
				TextColor3 = colors.SubText,
				Position = UDim2.fromOffset(10, 28),
				Size = UDim2.new(1, -150, 0, 24),
			}
		)
		control(thresholdFrame, thresholdLabel(rules.SellEasierThan), 120, if rules.SellEasierThan > 0
			then colors.Accent
			else colors.Panel, function()
			save(function(draft)
				draft.SellEasierThan = nextIn(AutoSell.ThresholdPresets, rules.SellEasierThan)
			end)
		end)

		heading("Protection (wins over the rules above)")
		toggleRow("Protect first discoveries", "ProtectFirst")
		toggleRow("Protect mutated relics", "ProtectMutated")

		heading("What happens to your next find")
		if state.Count >= state.Capacity then
			text(row(44), `[INVENTORY FULL] {state.Count}/{state.Capacity}: scanning is paused until you sell relics.`, {
				TextSize = 13,
				TextColor3 = colors.Red,
			})
		end
		for _, relic in RelicConfig.Relics do
			previewRow(relic)
		end
	end

	local function load()
		task.spawn(function()
			local okInventory, inventory = pcall(function()
				return GetInventory:InvokeServer()
			end)
			local okCodex, codex = pcall(function()
				return GetCodex:InvokeServer()
			end)
			if okCodex and type(codex) == "table" then
				discovered = codex.Discovered or {}
			end
			if okInventory and type(inventory) == "table" then
				state = inventory
				render()
			end
		end)
	end

	return {
		Open = function()
			panel.Visible = true
			load()
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return AutoSellPanel
