-- Pure checks for imported relic models (Slice 8b/8c): sizing and the warnings /modelcheck shows.
-- No Roblox types here so Lune can test it; RelicModels gathers the facts in Studio.

local ModelCheck = {}

export type Facts = {
	ClassName: string,
	Parts: number,
	HasTexture: boolean,
	Scripts: number,
	-- Bounding size of the first part, in studs.
	SizeX: number,
	SizeY: number,
	SizeZ: number,
}

-- Longest side stays within this ratio of the shortest; thinner meshes vanish at a distance.
ModelCheck.MaxAspect = 25

-- Uniform factor that makes the model's longest side equal the placeholder's longest side.
function ModelCheck.fitFactor(modelLongest: number, targetLongest: number): number
	if modelLongest <= 0 then
		return 1
	end
	return targetLongest / modelLongest
end

-- Display presence of a model: the geometric mean of its two largest dimensions, so a long thin
-- sword and a round fruit with the same presence read as the same size on a pedestal.
ModelCheck.DISPLAY_PRESENCE = 2.2
ModelCheck.DISPLAY_MAX_LONGEST = 4.2

function ModelCheck.presenceFactor(size: Vector3 | { X: number, Y: number, Z: number }): number
	local dims = { size.X, size.Y, size.Z }
	table.sort(dims, function(a, b)
		return a > b
	end)
	local presence = math.sqrt(dims[1] * dims[2])
	if presence <= 0 then
		return 1
	end
	return math.min(ModelCheck.DISPLAY_PRESENCE / presence, ModelCheck.DISPLAY_MAX_LONGEST / dims[1])
end

function ModelCheck.issues(facts: Facts): { string }
	local issues = {}
	if facts.Parts == 0 then
		table.insert(issues, "no parts inside")
		return issues
	end
	if facts.ClassName ~= "MeshPart" then
		table.insert(issues, `first part is a {facts.ClassName}, not a MeshPart`)
	end
	if facts.Parts > 1 then
		table.insert(issues, `{facts.Parts} parts: only the first is used, merge into one mesh`)
	end
	if not facts.HasTexture then
		table.insert(issues, "no texture (SurfaceAppearance or TextureID)")
	end
	if facts.Scripts > 0 then
		table.insert(issues, `{facts.Scripts} script(s) inside: removed when used`)
	end
	local longest = math.max(facts.SizeX, facts.SizeY, facts.SizeZ)
	local shortest = math.min(facts.SizeX, facts.SizeY, facts.SizeZ)
	if shortest <= 0 or longest / shortest > ModelCheck.MaxAspect then
		table.insert(issues, "extremely thin: may disappear at a distance")
	end
	return issues
end

return ModelCheck
