-- Rebirth menu (Shared/Rebirth). Before/after cards for the permanent income and luck
-- multipliers, short Lose / Keep lists, a thick CE bar toward the cost and a big jade "Rebirth"
-- price button (it reads "Need X CE" until you can pay) that asks for a second tap to confirm. RESETS/KEEPS follow BalanceTrials.rebirthModel()
-- (Live vs SoftCap_P4 B+). Numbers come from shared Rebirth math; the server re-checks the cost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local RebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction

local RebirthPanel = {}

local ARROW = "\u{2192}"
local CONFIRM_SECONDS = 4
local LINE_HEIGHT = 30
local PROGRESS_HEIGHT = 36

local LIVE_RESETS = { "CE", "Pedestal levels", "Skill ranks" }
local LIVE_KEEPS = {
	"Relics and slots",
	"Codex and titles",
	"Showcases",
	"Mastery and potions",
	"Fusion progress",
}
local BPLUS_RESETS = { "CE" }
local BPLUS_KEEPS = {
	"Skill ranks",
	"Pedestal levels",
	"Relics and Codex",
	"Fusion Board",
	"Rebirth bonuses",
}
local CORE_BPLUS_KEEPS = {
	"Skills and pedestals",
	"Relics and Codex",
	"Rebirth bonuses",
}

-- The icon beside each Lose / Keep line (UI pass 2026-11-09), matched on the line's first words.
local LINE_ICONS = {
	{ "CE", "CursedEnergy" },
	{ "Skill", "Upgrades" },
	{ "Pedestal", "Pedestals" },
	{ "Relics", "Backpack" },
	{ "Codex", "Codex" },
	{ "Showcase", "Pedestals" },
	{ "Fusion", "Collection" },
	{ "Zone mastery", "Streak" },
	{ "Mastery", "Streak" },
	{ "Rebirth", "Rebirth" },
}
local function lineIcon(line: string): string?
	for _, pair in LINE_ICONS do
		if string.sub(line, 1, #pair[1]) == pair[1] then
			return pair[2]
		end
	end
	return nil
end

local function listsForModel(model: string): ({ string }, { string })
	if model == "BPlus" then
		if BalanceTrials.coreLoopPresentation() then
			return BPLUS_RESETS, CORE_BPLUS_KEEPS
		end
		return BPLUS_RESETS, BPLUS_KEEPS
	end
	if BalanceTrials.coreLoopPresentation() then
		local keeps = {
			"Relics and pedestal slots",
			"Codex, titles and bonuses",
			"Showcases and lanterns",
			"Zone mastery and potions",
		}
		return LIVE_RESETS, keeps
	end
	return LIVE_RESETS, LIVE_KEEPS
end

function RebirthPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local settings = BalanceTrials.rebirthSettings(Config.Rebirth)
	local jade = "#" .. colors.Jade:ToHex()
	local model = BalanceTrials.rebirthModel()
	local RESETS, KEEPS = listsForModel(model)

	-- Layout heights (content space). The panel is sized to fit them (it used to leave a big empty
	-- band under the button).
	local STAT_Y, STAT_H = 34, 104
	local LIST_Y = STAT_Y + STAT_H + 12
	local listH = 26 + 8 + math.max(#RESETS, #KEEPS) * LINE_HEIGHT + 20
	local progressY = LIST_Y + listH + 14
	local contentH = progressY + PROGRESS_HEIGHT + 32 + 60 + 12
	-- Window chrome: 10 px padding top and bottom plus the 46 px header.
	local panelH = contentH + 20 + 46
	local panel, content = UIKit.modal(screen, "RebirthMenu", "REBIRTH", colors.Jade, Vector2.new(560, panelH), "Rebirth")

	local heading = UIKit.label({
		Name = "Count",
		RichText = true,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = content,
	})

	-- A Shop-style tinted card with the thing's own icon (CE gem / luck clover) and its before ->
	-- after value (UI pass 2026-11-09).
	local function statCard(x: number, title: string, tint: Color3, iconKey: string): TextLabel
		local card = UIKit.create("Frame", {
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, STAT_Y),
			Size = UDim2.new(0.5, -6, 0, STAT_H),
			ClipsDescendants = true,
			Parent = content,
		}, { UIKit.corner(12) })
		UIKit.skinTintCard(card, tint)
		local icon = Icons.image(card, iconKey, 62)
		local left = 10
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 10, 0.5, 0)
			left = 80
		end
		UIKit.label({
			Text = title,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(230, 222, 240),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(left, 14),
			Size = UDim2.new(1, -left - 8, 0, 22),
			Parent = card,
		})
		return UIKit.label({
			RichText = true,
			TextSize = 30,
			TextScaled = true,
			TextStrokeTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(left, 42),
			Size = UDim2.new(1, -left - 8, 0, 38),
			Parent = card,
		})
	end
	local incomeValue = statCard(0, "Income forever", colors.Gold, "CursedEnergy")
	local luckValue = statCard(0.5, "Luck forever", colors.Accent, "Luck")
	for _, value in { incomeValue, luckValue } do
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 16, Parent = value })
	end

	-- Lose (red) and Keep (green) cards, each line with its own icon.
	local function list(x: number, title: string, color: Color3, lines: { string })
		local column = UIKit.create("Frame", {
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, LIST_Y),
			Size = UDim2.new(0.5, -6, 0, listH),
			Parent = content,
		}, { UIKit.corner(12), UIKit.padding(10) })
		UIKit.skinTintCard(column, color, 0.35)
		UIKit.label({
			Text = title,
			FontFace = UIKit.TitleFont,
			TextSize = 22,
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25),
			TextStrokeTransparency = 0.5,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = column,
		})
		local mark = if color == colors.Red then "\u{00D7}" else "\u{2713}"
		for index, line in lines do
			local y = 34 + (index - 1) * LINE_HEIGHT
			local key = lineIcon(line)
			local icon = if key then Icons.image(column, key, LINE_HEIGHT - 4) else nil
			if icon then
				icon.Position = UDim2.fromOffset(0, y)
			else
				UIKit.label({
					Text = mark,
					TextSize = 20,
					TextColor3 = color,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.fromOffset(LINE_HEIGHT - 4, LINE_HEIGHT - 4),
					Parent = column,
				})
			end
			UIKit.label({
				Text = line,
				TextSize = 18,
				TextScaled = true,
				Position = UDim2.fromOffset(LINE_HEIGHT + 2, y + 3),
				Size = UDim2.new(1, -(LINE_HEIGHT + 2), 0, LINE_HEIGHT - 10),
				Parent = column,
			})
		end
	end
	list(0, "Lose", colors.Red, RESETS)
	list(0.5, "Keep", colors.Jade, KEEPS)

	local track = UIKit.create("Frame", {
		Name = "Progress",
		Position = UDim2.fromOffset(0, progressY),
		Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT),
		BackgroundColor3 = colors.Track,
		BorderSizePixel = 0,
		Parent = content,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(colors.Trim, 1, 0.5),
	})
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = colors.Jade,
		BorderSizePixel = 0,
		Parent = track,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local progressText = UIKit.label({
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = track,
	})

	local status = UIKit.label({
		TextSize = 18,
		TextColor3 = colors.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, progressY + PROGRESS_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})

	local confirming = false
	local busy = false
	local rebirthButton: TextButton
	local refresh: () -> ()

	local function cost(): number
		return Rebirth.cost(settings, player:GetAttribute("Rebirths") or 0)
	end

	rebirthButton = UIKit.priceButton({
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, progressY + PROGRESS_HEIGHT + 32),
		Size = UDim2.fromOffset(340, 60),
		TextSize = 24,
		Parent = content,
	}, "Rebirth", cost(), function()
		if busy or (player:GetAttribute("CE") or 0) + 1e-9 < cost() then
			Motion.deny(rebirthButton)
			return
		end
		if not confirming then
			confirming = true
			refresh()
			task.delay(CONFIRM_SECONDS, function()
				if confirming then
					confirming = false
					refresh()
				end
			end)
			return
		end
		confirming = false
		busy = true
		task.spawn(function()
			local ok, result = pcall(function()
				return RebirthRemote:InvokeServer("Rebirth")
			end)
			busy = false
			if ok and type(result) == "table" and result.Message then
				status.Text = result.Message
				status.TextColor3 = if result.Ok then colors.Jade else colors.Red
				if result.Ok then
					Motion.purchased(panel)
					if model == "BPlus" and not BalanceTrials.coreLoopPresentation() then
						status.Text ..= " Open Collection to pick a Resonance."
					elseif model == "BPlus" then
						status.Text ..= " Keep sealing — Luck and income are permanently higher."
					end
				end
			end
			refresh()
		end)
	end)

	function refresh()
		local count = player:GetAttribute("Rebirths") or 0
		local ce = player:GetAttribute("CE") or 0
		local price = Rebirth.cost(settings, count)
		local modeTag = ""
		heading.Text = `Rebirths: <b>{count}</b> {ARROW} <font color="{jade}">{count + 1}</font>{modeTag}`
		incomeValue.Text = `x{Format.multiplier(Rebirth.incomeMultiplier(settings, count))} {ARROW} <font color="{jade}">x{Format.multiplier(
			Rebirth.incomeMultiplier(settings, count + 1)
		)}</font>`
		luckValue.Text = `x{Format.multiplier(Rebirth.luckMultiplier(settings, count))} {ARROW} <font color="{jade}">x{Format.multiplier(
			Rebirth.luckMultiplier(settings, count + 1)
		)}</font>`
		fill.Size = UDim2.fromScale(math.clamp(ce / price, 0, 1), 1)
		progressText.Text = `{Format.ce(ce)} / {Format.ce(price)} CE`
		local affordable = ce + 1e-9 >= price
		if affordable then
			UIKit.setPrice(rebirthButton, if confirming then "Tap again!" else "Rebirth", price)
		else
			UIKit.setPrice(rebirthButton, "Need", price - ce)
		end
		UIKit.setAffordable(rebirthButton, affordable and not busy, price)
		if confirming then
			UIKit.skinButton(rebirthButton, "Danger")
		end
	end

	player:GetAttributeChangedSignal("CE"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	refresh()

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				confirming = false
				-- The Resets / You keep boxes already say what happens; only add what they don't.
				status.Text = if model == "BPlus" and not BalanceTrials.coreLoopPresentation()
					then "After Rebirth, pick a Resonance in Collection."
					else ""
				status.TextColor3 = colors.SubText
				refresh()
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
				confirming = false
			end
		end,
	}
end

return RebirthPanel
