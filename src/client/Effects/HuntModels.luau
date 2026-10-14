-- Hunt VFX meshes from ReplicatedStorage.HuntModels (synced from assets/HuntModels/<Name>.rbxm):
-- SignalCore, OfudaTalisman, ChainLink, SealJar and LostOne. Each is cloned as one anchored decor part,
-- scaled so its longest side is `size`. Callers fall back to primitives when a model is missing.
-- Optional attributes on a model: DisplayScale (number) and DisplayRotation (Vector3, degrees).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HuntModels = {}

local function asset(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("HuntModels")
	return folder and folder:FindFirstChild(name)
end

local function template(name: string): BasePart?
	local found = asset(name)
	if not found then
		return nil
	end
	if found:IsA("BasePart") then
		return found
	end
	return found:FindFirstChildWhichIsA("BasePart", true)
end

function HuntModels.has(name: string): boolean
	return template(name) ~= nil
end

-- The imported part's own size, before build() rescales it (attachments inside keep positions
-- for this size).
function HuntModels.sourceSize(name: string): Vector3?
	local source = template(name)
	return source and source.Size
end

-- An attribute set on the imported model (or nil).
function HuntModels.attribute(name: string, key: string): any
	local found = asset(name)
	return found and found:GetAttribute(key)
end

-- The imported part's rotation as saved (imported meshes often carry one; build() returns the
-- part unrotated).
function HuntModels.sourceRotation(name: string): CFrame?
	local source = template(name)
	return source and source.CFrame.Rotation
end

-- Rotation that turns the part's longest side along Z and its thinnest along Y (chain links lie
-- along the chain, talismans stand flat), so meshes work whatever axes they were exported with.
local function axisTurn(size: Vector3): CFrame
	local sides = { { 1, size.X }, { 2, size.Y }, { 3, size.Z } }
	table.sort(sides, function(a, b)
		return a[2] > b[2]
	end)
	local images = { Vector3.zero, Vector3.zero, Vector3.zero }
	images[sides[1][1]] = Vector3.zAxis
	images[sides[2][1]] = Vector3.xAxis
	images[sides[3][1]] = Vector3.yAxis
	if images[1]:Cross(images[2]):Dot(images[3]) < 0 then
		images[sides[2][1]] = -Vector3.xAxis
	end
	return CFrame.fromMatrix(Vector3.zero, images[1], images[2], images[3])
end

export type Built = {
	Part: BasePart,
	-- Applied after the caller's frame: part.CFrame = frame * Turn.
	Turn: CFrame,
}

-- `alignAxes`: also turn the longest side along Z and the thinnest along Y.
function HuntModels.build(name: string, size: number, alignAxes: boolean?): Built?
	local source = template(name)
	if not source then
		return nil
	end
	local part = source:Clone()
	for _, child in part:GetDescendants() do
		if child:IsA("LuaSourceContainer") or child:IsA("BasePart") or child:IsA("JointInstance") then
			child:Destroy()
		end
	end
	local model = asset(name) :: Instance
	local extra = model:GetAttribute("DisplayScale")
	local longest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	if longest > 0 then
		part.Size *= size / longest * (if type(extra) == "number" and extra > 0 then extra else 1)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true

	local rotation = model:GetAttribute("DisplayRotation")
	local turn = if typeof(rotation) == "Vector3"
		then CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		else CFrame.identity
	if alignAxes then
		turn = turn * axisTurn(part.Size)
	end
	return { Part = part, Turn = turn }
end

return HuntModels
