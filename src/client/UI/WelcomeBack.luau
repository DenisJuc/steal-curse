-- Welcome Back screen (GDD 2.2, 9.4), pushed by AfkService when you open the game (offline CE and
-- the AFK stretch you left running) or come back after an anti-AFK server hop. Shows the CE
-- earned as a big count-up, one short line of stats, the list of unlocks only when there are
-- some (AFK), and one big gold Collect button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Motion = require(script.Parent.Motion)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local WelcomeBack = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WelcomeBack") :: RemoteEvent

local WelcomeBackPanel = {}

local HEADLINE_HEIGHT = 84
local SUMMARY_HEIGHT = 30
local HEADER_HEIGHT = 24
local BUTTON_HEIGHT = 64
local ROW_HEIGHT = 48
local SHORT_SIZE = Vector2.new(480, 340)
local TALL_SIZE = Vector2.new(480, 580)

type Payload = {
	Offline: { Amount: number, Seconds: number, PaidSeconds: number }?,
	Afk: {
		Seconds: number,
		Scans: number,
		Discoveries: number,
		CE: number,
		Sold: number,
		SoldCE: number,
		Hops: number,
		Unlocks: { any },
		MoreUnlocks: number,
	}?,
}

local function plural(count: number, word: string): string
	return `{Format.number(count)} {word}{if count == 1 then "" else "s"}`
end

function WelcomeBackPanel.Start(screen: ScreenGui): { SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content = UIKit.modal(screen, "WelcomeBack", "WELCOME BACK", colors.Gold, TALL_SIZE)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
	local headline = UIKit.label({
		FontFace = UIKit.TitleFont,
		TextSize = 64,
		TextColor3 = colors.Gold,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, HEADLINE_HEIGHT),
		Parent = content,
	})
	local setHeadline = Motion.counter(headline, function(value: number): string
		return `+{Format.ce(value)} CE`
	end)
	local collectedTotal = 0
	local summary = UIKit.label({
		TextSize = 20,
		TextColor3 = colors.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, HEADLINE_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, SUMMARY_HEIGHT),
		Parent = content,
	})
	local listTop = HEADLINE_HEIGHT + 4 + SUMMARY_HEIGHT + 4
	local header = UIKit.heading({
		Text = "While you were away",
		TextSize = 19,
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Parent = content,
	})
	local holder = UIKit.create("Frame", {
		BackgroundColor3 = colors.Card,
		BackgroundTransparency = 0.5,
		Position = UDim2.fromOffset(0, listTop + HEADER_HEIGHT + 2),
		Size = UDim2.new(1, 0, 1, -(listTop + HEADER_HEIGHT + 2 + BUTTON_HEIGHT + 8)),
		Parent = content,
	}, { UIKit.corner(10), UIKit.padding(6) })
	local list = UIKit.scrollList(holder, 4)
	local collect: TextButton
	collect = UIKit.button({
		Text = "Collect",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.8, 0, 0, BUTTON_HEIGHT),
		Parent = content,
	}, function()
		if collectedTotal > 0 then
			local count = math.clamp(math.floor(4 + math.log10(collectedTotal + 1) * 1.5), 5, 14)
			Motion.payout(screen, collect.AbsolutePosition + collect.AbsoluteSize / 2, count)
			collectedTotal = 0
		end
		panel.Visible = false
	end)
	UIKit.skinButton(collect, "Gold")
	Motion.shineLoop(collect, 2.4)

	local function addRow(order: number, title: string, subtitle: string, color: Color3)
		local row = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, { UIKit.corner(8) })
		UIKit.skinCard(row)
		UIKit.create("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(0, 4, 1, -10),
			Parent = row,
		}, { UIKit.corner(2) })
		UIKit.label({
			Text = title,
			TextSize = 18,
			TextScaled = true,
			TextColor3 = color,
			Position = UDim2.fromOffset(16, 4),
			Size = UDim2.new(1, -22, 0, 20),
			Parent = row,
		})
		UIKit.label({
			Text = subtitle,
			TextSize = 15,
			TextScaled = true,
			TextColor3 = colors.SubText,
			Position = UDim2.fromOffset(16, 26),
			Size = UDim2.new(1, -22, 0, 17),
			Parent = row,
		})
	end

	local function addUnlock(order: number, unlock: any)
		if unlock.Kind == "Milestone" then
			local milestone = CodexBook.ById[unlock.Id]
			if milestone then
				addRow(order, "CODEX MILESTONE READY", `{Codex.goalText(CodexBook, milestone)}: claim it in the Codex`, colors.Gold)
			end
			return
		end
		local relic = RelicConfig.ById[unlock.Id]
		if not relic then
			return
		end
		local prefix = if unlock.New then "NEW! " elseif unlock.NewVariant then "NEW VARIANT! " else ""
		local count = if unlock.Count > 1 then `  x{unlock.Count}` else ""
		local color = if unlock.Mutation then UIKit.mutationColor(unlock.Mutation) else UIKit.tierColor(relic.Tier)
		addRow(order, prefix .. Odds.displayName(relic.Id, unlock.Mutation) .. count, Odds.describe(relic.Id, unlock.Mutation), color)
	end

	local function show(payload: Payload)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local offline, afk = payload.Offline, payload.Afk
		local total = 0
		-- One short line: how long, and what else happened.
		local parts = {}
		if offline then
			total += offline.Amount
			local stored = if offline.Seconds > offline.PaidSeconds then ` (max {Format.duration(offline.PaidSeconds)})` else ""
			table.insert(parts, `Away {Format.duration(offline.Seconds)}{stored}`)
		end
		if afk then
			total += afk.CE + afk.SoldCE
			table.insert(parts, `AFK {Format.duration(afk.Seconds)}`)
			table.insert(parts, plural(afk.Discoveries, "relic"))
			if afk.Sold > 0 then
				table.insert(parts, `{Format.number(afk.Sold)} sold`)
			end
		end
		local lines = { table.concat(parts, "  ·  ") }
		sizeLimit.MaxSize = if afk then TALL_SIZE else SHORT_SIZE
		collectedTotal = total
		setHeadline(0, true)
		task.delay(0.35, function()
			setHeadline(total)
		end)
		summary.Text = table.concat(lines, "\n")

		header.Visible = afk ~= nil
		holder.Visible = afk ~= nil
		if afk then
			for index, unlock in afk.Unlocks do
				addUnlock(index, unlock)
			end
			if #afk.Unlocks == 0 then
				addRow(1, "Nothing new this time", "Your relics and shrine kept working while you were away.", colors.SubText)
			elseif afk.MoreUnlocks > 0 then
				addRow(#afk.Unlocks + 1, `...and {afk.MoreUnlocks} more`, "See the Codex and the Journal for everything.", colors.SubText)
			end
		end
		UIKit.show(panel)
	end

	WelcomeBack.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and (type(payload.Offline) == "table" or type(payload.Afk) == "table") then
			show(payload)
		end
	end)

	return {
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return WelcomeBackPanel
