-- Auto-sell rules menu (GDD 9.2). Every change is sent at once and the server's cleaned-up rules
-- are redrawn. The preview runs the same AutoSell.decide the server uses on your current
-- inventory and Codex, so "what will happen" is exactly what will happen.
-- Layout (reworked 2026-11-08, the old one showed every rule at once): one rarity ladder
-- ("Sell duplicates up to": Off, Common ... Legendary; everything up to the pick lights up in its
-- colour) with a sentence saying what it does, the two protections as switches side by side, and
-- an "Advanced" fold with the per-rarity chips (tap to cycle Keep -> Sell dupes -> Sell all) and
-- the two extra rules. A custom mix opens the fold. One line on your likely next find closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetInventory = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local InventoryAction = Remotes:WaitForChild("InventoryAction") :: RemoteFunction
local GetCodex = Remotes:WaitForChild("GetCodex") :: RemoteFunction

local AutoSellPanel = {}

local ROW_HEIGHT = 52
local CHIP_HEIGHT = 50
local LADDER_HEIGHT = 50
-- Highest rarity the quick row offers; rarer finds are always worth a look.
local QUICK_MAX_TIER = 5
local MODE_SHORT = { Keep = "Keep", SellDuplicates = "Sell dupes", SellAll = "Sell all" }
local MODE_COLORS = {
	Keep = Color3.fromRGB(120, 230, 140),
	SellDuplicates = Color3.fromRGB(240, 194, 104),
	SellAll = Color3.fromRGB(240, 110, 96),
}
local KEEP_COLOR = Color3.fromRGB(120, 230, 140)

local function nextIn<T>(list: { T }, current: T): T
	local index = table.find(list, current) or 0
	return list[index % #list + 1]
end

local function thresholdLabel(value: number): string
	return if value <= 0 then "Off" else `1 in {Format.number(value)}`
end

-- The quick-row choice the rules match exactly ("Off", a tier id), or nil for a custom mix.
local function quickChoice(rules: AutoSell.Rules): string?
	local highest: string? = nil
	local sawKeep = false
	for _, tier in RarityConfig.Tiers do
		local mode = rules.Tiers[tier.Id] or "Keep"
		if mode == "SellDuplicates" then
			if sawKeep then
				return nil
			end
			highest = tier.Id
		elseif mode == "Keep" then
			sawKeep = true
		else
			return nil
		end
	end
	return highest or "Off"
end

function AutoSellPanel.Start(screen: ScreenGui): { Open: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local state: any = nil
	local discovered: { [string]: number } = {}

	local panel, content =
		UIKit.modal(screen, "AutoSellMenu", "AUTO-SELL", colors.Coral, Vector2.new(560, 560), "Backpack")
	local body = UIKit.scrollList(content, 10)
	body.ScrollBarImageColor3 = colors.Trim
	local order = 0
	local advancedOpen = false

	local function nextOrder(): number
		order += 1
		return order
	end

	local function clear()
		order = 0
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function heading(value: string)
		UIKit.heading({
			LayoutOrder = nextOrder(),
			Text = value,
			TextSize = 19,
			Size = UDim2.new(1, -10, 0, 24),
			Parent = body,
		})
	end

	local function line(value: string, color: Color3?, size: number?): TextLabel
		return UIKit.label({
			LayoutOrder = nextOrder(),
			Text = value,
			TextSize = size or 18,
			TextColor3 = color or colors.SubText,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -10, 0, 0),
			Parent = body,
		})
	end

	local function grid(name: string, columns: number): Frame
		return UIKit.create("Frame", {
			Name = name,
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -10, 0, 0),
			Parent = body,
		}, {
			UIKit.create("UIGridLayout", {
				CellSize = UDim2.new(1 / columns, -6, 0, CHIP_HEIGHT),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
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

	-- A full-width row: label left, switch right.
	local function switchRow(label: string, on: boolean, onToggle: (boolean) -> ())
		local frame = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = body,
		}, { UIKit.corner(10) })
		UIKit.skinCard(frame)
		UIKit.label({
			Text = label,
			TextSize = 18,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -100, 1, 0),
			Parent = frame,
		})
		UIKit.switch(frame, on, onToggle, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
		})
	end

	-- A half-width card in a horizontal row: label left, switch right.
	local function switchCard(parent: Frame, index: number, label: string, on: boolean, onToggle: (boolean) -> ())
		local frame = UIKit.create("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(0.5, -4, 1, 0),
			BackgroundColor3 = colors.Card,
			Parent = parent,
		}, { UIKit.corner(10) })
		UIKit.skinCard(frame)
		UIKit.label({
			Text = label,
			TextSize = 18,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -96, 1, 0),
			Parent = frame,
		})
		UIKit.switch(frame, on, onToggle, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
		})
	end

	-- What your most likely next find (most common rarity at your luck, a relic you own) would do.
	local function nextFindLine(): (string, Color3)
		local ctx = Odds.current()
		local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
		local bestIndex = 1
		for index, mass in masses do
			if mass > masses[bestIndex] then
				bestIndex = index
			end
		end
		local tierId = ctx.Tiers[bestIndex].Id
		local tier = RarityConfig.Get(tierId)
		local relic: RelicConfig.Relic? = nil
		for _, candidate in RelicConfig.Relics do
			if candidate.Tier == tierId and (relic == nil or discovered[candidate.Id] ~= nil) then
				relic = candidate
				if discovered[candidate.Id] then
					break
				end
			end
		end
		if not relic then
			return "", colors.SubText
		end
		-- The line describes a plain duplicate of a relic you already found.
		local sell, reason = AutoSell.decide(state.AutoSell, {
			Tier = relic.Tier,
			BaseOneIn = 1 / math.max(Odds.baseItem(relic.Id), 1e-300),
			First = false,
			Mutated = false,
			Duplicate = true,
			Favorite = false,
		})
		local verb = if sell then "SOLD" else "KEPT"
		return `Next {if tier then tier.Name else tierId} duplicate: {verb} ({AutoSell.ReasonText[reason]})`,
			if sell then colors.Red else KEEP_COLOR
	end

	function render()
		clear()
		if not state then
			return
		end
		local rules = state.AutoSell

		local quick = quickChoice(rules)
		if quick == nil then
			advancedOpen = true
		end
		if state.Count >= state.Capacity then
			line(`Backpack full ({state.Count}/{state.Capacity}): sell relics to keep scanning.`, colors.Red)
		end

		-- The ladder: everything up to the pick lights up in its rarity colour.
		heading("Sell duplicates up to")
		local ladder = UIKit.create("Frame", {
			Name = "Ladder",
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, LADDER_HEIGHT),
			Parent = body,
		}, {
			UIKit.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		})
		local quickOptions = { { Id = "Off", Text = "Off", Index = 0 } }
		for index, tier in RarityConfig.Tiers do
			if index > QUICK_MAX_TIER then
				break
			end
			table.insert(quickOptions, { Id = tier.Id, Text = tier.Name, Index = index })
		end
		local chosenIndex = -1
		for _, option in quickOptions do
			if option.Id == quick then
				chosenIndex = option.Index
			end
		end
		local count = #quickOptions
		for _, option in quickOptions do
			local lit = option.Index > 0 and option.Index <= chosenIndex
			local chosen = option.Index == chosenIndex
			local tint = if option.Index == 0 then colors.SubText else UIKit.tierColor(option.Id)
			local chip = UIKit.button({
				Name = option.Id,
				LayoutOrder = option.Index,
				Text = option.Text,
				TextSize = 16,
				TextScaled = true,
				Size = UDim2.new(1 / count, -6 + 6 / count, 1, 0),
				Parent = ladder,
			}, function()
				save(function(draft)
					local on = option.Id ~= "Off"
					for _, tier in RarityConfig.Tiers do
						draft.Tiers[tier.Id] = if on then "SellDuplicates" else "Keep"
						if tier.Id == option.Id then
							on = false
						end
					end
				end)
			end)
			UIKit.create("UITextSizeConstraint", { MaxTextSize = 17, Parent = chip })
			UIKit.create("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				Parent = chip,
			})
			UIKit.skinButton(chip, "Dark")
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			if lit then
				chip.BackgroundColor3 = tint:Lerp(colors.Card, 0.2)
				chip.TextColor3 = colors.Panel
			elseif chosen then
				chip.BackgroundColor3 = colors.Track
				chip.TextColor3 = colors.Text
			else
				chip.TextColor3 = tint
			end
			if stroke then
				stroke.Color = if chosen then colors.Text else tint
				stroke.Thickness = if chosen then 3 else 1.5
				stroke.Transparency = if chosen then 0 elseif lit then 0.2 else 0.65
			end
		end
		local quickTier = if quick and quick ~= "Off" then RarityConfig.Get(quick) else nil
		local summary = if quick == nil then "Custom rules (see Advanced)."
			elseif quickTier then `Duplicates up to {quickTier.Name} are sold for CE as they drop.`
			else "Off: every find is kept."
		line(summary, if quickTier then colors.Text else colors.SubText, 18)

		-- Protections, side by side.
		heading("Never sell")
		local protect = UIKit.create("Frame", {
			Name = "Protect",
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			Parent = body,
		}, {
			UIKit.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		})
		switchCard(protect, 1, "First finds", rules.ProtectFirst, function(on)
			save(function(draft)
				draft.ProtectFirst = on
			end)
		end)
		switchCard(protect, 2, "Mutations", rules.ProtectMutated, function(on)
			save(function(draft)
				draft.ProtectMutated = on
			end)
		end)
		line("Favorite, locked and placed relics are always safe.", colors.SubText, 15)

		-- Advanced fold.
		local fold = UIKit.button({
			Name = "Advanced",
			LayoutOrder = nextOrder(),
			Text = if advancedOpen then "Fewer rules  -" else "More rules  +",
			TextSize = 18,
			Size = UDim2.new(1, -10, 0, 36),
			Parent = body,
		}, function()
			advancedOpen = not advancedOpen
			render()
		end)
		UIKit.skinButton(fold, "Dark")
		fold.TextColor3 = colors.SubText
		if advancedOpen then
			local tierGrid = grid("Tiers", 4)
			for index, tier in RarityConfig.Tiers do
				local mode = rules.Tiers[tier.Id] or "Keep"
				local chip = UIKit.button({
					Name = tier.Id,
					LayoutOrder = index,
					Text = "",
					Parent = tierGrid,
				}, function()
					save(function(draft)
						draft.Tiers[tier.Id] = nextIn(AutoSell.Modes, mode)
					end)
				end)
				UIKit.skinButton(chip, "Dark")
				local stroke = chip:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = MODE_COLORS[mode]
					stroke.Transparency = if mode == "Keep" then 0.6 else 0
					stroke.Thickness = if mode == "Keep" then 1.5 else 2.5
				end
				UIKit.label({
					Text = tier.Name,
					TextSize = 16,
					TextScaled = true,
					TextColor3 = UIKit.tierColor(tier.Id),
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(4, 5),
					Size = UDim2.new(1, -8, 0, 18),
					Parent = chip,
				})
				UIKit.label({
					Text = MODE_SHORT[mode],
					TextSize = 16,
					TextScaled = true,
					TextColor3 = MODE_COLORS[mode],
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(4, 25),
					Size = UDim2.new(1, -8, 0, 18),
					Parent = chip,
				})
			end
			switchRow("Duplicates of any rarity", rules.SellAllDuplicates, function(on)
				save(function(draft)
					draft.SellAllDuplicates = on
				end)
			end)
			local easier = UIKit.create("Frame", {
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
				BackgroundColor3 = colors.Card,
				Parent = body,
			}, { UIKit.corner(10) })
			UIKit.skinCard(easier)
			UIKit.label({
				Text = "Anything more common than",
				TextSize = 18,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -150, 1, 0),
				Parent = easier,
			})
			local cycle = UIKit.button({
				Text = thresholdLabel(rules.SellEasierThan),
				TextSize = 17,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(124, ROW_HEIGHT - 14),
				Parent = easier,
			}, function()
				save(function(draft)
					draft.SellEasierThan = nextIn(AutoSell.ThresholdPresets, rules.SellEasierThan)
				end)
			end)
			UIKit.skinButton(cycle, if rules.SellEasierThan > 0 then "Sell" else "Dark")
		end

		local text, color = nextFindLine()
		if text ~= "" then
			line(text, color, 19)
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
			UIKit.show(panel)
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
