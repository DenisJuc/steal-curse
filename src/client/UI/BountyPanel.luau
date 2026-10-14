-- Bounties menu (BountyService): today's Easy / Medium / Hard bounty and this week's, with
-- progress, rewards, Claim and the one free reroll a day, plus the claim streak and its next
-- chest. Opened at the Bounty Board kiosk in the hub; the server validates everything and
-- answers with the fresh view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Motion = require(script.Parent.Motion)
local Toasts = require(script.Parent.Toasts)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BountyAction = Remotes:WaitForChild("BountyAction") :: RemoteFunction
local BountiesUpdated = Remotes:WaitForChild("BountiesUpdated") :: RemoteEvent

local BountyPanel = {}

local ROW_HEIGHT = 92
local DIFFICULTY_COLORS = {
	Easy = Color3.fromRGB(120, 230, 140),
	Medium = Color3.fromRGB(130, 200, 255),
	Hard = Color3.fromRGB(255, 150, 90),
	Weekly = Color3.fromRGB(240, 194, 104),
}

function BountyPanel.Start(screen: ScreenGui): { Toggle: () -> (), Open: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "BountyMenu", "BOUNTIES", colors.Gold, Vector2.new(520, 560), "Journal")
	local list = UIKit.scrollList(content, 6)
	local busy = false

	local render: (view: any) -> ()

	local function act(action: string, argument: any)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, result = pcall(function()
				return BountyAction:InvokeServer(action, argument)
			end)
			busy = false
			if ok and type(result) == "table" then
				if type(result.Message) == "string" then
					Toasts.Show(result.Message, if string.find(result.Message, "claimed") then "Item" else nil)
				end
				render(result.View)
			end
		end)
	end

	local function row(order: number, entry: any, slot: number | string, canReroll: boolean)
		local color = DIFFICULTY_COLORS[entry.Difficulty] or colors.Text
		local done = entry.Progress >= entry.Goal
		local card = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, { UIKit.corner(8), UIKit.padding(8) })
		UIKit.skinCard(card, if done and not entry.Claimed then colors.Gold else nil)
		UIKit.label({
			Text = string.upper(entry.Difficulty),
			TextSize = 12,
			TextColor3 = color,
			Size = UDim2.new(1, -120, 0, 14),
			Parent = card,
		})
		UIKit.label({
			Text = entry.Text,
			TextSize = 15,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, -120, 0, 20),
			Parent = card,
		})
		local track = UIKit.create("Frame", {
			BackgroundColor3 = colors.Track,
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, -120, 0, 8),
			Parent = card,
		}, { UIKit.corner(4) })
		UIKit.create("Frame", {
			BackgroundColor3 = color,
			Size = UDim2.fromScale(math.clamp(entry.Progress / math.max(1, entry.Goal), 0, 1), 1),
			Parent = track,
		}, { UIKit.corner(4) })
		UIKit.label({
			Text = `{entry.Progress}/{entry.Goal}   Reward: {entry.Reward}`,
			TextSize = 12,
			TextColor3 = colors.SubText,
			Position = UDim2.fromOffset(0, 54),
			Size = UDim2.new(1, -120, 0, 16),
			Parent = card,
		})
		local button: TextButton? = nil
		if entry.Claimed then
			UIKit.label({
				Text = "Claimed",
				TextSize = 15,
				TextColor3 = colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(104, 36),
				Parent = card,
			})
		elseif done then
			button = UIKit.button({
				Text = "Claim",
				TextSize = 16,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(104, 38),
				Parent = card,
			}, function()
				act("Claim", slot)
			end)
			UIKit.skinButton(button :: TextButton, "Gold")
			Motion.shine(button :: TextButton, 0.6)
		elseif canReroll then
			button = UIKit.button({
				Text = "Reroll",
				TextSize = 14,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(104, 34),
				Parent = card,
			}, function()
				act("Reroll", slot)
			end)
			UIKit.skinButton(button :: TextButton, "Dark")
		end
	end

	function render(view: any)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if type(view) ~= "table" then
			return
		end
		local order = 1
		local chest = view.NextChest
		UIKit.label({
			LayoutOrder = order,
			Text = `Streak: {view.Streak or 0} day{if view.Streak == 1 then "" else "s"}{if view.DoneToday then " (today done)" else ""}`
				.. (if type(chest) == "table" then `   |   Day {chest.Day} chest: {chest.Reward}` else ""),
			TextSize = 14,
			TextColor3 = colors.Gold,
			TextWrapped = true,
			Size = UDim2.new(1, -10, 0, 34),
			Parent = list,
		})
		order += 1
		UIKit.heading({
			LayoutOrder = order,
			Text = `Today (new bounties in {Format.duration(tonumber(view.ResetsIn) or 0)})`,
			TextSize = 16,
			Size = UDim2.new(1, -10, 0, 26),
			Parent = list,
		})
		for index, entry in view.Slots or {} do
			order += 1
			row(order, entry, index, not view.Rerolled)
		end
		if type(view.Weekly) == "table" then
			order += 1
			UIKit.heading({
				LayoutOrder = order,
				Text = "This week",
				TextSize = 16,
				Size = UDim2.new(1, -10, 0, 26),
				Parent = list,
			})
			order += 1
			row(order, view.Weekly, "Weekly", false)
		end
	end

	local function load()
		act("Get", nil)
	end

	BountiesUpdated.OnClientEvent:Connect(function(view)
		if panel.Visible then
			render(view)
		end
	end)

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				load()
			end
		end,
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

return BountyPanel
