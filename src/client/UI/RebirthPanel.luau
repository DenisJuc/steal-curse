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

	local panelH = 620
	local panel, content = UIKit.modal(screen, "RebirthMenu", "REBIRTH", colors.Jade, Vector2.new(560, panelH), "Rebirth")

	local heading = UIKit.label({
		Name = "Count",
		RichText = true,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = content,
	})

	local function statCard(x: number, title: string): TextLabel
		local card = UIKit.create("Frame", {
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 34),
			Size = UDim2.new(0.5, -6, 0, 86),
			BackgroundColor3 = colors.Card,
			Parent = content,
		}, { UIKit.corner(10) })
		UIKit.skinCard(card, colors.Jade)
		UIKit.label({
			Text = title,
			TextSize = 18,
			TextColor3 = colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = card,
		})
		return UIKit.label({
			RichText = true,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 38),
			Parent = card,
		})
	end
	local incomeValue = statCard(0, "Income forever")
	local luckValue = statCard(0.5, "Luck forever")

	local listH = 26 + 8 + math.max(#RESETS, #KEEPS) * LINE_HEIGHT + 20
	local function list(x: number, title: string, color: Color3, lines: { string })
		local column = UIKit.create("Frame", {
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 132),
			Size = UDim2.new(0.5, -6, 0, listH),
			BackgroundColor3 = colors.Card,
			Parent = content,
		}, { UIKit.corner(10), UIKit.padding(10) })
		UIKit.skinCard(column)
		UIKit.label({
			Text = title,
			TextSize = 21,
			TextColor3 = color,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = column,
		})
		local mark = if color == colors.Red then "\u{2715}" else "\u{2713}"
		for index, line in lines do
			local y = 34 + (index - 1) * LINE_HEIGHT
			UIKit.label({
				Text = mark,
				TextSize = 20,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.fromOffset(22, LINE_HEIGHT - 4),
				Parent = column,
			})
			UIKit.label({
				Text = line,
				TextSize = 18,
				TextScaled = true,
				Position = UDim2.fromOffset(28, y + 3),
				Size = UDim2.new(1, -28, 0, LINE_HEIGHT - 10),
				Parent = column,
			})
		end
	end
	list(0, "Lose", colors.Red, RESETS)
	list(0.5, "Keep", colors.Jade, KEEPS)

	local progressY = 132 + listH + 14
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
