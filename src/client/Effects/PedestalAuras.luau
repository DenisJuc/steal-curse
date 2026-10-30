-- Premade auras (RelicAura) on relics shown on pedestals. The server tags each RelicDisplay part
-- with RelicId and Size (PedestalVisuals); this picks the tier's aura, boosts it for Huge /
-- Titanic and layers the Titanic extra. Only the nearest MAX_ACTIVE displays within RANGE studs
-- of the camera carry an aura, so a crowded server stays cheap. Visual only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Settings = require(script.Parent.Parent.Settings)
local RelicAura = require(script.Parent.RelicAura)

local PedestalAuras = {}

-- Template names in ReplicatedStorage.VFX.Auras (assets/VFX/Auras). Common / Uncommon: none.
PedestalAuras.ByTier = {
	Rare = "Aura_Rare",
	Epic = "Aura_Epic",
	Legendary = "Aura_Legendary",
	Mythic = "Aura_Mythic",
	Celestial = "Aura_Celestial",
	Cosmic = "Aura_Cosmic",
} :: { [string]: string }
PedestalAuras.TitanicExtra = "Aura_TitanicExtra"
-- Common / Uncommon Titanic and Huge relics still get a glow: the Rare aura.
local SIZED_FALLBACK = "Rare"
local BOOST = { Huge = 1.25, Titanic = 1.5 }

local RANGE = 140
local MAX_ACTIVE = 12
local REFRESH_SECONDS = 0.5

type Entry = { Part: BasePart, Handles: { RelicAura.Handle } }

local displays: { [BasePart]: true } = {}
local active: { [BasePart]: Entry } = {}

local function templatesFor(part: BasePart): { { Template: Instance, Boost: number } }
	local relic = RelicConfig.ById[part:GetAttribute("RelicId") :: any]
	if not relic then
		return {}
	end
	local size = part:GetAttribute("Size")
	local tier = relic.Tier
	if not PedestalAuras.ByTier[tier] and (size == "Huge" or size == "Titanic") then
		tier = SIZED_FALLBACK
	end
	local list = {}
	local name = PedestalAuras.ByTier[tier]
	local main = name and RelicAura.template(name)
	-- The relic part is already scaled for its size, so the boost only adds extra presence.
	local boost = BOOST[size :: any] or 1
	if main then
		table.insert(list, { Template = main, Boost = boost })
	end
	if size == "Titanic" then
		local extra = RelicAura.template(PedestalAuras.TitanicExtra)
		if extra then
			table.insert(list, { Template = extra, Boost = 1 })
		end
	end
	return list
end

local function activate(part: BasePart)
	local handles = {}
	local low = Settings.LowEffects()
	for _, item in templatesFor(part) do
		table.insert(handles, RelicAura.attach(part, item.Template, { Boost = item.Boost, Low = low }))
	end
	active[part] = { Part = part, Handles = handles }
end

local function deactivate(part: BasePart)
	local entry = active[part]
	if entry then
		for _, handle in entry.Handles do
			handle:Destroy()
		end
		active[part] = nil
	end
end

local function track(item: Instance)
	if item:IsA("BasePart") and item.Name == "RelicDisplay" then
		displays[item] = true
		item.AncestryChanged:Connect(function()
			if not item:IsDescendantOf(workspace) then
				displays[item] = nil
				deactivate(item)
			end
		end)
	end
end

local function hasAura(part: BasePart): boolean
	local relic = RelicConfig.ById[part:GetAttribute("RelicId") :: any]
	if not relic then
		return false
	end
	local size = part:GetAttribute("Size")
	return PedestalAuras.ByTier[relic.Tier] ~= nil or size == "Huge" or size == "Titanic"
end

local function refresh()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local from = camera.CFrame.Position
	local nearby = {}
	for part in displays do
		local distance = (part.Position - from).Magnitude
		if distance <= RANGE and hasAura(part) then
			table.insert(nearby, { Part = part, Distance = distance })
		end
	end
	table.sort(nearby, function(a, b)
		return a.Distance < b.Distance
	end)
	local want: { [BasePart]: true } = {}
	for i = 1, math.min(#nearby, MAX_ACTIVE) do
		want[nearby[i].Part] = true
	end
	for part in active do
		if not want[part] then
			deactivate(part)
		end
	end
	for part in want do
		if not active[part] then
			activate(part)
		end
	end
end

function PedestalAuras.Start()
	for _, item in workspace:GetDescendants() do
		track(item)
	end
	workspace.DescendantAdded:Connect(track)
	Settings.Watch("LowEffects", function()
		for part in active do
			deactivate(part)
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return PedestalAuras
