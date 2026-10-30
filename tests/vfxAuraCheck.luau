-- Headless check of the installed relic auras: run `rojo build -o build/RelicCollector.rbxl` then
-- `lune run tests/vfxAuraCheck`. Attaches each aura to a 3-stud part and checks welds, rate caps,
-- extents and that the template helper values are consumed.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")
local game = roblox.deserializePlace(fs.readFile("build/RelicCollector.rbxl"))
local src = fs.readFile("src/client/Effects/RelicAura.luau")
local env = setmetatable({ game = game, task = task, Instance = roblox.Instance, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange, Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame }, { __index = _G })
local RelicAura = luau.load(luau.compile(src), { environment = env })()
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local fails = 0
for _, name in { "Aura_Rare", "Aura_Epic", "Aura_Legendary", "Aura_Mythic", "Aura_Celestial", "Aura_Cosmic", "Aura_TitanicExtra" } do
	local template = RelicAura.template(name)
	assert(template, "missing " .. name)
	local relic = Instance.new("Part")
	relic.Size = Vector3.new(1.5, 3, 1.5)
	relic.CFrame = CFrame.new(10, 5, 0)
	local h = RelicAura.attach(relic, template, { Boost = 1 })
	local aura = relic:FindFirstChild("RelicAura")
	local maxRate, far, parts, welds, leftovers = 0, 0, 0, 0, 0
	for _, d in aura:GetDescendants() do
		if d.ClassName == "ParticleEmitter" then maxRate = math.max(maxRate, d.Rate) end
		if d.ClassName == "Part" then
			parts += 1
			far = math.max(far, (d.CFrame.Position - relic.CFrame.Position).Magnitude)
		end
		if d.ClassName == "WeldConstraint" then welds += 1 end
		if d.Name == "EmitCount" or d.Name == "EmitEvery" or d.Name == "RefHeight" then leftovers += 1 end
	end
	local ok = maxRate <= 60 and far < 6 and welds == parts and leftovers == 0
	if not ok then fails += 1 end
	print(string.format("%-18s parts=%d welds=%d maxRate=%d farthest=%.2f studs %s", name, parts, welds, maxRate, far, ok and "OK" or "FAIL"))
	h:Destroy()
	assert(relic:FindFirstChild("RelicAura") == nil, "destroy failed")
end
print(fails == 0 and "ALL OK" or (fails .. " FAILED"))
