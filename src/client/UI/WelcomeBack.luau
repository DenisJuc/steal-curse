-- Welcome Back screen (GDD 2.2, 9.4), pushed by AfkService when you open the game (offline CE and
-- the AFK stretch you left running) or come back after an anti-AFK server hop. Shows the CE
-- earned, the AFK stats and a scrollable list of everything unlocked while you were AFK.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local WelcomeBack = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WelcomeBack") :: RemoteEvent

local WelcomeBackPanel = {}

local HEADLINE_HEIGHT = 40
local SUMMARY_HEIGHT = 84
local HEADER_HEIGHT = 20
local BUTTON_HEIGHT = 42
local ROW_HEIGHT = 40

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
	local panel, content = UIKit.modal(screen, "WelcomeBack", "WELCOME BACK", colors.Gold, Vector2.new(480, 580))
	local headline = UIKit.label({
		TextSize = 30,
		TextColor3 = colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, HEADLINE_HEIGHT),
		Parent = content,
	})
	local summary = UIKit.label({
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, HEADLINE_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, SUMMARY_HEIGHT),
		Parent = content,
	})
	local listTop = HEADLINE_HEIGHT + 4 + SUMMARY_HEIGHT + 4
	local header = UIKit.label({
		Text = "UNLOCKED WHILE YOU WERE AFK",
		TextSize = 13,
		TextColor3 = colors.SubText,
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
	UIKit.button({
		Text = "Collect",
		TextSize = 18,
		BackgroundColor3 = colors.Gold,
		TextColor3 = colors.Panel,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(180, BUTTON_HEIGHT),
		Parent = content,
	}, function()
		panel.Visible = false
	end)

	local function addRow(order: number, title: string, subtitle: string, color: Color3)
		local row = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, { UIKit.corner(8) })
		UIKit.create("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(0, 4, 1, -10),
			Parent = row,
		}, { UIKit.corner(2) })
		UIKit.label({
			Text = title,
			TextSize = 14,
			TextColor3 = color,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(16, 3),
			Size = UDim2.new(1, -22, 0, 18),
			Parent = row,
		})
		UIKit.label({
			Text = subtitle,
			TextSize = 12,
			TextColor3 = colors.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(16, 21),
			Size = UDim2.new(1, -22, 0, 15),
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
		local lines = {}
		if offline then
			total += offline.Amount
			local capped = if offline.Seconds > offline.PaidSeconds
				then `, the shrine stores up to {Format.duration(offline.PaidSeconds)}`
				else ""
			table.insert(
				lines,
				`Offline for {Format.duration(offline.Seconds)}: +{Format.ce(offline.Amount)} CE `
					.. `({math.floor(Config.Offline.Rate * 100 + 0.5)}% of shrine income{capped})`
			)
		end
		if afk then
			total += afk.CE + afk.SoldCE
			local hops = if afk.Hops > 0 then ` ({plural(afk.Hops, "anti-AFK server hop")})` else ""
			table.insert(lines, `AFK for {Format.duration(afk.Seconds)}{hops}: +{Format.ce(afk.CE)} CE shrine income`)
			local sold = if afk.Sold > 0
				then `, {Format.number(afk.Sold)} auto-sold for +{Format.ce(afk.SoldCE)} CE`
				else ""
			table.insert(lines, `{plural(afk.Scans, "scan")}, {plural(afk.Discoveries, "relic")} found{sold}`)
		else
			table.insert(lines, "No relics are found while you're offline. Your Spirit Resonator is scanning again.")
		end
		headline.Text = `+{Format.ce(total)} CE`
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
		panel.Visible = true
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
