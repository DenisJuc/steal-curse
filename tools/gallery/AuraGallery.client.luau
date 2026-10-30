-- Studio-only aura gallery (gallery.project.json, never shipped). Lays every extracted aura
-- candidate onto a real relic in a numbered grid so they can be compared in one walk-through.
-- Each slot shows the aura at relic scale; the back row repeats each one at Huge-size boost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicAura = require(script.Parent:WaitForChild("RelicAura"))
local RelicConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicConfig"))
local RelicModels = require(ReplicatedStorage.Shared:WaitForChild("RelicModels"))

local PER_ROW = 8
local SPACING = 16
local HUGE_BOOST = 1.5

local relicIds = {}
for _, relic in RelicConfig.Relics do
	if RelicModels.has(relic.Id) then
		table.insert(relicIds, relic.Id)
	end
end
if #relicIds == 0 then
	table.insert(relicIds, RelicConfig.Relics[1].Id)
end

local function label(parent: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, -1.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = parent
end

local function slot(folder: Folder, template: Instance, at: Vector3, relicId: string, boost: number, text: string)
	local pedestal = Instance.new("Part")
	pedestal.Anchored = true
	pedestal.Size = Vector3.new(5, 1, 5)
	pedestal.Position = at + Vector3.new(0, 0.5, 0)
	pedestal.Color = Color3.fromRGB(45, 40, 55)
	pedestal.Material = Enum.Material.Slate
	pedestal.Parent = folder
	label(pedestal, text)
	local relic = RelicModels.build(relicId, CFrame.new(at + Vector3.new(0, 3.5, 0)), boost)
	if not relic then
		return
	end
	relic.Parent = folder
	RelicAura.attach(relic, template)
end

local folder = Instance.new("Folder")
folder.Name = "AuraGallery"
folder.Parent = workspace

local templates = ReplicatedStorage:WaitForChild("AuraCandidates"):GetChildren()
table.sort(templates, function(a, b)
	return a.Name < b.Name
end)
for index, template in templates do
	local i = index - 1
	local x = (i % PER_ROW) * SPACING
	local z = math.floor(i / PER_ROW) * SPACING * 2
	local relicId = relicIds[(i % #relicIds) + 1]
	local number = string.match(template.Name, "^Aura(%d+)") or tostring(i)
	slot(folder, template, Vector3.new(x, 0, z), relicId, 1, "#" .. number)
	slot(folder, template, Vector3.new(x, 0, z + SPACING), relicId, HUGE_BOOST, "#" .. number .. " Huge")
end
print(string.format("[AuraGallery] %d auras on %d relic models", #templates, #relicIds))
