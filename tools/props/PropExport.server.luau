-- Studio-only helper (not part of the game): walks every model in ServerStorage.PropExport into
-- JSON and POSTs it to a local sink (tools/props/export_props.py turns it into assets/MapProps
-- .rbxmx). Run it as a Script in a Play session with HttpService.HttpEnabled on. MeshParts stay
-- MeshParts (mesh id + InitialSize; no baked collision data, MapProps never collides with visible
-- parts) so a SurfaceAppearance keeps working; welds are dropped (MapProps anchors every part),
-- lights are dropped (MapPropConfig adds its own, LOD-tagged) and scripts are never exported.

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local SINK = "http://127.0.0.1:34997/"

local PART = { "Size", "CFrame", "Color", "Material", "Transparency", "Reflectance", "CastShadow" }
local CLASS_PROPS: { [string]: { string } } = {
	Part = { "Shape" },
	WedgePart = {},
	CornerWedgePart = {},
	TrussPart = {},
	SpecialMesh = { "MeshType", "MeshId", "TextureId", "Scale", "Offset", "VertexColor" },
	Attachment = { "CFrame" },
	StringValue = { "Value" },
	PointLight = { "Brightness", "Range", "Color", "Shadows" },
	SpotLight = { "Brightness", "Range", "Color", "Angle", "Face" },
	Decal = { "Texture", "Face", "Color3", "Transparency" },
	Texture = { "Texture", "Face", "Color3", "Transparency", "StudsPerTileU", "StudsPerTileV" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "Color" },
	ParticleEmitter = {
		"Texture", "Color", "Size", "Transparency", "Lifetime", "Rate", "Speed", "SpreadAngle", "Rotation",
		"RotSpeed", "Acceleration", "Drag", "LightEmission", "LightInfluence", "EmissionDirection", "Enabled",
		"ZOffset", "Orientation", "Shape", "ShapeInOut", "ShapeStyle", "Brightness", "Squash", "TimeScale",
		"LockedToPart", "VelocityInheritance",
	},
}
local CONTENT = { MeshId = true, TextureId = true, TextureID = true, Texture = true, ColorMap = true, NormalMap = true, RoughnessMap = true, MetalnessMap = true }

local function encode(name: string, value: any): any
	local kind = typeof(value)
	if CONTENT[name] and kind == "string" then
		return { "content", value }
	elseif kind == "number" or kind == "boolean" or kind == "string" then
		return { kind, value }
	elseif kind == "EnumItem" then
		return { "token", value.Value }
	elseif kind == "Vector3" then
		return { "Vector3", { value.X, value.Y, value.Z } }
	elseif kind == "Vector2" then
		return { "Vector2", { value.X, value.Y } }
	elseif kind == "Color3" then
		return { "Color3", { value.R, value.G, value.B } }
	elseif kind == "CFrame" then
		return { "CFrame", { value:GetComponents() } }
	elseif kind == "NumberRange" then
		return { "NumberRange", { value.Min, value.Max } }
	elseif kind == "NumberSequence" then
		local keys = {}
		for _, k in value.Keypoints do
			table.insert(keys, { k.Time, k.Value, k.Envelope })
		end
		return { "NumberSequence", keys }
	elseif kind == "ColorSequence" then
		local keys = {}
		for _, k in value.Keypoints do
			table.insert(keys, { k.Time, k.Value.R, k.Value.G, k.Value.B })
		end
		return { "ColorSequence", keys }
	end
	return nil
end

local function read(instance: Instance, names: { string }, into: { [string]: any })
	for _, name in names do
		local ok, value = pcall(function()
			return (instance :: any)[name]
		end)
		if ok then
			into[name] = encode(name, value)
		end
	end
end

local function walk(instance: Instance): any?
	if instance:IsA("LuaSourceContainer") or instance:IsA("JointInstance") or instance:IsA("WeldConstraint") or instance:IsA("Light") then
		return nil
	end
	local class = instance.ClassName
	local props = {}
	local kids = {}
	if instance:IsA("MeshPart") then
		read(instance, PART, props)
		props.MeshId = { "content", instance.MeshId }
		props.TextureID = { "content", instance.TextureID }
		props.InitialSize = encode("InitialSize", instance.MeshSize)
	elseif instance:IsA("BasePart") then
		read(instance, PART, props)
		read(instance, CLASS_PROPS[class] or {}, props)
	elseif instance:IsA("Model") or instance:IsA("Folder") then
		class = "Model"
	elseif CLASS_PROPS[class] then
		read(instance, CLASS_PROPS[class], props)
	else
		return nil
	end
	for _, child in instance:GetChildren() do
		local node = walk(child)
		if node then
			table.insert(kids, node)
		end
	end
	return { class = class, name = instance.Name, props = props, kids = kids }
end

task.wait(2)
local folder = ServerStorage:FindFirstChild("PropExport")
for _, model in if folder then folder:GetChildren() else {} do
	local ok, err = pcall(function()
		return HttpService:PostAsync(SINK .. model.Name, HttpService:JSONEncode(walk(model)))
	end)
	print("[PropExport]", model.Name, ok, err)
end
