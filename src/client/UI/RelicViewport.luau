-- 3D relic renders for menus (Backpack cards and detail panel). A ViewportFrame holding the
-- relic's model (RelicModels) framed by its own camera. Cards share a small cache so only about
-- MaxLive renders exist at once: scrolling reuses the least recently used one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local UIKit = require(script.Parent.UIKit)

local RelicViewport = {}

local VIEW_ANGLE = CFrame.Angles(math.rad(-12), math.rad(28), 0)

-- Points the viewport camera at `part` so its longest side fills the frame.
local function frame(viewport: ViewportFrame, part: BasePart)
	local camera = viewport.CurrentCamera or Instance.new("Camera")
	camera.FieldOfView = 30
	local size = part.Size.Magnitude
	local distance = size / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 1.05
	camera.CFrame = CFrame.lookAt(part.Position + Vector3.new(0, size * 0.12, distance), part.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- A new viewport showing `relicId` (unparented). `props` are applied to the ViewportFrame.
function RelicViewport.new(relicId: string, props: { [string]: any }?): ViewportFrame
	local viewport = UIKit.create("ViewportFrame", {
		Name = "Render",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 205),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Size = UDim2.fromScale(1, 1),
	})
	for key, value in props or {} do
		(viewport :: any)[key] = value
	end
	RelicViewport.show(viewport, relicId)
	return viewport
end

-- Replaces the relic shown in `viewport`.
function RelicViewport.show(viewport: ViewportFrame, relicId: string)
	for _, child in viewport:GetChildren() do
		if child:IsA("BasePart") then
			child:Destroy()
		end
	end
	local part = RelicModels.build(relicId, VIEW_ANGLE)
	if part then
		part.Parent = viewport
		frame(viewport, part)
	end
	viewport:SetAttribute("RelicId", relicId)
end

-- Turns the shown relic around its vertical axis (detail panel spin).
function RelicViewport.spin(viewport: ViewportFrame, radians: number)
	local part = viewport:FindFirstChildWhichIsA("BasePart")
	if part then
		part.CFrame = CFrame.Angles(0, radians, 0) * part.CFrame
	end
end

export type Cache = {
	-- `key` tells apart copies that share a model (e.g. "<relicId>|<mutation>").
	Get: (key: string, relicId: string) -> ViewportFrame,
	DetachAll: () -> (),
}

-- Least-recently-used pool of renders. Only unparented renders are evicted.
function RelicViewport.cache(maxLive: number): Cache
	local entries: { [string]: { Viewport: ViewportFrame, Used: number } } = {}
	local count = 0
	local clock = 0

	local function evictOne()
		local oldestId, oldest = nil, math.huge
		for id, entry in entries do
			if entry.Viewport.Parent == nil and entry.Used < oldest then
				oldestId, oldest = id, entry.Used
			end
		end
		if oldestId then
			entries[oldestId].Viewport:Destroy()
			entries[oldestId] = nil
			count -= 1
		end
	end

	return {
		Get = function(key: string, relicId: string): ViewportFrame
			clock += 1
			local entry = entries[key]
			if entry then
				entry.Used = clock
				return entry.Viewport
			end
			if count >= maxLive then
				evictOne()
			end
			local viewport = RelicViewport.new(relicId)
			entries[key] = { Viewport = viewport, Used = clock }
			count += 1
			return viewport
		end,
		-- Unparents every render (before the cards holding them are destroyed).
		DetachAll = function()
			for _, entry in entries do
				entry.Viewport.Parent = nil
			end
		end,
	}
end

return RelicViewport
