-- Rebirth menu (Shared/Rebirth). Before/after cards for the permanent income and luck
-- multipliers, what resets and what you keep, a CE bar toward the cost and a jade "Rebirth" price
-- button that asks for a second tap to confirm. Numbers come from the shared Rebirth math and the
-- CE / Rebirths attributes; the server re-checks the cost (Remote "Rebirth").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local RebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction

local RebirthPanel = {}

local ARROW = "\u{2192}"
local CONFIRM_SECONDS = 4
local RESETS = { "Cursed Energy", "Pedestal levels", "Skill ranks" }
local KEEPS = {
	"Relics and pedestal slots",
	"Codex, titles and bonuses",
	"Showcases and lanterns",
	"Zone mastery and potions",
}

function RebirthPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local settings = Config.Rebirth
	local jade = "#" .. colors.Jade:ToHex()

	local panel, content = UIKit.modal(screen, "RebirthMenu", "REBIRTH", colors.Jade, Vector2.new(560, 560), "Rebirth")

	local heading = UIKit.label({
		Name = "Count",
		RichText = true,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})

	-- Before -> after cards.
	local function statCard(x: number, title: string): TextLabel
		local card = UIKit.create("Frame", {
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 32),
			Size = UDim2.new(0.5, -6, 0, 76),
			BackgroundColor3 = colors.Card,
			Parent = content,
		}, { UIKit.corner(10) })
		UIKit.skinCard(card, colors.Jade)
		UIKit.label({
			Text = title,
			TextSize = 15,
			TextColor3 = colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 18),
			Parent = card,
		})
		return UIKit.label({
			RichText = true,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 32),
			Parent = card,
		})
	end
	local incomeValue = statCard(0, "Income (forever)")
	local luckValue = statCard(0.5, "Luck (forever)")

	-- What resets / what stays, as two lists with a colored marker each.
	local function list(x: number, title: string, color: Color3, lines: { string })
		local column = UIKit.create("Frame", {
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 120),
			Size = UDim2.new(0.5, -6, 0, 150),
			BackgroundColor3 = colors.Card,
			Parent = content,
		}, { UIKit.corner(10), UIKit.padding(10) })
		UIKit.skinCard(column)
		UIKit.label({
			Text = title,
			TextSize = 16,
			TextColor3 = color,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = column,
		})
		for index, line in lines do
			local y = 26 + (index - 1) * 26
			UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(2, y + 10),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = column,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			UIKit.label({
				Text = line,
				TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(20, y),
				Size = UDim2.new(1, -20, 0, 20),
				Parent = column,
			})
		end
	end
	list(0, "Resets", colors.Red, RESETS)
	list(0.5, "You keep", colors.Jade, KEEPS)

	-- CE progress toward the cost.
	local track = UIKit.create("Frame", {
		Name = "Progress",
		Position = UDim2.fromOffset(0, 284),
		Size = UDim2.new(1, 0, 0, 22),
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
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = track,
	})

	local status = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 312),
		Size = UDim2.new(1, 0, 0, 40),
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
		Position = UDim2.new(0.5, 0, 0, 358),
		Size = UDim2.fromOffset(280, 46),
		TextSize = 20,
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
				end
			end
			refresh()
		end)
	end)

	function refresh()
		local count = player:GetAttribute("Rebirths") or 0
		local ce = player:GetAttribute("CE") or 0
		local price = Rebirth.cost(settings, count)
		heading.Text = `Rebirths: <b>{count}</b> {ARROW} <font color="{jade}">{count + 1}</font>`
		incomeValue.Text = `x{Format.multiplier(Rebirth.incomeMultiplier(settings, count))} {ARROW} <font color="{jade}">x{Format.multiplier(
			Rebirth.incomeMultiplier(settings, count + 1)
		)}</font>`
		luckValue.Text = `x{Format.multiplier(Rebirth.luckMultiplier(settings, count))} {ARROW} <font color="{jade}">x{Format.multiplier(
			Rebirth.luckMultiplier(settings, count + 1)
		)}</font>`
		fill.Size = UDim2.fromScale(math.clamp(ce / price, 0, 1), 1)
		progressText.Text = `{Format.ce(ce)} / {Format.ce(price)} CE`
		local affordable = ce + 1e-9 >= price
		UIKit.setPrice(rebirthButton, if confirming then "Tap again to confirm" else "Rebirth", price)
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
				status.Text = "Rebirth when the bar is full. Your next run earns and finds more."
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
