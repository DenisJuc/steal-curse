-- One place that builds a relic's 3D look for pedestals, reveals, projections, captures and the
-- carried relic. Imported models live in ReplicatedStorage.RelicModels as "<RelicId>" (synced
-- from assets/RelicModels/<RelicId>.rbxm). A relic without one falls back to its placeholder
-- shape (RelicShapes) with the ModelNeeded attribute set.
-- Optional attributes on an imported model: DisplayScale (number, default 1) and
-- DisplayRotation (Vector3 in degrees) to fix its size and facing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelCheck = require(script.Parent.ModelCheck)
local RarityConfig = require(script.Parent.RarityConfig)
local RelicConfig = require(script.Parent.RelicConfig)
local RelicShapes = require(script.Parent.RelicShapes)

local RelicModels = {}

export type Options = {
	-- Glowing tier-colored silhouette (projections, captures): textures are stripped.
	Spectral: boolean?,
}

local NEON_FROM_TIER = RarityConfig.IndexById.Epic

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild("RelicModels")
end

local function firstPart(asset: Instance): BasePart?
	if asset:IsA("BasePart") then
		return asset
	end
	for _, descendant in asset:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

function RelicModels.asset(relicId: string): Instance?
	local models = folder()
	return models and models:FindFirstChild(relicId)
end

function RelicModels.has(relicId: string): boolean
	local asset = RelicModels.asset(relicId)
	return asset ~= nil and firstPart(asset) ~= nil
end

function RelicModels.facts(asset: Instance): ModelCheck.Facts
	local part = firstPart(asset)
	local parts, scripts, textured = 0, 0, false
	for _, item in { asset, table.unpack(asset:GetDescendants()) } do
		if item:IsA("BasePart") then
			parts += 1
		elseif item:IsA("LuaSourceContainer") then
			scripts += 1
		elseif item:IsA("SurfaceAppearance") then
			textured = true
		end
		if item:IsA("MeshPart") and item.TextureID ~= "" then
			textured = true
		end
	end
	local size = if part then part.Size else Vector3.zero
	return {
		ClassName = if part then part.ClassName else "",
		Parts = parts,
		HasTexture = textured,
		Scripts = scripts,
		SizeX = size.X,
		SizeY = size.Y,
		SizeZ = size.Z,
	}
end

-- Folder entries whose name is not a relic id (typos in the .rbxm file name).
function RelicModels.unknownNames(): { string }
	local unknown = {}
	local models = folder()
	for _, child in if models then models:GetChildren() else {} do
		if not RelicConfig.ById[child.Name] then
			table.insert(unknown, child.Name)
		end
	end
	return unknown
end

local function tierColor(relic: RelicConfig.Relic): Color3
	local tier = RarityConfig.Get(relic.Tier)
	return if tier then Color3.fromHex(tier.Color) else Color3.new(1, 1, 1)
end

local function setDecor(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
end

local function fromAsset(relic: RelicConfig.Relic, asset: Instance, at: CFrame, scale: number, spectral: boolean): BasePart?
	local template = firstPart(asset)
	if not template then
		return nil
	end
	local part = template:Clone()
	for _, child in part:GetDescendants() do
		if child:IsA("LuaSourceContainer") or child:IsA("BasePart") or child:IsA("JointInstance") then
			child:Destroy()
		end
	end
	local target = RelicShapes.props(relic.ObjectType, CFrame.new(), scale).Size :: Vector3
	local extra = asset:GetAttribute("DisplayScale")
	local factor = ModelCheck.fitFactor(math.max(part.Size.X, part.Size.Y, part.Size.Z), math.max(target.X, target.Y, target.Z))
	part.Size *= factor * (if type(extra) == "number" and extra > 0 then extra else 1)
	local rotation = asset:GetAttribute("DisplayRotation")
	local turn = if typeof(rotation) == "Vector3"
		then CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		else CFrame.identity
	part.CFrame = at * turn
	if spectral then
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		if part:IsA("MeshPart") then
			part.TextureID = ""
		end
		part.Material = Enum.Material.Neon
		part.Color = tierColor(relic)
	end
	return part
end

local function placeholder(relic: RelicConfig.Relic, at: CFrame, scale: number, spectral: boolean): BasePart
	local props = RelicShapes.props(relic.ObjectType, at, scale)
	local part = Instance.new("Part")
	part.Shape = props.Shape or Enum.PartType.Block
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = tierColor(relic)
	part.Material = if spectral or (RarityConfig.IndexById[relic.Tier] or 1) >= NEON_FROM_TIER
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	part:SetAttribute("ModelNeeded", relic.Id)
	return part
end

-- A new, unparented, anchored, non-colliding part showing the relic centred around `at`, sized
-- like its placeholder shape times `scale`. Returns nil for an unknown relic id.
function RelicModels.build(relicId: string, at: CFrame, scale: number?, options: Options?): BasePart?
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return nil
	end
	local s = scale or 1
	local spectral = options ~= nil and options.Spectral == true
	local asset = RelicModels.asset(relicId)
	local part = (asset and fromAsset(relic, asset, at, s, spectral)) or placeholder(relic, at, s, spectral)
	part.Name = relicId
	setDecor(part)
	return part
end

return RelicModels
