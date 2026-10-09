-- Server-side look of a plot's six pedestals, so visitors see the same shrine as the owner.
-- Owned: solid stand, glow brightens with level, placeholder relic shape + info billboard.
-- Next buyable slot: ghost stand with its price. Later slots: hidden ghost.
-- Placeholder shapes by object type (RelicShapes) until Slice 8 imports real models.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicShapes = require(ReplicatedStorage.Shared.RelicShapes)
local BuildUtil = require(script.Parent.BuildUtil)

local PedestalVisuals = {}

export type SlotState = {
	Slot: number,
	Owned: boolean,
	Level: number?,
	Locked: boolean?,
	Id: string?,
	Mutation: string?,
	IncomePerMin: number?,
	Price: number?,
	IsNext: boolean?,
}

local NEON_FROM_TIER = RarityConfig.IndexById.Epic

local function buildDisplay(pedestal: Model, top: BasePart, relicId: string, mutationId: string?)
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return
	end
	local tier = RarityConfig.Get(relic.Tier)
	local color = if tier then Color3.fromHex(tier.Color) else Color3.new(1, 1, 1)
	local props = RelicShapes.props(relic.ObjectType, CFrame.new(top.Position + Vector3.new(0, 2.4, 0)))
	props.Name = "RelicDisplay"
	props.Color = color
	props.Material = if (RarityConfig.IndexById[relic.Tier] or 1) >= NEON_FROM_TIER
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	local part = BuildUtil.decor(BuildUtil.part(pedestal, props))

	local mutation = mutationId and MutationConfig.ById[mutationId]
	if mutation then
		local mutationColor = Color3.fromHex(mutation.Color)
		BuildUtil.sparkles(part, mutationColor, 10)
		BuildUtil.light(part, mutationColor, 10, 2)
	end
end

local function infoText(state: SlotState): string
	if not state.Owned then
		return if state.IsNext and state.Price then `Slot {state.Slot}\n{Format.number(state.Price)} CE` else ""
	end
	local suffix = `Lv {state.Level}` .. (if state.Locked then "  |  LOCKED" else "")
	if not state.Id then
		return `Empty\n{suffix}`
	end
	local relic = RelicConfig.ById[state.Id]
	local name = if relic then relic.Name else state.Id
	if state.Mutation then
		name = `{state.Mutation} {name}`
	end
	return `{name}\n+{Format.number(state.IncomePerMin or 0)} CE/min  |  {suffix}`
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
		base.Transparency = standTransparency
		top.Transparency = standTransparency
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

		local label = top:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			label.Text = infoText(state)
		end
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
			local label = top and top:FindFirstChild("Label", true)
			if label and label:IsA("TextLabel") then
				label.Text = ""
			end
		end
	end
end

return PedestalVisuals
