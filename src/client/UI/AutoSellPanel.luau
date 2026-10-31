-- Auto-sell rules menu (GDD 9.2). Every change is sent at once and the server's cleaned-up rules
-- are redrawn. The preview runs the same AutoSell.decide the server uses on your current
-- inventory and Codex, so "what will happen" is exactly what will happen.
-- Layout: a quick row ("Sell duplicates up to: Off / Common / ... / Legendary") that sets every
-- rarity at once, one compact chip per rarity (tap to cycle Keep -> Sell dupes -> Sell all) for the exact
-- rules, the two protection switches, the two extra rules, and one line on your likely next find.

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
local CHIP_HEIGHT = 56
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
		UIKit.modal(screen, "AutoSellMenu", "AUTO-SELL", colors.Accent, Vector2.new(600, 640), "Backpack")
	local body = UIKit.scrollList(content, 8)
	body.ScrollBarImageColor3 = colors.Trim
	local order = 0

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

	-- A row with a label on the left and an ON/OFF (or value) button on the right.
	local function switchRow(label: string, value: string, on: boolean, onClick: () -> ())
		local frame = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = body,
		}, { UIKit.corner(8) })
		UIKit.skinCard(frame)
		UIKit.label({
			Text = label,
			TextSize = 19,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Parent = frame,
		})
		local button = UIKit.button({
			Text = value,
			TextSize = 19,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(124, ROW_HEIGHT - 10),
			Parent = frame,
		}, onClick)
		UIKit.skinTab(button, on)
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

		line("New finds only. Favorite, locked and placed relics are safe.")
		if state.Count >= state.Capacity then
			line(`Backpack full ({state.Count}/{state.Capacity}): sell relics to keep scanning.`, colors.Red)
		end

		heading("Sell duplicates up to")
		local quick = quickChoice(rules)
		local quickGrid = grid("Quick", 3)
		local quickOptions = { { Id = "Off", Text = "Off" } }
		for index, tier in RarityConfig.Tiers do
			if index > QUICK_MAX_TIER then
				break
			end
			table.insert(quickOptions, { Id = tier.Id, Text = tier.Name })
		end
		for index, option in quickOptions do
			local chip = UIKit.button({
				Name = option.Id,
				LayoutOrder = index,
				Text = option.Text,
				TextSize = 19,
				Parent = quickGrid,
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
			UIKit.skinTab(chip, quick == option.Id)
			if option.Id ~= "Off" then
				chip.TextColor3 = if quick == option.Id then colors.Panel else UIKit.tierColor(option.Id)
			end
		end

		heading(if quick then "Each rarity" else "Each rarity (custom)")
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
				TextSize = 17,
				TextScaled = true,
				TextColor3 = UIKit.tierColor(tier.Id),
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(4, 5),
				Size = UDim2.new(1, -8, 0, 20),
				Parent = chip,
			})
			UIKit.label({
				Text = MODE_SHORT[mode],
				TextSize = 18,
				TextScaled = true,
				TextColor3 = MODE_COLORS[mode],
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(4, 27),
				Size = UDim2.new(1, -8, 0, 22),
				Parent = chip,
			})
		end

		heading("Protect")
		switchRow("First finds", if rules.ProtectFirst then "ON" else "OFF", rules.ProtectFirst, function()
			save(function(draft)
				draft.ProtectFirst = not rules.ProtectFirst
			end)
		end)
		switchRow("Mutated relics", if rules.ProtectMutated then "ON" else "OFF", rules.ProtectMutated, function()
			save(function(draft)
				draft.ProtectMutated = not rules.ProtectMutated
			end)
		end)

		heading("More")
		switchRow("Duplicates of any rarity", if rules.SellAllDuplicates then "ON" else "OFF", rules.SellAllDuplicates, function()
			save(function(draft)
				draft.SellAllDuplicates = not rules.SellAllDuplicates
			end)
		end)
		switchRow("Anything more common than", thresholdLabel(rules.SellEasierThan), rules.SellEasierThan > 0, function()
			save(function(draft)
				draft.SellEasierThan = nextIn(AutoSell.ThresholdPresets, rules.SellEasierThan)
			end)
		end)

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
