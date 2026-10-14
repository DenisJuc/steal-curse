-- End-of-hunt rolls: once the capture animation is over, the hunt's finds roll as a row of
-- omikuji papers (no boxes) in the middle of the screen. Each paper unrolls, flickers through
-- relics and gets its tier seal stamped; the captured relic goes first and the rarest finds land
-- last. Every find gets a paper, 5 papers per wave (Skip ends it). Purely cosmetic: everything was granted and saved by the server before this starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local ReelStrip = require(ReplicatedStorage.Shared.ReelStrip)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Settings = require(script.Parent.Parent.Settings)
local Motion = require(script.Parent.Motion)
local RelicViewport = require(script.Parent.RelicViewport)
local RollKit = require(script.Parent.RollStyles.RollKit)
local UIKit = require(script.Parent.UIKit)

local HuntRolls = {}

export type Header = {
	BonusCount: number?,
	BonusMultiplier: number?,
	Tags: { string }?,
}

local PAPER_SIZE = Vector2.new(124, 172)
local GAP = 12
local PER_WAVE = 5
local UNROLL_SECONDS = 0.25
local FLICKS_PER_SECOND = 9
local FLICKER_SECONDS = 0.85
-- Delay between neighbouring papers of a wave.
local STAGGER_SECONDS = 0.14
-- How long a finished wave stays up before the next one; the last wave stays longer.
local WAVE_HOLD_SECONDS = 0.9
local FINAL_HOLD_SECONDS = 2

local PAPER = Color3.fromRGB(244, 234, 212)
local INK = Color3.fromRGB(48, 32, 28)
local WOOD = Color3.fromRGB(70, 44, 30)
local BLACK = Color3.new(0, 0, 0)

local roster: { ReelStrip.Entry } = {}
for _, relic in RelicConfig.Relics do
	table.insert(roster, { Id = relic.Id, Tier = relic.Tier })
end
local stripOptions = {
	Length = Config.Roll.StripLength,
	LandIndex = Config.Roll.LandIndex,
	TierWeights = Config.Roll.TeaserTierWeights,
}
local rng = Random.new()
-- Every paper keeps its own renders (two papers often show the same relic at once).
local renders = RelicViewport.cache(60)

type Paper = {
	Frame: Frame,
	Sheet: Frame,
	Border: UIStroke,
	Art: Frame,
	Name: TextLabel,
	Detail: TextLabel,
	Seal: Frame,
	SealText: TextLabel,
	New: TextLabel,
}

type Ui = {
	Root: Frame,
	Header: TextLabel,
	Tags: TextLabel,
	Row: Frame,
	Footer: TextLabel,
}

local ui: Ui? = nil
local ticket = 0
local finishing: (() -> ())? = nil

local function ink(color: Color3): Color3
	return color:Lerp(BLACK, 0.35)
end

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 0 else 0
end

-- Sort key: tier first, mutated above plain within a tier.
local function rarityKey(result: any): number
	return tierIndex(result.Id) * 2 + (if result.Mutation then 1 else 0)
end

local function showRelic(holder: Frame, slot: number, relicId: string)
	local current = holder:FindFirstChild("Render")
	if current and current:GetAttribute("RelicId") == relicId then
		return
	end
	if current then
		current.Parent = nil
	end
	local render = renders.Get(`{slot}|{relicId}`, relicId)
	render.Size = UDim2.fromScale(1, 1)
	render.Parent = holder
end

local function build(screen: ScreenGui): Ui
	local colors = UIKit.Colors
	local width = PER_WAVE * PAPER_SIZE.X + (PER_WAVE + 1) * GAP
	local root = UIKit.create("Frame", {
		Name = "HuntRolls",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(width, PAPER_SIZE.Y + 92),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	UIKit.scaler(root)
	local header = UIKit.label({
		Name = "Header",
		FontFace = UIKit.TitleFont,
		TextSize = 24,
		TextColor3 = colors.Gold,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 21,
		Parent = root,
	})
	local tags = UIKit.label({
		Name = "Tags",
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 21,
		Parent = root,
	})
	local row = UIKit.create("Frame", {
		Name = "Row",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, PAPER_SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = root,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	})
	local footer = UIKit.label({
		Name = "Footer",
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 21,
		Parent = root,
	})
	local skip = UIKit.button({
		Name = "Skip",
		Text = "Skip",
		TextSize = 14,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(70, 26),
		ZIndex = 22,
		Parent = root,
	}, function()
		HuntRolls.Finish()
	end)
	UIKit.skinButton(skip, "Dark")
	return { Root = root, Header = header, Tags = tags, Row = row, Footer = footer }
end

-- One portrait fortune paper: wooden rods top and bottom, the relic, its name and odds; the seal
-- and the NEW! ribbon sit outside the paper's clipping so they can slam in big.
local function makePaper(row: Frame, order: number): Paper
	local colors = UIKit.Colors
	local frame = UIKit.create("Frame", {
		Name = "Paper" .. order,
		LayoutOrder = order,
		Size = UDim2.fromOffset(PAPER_SIZE.X, PAPER_SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = row,
	}, { UIKit.create("UIScale", { Name = "Juice" }) })
	local sheet = UIKit.create("Frame", {
		Name = "Sheet",
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = PAPER,
		ClipsDescendants = true,
		ZIndex = 22,
		Parent = frame,
	}, { UIKit.corner(3), UIKit.stroke(WOOD, 2, 0) })
	local content = UIKit.create("Frame", {
		Name = "Content",
		Size = UDim2.fromOffset(PAPER_SIZE.X, PAPER_SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = sheet,
	})
	for _, side in { 0, 1 } do
		UIKit.create("Frame", {
			Name = "Rod",
			AnchorPoint = Vector2.new(0, side),
			Position = UDim2.fromScale(0, side),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = WOOD,
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = content,
		})
	end
	local border = UIKit.create("Frame", {
		Name = "Border",
		Position = UDim2.fromOffset(6, 13),
		Size = UDim2.new(1, -12, 1, -26),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = content,
	})
	local borderStroke = UIKit.stroke(colors.Red, 1.5, 0.3)
	borderStroke.Parent = border
	local art = UIKit.create("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(78, 78),
		BackgroundTransparency = 1,
		ZIndex = 23,
		Parent = content,
	})
	local name = UIKit.label({
		Name = "RelicName",
		FontFace = UIKit.TitleFont,
		TextSize = 14,
		TextColor3 = INK,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(8, 98),
		Size = UDim2.new(1, -16, 0, 34),
		ZIndex = 23,
		Parent = content,
	})
	local detail = UIKit.label({
		Name = "Detail",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 134),
		Size = UDim2.new(1, -16, 0, 16),
		ZIndex = 23,
		Parent = content,
	})
	local seal = UIKit.create("Frame", {
		Name = "Seal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0, 26),
		Size = UDim2.fromOffset(40, 40),
		Rotation = -12,
		Visible = false,
		ZIndex = 25,
		Parent = frame,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(INK, 2, 0.2),
		UIKit.create("UIScale", { Name = "Juice" }),
	})
	local sealText = UIKit.label({
		Name = "Tier",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.84, 0.4),
		ZIndex = 26,
		Parent = seal,
	})
	local new = UIKit.label({
		Name = "New",
		Text = "NEW!",
		FontFace = UIKit.TitleFont,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = colors.Red,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(46, 20),
		Rotation = -10,
		Visible = false,
		ZIndex = 26,
		Parent = frame,
	})
	UIKit.corner(5).Parent = new
	return {
		Frame = frame,
		Sheet = sheet,
		Border = borderStroke,
		Art = art,
		Name = name,
		Detail = detail,
		Seal = seal,
		SealText = sealText,
		New = new,
	}
end

local function write(paper: Paper, slot: number, info: RollKit.Info, detail: string)
	showRelic(paper.Art, slot, info.Id)
	paper.Name.Text = info.Name
	paper.Detail.Text = detail
	paper.Detail.TextColor3 = ink(info.Color)
	paper.Border.Color = ink(info.Color)
end

local function land(paper: Paper, slot: number, result: any)
	local info = RollKit.info(result.Id, result.Mutation)
	write(paper, slot, info, if result.Sold then `{info.Odds} | sold` else info.Odds)
	local seal = paper.Seal
	seal.Visible = true
	seal.BackgroundColor3 = info.Color
	paper.SealText.Text = string.upper(info.TierName)
	local rainbow = seal:FindFirstChild("Rainbow")
	if rainbow then
		rainbow:Destroy()
	end
	if info.TierIndex >= RollKit.TierCount then
		seal.BackgroundColor3 = Color3.new(1, 1, 1)
		RollKit.rainbow(seal)
	end
	Motion.pop(seal, 0, 2.2 + math.max(0, info.TierIndex - 4) * 0.3)
	Motion.punch(paper.Frame, 1 + info.TierIndex * 0.2)
	Motion.flash(paper.Sheet, info.Color, 0.4)
	if result.First == true or result.NewVariant == true then
		paper.New.Text = if result.First then "NEW!" else "NEW VARIANT"
		paper.New.Size = UDim2.fromOffset(if result.First then 46 else 96, 20)
		paper.New.Visible = true
		Motion.pop(paper.New, 0.1, 0)
	end
	RollKit.impact(info, seal, paper.Frame, paper.Sheet)
end

-- Plays one paper: unrolls after `delay`, flickers for `seconds`, then lands on `result`. Returns
-- when it will have landed (seconds from now).
local function roll(paper: Paper, slot: number, result: any, delay: number, seconds: number, myTicket: number): number
	local teasers = ReelStrip.strip(result.Id, function()
		return rng:NextNumber()
	end, roster, stripOptions)
	write(paper, slot, RollKit.info(teasers[1]), "")
	local function alive(): boolean
		return ticket == myTicket and paper.Frame.Parent ~= nil
	end
	task.delay(delay, function()
		if not alive() then
			return
		end
		RollKit.tick(0, 0.7)
		TweenService:Create(
			paper.Sheet,
			TweenInfo.new(UNROLL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(1, 1) }
		):Play()
	end)
	task.delay(delay + UNROLL_SECONDS, function()
		if not alive() then
			return
		end
		local count = math.clamp(math.floor(seconds * FLICKS_PER_SECOND + 0.5), 4, #teasers)
		local first = #teasers - count + 1
		local cancel: (() -> ())? = nil
		cancel = RollKit.steps(count, seconds, function(step)
			if not alive() then
				if cancel then
					cancel()
				end
				return
			end
			if step >= count then
				land(paper, slot, result)
				return
			end
			local info = RollKit.info(teasers[first + step - 1])
			write(paper, slot, info, string.upper(info.TierName))
			Motion.punch(paper.Art, 1 + step / count)
			RollKit.tick(step / count)
		end)
	end)
	return delay + UNROLL_SECONDS + seconds
end

local function clearRow(row: Frame)
	renders.DetachAll()
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function footerText(results: { any }): string
	local new, sold, soldCE = 0, 0, 0
	for _, result in results do
		if result.First == true or result.NewVariant == true then
			new += 1
		end
		if type(result.Sold) == "number" then
			sold += 1
			soldCE += result.Sold
		end
	end
	local parts = {}
	if new > 0 then
		table.insert(parts, `{new} new to your Codex`)
	end
	if sold > 0 then
		table.insert(parts, `{sold} auto-sold (+{Format.number(soldCE)} CE)`)
	end
	return table.concat(parts, "   |   ")
end

-- Stops the rolls now (a newer hunt, or Spirit Sight).
function HuntRolls.Finish()
	local callback = finishing
	finishing = nil
	ticket += 1
	if ui then
		clearRow(ui.Row)
		ui.Root.Visible = false
	end
	if callback then
		callback()
	end
end

-- Rolls a hunt's batch (`results`, as sent by DiscoveryResult), then calls `onDone`.
function HuntRolls.Play(results: { any }, header: Header?, onDone: () -> ())
	HuntRolls.Finish()
	local current = ui
	if not current or Settings.Get("RollAnimation") == "Off" or #results == 0 then
		onDone()
		return
	end
	finishing = onDone
	local myTicket = ticket

	local speed = if Settings.Get("RollAnimation") == "Fast" then 0.55 else 1
	local captured, bonus = {}, {}
	for _, result in results do
		if type(result) == "table" and type(result.Id) == "string" and RelicConfig.ById[result.Id] then
			table.insert(if result.Source == "Capture" then captured else bonus, result)
		end
	end
	table.sort(bonus, function(a, b)
		return rarityKey(a) < rarityKey(b)
	end)
	local queue = table.clone(captured)
	table.move(bonus, 1, #bonus, #queue + 1, queue)

	local count = header and header.BonusCount or #results - #captured
	local boost = header and header.BonusMultiplier
	current.Header.Text = `Sealed!  +{count} bonus finds`
		.. (if boost and boost > 1 then `  (x{Format.multiplier(boost)})` else "")
	local tags = header and header.Tags
	current.Tags.Text = if tags and #tags > 0 then table.concat(tags, "  |  ") else ""
	current.Footer.Text = ""
	current.Root.Visible = true
	Motion.pop(current.Root, 0, 0.6)

	task.spawn(function()
		local waves = math.max(1, math.ceil(#queue / PER_WAVE))
		for wave = 1, waves do
			if ticket ~= myTicket then
				return
			end
			clearRow(current.Row)
			local finish = 0
			for slot = 1, PER_WAVE do
				local result = queue[(wave - 1) * PER_WAVE + slot]
				if not result then
					break
				end
				local paper = makePaper(current.Row, slot)
				-- A rare paper takes a little longer: the slow-down before its seal is the tease.
				local suspense = RollKit.suspense(RollKit.info(result.Id, result.Mutation))
				local seconds = (FLICKER_SECONDS + suspense * 0.6) * speed
				finish = math.max(finish, roll(paper, slot, result, (slot - 1) * STAGGER_SECONDS * speed, seconds, myTicket))
			end
			if waves > 1 then
				current.Footer.Text = `Wave {wave} of {waves}`
			end
			task.wait(finish)
			if ticket ~= myTicket then
				return
			end
			if wave == waves then
				current.Footer.Text = footerText(results)
			end
			task.wait(if wave == waves then FINAL_HOLD_SECONDS else WAVE_HOLD_SECONDS * speed)
		end
		if ticket == myTicket then
			HuntRolls.Finish()
		end
	end)
end

function HuntRolls.Start(screen: ScreenGui)
	ui = build(screen)
end

return HuntRolls
