-- Luck tag over every player's head: "x3.2 LUCK", read from the replicated "EffectiveLuck"
-- attribute (RollService sets it; the HUD luck chip shows the same number). Built on this client
-- for every character so everyone sees everyone's luck (a flex). MaxDistance keeps crowds clean.
-- When a player's luck goes up, a short "+x0.4" pops over the tag (0.6 s scale punch, no particles).
-- Sits just above the earned title (PlayerTitles) when the player has one.
-- The tag leads with the player's seal rank (Config.SealLadder by the "LastingLuck" attribute),
-- tinted per tier: "JADE SEAL · x31 LUCK". Your own tag adds a small "Next: Silver Seal at x40".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local SealLadder = require(ReplicatedStorage.Shared.SealLadder)

local LuckTag = {}

local NAME = "LuckTag"
local WIDTH, HEIGHT = 250, 34
-- Your own tag only: the next seal, in a small line right above the tag.
local NEXT_HEIGHT = 16
-- The gui is taller than the tag: the "+x" pop rises in the room above (a BillboardGui clips).
local GUI_HEIGHT = 84 + NEXT_HEIGHT
local BASE_LIFT = (GUI_HEIGHT - HEIGHT) / 2 / GUI_HEIGHT -- keeps the tag where a 34 px gui would be
local TITLE_HEIGHT = 22 -- PlayerTitles label height, so the tag can sit above it
local MAX_DISTANCE = 80
local COLOR = Color3.fromRGB(120, 255, 150) -- before the first seal tint
local POP_COLOR = Color3.fromRGB(255, 240, 120)
local POP_SECONDS = 0.6
local MIN_GAIN = 0.05 -- smaller rises (rounding, timers) don't pop

type Entry = {
	Gui: BillboardGui,
	Label: TextLabel,
	Pop: TextLabel,
	Next: TextLabel?,
	Shown: number?,
	PopToken: number,
}

local function lastingOf(player: Player): number
	local value = player:GetAttribute("LastingLuck")
	return if type(value) == "number" and value == value then value else 1
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Text tint: the tier colour, kept readable (dark tiers like Ink and Void are lifted).
local function tint(tier: SealLadder.Tier): Color3
	local color = rgb(tier.Color)
	local h, sat, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(sat, 0.75), math.max(v, 0.8))
end

local function luckOf(player: Player): number?
	local value = player:GetAttribute("EffectiveLuck")
	return if type(value) == "number" and value == value then value else nil
end

-- The pop's bottom edge sits above the tag (and the next-seal line) and rises from there.
local POP_START = UDim2.new(0.5, 0, 1, -HEIGHT - NEXT_HEIGHT)
local function popSize(scale: number): UDim2
	return UDim2.new(0.7 * scale, 0, 0, 30 * scale)
end

local function make(head: BasePart, own: boolean): Entry
	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Size = UDim2.fromOffset(WIDTH, GUI_HEIGHT)
	gui.SizeOffset = Vector2.new(0, BASE_LIFT)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Name = "Luck"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 1, -HEIGHT / 2)
	label.Size = UDim2.new(1, 0, 0, HEIGHT)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = COLOR
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(10, 20, 12)
	label.Parent = gui
	local pop = Instance.new("TextLabel")
	pop.Name = "Gain"
	pop.AnchorPoint = Vector2.new(0.5, 1)
	pop.Position = POP_START
	pop.Size = popSize(0.8)
	pop.BackgroundTransparency = 1
	pop.Font = Enum.Font.FredokaOne
	pop.TextScaled = true
	pop.TextColor3 = POP_COLOR
	pop.TextStrokeTransparency = 0
	pop.TextTransparency = 1
	pop.TextStrokeColor3 = Color3.fromRGB(40, 30, 0)
	pop.Parent = gui
	local nextLabel = nil
	if own then
		nextLabel = Instance.new("TextLabel")
		nextLabel.Name = "NextSeal"
		nextLabel.AnchorPoint = Vector2.new(0.5, 1)
		nextLabel.Position = UDim2.new(0.5, 0, 1, -HEIGHT)
		nextLabel.Size = UDim2.new(0.9, 0, 0, NEXT_HEIGHT)
		nextLabel.BackgroundTransparency = 1
		nextLabel.Font = Enum.Font.FredokaOne
		nextLabel.TextScaled = true
		nextLabel.TextColor3 = Color3.fromRGB(225, 225, 235)
		nextLabel.TextStrokeTransparency = 0.2
		nextLabel.Parent = gui
	end
	gui.Adornee = head
	gui.Parent = head
	return { Gui = gui, Label = label, Pop = pop, Next = nextLabel, Shown = nil, PopToken = 0 }
end

local function popGain(entry: Entry, gain: number)
	entry.PopToken += 1
	local token = entry.PopToken
	local pop = entry.Pop
	pop.Text = `+x{Format.number(gain)}`
	pop.Position = POP_START
	pop.Size = popSize(0.4)
	pop.TextTransparency = 0
	pop.TextStrokeTransparency = 0
	-- Scale punch: overshoot fast, settle, then rise and fade; 0.6 s in all.
	TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = popSize(1.15),
	}):Play()
	local label = entry.Label
	label.Size = UDim2.new(1.15, 0, 0, HEIGHT * 1.15)
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, HEIGHT),
	}):Play()
	task.delay(0.12, function()
		if entry.PopToken ~= token then
			return
		end
		TweenService:Create(pop, TweenInfo.new(0.1), { Size = popSize(1) }):Play()
	end)
	task.delay(0.3, function()
		if entry.PopToken ~= token then
			return
		end
		local fade = TweenInfo.new(POP_SECONDS - 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(pop, fade, {
			Position = UDim2.new(0.5, 0, 0, 30),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)
end

function LuckTag.Start()
	local shown: { [Player]: Entry } = {}
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
	end)
	local check = 0
	RunService.Heartbeat:Connect(function(dt)
		check += dt
		if check < 0.25 then
			return
		end
		check = 0
		for _, player in Players:GetPlayers() do
			local luck = luckOf(player)
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local entry = shown[player]
			if not luck or not (head and head:IsA("BasePart")) then
				if entry then
					entry.Gui:Destroy()
					shown[player] = nil
				end
				continue
			end
			if not entry or entry.Gui.Parent ~= head then
				local last = entry and entry.Shown
				if entry then
					entry.Gui:Destroy()
				end
				entry = make(head, player == Players.LocalPlayer)
				entry.Shown = last -- a respawn is not a luck gain
				shown[player] = entry
			end
			assert(entry, "luck tag entry")
			-- Above the earned title when there is one (both centre 2.6 studs over the head).
			local title = player:GetAttribute("Title")
			local lift = BASE_LIFT
				+ (if type(title) == "string" and title ~= "" then (HEIGHT + TITLE_HEIGHT) / 2 / GUI_HEIGHT else 0)
			if entry.Gui.SizeOffset.Y ~= lift then
				entry.Gui.SizeOffset = Vector2.new(0, lift)
			end
			local lasting = lastingOf(player)
			local _, tier = SealLadder.tierFor(Config.SealLadder, lasting)
			local text = `{string.upper(tier.Name)} · x{Format.number(luck)} LUCK`
			if entry.Label.Text ~= text then
				entry.Label.Text = text
				entry.Label.TextColor3 = tint(tier)
			end
			if entry.Next then
				local nextTier = SealLadder.nextTier(Config.SealLadder, lasting)
				local nextText = if nextTier then `Next: {nextTier.Name} at x{Format.number(nextTier.Luck)}` else "Highest seal"
				if entry.Next.Text ~= nextText then
					entry.Next.Text = nextText
				end
			end
			local before = entry.Shown
			if before and luck - before >= MIN_GAIN then
				popGain(entry, luck - before)
			end
			entry.Shown = luck
		end
	end)
end

return LuckTag
