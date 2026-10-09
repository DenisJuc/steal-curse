-- Relics menu (GDD 9.2, 12.1): held relics grouped by relic + mutation, with base and current
-- 1-in-X odds (RollMath via Odds), favorites, locks and manual selling. Every button sends an
-- intent; the server answers with the fresh inventory, which is redrawn as-is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetInventory = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local InventoryAction = Remotes:WaitForChild("InventoryAction") :: RemoteFunction

local InventoryPanel = {}

export type State = {
	Groups: { any },
	Count: number,
	Capacity: number,
	AutoSell: any,
}

local ROW_HEIGHT = 66
local REFRESH_SECONDS = 1

local function relicColor(relicId: string, mutation: string?): Color3
	if mutation then
		return UIKit.mutationColor(mutation)
	end
	local relic = RelicConfig.ById[relicId]
	return if relic then UIKit.tierColor(relic.Tier) else UIKit.Colors.Text
end

function InventoryPanel.Start(
	screen: ScreenGui,
	onOpenAutoSell: (State?) -> ()
): { Toggle: () -> (), SetVisible: (boolean) -> (), GetState: () -> State? }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local state: State? = nil

	local panel, content = UIKit.modal(screen, "RelicsMenu", "RELICS", colors.Gold, Vector2.new(560, 620))

	local countLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		Size = UDim2.new(0.5, 0, 0, 34),
		Parent = content,
	})
	UIKit.button({
		Text = "Auto-Sell Rules",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -6, 0, 34),
		Parent = content,
	}, function()
		onOpenAutoSell(state)
	end)
	local statusLabel = UIKit.label({
		TextSize = 13,
		TextColor3 = colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "Favorite: never auto-sold, pinned to top. Lock: can't be sold at all.",
		Parent = content,
	})
	local list = UIKit.scrollList(content, 4)
	list.Position = UDim2.fromOffset(0, 62)
	list.Size = UDim2.new(1, 0, 1, -62)

	local render: (State) -> ()

	local function send(action: string, ...: any)
		local args = table.pack(...)
		task.spawn(function()
			local ok, result = pcall(function()
				return InventoryAction:InvokeServer(action, table.unpack(args, 1, args.n))
			end)
			if ok and type(result) == "table" and result.State then
				if result.Message then
					statusLabel.Text = result.Message
				end
				render(result.State)
			end
		end)
	end

	local function rowButton(row: Frame, text: string, width: number, x: number, color: Color3, onClick: () -> ())
		return UIKit.button({
			Text = text,
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0.5, 0),
			Size = UDim2.fromOffset(width, 36),
			Parent = row,
		}, onClick)
	end

	function render(newState: State)
		state = newState
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local over = newState.Count - newState.Capacity
		local full = over >= 0
		countLabel.Text = `{if full then "[INVENTORY FULL] " else ""}Held {newState.Count} / {newState.Capacity}{if over > 0
			then `  (+{over} protected)`
			else ""}`
		countLabel.TextColor3 = if full then colors.Red else colors.Gold
		if #newState.Groups == 0 then
			UIKit.label({
				Text = "No relics yet. Your resonator finds one every few seconds.",
				TextColor3 = colors.SubText,
				TextSize = 14,
				Size = UDim2.new(1, -10, 0, 30),
				Parent = UIKit.create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = list }),
			})
			return
		end

		local ctx = Odds.current()
		for index, group in newState.Groups do
			local row = UIKit.create("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
				BackgroundColor3 = colors.Card,
				Parent = list,
			}, { UIKit.corner(8) })
			local textWidth = -258
			UIKit.label({
				Text = `{if group.Favorite then "* " else ""}{Odds.displayName(group.Id, group.Mutation)}`,
				TextSize = 15,
				TextColor3 = relicColor(group.Id, group.Mutation),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(1, textWidth, 0, 20),
				Parent = row,
			})
			local notes = {}
			if group.Displayed > 0 then
				table.insert(notes, `{group.Displayed} shown`)
			end
			if group.Locked > 0 then
				table.insert(notes, `{group.Locked} locked`)
			end
			UIKit.label({
				Text = `x{group.Count}{if #notes > 0 then ` ({table.concat(notes, ", ")})` else ""}  |  +{Format.number(
					group.IncomePerMin
				)}/min  |  sells {Format.number(group.SellValue)}`,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 25),
				Size = UDim2.new(1, textWidth, 0, 16),
				Parent = row,
			})
			local yours = RollMath.comboProbability(ctx, group.Id, group.Mutation)
			UIKit.label({
				Text = `Base {Format.odds(Odds.baseItem(group.Id))}  |  Yours {Format.odds(yours)}{if group.Mutation
					then ` ({group.Mutation})`
					else ""}`,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 43),
				Size = UDim2.new(1, textWidth, 0, 16),
				Parent = row,
			})

			local allLocked = group.Locked >= group.Count
			rowButton(row, "Sell all", 66, -6, colors.Accent, function()
				send("Sell", group.Id, group.Mutation, "All")
			end).Visible = group.Sellable > 0
			rowButton(row, "Sell 1", 54, -76, colors.Accent, function()
				send("Sell", group.Id, group.Mutation, 1)
			end).Visible = group.Sellable > 0
			rowButton(row, if allLocked then "Locked" else "Lock", 62, -134, if allLocked then colors.Gold else colors.Panel, function()
				send("Lock", group.Id, group.Mutation, not allLocked)
			end)
			rowButton(row, if group.Favorite then "Fav *" else "Fav", 50, -200, if group.Favorite
				then colors.Gold
				else colors.Panel, function()
				send("Favorite", group.Id, group.Mutation, not group.Favorite)
			end)
		end
	end

	local function load()
		task.spawn(function()
			local ok, result = pcall(function()
				return GetInventory:InvokeServer()
			end)
			if ok and type(result) == "table" and panel.Visible then
				render(result)
			end
		end)
	end

	-- New finds change the list while it's open; refresh at most once per REFRESH_SECONDS.
	local refreshQueued = false
	player:GetAttributeChangedSignal("InventoryCount"):Connect(function()
		if not panel.Visible or refreshQueued then
			return
		end
		refreshQueued = true
		task.delay(REFRESH_SECONDS, function()
			refreshQueued = false
			if panel.Visible then
				load()
			end
		end)
	end)

	return {
		Toggle = function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				load()
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
		GetState = function()
			return state
		end,
	}
end

return InventoryPanel
