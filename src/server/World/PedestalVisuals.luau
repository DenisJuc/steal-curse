-- Server-side look of a plot's six pedestals, so visitors see the same shrine as the owner.
-- Owned: solid stand, glow brightens with level, the relic's model (RelicModels) + info billboard.
-- Next buyable slot: ghost stand with its price. Later slots: hidden ghost.
-- Each pedestal model mirrors Owned / RelicName / IncomePerSec attributes for the owner's prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local BuildUtil = require(script.Parent.BuildUtil)

local PedestalVisuals = {}

local INFO_OFFSET = 6.5
local WHITE = Color3.fromRGB(245, 240, 255)
local GREY = Color3.fromRGB(182, 170, 158)
local GOLD = Color3.fromRGB(240, 194, 104)
local INK = Color3.fromRGB(17, 13, 24)

export type SlotState = {
	Slot: number,
	Owned: boolean,
	Level: number?,
	Locked: boolean?,
	Id: string?,
	Mutation: string?,
	IncomePerSec: number?,
	Price: number?,
	IsNext: boolean?,
}

local function buildDisplay(pedestal: Model, top: BasePart, relicId: string, mutationId: string?)
	local part = RelicModels.build(relicId, CFrame.new(top.Position + Vector3.new(0, 2.4, 0)))
	if not part then
		return
	end
	part.Name = "RelicDisplay"
	part.Parent = pedestal

	local mutation = mutationId and MutationConfig.ById[mutationId]
	if mutation then
		local mutationColor = Color3.fromHex(mutation.Color)
		BuildUtil.sparkles(part, mutationColor, 10)
		BuildUtil.light(part, mutationColor, 10, 2)
	end
end

local function round(instance: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = instance
end

local function textLabel(name: string, parent: Instance, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

-- The billboard over a pedestal (sizes are in studs): relic name in its tier color, then
-- coin + income per second and a level chip, then a small tag line (locked / how to unlock).
local function buildInfo(top: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromScale(8, 3)
	gui.StudsOffset = Vector3.new(0, INFO_OFFSET, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70

	textLabel("Name", gui, WHITE).Size = UDim2.fromScale(1, 0.4)

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromScale(0, 0.44)
	stats.Size = UDim2.fromScale(1, 0.34)
	stats.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = stats

	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.LayoutOrder = 1
	coin.Size = UDim2.fromScale(0.1, 0.85)
	coin.BackgroundColor3 = GOLD
	coin.BorderSizePixel = 0
	coin.Parent = stats
	round(coin, UDim.new(1, 0))
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = coin
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(110, 70, 20)
	rim.Thickness = 2
	rim.Parent = coin
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Size = UDim2.fromScale(0.3, 0.3)
	hole.BackgroundColor3 = INK
	hole.BorderSizePixel = 0
	hole.Parent = coin

	local amount = textLabel("Amount", stats, GOLD)
	amount.LayoutOrder = 2
	amount.Size = UDim2.fromScale(0.42, 1)
	amount.TextXAlignment = Enum.TextXAlignment.Left

	local level = Instance.new("Frame")
	level.Name = "Level"
	level.LayoutOrder = 3
	level.Size = UDim2.fromScale(0.24, 0.9)
	level.BackgroundColor3 = INK
	level.BackgroundTransparency = 0.15
	level.Parent = stats
	round(level, UDim.new(0.35, 0))
	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 1.5
	edge.Transparency = 0.3
	edge.Parent = level
	local levelText = textLabel("Text", level, WHITE)
	levelText.AnchorPoint = Vector2.new(0.5, 0.5)
	levelText.Position = UDim2.fromScale(0.5, 0.5)
	levelText.Size = UDim2.fromScale(0.8, 0.8)

	local tag = textLabel("Tag", gui, GOLD)
	tag.Position = UDim2.fromScale(0, 0.8)
	tag.Size = UDim2.fromScale(1, 0.2)

	gui.Parent = top
	return gui
end

local function relicLook(state: SlotState): (string, Color3)
	local relic = state.Id and RelicConfig.ById[state.Id]
	local name = if relic then relic.Name else (state.Id or "")
	local mutation = state.Mutation and MutationConfig.ById[state.Mutation]
	if mutation then
		return `{state.Mutation} {name}`, Color3.fromHex(mutation.Color)
	end
	local tier = relic and RarityConfig.Get(relic.Tier)
	return name, if tier then Color3.fromHex(tier.Color) else WHITE
end

local function updateInfo(top: BasePart, state: SlotState)
	local gui = (top:FindFirstChild("Info") or buildInfo(top)) :: BillboardGui
	local name = gui:FindFirstChild("Name") :: TextLabel
	local stats = gui:FindFirstChild("Stats") :: Frame
	local amount = stats:FindFirstChild("Amount") :: TextLabel
	local level = stats:FindFirstChild("Level") :: Frame
	local tag = gui:FindFirstChild("Tag") :: TextLabel

	if not state.Owned then
		gui.Enabled = state.IsNext == true and state.Price ~= nil
		name.Text = `Pedestal {state.Slot}`
		name.TextColor3 = WHITE
		amount.Text = Format.number(state.Price or 0)
		level.Visible = false
		tag.Text = "Unlock it in the Shrine menu"
		return
	end
	gui.Enabled = true
	if state.Id then
		name.Text, name.TextColor3 = relicLook(state)
	else
		name.Text, name.TextColor3 = "Empty pedestal", GREY
	end
	amount.Text = Format.rate(state.IncomePerSec or 0)
	level.Visible = true
	local levelText = level:FindFirstChild("Text") :: TextLabel
	levelText.Text = `Lv {state.Level or 1}`
	tag.Text = if state.Locked then "LOCKED" else ""
end

function PedestalVisuals.Apply(plot: Model?, slots: { SlotState })
	local folder = plot and plot:FindFirstChild("Pedestals")
	if not folder then
		return
	end
	for _, state in slots do
		local pedestal = folder:FindFirstChild("Pedestal" .. state.Slot)
		if not pedestal or not pedestal:IsA("Model") then
			continue
		end
		local base = pedestal:FindFirstChild("Base") :: BasePart
		local top = pedestal:FindFirstChild("Top") :: BasePart
		local glow = pedestal:FindFirstChild("Glow") :: BasePart
		local visible = state.Owned or state.IsNext == true
		local ghost = not state.Owned
		local standTransparency = if not visible then 1 elseif ghost then 0.75 else 0
		-- An imported RelicPedestal model ("Look") replaces the primitive base and top, which stay
		-- as invisible colliders and display anchors.
		local look = pedestal:FindFirstChild("Look")
		if look then
			for _, part in look:GetDescendants() do
				if part:IsA("BasePart") and part.Name ~= "Collider" and part.Name ~= "LightAnchor" then
					part.Transparency = standTransparency
				end
			end
		end
		base.Transparency = if look then 1 else standTransparency
		top.Transparency = if look then 1 else standTransparency
		base.CanCollide = state.Owned
		top.CanCollide = state.Owned
		local level = state.Level or 1
		glow.Transparency = if state.Owned
			then 0.8 - 0.6 * (level - 1) / (Config.Economy.PedestalMaxLevel - 1)
			else 1

		local key = if state.Owned and state.Id then `{state.Id}|{state.Mutation or ""}` else ""
		if pedestal:GetAttribute("ShownKey") ~= key then
			pedestal:SetAttribute("ShownKey", key)
			local old = pedestal:FindFirstChild("RelicDisplay")
			if old then
				old:Destroy()
			end
			if state.Owned and state.Id then
				buildDisplay(pedestal, top, state.Id, state.Mutation)
			end
		end

		updateInfo(top, state)
		-- Read by the owner's hold-E prompt (PedestalPrompts).
		pedestal:SetAttribute("Owned", state.Owned)
		pedestal:SetAttribute("RelicName", if state.Owned and state.Id then (relicLook(state)) else "")
		pedestal:SetAttribute("IncomePerSec", if state.Owned then state.IncomePerSec or 0 else 0)
	end
end

-- Unclaimed look: free starting slots empty, first buyable slot as a ghost.
function PedestalVisuals.Reset(plot: Model?)
	local slots = {}
	for slot = 1, Config.Plots.MaxPedestals do
		local owned = slot <= Config.Plots.StartingPedestals
		table.insert(slots, {
			Slot = slot,
			Owned = owned,
			Level = 1,
			IsNext = slot == Config.Plots.StartingPedestals + 1,
			Price = Config.Economy.SlotPrices[slot],
		})
	end
	PedestalVisuals.Apply(plot, slots)
	local folder = plot and plot:FindFirstChild("Pedestals")
	if folder then
		for _, pedestal in folder:GetChildren() do
			local top = pedestal:FindFirstChild("Top")
			local info = top and top:FindFirstChild("Info")
			if info and info:IsA("BillboardGui") then
				info.Enabled = false
			end
		end
	end
end

return PedestalVisuals
