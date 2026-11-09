-- 3D relic renders for menus (Backpack cards and detail panel). A ViewportFrame holding the
-- relic's model (RelicModels) framed by its own camera. Cards share a small cache so only about
-- MaxLive renders exist at once: scrolling reuses the least recently used one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local SizeConfig = require(ReplicatedStorage.Shared.SizeConfig)
local UIKit = require(script.Parent.UIKit)

local RelicViewport = {}

local VIEW_ANGLE = CFrame.Angles(math.rad(-12), math.rad(28), 0)

-- How much of the frame the relic fills, by size (2026-11-09: the camera used to fit every model
-- the same way, so a Titanic looked no bigger than a Normal one). Titanic spills past the edges.
local FILL = { Normal = 0.72, Huge = 0.95, Titanic = 1.2 }

-- Points the viewport camera at `part` so it fills `fill` of the frame.
local function frame(viewport: ViewportFrame, part: BasePart, fill: number?)
	local camera = viewport.CurrentCamera or Instance.new("Camera")
	camera.FieldOfView = 30
	local size = part.Size.Magnitude
	local distance = size / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 1.05 * 0.95 / (fill or FILL.Normal)
	camera.CFrame = CFrame.lookAt(part.Position + Vector3.new(0, size * 0.12, distance), part.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- A new viewport showing `relicId` (unparented). `props` are applied to the ViewportFrame.
function RelicViewport.new(relicId: string, props: { [string]: any }?, sizeId: string?): ViewportFrame
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
	RelicViewport.show(viewport, relicId, sizeId)
	return viewport
end

-- Replaces the relic shown in `viewport`. Optional sizeId scales Huge/Titanic.
function RelicViewport.show(viewport: ViewportFrame, relicId: string, sizeId: string?)
	for _, child in viewport:GetChildren() do
		if child:IsA("BasePart") then
			child:Destroy()
		end
	end
	local scale = SizeConfig.scaleOf(sizeId)
	local part = RelicModels.build(relicId, VIEW_ANGLE, scale)
	if part and part:GetAttribute("ModelNeeded") then
		-- No model yet: a dark silhouette tinted with the rarity color reads as "relic", not as a
		-- white block.
		local relic = RelicConfig.ById[relicId]
		local tint = if relic then UIKit.tierColor(relic.Tier) else UIKit.Colors.SubText
		part.Color = tint:Lerp(Color3.fromRGB(20, 14, 30), 0.55)
		part.Material = Enum.Material.SmoothPlastic
	end
	if part then
		part.Parent = viewport
		frame(viewport, part, FILL[SizeConfig.normalize(sizeId) or "Normal"])
	end
	viewport:SetAttribute("RelicId", relicId)
	viewport:SetAttribute("Size", sizeId or "")
end

-- Turns the shown relic around its vertical axis (detail panel spin).
function RelicViewport.spin(viewport: ViewportFrame, radians: number)
	local part = viewport:FindFirstChildWhichIsA("BasePart")
	if part then
		part.CFrame = CFrame.Angles(0, radians, 0) * part.CFrame
	end
end

export type Cache = {
	-- `key` tells apart copies that share a model (e.g. "<relicId>|<mutation>|<size>").
	Get: (key: string, relicId: string, sizeId: string?) -> ViewportFrame,
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
		Get = function(key: string, relicId: string, sizeId: string?): ViewportFrame
			clock += 1
			local entry = entries[key]
			if entry then
				entry.Used = clock
				return entry.Viewport
			end
			if count >= maxLive then
				evictOne()
			end
			local viewport = RelicViewport.new(relicId, nil, sizeId)
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
