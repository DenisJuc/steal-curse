-- Places map props (MapPropConfig), the map's version of RelicModels. Imported models live in
-- ServerStorage.MapProps as "<PropId>" (synced from assets/MapProps/<PropId>.rbxm); a prop without
-- one is built from primitives (PropFallbacks) and tagged with the ModelNeeded attribute.
-- Imports are scaled so their height matches the config, then stood on the ground point. Optional
-- attributes on an imported model: DisplayScale (number) and DisplayRotation (Vector3 degrees).
-- Collision: the visible parts never collide; "Box" props get one invisible box collider.
-- Lights: a PointLight tagged "MapLight" (the client switches far ones off).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local BuildUtil = require(script.Parent.BuildUtil)
local PropFallbacks = require(script.Parent.PropFallbacks)

local MapProps = {}

local function folder(): Instance?
	return ServerStorage:FindFirstChild("MapProps")
end

function MapProps.asset(propId: string): Instance?
	local props = folder()
	return props and props:FindFirstChild(propId)
end

function MapProps.has(propId: string): boolean
	local asset = MapProps.asset(propId)
	return asset ~= nil and (asset:IsA("BasePart") or asset:FindFirstChildWhichIsA("BasePart", true) ~= nil)
end

-- Folder entries whose name is not a prop id (typos in the .rbxm file name).
function MapProps.unknownNames(): { string }
	local unknown = {}
	local props = folder()
	for _, child in if props then props:GetChildren() else {} do
		if not MapPropConfig.Props[child.Name] then
			table.insert(unknown, child.Name)
		end
	end
	return unknown
end

local function fromAsset(model: Model, asset: Instance, base: CFrame, size: Vector3, config: MapPropConfig.Prop)
	local fitLength = config.Fit == "Length"
	local copy = asset:Clone()
	for _, item in copy:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
	local holder: Model
	if copy:IsA("Model") then
		holder = copy
	else
		holder = Instance.new("Model")
		copy.Parent = holder
	end
	for _, item in { holder, table.unpack(holder:GetDescendants()) } do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	-- Measure along world axes, whatever pivot the import came with.
	holder.PrimaryPart = nil
	holder.WorldPivot = CFrame.new(holder:GetPivot().Position)
	local extra = asset:GetAttribute("DisplayScale")
	local multiplier = if type(extra) == "number" and extra > 0 then extra else 1
	local _, bounds = holder:GetBoundingBox()
	local measured, target = bounds.Y, size.Y
	if fitLength then
		measured, target = math.max(bounds.X, bounds.Z), math.max(size.X, size.Z)
	end
	if measured > 1e-3 then
		holder:ScaleTo(holder:GetScale() * target / measured * multiplier)
	end
	local boxCFrame, scaled = holder:GetBoundingBox()
	holder.WorldPivot = CFrame.new(boxCFrame.Position)
	local rotation = asset:GetAttribute("DisplayRotation")
	local turn = if typeof(rotation) == "Vector3"
		then CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		else CFrame.identity
	if fitLength and scaled.X > scaled.Z then
		turn = CFrame.Angles(0, math.pi / 2, 0) * turn
	end
	if config.Tilt then
		turn = CFrame.Angles(math.rad(config.Tilt), 0, 0) * turn
	end
	-- Turn about the center, then stand the (possibly tilted) model's lowest point on `base`.
	holder:PivotTo(base * CFrame.new(0, scaled.Y / 2, 0) * turn)
	holder.WorldPivot = CFrame.new(holder:GetPivot().Position)
	local placed, extent = holder:GetBoundingBox()
	local bottom = placed.Position.Y - extent.Y / 2
	holder:PivotTo(holder:GetPivot() + Vector3.new(0, base.Position.Y - bottom, 0))
	for _, child in holder:GetChildren() do
		child.Parent = model
	end
	holder:Destroy()
end

local function addLight(model: Model, base: CFrame, size: Vector3, light: MapPropConfig.Light)
	local color = Color3.fromRGB(light.Color[1], light.Color[2], light.Color[3])
	local anchor = BuildUtil.decor(BuildUtil.part(model, {
		Name = "LightAnchor",
		Size = Vector3.one * 0.2,
		CFrame = base * CFrame.new(0, size.Y * light.Height, 0),
		Transparency = 1,
	}))
	local point = BuildUtil.light(anchor, color, light.Range, light.Brightness)
	CollectionService:AddTag(point, "MapLight")
end

-- A new prop model standing on `base` (its bottom center), `scale` times the configured size.
-- Parented to `parent`. Unknown ids return nil.
function MapProps.build(parent: Instance, propId: string, base: CFrame, scale: number?, rng: Random?): Model?
	local config = MapPropConfig.Props[propId]
	if not config then
		return nil
	end
	local s = scale or 1
	local size = Vector3.new(config.Size[1], config.Size[2], config.Size[3]) * s
	if config.Sink then
		base *= CFrame.new(0, -config.Sink * s, 0)
	end
	local model = Instance.new("Model")
	model.Name = propId
	model:SetAttribute("Prop", propId)

	local asset = MapProps.asset(propId)
	if asset and MapProps.has(propId) then
		fromAsset(model, asset, base, size, config)
	else
		PropFallbacks.build(config.Fallback, model, base, size, rng or Random.new())
		model:SetAttribute("ModelNeeded", propId)
		if config.Collide == "None" then
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					BuildUtil.decor(item)
				end
			end
		end
	end

	if config.Collide == "Box" and model:GetAttribute("ModelNeeded") == nil then
		local collider = config.Collider or config.Size
		local box = Vector3.new(collider[1], collider[2], collider[3]) * s
		local part = BuildUtil.part(model, {
			Name = "Collider",
			Size = box,
			CFrame = base * CFrame.new(0, box.Y / 2, 0),
			Transparency = 1,
			CastShadow = false,
		})
		part.CanTouch = false
	end
	if config.Light then
		addLight(model, base, size, config.Light)
	end
	model.Parent = parent
	return model
end

return MapProps
