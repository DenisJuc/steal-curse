-- Spirit type look on signal orbs (Config.Spirits): tints the orb's light and sparkles to its
-- type and floats a small tag with the type name and the exact total rolls its capture gives now
-- (server preview: relic + bonus after streak, events, skills and caps). Kept outside
-- SpiritSight so it only decorates the orbs SpiritSight already builds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SpiritTypes = require(ReplicatedStorage.Shared.SpiritTypes)
local SpiritSight = require(script.Parent.Parent.Effects.SpiritSight)

local SpiritTags = {}

-- Tag fades out past this many studs (the strongest type is seen from farther).
local TAG_RANGE = { Wisp = 70, Restless = 100, Vengeful = 170 }

type Tag = { Orb: BasePart, Type: string, Gui: BillboardGui, Highlight: Highlight, Rolls: TextLabel }

local tags: { [number]: Tag } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function label(parent: Instance, text: string, color: Color3, y: number, height: number, _bold: boolean)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, height, 0)
	l.Position = UDim2.new(0, 0, y, 0)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.35
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = parent
	return l
end

-- Tag headline: the previewed total, LIGHTNING LUCK on a struck spirit, else the type's default.
local function rollsText(id: number, typeId: string, rolls: { [number]: number }, struck: { [number]: number }): string
	local total = rolls[id]
	if total then
		return `+{total} ROLLS`
	end
	local untilTime = struck[id]
	if untilTime and workspace:GetServerTimeNow() <= untilTime then
		return "LIGHTNING LUCK"
	end
	return `+{1 + SpiritTypes.get(typeId, Config.Spirits :: any).Bonus} ROLLS`
end

local function decorate(orb: BasePart, typeId: string, text: string): Tag
	local spirit = SpiritTypes.get(typeId, Config.Spirits :: any)
	local color = rgb(spirit.Color)
	orb.Color = color
	for _, child in orb:GetDescendants() do
		if child:IsA("PointLight") then
			child.Color = color
			child.Brightness = 1.2 + spirit.Scale
			child.Range = 10 * spirit.Scale
		elseif child:IsA("ParticleEmitter") then
			child.Color = ColorSequence.new(color)
			child.Rate = 10 * spirit.Scale
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpiritTag"
	gui.Size = UDim2.new(0, 150 * spirit.Scale, 0, 46 * spirit.Scale)
	gui.StudsOffset = Vector3.new(0, 2.6 + spirit.Scale, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = TAG_RANGE[typeId] or 100
	gui.Enabled = false
	local rollsLabel = label(gui, text, color, 0, 0.6, true)
	label(gui, string.upper(spirit.Name), Color3.fromRGB(230, 225, 240), 0.6, 0.4, false)
	gui.Parent = orb
	-- Tints the whole orb (body and talismans) so the type reads without the tag.
	local model = orb.Parent
	local highlight = Instance.new("Highlight")
	highlight.Name = "SpiritTint"
	highlight.Adornee = if model and model:IsA("Model") and string.sub(model.Name, 1, 6) == "Signal"
		then model
		else orb
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = orb
	return { Orb = orb, Type = typeId, Gui = gui, Highlight = highlight, Rolls = rollsLabel }
end

-- `types`: signal id -> spirit type id (nil entries: no type, e.g. spirit types off); `rolls`:
-- signal id -> previewed total rolls; `struck`: signal id -> lightning struck-until time.
function SpiritTags.Sync(types: { [number]: string }, rolls: { [number]: number }, struck: { [number]: number })
	for id, tag in tags do
		if types[id] ~= tag.Type or not tag.Orb.Parent then
			tag.Gui:Destroy()
			tag.Highlight:Destroy()
			tags[id] = nil
		end
	end
	if not Config.Spirits.Enabled then
		return
	end
	for id, typeId in types do
		if not tags[id] then
			local orb = SpiritSight.GetOrb(id)
			if orb then
				tags[id] = decorate(orb, typeId, rollsText(id, typeId, rolls, struck))
			end
		end
	end
	for id, tag in tags do
		local text = rollsText(id, tag.Type, rolls, struck)
		if tag.Rolls.Text ~= text then
			tag.Rolls.Text = text
		end
	end
end

-- Tags show only while Spirit Sight is on.
function SpiritTags.Update(types: { [number]: string }, rolls: { [number]: number }, struck: { [number]: number })
	local on = SpiritSight.IsEnabled()
	for id, tag in tags do
		if not tag.Orb.Parent then
			tags[id] = nil
		else
			tag.Gui.Enabled = on
			tag.Highlight.Enabled = on
		end
	end
	-- Orbs rebuilt by SpiritSight (e.g. low-effects toggle) get their tag back.
	for id in types do
		if not tags[id] then
			SpiritTags.Sync(types, rolls, struck)
			break
		end
	end
end

return SpiritTags
