-- Reveal presentation (GDD 3.2). Every reward is already granted and saved by the server; this
-- only shows it. Small finds: spectral projection + soft tick (the feed line is DiscoveryFeed).
-- Medium/Large finds: an overlay card with the relic model, rarity flash and sound; Large adds a
-- dim backdrop, light rays and a camera zoom. Any click or tap skips the reveal on screen. A mutation is revealed as a
-- second stage after the base relic. Overlays queue in arrival order (Presentation queue); extra
-- ones are coalesced into "+N more in your Journal". Nothing here touches scanning or movement.
-- Scan finds arrive through RollReel once the roll reel has landed on them. A hunt's finds arrive
-- after the hunt papers (HuntRolls): only the new ones get a reveal then.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local Presentation = require(ReplicatedStorage.Shared.Presentation)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local MutationVFX = require(script.Parent.Parent.Effects.MutationVFX)
local RelicProjection = require(script.Parent.Parent.Effects.RelicProjection)
local Odds = require(script.Parent.Parent.UI.Odds)
local RollReel = require(script.Parent.Parent.UI.RollReel)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local RevealController = {}

local MEDIUM_INDEX = RarityConfig.IndexById[Config.Reveal.MediumTier]
local LARGE_INDEX = RarityConfig.IndexById[Config.Reveal.LargeTier]
local CARD_SIZE = Vector2.new(400, 300)
local CAMERA_ZOOM_FOV = 12

local SOURCE_TEXT: { [string]: string } = {
	Scan = "Found by your Spirit Resonator",
	Capture = "Sealed with Hold to Bind",
	Bonus = "Bonus discovery from a hunt",
	Debug = "Debug grant",
}

type Ui = {
	Dim: Frame,
	Flash: Frame,
	Card: Frame,
	Stroke: UIStroke,
	Rays: Frame,
	Viewport: ViewportFrame,
	TierLabel: TextLabel,
	NameLabel: TextLabel,
	OddsLabel: TextLabel,
	MutationLabel: TextLabel,
	NoteLabel: TextLabel,
	SkipButton: TextButton,
}

local ui: Ui
local queue = Presentation.newQueue(Config.Reveal.MaxQueued)
local running = false
local skipRequested = false
local showing = false
local showingLarge = false
local holdUntil = 0
local model: BasePart? = nil
local modelBase = CFrame.new()

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
end

local function build(screen: ScreenGui): Ui
	local colors = UIKit.Colors
	local dim = UIKit.create("Frame", {
		Name = "RevealDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	local flash = UIKit.create("Frame", {
		Name = "RevealFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 31,
		Parent = screen,
	})
	local card = UIKit.create("Frame", {
		Name = "RevealCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 32,
		Parent = screen,
	}, { UIKit.corner(16), UIKit.padding(12) })
	UIKit.scaler(card)
	local stroke = UIKit.stroke(colors.Accent, 3, 0)
	stroke.Parent = card
	UIKit.skinPanel(card)
	stroke.Thickness = 3
	stroke.Transparency = 0

	local rays = UIKit.create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(230, 230),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = card,
	})
	for index = 0, 3 do
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 10),
			Rotation = index * 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 32,
			Parent = rays,
		}, {
			UIKit.create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end

	local tierLabel = UIKit.label({
		Name = "Tier",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 34,
		Parent = card,
	})
	local viewport = UIKit.create("ViewportFrame", {
		Name = "Model",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(220, 150),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		ZIndex = 33,
		Parent = card,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, 8), Vector3.new(0, 0.3, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local nameLabel = UIKit.label({
		Name = "RelicName",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 188),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 34,
		Parent = card,
	})
	local oddsLabel = UIKit.label({
		Name = "Odds",
		TextSize = 15,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 216),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 34,
		Parent = card,
	})
	local mutationLabel = UIKit.label({
		Name = "Mutation",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 236),
		Size = UDim2.new(1, 0, 0, 24),
		Visible = false,
		ZIndex = 34,
		Parent = card,
	})
	local noteLabel = UIKit.label({
		Name = "Note",
		TextSize = 13,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -90, 0, 18),
		ZIndex = 34,
		Parent = card,
	})
	local skipButton = UIKit.button({
		Name = "Skip",
		Text = "Skip",
		TextSize = 15,
		BackgroundColor3 = colors.Card,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(80, 30),
		Visible = false,
		ZIndex = 35,
		Parent = card,
	}, function()
		RevealController.Skip()
	end)

	return {
		Dim = dim,
		Flash = flash,
		Card = card,
		Stroke = stroke,
		Rays = rays,
		Viewport = viewport,
		TierLabel = tierLabel,
		NameLabel = nameLabel,
		OddsLabel = oddsLabel,
		MutationLabel = mutationLabel,
		NoteLabel = noteLabel,
		SkipButton = skipButton,
	}
end

local function setModel(relicId: string)
	if model then
		model:Destroy()
		model = nil
	end
	local part = RelicModels.build(relicId, CFrame.new(), 1.15)
	if not part then
		return
	end
	part.Parent = ui.Viewport
	model = part
	modelBase = part.CFrame
end

local function flash(color: Color3, from: number, seconds: number)
	if Settings.LowEffects() then
		return
	end
	ui.Flash.BackgroundColor3 = color
	ui.Flash.BackgroundTransparency = from
	ui.Flash.Visible = true
	UIKit.tween(ui.Flash, seconds, { BackgroundTransparency = 1 })
end

-- Waits up to `seconds`; returns false if the player skipped.
local function waitUnlessSkipped(seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if skipRequested then
			return false
		end
		task.wait(0.03)
	end
	return not skipRequested
end

local function play(entry: Presentation.Entry, dropped: number)
	local result = entry.Result
	local relic = RelicConfig.ById[result.Id]
	if not relic then
		return
	end
	local category: Presentation.Category = entry.Category
	local large = category == "Large"
	local mutation: string? = result.Mutation
	local baseSeconds, mutationSeconds = Presentation.durations(category, mutation ~= nil, Config.Reveal)
	local tierColor = UIKit.tierColor(relic.Tier)
	local tier = RarityConfig.Get(relic.Tier)
	local low = Settings.LowEffects()

	skipRequested = false
	showing = true
	showingLarge = large
	setModel(relic.Id)
	ui.TierLabel.Text = string.upper(if tier then tier.Name else relic.Tier)
	ui.TierLabel.TextColor3 = tierColor
	ui.NameLabel.Text = (if result.First then "NEW! " else "") .. relic.Name
	ui.NameLabel.TextColor3 = tierColor
	ui.OddsLabel.Text = `Base odds {Odds.describe(relic.Id, nil)}`
	ui.MutationLabel.Visible = false
	ui.Stroke.Color = tierColor
	local note = SOURCE_TEXT[result.Source] or ""
	if dropped > 0 then
		note = `+{dropped} more rare find{if dropped == 1 then "" else "s"} in your Journal`
	end
	ui.NoteLabel.Text = note
	ui.SkipButton.Visible = true
	ui.Rays.Visible = large and not low
	for _, ray in ui.Rays:GetChildren() do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = tierColor
		end
	end

	ui.Dim.Visible = large
	ui.Dim.BackgroundTransparency = 1
	if large then
		UIKit.tween(ui.Dim, 0.3, { BackgroundTransparency = 0.45 })
	end
	ui.Card.Size = UDim2.fromOffset(CARD_SIZE.X * 0.8, CARD_SIZE.Y * 0.8)
	ui.Card.BackgroundTransparency = 0.05
	ui.Card.Visible = true
	UIKit.tween(ui.Card, 0.22, { Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y) }, Enum.EasingStyle.Back)
	flash(tierColor, if large then 0.35 else 0.7, if large then 0.9 else 0.45)
	Sounds.Play(if large then "RevealLarge" else "RevealMedium")
	RelicProjection.Spawn(relic.Id, mutation, category, baseSeconds + mutationSeconds, low)

	local camera = workspace.CurrentCamera
	local baseFov = camera and camera.FieldOfView
	local zoom = large and Settings.Get("Camera") == "On" and camera ~= nil
	if zoom and camera and baseFov then
		UIKit.tween(camera, 0.35, { FieldOfView = baseFov - CAMERA_ZOOM_FOV })
	end

	local finished = waitUnlessSkipped(baseSeconds)
	if finished and mutation then
		local mutationInfo = MutationConfig.ById[mutation]
		local color = MutationVFX.Color(mutation) or tierColor
		ui.MutationLabel.Text = `+ {string.upper(mutation)} MUTATION`
			.. (if mutationInfo then `  (x{mutationInfo.IncomeMultiplier} income)` else "")
		ui.MutationLabel.TextColor3 = color
		ui.MutationLabel.Visible = true
		ui.NameLabel.Text = (if result.First then "NEW! " else "") .. Odds.displayName(relic.Id, mutation)
		ui.NameLabel.TextColor3 = color
		ui.Stroke.Color = color
		if model then
			MutationVFX.Apply(model, mutation, { Highlight = false, Particles = false })
		end
		flash(color, if large then 0.45 else 0.75, 0.5)
		Sounds.Play("Mutation")
		waitUnlessSkipped(mutationSeconds)
	end

	if zoom and camera and baseFov then
		UIKit.tween(camera, 0.5, { FieldOfView = baseFov })
	end
	showingLarge = false
	showing = false
	ui.SkipButton.Visible = false
	-- A skipped reveal vanishes at once; a finished one fades out.
	if not skipRequested then
		UIKit.tween(ui.Card, 0.18, { BackgroundTransparency = 1, Size = UDim2.fromOffset(CARD_SIZE.X * 0.9, CARD_SIZE.Y * 0.9) })
		if large then
			UIKit.tween(ui.Dim, 0.25, { BackgroundTransparency = 1 })
		end
		task.wait(0.2)
	end
	ui.Card.Visible = false
	ui.Dim.Visible = false
	ui.Flash.Visible = false
end

local function runQueue()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while true do
			while os.clock() < holdUntil do
				task.wait(0.1)
			end
			local entry, dropped = Presentation.pop(queue)
			if not entry then
				break
			end
			local ok, err = pcall(play, entry, dropped)
			if not ok then
				warn(`[RevealController] {err}`)
				showing = false
				ui.Card.Visible = false
				ui.Dim.Visible = false
			end
		end
		running = false
	end)
end

local function onResults(results: { any }, hunt: boolean)
	if type(results) ~= "table" then
		return
	end
	local mode = tostring(Settings.Get("Reveals"))
	local low = Settings.LowEffects()
	local smallShown = 0
	for _, result in results do
		if type(result) ~= "table" or type(result.Id) ~= "string" then
			continue
		end
		local index = tierIndex(result.Id)
		local isNew = result.First == true or result.NewVariant == true
		local category = Presentation.category(index, MEDIUM_INDEX, LARGE_INDEX, isNew)
		if hunt then
			-- The hunt papers already showed every find: only new ones get their reveal, one by one.
			if not isNew then
				continue
			end
			if category == "Small" then
				category = "Medium"
			end
		end
		category = Presentation.applyMode(category, mode)
		if hunt and category == "Small" then
			continue
		end
		if category == "Small" then
			-- One projection per batch is enough (bind batches can hold dozens of finds). While a
			-- capture plays, its own animation and summary are the presentation.
			if smallShown == 0 and os.clock() >= holdUntil then
				RelicProjection.Spawn(result.Id, result.Mutation, "Small", Config.Reveal.SmallSeconds, low)
				Sounds.Play("RevealSmall")
			end
			smallShown += 1
		else
			Presentation.push(queue, {
				Category = category,
				Score = Presentation.score(index, result.Mutation ~= nil),
				Seq = 0,
				Result = result,
			})
		end
	end
	runQueue()
end

-- Holds overlay reveals (they stay queued) for up to `seconds`, e.g. while a capture animation
-- and its summary card are on screen. Release lets the queue continue right away.
function RevealController.Hold(seconds: number)
	holdUntil = math.max(holdUntil, os.clock() + seconds)
end

function RevealController.Release()
	holdUntil = 0
end

-- Ends the reveal on screen right away (Skip button, any click or tap, Enter, gamepad B).
function RevealController.Skip()
	if showing then
		skipRequested = true
	end
end

function RevealController.IsShowingLarge(): boolean
	return showingLarge
end

function RevealController.Start(screen: ScreenGui)
	ui = build(screen)
	RollReel.OnResults(onResults)

	RunService.RenderStepped:Connect(function(dt)
		if not ui.Card.Visible then
			return
		end
		if model then
			modelBase = CFrame.Angles(0, dt * 1.6, 0) * modelBase
			model.CFrame = modelBase
		end
		if ui.Rays.Visible then
			ui.Rays.Rotation = (ui.Rays.Rotation + dt * 25) % 360
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local enter = input.KeyCode == Enum.KeyCode.Return and not gameProcessed
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if enter or click or input.KeyCode == Enum.KeyCode.ButtonB then
			RevealController.Skip()
		end
	end)
end

return RevealController
